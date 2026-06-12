import { expect, test } from '@playwright/test';

const backendURL = process.env.E2E_BACKEND_URL ?? 'http://localhost:8080';
const keycloakURL = process.env.E2E_KEYCLOAK_URL ?? 'http://localhost:8081';
const keycloakRealm = process.env.E2E_KEYCLOAK_REALM ?? 'inventory';

test('expone los servicios requeridos por la suite E2E', async ({
  request,
}) => {
  const [frontend, backend, keycloak] = await Promise.all([
    request.get('/health'),
    request.get(`${backendURL}/actuator/health`),
    request.get(`${keycloakURL}/realms/${keycloakRealm}`),
  ]);

  expect(frontend.ok()).toBeTruthy();
  expect(backend.ok()).toBeTruthy();
  expect(keycloak.ok()).toBeTruthy();
});
