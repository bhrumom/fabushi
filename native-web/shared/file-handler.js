/**
 * 文件处理模块
 * 用于在不同平台间共享的文件处理逻辑
 */

/**
 * 文件队列管理器
 */
export class FileQueue {
    constructor() {
        this.queue = [];
        this.processing = false;
    }
    
    /**
     * 添加文件到队列
     * @param {File|Object} file - 文件对象
     */
    addFile(file) {
        this.queue.push(file);
    }
    
    /**
     * 从队列中移除文件
     * @param {string} fileId - 文件ID
     */
    removeFile(fileId) {
        this.queue = this.queue.filter(file => file.id !== fileId);
    }
    
    /**
     * 获取队列中的所有文件
     * @returns {Array} 文件数组
     */
    getFiles() {
        return [...this.queue];
    }
    
    /**
     * 清空队列
     */
    clear() {
        this.queue = [];
    }
    
    /**
     * 获取队列大小
     * @returns {number} 队列中的文件数量
     */
    size() {
        return this.queue.length;
    }
}

/**
 * 文件发送管理器
 */
export class FileSender {
    constructor(countryServers) {
        this.countryServers = countryServers;
        this.isSending = false;
        this.isLoopMode = false;
        this.abortController = null;
    }
    
    /**
     * 开始发送文件
     * @param {Array} files - 要发送的文件数组
     * @param {Function} progressCallback - 进度回调函数
     * @param {Function} logCallback - 日志回调函数
     * @returns {Promise} 发送结果
     */
    async startSending(files, progressCallback, logCallback) {
        if (this.isSending) {
            throw new Error('发送正在进行中，请先停止当前发送任务');
        }
        
        this.isSending = true;
        this.abortController = new AbortController();
        
        try {
            logCallback('🚀 开始发送文件到全球249个国家...');
            
            // 发送每个文件
            for (let i = 0; i < files.length; i++) {
                if (this.abortController.signal.aborted) {
                    logCallback('⏹️ 发送任务已被用户中断');
                    break;
                }
                
                const file = files[i];
                logCallback(`📄 正在发送文件: ${file.name || file.fileName} (${formatFileSize(file.size || 0)})`);
                
                // 发送到所有国家
                await this.countryServers.sendToAllCountries(file, (progress) => {
                    if (progressCallback) {
                        progressCallback({
                            fileIndex: i,
                            fileName: file.name || file.fileName,
                            totalFiles: files.length,
                            ...progress
                        });
                    }
                });
            }
            
            logCallback('✅ 所有文件发送完成！');
            return { success: true };
        } catch (error) {
            logCallback(`❌ 发送过程中发生错误: ${error.message}`);
            return { success: false, error: error.message };
        } finally {
            this.isSending = false;
            this.abortController = null;
        }
    }
    
    /**
     * 停止发送文件
     */
    stopSending() {
        if (this.abortController) {
            this.abortController.abort();
            this.isSending = false;
        }
    }
    
    /**
     * 设置循环模式
     * @param {boolean} enabled - 是否启用循环模式
     */
    setLoopMode(enabled) {
        this.isLoopMode = enabled;
    }
}

/**
 * 格式化文件大小
 * @param {number} bytes - 字节数
 * @param {number} decimals - 小数位数
 * @returns {string} 格式化后的文件大小
 */
function formatFileSize(bytes, decimals = 2) {
    if (bytes === 0) return '0 Bytes';
    
    const k = 1024;
    const dm = decimals < 0 ? 0 : decimals;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
}

/**
 * 读取文件内容为文本
 * @param {File|Blob} file - 文件对象
 * @returns {Promise<string>} 文件内容
 */
export function readFileAsText(file) {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => resolve(reader.result);
        reader.onerror = () => reject(reader.error);
        reader.readAsText(file);
    });
}

/**
 * 读取文件内容为ArrayBuffer
 * @param {File|Blob} file - 文件对象
 * @returns {Promise<ArrayBuffer>} 文件内容
 */
export function readFileAsArrayBuffer(file) {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => resolve(reader.result);
        reader.onerror = () => reject(reader.error);
        reader.readAsArrayBuffer(file);
    });
}

/**
 * 读取文件内容为DataURL
 * @param {File|Blob} file - 文件对象
 * @returns {Promise<string>} DataURL
 */
export function readFileAsDataURL(file) {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => resolve(reader.result);
        reader.onerror = () => reject(reader.error);
        reader.readAsDataURL(file);
    });
}

/**
 * 从URL下载文件
 * @param {string} url - 文件URL
 * @param {string} filename - 文件名
 * @returns {Promise<File>} 下载的文件
 */
export async function downloadFileFromURL(url, filename) {
    try {
        const response = await fetch(url);
        if (!response.ok) {
            throw new Error(`下载失败: ${response.status} ${response.statusText}`);
        }
        
        const blob = await response.blob();
        return new File([blob], filename, { type: blob.type });
    } catch (error) {
        throw new Error(`下载文件时发生错误: ${error.message}`);
    }
}

export default {
    FileQueue,
    FileSender,
    readFileAsText,
    readFileAsArrayBuffer,
    readFileAsDataURL,
    downloadFileFromURL,
    formatFileSize
};