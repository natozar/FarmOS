import { test, expect } from '@playwright/test';

const PAINEL = '/painel.html';
const EMAIL = 'fazendeiro.teste@agruai.com';
const PASS = 'AgrUAI2026!';

async function loginAndWait(page: any) {
  await page.goto(PAINEL);
  await page.fill('#authEmail', EMAIL);
  await page.fill('#authSenha', PASS);
  await page.click('#btnAuth');
  await page.waitForSelector('.prop-card,.empty-state,.page-title', { timeout: 15000 });
}

// ============================================================
// CONSOLE ERROR AUDIT
// ============================================================
test.describe('Console Error Audit', () => {
  test('no critical JS errors on login', async ({ page }) => {
    test.setTimeout(25000);
    const errors: string[] = [];
    page.on('pageerror', (err) => errors.push(err.message));
    await loginAndWait(page);
    await page.waitForTimeout(2000);
    const critical = errors.filter(e =>
      !e.includes('service-worker') && !e.includes('Failed to fetch') &&
      !e.includes('NetworkError') && !e.includes('Load failed') &&
      !e.includes('AbortError') && !e.includes('NotAllowedError'));
    expect(critical).toEqual([]);
  });
});

// ============================================================
// NETWORK 403/401 AUDIT (RLS)
// ============================================================
test.describe('RLS Permission Audit', () => {
  test('no 403 from Supabase after login', async ({ page }) => {
    test.setTimeout(25000);
    const forbidden: string[] = [];
    page.on('response', (res) => {
      if (res.url().includes('supabase.co') && res.status() === 403) {
        forbidden.push(`403 ${res.url().split('/').pop()?.split('?')[0]}`);
      }
    });
    await loginAndWait(page);
    await page.waitForTimeout(3000);
    expect(forbidden).toEqual([]);
  });

  test('telemetry 500 is silently caught (table may not exist)', async ({ page }) => {
    test.setTimeout(25000);
    // This test verifies the app does NOT crash even if telemetry table is missing
    const crashes: string[] = [];
    page.on('pageerror', (err) => crashes.push(err.message));
    await loginAndWait(page);
    await page.waitForTimeout(3000);
    const critical = crashes.filter(e => !e.includes('fetch') && !e.includes('Network'));
    expect(critical).toEqual([]);
  });
});

// ============================================================
// CORS AUDIT
// ============================================================
test.describe('CORS Audit', () => {
  test('AwesomeAPI forex no CORS block', async ({ page }) => {
    test.setTimeout(20000);
    const corsErrors: string[] = [];
    page.on('pageerror', (err) => {
      if (err.message.toLowerCase().includes('cors')) corsErrors.push(err.message);
    });
    await loginAndWait(page);
    await page.waitForTimeout(4000);
    expect(corsErrors).toEqual([]);
  });

  test('Mapbox tiles load clean', async ({ page }) => {
    test.setTimeout(20000);
    const corsErrors: string[] = [];
    page.on('pageerror', (err) => {
      if (err.message.toLowerCase().includes('cors') && err.message.includes('mapbox'))
        corsErrors.push(err.message);
    });
    await loginAndWait(page);
    await page.click('a[href="#mapa"]');
    await page.waitForTimeout(3000);
    expect(corsErrors).toEqual([]);
  });
});

// ============================================================
// OFFLINE RESILIENCE
// ============================================================
test.describe('Offline Resilience', () => {
  test('offline bar appears when connection drops', async ({ page, context }) => {
    test.setTimeout(25000);
    await loginAndWait(page);
    await context.setOffline(true);
    await page.waitForTimeout(500);
    const bar = page.locator('#offlineBar');
    const isVisible = await bar.evaluate(el => el.classList.contains('visivel'));
    expect(isVisible).toBe(true);
    await context.setOffline(false);
    await page.waitForTimeout(1000);
    const isHidden = await bar.evaluate(el => !el.classList.contains('visivel'));
    expect(isHidden).toBe(true);
  });
});

// ============================================================
// UNHANDLED PROMISE REJECTION AUDIT
// ============================================================
test.describe('Promise Audit', () => {
  test('no unhandled rejections on app lifecycle', async ({ page }) => {
    test.setTimeout(20000);
    const rejections: string[] = [];
    page.on('pageerror', (err) => {
      if (err.message.includes('Unhandled') || err.message.includes('rejection'))
        rejections.push(err.message);
    });
    await loginAndWait(page);
    await page.waitForTimeout(2000);
    expect(rejections).toEqual([]);
  });
});
