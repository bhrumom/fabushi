import assert from "node:assert/strict";

const selectorForTestId = (id) => `[data-testid="${id}"]`;
const testId = (id) => browser.$(selectorForTestId(id));

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

async function onboardingNextState() {
  return browser.executeAsync((done) => {
    try {
      const button = Array.from(document.querySelectorAll("button")).find(
        (candidate) => candidate.textContent?.trim() === "下一步",
      );
      if (!(button instanceof HTMLElement)) {
        done({ exists: false, visible: false });
        return;
      }
      const style = window.getComputedStyle(button);
      const rect = button.getBoundingClientRect();
      done({
        exists: true,
        visible:
          style.display !== "none" &&
          style.visibility !== "hidden" &&
          rect.width > 0 &&
          rect.height > 0,
      });
    } catch (error) {
      done({ exists: false, visible: false, error: String(error) });
    }
  });
}

async function finishOnboarding() {
  const nextSelector = '//button[normalize-space(.)="下一步"]';
  for (let index = 0; index < 8; index += 1) {
    const state = await onboardingNextState();
    if (!state.visible) return;

    const next = await browser.$(nextSelector);
    await next.click();
  }
  throw new Error("Tauri onboarding did not finish within eight steps");
}

describe("packaged Fabushi Tauri app", () => {
  it("drives the real WKWebView login controls", async () => {
    await waitForVisible(selectorForTestId("login-gate"));
    await finishOnboarding();

    if (await isVisible(selectorForTestId("show-login-options"))) {
      await testId("show-login-options").click();
    }

    const passwordToggle = await waitForVisible(selectorForTestId("password-login-toggle"));
    await passwordToggle.click();

    const username = await waitForVisible(selectorForTestId("login-username"));
    const password = await waitForVisible(selectorForTestId("login-password"));

    await username.setValue("tauri-wdio-e2e");
    await password.setValue("real-wkwebview-input");

    assert.equal(await username.getValue(), "tauri-wdio-e2e");
    assert.equal(await password.getValue(), "real-wkwebview-input");
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
