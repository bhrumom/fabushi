'use strict';

const { defineEdge } = require('./edge-ipc.cjs');

const methods = {
  openExternal: { args: 'object' },
  getDesktopEnvironment: { args: 'none' },
  getWindowState: { args: 'none' },
  minimizeWindow: { args: 'none' },
  toggleMaximizeWindow: { args: 'none' },
  closeWindow: { args: 'none' },
  resizeWindowWidth: { args: 'object' },
  getThemeState: { args: 'none' },
  setThemePreference: { args: 'object' },
  relaunchDesktop: { args: 'none' },
  getOnboardingSeen: { args: 'none' },
  setOnboardingSeen: { args: 'object' },
  getTimeZone: { args: 'none' },
  setTimeZoneOverride: { args: 'object' },
  getSidebarCollapsed: { args: 'none' },
  setSidebarCollapsed: { args: 'object' },
  readClientPersistence: { args: 'object' },
  writeClientPersistence: { args: 'object' },
  removeClientPersistence: { args: 'object' },
  listClientPersistenceKeys: { args: 'object' },
  requestDiskSaverAudit: { args: 'none' },
};

const NATIVE_EDGE = defineEdge('native-desktop', methods, [
  'window-state',
  'theme-changed',
]);

module.exports = { NATIVE_EDGE };
