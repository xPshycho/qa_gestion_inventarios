import { expect, test } from '@playwright/test';
import { adminUser, loginAs, viewerUser } from '../helpers/auth';
import {
  cleanupProduct,
  deleteProductFromRow,
  fillProductForm,
  findProductRow,
  ProductFormData,
} from '../helpers/products';

test('permite consultar auditoria de productos y movimientos de stock', async ({
  page,
}, testInfo) => {
  const suffix = `${Date.now()}-${testInfo.workerIndex}`;
  const sku = `AUD-${suffix}`;
  const initialProduct: ProductFormData = {
    sku,
    name: `Producto auditado ${suffix}`,
    category: 'Auditoria E2E',
    status: 'Activo',
    price: '950.00',
    currentStock: '7',
    minimumStock: '2',
    description: 'Producto temporal para auditoria.',
  };
  const updatedProduct: ProductFormData = {
    ...initialProduct,
    name: `Producto auditado actualizado ${suffix}`,
    category: 'Auditoria',
    price: '975.00',
    currentStock: '7',
    description: 'Producto temporal actualizado para auditoria.',
  };
  let deleted = false;

  await loginAs(page, adminUser);

  try {
    await page.goto('/productos');
    await page.getByRole('link', { name: 'Nuevo producto' }).click();
    await fillProductForm(page, initialProduct);
    await page.getByRole('button', { name: 'Crear producto' }).click();
    await expect(page.getByRole('status')).toHaveText(
      `Producto ${sku} creado correctamente.`,
    );

    let row = await findProductRow(page, sku);
    await row.getByRole('link', { name: 'Editar' }).click();
    await fillProductForm(page, updatedProduct);
    await page.getByRole('button', { name: 'Guardar cambios' }).click();
    await expect(page.getByRole('status')).toHaveText(
      `Producto ${sku} actualizado correctamente.`,
    );

    row = await findProductRow(page, sku);
    await row.getByRole('link', { name: 'Auditoria' }).click();
    await expect(
      page.getByRole('heading', { name: 'Historial de producto y stock' }),
    ).toBeVisible();
    await expect(page.getByText(`${sku} - ${updatedProduct.name}`)).toBeVisible();
    await expect(page.getByText('Cambios del producto')).toBeVisible();
    await expect(page.getByText('Modificacion')).toBeVisible();
    await expect(page.getByText(updatedProduct.name, { exact: true })).toBeVisible();

    await testInfo.attach('auditoria-producto', {
      body: await page.screenshot({ fullPage: true }),
      contentType: 'image/png',
    });

    await page.goto('/productos');
    const seedRow = await findProductRow(page, 'DELL-LAT-5440');
    await seedRow.getByRole('link', { name: 'Auditoria' }).click();
    const stockAuditPanel = page.locator('article').filter({
      hasText: 'Revisiones de movimientos de stock',
    });
    await expect(stockAuditPanel).toBeVisible();
    await expect(
      stockAuditPanel.getByText(/No hay revisiones de movimientos de stock|Tipo de movimiento/).first(),
    ).toBeVisible();

    await testInfo.attach('auditoria-stock', {
      body: await page.screenshot({ fullPage: true }),
      contentType: 'image/png',
    });

    await page.goto('/productos');
    row = await findProductRow(page, sku);
    await deleteProductFromRow(page, row);
    deleted = true;
  } finally {
    if (!deleted) {
      await cleanupProduct(page, sku);
    }
  }
});

test('bloquea la auditoria a usuarios sin permiso audit view', async ({ page }) => {
  await loginAs(page, viewerUser);

  await page.goto('/productos');
  await expect(page.getByRole('link', { name: 'Auditoria' })).toHaveCount(0);

  await page.goto('/productos/1/auditoria');
  await expect(page).toHaveURL(/\/forbidden$/);
  await expect(
    page.getByRole('heading', {
      name: 'No tienes permiso para ver este modulo',
    }),
  ).toBeVisible();
});
