// download-manager.js v3.0 (Resumable Downloads)

class DownloadManager {
    constructor() {
        this.controllers = new Map();
        this.inflight = new Map();
        // 版本号变更，避免与旧缓存冲突
        this.cacheName = 'download-cache-v2'; 
    }

    /**
     * 将文件 Blob 及其预期的总大小一同缓存。
     * @param {string} key - 缓存键。
     * @param {Blob} blob - 文件内容 (可以是部分的或完整的)。
     * @param {number} totalSize - 完整文件的总大小。
     */
    async _cacheFile(key, blob, totalSize) {
        const cache = await caches.open(this.cacheName);
        const headers = {
            'Content-Length': blob.size,
            'X-Total-Size': totalSize
        };
        const response = new Response(blob, { headers });
        await cache.put(key, response);
    }

    /**
     * 获取文件的主要公共方法。
     * 它会从缓存返回完整的文件，或者启动/恢复下载。
     * @param {string} downloadId - 文件的唯一标识符。
     * @param {string} url - 必要时用于下载的 URL。
     * @returns {Promise<Blob>}
     */
    async getFile(downloadId, url) {
        if (this.inflight.has(downloadId)) {
            console.log(`ID 为 ${downloadId} 的下载已在进行中，等待完成...`);
            return this.inflight.get(downloadId);
        }

        const cache = await caches.open(this.cacheName);
        const cachedResponse = await cache.match(downloadId);

        let startByte = 0;
        let totalSize = 0;

        if (cachedResponse) {
            const cachedBlob = await cachedResponse.blob();
            const expectedTotalSize = parseInt(cachedResponse.headers.get('X-Total-Size'), 10);

            if (cachedBlob.size === expectedTotalSize) {
                console.log(`文件 ${downloadId} 在缓存中已完整。`);
                return cachedBlob;
            }

            if (cachedBlob.size < expectedTotalSize) {
                console.log(`恢复文件 ${downloadId} 的下载。`);
                startByte = cachedBlob.size;
                totalSize = expectedTotalSize;
            }
        }

        // 如果执行到这里，说明需要下载（或恢复下载）。
        const promise = this.startOrResumeDownload(downloadId, url, startByte, totalSize);
        this.inflight.set(downloadId, promise);
        try {
            const result = await promise;
            return result;
        } finally {
            this.inflight.delete(downloadId);
        }
    }

    /**
     * 处理实际的下载逻辑，包括恢复下载。
     * @private
     */
    async startOrResumeDownload(downloadId, url, startByte = 0, knownTotalSize = 0, retryAttempt = 0) {
        const controller = new AbortController();
        const { signal } = controller;
        this.controllers.set(downloadId, controller);

        const headers = {};
        if (startByte > 0) {
            headers['Range'] = `bytes=${startByte}-`;
        }

        let response;
        try {
            response = await fetch(url, { signal, headers });
        } catch (error) {
            // 网络错误或在收到响应前中止
            this.controllers.delete(downloadId);
            throw error;
        }

        // 如果我们请求了一个范围，但服务器返回 200，说明它不支持范围请求。
        // 我们必须从头开始下载。
        if (response.status === 200 && startByte > 0) {
            console.warn(`服务器 ${url} 未遵循 Range 请求。正在重新从头下载。`);
            startByte = 0;
        } else if (startByte > 0 && response.status !== 206) {
            // 对于范围请求，任何非 206 的响应都是一个错误。
            this.controllers.delete(downloadId);
            throw new Error(`服务器对 Range 请求返回了状态 ${response.status}。`);
        }

        if (!response.ok) {
            this.controllers.delete(downloadId);
            throw new Error(`HTTP 错误！状态: ${response.status}`);
        }

        const totalSize = knownTotalSize > 0 ? knownTotalSize :
            response.headers.get('Content-Range')
                ? parseInt(response.headers.get('Content-Range').split('/')[1], 10)
                : +response.headers.get('Content-Length');

        if (isNaN(totalSize)) {
             this.controllers.delete(downloadId);
             throw new Error('无法确定文件的总大小。');
        }

        const cache = await caches.open(this.cacheName);
        const cachedResponse = startByte > 0 ? await cache.match(downloadId) : null;
        const existingData = cachedResponse ? [await cachedResponse.arrayBuffer()] : [];

        const reader = response.body.getReader();
        const receivedChunks = [];

        try {
            while (true) {
                // 检查中止信号
                if (signal.aborted) {
                    reader.releaseLock();
                    throw new DOMException('下载被中止', 'AbortError');
                }
                
                const { done, value } = await reader.read();
                if (done) break;
                receivedChunks.push(value);
            }

            const allData = new Blob(existingData.concat(receivedChunks));
            await this._cacheFile(downloadId, allData, totalSize);

            // 只有当服务器提供了明确的 Content-Length 时才进行大小检查
            const contentLength = response.headers.get('Content-Length');
            if (contentLength && allData.size !== totalSize) {
                console.warn(`文件大小不匹配: 实际 ${allData.size}, 预期 ${totalSize}`);
                // 不抛出错误，而是记录警告并继续
            }

            console.log(`文件 ${downloadId} 下载成功。`);
            return allData;

        } catch (error) {
            // 这可能是一个真正的错误，也可能是一个中止操作。
            if (error.name === 'AbortError') {
                console.log(`文件 ${downloadId} 的下载被中止。正在保存进度。`);
            } else {
                console.log(`文件 ${downloadId} 的下载出错: ${error.message}。正在保存进度。`);
            }
            
            const partialData = new Blob(existingData.concat(receivedChunks));
            let newStartByte = startByte; // 默认为旧的起始字节

            if (partialData.size > startByte) {
                await this._cacheFile(downloadId, partialData, totalSize);
                console.log(`已为 ${downloadId} 保存 ${partialData.size} 字节用于断点续传。`);
                newStartByte = partialData.size; // 更新起始字节为当前已下载的大小
            }
            
            // 如果是网络错误，尝试重试
            if (error.name !== 'AbortError' && retryAttempt < 3) {
                console.log(`尝试重试下载 ${downloadId}，第 ${retryAttempt + 1} 次重试，从字节 ${newStartByte} 开始...`);
                // [修复] 使用更新后的 newStartByte 和 totalSize (即 knownTotalSize) 进行重试
                return this.startOrResumeDownload(downloadId, url, newStartByte, totalSize, retryAttempt + 1);
            }
            
            throw error; // 重新抛出错误，以便调用者知道它失败了或被中止了。
        } finally {
            this.controllers.delete(downloadId);
        }
    }

    abort(downloadId) {
        console.log(`正在中止下载: ${downloadId}`);
        
        if (this.controllers.has(downloadId)) {
            const controller = this.controllers.get(downloadId);
            try {
                controller.abort();
                console.log(`下载控制器已中止: ${downloadId}`);
            } catch (error) {
                console.warn(`中止下载控制器时出错: ${error.message}`);
            }
            this.controllers.delete(downloadId);
        }
        
        // 清理正在进行的下载Promise
        if (this.inflight.has(downloadId)) {
            this.inflight.delete(downloadId);
            console.log(`已清理正在进行的下载: ${downloadId}`);
        }
        
        console.log(`下载中止完成: ${downloadId}`);
    }

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
        this.inflight.clear();
        console.log('所有下载已中止，缓存已清理');
    }
}

// 暴露给 Service Worker 使用
self.DownloadManager = DownloadManager;
