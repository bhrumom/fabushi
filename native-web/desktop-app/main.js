const { app, BrowserWindow, ipcMain, dialog, shell, Tray, Menu } = require('electron');
const path = require('path');
const fs = require('fs');
const AppTray = require('./tray.js');
const AutoUpdater = require('./auto-updater.js');

// 检查是否在开发环境中
const isDev = require('electron-is-dev');

// 获取应用数据目录
const appDataPath = app.getPath('userData');
const configPath = path.join(appDataPath, 'config.json');

let mainWindow;
let appTray = null;
let autoUpdater = null;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    minWidth: 800,
    minHeight: 600,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js'),
      webSecurity: !isDev, // 仅在开发环境中禁用，生产环境中应启用
    },
    icon: path.join(__dirname, 'assets/icon.png'), // 如果有图标文件的话
  });

  // 加载应用
  if (isDev) {
    mainWindow.loadFile('app.html'); // 开发环境直接加载本地文件
    mainWindow.webContents.openDevTools(); // 打开开发者工具
  } else {
    mainWindow.loadFile('app.html'); // 生产环境也加载本地文件
  }

  // 处理窗口关闭事件
  mainWindow.on('closed', () => {
    mainWindow = null;
  });

  // 在 macOS 上，最小化到dock而不是完全关闭
  mainWindow.on('close', (event) => {
    if (process.platform === 'darwin' && !app.quitting) {
      event.preventDefault();
      mainWindow.hide();
    }
  });

  // 处理新窗口打开事件（如链接点击）
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url);
    return { action: 'deny' };
  });

  // 创建系统托盘
  appTray = new AppTray(mainWindow);
  
  // 初始化自动更新
  autoUpdater = new AutoUpdater(mainWindow);
  
  // 应用启动后检查更新
  setTimeout(() => {
    if (autoUpdater) {
      autoUpdater.checkForUpdates();
    }
  }, 5000);
}

// 应用准备就绪时创建窗口
app.whenReady().then(() => {
  createWindow();

  // 在 macOS 上，当点击 dock 图标且没有其他窗口打开时，通常会重新创建一个窗口
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

// 当所有窗口都关闭时退出应用
app.on('window-all-closed', () => {
  // 在 macOS 上，应用程序菜单栏通常会保持活动状态，直到用户明确退出
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

// 优雅退出
app.on('before-quit', () => {
  app.quitting = true;
});

// IPC 处理程序
// 处理文件选择请求
ipcMain.handle('select-files', async () => {
  const result = await dialog.showOpenDialog(mainWindow, {
    properties: ['openFile', 'multiSelections'],
    filters: [
      { name: 'Text Files', extensions: ['txt'] },
      { name: 'Images', extensions: ['jpg', 'jpeg', 'png', 'gif'] },
      { name: 'All Files', extensions: ['*'] }
    ]
  });

  if (result.canceled) {
    return { canceled: true };
  }

  // 读取文件内容
  const files = [];
  for (const filePath of result.filePaths) {
    try {
      const content = fs.readFileSync(filePath);
      const stats = fs.statSync(filePath);
      
      files.push({
        name: path.basename(filePath),
        path: filePath,
        size: stats.size,
        content: content.toString('base64'), // 转换为base64以便在前端处理
        type: getFileType(filePath)
      });
    } catch (error) {
      console.error('读取文件时出错:', error);
    }
  }

  return { canceled: false, files };
});

// 获取文件类型
function getFileType(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  if (['.jpg', '.jpeg', '.png', '.gif'].includes(ext)) {
    return 'image';
  } else if (ext === '.txt') {
    return 'text';
  } else {
    return 'file';
  }
}

// 处理保存配置请求
ipcMain.handle('save-config', async (event, config) => {
  try {
    fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
    return { success: true };
  } catch (error) {
    console.error('保存配置时出错:', error);
    return { success: false, error: error.message };
  }
});

// 处理读取配置请求
ipcMain.handle('load-config', async () => {
  try {
    if (fs.existsSync(configPath)) {
      const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
      return { success: true, config };
    } else {
      return { success: true, config: {} };
    }
  } catch (error) {
    console.error('读取配置时出错:', error);
    return { success: false, error: error.message };
  }
});

// 处理打开外部链接请求
ipcMain.handle('open-external', async (event, url) => {
  try {
    await shell.openExternal(url);
    return { success: true };
  } catch (error) {
    console.error('打开外部链接时出错:', error);
    return { success: false, error: error.message };
  }
});

// 处理获取应用版本请求
ipcMain.handle('get-app-version', async () => {
  return { version: app.getVersion() };
});

// 处理手动检查更新请求
ipcMain.handle('check-for-updates', async () => {
  if (autoUpdater) {
    autoUpdater.checkForUpdates();
    return { success: true };
  }
  return { success: false, error: '自动更新未初始化' };
});