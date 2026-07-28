import { expect, Page } from '@playwright/test';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

export interface E2EUser {
  username: string;
  password: string;
}

function requiredSecret(name: string): string {
  const processValue = process.env[name]?.trim();
  if (processValue) {
    return processValue;
  }

  const candidates = [
    resolve(process.cwd(), '.env'),
    resolve(process.cwd(), '..', '..', '.env'),
  ];

  for (const candidate of candidates) {
    if (!existsSync(candidate)) {
      continue;
    }

    const prefix = `${name}=`;
    const matchingLine = readFileSync(candidate, 'utf8')
      .split(/\r?\n/)
      .find((line) => line.startsWith(prefix));
    const fileValue = matchingLine?.slice(prefix.length).trim();
    if (fileValue) {
      return fileValue;
    }
  }

  throw new Error(
    `${name} is required. Run ./scripts/security/init-secret-env.sh local or inject it through the environment.`,
  );
}

export const adminUser: E2EUser = {
  username: process.env.E2E_ADMIN_USERNAME ?? 'carlos',
  password: requiredSecret('E2E_ADMIN_PASSWORD'),
};

export const viewerUser: E2EUser = {
  username: process.env.E2E_VIEWER_USERNAME ?? 'viewer',
  password: requiredSecret('E2E_VIEWER_PASSWORD'),
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
