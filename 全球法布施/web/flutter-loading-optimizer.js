/**
 * Flutter Web 加载优化器 - 简化版
 * 用于管理加载动画和Flutter应用初始化的协调
 */

(function() {
  'use strict';

  // 加载状态管理
  const LoadingManager = {
    isFlutterLoaded: false,
    isPageLoaded: false,
    loadingStartTime: Date.now(),
    maxLoadingTime: 15000, // 最大加载时间15秒
    isHiding: false,

    init: function() {
      this.setupEventListeners();
      this.startTimeoutProtection();
      this.updateLoadingProgress();
    },

    setupEventListeners: function() {
      // 监听Flutter第一帧渲染完成
      window.addEventListener('flutter-first-frame', () => {
        console.log('🎯 Flutter第一帧渲染完成');
        this.onFlutterLoaded();
      });

      // 监听页面加载完成
      window.addEventListener('load', () => {
        console.log('📄 页面资源加载完成');
        this.isPageLoaded = true;
        this.checkLoadingComplete();
      });

      // 监听Flutter初始化错误
      window.addEventListener('error', (e) => {
        console.error('❌ 加载错误:', e);
        this.handleLoadingError();
      });
    },

    startTimeoutProtection: function() {
      // 超时保护
      setTimeout(() => {
        if (!this.isFlutterLoaded) {
          console.warn('⏰ 加载超时保护触发');
          this.hideLoadingScreen();
        }
      }, this.maxLoadingTime);

      // 渐进式隐藏策略
      setTimeout(() => {
        if (!this.isFlutterLoaded) {
          console.log('🔄 尝试渐进式显示');
          this.hideLoadingScreen();
        }
      }, 8000); // 8秒后尝试显示
    },

    updateLoadingProgress: function() {
      const progressBar = document.querySelector('.loading-progress-bar');
      if (!progressBar) return;

      let progress = 0;
      const interval = setInterval(() => {
        if (this.isFlutterLoaded) {
          progress = 100;
          progressBar.style.width = progress + '%';
          clearInterval(interval);
          return;
        }

        // 模拟加载进度
        if (progress < 90) {
          progress += Math.random() * 3 + 1;
          progressBar.style.width = Math.min(progress, 90) + '%';
        }
      }, 200);
    },

    onFlutterLoaded: function() {
      this.isFlutterLoaded = true;
      console.log('✅ Flutter应用加载完成');
      this.hideLoadingScreen();
      this.updateLoadingText('应用加载完成！');
    },

    checkLoadingComplete: function() {
      if (this.isFlutterLoaded && this.isPageLoaded) {
        console.log('✅ 所有资源加载完成');
        this.hideLoadingScreen();
      }
    },

    handleLoadingError: function() {
      console.error('💥 加载过程中出现错误');
      this.updateLoadingText('加载出错，请刷新页面重试');
      setTimeout(() => {
        this.hideLoadingScreen();
      }, 2000);
    },

    updateLoadingText: function(text) {
      const loadingText = document.querySelector('.loading-subtext');
      if (loadingText) {
        loadingText.textContent = text;
      }
    },

    hideLoadingScreen: function() {
      const loadingContainer = document.getElementById('loading-container');
      const appContainer = document.getElementById('app-container');
      
      if (!loadingContainer || this.isHiding) return;
      
      this.isHiding = true;
      console.log('🎬 开始隐藏加载动画');
      
      if (loadingContainer) {
        loadingContainer.classList.add('fade-out');
      }
      
      if (appContainer) {
        appContainer.classList.add('show');
      }
      
      // 动画完成后移除加载容器
      setTimeout(() => {
        if (loadingContainer) {
          loadingContainer.style.display = 'none';
        }
        document.body.style.background = '#f5f5f5';
        console.log('🎉 加载动画隐藏完成');
      }, 500);
    }
  };

  // 性能监控
  const PerformanceMonitor = {
    init: function() {
      this.measureLoadingTime();
    },

    measureLoadingTime: function() {
      const startTime = performance.now();
      
      window.addEventListener('flutter-first-frame', () => {
        const loadTime = performance.now() - startTime;
        console.log(`⏱️ Flutter应用加载耗时: ${loadTime.toFixed(2)}ms`);
        
        // 根据加载时间给出建议
        if (loadTime > 5000) {
          console.warn('⚠️ 加载时间较长，建议优化资源大小');
        } else if (loadTime < 2000) {
          console.log('🚀 加载速度很快！');
        }
      });
    }
  };

  // 初始化
  document.addEventListener('DOMContentLoaded', function() {
    console.log('🚀 Flutter Web加载优化器启动');
    LoadingManager.init();
    PerformanceMonitor.init();
  });

  // 暴露全局接口
  window.FlutterLoadingOptimizer = {
    hideLoading: function() {
      LoadingManager.hideLoadingScreen();
    },
    updateText: function(text) {
      LoadingManager.updateLoadingText(text);
    }
  };

})();