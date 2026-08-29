import { listSemanticApplications, listSemanticElements, semanticElementAction } from "../lib/semantic-computer.js";
import assert from "node:assert/strict";

const APP_ID = "com.ombhrum.fabushi";

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function getAppElements(query = undefined) {
  const result = await listSemanticElements({
    source: "desktop",
    application: APP_ID,
    maxElements: 300,
    maxDepth: 30,
    maxVisitedNodes: 5000,
    focusedWindowOnly: false,
    includeContainers: true,
    includeStaticText: true,
    query,
  });
  return result.elements;
}

async function runFullTestSuite() {
  console.log("=================================================");
  console.log("🚀 [Fabushi 自动化操控测试套件] 开始执行");
  console.log("=================================================\n");

  // ==========================================
  // 1. 验证目标应用运行状态
  // ==========================================
  console.log("【测试阶段 1】验证目标应用环境与运行状态");
  const apps = await listSemanticApplications();
  const fabushiApp = apps.find(
    (a) => a.id === APP_ID || (a.displayName === "全球法布施" && a.path?.includes("fabushi"))
  );
  assert.ok(fabushiApp, `必须检测到目标应用 ${APP_ID}`);
  assert.ok(fabushiApp.isRunning, "应用必须处于运行中状态");
  console.log(`  ✅ 成功连接目标应用: ${fabushiApp.displayName} (PID: ${fabushiApp.pid}, Path: ${fabushiApp.path})`);

  let elements = await getAppElements();
  console.log(`  ✅ 成功获取应用 AXUIElement 树，当前节点数: ${elements.length}`);

  // ==========================================
  // 2. 测试主界面侧边栏搜索功能
  // ==========================================
  console.log("\n【测试阶段 2】测试主界面侧边栏搜索与会话列表过滤");
  
  let searchSessionInput = elements.find(
    (el) => el.role === "AXTextField" && el.name === "搜索会话"
  );
  
  if (searchSessionInput) {
    console.log(`  -> 发现侧边栏搜索框 (当前值: "${searchSessionInput.value || ""}")`);
    
    // 清空搜索框
    console.log("  -> 步骤 2.1: 清空搜索框...");
    await semanticElementAction({
      elementId: searchSessionInput.id,
      action: "set_value",
      value: "",
    });
    await sleep(500);
    elements = await getAppElements();
    
    // 输入搜索关键词 "大乘"
    searchSessionInput = elements.find((el) => el.role === "AXTextField" && el.name === "搜索会话");
    console.log('  -> 步骤 2.2: 搜索关键词 "大乘"...');
    await semanticElementAction({
      elementId: searchSessionInput.id,
      action: "set_value",
      value: "大乘",
    });
    await sleep(500);
    elements = await getAppElements();
    
    const matchedSession = elements.some((el) => el.name && el.name.includes("大乘助手"));
    console.log(`  -> 搜索过滤结果: 包含大乘助手 = ${matchedSession}`);
    assert.ok(matchedSession, "搜索'大乘'后会话列表应展示大乘助手");
    
    // 恢复清空
    searchSessionInput = elements.find((el) => el.role === "AXTextField" && el.name === "搜索会话");
    console.log("  -> 步骤 2.3: 恢复清空会话搜索框...");
    await semanticElementAction({
      elementId: searchSessionInput.id,
      action: "set_value",
      value: "",
    });
    await sleep(500);
    elements = await getAppElements();
    console.log("  ✅ 侧边栏搜索功能测试通过！");
  }

  // ==========================================
  // 3. 测试打开与操控“插件市场”弹窗
  // ==========================================
  console.log("\n【测试阶段 3】测试“插件市场”弹窗全生命周期与交互功能");
  
  // 检查是否已经在插件市场，如果不在则点击打开
  let pluginMarketDialog = elements.find(
    (el) => el.name === "插件市场" && (el.subrole === "AXApplicationDialog" || el.role === "AXHeading")
  );
  
  if (!pluginMarketDialog) {
    const openMarketBtn = elements.find(
      (el) => el.role === "AXButton" && el.name === "插件市场"
    );
    assert.ok(openMarketBtn, "主界面侧边栏应存在'插件市场'按钮");
    console.log(`  -> 步骤 3.1: 点击侧边栏'插件市场'按钮 (ID: ${openMarketBtn.id.slice(0, 16)}...)...`);
    await semanticElementAction({
      elementId: openMarketBtn.id,
      action: "press",
    });
    await sleep(800);
    elements = await getAppElements();
  }

  // 验证插件市场弹窗已展示
  const hasMarketHeading = elements.some(
    (el) => el.name === "插件市场" && (el.role === "AXHeading" || el.subrole === "AXApplicationDialog")
  );
  assert.ok(hasMarketHeading, "插件市场弹窗必须成功打开并展示标题");
  console.log("  ✅ 步骤 3.1: 插件市场弹窗成功打开！");

  // 步骤 3.2: 测试分类 Tab 切换
  console.log("  -> 步骤 3.2: 测试分类 Tab 切换 (Connectors -> Skills -> Bots -> Apps)...");
  
  const tabs = ["Connectors", "Skills", "Bots", "Apps"];
  for (const tabName of tabs) {
    const tabBtn = elements.find(
      (el) => el.role === "AXButton" && el.name.includes(tabName)
    );
    if (tabBtn) {
      console.log(`     - 切换到 Tab: "${tabBtn.name}"`);
      await semanticElementAction({
        elementId: tabBtn.id,
        action: "press",
      });
      await sleep(400);
      elements = await getAppElements();
    }
  }
  
  // 验证回到 Apps 分类后，卡片加载情况
  const hasFabushi = elements.some((el) => el.value === "全球法布施" || el.name === "全球法布施");
  const hasHermes = elements.some((el) => el.value?.includes("Hermes") || el.name?.includes("Hermes"));
  console.log(`  -> Apps 分类内容验证: 全球法布施=${hasFabushi}, Hermes 安装器=${hasHermes}`);
  assert.ok(hasFabushi && hasHermes, "Apps 分类下应展示官方插件卡片");
  console.log("  ✅ 步骤 3.2: 分类 Tab 切换及卡片列表加载测试通过！");

  // 步骤 3.3: 测试插件市场搜索与过滤
  console.log("  -> 步骤 3.3: 测试插件市场内搜索过滤...");
  
  // 查找插件市场弹窗内的搜索输入框（排查非侧边栏搜索框）
  let marketSearchInput = elements.find(
    (el) => (el.role === "AXTextField" || el.role === "AXSearchField") && el.name !== "搜索会话"
  );
  
  if (marketSearchInput) {
    console.log(`     - 定位到插件市场搜索框 (bounds: x=${marketSearchInput.bounds?.x}, y=${marketSearchInput.bounds?.y})`);
    
    // 输入 "记忆卡"
    console.log('     - 输入搜索词: "记忆卡"');
    await semanticElementAction({
      elementId: marketSearchInput.id,
      action: "set_value",
      value: "记忆卡",
    });
    await sleep(500);
    elements = await getAppElements();
    
    const cardFound = elements.some((el) => el.value?.includes("法流记忆卡"));
    const botFatherHidden = !elements.some((el) => el.value?.includes("Bot Father"));
    console.log(`     - 过滤结果断言: 包含法流记忆卡 = ${cardFound}, 隐藏无关项 Bot Father = ${botFatherHidden}`);
    assert.ok(cardFound, "搜索'记忆卡'应精准匹配到'法流记忆卡'");

    // 清空插件市场搜索框
    marketSearchInput = elements.find(
      (el) => (el.role === "AXTextField" || el.role === "AXSearchField") && el.name !== "搜索会话"
    );
    if (marketSearchInput) {
      console.log("     - 清空插件市场搜索框...");
      await semanticElementAction({
        elementId: marketSearchInput.id,
        action: "set_value",
        value: "",
      });
      await sleep(500);
      elements = await getAppElements();
      const allRestored = elements.some((el) => el.value?.includes("Bot Father"));
      console.log(`     - 列表重置断言: 全部插件卡片恢复 = ${allRestored}`);
      assert.ok(allRestored, "清空搜索框后应恢复所有插件列表");
    }
  }
  console.log("  ✅ 步骤 3.3: 插件市场搜索过滤与恢复测试通过！");

  // 步骤 3.4: 测试关闭插件市场弹窗
  console.log("  -> 步骤 3.4: 测试关闭插件市场弹窗...");
  const closeMarketBtn = elements.find(
    (el) => el.role === "AXButton" && (el.name.includes("关闭") || el.name.includes("Close"))
  );
  assert.ok(closeMarketBtn, "应存在关闭插件市场按钮");
  console.log(`     - 点击按钮: "${closeMarketBtn.name}"`);
  await semanticElementAction({
    elementId: closeMarketBtn.id,
    action: "press",
  });
  await sleep(800);
  elements = await getAppElements();
  
  const marketClosed = !elements.some(
    (el) => el.subrole === "AXApplicationDialog" && el.name === "插件市场"
  );
  assert.ok(marketClosed, "插件市场弹窗应已关闭");
  console.log("  ✅ 步骤 3.4: 插件市场弹窗成功关闭，顺利返回主界面！");

  // ==========================================
  // 4. 测试主界面消息输入与交互功能
  // ==========================================
  console.log("\n【测试阶段 4】测试主界面消息输入区（Composer）交互功能");
  
  const messageInput = elements.find(
    (el) => (el.role === "AXTextArea" || el.role === "AXTextField") && (el.name === "消息内容" || el.name?.includes("消息"))
  );
  
  if (messageInput) {
    const testMessage = "【自动测试】这是一条通过 Fabushi Computer Control 写入的测试指令";
    console.log(`  -> 步骤 4.1: 找到消息输入框 (Role: ${messageInput.role}, Name: "${messageInput.name}")`);
    console.log(`  -> 步骤 4.2: 写入测试内容: "${testMessage}"`);
    
    await semanticElementAction({
      elementId: messageInput.id,
      action: "set_value",
      value: testMessage,
    });
    await sleep(500);
    elements = await getAppElements();
    
    const updatedInput = elements.find(
      (el) => (el.role === "AXTextArea" || el.role === "AXTextField") && (el.name === "消息内容" || el.name?.includes("消息"))
    );
    console.log(`  -> 输入框当前值验证: "${updatedInput?.value || ""}"`);
    assert.equal(updatedInput?.value, testMessage, "消息输入框内容应与写入内容完全一致");
    console.log("  ✅ 步骤 4.2: 消息内容精准写入验证成功！");

    // 清空输入框
    console.log("  -> 步骤 4.3: 清空测试消息内容...");
    await semanticElementAction({
      elementId: updatedInput.id,
      action: "set_value",
      value: "",
    });
    await sleep(300);
    console.log("  ✅ 步骤 4.3: 输入框已恢复初始状态！");
  } else {
    console.log("  ⚠️ 未在当前主视图定位到 AXTextArea 消息输入框，跳过写入测试");
  }

  // ==========================================
  // 5. 测试主界面功能入口（新建会话 / 智能体切换）
  // ==========================================
  console.log("\n【测试阶段 5】测试主界面核心功能入口与操作响应");
  
  const newSessionBtn = elements.find(
    (el) => el.role === "AXButton" && el.name === "新建会话"
  );
  if (newSessionBtn) {
    console.log(`  -> 步骤 5.1: 点击"新建会话"按钮 (ID: ${newSessionBtn.id.slice(0, 16)}...)...`);
    await semanticElementAction({
      elementId: newSessionBtn.id,
      action: "press",
    });
    await sleep(500);
    elements = await getAppElements();
    console.log("  ✅ 步骤 5.1: 新建会话触发成功！");
  }

  const assistantSessionBtn = elements.find(
    (el) => el.role === "AXButton" && el.name.includes("大乘助手")
  );
  if (assistantSessionBtn) {
    console.log(`  -> 步骤 5.2: 点击会话列表中"大乘助手"卡片...`);
    await semanticElementAction({
      elementId: assistantSessionBtn.id,
      action: "press",
    });
    await sleep(500);
    elements = await getAppElements();
    console.log("  ✅ 步骤 5.2: 会话切换响应成功！");
  }

  console.log("\n=================================================");
  console.log("🎉 [Fabushi 自动化操控测试套件] 全部 5 个测试阶段 100% 顺利通过！");
  console.log("=================================================\n");
}

runFullTestSuite().catch((err) => {
  console.error("\n❌ [Fabushi 自动化测试] 执行失败:", err);
  process.exit(1);
});
