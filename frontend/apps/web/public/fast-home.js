(() => {
  const root = document.querySelector('[data-fast-home-root]');
  if (!root || root.dataset.ready === '1') return;
  root.dataset.ready = '1';

  const input = root.querySelector('[data-composer-input]');
  const messagesEl = root.querySelector('[data-messages]');
  const hero = root.querySelector('[data-empty-state]');
  const menu = root.querySelector('[data-tool-menu]');
  const mode = root.querySelector('[data-current-mode]');
  const sendLog = root.querySelector('[data-global-log]');
  const cardWrap = root.querySelector('[data-card-wrap]');
  const cardCount = root.querySelector('[data-card-count]');
  const defaultText = root.getAttribute('data-default-text') || '';
  const brandName = root.getAttribute('data-brand-name') || '大乘';
  const brandLetter = brandName.slice(0, 1);
  const inputPlaceholder = root.getAttribute('data-input-placeholder') || '';
  const regions = Array.from(root.querySelectorAll('[data-region]')).map((node) => node.getAttribute('data-region') || '').filter(Boolean);

  let activeTool = null;
  let cards = [];
  let cardIndex = 0;
  let answerVisible = false;

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

  function updateMode() {
    const tool = activeTool ? findTool(activeTool) : null;
    if (mode) {
      mode.hidden = !tool;
      mode.textContent = tool ? tool.shortTitle + ' ×' : '';
    }
    root.querySelectorAll('[data-select-tool]').forEach((button) => {
      button.classList.toggle('is-active', button.getAttribute('data-select-tool') === activeTool);
    });
    if (input) {
      input.placeholder = tool ? tool.action + '，也可以继续问一问' + brandName : inputPlaceholder;
    }
  }

  function setTool(id) {
    activeTool = id || null;
    updateMode();
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

  function clearMessages() {
    if (messagesEl) messagesEl.textContent = '';
    if (hero) hero.hidden = false;
    root.classList.remove('has-chat');
    cards = [];
    cardIndex = 0;
    answerVisible = false;
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

  function makeCards(text) {
    const made = [];
    splitSentences(text).forEach((sentence) => {
      const plain = sentence.replace(/[，、：,\s]/g, '');
      const start = Math.max(0, Math.floor(plain.length / 3) - 1);
      const term = plain.slice(start, Math.min(plain.length, start + 4));
      const cloze = term && sentence.includes(term)
        ? sentence.replace(term, '〔……〕')
        : sentence.slice(0, 8) + '〔……〕' + sentence.slice(Math.min(sentence.length, 14));
      made.push({ id: makeId('card'), front: cloze, back: sentence, kind: '挖空', reviews: 0, due: '现在' });
      made.push({ id: makeId('card'), front: '请背诵并解释：' + sentence.slice(0, 18) + '…', back: sentence, kind: '双向', reviews: 0, due: '现在' });
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
      empty.textContent = '输入正文并选择背诵闪卡后，这里会出现挖空卡和双向卡。';
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
    const made = makeCards(text || defaultText);
    cards = made.concat(cards);
    cardIndex = 0;
    answerVisible = false;
    renderCard();
    addMessage('assistant', made.length ? '已制作 ' + made.length + ' 张背诵闪卡。' : '内容太短，请补充正文后再制卡。', '背诵闪卡');
  }

  function submit() {
    if (!input) return;
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
      addMessage('assistant', '已收到。可以继续输入，或点击 + 进入全球法布施和背诵闪卡。');
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
      submit();
    });
  }

  if (mode) mode.addEventListener('click', () => setTool(null));
  const newChat = root.querySelector('[data-new-chat]');
  if (newChat) newChat.addEventListener('click', clearMessages);
  if (input) {
    input.addEventListener('input', autoSizeInput);
    input.addEventListener('keydown', (event) => {
      if (event.key === 'Enter' && !event.shiftKey) {
        event.preventDefault();
        submit();
      }
    });
  }

  renderCard();
  updateMode();
})();
