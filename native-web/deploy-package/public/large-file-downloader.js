// 大文件下载器 - 专门处理超大文件的流式下载
class LargeFileDownloader {
    constructor() {
        this.controllers = new Map();
        this.cacheName = 'large-file-cache-v1';
        this.chunkSize = 10 * 1024 * 1024; // 10MB 分片
        this.progressCache = new Map(); // 内存中的进度缓存
    }

    /**
     * 创建组合的中止信号，当任何一个信号中止时都会触发
     */
    createCombinedAbortSignal(signals) {
        const controller = new AbortController();
        
        for (const signal of signals) {
            if (signal && signal.aborted) {
                controller.abort();
                break;
            }
            if (signal) {
                signal.addEventListener('abort', () => controller.abort(), { once: true });
            }
        }
        
        return controller.signal;
    }

    /**
     * 下载大文件，使用分片方式避免内存溢出，支持断点续传
     */
    async downloadLargeFile(downloadId, url, onProgress = null, externalAbortController = null) {
        console.log(`开始下载大文件: ${downloadId}`);
        
        // 检查是否有缓存的文件
        const cache = await caches.open(this.cacheName);
        const cachedResponse = await cache.match(downloadId);
        
        if (cachedResponse) {
            const cachedBlob = await cachedResponse.blob();
            const expectedSize = parseInt(cachedResponse.headers.get('X-Total-Size') || '0', 10);
            
            if (expectedSize > 0 && cachedBlob.size === expectedSize) {
                console.log(`文件已完整缓存: ${downloadId} (${(cachedBlob.size / 1024 / 1024).toFixed(2)} MB)`);
                return cachedBlob;
            } else if (expectedSize > 0 && cachedBlob.size < expectedSize) {
                console.log(`发现部分缓存文件，准备断点续传: ${cachedBlob.size}/${expectedSize} 字节`);
                return this.resumeDownload(downloadId, url, cachedBlob, expectedSize, onProgress, externalAbortController);
            }
        }
        
        // 首先获取文件信息
        const headResponse = await fetch(url, { method: 'HEAD' });
        if (!headResponse.ok) {
            throw new Error(`无法获取文件信息: ${headResponse.status}`);
        }
        
        const contentLength = headResponse.headers.get('Content-Length');
        const totalSize = contentLength ? parseInt(contentLength, 10) : 0;
        
        console.log(`HEAD 响应 Content-Length: ${contentLength}, 解析后大小: ${totalSize}`);
        
        if (!totalSize || totalSize === 0) {
            console.log('HEAD 请求未返回有效文件大小，尝试部分下载来获取大小');
            // 尝试下载前1KB来获取实际文件大小
            const testResponse = await fetch(url, {
                headers: { 'Range': 'bytes=0-1023' }
            });
            
            if (testResponse.status === 206) {
                const contentRange = testResponse.headers.get('Content-Range');
                console.log(`Range 响应 Content-Range: ${contentRange}`);
                
                if (contentRange) {
                    const match = contentRange.match(/bytes \d+-\d+\/(\d+)/);
                    if (match) {
                        const actualSize = parseInt(match[1], 10);
                        console.log(`从 Content-Range 获取实际文件大小: ${actualSize}`);
                        return this.downloadInChunks(downloadId, url, actualSize, onProgress);
                    }
                }
            }
            
            throw new Error('无法确定文件大小，HEAD 和 Range 请求都失败');
        }
        
        console.log(`文件总大小: ${(totalSize / 1024 / 1024).toFixed(2)} MB`);
        
        // 检查是否支持范围请求
        const acceptRanges = headResponse.headers.get('Accept-Ranges');
        if (acceptRanges !== 'bytes') {
            console.warn('服务器不支持范围请求，将尝试完整下载');
            return this.downloadComplete(downloadId, url, totalSize, onProgress, externalAbortController);
        }
        
        // 使用分片下载
        return this.downloadInChunks(downloadId, url, totalSize, onProgress, externalAbortController);
    }
    
    /**
     * 分片下载大文件
     */
    async downloadInChunks(downloadId, url, totalSize, onProgress, externalAbortController = null) {
        const chunks = [];
        const numChunks = Math.ceil(totalSize / this.chunkSize);
        let downloadedBytes = 0;
        
        console.log(`开始分片下载，共 ${numChunks} 个分片`);
        
        for (let i = 0; i < numChunks; i++) {
            // 检查外部中止信号
            if (externalAbortController && externalAbortController.signal.aborted) {
                console.log('分片下载被外部中止');
                throw new DOMException('分片下载被外部中止', 'AbortError');
            }
            
            // 检查主下载是否被中止
            if (this.controllers.has(downloadId) && this.controllers.get(downloadId).signal.aborted) {
                console.log('分片下载被中止');
                throw new DOMException('分片下载被中止', 'AbortError');
            }
            
            const start = i * this.chunkSize;
            const end = Math.min(start + this.chunkSize - 1, totalSize - 1);
            
            console.log(`下载分片 ${i + 1}/${numChunks}: ${start}-${end}`);
            
            const controller = new AbortController();
            this.controllers.set(`${downloadId}_chunk_${i}`, controller);
            
            try {
                // 创建组合的中止信号
                const combinedSignal = this.createCombinedAbortSignal([
                    controller.signal,
                    externalAbortController?.signal,
                    this.controllers.get(downloadId)?.signal
                ].filter(Boolean));
                
                const response = await fetch(url, {
                    headers: { 'Range': `bytes=${start}-${end}` },
                    signal: combinedSignal
                });
                
                if (response.status !== 206) {
                    throw new Error(`分片下载失败: ${response.status}`);
                }
                
                // 使用流式读取，以便能够及时响应中止信号
                const reader = response.body.getReader();
                const chunkParts = [];
                
                try {
                    while (true) {
                        // 检查中止信号
                        if (combinedSignal.aborted) {
                            throw new DOMException('下载被中止', 'AbortError');
                        }
                        
                        const { done, value } = await reader.read();
                        if (done) break;
                        chunkParts.push(value);
                    }
                } finally {
                    reader.releaseLock();
                }
                
                // 合并分片数据
                const totalChunkSize = chunkParts.reduce((acc, part) => acc + part.length, 0);
                const chunkData = new Uint8Array(totalChunkSize);
                let offset = 0;
                for (const part of chunkParts) {
                    chunkData.set(part, offset);
                    offset += part.length;
                }
                
                chunks.push(chunkData);
                downloadedBytes += chunkData.byteLength;
                
                if (onProgress) {
                    onProgress(downloadedBytes, totalSize);
                }
                
                console.log(`分片 ${i + 1} 下载完成: ${chunkData.byteLength} 字节`);
                
            } catch (error) {
                if (error.name === 'AbortError') {
                    console.log(`分片 ${i + 1} 下载被中止`);
                    // 保存已下载的分片作为断点续传的基础
                    if (chunks.length > 0) {
                        console.log(`保存断点续传进度: ${chunks.length} 个分片已完成`);
                        const partialArray = new Uint8Array(chunks.reduce((sum, chunk) => sum + chunk.length, 0));
                        let offset = 0;
                        for (const chunk of chunks) {
                            partialArray.set(chunk, offset);
                            offset += chunk.length;
                        }
                        const partialBlob = new Blob([partialArray]);
                        await this.cacheFile(downloadId, partialBlob, totalSize);
                        console.log(`已保存 ${(partialBlob.size / 1024 / 1024).toFixed(2)} MB 用于断点续传`);
                    }
                } else {
                    console.error(`分片 ${i + 1} 下载失败:`, error);
                }
                throw error;
            } finally {
                this.controllers.delete(`${downloadId}_chunk_${i}`);
            }
        }
        
        // 合并所有分片
        console.log('正在合并分片...');
        const totalBytes = chunks.reduce((sum, chunk) => sum + chunk.length, 0);
        const mergedArray = new Uint8Array(totalBytes);
        let offset = 0;
        
        for (const chunk of chunks) {
            mergedArray.set(chunk, offset);
            offset += chunk.length;
        }
        
        const finalBlob = new Blob([mergedArray]);
        console.log(`文件合并完成，最终大小: ${(finalBlob.size / 1024 / 1024).toFixed(2)} MB`);
        
        // 缓存完整文件
        await this.cacheFile(downloadId, finalBlob, totalSize);
        
        return finalBlob;
    }
    
    /**
     * 完整下载（当服务器不支持范围请求时）
     */
    async downloadComplete(downloadId, url, totalSize, onProgress, externalAbortController = null) {
        console.log('开始完整文件下载...');
        
        const controller = new AbortController();
        this.controllers.set(downloadId, controller);
        
        try {
            const response = await fetch(url, { signal: controller.signal });
            if (!response.ok) {
                throw new Error(`下载失败: ${response.status}`);
            }
            
            const reader = response.body.getReader();
            const chunks = [];
            let downloadedBytes = 0;
            
            while (true) {
                // 检查外部中止信号
                if (externalAbortController && externalAbortController.signal.aborted) {
                    console.log('下载被外部中止');
                    reader.releaseLock();
                    throw new DOMException('下载被外部中止', 'AbortError');
                }
                
                // 检查是否被中止
                if (controller.signal.aborted) {
                    console.log('下载被中止');
                    reader.releaseLock();
                    throw new DOMException('下载被中止', 'AbortError');
                }
                
                const { done, value } = await reader.read();
                if (done) break;
                
                chunks.push(value);
                downloadedBytes += value.length;
                
                if (onProgress) {
                    onProgress(downloadedBytes, totalSize);
                }
                
                // 每下载50MB输出一次进度
                if (downloadedBytes % (50 * 1024 * 1024) < value.length) {
                    console.log(`已下载: ${(downloadedBytes / 1024 / 1024).toFixed(2)} MB / ${(totalSize / 1024 / 1024).toFixed(2)} MB`);
                }
            }
            
            const blob = new Blob(chunks);
            console.log(`完整下载完成: ${(blob.size / 1024 / 1024).toFixed(2)} MB`);
            return blob;
            
        } catch (error) {
            if (error.name === 'AbortError') {
                console.log('完整下载被中止，保存断点续传进度');
                
                // 保存已下载的数据用于断点续传
                if (chunks.length > 0) {
                    const partialBlob = new Blob(chunks);
                    await this.cacheFile(downloadId, partialBlob, totalSize);
                    console.log(`已保存 ${(partialBlob.size / 1024 / 1024).toFixed(2)} MB 用于断点续传`);
                }
            }
            throw error;
        } finally {
            this.controllers.delete(downloadId);
        }
    }
    
    /**
     * 中止下载
     */
    abort(downloadId) {
        console.log(`正在中止下载: ${downloadId}`);
        
        // 中止主下载
        if (this.controllers.has(downloadId)) {
            const controller = this.controllers.get(downloadId);
            try {
                controller.abort();
                console.log(`主下载控制器已中止: ${downloadId}`);
            } catch (error) {
                console.warn(`中止主下载控制器时出错: ${error.message}`);
            }
            this.controllers.delete(downloadId);
        }
        
        // 中止所有相关的分片下载
        const chunkControllers = Array.from(this.controllers.keys())
            .filter(key => key.startsWith(`${downloadId}_chunk_`));
            
        console.log(`找到 ${chunkControllers.length} 个分片控制器需要中止`);
        chunkControllers.forEach(key => {
            const controller = this.controllers.get(key);
            try {
                controller.abort();
                console.log(`分片控制器已中止: ${key}`);
            } catch (error) {
                console.warn(`中止分片控制器时出错: ${error.message}`);
            }
            this.controllers.delete(key);
        });
        
        // 清理进度缓存
        this.progressCache.delete(downloadId);
        
        console.log(`下载中止完成: ${downloadId}`);
    }
    
    /**
     * 断点续传下载
     */
    async resumeDownload(downloadId, url, existingBlob, totalSize, onProgress, externalAbortController = null) {
        console.log(`断点续传下载: ${downloadId}, 已有 ${existingBlob.size} 字节`);
        
        const startByte = existingBlob.size;
        const controller = new AbortController();
        this.controllers.set(downloadId, controller);
        
        try {
            const response = await fetch(url, {
                headers: { 'Range': `bytes=${startByte}-` },
                signal: controller.signal
            });
            
            if (response.status !== 206) {
                console.log('服务器不支持断点续传，重新下载');
                return this.downloadInChunks(downloadId, url, totalSize, onProgress, externalAbortController);
            }
            
            const reader = response.body.getReader();
            const newChunks = [];
            let downloadedBytes = startByte;
            
            while (true) {
                // 检查外部中止信号
                if (externalAbortController && externalAbortController.signal.aborted) {
                    console.log('断点续传被外部中止');
                    reader.releaseLock();
                    throw new DOMException('断点续传被外部中止', 'AbortError');
                }
                
                if (controller.signal.aborted) {
                    console.log('断点续传被中止');
                    reader.releaseLock();
                    throw new DOMException('断点续传被中止', 'AbortError');
                }
                
                const { done, value } = await reader.read();
                if (done) break;
                
                newChunks.push(value);
                downloadedBytes += value.length;
                
                if (onProgress) {
                    onProgress(downloadedBytes, totalSize);
                }
                
                // 每下载50MB保存一次进度
                if (newChunks.length > 0 && downloadedBytes % (50 * 1024 * 1024) < value.length) {
                    console.log(`断点续传进度: ${(downloadedBytes / 1024 / 1024).toFixed(2)} MB / ${(totalSize / 1024 / 1024).toFixed(2)} MB`);
                    // 保存当前进度
                    const partialBlob = new Blob([existingBlob, ...newChunks]);
                    await this.cacheFile(downloadId, partialBlob, totalSize);
                }
            }
            
            // 合并所有数据
            const finalBlob = new Blob([existingBlob, ...newChunks]);
            await this.cacheFile(downloadId, finalBlob, totalSize);
            
            console.log(`断点续传完成: ${(finalBlob.size / 1024 / 1024).toFixed(2)} MB`);
            return finalBlob;
            
        } catch (error) {
            if (error.name === 'AbortError') {
                console.log('断点续传被中止，保存当前进度');
                
                // 保存当前进度（包括原有数据和新下载的数据）
                if (newChunks.length > 0) {
                    const currentBlob = new Blob([existingBlob, ...newChunks]);
                    await this.cacheFile(downloadId, currentBlob, totalSize);
                    console.log(`断点续传已保存 ${(currentBlob.size / 1024 / 1024).toFixed(2)} MB 用于下次继续`);
                }
            }
            throw error;
        } finally {
            this.controllers.delete(downloadId);
        }
    }
    
    /**
     * 缓存文件
     */
    async cacheFile(downloadId, blob, totalSize) {
        const cache = await caches.open(this.cacheName);
        const headers = {
            'Content-Length': blob.size,
            'X-Total-Size': totalSize,
            'Content-Type': 'application/octet-stream'
        };
        const response = new Response(blob, { headers });
        await cache.put(downloadId, response);
    }

    /**
     * 中止所有下载
     */
    abortAll() {
        console.log(`正在中止所有 ${this.controllers.size} 个下载`);
        
        const controllerIds = Array.from(this.controllers.keys());
        for (const controllerId of controllerIds) {
            const controller = this.controllers.get(controllerId);
            try {
                controller.abort();
                console.log(`已中止控制器: ${controllerId}`);
            } catch (error) {
                console.warn(`中止控制器时出错 ${controllerId}: ${error.message}`);
            }
        }
        
        this.controllers.clear();
        this.progressCache.clear();
        console.log('所有下载已中止，缓存已清理');
    }
}

// 暴露给全局使用
if (typeof window !== 'undefined') {
    window.LargeFileDownloader = LargeFileDownloader;
}
if (typeof self !== 'undefined') {
    self.LargeFileDownloader = LargeFileDownloader;
}