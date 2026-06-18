const bridgeUrlInput = document.getElementById("bridgeUrl");
const tokenInput = document.getElementById("token");
const statusNode = document.getElementById("status");

async function load() {
  const settings = await chrome.storage.local.get(["bridgeUrl", "token"]);
  bridgeUrlInput.value = settings.bridgeUrl || "http://127.0.0.1:18790";
  tokenInput.value = settings.token || "";
}

async function save() {
  await chrome.storage.local.set({
    bridgeUrl: bridgeUrlInput.value.trim().replace(/\/$/, ""),
    token: tokenInput.value.trim(),
  });
  statusNode.textContent = "Saved.";
}

document.getElementById("save").addEventListener("click", save);
load();
