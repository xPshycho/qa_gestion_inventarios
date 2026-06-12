import { expect, test } from '@playwright/test';
import { adminUser, loginAs } from '../helpers/auth';

test('permite iniciar y cerrar sesion con Keycloak', async ({
  page,
}, testInfo) => {
  await loginAs(page, adminUser);

  await expect(page).toHaveURL(/\/dashboard$/);
  await expect(
    page.getByRole('heading', { name: 'Inventario operativo' }),
  ).toBeVisible();

  await testInfo.attach('sesion-administrador', {
    body: await page.screenshot({ fullPage: true }),
    contentType: 'image/png',
  });

  await page.getByRole('button', { name: 'Cerrar sesion' }).click();

  await expect(page).toHaveURL(/\/login$/);
  await expect(
    page.getByRole('button', { name: 'Iniciar sesion con Keycloak' }),
  ).toBeVisible();

  await testInfo.attach('sesion-cerrada', {
    body: await page.screenshot({ fullPage: true }),
    contentType: 'image/png',
  });
});
