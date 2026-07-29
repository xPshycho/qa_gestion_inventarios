import { expect, Page, test } from '@playwright/test';
import { adminUser, loginAs } from '../helpers/auth';

async function visit(page: Page, route: string, heading: string): Promise<void> {
  await page.goto(route);
  await expect(page.getByRole('heading', { name: heading, exact: true }))
    .toBeVisible();
  await expect(page.locator('mat-progress-bar')).toHaveCount(0);
}

test('mantiene operables las vistas críticas en el motor del navegador', async ({
  page,
  browserName,
}, testInfo) => {
  await visit(page, '/login', 'Gestión de inventarios');
  await loginAs(page, adminUser);
  await visit(page, '/productos', 'Catálogo de inventario');

  const stockRoute = await page.getByRole('link', { name: 'Movimientos' })
    .first()
    .getAttribute('href');
  const auditRoute = await page.getByRole('link', { name: 'Auditoría' })
    .first()
    .getAttribute('href');
  expect(stockRoute).toBeTruthy();
  expect(auditRoute).toBeTruthy();

  const views = [
    ['/dashboard', 'Inventario operativo'],
    ['/productos', 'Catálogo de inventario'],
    [stockRoute!, 'Movimientos de stock'],
    [auditRoute!, 'Historial de producto y stock'],
    ['/seguridad', 'Usuarios, roles y permisos'],
  ] as const;

  for (const [route, heading] of views) {
    await visit(page, route, heading);
  }

  await testInfo.attach(`browser-${browserName}-screens`, {
    body: Buffer.from(JSON.stringify({
      generatedAt: new Date().toISOString(),
      browserName,
      project: testInfo.project.name,
      result: 'passed',
      screens: ['login', 'dashboard', 'productos', 'stock', 'auditoria', 'seguridad'],
    }, null, 2)),
    contentType: 'application/json',
  });
  await testInfo.attach(`browser-${browserName}-seguridad`, {
    body: await page.screenshot({ animations: 'disabled' }),
    contentType: 'image/png',
  });
});
