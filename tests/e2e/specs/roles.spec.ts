import { expect, test } from '@playwright/test';
import { loginAs, viewerUser } from '../helpers/auth';

test('restringe acciones administrativas al usuario de consulta', async ({
  page,
}, testInfo) => {
  await loginAs(page, viewerUser);

  await page.goto('/productos');
  await expect(
    page.getByRole('heading', { name: 'Catálogo de inventario' }),
  ).toBeVisible();
  await expect(
    page.getByRole('link', { name: 'Nuevo producto' }),
  ).toHaveCount(0);
  await expect(
    page.getByRole('columnheader', { name: 'Acciones' }),
  ).toBeVisible();
  await expect(page.getByRole('link', { name: 'Movimientos' }).first()).toBeVisible();
  await expect(page.getByRole('link', { name: 'Editar' })).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Eliminar' })).toHaveCount(0);

  await testInfo.attach('catalogo-solo-lectura', {
    body: await page.screenshot({ fullPage: true }),
    contentType: 'image/png',
  });

  await page.getByRole('link', { name: 'Movimientos' }).first().click();
  await expect(
    page.getByRole('heading', { name: 'Movimientos de stock' }),
  ).toBeVisible();
  await expect(page.getByText('Consulta de stock')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Registrar entrada' })).toHaveCount(0);

  await page.goto('/productos/nuevo');
  await expect(page).toHaveURL(/\/forbidden$/);
  await expect(
    page.getByRole('heading', {
      name: 'No tienes permiso para ver este módulo',
    }),
  ).toBeVisible();

  await testInfo.attach('acceso-denegado-productos', {
    body: await page.screenshot({ fullPage: true }),
    contentType: 'image/png',
  });
});
