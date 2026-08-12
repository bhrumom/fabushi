import { expect, test, type Page } from "@playwright/test";
import {
  mahayanaHostFeatures,
  type MahayanaHostJourneyStep,
} from "../../../frontend/packages/shared/src/mahayana-host-features";

async function runJourneyStep(
  page: Page,
  step: MahayanaHostJourneyStep,
): Promise<void> {
  switch (step.action) {
    case "expectText":
      await expect(page.getByTestId(step.testId)).toHaveText(step.text);
      return;
    case "expectContainsText":
      await expect(page.getByTestId(step.testId)).toContainText(step.text);
      return;
    case "fill":
      await page.getByTestId(step.testId).fill(step.value);
      return;
    case "click":
      await page.getByTestId(step.testId).click();
      return;
    case "expectVisible":
      await expect(page.getByTestId(step.testId)).toBeVisible();
      return;
    case "expectDialog":
      await expect(page.getByRole("dialog", { name: step.name })).toBeVisible();
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
  await page.goto("/host");

  for (const feature of mahayanaHostFeatures) {
    await test.step(`${feature.id}: ${feature.label}`, async () => {
      for (const step of feature.journey) {
        await runJourneyStep(page, step);
      }
      await expect(page.getByTestId(`feature-result-${feature.id}`)).toHaveAttribute(
        "data-state",
        "passed",
      );
    });
  }
});
