import { expect, Page } from '@playwright/test';

export interface E2EUser {
  username: string;
  password: string;
}

export const adminUser: E2EUser = {
  username: process.env.E2E_ADMIN_USERNAME ?? 'carlos',
  password: process.env.E2E_ADMIN_PASSWORD ?? 'admin123',
};

export const viewerUser: E2EUser = {
  username: process.env.E2E_VIEWER_USERNAME ?? 'viewer',
  password: process.env.E2E_VIEWER_PASSWORD ?? 'admin123',
};

export async function loginAs(page: Page, user: E2EUser): Promise<void> {
  await page.goto('/login');
  await expect(
    page.getByRole('heading', { name: 'Gestión de inventarios' }),
  ).toBeVisible();

  await page
    .getByRole('button', { name: 'Iniciar sesión con Keycloak' })
    .click();
  await expect(page).toHaveURL(/\/realms\/inventory\/protocol\/openid-connect\/auth/);

  await page.locator('#username').fill(user.username);
  await page.locator('#password').fill(user.password);
  await page.locator('#kc-login').click();

  await expect(
    page.getByRole('button', { name: 'Cerrar sesión' }),
  ).toBeVisible();
}
