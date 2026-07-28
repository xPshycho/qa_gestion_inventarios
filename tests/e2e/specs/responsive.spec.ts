import { expect, Page, test, TestInfo } from '@playwright/test';
import { adminUser, loginAs } from '../helpers/auth';

interface ResponsiveView {
  heading: string;
  name: string;
  route: string;
}

async function verifyResponsiveView(
  page: Page,
  testInfo: TestInfo,
  view: ResponsiveView,
): Promise<void> {
  await page.goto(view.route);
  await expect(page.getByRole('heading', { name: view.heading, exact: true }))
    .toBeVisible();
  await expect(page.locator('mat-progress-bar')).toHaveCount(0);

  const layout = await page.evaluate(() => {
    const viewportWidth = window.innerWidth;
    const documentWidth = Math.max(
      document.documentElement.scrollWidth,
      document.body.scrollWidth,
    );
    const main = document.querySelector<HTMLElement>('#main-content');
    const header = document.querySelector<HTMLElement>('.application-header');
    const mainRect = main?.getBoundingClientRect() ?? null;
    const headerRect = header?.getBoundingClientRect() ?? null;

    return {
      viewport: { width: viewportWidth, height: window.innerHeight },
      documentWidth,
      hasDocumentOverflow: documentWidth > viewportWidth + 1,
      mainInsideViewport: Boolean(
        mainRect
        && mainRect.left >= -1
        && mainRect.right <= viewportWidth + 1
        && mainRect.width > 0,
      ),
      headerInsideViewport: !headerRect || (
        headerRect.left >= -1
        && headerRect.right <= viewportWidth + 1
        && headerRect.width > 0
      ),
      headerOverlapsMain: Boolean(
        headerRect
        && mainRect
        && window.scrollY === 0
        && mainRect.top < headerRect.bottom - 1,
      ),
    };
  });

  const evidence = {
    generatedAt: new Date().toISOString(),
    project: testInfo.project.name,
    screen: view.name,
    url: page.url(),
    ...layout,
  };
  await testInfo.attach(`responsive-${testInfo.project.name}-${view.name}`, {
    body: Buffer.from(JSON.stringify(evidence, null, 2)),
    contentType: 'application/json',
  });
  await testInfo.attach(`responsive-${testInfo.project.name}-${view.name}`, {
    body: await page.screenshot({ fullPage: true }),
    contentType: 'image/png',
  });

  expect(layout.hasDocumentOverflow, JSON.stringify(evidence, null, 2)).toBeFalsy();
  expect(layout.mainInsideViewport, JSON.stringify(evidence, null, 2)).toBeTruthy();
  expect(layout.headerInsideViewport, JSON.stringify(evidence, null, 2)).toBeTruthy();
  expect(layout.headerOverlapsMain, JSON.stringify(evidence, null, 2)).toBeFalsy();
}

test('valida login y vistas críticas sin overflow ni solapamientos', async ({
  page,
}, testInfo) => {
  await verifyResponsiveView(page, testInfo, {
    name: 'login',
    route: '/login',
    heading: 'Gestión de inventarios',
  });

  await loginAs(page, adminUser);
  await page.goto('/productos');
  await expect(page.getByRole('heading', { name: 'Catálogo de inventario' }))
    .toBeVisible();
  const stockRoute = await page.getByRole('link', { name: 'Movimientos' })
    .first()
    .getAttribute('href');
  const auditRoute = await page.getByRole('link', { name: 'Auditoría' })
    .first()
    .getAttribute('href');
  expect(stockRoute).toBeTruthy();
  expect(auditRoute).toBeTruthy();

  const views: ResponsiveView[] = [
    { name: 'dashboard', route: '/dashboard', heading: 'Inventario operativo' },
    { name: 'productos', route: '/productos', heading: 'Catálogo de inventario' },
    { name: 'stock', route: stockRoute!, heading: 'Movimientos de stock' },
    { name: 'auditoria', route: auditRoute!, heading: 'Historial de producto y stock' },
    { name: 'seguridad', route: '/seguridad', heading: 'Usuarios, roles y permisos' },
  ];

  for (const view of views) {
    await verifyResponsiveView(page, testInfo, view);
  }
});
