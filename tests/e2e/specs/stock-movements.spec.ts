import { expect, test } from '@playwright/test';
import { adminUser, loginAs } from '../helpers/auth';
import { findProductRow } from '../helpers/products';

test('permite registrar movimientos de stock desde la UI', async ({
  page,
}, testInfo) => {
  await loginAs(page, adminUser);

  await page.goto('/productos');
  let row = await findProductRow(page, 'DELL-LAT-5440');
  const initialStock = Number((await row.locator('td').nth(4).textContent())?.trim());

  await row.getByRole('link', { name: 'Movimientos' }).click();
  await expect(
    page.getByRole('heading', { name: 'Movimientos de stock' }),
  ).toBeVisible();
  await expect(page.getByText('DELL-LAT-5440 - Dell Latitude 5440')).toBeVisible();

  await page.getByRole('button', { name: 'Entrada', exact: true }).click();
  await page.getByLabel('Cantidad').fill('5');
  await page.getByLabel('Observaciones').fill('Entrada E2E');
  await page.getByRole('button', { name: 'Registrar entrada' }).click();
  await expect(page.getByRole('status')).toHaveText(
    `Entrada registrada correctamente. Stock actual: ${initialStock + 5}.`,
  );
  await expect(page.getByRole('row').filter({ hasText: 'Entrada E2E' })).toContainText('+5');

  await page.getByRole('button', { name: 'Salida', exact: true }).click();
  await page.getByLabel('Cantidad').fill('2');
  await page.getByLabel('Observaciones').fill('Salida E2E');
  await page.getByRole('button', { name: 'Registrar salida' }).click();
  await expect(page.getByRole('status')).toHaveText(
    `Salida registrada correctamente. Stock actual: ${initialStock + 3}.`,
  );
  await expect(page.getByRole('row').filter({ hasText: 'Salida E2E' })).toContainText('-2');

  await page.getByRole('button', { name: 'Ajuste', exact: true }).click();
  await page.getByLabel('Stock nuevo').fill(String(initialStock));
  await page.getByLabel('Observaciones').fill('Ajuste E2E');
  await page.getByRole('button', { name: 'Registrar ajuste' }).click();
  await expect(page.getByRole('status')).toHaveText(
    `Ajuste registrado correctamente. Stock actual: ${initialStock}.`,
  );
  await expect(page.getByRole('row').filter({ hasText: 'Ajuste E2E' })).toContainText(String(initialStock));

  await testInfo.attach('movimientos-stock', {
    body: await page.screenshot({ fullPage: true }),
    contentType: 'image/png',
  });

  await page.goto('/productos');
  row = await findProductRow(page, 'DELL-LAT-5440');
  await expect(row.locator('td').nth(4)).toHaveText(String(initialStock));
});
