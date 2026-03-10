/**
 * 提瓦特小助手 - 网页版交互逻辑
 */

document.addEventListener('DOMContentLoaded', () => {
  initBannerCarousel();
  initBottomNav();
  initFeatureCards();
  initQuickAccess();
  initStatsCounter();
  initSubPage();
});

/* ========== Banner 轮播 ========== */
function initBannerCarousel() {
  const slides = document.querySelectorAll('.banner-slide');
  const dots = document.querySelectorAll('.dot');
  let current = 0;
  let timer = null;

  function goTo(index) {
    slides[current].classList.remove('active');
    dots[current].classList.remove('active');
    current = index;
    slides[current].classList.add('active');
    dots[current].classList.add('active');
  }

  function next() {
    goTo((current + 1) % slides.length);
  }

  function startAuto() {
    timer = setInterval(next, 4000);
  }

  function stopAuto() {
    clearInterval(timer);
  }

  dots.forEach(dot => {
    dot.addEventListener('click', () => {
      stopAuto();
      goTo(parseInt(dot.dataset.index));
      startAuto();
    });
  });

  // Swipe support
  const carousel = document.getElementById('bannerCarousel');
  let startX = 0;
  let startY = 0;

  carousel.addEventListener('touchstart', e => {
    startX = e.touches[0].clientX;
    startY = e.touches[0].clientY;
    stopAuto();
  }, { passive: true });

  carousel.addEventListener('touchend', e => {
    const dx = e.changedTouches[0].clientX - startX;
    const dy = e.changedTouches[0].clientY - startY;
    if (Math.abs(dx) > Math.abs(dy) && Math.abs(dx) > 40) {
      if (dx < 0) next();
      else goTo((current - 1 + slides.length) % slides.length);
    }
    startAuto();
  }, { passive: true });

  startAuto();
}

/* ========== 底部导航 ========== */
function initBottomNav() {
  const navItems = document.querySelectorAll('.nav-item');
  navItems.forEach(item => {
    item.addEventListener('click', e => {
      e.preventDefault();
      navItems.forEach(n => n.classList.remove('active'));
      item.classList.add('active');

      const tab = item.dataset.tab;
      if (tab === 'tools') {
        showToast('更多工具正在开发中...');
      } else if (tab === 'wiki') {
        showToast('图鉴功能即将上线');
      } else if (tab === 'profile') {
        showToast('个人中心即将上线');
      }
    });
  });
}

/* ========== 功能卡片点击 ========== */
function initFeatureCards() {
  const cards = document.querySelectorAll('.feature-card');
  cards.forEach(card => {
    card.addEventListener('click', () => {
      const page = card.dataset.page;
      openSubPage(page);
    });
  });
}

/* ========== 快捷功能点击 ========== */
function initQuickAccess() {
  const items = document.querySelectorAll('.quick-item');
  items.forEach(item => {
    item.addEventListener('click', e => {
      e.preventDefault();
      const page = item.dataset.page;
      openSubPage(page);
    });
  });
}

/* ========== 数据统计动画 ========== */
function initStatsCounter() {
  const observer = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        const el = entry.target;
        const target = parseInt(el.dataset.target);
        animateNumber(el, target);
        observer.unobserve(el);
      }
    });
  }, { threshold: 0.5 });

  document.querySelectorAll('.stat-value').forEach(el => observer.observe(el));
}

function animateNumber(el, target) {
  const duration = 1500;
  const start = performance.now();

  function update(now) {
    const elapsed = now - start;
    const progress = Math.min(elapsed / duration, 1);
    const eased = 1 - Math.pow(1 - progress, 3);
    const current = Math.floor(eased * target);
    el.textContent = formatNumber(current);
    if (progress < 1) requestAnimationFrame(update);
  }

  requestAnimationFrame(update);
}

function formatNumber(num) {
  if (num >= 1000000) return (num / 10000).toFixed(0) + '万+';
  if (num >= 10000) return (num / 10000).toFixed(1) + '万';
  return num.toLocaleString();
}

/* ========== 子页面系统 ========== */
function initSubPage() {
  const overlay = document.getElementById('pageOverlay');
  const backBtn = document.getElementById('backBtn');

  backBtn.addEventListener('click', closeSubPage);
  overlay.addEventListener('click', e => {
    if (e.target === overlay) closeSubPage();
  });

  // ESC key
  document.addEventListener('keydown', e => {
    if (e.key === 'Escape') closeSubPage();
  });
}

function openSubPage(pageName) {
  const overlay = document.getElementById('pageOverlay');
  const title = document.getElementById('subPageTitle');
  const body = document.getElementById('subPageBody');

  const pageConfig = getPageConfig(pageName);
  title.textContent = pageConfig.title;
  body.innerHTML = pageConfig.html;

  overlay.classList.add('active');
  document.body.style.overflow = 'hidden';

  // Init page specific logic
  if (pageConfig.init) pageConfig.init();
}

function closeSubPage() {
  const overlay = document.getElementById('pageOverlay');
  overlay.classList.remove('active');
  document.body.style.overflow = '';
}

/* ========== 各子页面内容 ========== */
function getPageConfig(pageName) {
  const pages = {
    'gacha-analysis': {
      title: '抽卡分析',
      html: `
        <div style="text-align:center; padding:40px 0;">
          <div style="font-size:3rem; margin-bottom:16px;">📊</div>
          <h3 style="margin-bottom:8px;">导入你的抽卡记录</h3>
          <p style="color:var(--text-secondary); font-size:0.85rem; margin-bottom:24px; line-height:1.7;">
            支持通过链接导入抽卡记录<br>数据将自动同步到云端永久保存
          </p>
          <div style="max-width:320px; margin:0 auto;">
            <input type="text" placeholder="请粘贴抽卡记录链接..." style="
              width:100%;
              padding:12px 16px;
              background:var(--bg-card);
              border:1px solid var(--border-color);
              border-radius:var(--radius-md);
              color:var(--text-primary);
              font-size:0.9rem;
              outline:none;
              margin-bottom:12px;
              font-family:inherit;
            " />
            <button onclick="showToast('正在解析抽卡记录...')" style="
              width:100%;
              padding:12px;
              background:linear-gradient(135deg, var(--accent-blue), var(--accent-purple));
              border:none;
              border-radius:var(--radius-md);
              color:white;
              font-size:0.95rem;
              font-weight:600;
              cursor:pointer;
              font-family:inherit;
            ">开始分析</button>
          </div>
          <div style="margin-top:32px; text-align:left;">
            <h4 style="font-size:0.9rem; margin-bottom:16px; color:var(--text-secondary);">📈 抽卡统计（演示数据）</h4>
            <div style="background:var(--bg-card); border-radius:var(--radius-md); padding:16px; border:1px solid var(--border-color);">
              <div class="gacha-stat-row"><span>总抽数</span><span style="color:var(--accent-blue);">632</span></div>
              <div class="gacha-stat-row"><span>5星数量</span><span style="color:#fbbf24;">8</span></div>
              <div class="gacha-stat-row"><span>4星数量</span><span style="color:#8b5cf6;">67</span></div>
              <div class="gacha-stat-row"><span>5星平均抽数</span><span style="color:var(--accent-orange);">79.0</span></div>
              <div class="gacha-stat-row"><span>欧非指数</span><span style="color:var(--accent-green);">😎 小欧</span></div>
            </div>
          </div>
        </div>
      `
    },

    'gacha-simulator': {
      title: '抽卡模拟器',
      html: `
        <div class="gacha-sim">
          <div class="gacha-pool-info">
            <h3>✦ 兹白 · 限定池</h3>
            <p class="pool-chars">UP: 兹白 / 常驻·风系5星</p>
            <div style="margin-top:16px;">
              <div class="gacha-pity-text"><span>当前保底</span><span id="pityCount">0 / 90</span></div>
              <div class="gacha-pity-bar"><div class="gacha-pity-fill" id="pityBar" style="width:0%"></div></div>
            </div>
          </div>
          <div class="gacha-buttons">
            <button class="gacha-btn gacha-btn-1" onclick="doGacha(1)">抽1次</button>
            <button class="gacha-btn gacha-btn-10" onclick="doGacha(10)">抽10次</button>
          </div>
          <div id="gachaResults" class="gacha-results"></div>
          <div class="gacha-history" id="gachaHistory" style="display:none;">
            <h4>📊 模拟统计</h4>
            <div class="gacha-stat-row"><span>总抽数</span><span id="totalPulls">0</span></div>
            <div class="gacha-stat-row"><span>⭐⭐⭐⭐⭐</span><span id="star5Count">0</span></div>
            <div class="gacha-stat-row"><span>⭐⭐⭐⭐</span><span id="star4Count">0</span></div>
            <div class="gacha-stat-row"><span>⭐⭐⭐</span><span id="star3Count">0</span></div>
          </div>
        </div>
      `,
      init: initGachaSimulator
    },

    'abyss-battle': {
      title: '幽境危战',
      html: buildAbyssPage()
    },

    'abyss-rank': {
      title: '深渊排行',
      html: buildAbyssRankPage()
    },

    'character-eval': {
      title: '角色综合测评',
      html: buildCharacterEvalPage()
    },

    'team-damage': {
      title: '队伍伤害计算',
      html: buildTeamDamagePage(),
      init: initTeamDamage
    },

    'artifact-score': {
      title: '圣遗物评分',
      html: `
        <div style="text-align:center; padding:40px 0;">
          <div style="font-size:3rem; margin-bottom:16px;">⭐</div>
          <h3 style="margin-bottom:8px;">圣遗物智能评分</h3>
          <p style="color:var(--text-secondary); font-size:0.85rem; line-height:1.7;">
            评估你的圣遗物品质<br>基于角色最优词条权重计算
          </p>
          <div style="margin-top:24px; background:var(--bg-card); border-radius:var(--radius-lg); padding:24px; border:1px solid var(--border-color);">
            <p style="color:var(--text-muted); font-size:0.85rem;">🔧 功能开发中，敬请期待...</p>
          </div>
        </div>
      `
    },

    'build-calc': {
      title: '养成计算器',
      html: `
        <div style="text-align:center; padding:40px 0;">
          <div style="font-size:3rem; margin-bottom:16px;">📋</div>
          <h3 style="margin-bottom:8px;">养成计算器</h3>
          <p style="color:var(--text-secondary); font-size:0.85rem; line-height:1.7;">
            规划角色培养材料需求<br>高效利用每一点体力
          </p>
          <div style="margin-top:24px; background:var(--bg-card); border-radius:var(--radius-lg); padding:24px; border:1px solid var(--border-color);">
            <p style="color:var(--text-muted); font-size:0.85rem;">🔧 功能开发中，敬请期待...</p>
          </div>
        </div>
      `
    }
  };

  return pages[pageName] || { title: '未知页面', html: '<p>页面不存在</p>' };
}

/* ========== 抽卡模拟器逻辑 ========== */
let gachaState = { total: 0, pity: 0, star5: 0, star4: 0, star3: 0, pity4: 0 };

function initGachaSimulator() {
  gachaState = { total: 0, pity: 0, star5: 0, star4: 0, star3: 0, pity4: 0 };
}

function doGacha(count) {
  const results = [];
  const chars5 = ['🗡️', '🏹', '⚔️', '🔮', '📖', '🎯', '🛡️', '🔱'];
  const chars4 = ['⚡', '🔥', '❄️', '🌊', '🌪️', '🪨', '🌿', '☀️'];
  const chars3 = ['🗡️', '🏹', '⚔️', '🔮'];

  for (let i = 0; i < count; i++) {
    gachaState.total++;
    gachaState.pity++;
    gachaState.pity4++;

    let star;
    const r = Math.random();

    // 5star: base 0.6%, soft pity from 74, guaranteed at 90
    if (gachaState.pity >= 90) {
      star = 5;
    } else if (gachaState.pity >= 74) {
      const softRate = 0.006 + (gachaState.pity - 73) * 0.06;
      star = r < softRate ? 5 : (gachaState.pity4 >= 10 || r < 0.057 ? 4 : 3);
    } else {
      star = r < 0.006 ? 5 : (gachaState.pity4 >= 10 || r < 0.057 ? 4 : 3);
    }

    if (star === 5) {
      gachaState.star5++;
      gachaState.pity = 0;
      results.push({ star: 5, char: chars5[Math.floor(Math.random() * chars5.length)] });
    } else if (star === 4) {
      gachaState.star4++;
      gachaState.pity4 = 0;
      results.push({ star: 4, char: chars4[Math.floor(Math.random() * chars4.length)] });
    } else {
      gachaState.star3++;
      results.push({ star: 3, char: chars3[Math.floor(Math.random() * chars3.length)] });
    }
  }

  renderGachaResults(results);
  updateGachaStats();
}

function renderGachaResults(results) {
  const container = document.getElementById('gachaResults');
  container.innerHTML = results.map((r, i) => `
    <div class="gacha-result-item star-${r.star}" style="animation-delay:${i * 0.08}s">
      ${r.char}
      <span class="star-label">${'★'.repeat(r.star)}</span>
    </div>
  `).join('');

  // Flash on 5star
  if (results.some(r => r.star === 5)) {
    showToast('🎉 恭喜抽到5星角色！');
  }
}

function updateGachaStats() {
  const pityEl = document.getElementById('pityCount');
  const barEl = document.getElementById('pityBar');
  const historyEl = document.getElementById('gachaHistory');

  if (pityEl) pityEl.textContent = `${gachaState.pity} / 90`;
  if (barEl) barEl.style.width = `${(gachaState.pity / 90) * 100}%`;

  if (historyEl) {
    historyEl.style.display = 'block';
    document.getElementById('totalPulls').textContent = gachaState.total;
    document.getElementById('star5Count').textContent = gachaState.star5;
    document.getElementById('star4Count').textContent = gachaState.star4;
    document.getElementById('star3Count').textContent = gachaState.star3;
  }
}

/* ========== 幽境危战页面 ========== */
function buildAbyssPage() {
  const floors = [
    { floor: '第12层', stars: '9/9', status: '已完成', color: 'var(--accent-green)' },
    { floor: '第11层', stars: '9/9', status: '已完成', color: 'var(--accent-green)' },
    { floor: '第10层', stars: '8/9', status: '已完成', color: 'var(--accent-orange)' },
    { floor: '第9层', stars: '9/9', status: '已完成', color: 'var(--accent-green)' },
  ];

  return `
    <div style="margin-bottom:20px; text-align:center;">
      <div style="font-size:2rem; margin-bottom:8px;">⚔️</div>
      <h3>6.3期 幽境危战</h3>
      <p style="color:var(--text-secondary); font-size:0.85rem;">2026.02.01 - 2026.02.28</p>
    </div>
    <div style="display:flex; flex-direction:column; gap:10px;">
      ${floors.map(f => `
        <div style="background:var(--bg-card); border-radius:var(--radius-md); padding:16px; border:1px solid var(--border-color); display:flex; justify-content:space-between; align-items:center;">
          <div>
            <div style="font-weight:600;">${f.floor}</div>
            <div style="font-size:0.8rem; color:var(--text-secondary); margin-top:2px;">⭐ ${f.stars}</div>
          </div>
          <span style="font-size:0.8rem; color:${f.color}; font-weight:500;">${f.status}</span>
        </div>
      `).join('')}
    </div>
    <div style="margin-top:24px;">
      <h4 style="font-size:0.9rem; color:var(--text-secondary); margin-bottom:12px;">💡 推荐阵容</h4>
      <div style="background:var(--bg-card); border-radius:var(--radius-md); padding:16px; border:1px solid var(--border-color);">
        <div style="display:flex; justify-content:space-around; font-size:1.6rem;">
          <span title="纳西妲">🌿</span><span title="雷电将军">⚡</span><span title="行秋">🌊</span><span title="钟离">🪨</span>
        </div>
        <p style="text-align:center; font-size:0.8rem; color:var(--text-secondary); margin-top:8px;">超绽放队 · 使用率 32.5%</p>
      </div>
    </div>
  `;
}

/* ========== 深渊排行页面 ========== */
function buildAbyssRankPage() {
  const rankings = [
    { rank: 1, name: '纳西妲', emoji: '🌿', rate: '78.5%', element: 'Dendro' },
    { rank: 2, name: '钟离', emoji: '🪨', rate: '72.3%', element: 'Geo' },
    { rank: 3, name: '雷电将军', emoji: '⚡', rate: '68.1%', element: 'Electro' },
    { rank: 4, name: '万叶', emoji: '🌪️', rate: '65.7%', element: 'Anemo' },
    { rank: 5, name: '夜兰', emoji: '🌊', rate: '61.2%', element: 'Hydro' },
    { rank: 6, name: '行秋', emoji: '💧', rate: '58.4%', element: 'Hydro' },
    { rank: 7, name: '班尼特', emoji: '🔥', rate: '55.8%', element: 'Pyro' },
    { rank: 8, name: '芙宁娜', emoji: '🌊', rate: '53.2%', element: 'Hydro' },
  ];

  const colors = {
    Dendro: '#34d399', Geo: '#fbbf24', Electro: '#a78bfa',
    Anemo: '#67e8f9', Hydro: '#60a5fa', Pyro: '#f87171'
  };

  return `
    <h4 style="font-size:0.9rem; color:var(--text-secondary); margin-bottom:16px;">📊 6.3期深渊角色使用率排行</h4>
    <div style="display:flex; flex-direction:column; gap:8px;">
      ${rankings.map(r => `
        <div style="background:var(--bg-card); border-radius:var(--radius-md); padding:14px 16px; border:1px solid var(--border-color); display:flex; align-items:center; gap:12px;">
          <span style="font-size:0.85rem; font-weight:700; color:${r.rank <= 3 ? '#fbbf24' : 'var(--text-muted)'}; width:24px; text-align:center;">${r.rank}</span>
          <span style="font-size:1.5rem;">${r.emoji}</span>
          <div style="flex:1;">
            <div style="font-weight:500; font-size:0.9rem;">${r.name}</div>
            <div style="height:4px; background:var(--bg-surface); border-radius:2px; margin-top:6px; overflow:hidden;">
              <div style="height:100%; width:${r.rate}; background:${colors[r.element]}; border-radius:2px;"></div>
            </div>
          </div>
          <span style="font-size:0.85rem; font-weight:600; color:${colors[r.element]};">${r.rate}</span>
        </div>
      `).join('')}
    </div>
  `;
}

/* ========== 角色测评页面 ========== */
function buildCharacterEvalPage() {
  const chars = [
    { name: '纳西妲', emoji: '🌿', score: 'T0', bg: 'linear-gradient(135deg, #065f46, #064e3b)' },
    { name: '雷电将军', emoji: '⚡', score: 'T0', bg: 'linear-gradient(135deg, #4c1d95, #3b0764)' },
    { name: '钟离', emoji: '🪨', score: 'T0', bg: 'linear-gradient(135deg, #78350f, #451a03)' },
    { name: '万叶', emoji: '🌪️', score: 'T0', bg: 'linear-gradient(135deg, #164e63, #083344)' },
    { name: '夜兰', emoji: '🌊', score: 'T0.5', bg: 'linear-gradient(135deg, #1e3a5f, #0c2340)' },
    { name: '行秋', emoji: '💧', score: 'T0.5', bg: 'linear-gradient(135deg, #1e3a5f, #0c2340)' },
    { name: '班尼特', emoji: '🔥', score: 'T0.5', bg: 'linear-gradient(135deg, #7f1d1d, #450a0a)' },
    { name: '芙宁娜', emoji: '🌊', score: 'T0', bg: 'linear-gradient(135deg, #1e3a5f, #0c2340)' },
    { name: '琴', emoji: '💚', score: 'T1', bg: 'linear-gradient(135deg, #164e63, #083344)' },
    { name: '迪卢克', emoji: '🔥', score: 'T1.5', bg: 'linear-gradient(135deg, #7f1d1d, #450a0a)' },
    { name: '甘雨', emoji: '❄️', score: 'T0.5', bg: 'linear-gradient(135deg, #164e63, #083344)' },
    { name: '胡桃', emoji: '🔥', score: 'T0', bg: 'linear-gradient(135deg, #7f1d1d, #450a0a)' },
  ];

  return `
    <h4 style="font-size:0.9rem; color:var(--text-secondary); margin-bottom:16px;">🏆 角色强度排行</h4>
    <div class="char-eval-grid">
      ${chars.map(c => `
        <div class="char-eval-item" onclick="showToast('${c.name}: ${c.score}级')">
          <div class="char-avatar" style="background:${c.bg}">${c.emoji}</div>
          <div class="char-name">${c.name}</div>
          <div class="char-score">${c.score}</div>
        </div>
      `).join('')}
    </div>
  `;
}

/* ========== 队伍伤害计算页面 ========== */
function buildTeamDamagePage() {
  return `
    <div class="team-builder">
      <h4 style="font-size:0.9rem; color:var(--text-secondary); margin-bottom:12px;">🎮 选择队伍角色</h4>
      <div class="team-slots">
        <div class="team-slot filled" data-slot="0">🌿</div>
        <div class="team-slot filled" data-slot="1">⚡</div>
        <div class="team-slot filled" data-slot="2">🌊</div>
        <div class="team-slot" data-slot="3">+</div>
      </div>
      <button onclick="calcTeamDamage()" style="
        width:100%;
        padding:12px;
        background:linear-gradient(135deg, var(--accent-orange), var(--accent-red));
        border:none;
        border-radius:var(--radius-md);
        color:white;
        font-size:0.95rem;
        font-weight:600;
        cursor:pointer;
        font-family:inherit;
        margin-bottom:20px;
      ">计算队伍DPS</button>
    </div>
    <div id="damageResult" style="display:none;">
      <div class="damage-result">
        <div class="dps-value" id="dpsValue">0</div>
        <div class="dps-label">队伍总DPS</div>
      </div>
      <div class="damage-bar-chart" id="damageChart"></div>
    </div>
  `;
}

function initTeamDamage() {
  const slots = document.querySelectorAll('.team-slot:not(.filled)');
  const chars = ['🔥', '❄️', '🪨', '🌪️', '☀️'];
  slots.forEach(slot => {
    slot.addEventListener('click', () => {
      const c = chars[Math.floor(Math.random() * chars.length)];
      slot.textContent = c;
      slot.classList.add('filled');
    });
  });
}

function calcTeamDamage() {
  const result = document.getElementById('damageResult');
  if (result) result.style.display = 'block';

  const totalDps = Math.floor(35000 + Math.random() * 25000);
  const dpsEl = document.getElementById('dpsValue');
  animateNumber(dpsEl, totalDps);

  const members = [
    { emoji: '🌿', name: '主C', pct: 0.4 + Math.random() * 0.15 },
    { emoji: '⚡', name: '副C', pct: 0.2 + Math.random() * 0.1 },
    { emoji: '🌊', name: '辅助', pct: 0.15 + Math.random() * 0.1 },
    { emoji: '🔥', name: '增幅', pct: 0.1 + Math.random() * 0.05 },
  ];

  const chart = document.getElementById('damageChart');
  const maxPct = Math.max(...members.map(m => m.pct));
  const colors = ['linear-gradient(90deg, #f59e0b, #ef4444)', 'linear-gradient(90deg, #8b5cf6, #6366f1)', 'linear-gradient(90deg, #3b82f6, #06b6d4)', 'linear-gradient(90deg, #ef4444, #f97316)'];

  chart.innerHTML = members.map((m, i) => `
    <div class="damage-bar-row">
      <div class="damage-bar-label">${m.emoji}</div>
      <div class="damage-bar-track">
        <div class="damage-bar-fill" style="width:${(m.pct / maxPct) * 100}%; background:${colors[i]};">
          ${Math.floor(m.pct * totalDps).toLocaleString()}
        </div>
      </div>
    </div>
  `).join('');
}

/* ========== Toast 提示 ========== */
function showToast(msg) {
  const toast = document.getElementById('toast');
  toast.textContent = msg;
  toast.classList.add('show');
  setTimeout(() => toast.classList.remove('show'), 2200);
}
