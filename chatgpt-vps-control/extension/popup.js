const button = document.querySelector("#toggle");
const bridge = document.querySelector("#bridge");
const details = document.querySelector("#details");
const consent = document.querySelector("#userscript-consent");
const userscriptStatus = document.querySelector("#userscript-status");
const userscriptList = document.querySelector("#userscript-list");
const userscriptPort = chrome.runtime.connect({ name: "fabushi-userscripts" });
const pending = new Map();
let requestSequence = 0;

function userscriptRequest(action, payload = {}) {
  const requestId = `popup-${Date.now()}-${++requestSequence}`;
  return new Promise((resolve, reject) => {
    pending.set(requestId, { resolve, reject });
    userscriptPort.postMessage({ requestId, action, ...payload });
  });
}

userscriptPort.onMessage.addListener((message) => {
  const waiter = pending.get(message?.requestId);
  if (!waiter) return;
  pending.delete(message.requestId);
  if (message.ok) waiter.resolve(message.result);
  else waiter.reject(new Error(message.error || "User-script operation failed."));
});

function render(result) {
  if (result?.error) {
    button.textContent = result.error;
    button.disabled = true;
    return;
  }
  button.disabled = false;
  button.textContent = result.connected ? "本机服务已连接" : "重新连接本机服务";
  bridge.textContent = result.connected ? "本机控制服务：已连接" : "本机控制服务：未连接，请先运行安装与服务命令";
  details.textContent = `扩展 ID：${result.extensionId || "未知"}\n当前标签页：${result.eligible ? (result.claimed ? "已认领" : "可由控制服务选择") : "不可控制"}${result.nativeError ? `\n错误：${result.nativeError}` : ""}`;
}

function renderUserscripts(result) {
  consent.checked = result.consent === true;
  consent.disabled = result.available !== true;
  userscriptStatus.textContent = result.available
    ? (result.runtimeError ? `运行时已安全停止：${result.runtimeError}` : `已安装 ${result.scripts.length} 个用户脚本；总开关${result.consent ? "已开启" : "已关闭"}。`)
    : "当前 Chrome 未开放 userScripts API；所有用户脚本保持停用。";
  userscriptList.replaceChildren();
  for (const script of result.scripts) {
    const item = document.createElement("div");
    item.className = "userscript-item";
    const header = document.createElement("div");
    header.className = "userscript-header";
    const label = document.createElement("label");
    const toggle = document.createElement("input");
    toggle.type = "checkbox";
    toggle.checked = script.enabled === true;
    toggle.disabled = !result.consent;
    const name = document.createElement("span");
    name.textContent = `${script.name} ${script.version}`;
    label.append(toggle, name);
    const remove = document.createElement("button");
    remove.type = "button";
    remove.className = "danger secondary";
    remove.textContent = "卸载";
    header.append(label, remove);
    const meta = document.createElement("div");
    meta.className = "userscript-meta";
    meta.textContent = `来源：${script.source.pluginId}@${script.source.version}\n权限：${script.permissions.join(", ") || "无"}\n站点：${script.matches.join("\n")}`;
    item.append(header, meta);
    toggle.addEventListener("change", async () => {
      const enabling = toggle.checked;
      if (enabling && !confirm(`启用“${script.name}”？它将仅在列出的 HTTPS 站点运行。`)) {
        toggle.checked = false;
        return;
      }
      try {
        renderUserscripts(await userscriptRequest("set-enabled", { id: script.id, enabled: enabling, userConfirmed: enabling }));
      } catch (error) {
        userscriptStatus.textContent = error.message;
        toggle.checked = !enabling;
      }
    });
    remove.addEventListener("click", async () => {
      if (!confirm(`卸载“${script.name}”？`)) return;
      try {
        renderUserscripts(await userscriptRequest("uninstall", { id: script.id, userConfirmed: true }));
      } catch (error) {
        userscriptStatus.textContent = error.message;
      }
    });
    userscriptList.append(item);
  }
}

consent.addEventListener("change", async () => {
  const enabling = consent.checked;
  if (enabling && !confirm("开启 Fabushi 用户脚本？安装后的脚本仍默认关闭，必须逐个启用。")) {
    consent.checked = false;
    return;
  }
  try {
    renderUserscripts(await userscriptRequest("set-consent", { consent: enabling, userConfirmed: enabling }));
  } catch (error) {
    userscriptStatus.textContent = error.message;
    consent.checked = !enabling;
  }
});

button.addEventListener("click", () => chrome.runtime.sendMessage({ type: "reconnect" }, () => setTimeout(() => chrome.runtime.sendMessage({ type: "status" }, render), 300)));
chrome.runtime.sendMessage({ type: "status" }, render);
userscriptRequest("status").then(renderUserscripts, (error) => { userscriptStatus.textContent = error.message; });
