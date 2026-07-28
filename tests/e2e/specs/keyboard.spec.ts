import { expect, Locator, Page, test } from '@playwright/test';
import { adminUser, loginAs } from '../helpers/auth';

async function tabTo(page: Page, target: Locator, maxTabs = 30): Promise<void> {
  for (let index = 0; index < maxTabs; index += 1) {
    await page.keyboard.press('Tab');
    if (await target.evaluate((element) => element === document.activeElement)) {
      return;
    }
  }

  throw new Error(`No se alcanzó por teclado el elemento ${await target.getAttribute('id') ?? await target.getAttribute('name') ?? 'sin identificador'}.`);
}

test('permite iniciar sesión usando exclusivamente el teclado', async ({
  page,
}, testInfo) => {
  await page.goto('/login');
  await expect(page.getByRole('heading', { name: 'Gestión de inventarios' }))
    .toBeVisible();

  const main = page.locator('#main-content');
  await expect(main).toBeFocused();
  await page.keyboard.press('Shift+Tab');
  const skipLink = page.getByRole('link', { name: 'Saltar al contenido principal' });
  await expect(skipLink).toBeFocused();
  await page.keyboard.press('Enter');
  await expect(main).toBeFocused();

  await page.keyboard.press('Tab');
  const loginButton = page.getByRole('button', { name: 'Iniciar sesión con Keycloak' });
  await expect(loginButton).toBeFocused();
  await page.keyboard.press('Enter');

  const username = page.locator('#username');
  const password = page.locator('#password');
  const submit = page.locator('#kc-login');
  await expect(username).toBeVisible();
  await page.evaluate(() => {
    (document.activeElement as HTMLElement | null)?.blur();
  });
  await tabTo(page, username);
  await page.keyboard.type(adminUser.username);
  await tabTo(page, password);
  await page.keyboard.type(adminUser.password);
  await tabTo(page, submit);
  await page.keyboard.press('Enter');

  await expect(page.getByRole('button', { name: 'Cerrar sesión' })).toBeVisible();
  await testInfo.attach('keyboard-login', {
    body: Buffer.from(JSON.stringify({
      flow: 'login',
      result: 'passed',
      finalUrl: page.url(),
      validated: ['skip-link', 'tab-order', 'keyboard-submit'],
    }, null, 2)),
    contentType: 'application/json',
  });
});

test('atrapa y restaura el foco del diálogo y anuncia el orden de tabla', async ({
  page,
}, testInfo) => {
  await loginAs(page, adminUser);
  await page.goto('/productos');
  await expect(page.getByRole('heading', { name: 'Catálogo de inventario' }))
    .toBeVisible();

  const deleteButton = page.getByRole('button', { name: 'Eliminar' }).first();
  await deleteButton.focus();
  await page.keyboard.press('Enter');

  const dialog = page.getByRole('alertdialog');
  const cancelButton = dialog.getByRole('button', { name: 'Cancelar' });
  const confirmButton = dialog.getByRole('button', { name: 'Eliminar producto' });
  await expect(dialog).toBeVisible();
  await expect(cancelButton).toBeFocused();
  await page.keyboard.press('Tab');
  await expect(confirmButton).toBeFocused();
  await page.keyboard.press('Tab');
  await expect(cancelButton).toBeFocused();
  await page.keyboard.press('Shift+Tab');
  await expect(confirmButton).toBeFocused();
  await page.keyboard.press('Escape');
  await expect(dialog).not.toBeVisible();
  await expect(deleteButton).toBeFocused();

  const nameSort = page.getByRole('button', { name: /Ordenar por nombre/ });
  const nameHeader = page.locator('th').filter({ has: nameSort });
  await expect(nameHeader).toHaveAttribute('aria-sort', 'ascending');
  await nameSort.focus();
  await page.keyboard.press('Enter');
  await expect(nameHeader).toHaveAttribute('aria-sort', 'descending');

  await testInfo.attach('keyboard-products', {
    body: Buffer.from(JSON.stringify({
      flow: 'products-delete-dialog-and-sort',
      result: 'passed',
      validated: ['safe-initial-focus', 'focus-trap', 'escape', 'focus-return', 'aria-sort'],
    }, null, 2)),
    contentType: 'application/json',
  });
  await testInfo.attach('keyboard-products-dialog', {
    body: await page.screenshot({ fullPage: false }),
    contentType: 'image/png',
  });
});

test('muestra errores en línea y enfoca el primer campo inválido', async ({
  page,
}, testInfo) => {
  await loginAs(page, adminUser);
  await page.goto('/seguridad');
  await expect(page.getByRole('heading', { name: 'Usuarios, roles y permisos' }))
    .toBeVisible();
  await expect(page.locator('mat-progress-bar')).toHaveCount(0);

  const submit = page.getByRole('button', { name: 'Guardar usuario' });
  await submit.focus();
  await page.keyboard.press('Enter');

  await expect(page.getByRole('alert'))
    .toContainText('Revisa los campos obligatorios');
  const username = page.getByRole('textbox', { name: 'Usuario', exact: true });
  await expect(username).toBeFocused();
  await expect(username).toHaveAttribute('aria-invalid', 'true');
  await expect(page.getByText('El usuario es obligatorio.')).toBeVisible();

  await testInfo.attach('keyboard-security-validation', {
    body: Buffer.from(JSON.stringify({
      flow: 'security-inline-validation',
      result: 'passed',
      validated: ['inline-error', 'aria-invalid', 'first-invalid-focus', 'alert'],
    }, null, 2)),
    contentType: 'application/json',
  });
});
