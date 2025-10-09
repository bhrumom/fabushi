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
      
      // 确保加载动画立即显示
      this.ensureLoadingVisible();
    },

    ensureLoadingVisible: function() {
      // 确保加载容器存在并可见
      let loadingContainer = document.getElementById('loading-container');
      if (!loadingContainer) {
        // 如果不存在，创建基本的加载容器
        const loadingHtml = `
          <div id="loading-container" class="loading-container">
            <div class="loading-content">
              <div class="loading-spinner"></div>
              <div class="loading-text">全球法布施</div>
              <div class="loading-subtext">正在加载应用...</div>
              <div class="loading-progress">
                <div class="loading-progress-bar"></div>
              </div>
            </div>
          </div>
        `;
        document.body.insertAdjacentHTML('afterbegin', loadingHtml);
        loadingContainer = document.getElementById('loading-container');
      }
      
      // 确保应用容器存在
      let appContainer = document.getElementById('app-container');
      if (!appContainer) {
        appContainer = document.createElement('div');
        appContainer.id = 'app-container';
        appContainer.className = 'app-container';
        document.body.appendChild(appContainer);
      }
      
      console.log('✅ 确保加载动画和应用容器已准备就绪');
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
      // 超时保护 - 15秒后强制隐藏
      setTimeout(() => {
        if (!this.isFlutterLoaded) {
          console.warn('⏰ 加载超时保护触发（15秒）');
          this.updateLoadingText('加载超时，请检查网络连接');
          setTimeout(() => {
            this.hideLoadingScreen();
          }, 1000);
        }
      }, this.maxLoadingTime);

      // 智能渐进式隐藏策略
      setTimeout(() => {
        if (!this.isFlutterLoaded) {
          console.log('🔄 智能渐进式显示触发（8秒）');
          // 检查是否有可能正在加载
          const currentProgress = this.getCurrentProgress();
          if (currentProgress < 50) {
            // 如果进度很低，可能是网络问题，显示提示
            this.updateLoadingText('网络较慢，请耐心等待...');
          }
        }
      }, 8000);
      
      // 中期检查 - 4秒时
      setTimeout(() => {
        if (!this.isFlutterLoaded) {
          console.log('📊 中期检查（4秒）');
          const currentProgress = this.getCurrentProgress();
          if (currentProgress < 20) {
            this.updateLoadingText('正在连接服务器...');
          } else if (currentProgress < 40) {
            this.updateLoadingText('正在加载资源...');
          }
        }
      }, 4000);
    },

    getCurrentProgress: function() {
      const progressBar = document.querySelector('.loading-progress-bar');
      if (!progressBar) return 0;
      const width = progressBar.style.width;
      return parseInt(width) || 0;
    },

    updateLoadingProgress: function() {
      const progressBar = document.querySelector('.loading-progress-bar');
      if (!progressBar) return;

      let progress = 0;
      let lastUpdate = Date.now();
      
      const interval = setInterval(() => {
        if (this.isFlutterLoaded) {
          progress = 100;
          progressBar.style.width = progress + '%';
          clearInterval(interval);
          return;
        }

        // 模拟加载进度，更加平滑
        const now = Date.now();
        const elapsed = now - lastUpdate;
        
        if (progress < 85) {
          // 前期快速加载
          const increment = Math.random() * 2 + 1.5;
          progress += increment * (elapsed / 200);
          progressBar.style.width = Math.min(progress, 85) + '%';
        } else if (progress < 95) {
          // 后期缓慢加载
          const increment = Math.random() * 0.5 + 0.3;
          progress += increment * (elapsed / 200);
          progressBar.style.width = Math.min(progress, 95) + '%';
        }
        
        lastUpdate = now;
      }, 100); // 提高更新频率，使动画更流畅
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
      
      // 首先显示应用容器（让Flutter内容可以渲染）
      if (appContainer) {
        appContainer.classList.add('show');
        // 触发重排，确保过渡效果
        appContainer.offsetHeight;
      }
      
      // 然后淡出加载容器
      if (loadingContainer) {
        loadingContainer.classList.add('fade-out');
      }
      
      // 动画完成后移除加载容器
      setTimeout(() => {
        if (loadingContainer) {
          loadingContainer.style.display = 'none';
        }
        // 恢复默认背景色
        document.body.style.background = '';
        document.body.style.overflow = '';
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