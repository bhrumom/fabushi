import { expect, test, type Page } from "@playwright/test";
import journeyContract from "../../../contracts/automation/cross-platform-journeys.json" with { type: "json" };
import type {
  MahayanaHostFeature,
  MahayanaHostJourneyStep,
} from "../../../frontend/packages/shared/src/mahayana-host-features";

const mahayanaHostFeatures =
  journeyContract.features as ReadonlyArray<MahayanaHostFeature>;

async function openLoginOptions(page: Page): Promise<void> {
  while (await page.getByTestId("onboarding-gate").isVisible().catch(() => false)) {
    await page.getByRole("button", { name: "下一步" }).click();
  }
  await expect(page.getByTestId("login-gate")).toBeVisible();
  if (await page.getByTestId("show-login-options").isVisible().catch(() => false)) {
    await page.getByTestId("show-login-options").click();
  }
}

async function ensureComputerPanel(page: Page): Promise<void> {
  if (await page.getByTestId("feature-coverage").isVisible().catch(() => false)) return;
  await page.getByRole("button", { name: "大乘助手的电脑" }).click();
  await expect(page.getByTestId("feature-coverage")).toBeVisible();
}

async function runJourneyStep(
  page: Page,
  step: MahayanaHostJourneyStep,
): Promise<void> {
  switch (step.action) {
    case "oauthLogin":
      await openLoginOptions(page);
      await page.getByTestId(`oauth-${step.provider}`).click();
      await expect(page.getByTestId("login-gate")).toBeHidden();
      break;
    case "login":
      await openLoginOptions(page);
      await page.getByTestId("password-login-toggle").click();
      await page.getByTestId("login-username").fill(step.username);
      await page.getByTestId("login-password").fill(step.password);
      await page.getByTestId("login-submit").click();
      await expect(page.getByTestId("login-gate")).toBeHidden();
      break;
    case "expectReady":
      await expect(page.getByTestId("host-status")).toHaveText("ready");
      return;
    case "sendChat":
      await page.getByTestId("chat-input").fill(step.text);
      await page.getByTestId("send-message").click();
      await expect(page.getByTestId("messages")).toContainText(
        step.expectedReply,
      );
      return;
    case "installMiniApp":
      await page.getByTestId("open-marketplace").click();
      await expect(page.getByRole("dialog", { name: "插件市场" })).toBeVisible();
      await page.getByTestId("install-miniapp").click();
      await expect(page.getByTestId("marketplace-state")).toHaveText(
        "installed",
      );
      return;
    case "openMiniApp":
      await page.getByRole("button", { name: "关闭插件市场" }).click();
      await page.getByTestId(`agent-${step.miniAppId}`).click();
      await expect(page.getByTestId("miniapp-panel")).toContainText(
        step.miniAppId,
      );
      await expect(page.getByTestId("miniapp-frame")).toBeVisible();
      return;
    case "approveCapability":
      await page.getByTestId("request-capability").click();
      await expect(page.getByRole("dialog", { name: "能力审批" })).toContainText(
        step.capability,
      );
      await page
        .getByTestId(
          step.decision === "allow-once"
            ? "approve-capability"
            : "deny-capability",
        )
        .click();
      await expect(page.getByTestId("approval-state")).toHaveText(
        step.decision === "allow-once" ? "allowed-once" : "denied",
      );
      return;
    case "interruptOperation":
      await page.getByTestId("start-long-operation").click();
      await expect(page.getByTestId("operation-state")).toHaveText("running");
      await page.getByTestId("interrupt-operation").click();
      await expect(page.getByTestId("operation-state")).toHaveText(
        "interrupted",
      );
      return;
    case "clearSession":
      await page.getByTestId("clear-session").click();
      await expect(page.getByTestId("session-state")).toHaveText("cleared");
      return;
    default: {
      const unhandled: never = step;
      throw new Error(`Unhandled Host journey step: ${JSON.stringify(unhandled)}`);
    }
  }
}

test("Mahayana Host 的所有声明功能可由目录驱动的用户操作完成", async ({
  page,
}) => {
  await page.goto("/");

  for (const feature of mahayanaHostFeatures) {
    await test.step(`${feature.id}: ${feature.label}`, async () => {
      for (const step of feature.steps) {
        await runJourneyStep(page, step);
      }
      await ensureComputerPanel(page);
      await expect(page.getByTestId(`feature-result-${feature.id}`)).toHaveAttribute(
        "data-state",
        "passed",
      );
    });
  }
});

test("所有官方应用复用同一条安装、机器人和 MiniApp 打开旅程", async ({ page }) => {
  const appIds = [
    "global-dharma",
    "faliu-flashcards",
    "platform-publish",
    "hermes-installer",
    "bot-father",
    "chatgpt-auto-confirm",
  ];

  await page.goto("/");
  await openLoginOptions(page);
  await page.getByTestId("password-login-toggle").click();
  await page.getByTestId("login-username").fill("marketplace-fast-e2e");
  await page.getByTestId("login-password").fill("deterministic-test-password");
  await page.getByTestId("login-submit").click();
  await expect(page.getByTestId("host-status")).toHaveText("ready");

  for (const appId of appIds) {
    await test.step(appId, async () => {
      await page.getByTestId("open-marketplace").click();
      const installId = appId === "global-dharma" ? "install-miniapp" : `install-${appId}`;
      await page.getByTestId(installId).click();
      await expect(page.getByTestId(installId)).toBeDisabled();
      await page.getByRole("button", { name: "关闭插件市场" }).click();
      await expect(page.getByTestId(`agent-${appId}`)).toBeVisible();
      await page.getByTestId(`agent-${appId}`).click();
      await expect(page.getByTestId("miniapp-panel")).toContainText(appId);
      await expect(page.getByTestId("miniapp-frame")).toBeVisible();
    });
  }
});
