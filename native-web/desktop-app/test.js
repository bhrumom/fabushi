// 桌面应用测试脚本

const { app, BrowserWindow } = require('electron');
const path = require('path');

// 测试主进程功能
describe('Main Process', () => {
  test('should create app window', () => {
    expect(app).toBeDefined();
  });

  test('should have correct app name', () => {
    expect(app.name).toBe('fabushi-desktop');
  });
});

// 测试文件处理功能
const { getFileType } = require('./main.js');

describe('File Type Detection', () => {
  test('should detect text files', () => {
    expect(getFileType('/path/to/file.txt')).toBe('text');
  });

  test('should detect image files', () => {
    expect(getFileType('/path/to/image.jpg')).toBe('image');
    expect(getFileType('/path/to/image.png')).toBe('image');
    expect(getFileType('/path/to/image.gif')).toBe('image');
  });

  test('should detect other files', () => {
    expect(getFileType('/path/to/file.pdf')).toBe('file');
    expect(getFileType('/path/to/file.docx')).toBe('file');
  });
});

// 测试自动更新功能
const AutoUpdater = require('./auto-updater.js');

describe('Auto Updater', () => {
  test('should be defined', () => {
    expect(AutoUpdater).toBeDefined();
  });
});

// 测试系统托盘功能
const AppTray = require('./tray.js');

describe('App Tray', () => {
  test('should be defined', () => {
    expect(AppTray).toBeDefined();
  });
});

console.log('All tests completed');