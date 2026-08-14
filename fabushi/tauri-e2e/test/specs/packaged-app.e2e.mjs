import assert from "node:assert/strict";

const selectorForTestId = (id) => `[data-testid="${id}"]`;
const testId = (id) => browser.$(selectorForTestId(id));

async function stage(label, operation) {
  const startedAt = Date.now();
  console.log(`[tauri-e2e] start: ${label}`);
  const result = await operation();
  console.log(`[tauri-e2e] done: ${label} (${Date.now() - startedAt}ms)`);
  return result;
}

async function domState(selector) {
  return browser.executeAsync((target, done) => {
    try {
      const element = document.querySelector(target);
      if (!(element instanceof HTMLElement)) {
        done({
          exists: false,
          visible: false,
          readyState: document.readyState,
          testIds: Array.from(document.querySelectorAll("[data-testid]"))
            .slice(0, 40)
            .map((candidate) => candidate.getAttribute("data-testid")),
          bodyText: document.body?.innerText?.slice(0, 500) ?? "",
        });
        return;
      }

      const style = window.getComputedStyle(element);
      const rect = element.getBoundingClientRect();
      done({
        exists: true,
        visible:
          style.display !== "none" &&
          style.visibility !== "hidden" &&
          Number(style.opacity || "1") > 0 &&
          rect.width > 0 &&
          rect.height > 0,
        readyState: document.readyState,
        rect: {
          x: rect.x,
          y: rect.y,
          width: rect.width,
          height: rect.height,
        },
        text: element.innerText?.slice(0, 300) ?? "",
      });
    } catch (error) {
      done({ exists: false, visible: false, error: String(error) });
    }
  }, selector);
}

async function waitForVisible(selector, timeout = 20_000) {
  let latest = null;
  await browser.waitUntil(
    async () => {
      latest = await domState(selector);
      return latest.visible;
    },
    {
      timeout,
      interval: 250,
      timeoutMsg: `WKWebView element did not become visible: ${selector}; state=${JSON.stringify(latest)}`,
    },
  );
  return browser.$(selector);
}

async function isVisible(selector) {
  try {
    return (await domState(selector)).visible;
  } catch {
    return false;
  }
}

async function markOnboardingNextButton() {
  return browser.executeAsync((done) => {
    try {
      document
        .querySelectorAll('[data-wdio-onboarding-next="true"]')
        .forEach((element) => element.removeAttribute("data-wdio-onboarding-next"));
      const button = Array.from(document.querySelectorAll("button")).find(
        (candidate) => candidate.textContent?.trim() === "下一步",
      );
      if (!(button instanceof HTMLElement)) {
        done({ exists: false, visible: false });
        return;
      }
      const style = window.getComputedStyle(button);
      const rect = button.getBoundingClientRect();
      const visible =
        style.display !== "none" &&
        style.visibility !== "hidden" &&
        rect.width > 0 &&
        rect.height > 0;
      if (visible) button.setAttribute("data-wdio-onboarding-next", "true");
      done({ exists: true, visible });
    } catch (error) {
      done({ exists: false, visible: false, error: String(error) });
    }
  });
}

async function finishOnboarding() {
  const nextSelector = '[data-wdio-onboarding-next="true"]';
  for (let index = 0; index < 8; index += 1) {
    const state = await stage(`inspect onboarding step ${index}`, markOnboardingNextButton);
    if (!state.visible) return;

    const next = await stage(`locate onboarding next ${index}`, () => browser.$(nextSelector));
    await stage(`click onboarding next ${index}`, () => next.click());
  }
  throw new Error("Tauri onboarding did not finish within eight steps");
}

describe("packaged Fabushi Tauri app", () => {
  it("drives the real WKWebView login controls", async () => {
    await stage("wait for login gate", () => waitForVisible(selectorForTestId("login-gate")));
    await finishOnboarding();

    if (await stage("inspect login options button", () => isVisible(selectorForTestId("show-login-options")))) {
      const showLoginOptions = await stage("locate login options button", () => testId("show-login-options"));
      await stage("click login options button", () => showLoginOptions.click());
    }

    const passwordToggle = await stage("wait for password login toggle", () =>
      waitForVisible(selectorForTestId("password-login-toggle")),
    );
    await stage("click password login toggle", () => passwordToggle.click());

    const username = await stage("wait for username input", () =>
      waitForVisible(selectorForTestId("login-username")),
    );
    const password = await stage("wait for password input", () =>
      waitForVisible(selectorForTestId("login-password")),
    );

    await stage("type username", () => username.setValue("tauri-wdio-e2e"));
    await stage("type password", () => password.setValue("real-wkwebview-input"));

    assert.equal(await stage("read username", () => username.getValue()), "tauri-wdio-e2e");
    assert.equal(await stage("read password", () => password.getValue()), "real-wkwebview-input");
  });

  it("crosses the real WKWebView to Rust IPC boundary", async () => {
    const result = await browser.executeAsync((done) => {
      const invoke = window.__TAURI__?.core?.invoke;
      if (typeof invoke !== "function") {
        done({ ok: false, error: "window.__TAURI__.core.invoke is unavailable" });
        return;
      }
      invoke("feature_host_auth_status")
        .then((value) => done({ ok: true, value }))
        .catch((error) => done({ ok: false, error: String(error) }));
    });

    assert.equal(result.ok, true, result.error || "Tauri IPC invocation failed");
    assert.equal(typeof result.value?.loggedIn, "boolean");
  });

  it("controls the actual native macOS window through WebDriver", async () => {
    assert.equal(await browser.getTitle(), "发布软件");

    const handles = await browser.getWindowHandles();
    assert.equal(handles.length, 1);
    assert.equal(await browser.getWindowHandle(), handles[0]);

    const initial = await browser.getWindowSize();
    assert.ok(initial.width >= 760, `unexpected initial width: ${initial.width}`);
    assert.ok(initial.height >= 560, `unexpected initial height: ${initial.height}`);

    await browser.setWindowSize(900, 640);
    const resized = await browser.getWindowSize();
    assert.ok(resized.width >= 880, `native window was not resized: ${resized.width}`);
    assert.ok(resized.height >= 620, `native window was not resized: ${resized.height}`);

    await browser.maximizeWindow();
    const maximized = await browser.getWindowSize();
    assert.ok(maximized.width >= resized.width);
    assert.ok(maximized.height >= resized.height);

    await browser.setWindowSize(initial.width, initial.height);
  });
});
