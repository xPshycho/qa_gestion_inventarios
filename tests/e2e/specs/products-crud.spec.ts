import { expect, test } from '@playwright/test';
import { adminUser, loginAs } from '../helpers/auth';
import {
  cleanupProduct,
  deleteProductFromRow,
  fillProductForm,
  findProductRow,
  ProductFormData,
} from '../helpers/products';

test('permite completar el CRUD de productos', async ({ page }, testInfo) => {
  const suffix = `${Date.now()}-${testInfo.workerIndex}`;
  const sku = `E2E-${suffix}`;
  const initialProduct: ProductFormData = {
    sku,
    name: `Producto E2E ${suffix}`,
    category: 'Pruebas E2E',
    status: 'Activo',
    price: '1250.50',
    currentStock: '12',
    minimumStock: '3',
    description: 'Producto temporal creado por Playwright.',
  };
  const updatedProduct: ProductFormData = {
    ...initialProduct,
    name: `Producto E2E actualizado ${suffix}`,
    category: 'Automatizacion',
    status: 'Inactivo',
    price: '1499.99',
    currentStock: '18',
    minimumStock: '5',
    description: 'Producto temporal actualizado por Playwright.',
  };
  let deleted = false;

  await loginAs(page, adminUser);

  try {
    await page.goto('/productos');
    await page.getByRole('link', { name: 'Nuevo producto' }).click();
    await expect(
      page.getByRole('heading', { name: 'Crear producto' }),
    ).toBeVisible();

    await fillProductForm(page, initialProduct);
    await page.getByRole('button', { name: 'Crear producto' }).click();

    await expect(page.getByRole('status')).toHaveText(
      `Producto ${sku} creado correctamente.`,
    );
    let row = await findProductRow(page, sku);
    await expect(row).toContainText(initialProduct.name);
    await expect(row).toContainText(initialProduct.category);
    await expect(row).toContainText('12');

    await testInfo.attach('producto-creado', {
      body: await page.screenshot({ fullPage: true }),
      contentType: 'image/png',
    });

    await row.getByRole('link', { name: 'Editar' }).click();
    await expect(
      page.getByRole('heading', { name: 'Editar producto' }),
    ).toBeVisible();
    await expect(page.getByLabel('SKU')).toHaveValue(sku);

    await fillProductForm(page, updatedProduct);
    await page.getByRole('button', { name: 'Guardar cambios' }).click();

    await expect(page.getByRole('status')).toHaveText(
      `Producto ${sku} actualizado correctamente.`,
    );
    row = await findProductRow(page, sku);
    await expect(row).toContainText(updatedProduct.name);
    await expect(row).toContainText(updatedProduct.category);
    await expect(row).toContainText('18');
    await expect(row).toContainText('Inactivo');

    await testInfo.attach('producto-actualizado', {
      body: await page.screenshot({ fullPage: true }),
      contentType: 'image/png',
    });

    await deleteProductFromRow(page, row);
    deleted = true;

    await expect(page.getByRole('status')).toHaveText(
      `Producto ${sku} eliminado correctamente.`,
    );
    await expect(page.getByRole('row').filter({ hasText: sku })).toHaveCount(0);

    await testInfo.attach('producto-eliminado', {
      body: await page.screenshot({ fullPage: true }),
      contentType: 'image/png',
    });
  } finally {
    if (!deleted) {
      await cleanupProduct(page, sku);
    }
  }
});
