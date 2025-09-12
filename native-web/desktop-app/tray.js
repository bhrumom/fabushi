const { Tray, Menu, app, shell } = require('electron');
const path = require('path');

class AppTray {
  constructor(mainWindow) {
    this.mainWindow = mainWindow;
    this.tray = null;
    this.createTray();
  }

  createTray() {
    // 创建系统托盘图标
    // 注意：在实际应用中，您需要提供一个真实的图标文件
    const iconPath = path.join(__dirname, 'assets/tray-icon.png');
    
    try {
      this.tray = new Tray(iconPath);
      this.tray.setToolTip('全球法布施');
      
      // 创建上下文菜单
      const contextMenu = Menu.buildFromTemplate([
        {
          label: '显示应用',
          click: () => {
            this.mainWindow.show();
          }
        },
        {
          label: '最小化到托盘',
          click: () => {
            this.mainWindow.hide();
          }
        },
        { type: 'separator' },
        {
          label: '官方网站',
          click: () => {
            shell.openExternal('https://your-website.com');
          }
        },
        { type: 'separator' },
        {
          label: '退出',
          click: () => {
            app.quit();
          }
        }
      ]);
      
      this.tray.setContextMenu(contextMenu);
      
      // 点击托盘图标时显示/隐藏应用
      this.tray.on('click', () => {
        if (this.mainWindow.isVisible()) {
          this.mainWindow.hide();
        } else {
          this.mainWindow.show();
        }
      });
    } catch (error) {
      console.error('创建系统托盘时出错:', error);
    }
  }

  destroy() {
    if (this.tray) {
      this.tray.destroy();
    }
  }
}

module.exports = AppTray;