// Web Worker for sending files using modern Fetch API
self.addEventListener('message', async (event) => {
    const { type, data } = event.data;
    
    switch (type) {
        case 'start-transfer':
            await handleStartTransfer(data);
            break;
        case 'cancel-transfer':
            handleCancelTransfer(data);
            break;
        default:
            console.warn('Unknown message type in worker:', type);
    }
});

let currentTransfers = new Map();

async function handleStartTransfer(data) {
    const { 
        transferId, 
        file, 
        countries, 
        countryServers, 
        countryNames,
        options = {} 
    } = data;
    
    const {
        concurrency = 3,
        retryAttempts = 3,
        onProgress = null
    } = options;
    
    try {
        // Initialize transfer tracking
        currentTransfers.set(transferId, {
            cancelled: false,
            progress: 0,
            total: countries.length,
            completed: 0,
            failed: 0
        });
        
        // Send start message
        self.postMessage({
            type: 'transfer-started',
            data: { transferId }
        });
        
        // Process countries in batches
        const batches = createBatches(countries, concurrency);
        let totalCompleted = 0;
        let totalFailed = 0;
        
        for (const batch of batches) {
            // Check if transfer was cancelled
            if (isTransferCancelled(transferId)) {
                break;
            }
            
            const batchPromises = batch.map(countryCode => 
                sendToCountry(transferId, file, countryCode, countryServers, countryNames, retryAttempts)
            );
            
            const results = await Promise.allSettled(batchPromises);
            
            // Count results
            results.forEach(result => {
                if (result.status === 'fulfilled') {
                    if (result.value.success) {
                        totalCompleted++;
                    } else {
                        totalFailed++;
                    }
                } else {
                    totalFailed++;
                }
            });
            
            // Update progress
            const transfer = currentTransfers.get(transferId);
            if (transfer) {
                transfer.completed = totalCompleted;
                transfer.failed = totalFailed;
                transfer.progress = ((totalCompleted + totalFailed) / countries.length) * 100;
                
                self.postMessage({
                    type: 'transfer-progress',
                    data: {
                        transferId,
                        progress: transfer.progress,
                        completed: totalCompleted,
                        failed: totalFailed,
                        total: countries.length
                    }
                });
            }
            
            // 发送更详细的进度更新到主程序
            self.postMessage({
                type: 'progress-update',
                data: {
                    transferId,
                    completedTasks: totalCompleted + totalFailed,
                    totalTasks: countries.length
                }
            });
        }
        
        // Transfer completed
        currentTransfers.delete(transferId);
        
        self.postMessage({
            type: 'transfer-completed',
            data: {
                transferId,
                success: totalFailed === 0,
                completed: totalCompleted,
                failed: totalFailed,
                total: countries.length
            }
        });
        
    } catch (error) {
        console.error('Transfer error:', error);
        
        currentTransfers.delete(transferId);
        
        self.postMessage({
            type: 'transfer-error',
            data: {
                transferId,
                error: error.message
            }
        });
    }
}

function handleCancelTransfer(data) {
    const { transferId } = data;
    const transfer = currentTransfers.get(transferId);
    
    if (transfer) {
        transfer.cancelled = true;
        self.postMessage({
            type: 'transfer-cancelled',
            data: { transferId }
        });
    }
}

function isTransferCancelled(transferId) {
    const transfer = currentTransfers.get(transferId);
    return transfer ? transfer.cancelled : false;
}

async function sendToCountry(transferId, file, countryCode, countryServers, countryNames, retryAttempts) {
    const servers = countryServers[countryCode] || [];
    if (servers.length === 0) {
        return { success: false, countryCode };
    }
    
    const countryName = countryNames[countryCode] || countryCode;
    const serverUrl = servers[0]; // Use first server
    
    // Notify that we're starting to send to this country
    self.postMessage({
        type: 'country-started',
        data: {
            transferId,
            countryCode,
            countryName
        }
    });
    
    // Try to send with retries
    for (let attempt = 0; attempt <= retryAttempts; attempt++) {
        try {
            // Check if transfer was cancelled
            if (isTransferCancelled(transferId)) {
                return { success: false, countryCode };
            }
            
            const formData = new FormData();
            formData.append('file', file, file.name);
            
            const response = await fetch(serverUrl, {
                method: 'POST',
                body: formData,
                mode: 'no-cors' // Use no-cors to avoid preflight requests
            });
            
            // For no-cors mode, we can't read the response, but if fetch didn't throw,
            // we assume it was successful
            self.postMessage({
                type: 'country-completed',
                data: {
                    transferId,
                    countryCode,
                    countryName,
                    success: true,
                    attempt: attempt + 1
                }
            });
            
            return { success: true, countryCode };
            
        } catch (error) {
            if (attempt === retryAttempts) {
                // Last attempt failed
                self.postMessage({
                    type: 'country-completed',
                    data: {
                        transferId,
                        countryCode,
                        countryName,
                        success: false,
                        attempt: attempt + 1,
                        error: error.message
                    }
                });
                
                return { success: false, countryCode };
            }
            
            // Wait before retrying
            await new Promise(resolve => setTimeout(resolve, Math.pow(2, attempt) * 1000));
        }
    }
}

function createBatches(items, batchSize) {
    const batches = [];
    for (let i = 0; i < items.length; i += batchSize) {
        batches.push(items.slice(i, i + batchSize));
    }
    return batches;
}

// Error handling
self.addEventListener('error', (error) => {
    console.error('Worker error:', error);
});

self.addEventListener('unhandledrejection', (event) => {
    console.error('Unhandled promise rejection in worker:', event.reason);
});