import { expect, test, type Page } from "@playwright/test";
import journeyContract from "../../../contracts/automation/cross-platform-journeys.json" with { type: "json" };
import type {
  MahayanaHostFeature,
  MahayanaHostJourneyStep,
} from "../../../frontend/packages/shared/src/mahayana-host-features";

const mahayanaHostFeatures =
  journeyContract.features as ReadonlyArray<MahayanaHostFeature>;

async function runJourneyStep(
  page: Page,
  step: MahayanaHostJourneyStep,
): Promise<void> {
  switch (step.action) {
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
      await page.getByTestId("open-miniapp").click();
      await expect(page.getByTestId("miniapp-panel")).toContainText(
        step.miniAppId,
      );
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
        step.decision === "allow-once" ? "allowed" : "denied",
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
      await expect(page.getByTestId(`feature-result-${feature.id}`)).toHaveAttribute(
        "data-state",
        "passed",
      );
    });
  }
});
