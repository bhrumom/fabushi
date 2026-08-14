import assert from "node:assert/strict";

const testId = (id) => browser.$(`[data-testid="${id}"]`);

async function isDisplayed(element) {
  try {
    return (await element.isExisting()) && (await element.isDisplayed());
  } catch {
    return false;
  }
}

async function finishOnboarding() {
  for (let index = 0; index < 8; index += 1) {
    const next = await browser.$('//button[normalize-space(.)="下一步"]');
    if (!(await isDisplayed(next))) return;
    await next.click();
  }
  throw new Error("Tauri onboarding did not finish within eight steps");
}

describe("packaged Fabushi Tauri app", () => {
  it("drives the real WKWebView login controls", async () => {
    const loginGate = await testId("login-gate");
    await loginGate.waitForDisplayed({ timeout: 30_000 });

    await finishOnboarding();

    const showLoginOptions = await testId("show-login-options");
    if (await isDisplayed(showLoginOptions)) {
      await showLoginOptions.click();
    }

    const passwordToggle = await testId("password-login-toggle");
    await passwordToggle.waitForDisplayed();
    await passwordToggle.click();

    const username = await testId("login-username");
    const password = await testId("login-password");
    await username.waitForDisplayed();
    await password.waitForDisplayed();

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
