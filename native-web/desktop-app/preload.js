const { contextBridge, ipcRenderer } = require('electron');

// 暴露安全的API给渲染进程
contextBridge.exposeInMainWorld('electronAPI', {
  // 文件操作
  selectFiles: () => ipcRenderer.invoke('select-files'),
  
  // 配置操作
  saveConfig: (config) => ipcRenderer.invoke('save-config', config),
  loadConfig: () => ipcRenderer.invoke('load-config'),
  
  // 外部链接
  openExternal: (url) => ipcRenderer.invoke('open-external', url),
  
  // 应用信息
  getAppVersion: () => ipcRenderer.invoke('get-app-version'),
  
  // 更新操作
  checkForUpdates: () => ipcRenderer.invoke('check-for-updates'),
  
  // 监听主进程事件
  on: (channel, func) => {
    const validChannels = ['update-progress', 'send-log', 'update-message'];
    if (validChannels.includes(channel)) {
      // 从渲染器到主进程的事件监听器
      ipcRenderer.on(channel, (event, ...args) => func(...args));
    }
  },
  
  // 移除事件监听器
  removeListener: (channel, func) => {
    const validChannels = ['update-progress', 'send-log', 'update-message'];
    if (validChannels.includes(channel)) {
      ipcRenderer.removeListener(channel, func);
    }
  }
});