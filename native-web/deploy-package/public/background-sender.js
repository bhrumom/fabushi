// 后台发送服务 - v7.0 (采用优化的任务池并发模型，提升小文件发送速度)
let isRunning = false;
let loopMode = false;
let contentQueue = [];
let countryServers = {};
let countryNames = {};
let loopDelay = 2000;
let sendConcurrency = 10; // 默认并发数

/**
 * 优化：将日志消息发送回主线程，只输出错误信息
 * 成功发送的国家信息只记录在国家状态中
 * @param {string} message 
 * @param {string} level 日志级别: 'info', 'success', 'error', 'warning'
 */
function logMessage(message, level = 'info') {
    // 优化：只发送错误和警告信息到主线程
    if (level === 'error' || level === 'warning' || 
        message.includes('❌') || message.includes('失败') || 
        message.includes('错误') || message.includes('⚠️')) {
        postMessage({ type: 'log', message, level });
    }
    
    // 成功信息不再发送到主线程，减少日志噪音
    // 成功发送的国家信息只记录在国家状态中
}

/**
 * 获取要发送的内容。
 * @param {object} item - 队列中的指令项
 * @returns {Promise<Blob|File|null>}
 */
async function getContent(item) {
    if (item.type === 'file') {
        return item.file;
    }
    if (item.type === 'asset') {
        try {
            const response = await fetch(item.path);
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            return await response.blob();
        } catch (e) {
            logMessage(`[后台] ❌ 加载素材失败: ${item.path}. 错误: ${e.message}`);
            console.error(`[后台] Failed to fetch asset: ${item.path}`, e);
            return null;
        }
    }
    return null;
}

/**
 * 将内容发送到单个国家的所有服务器。
 * 核心策略：始终发送包含完整文件数据的 FormData 对象，并使用 no-cors 模式。
 * @param {object} item - 队列项
 * @param {Blob|File} content - 要发送的完整文件内容
 * @param {string} countryCode - 国家代码
 * @returns {Promise<boolean>} - 是否成功
 */
async function sendToSingleCountry(item, content, countryCode) {
    const servers = countryServers[countryCode] || [];
    if (servers.length === 0) return false;

    const countryName = countryNames[countryCode] || countryCode;

    for (const server of servers) {
        if (!isRunning) return false;
        try {
            // 核心策略：使用 FormData 来包装文件数据。这是发送文件的标准方法。
            const formData = new FormData();
            // 'file' 是一个常见的字段名，'item.name' 是原始文件名。
            formData.append('file', content, item.name);

            // 关键：使用 'no-cors' 模式来绕过浏览器的CORS预检请求。
            // 这对于向未明确配置CORS的服务器发送数据至关重要。
            await fetch(server, {
                method: 'POST',
                body: formData,
                mode: 'no-cors'
            });

            // 优化：成功发送不输出日志，只记录在国家状态中
            // logMessage(`✅ [${item.name}] -> ${countryName}: 文件数据已发送`, 'success');
            return true;
        } catch (e) {
            if (e.name !== 'AbortError' && isRunning) {
                logMessage(`❌ [后台] 发往 ${countryName} (${server}) 失败: ${e.message}`, 'error');
                console.error(`[后台] Fetch error details for ${countryName}:`, e);
            }
        }
    }
    return false;
}

/**
 * 启动发送流程的主函数 (V7.0 优化的任务池模型)
 */
async function startSendingProcess() {
    isRunning = true;
    logMessage(`🚀 [后台] 后台发送服务已启动...`);
    postMessage({ type: 'started', payload: { startTime: Date.now() } });

    try {
        do {
            const allTasks = [];
            const allCountryCodes = Object.keys(countryServers);
            for (const item of contentQueue) {
                for (const countryCode of allCountryCodes) {
                    allTasks.push({ item, countryCode });
                }
            }

            const totalTasks = allTasks.length;
            let completedTasks = 0;
            // 移除任务准备就绪的日志输出，只在出现错误时输出
            // logMessage(`[后台] 任务准备就绪，总共需要处理 ${totalTasks} 个发送操作。`, 'info');
            
            postMessage({
                type: 'progress',
                payload: { sentItems: 0, totalItems: totalTasks }
            });

            const taskQueue = [...allTasks];
            const executing = new Set();

            const processTask = async (task) => {
                try {
                    const content = await getContent(task.item);
                    if (content && isRunning) {
                        await sendToSingleCountry(task.item, content, task.countryCode);
                    }
                } catch (error) {
                    if (isRunning) {
                        logMessage(`❌ [后台] 处理任务 "${task.item.name}" -> ${task.countryCode} 时出错: ${error.message}`, 'error');
                    }
                } finally {
                    if (isRunning) {
                        completedTasks++;
                        postMessage({
                            type: 'progress',
                            payload: { sentItems: completedTasks, totalItems: totalTasks }
                        });
                        // 移除任务完成的日志输出，只在出现错误时输出
                    }
                }
            };

            const run = async () => {
                // 主循环，只要还有任务在队列中或在执行中，就继续
                while (taskQueue.length > 0 || executing.size > 0) {
                    if (!isRunning) break;

                    // 填充执行队列直到达到并发上限
                    while (executing.size < sendConcurrency && taskQueue.length > 0) {
                        if (!isRunning) break;
                        const task = taskQueue.shift();
                        const promise = processTask(task).finally(() => executing.delete(promise));
                        executing.add(promise);
                    }

                    // 等待任意一个正在执行的任务完成
                    if (executing.size > 0) {
                        await Promise.race(executing);
                    } else {
                        // 如果队列为空且执行集也为空，则退出
                        break;
                    }
                }
            };

            await run();

            if (loopMode && isRunning) {
                logMessage(`🔄 [后台] 完成一轮循环，${(loopDelay / 1000).toFixed(1)}秒后开始下一轮...`);
                await new Promise(resolve => setTimeout(resolve, loopDelay));
            }
        } while (isRunning && loopMode);
    } catch (error) {
        logMessage(`❌ [后台] 发送时发生严重错误: ${error.message}`);
    } finally {
        if (isRunning) {
            logMessage('✅ [后台] 所有任务已完成。');
            postMessage({ type: 'finished' });
        }
    }
}

// 监听来自主线程的消息
self.onmessage = function(e) {
    const { command, payload } = e.data;

    switch (command) {
        case 'start':
            if (isRunning) {
                logMessage("⚠️ [后台] 发送任务已在运行中。");
                return;
            }
            countryServers = payload.countryServers;
            countryNames = payload.countryNames;
            contentQueue = payload.contentQueue;
            loopMode = payload.loopMode;
            loopDelay = payload.loopDelay || 2000;
            sendConcurrency = Math.min(Math.max(1, parseInt(payload.speed || 10, 10)), 50); // 提升最大并发限制
            
            logMessage(`⚙️ [后台] 并发数已设置为 ${sendConcurrency}`);
            startSendingProcess();
            break;

        case 'stop':
            if (isRunning) {
                isRunning = false;
                logMessage('⏹️ [后台] 收到停止指令，正在安全地完成当前任务...');
                postMessage({ type: 'stopped' });
            }
            break;

        case 'updateSpeed':
            const newSpeed = Math.min(Math.max(1, parseInt(payload.speed || 10, 10)), 50);
            if (sendConcurrency !== newSpeed) {
                sendConcurrency = newSpeed;
                logMessage(`⚙️ [后台] 并发数已动态更新为 ${sendConcurrency}`);
            }
            break;
    }
};