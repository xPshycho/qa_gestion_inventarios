import { expect, test } from '@playwright/test';
import { loginAs, viewerUser } from '../helpers/auth';

test('mantiene usable el catalogo en viewport movil', async ({
  page,
}, testInfo) => {
  await loginAs(page, viewerUser);
  await page.goto('/productos');

  await expect(
    page.getByRole('heading', { name: 'Catálogo de inventario' }),
  ).toBeVisible();
  await expect(page.getByLabel('Búsqueda por nombre o SKU')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Actualizar' })).toBeVisible();
  await expect(page.getByRole('navigation', { name: 'Módulos principales' }))
    .toBeVisible();

  const hasHorizontalOverflow = await page.evaluate(() => (
    document.documentElement.scrollWidth > document.documentElement.clientWidth
  ));
  expect(hasHorizontalOverflow).toBeFalsy();

  await testInfo.attach('catalogo-movil', {
    body: await page.screenshot({ fullPage: true }),
    contentType: 'image/png',
  });
});
