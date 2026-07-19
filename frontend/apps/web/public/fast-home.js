(() => {
  const root = document.querySelector('[data-fast-home-root]');
  if (!root || root.dataset.ready === '1') return;
  root.dataset.ready = '1';

  const input = root.querySelector('[data-composer-input]');
  const messagesEl = root.querySelector('[data-messages]');
  const hero = root.querySelector('[data-empty-state]');
  const menu = root.querySelector('[data-tool-menu]');
  const mode = root.querySelector('[data-current-mode]');
  const modeBar = root.querySelector('[data-flashcard-mode-bar]');
  const sendLog = root.querySelector('[data-global-log]');
  const cardWrap = root.querySelector('[data-card-wrap]');
  const cardCount = root.querySelector('[data-card-count]');
  const defaultText = root.getAttribute('data-default-text') || '';
  const brandName = root.getAttribute('data-brand-name') || '大乘';
  const brandLetter = brandName.slice(0, 1);
  const inputPlaceholder = root.getAttribute('data-input-placeholder') || '';
  const productApiBase = (root.getAttribute('data-product-api-base') || 'https://api.ombhrum.com').replace(/\/+$/, '');
  const aiApiBase = /^(localhost|127\.0\.0\.1|\[::1\])$/.test(window.location.hostname)
    ? 'https://ai.ombhrum.com'
    : window.location.origin + '/api/dacheng-ai';
  const regions = Array.from(root.querySelectorAll('[data-region]')).map((node) => node.getAttribute('data-region') || '').filter(Boolean);

  let activeTool = null;
  let activeCardMode = 'mixed';
  let cards = [];
  let cardIndex = 0;
  let answerVisible = false;
  let busy = false;

  function makeId(prefix) {
    return prefix + '-' + Date.now() + '-' + Math.random().toString(36).slice(2, 8);
  }

  function findTool(id) {
    const selector = '[data-select-tool="' + id + '"]';
    const node = root.querySelector(selector);
    if (!node) return null;
    return {
      id,
      title: node.getAttribute('data-tool-title') || '',
      shortTitle: node.getAttribute('data-tool-short') || '',
      action: node.getAttribute('data-tool-action') || '',
    };
  }

  function findCardMode(id) {
    const selector = '[data-select-card-mode="' + id + '"]';
    const node = root.querySelector(selector);
    if (!node) return null;
    return {
      id,
      title: node.getAttribute('data-card-mode-title') || '',
      shortTitle: node.getAttribute('data-card-mode-short') || '',
    };
  }

  function updateCardMode() {
    root.querySelectorAll('[data-select-card-mode]').forEach((button) => {
      const isActive = button.getAttribute('data-select-card-mode') === activeCardMode;
      button.classList.toggle('is-active', isActive);
      button.setAttribute('aria-pressed', isActive ? 'true' : 'false');
    });
  }

  function updateMode() {
    const tool = activeTool ? findTool(activeTool) : null;
    const cardMode = findCardMode(activeCardMode);
    if (mode) {
      mode.hidden = !tool;
      mode.textContent = tool ? tool.shortTitle + ' ×' : '';
    }
    if (modeBar) {
      modeBar.hidden = activeTool !== 'flashcards';
    }
    root.querySelectorAll('[data-select-tool]').forEach((button) => {
      button.classList.toggle('is-active', button.getAttribute('data-select-tool') === activeTool);
    });
    if (input) {
      const action = tool && activeTool === 'flashcards' && cardMode
        ? '制作' + cardMode.title
        : tool ? tool.action : '';
      input.placeholder = tool ? action + '，也可以继续问一问' + brandName : inputPlaceholder;
    }
    updateCardMode();
  }

  function setTool(id) {
    activeTool = id || null;
    updateMode();
  }

  function setCardMode(id) {
    activeCardMode = id || 'mixed';
    updateMode();
    if (input) input.focus();
  }

  function setText(node, value) {
    if (node) node.textContent = value;
  }

  function addMessage(role, text, tag) {
    if (!messagesEl) return;
    root.classList.add('has-chat');
    if (hero) hero.hidden = true;

    const article = document.createElement('article');
    article.className = 'fast-message ' + role;
    article.setAttribute('data-id', makeId('msg'));

    const avatar = document.createElement('span');
    avatar.className = 'fast-avatar';
    avatar.textContent = role === 'user' ? '我' : brandLetter;

    const bubble = document.createElement('p');
    bubble.className = 'fast-bubble';
    bubble.textContent = (tag ? tag + '：' : '') + text;

    article.append(avatar, bubble);
    messagesEl.appendChild(article);
    messagesEl.scrollTop = messagesEl.scrollHeight;
  }

  function readAuthToken() {
    return window.localStorage.getItem('auth_token') || window.localStorage.getItem('authToken') || '';
  }

  function importCallbackToken() {
    const hash = new URLSearchParams(window.location.hash.replace(/^#/, ''));
    const token = hash.get('token');
    if (!token) return;
    window.localStorage.setItem('auth_token', token);
    window.history.replaceState(null, '', window.location.pathname + window.location.search);
  }

  function commandHelp() {
    return [
      '大乘 CLI 命令：',
      '/login  使用支付宝登录',
      '/login complete <授权码> [state]',
      '/status  查看登录状态',
      '/contacts  查看好友',
      '/contacts search <关键词>',
      '/contacts add <用户编号或用户名> [验证消息]',
      '/requests  查看好友申请',
      '/requests accept <申请编号>',
      '/message <联系人> <消息>',
      '/messages <联系人>',
      '/miniapp <小程序ID> <消息>',
      '/logout  退出软件账号',
      '普通文字会进入大乘 AI 对话。',
    ].join('\n');
  }

  function formatCommandResult(payload) {
    const data = payload && payload.data ? payload.data : payload;
    if (data && Array.isArray(data.friends)) {
      return data.friends.length
        ? data.friends.map((item) => item.displayName + (item.username ? ' (@' + item.username + ')' : '') + ' · ' + item.id).join('\n')
        : '好友列表为空。';
    }
    if (data && Array.isArray(data.users)) {
      return data.users.length
        ? data.users.map((item) => item.displayName + (item.username ? ' (@' + item.username + ')' : '') + ' · ' + item.id + ' · ' + item.status).join('\n')
        : '没有找到联系人。';
    }
    if (data && Array.isArray(data.requests)) {
      return data.requests.length
        ? data.requests.map((item) => '#' + item.id + ' · ' + (item.fromUser && item.fromUser.displayName || '未知用户') + (item.message ? ' · ' + item.message : '')).join('\n')
        : '没有待处理的好友申请。';
    }
    if (data && Array.isArray(data.messages)) {
      return data.messages.length
        ? data.messages.map((item) => (item.isOutgoing ? '我' : item.senderUsername || '对方') + '：' + item.text).join('\n')
        : '还没有消息。';
    }
    if (payload && payload.message && typeof payload.message === 'object') {
      return '消息已发送，编号 #' + (payload.message.id || '待同步') + '。';
    }
    if (payload && payload.status === 'accepted') return '好友申请已接受。';
    if (payload && payload.status === 'pending') return '好友申请已发送。';
    return JSON.stringify(payload, null, 2);
  }

  async function executeMahayana(command, options) {
    const token = readAuthToken();
    if ((!options || options.auth !== false) && !token) {
      throw new Error('尚未登录。请输入 /login 使用支付宝登录。');
    }
    const headers = { Accept: 'application/json', 'Content-Type': 'application/json' };
    if (token) headers.Authorization = 'Bearer ' + token;
    const response = await fetch(productApiBase + '/api/mahayana/execute', {
      method: 'POST',
      headers,
      body: JSON.stringify(command),
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok || payload.success === false || payload.error) {
      throw new Error(payload.error || payload.message || '命令执行失败 (' + response.status + ')');
    }
    return payload;
  }

  async function startAlipayLogin() {
    const payload = await executeMahayana({ '@type': 'mahayana.auth.alipay.start', platform: 'cli' }, { auth: false });
    const loginUrl = payload.authUrl || payload.loginUrl;
    if (!loginUrl) throw new Error('支付宝登录接口没有返回授权地址。');
    if (!payload.state) throw new Error('支付宝登录接口没有返回登录状态。');
    if (payload.state) window.sessionStorage.setItem('mahayana_alipay_state', payload.state);
    window.open(loginUrl, '_blank', 'noopener,noreferrer');
    addMessage('assistant', '支付宝授权页已打开，正在安全等待授权结果…', '大乘 CLI');
    for (let attempt = 0; attempt < 150; attempt += 1) {
      await new Promise((resolve) => window.setTimeout(resolve, 2000));
      const result = await executeMahayana({
        '@type': 'mahayana.auth.alipay.poll',
        state: payload.state,
      }, { auth: false });
      if (result.status === 'pending') continue;
      if (result.status === 'complete' && result.token) {
        window.localStorage.setItem('auth_token', result.token);
        window.sessionStorage.removeItem('mahayana_alipay_state');
        return '支付宝账号登录成功。';
      }
      throw new Error(result.error || '支付宝登录未完成。');
    }
    throw new Error('等待支付宝授权超时，请重新输入 /login。');
  }

  async function runAiChat(text, miniAppId) {
    const message = miniAppId
      ? '你正在通过大乘 CLI 与小程序 ' + miniAppId + ' 对话。请以该小程序能力回答：\n' + text
      : text;
    const response = await fetch(aiApiBase + '/api/ai/chat', {
      method: 'POST',
      headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
      body: JSON.stringify({ message, clientMembershipHint: false }),
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok || payload.success === false) {
      throw new Error(payload.message || payload.error || '大乘 AI 暂时不可用。');
    }
    return payload.message || payload.text || JSON.stringify(payload, null, 2);
  }

  async function runCommand(line) {
    const parts = line.trim().split(/\s+/);
    const name = (parts.shift() || '').toLowerCase();
    if (name === '/help') return commandHelp();
    if (name === '/login') {
      if ((parts[0] || '').toLowerCase() !== 'complete') return startAlipayLogin();
      parts.shift();
      const authCode = parts.shift();
      if (!authCode) throw new Error('用法：/login complete <授权码> [state]');
      const payload = await executeMahayana({
        '@type': 'mahayana.auth.alipay.complete',
        authCode,
        state: parts.shift() || window.sessionStorage.getItem('mahayana_alipay_state') || undefined,
      }, { auth: false });
      if (payload.needsRegistration && !payload.token) {
        throw new Error('该支付宝账号需要先完成大乘账号注册。');
      }
      if (payload.token) window.localStorage.setItem('auth_token', payload.token);
      return '支付宝账号登录成功。';
    }
    if (name === '/logout') {
      if (readAuthToken()) {
        await executeMahayana({ '@type': 'mahayana.auth.logout' });
      }
      window.localStorage.removeItem('auth_token');
      window.localStorage.removeItem('authToken');
      return '已退出大乘软件账号。';
    }
    if (name === '/status') {
      if (!readAuthToken()) return '尚未登录。输入 /login 使用支付宝登录。';
      const payload = await executeMahayana({ '@type': 'mahayana.auth.status' });
      const user = payload.user || payload.data && payload.data.user || payload;
      return '已登录大乘软件账号' + (user.username ? '：@' + user.username : '') + '。';
    }
    if (name === '/contacts') {
      const action = (parts.shift() || '').toLowerCase();
      if (!action) return formatCommandResult(await executeMahayana({ '@type': 'mahayana.contacts.list' }));
      if (action === 'search') {
        const query = parts.join(' ').trim();
        if (!query) throw new Error('用法：/contacts search <关键词>');
        return formatCommandResult(await executeMahayana({ '@type': 'mahayana.contacts.search', query }));
      }
      if (action === 'add') {
        const contact = parts.shift();
        if (!contact) throw new Error('用法：/contacts add <用户编号或用户名> [验证消息]');
        return formatCommandResult(await executeMahayana({ '@type': 'mahayana.contacts.add', contact, message: parts.join(' ') }));
      }
      throw new Error('联系人子命令仅支持 search 或 add。');
    }
    if (name === '/requests') {
      const action = (parts.shift() || '').toLowerCase();
      if (!action) return formatCommandResult(await executeMahayana({ '@type': 'mahayana.contacts.requests' }));
      if (action === 'accept' && parts[0]) {
        return formatCommandResult(await executeMahayana({ '@type': 'mahayana.contacts.accept', requestId: parts[0] }));
      }
      throw new Error('用法：/requests accept <申请编号>');
    }
    if (name === '/message') {
      const contact = parts.shift();
      const text = parts.join(' ').trim();
      if (!contact || !text) throw new Error('用法：/message <联系人> <消息>');
      return formatCommandResult(await executeMahayana({ '@type': 'mahayana.messages.send', contact, text, clientRequestId: makeId('web') }));
    }
    if (name === '/messages') {
      const contact = parts.shift();
      if (!contact) throw new Error('用法：/messages <联系人>');
      return formatCommandResult(await executeMahayana({ '@type': 'mahayana.messages.list', contact }));
    }
    if (name === '/miniapp') {
      const miniAppId = parts.shift();
      const text = parts.join(' ').trim();
      if (!miniAppId || !text) throw new Error('用法：/miniapp <小程序ID> <消息>');
      return runAiChat(text, miniAppId);
    }
    throw new Error('未知命令。输入 /help 查看大乘 CLI 命令。');
  }

  function clearMessages() {
    if (messagesEl) messagesEl.textContent = '';
    if (hero) hero.hidden = false;
    root.classList.remove('has-chat');
    cards = [];
    cardIndex = 0;
    answerVisible = false;
    activeCardMode = 'mixed';
    setText(sendLog, '等待输入正文后生成全球法布施清单。');
    renderCard();
    setTool(null);
    if (input) {
      input.value = '';
      autoSizeInput();
    }
  }

  function splitSentences(text) {
    return text
      .split(/[。！？!?；;\n]+/)
      .map((item) => item.trim())
      .filter((item) => item.length > 5)
      .slice(0, 6);
  }

  function makeCards(text, cardMode) {
    const made = [];
    splitSentences(text).forEach((sentence) => {
      const plain = sentence.replace(/[，、：,\s]/g, '');
      const start = Math.max(0, Math.floor(plain.length / 3) - 1);
      const term = plain.slice(start, Math.min(plain.length, start + 4));
      const cloze = term && sentence.includes(term)
        ? sentence.replace(term, '〔……〕')
        : sentence.slice(0, 8) + '〔……〕' + sentence.slice(Math.min(sentence.length, 14));
      if (cardMode !== 'bidirectional') {
        made.push({ id: makeId('card'), front: cloze, back: sentence, kind: '挖空', reviews: 0, due: '现在' });
      }
      if (cardMode !== 'cloze') {
        made.push({ id: makeId('card'), front: '请背诵并解释：' + sentence.slice(0, 18) + '…', back: sentence, kind: '双向', reviews: 0, due: '现在' });
      }
    });
    return made;
  }

  function nextDue(rating) {
    if (rating === 'Again') return '10 分钟后';
    if (rating === 'Hard') return '明天';
    if (rating === 'Good') return '3 天后';
    return '7 天后';
  }

  function renderCard() {
    if (!cardWrap) return;
    cardWrap.textContent = '';
    setText(cardCount, cards.length ? cards.length + ' 张卡片' : '暂无卡片');
    const card = cards[cardIndex];
    if (!card) {
      const empty = document.createElement('p');
      empty.textContent = '输入正文并选择背诵闪卡后，可在输入框上方切换挖空卡、双向卡或混合制卡。';
      cardWrap.appendChild(empty);
      return;
    }

    const meta = document.createElement('small');
    meta.textContent = card.kind + ' · ' + card.due + ' · 已复习 ' + card.reviews + ' 次';
    const front = document.createElement('strong');
    front.textContent = card.front;
    cardWrap.append(meta, front);

    if (answerVisible) {
      const answer = document.createElement('p');
      answer.textContent = card.back;
      cardWrap.appendChild(answer);
    } else {
      const reveal = document.createElement('button');
      reveal.type = 'button';
      reveal.textContent = '显示答案';
      reveal.addEventListener('click', () => {
        answerVisible = true;
        renderCard();
      });
      cardWrap.appendChild(reveal);
    }

    const reviews = document.createElement('div');
    reviews.className = 'fast-reviews';
    ['Again', 'Hard', 'Good', 'Easy'].forEach((rating) => {
      const button = document.createElement('button');
      button.type = 'button';
      button.textContent = rating;
      button.addEventListener('click', () => {
        card.reviews += 1;
        card.due = nextDue(rating);
        cardIndex = cards.length ? (cardIndex + 1) % cards.length : 0;
        answerVisible = false;
        renderCard();
      });
      reviews.appendChild(button);
    });
    cardWrap.appendChild(reviews);
  }

  function runGlobal(text) {
    const body = (text || defaultText).trim();
    const lines = regions.map((region) => '✓ ' + region + ' · 已生成首页轻量清单');
    setText(sendLog, lines.join('\n'));
    addMessage('assistant', '开始全球法布施：极速 Web 版只保留首页轻量流程，不加载 App 专属页面。', '全球法布施');
    addMessage('assistant', '全球法布施完成：已整理 ' + lines.length + ' 个地区。\n正文：' + body, '全球法布施');
  }

  function buildDeck(text) {
    const cardMode = findCardMode(activeCardMode) || { title: '混合制卡' };
    const made = makeCards(text || defaultText, activeCardMode);
    cards = made.concat(cards);
    cardIndex = 0;
    answerVisible = false;
    renderCard();
    addMessage('assistant', made.length ? '已按' + cardMode.title + '模式制作 ' + made.length + ' 张背诵闪卡。' : '内容太短，请补充正文后再制卡。', '背诵闪卡');
  }

  async function submit() {
    if (!input) return;
    if (busy) return;
    const tool = activeTool ? findTool(activeTool) : null;
    const text = (input.value || '').trim() || defaultText;
    input.value = '';
    autoSizeInput();
    addMessage('user', text, tool ? tool.title : '通用');
    if (activeTool === 'global-dharma') {
      runGlobal(text);
    } else if (activeTool === 'flashcards') {
      buildDeck(text);
    } else {
      busy = true;
      try {
        const result = text.startsWith('/') ? await runCommand(text) : await runAiChat(text);
        addMessage('assistant', result, text.startsWith('/') ? '大乘 CLI' : '大乘 AI');
      } catch (error) {
        addMessage('assistant', error && error.message ? error.message : '执行失败，请稍后再试。', '错误');
      } finally {
        busy = false;
      }
    }
  }

  function autoSizeInput() {
    if (!input) return;
    input.style.height = 'auto';
    input.style.height = Math.min(input.scrollHeight, 148) + 'px';
  }

  root.querySelectorAll('[data-chip]').forEach((button) => {
    button.addEventListener('click', () => {
      if (input) {
        input.value = button.getAttribute('data-prompt') || '';
        input.focus();
        autoSizeInput();
      }
      setTool(button.getAttribute('data-tool') || null);
    });
  });

  root.querySelectorAll('[data-select-tool]').forEach((button) => {
    button.addEventListener('click', () => {
      setTool(button.getAttribute('data-select-tool') || null);
      if (menu) menu.hidden = true;
      if (input) input.focus();
    });
  });

  root.querySelectorAll('[data-select-card-mode]').forEach((button) => {
    button.addEventListener('click', () => {
      setCardMode(button.getAttribute('data-select-card-mode') || 'mixed');
    });
  });

  const plus = root.querySelector('[data-toggle-menu]');
  if (plus && menu) {
    plus.addEventListener('click', () => {
      menu.hidden = !menu.hidden;
    });
  }

  const form = root.querySelector('[data-composer-form]');
  if (form) {
    form.addEventListener('submit', (event) => {
      event.preventDefault();
      void submit();
    });
  }

  if (mode) mode.addEventListener('click', () => setTool(null));
  const newChat = root.querySelector('[data-new-chat]');
  if (newChat) newChat.addEventListener('click', clearMessages);
  const login = root.querySelector('[data-alipay-login]');
  if (login) login.addEventListener('click', async () => {
    try {
      addMessage('assistant', await startAlipayLogin(), '大乘 CLI');
    } catch (error) {
      addMessage('assistant', error && error.message ? error.message : '支付宝登录启动失败。', '错误');
    }
  });
  if (input) {
    input.addEventListener('input', autoSizeInput);
    input.addEventListener('keydown', (event) => {
      if (event.key === 'Enter' && !event.shiftKey) {
        event.preventDefault();
        void submit();
      }
    });
  }

  renderCard();
  updateMode();
  importCallbackToken();
})();
