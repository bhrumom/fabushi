const { autoUpdater } = require('electron-updater');
const { app, dialog } = require('electron');

class AutoUpdater {
  constructor(mainWindow) {
    this.mainWindow = mainWindow;
    this.init();
  }

  init() {
    // 设置更新服务器URL（在实际应用中，您需要配置这个）
    // autoUpdater.setFeedURL('https://your-update-server.com');

    // 监听更新事件
    autoUpdater.on('checking-for-update', () => {
      this.sendStatusToWindow('正在检查更新...');
    });

    autoUpdater.on('update-available', (info) => {
      this.sendStatusToWindow('发现新版本，正在下载...');
    });

    autoUpdater.on('update-not-available', (info) => {
      this.sendStatusToWindow('当前已是最新版本');
    });

    autoUpdater.on('error', (err) => {
      this.sendStatusToWindow('更新出错: ' + err);
    });

    autoUpdater.on('download-progress', (progressObj) => {
      let log_message = "下载速度: " + progressObj.bytesPerSecond;
      log_message = log_message + ' - 已下载 ' + Math.round(progressObj.percent) + '%';
      log_message = log_message + ' (' + progressObj.transferred + "/" + progressObj.total + ')';
      this.sendStatusToWindow(log_message);
    });

    autoUpdater.on('update-downloaded', (info) => {
      this.sendStatusToWindow('更新下载完成');
      
      // 询问用户是否立即重启应用以应用更新
      dialog.showMessageBox({
        type: 'info',
        title: '更新已就绪',
        message: '新版本已下载完成，是否立即重启应用以应用更新？',
        buttons: ['立即重启', '稍后重启']
      }).then((result) => {
        if (result.response === 0) {
          autoUpdater.quitAndInstall();
        }
      });
    });
  }

  checkForUpdates() {
    // 在开发环境中禁用自动更新
    if (process.env.NODE_ENV === 'development') {
      this.sendStatusToWindow('开发环境中禁用自动更新');
      return;
    }

    autoUpdater.checkForUpdates();
  }

  sendStatusToWindow(text) {
    if (this.mainWindow) {
      this.mainWindow.webContents.send('update-message', text);
    }
  }
}

module.exports = AutoUpdater;