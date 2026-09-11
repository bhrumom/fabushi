import { expect, test, type Page, type TestInfo } from '@playwright/test';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const repository = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const surfaceModule = '/@fs' + repository + '/frontend/apps/web/src/lib/app-agent-surface/dom-agent-surface.ts';

async function call(page: Page, operation: string, input: Record<string, unknown> = {}): Promise<any> {
  return page.evaluate(async ({ modulePath, operation, input }) => {
    const module = await import(/* @vite-ignore */ modulePath);
    return module.installFabushiDomAppSurface().surface.call(operation, input);
  }, { modulePath: surfaceModule, operation, input });
}

async function checkpoint(page: Page, info: TestInfo, label: string): Promise<void> {
  await info.attach(label + '.png', { body: await page.screenshot({ fullPage: true }), contentType: 'image/png' });
  await info.attach(label + '.json', {
    body: JSON.stringify(await call(page, 'snapshot', { maxElements: 500 }), null, 2),
    contentType: 'application/json',
  });
}

async function ready(page: Page): Promise<void> {
  // An isolated browser is not allowed to contact payment/auth/production services.
  await page.route('**/*', route => {
    const url = new URL(route.request().url());
    return url.origin === 'http://127.0.0.1:1420' ? route.continue() : route.abort('blockedbyclient');
  });
  await page.goto('/');
  const phase = () => page.evaluate(() => {
    if (document.querySelector('[data-testid="onboarding-gate"]')) return 'onboarding';
    if (document.querySelector('[data-testid="login-gate"]')) return 'login';
    return document.querySelector('[data-testid="messenger-workspace"]')
      ?.getAttribute('data-initial-host-hydrated') === 'true' ? 'ready' : 'waiting';
  });
  for (let step = 0; step < 12; step += 1) {
    await expect.poll(phase).not.toBe('waiting');
    const state = await phase();
    if (state === 'ready') break;
    if (state === 'onboarding') await page.getByTestId('onboarding-next').click();
    else throw new Error('Presentation fixture unexpectedly requires login; do not fabricate authentication');
  }
  await expect(page.getByTestId('messenger-workspace')).toHaveAttribute('data-initial-host-hydrated', 'true');
  await expect(page.getByTestId('messenger-workspace')).toBeVisible();
}

test('real renderer hydrates and exposes masked semantic state without an App package', async ({ page }, info) => {
  await ready(page);
  const status = await call(page, 'status');
  expect(status.available).toBe(true);
  expect(status.generation).toBeGreaterThan(0);
  const snapshot = await call(page, 'snapshot', { maxElements: 500 });
  expect(snapshot.elements.length).toBeGreaterThan(0);
  expect(snapshot.elements.some((element: any) => element.sensitive && element.value !== undefined)).toBe(false);
  await checkpoint(page, info, '01-hydrated-real-renderer');
});

test('semantic actions reach the actual profile UI and stale actions fail closed', async ({ page }, info) => {
  await ready(page);
  await expect(page.getByTestId('profile-navigation-trigger')).toBeVisible();
  await checkpoint(page, info, '01-before-profile');
  // Find and invoke in one browser evaluation, avoiding an unrelated DOM mutation between RPCs.
  const action = await page.evaluate(async modulePath => {
    const module = await import(/* @vite-ignore */ modulePath);
    const surface = module.installFabushiDomAppSurface().surface;
    const found = await surface.call('find', { agentId: 'test:profile-navigation-trigger' });
    if (found.count !== 1) throw new Error('profile target must be unique');
    return surface.call('action', { agentId: 'test:profile-navigation-trigger', generation: found.generation, action: 'invoke' });
  }, surfaceModule);
  expect(action.status).toBe('completed');
  await expect(page.getByTestId('profile-navigation-menu')).toBeVisible();
  expect((await call(page, 'assert', { agentId: 'test:profile-navigation-menu', state: 'visible' })).passed).toBe(true);
  await checkpoint(page, info, '02-profile-open');
  await expect(call(page, 'action', { agentId: 'test:profile-navigation-trigger', generation: 0, action: 'invoke' }))
    .rejects.toThrow(/stale_app_surface_generation/);
  await expect(page.getByTestId('profile-navigation-menu')).toBeVisible();
});

test('missing semantic targets and unmet conditions never report success', async ({ page }, info) => {
  await ready(page);
  expect((await call(page, 'find', { agentId: 'test:fcm-intentionally-absent' })).count).toBe(0);
  expect((await call(page, 'assert', { agentId: 'test:fcm-intentionally-absent', state: 'visible' })).passed).toBe(false);
  await expect(call(page, 'unsupported-operation')).rejects.toThrow(/unsupported_app_surface_operation/);
  await checkpoint(page, info, '01-negative-semantics');
});
