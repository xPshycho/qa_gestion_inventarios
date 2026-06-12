import { expect, Locator, Page } from '@playwright/test';

export interface ProductFormData {
  sku: string;
  name: string;
  category: string;
  status: 'Activo' | 'Inactivo';
  price: string;
  currentStock: string;
  minimumStock: string;
  description: string;
}

export async function fillProductForm(
  page: Page,
  product: ProductFormData,
): Promise<void> {
  await page.getByLabel('SKU').fill(product.sku);
  await page.getByLabel('Nombre').fill(product.name);
  await page.getByLabel('Categoria').fill(product.category);
  await page.getByLabel('Estado').selectOption({ label: product.status });
  await page.getByLabel('Precio').fill(product.price);
  await page.getByLabel('Stock actual').fill(product.currentStock);
  await page.getByLabel('Stock minimo').fill(product.minimumStock);
  await page.getByLabel('Descripcion').fill(product.description);
}

export async function findProductRow(
  page: Page,
  sku: string,
): Promise<Locator> {
  const search = page.getByLabel('Busqueda por nombre o SKU');
  await search.fill(sku);

  const row = page.getByRole('row').filter({ hasText: sku });
  await expect(row).toHaveCount(1);
  return row;
}

export async function deleteProductFromRow(
  page: Page,
  row: Locator,
): Promise<void> {
  await row.getByRole('button', { name: 'Eliminar' }).click();
  const dialog = page.getByRole('alertdialog');
  await expect(dialog).toBeVisible();
  await dialog.getByRole('button', { name: 'Eliminar producto' }).click();
  await expect(dialog).not.toBeVisible();
}

export async function cleanupProduct(page: Page, sku: string): Promise<void> {
  try {
    await page.goto('/productos');
    const search = page.getByLabel('Busqueda por nombre o SKU');
    await search.fill(sku);

    const row = page.getByRole('row').filter({ hasText: sku });
    if ((await row.count()) === 1) {
      await deleteProductFromRow(page, row);
    }
  } catch {
    console.warn(`No se pudo limpiar el producto E2E ${sku}.`);
  }
}
