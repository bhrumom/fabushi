const result = document.querySelector("#result");

const browserMock = {
  initialized: false,
  async invoke(command, args = {}) {
    switch (command) {
      case "host_initialize":
        this.initialized = true;
        return {
          initialized: true,
          status: { runtimeAbiVersion: 1, remoteAgentEnabled: false },
        };
      case "host_execute":
        if (!this.initialized) throw new Error("Mahayana Host is not initialized");
        return { runtimeAbiVersion: 1, remoteAgentEnabled: false };
      case "host_receive":
        if (!this.initialized) throw new Error("Mahayana Host is not initialized");
        return { "@type": "mahayana.runtime.ready" };
      case "host_close":
        this.initialized = false;
        return { closed: true };
      default:
        throw new Error(`Unsupported diagnostic command: ${command}`);
    }
  },
};

const invoke = (...args) =>
  window.__TAURI__?.core?.invoke(...args) ?? browserMock.invoke(...args);

async function run(command, args) {
  result.dataset.state = "running";
  result.textContent = `执行 ${command}…`;
  try {
    const value = await invoke(command, args);
    result.dataset.state = "passed";
    result.textContent = JSON.stringify(value, null, 2);
  } catch (error) {
    result.dataset.state = "failed";
    result.textContent = String(error);
  }
}

document.querySelector("#initialize").addEventListener("click", () =>
  run("host_initialize", { config: null }),
);
document.querySelector("#status").addEventListener("click", () =>
  run("host_execute", {
    command: { "@type": "mahayana.runtime.status" },
  }),
);
document.querySelector("#receive").addEventListener("click", () =>
  run("host_receive", { timeoutMs: 25 }),
);
document.querySelector("#close").addEventListener("click", () =>
  run("host_close"),
);
