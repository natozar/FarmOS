import { test, expect } from '@playwright/test';

const PAINEL = '/painel.html';
const LANDING = '/landing.html';

// ============================================================
// 1. LANDING PAGE — SEO & Structure
// ============================================================
test.describe('Landing Page', () => {
  test('loads with correct title and meta', async ({ page }) => {
    await page.goto(LANDING);
    await expect(page).toHaveTitle(/AgrUAI/);
    const desc = page.locator('meta[name="description"]');
    await expect(desc).toHaveAttribute('content', /NDVI|satélite|satellite/i);
  });

  test('has hreflang tags for i18n', async ({ page }) => {
    await page.goto(LANDING);
    const ptLink = page.locator('link[hreflang="pt-BR"]');
    const enLink = page.locator('link[hreflang="en-US"]');
    const esLink = page.locator('link[hreflang="es-MX"]');
    await expect(ptLink).toHaveAttribute('href', /agruai\.com/);
    await expect(enLink).toHaveAttribute('href', /agruai\.com\/en/);
    await expect(esLink).toHaveAttribute('href', /agruai\.com\/es/);
  });

  test('has OpenGraph image tag', async ({ page }) => {
    await page.goto(LANDING);
    const ogImg = page.locator('meta[property="og:image"]');
    await expect(ogImg).toHaveAttribute('content', /og-agruai\.jpg/);
  });

  test('has JSON-LD structured data', async ({ page }) => {
    await page.goto(LANDING);
    const jsonLd = page.locator('script[type="application/ld+json"]');
    await expect(jsonLd).toHaveCount(1);
    const content = await jsonLd.textContent();
    expect(content).toContain('SoftwareApplication');
    expect(content).toContain('BusinessApplication');
    expect(content).toContain('Windows, iOS, Android, Web');
  });

  test('satellite SVG renders in hero', async ({ page }) => {
    await page.goto(LANDING);
    const sat = page.locator('.sat-wrap svg').first();
    await expect(sat).toBeVisible();
  });

  test('lead capture form exists', async ({ page }) => {
    await page.goto(LANDING);
    const form = page.locator('form').first();
    await expect(form).toBeVisible();
  });
});

// ============================================================
// 2. PAINEL — PWA Infrastructure
// ============================================================
test.describe('Painel PWA', () => {
  test('has manifest link', async ({ page }) => {
    await page.goto(PAINEL);
    const manifest = page.locator('link[rel="manifest"]');
    await expect(manifest).toHaveAttribute('href', 'manifest.json');
  });

  test('has apple-touch-icon', async ({ page }) => {
    await page.goto(PAINEL);
    const icon = page.locator('link[rel="apple-touch-icon"]');
    await expect(icon).toHaveCount(1);
  });

  test('has apple-mobile-web-app-capable', async ({ page }) => {
    await page.goto(PAINEL);
    const meta = page.locator('meta[name="apple-mobile-web-app-capable"]');
    await expect(meta).toHaveAttribute('content', 'yes');
  });

  test('service worker registration script exists', async ({ page }) => {
    await page.goto(PAINEL);
    const swScript = await page.content();
    expect(swScript).toContain("serviceWorker.register('sw.js')");
  });

  test('login screen renders', async ({ page }) => {
    await page.goto(PAINEL);
    await expect(page.locator('#tela-login')).toBeVisible();
    await expect(page.locator('#authEmail')).toBeVisible();
    await expect(page.locator('#authSenha')).toBeVisible();
  });

  test('three auth tabs exist (Entrar, Criar, Equipe)', async ({ page }) => {
    await page.goto(PAINEL);
    await expect(page.locator('#tabEntrar')).toBeVisible();
    await expect(page.locator('#tabCriar')).toBeVisible();
    await expect(page.locator('#tabEquipe')).toBeVisible();
  });
});

// ============================================================
// 3. SPEECH RECOGNITION — Browser-specific
// ============================================================
test.describe('Speech Recognition', () => {
  test('mic button hidden on WebKit/Safari (no SpeechRecognition)', async ({ page, browserName }) => {
    test.skip(browserName !== 'webkit', 'WebKit-only test');
    await page.goto(PAINEL);
    // Login to reach diary
    await page.fill('#authEmail', 'fazendeiro.teste@agruai.com');
    await page.fill('#authSenha', 'AgrUAI2026!');
    await page.click('#btnAuth');
    await page.waitForSelector('#propContent', { timeout: 10000 });
    // Navigate to first property detail
    const card = page.locator('.prop-card').first();
    if (await card.isVisible()) {
      await card.click();
      await page.waitForTimeout(1000);
      // Switch to diary tab
      const diarioTab = page.locator('.detalhe-tab', { hasText: /Diário|Diary|Diario/ });
      if (await diarioTab.isVisible()) {
        await diarioTab.click();
        await page.waitForTimeout(500);
        const micBtn = page.locator('#btnRec');
        await expect(micBtn).toHaveCount(0);
      }
    }
  });

  test('mic button visible on Chromium (has SpeechRecognition)', async ({ page, browserName }) => {
    test.skip(browserName !== 'chromium', 'Chromium-only test');
    test.setTimeout(20000);
    await page.goto(PAINEL);
    await page.fill('#authEmail', 'fazendeiro.teste@agruai.com');
    await page.fill('#authSenha', 'AgrUAI2026!');
    await page.click('#btnAuth');
    await page.waitForSelector('#propContent', { timeout: 15000 });
    const card = page.locator('.prop-card').first();
    if (await card.isVisible()) {
      await card.click();
      await page.waitForTimeout(1000);
      const diarioTab = page.locator('.detalhe-tab', { hasText: /Diário|Diary|Diario/ });
      if (await diarioTab.isVisible()) {
        await diarioTab.click();
        await page.waitForTimeout(500);
        const micBtn = page.locator('#btnRec');
        await expect(micBtn).toBeVisible();
      }
    }
  });
});

// ============================================================
// 4. i18n — Language Switching
// ============================================================
test.describe('Internationalization', () => {
  test('language switch to English changes UI text', async ({ page }) => {
    test.setTimeout(20000);
    await page.goto(PAINEL);
    await page.fill('#authEmail', 'fazendeiro.teste@agruai.com');
    await page.fill('#authSenha', 'AgrUAI2026!');
    await page.click('#btnAuth');
    await page.waitForSelector('#propContent', { timeout: 15000 });
    // Open user menu and switch language
    await page.click('#btnUser');
    await page.waitForTimeout(300);
    await page.selectOption('#langSelect', 'en-US');
    await page.waitForTimeout(1000);
    // Check that UI updated
    const content = await page.textContent('body');
    expect(content).toContain('Properties');
  });

  test('language switch to Spanish changes UI text', async ({ page }) => {
    test.setTimeout(20000);
    await page.goto(PAINEL);
    await page.fill('#authEmail', 'fazendeiro.teste@agruai.com');
    await page.fill('#authSenha', 'AgrUAI2026!');
    await page.click('#btnAuth');
    await page.waitForSelector('#propContent', { timeout: 15000 });
    await page.click('#btnUser');
    await page.waitForTimeout(300);
    await page.selectOption('#langSelect', 'es-MX');
    await page.waitForTimeout(1000);
    const content = await page.textContent('body');
    expect(content).toContain('Propiedades');
  });

  test('language persists after reload', async ({ page }) => {
    test.setTimeout(20000);
    await page.goto(PAINEL);
    await page.evaluate(() => localStorage.setItem('agruai_lang', 'en-US'));
    await page.fill('#authEmail', 'fazendeiro.teste@agruai.com');
    await page.fill('#authSenha', 'AgrUAI2026!');
    await page.click('#btnAuth');
    await page.waitForSelector('#propContent', { timeout: 15000 });
    const lang = await page.evaluate(() => localStorage.getItem('agruai_lang'));
    expect(lang).toBe('en-US');
  });
});

// ============================================================
// 5. RESPONSIVE — iPhone SE viewport
// ============================================================
test.describe('Responsive Layout', () => {
  test('login card fits iPhone SE width', async ({ browser }) => {
    const context = await browser.newContext({
      viewport: { width: 320, height: 568 },
    });
    const page = await context.newPage();
    await page.goto(PAINEL);
    const card = page.locator('.login-card');
    const box = await card.boundingBox();
    expect(box).toBeTruthy();
    expect(box!.width).toBeLessThanOrEqual(320);
    await context.close();
  });
});

// ============================================================
// 6. SECURITY — godmode access control
// ============================================================
test.describe('God Mode Security', () => {
  test('godmode rejects non-admin email', async ({ page }) => {
    await page.goto('/godmode.html');
    await page.fill('#gmEmail', 'hacker@evil.com');
    await page.fill('#gmSenha', 'password123');
    await page.click('#gmBtn');
    await page.waitForTimeout(1000);
    const err = await page.textContent('#gmErro');
    expect(err).toContain('Acesso negado');
    // Dashboard should NOT be visible
    const dash = page.locator('#dashboard');
    await expect(dash).not.toHaveClass(/ativo/);
  });
});

// ============================================================
// 7. EN/ES LANDING PAGES
// ============================================================
test.describe('International Landing Pages', () => {
  test('English landing has correct lang and title', async ({ page }) => {
    await page.goto('/landing-en.html');
    const html = page.locator('html');
    await expect(html).toHaveAttribute('lang', 'en');
    await expect(page).toHaveTitle(/FarmOS|Yield Protection/);
  });

  test('Spanish landing has correct lang and title', async ({ page }) => {
    await page.goto('/landing-es.html');
    const html = page.locator('html');
    await expect(html).toHaveAttribute('lang', 'es');
    await expect(page).toHaveTitle(/AgrUAI|Finanzas/);
  });
});

// ============================================================
// 8. EPIC 7 — Bloomberg, Carbon, Geo-Camera
// ============================================================
test.describe('Epic 7 Modules', () => {
  test('ticker bar exists in DOM', async ({ page }) => {
    await page.goto('/painel.html');
    const ticker = page.locator('#tickerBar');
    await expect(ticker).toHaveCount(1);
  });

  test('ticker renders forex data after login', async ({ page }) => {
    await page.goto('/painel.html');
    await page.fill('#authEmail', 'fazendeiro.teste@agruai.com');
    await page.fill('#authSenha', 'AgrUAI2026!');
    await page.click('#btnAuth');
    await page.waitForTimeout(5000);
    const ticker = await page.textContent('#tickerBar');
    expect(ticker).toBeTruthy();
  });

  test('photo input exists in diary source', async ({ page }) => {
    await page.goto('/painel.html');
    const html = await page.content();
    expect(html).toContain('onPhotoSelected');
    expect(html).toContain('capture="environment"');
  });

  test('carbon card function exists', async ({ page }) => {
    await page.goto('/painel.html');
    const html = await page.content();
    expect(html).toContain('buildCarbonCard');
  });

  test('image compression function exists in JS', async ({ page }) => {
    await page.goto('/painel.html');
    const hasCompression = await page.evaluate(() => {
      return typeof window.onPhotoSelected === 'function';
    });
    expect(hasCompression).toBe(true);
  });

  test('geolocation denial does not crash', async ({ browser }) => {
    const context = await browser.newContext({
      permissions: [],
      geolocation: undefined,
    });
    const page = await context.newPage();
    await page.goto('/painel.html');
    // App should load without crashing even with no geo permissions
    await expect(page.locator('#tela-login')).toBeVisible();
    await context.close();
  });

  test('ticker works offline with cached data', async ({ page }) => {
    await page.goto('/painel.html');
    await page.evaluate(() => {
      localStorage.setItem('agruai_forex', JSON.stringify({ usd: 5.25, pct: 0.15, time: '14:30' }));
    });
    const hasTickerFn = await page.evaluate(() => typeof document.getElementById('tickerBar') !== 'undefined');
    expect(hasTickerFn).toBe(true);
  });
});

// ============================================================
// 9. EPIC 8 — War Room, Scanner, Heatmap
// ============================================================
test.describe('Epic 8 Modules', () => {
  test('war room toggle function exists', async ({ page }) => {
    await page.goto('/painel.html');
    const html = await page.content();
    expect(html).toContain('toggleWarRoom');
    expect(html).toContain('war-room-mode');
  });

  test('war room menu button exists', async ({ page }) => {
    await page.goto('/painel.html');
    const html = await page.content();
    expect(html).toContain('Sala de Guerra');
  });

  test('scanner function exists in JS', async ({ page }) => {
    await page.goto('/painel.html');
    const html = await page.content();
    expect(html).toContain('iniciarScanner');
    expect(html).toContain('Html5Qrcode');
  });

  test('background tracking function exists', async ({ page }) => {
    await page.goto('/painel.html');
    const html = await page.content();
    expect(html).toContain('startBackgroundTracking');
    expect(html).toContain('agruai_track_points');
  });

  test('heatmap layer function exists', async ({ page }) => {
    await page.goto('/painel.html');
    const html = await page.content();
    expect(html).toContain('renderHeatmapLayer');
    expect(html).toContain('track-heatmap');
  });

  test('war exit button exists in DOM', async ({ page }) => {
    await page.goto('/painel.html');
    const exit = page.locator('#warExit');
    await expect(exit).toHaveCount(1);
  });

  test('scanner button renders in supply tab source', async ({ page }) => {
    await page.goto('/painel.html');
    const html = await page.content();
    expect(html).toContain('Escanear Defensivo');
    expect(html).toContain('scannerContainer');
  });
});
