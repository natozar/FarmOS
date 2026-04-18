import { test, expect, Page } from '@playwright/test';

const GESTOR_EMAIL = 'teste@agruai.com';
const GESTOR_SENHA = 'gestor2026';

async function loginComoGestor(page: Page) {
  await page.goto('/painel.html');
  // Dismiss service worker cache of older painel by forcing reload
  await page.waitForLoadState('domcontentloaded');

  // The login card must be visible
  await expect(page.locator('.login-card')).toBeVisible({ timeout: 10000 });

  // Enter credentials (default tab is "Entrar")
  await page.locator('#authEmail').fill(GESTOR_EMAIL);
  await page.locator('#authSenha').fill(GESTOR_SENHA);
  await page.locator('#btnAuth').click();

  // Propriedades screen should show within a reasonable time
  await expect(page.locator('#tela-propriedades.ativo')).toBeVisible({ timeout: 15000 });
}

test.describe('Landing & painel públicos', () => {
  test('landing carrega em /', async ({ page }) => {
    const res = await page.goto('/');
    expect(res?.status()).toBeLessThan(400);
    await expect(page).toHaveTitle(/AgrUAI/i);
  });

  test('painel.html mostra card de login', async ({ page }) => {
    await page.goto('/painel.html');
    await expect(page.locator('.login-card')).toBeVisible();
    await expect(page.locator('#authEmail')).toBeVisible();
    await expect(page.locator('#btnAuth')).toBeVisible();
  });

  test('rewrites de alias respondem 200 (não 404)', async ({ request }) => {
    for (const path of ['/app', '/painel', '/entrar', '/fazenda', '/index.html']) {
      const res = await request.get(path);
      expect(res.status(), `alias ${path} deve servir algo, não 404`).toBeLessThan(400);
    }
  });
});

test.describe('Login do gestor e visão das propriedades', () => {
  test('loga e vê Fazenda Santa Cruz com badge de Gestor', async ({ page }) => {
    await loginComoGestor(page);

    // Espera a lista carregar (spinner pode estar presente brevemente)
    const santaCruz = page.locator('.prop-card', { hasText: 'Fazenda Santa Cruz' });
    await expect(santaCruz).toBeVisible({ timeout: 15000 });

    // Badge de gestor (texto "Gestor" no card)
    await expect(santaCruz).toContainText(/Gestor/i);
  });

  test('abre detalhe da fazenda e vê aba Diário com timeline', async ({ page }) => {
    await loginComoGestor(page);
    const santaCruz = page.locator('.prop-card', { hasText: 'Fazenda Santa Cruz' });
    await santaCruz.click();
    await expect(page.locator('#tela-detalhe.ativo')).toBeVisible({ timeout: 10000 });

    // Clica na aba Diário
    await page.getByRole('button', { name: 'Diário' }).click();
    await expect(page.locator('#panelDiario.ativo')).toBeVisible();

    // Timeline deve carregar (spinner some, items ou "nenhum registro")
    const timeline = page.locator('#timelineContainer');
    await expect(timeline).toBeVisible();
    await expect(timeline.locator('.timeline-item, .timeline-empty').first()).toBeVisible({ timeout: 15000 });
  });

  test('aba Equipe NÃO aparece pro gestor (só pro dono)', async ({ page }) => {
    await loginComoGestor(page);
    await page.locator('.prop-card', { hasText: 'Fazenda Santa Cruz' }).click();
    await expect(page.locator('#tela-detalhe.ativo')).toBeVisible();

    const abaEquipe = page.getByRole('button', { name: /^Equipe$/ });
    await expect(abaEquipe).toHaveCount(0);
  });
});

test.describe('Área do Gestor (sandbox)', () => {
  test('menu do usuário tem o atalho e a tela abre com as 3 seções', async ({ page }) => {
    await loginComoGestor(page);

    // Abre o menu do usuário
    await page.locator('#btnUser').click();
    const gestorBtn = page.getByRole('button', { name: /Área do Gestor/i });
    await expect(gestorBtn).toBeVisible();
    await gestorBtn.click();

    await expect(page.locator('#tela-gestor.ativo')).toBeVisible();

    // Confere as 3 seções pelo título (IA foi removida — é ferramenta do fazendeiro)
    await expect(page.getByText(/Foto \(câmera\)/)).toBeVisible();
    await expect(page.getByText(/Imagem \(galeria\)/)).toBeVisible();
    await expect(page.getByText(/Áudio \+ Transcrição/)).toBeVisible();
    await expect(page.getByText(/Sugestões da IA/)).toHaveCount(0);
  });
});

test.describe('Regressão: bottom nav não cobre conteúdo (fix b354c7c)', () => {
  test('último card da lista fica acima da bottom nav no mobile', async ({ page, viewport }) => {
    await loginComoGestor(page);
    await expect(page.locator('.prop-card').first()).toBeVisible();

    // Scroll instantâneo até o fim (evita smooth-scroll animation do CSS)
    await page.evaluate(() => window.scrollTo({ top: document.body.scrollHeight, behavior: 'instant' as ScrollBehavior }));
    await page.waitForTimeout(200);

    const nav = page.locator('.bottom-nav');
    await expect(nav).toBeVisible();

    // Usa o último elemento do content (pode ser o botão "+ Cadastrar") pra garantir que nada do final fica coberto
    const lastChild = page.locator('#propContent > *').last();
    await expect(lastChild).toBeVisible();

    const navBox = await nav.boundingBox();
    const lastBox = await lastChild.boundingBox();
    if (navBox && lastBox) {
      // O topo da nav deve ficar abaixo do fim do último elemento (sem sobreposição)
      expect(navBox.y).toBeGreaterThanOrEqual(lastBox.y + lastBox.height - 4);
    }
  });
});
