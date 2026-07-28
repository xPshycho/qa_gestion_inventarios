import { expect, test } from '@playwright/test';
import type {
  APIRequestContext,
  Page,
  Response as PlaywrightResponse,
} from '@playwright/test';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

interface AuthRuntimeConfig {
  url: string;
  realm: string;
  clientId: string;
}

const apiReadMethods = new Set(['GET', 'HEAD', 'OPTIONS']);

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

function isAuthRuntimeConfig(value: unknown): value is AuthRuntimeConfig {
  return isRecord(value)
    && typeof value['url'] === 'string'
    && value['url'].trim().length > 0
    && typeof value['realm'] === 'string'
    && value['realm'].trim().length > 0
    && typeof value['clientId'] === 'string'
    && value['clientId'].trim().length > 0;
}

function normalizedPublicUrl(value: string, variableName: string): string {
  let url: URL;
  try {
    url = new URL(value.trim());
  } catch {
    throw new Error(`${variableName} must be an absolute HTTP(S) URL.`);
  }

  if (
    !['http:', 'https:'].includes(url.protocol)
    || url.username
    || url.password
    || url.search
    || url.hash
  ) {
    throw new Error(`${variableName} must be a credential-free HTTP(S) URL.`);
  }

  return url.toString().replace(/\/$/, '');
}

function requiredViewerPassword(): string {
  let password = process.env.E2E_VIEWER_PASSWORD?.trim();
  if (!password) {
    for (const candidate of [
      resolve(process.cwd(), '.env'),
      resolve(process.cwd(), '..', '..', '.env'),
    ]) {
      if (!existsSync(candidate)) {
        continue;
      }

      const prefix = 'E2E_VIEWER_PASSWORD=';
      password = readFileSync(candidate, 'utf8')
        .split(/\r?\n/)
        .find((line) => line.startsWith(prefix))
        ?.slice(prefix.length)
        .trim();
      if (password) {
        break;
      }
    }
  }

  if (!password || password.includes('\n') || password.includes('\r')) {
    throw new Error('E2E_VIEWER_PASSWORD must be a non-empty single-line secret.');
  }
  return password;
}

async function loadAuthRuntimeConfig(
  request: APIRequestContext,
): Promise<AuthRuntimeConfig> {
  const response = await request.get('/auth-config.json', {
    headers: { 'Cache-Control': 'no-store' },
  });
  expect(response.ok(), 'auth-config.json must be publicly available').toBe(true);

  const config: unknown = await response.json();
  if (!isAuthRuntimeConfig(config)) {
    throw new Error('auth-config.json does not contain a valid OIDC configuration.');
  }
  return config;
}

function apiResponseFor(
  response: PlaywrightResponse,
  pathname: string,
): boolean {
  return response.request().method() === 'GET'
    && new URL(response.url()).pathname === pathname;
}

async function loginAsViewer(
  page: Page,
  expectedIssuer: string,
): Promise<PlaywrightResponse> {
  const viewerUsername = process.env.E2E_VIEWER_USERNAME?.trim() || 'viewer';
  const viewerPassword = requiredViewerPassword();

  await page.goto('/login');
  await expect(
    page.getByRole('heading', { name: 'Gestión de inventarios' }),
  ).toBeVisible();

  await page
    .getByRole('button', { name: 'Iniciar sesión con Keycloak' })
    .click();
  await expect(page).toHaveURL((url) =>
    url.href.startsWith(`${expectedIssuer}/protocol/openid-connect/auth`),
  );

  await page.locator('#username').fill(viewerUsername);
  await page.locator('#password').fill(viewerPassword);

  const dashboardResponse = page.waitForResponse((response) =>
    apiResponseFor(response, '/api/reports/dashboard'),
  );
  await page.locator('#kc-login').click();

  await expect(page).toHaveURL(/\/dashboard(?:[?#].*)?$/);
  await expect(
    page.getByRole('button', { name: 'Cerrar sesión' }),
  ).toBeVisible();
  return dashboardResponse;
}

test(
  'valida frontend y backend por sus rutas públicas',
  { tag: '@deployed-smoke' },
  async ({ request }) => {
    const [frontend, backend] = await Promise.all([
      request.get('/health'),
      request.get('/api/actuator/health'),
    ]);

    expect(frontend.ok(), 'frontend /health must return 2xx').toBe(true);
    expect((await frontend.text()).trim()).toBe('ok');
    expect(backend.ok(), 'public backend health route must return 2xx').toBe(true);

    const backendHealth: unknown = await backend.json();
    expect(isRecord(backendHealth)).toBe(true);
    if (!isRecord(backendHealth)) {
      throw new Error('Backend health response must be a JSON object.');
    }
    expect(backendHealth['status']).toBe('UP');
  },
);

test(
  'publica el issuer OIDC configurado de forma exacta',
  { tag: '@deployed-smoke' },
  async ({ request }) => {
    const authConfig = await loadAuthRuntimeConfig(request);
    const configuredKeycloakUrl = normalizedPublicUrl(
      authConfig.url,
      'auth-config.json url',
    );
    const expectedKeycloakUrl = process.env.E2E_KEYCLOAK_URL
      ? normalizedPublicUrl(process.env.E2E_KEYCLOAK_URL, 'E2E_KEYCLOAK_URL')
      : configuredKeycloakUrl;
    const expectedRealm =
      process.env.E2E_KEYCLOAK_REALM?.trim() || authConfig.realm;

    expect(configuredKeycloakUrl).toBe(expectedKeycloakUrl);
    expect(authConfig.realm).toBe(expectedRealm);

    const publicIssuer =
      `${expectedKeycloakUrl}/realms/${encodeURIComponent(expectedRealm)}`;
    const expectedIssuer =
      process.env.E2E_EXPECTED_OIDC_ISSUER?.trim() || publicIssuer;
    const discovery = await request.get(
      `${publicIssuer}/.well-known/openid-configuration`,
    );

    expect(discovery.ok(), 'OIDC discovery endpoint must return 2xx').toBe(true);
    const discoveryDocument: unknown = await discovery.json();
    expect(isRecord(discoveryDocument)).toBe(true);
    if (!isRecord(discoveryDocument)) {
      throw new Error('OIDC discovery response must be a JSON object.');
    }
    expect(discoveryDocument['issuer']).toBe(expectedIssuer);
  },
);

test(
  'viewer inicia sesión y carga dashboard y catálogo sin mutar datos',
  { tag: '@deployed-smoke' },
  async ({ page, request }) => {
    const authConfig = await loadAuthRuntimeConfig(request);
    const keycloakUrl = process.env.E2E_KEYCLOAK_URL
      ? normalizedPublicUrl(process.env.E2E_KEYCLOAK_URL, 'E2E_KEYCLOAK_URL')
      : normalizedPublicUrl(authConfig.url, 'auth-config.json url');
    const realm = process.env.E2E_KEYCLOAK_REALM?.trim() || authConfig.realm;
    const expectedIssuer =
      process.env.E2E_EXPECTED_OIDC_ISSUER?.trim()
      || `${keycloakUrl}/realms/${encodeURIComponent(realm)}`;
    const mutationRequests: string[] = [];

    await page.route('**/api/**', async (route) => {
      const outgoingRequest = route.request();
      const pathname = new URL(outgoingRequest.url()).pathname;
      if (
        !apiReadMethods.has(outgoingRequest.method())
      ) {
        mutationRequests.push(`${outgoingRequest.method()} ${pathname}`);
        await route.abort('blockedbyclient');
        return;
      }
      await route.continue();
    });

    const dashboardResponse = await loginAsViewer(page, expectedIssuer);
    expect(dashboardResponse.ok(), 'dashboard API must return 2xx').toBe(true);

    const dashboard: unknown = await dashboardResponse.json();
    expect(isRecord(dashboard)).toBe(true);
    if (!isRecord(dashboard) || !isRecord(dashboard['metrics'])) {
      throw new Error('Dashboard API response is missing its metrics object.');
    }
    const totalProducts = dashboard['metrics']['totalProducts'];
    expect(typeof totalProducts).toBe('number');
    if (typeof totalProducts !== 'number') {
      throw new Error('Dashboard totalProducts metric must be numeric.');
    }
    expect(totalProducts).toBeGreaterThan(0);
    expect(Array.isArray(dashboard['criticalProducts'])).toBe(true);
    expect(Array.isArray(dashboard['mostMovedProducts'])).toBe(true);
    expect(Array.isArray(dashboard['recentMovements'])).toBe(true);

    await expect(
      page.getByRole('heading', { name: 'Inventario operativo' }),
    ).toBeVisible();
    await expect(
      page.getByRole('region', { name: 'Métricas operacionales' }),
    ).toBeVisible();
    await expect(page.getByText('Total productos', { exact: true })).toBeVisible();
    await expect(page.getByRole('alert')).toHaveCount(0);

    const productsResponsePromise = page.waitForResponse((response) =>
      apiResponseFor(response, '/api/products'),
    );
    await page.goto('/productos');
    const productsResponse = await productsResponsePromise;
    expect(productsResponse.ok(), 'products API must return 2xx').toBe(true);

    const productsPage: unknown = await productsResponse.json();
    if (!isRecord(productsPage) || !Array.isArray(productsPage['content'])) {
      throw new Error('Products API response is missing its content array.');
    }
    const totalElements = productsPage['totalElements'];
    expect(typeof totalElements).toBe('number');
    if (typeof totalElements !== 'number') {
      throw new Error('Products totalElements field must be numeric.');
    }
    expect(totalElements).toBeGreaterThan(0);
    expect(productsPage['content'].length).toBeGreaterThan(0);

    const firstProduct: unknown = productsPage['content'][0];
    if (!isRecord(firstProduct) || typeof firstProduct['sku'] !== 'string') {
      throw new Error('Products API returned an invalid first catalog item.');
    }

    await expect(
      page.getByRole('heading', { name: 'Catálogo de inventario' }),
    ).toBeVisible();
    await expect(
      page.locator('[aria-label="Listado de productos"]'),
    ).toBeVisible();
    await expect(page.getByText(firstProduct['sku'], { exact: true })).toBeVisible();
    await expect(page.getByText('Cargando productos...')).toHaveCount(0);
    await expect(page.getByRole('alert')).toHaveCount(0);
    await expect(
      page.getByRole('link', { name: 'Nuevo producto' }),
    ).toHaveCount(0);
    await expect(page.getByRole('link', { name: 'Editar' })).toHaveCount(0);
    await expect(page.getByRole('button', { name: 'Eliminar' })).toHaveCount(0);
    expect(mutationRequests, 'deployed smoke must keep the inventory API read-only')
      .toEqual([]);
  },
);
