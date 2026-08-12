import { expect, test } from "@playwright/test";

test("Mahayana Host 的所有声明功能可由用户操作完成", async ({ page }) => {
  await page.goto("/host");
  await expect(page.getByTestId("host-status")).toHaveText("ready");

  await page.getByTestId("chat-input").fill("验证极速自动化测试");
  await page.getByTestId("send-message").click();
  await expect(page.getByTestId("messages")).toContainText(
    "收到：验证极速自动化测试",
  );

  await page.getByTestId("install-miniapp").click();
  await expect(page.getByTestId("marketplace-state")).toHaveText("installed");

  await page.getByTestId("open-miniapp").click();
  await expect(page.getByTestId("miniapp-panel")).toBeVisible();

  await page.getByTestId("request-capability").click();
  await expect(page.getByRole("dialog", { name: "能力审批" })).toBeVisible();
  await page.getByTestId("approve-capability").click();
  await expect(page.getByTestId("approval-state")).toHaveText("allowed");

  await page.getByTestId("start-long-operation").click();
  await expect(page.getByTestId("operation-state")).toHaveText("running");
  await page.getByTestId("interrupt-operation").click();
  await expect(page.getByTestId("operation-state")).toHaveText("interrupted");

  await page.getByTestId("clear-session").click();
  await expect(page.getByTestId("session-state")).toHaveText("cleared");

  const featureResults = page.locator('[data-testid^="feature-result-"]');
  const featureCount = await featureResults.count();
  expect(featureCount).toBeGreaterThanOrEqual(7);
  for (let index = 0; index < featureCount; index += 1) {
    await expect(featureResults.nth(index)).toHaveAttribute("data-state", "passed");
  }
});
