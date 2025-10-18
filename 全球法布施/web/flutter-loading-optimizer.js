// Flutter Web 版本检测和自动缓存更新
(function() {
  'use strict';
  
  const APP_VERSION_KEY = 'app_version';
  const BUILD_VERSION = '__BUILD_VERSION__'; // 占位符，构建时替换
  
  // 检查版本并清除缓存
  async function checkVersionAndClearCache() {
    try {
      const storedVersion = localStorage.getItem(APP_VERSION_KEY);
      
      if (storedVersion !== BUILD_VERSION) {
        console.log('🔄 检测到新版本，清除缓存...');
        console.log(`旧版本: ${storedVersion}, 新版本: ${BUILD_VERSION}`);
        
        // 1. 清除 Service Worker 缓存
        if ('serviceWorker' in navigator) {
          const registrations = await navigator.serviceWorker.getRegistrations();
          for (const registration of registrations) {
            await registration.unregister();
            console.log('✅ Service Worker 已注销');
          }
        }
        
        // 2. 清除 Cache Storage
        if ('caches' in window) {
          const cacheNames = await caches.keys();
          for (const cacheName of cacheNames) {
            await caches.delete(cacheName);
            console.log(`✅ 缓存已删除: ${cacheName}`);
          }
        }
        
        // 3. 更新版本号
        localStorage.setItem(APP_VERSION_KEY, BUILD_VERSION);
        
        // 4. 强制刷新页面（跳过缓存）
        console.log('🔄 强制刷新页面...');
        window.location.reload(true);
      } else {
        console.log('✅ 版本一致，无需清除缓存');
      }
    } catch (error) {
      console.error('❌ 版本检查失败:', error);
    }
  }
  
  // 立即执行版本检查
  checkVersionAndClearCache();
  
  // 确保页面完全加载后也检查一次
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', hideLoadingAnimation);
  }
  
  // 隐藏加载动画
  function hideLoadingAnimation() {
    const loadingContainer = document.getElementById('loading-container');
    if (loadingContainer) {
      loadingContainer.classList.add('fade-out');
      setTimeout(() => {
        loadingContainer.style.display = 'none';
      }, 500);
    }
  }
  
  // 监听 Flutter 首帧渲染事件
  window.addEventListener('flutter-first-frame', function() {
    console.log('🎨 Flutter首帧已渲染，隐藏加载动画');
    hideLoadingAnimation();
  });
  
  // 备用：3秒后强制隐藏加载动画
  setTimeout(() => {
    console.log('⏰ 超时保护：强制隐藏加载动画');
    hideLoadingAnimation();
  }, 3000);
  
  // 导出加载管理器
  window.LoadingManager = {
    init: function() {
      console.log('📦 加载管理器已初始化');
    },
    hideLoading: hideLoadingAnimation
  };
})();
