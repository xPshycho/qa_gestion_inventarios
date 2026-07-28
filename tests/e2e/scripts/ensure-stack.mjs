import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const directory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(directory, '../../..');
const timeoutMs = Number(process.env.E2E_STACK_TIMEOUT_MS ?? 240_000);
const pollIntervalMs = 2_000;

const services = [
  {
    name: 'frontend',
    url: `${process.env.E2E_BASE_URL ?? 'http://localhost:5173'}/health`,
  },
  {
    name: 'backend',
    url: `${process.env.E2E_BACKEND_URL ?? 'http://localhost:8080'}/actuator/health`,
  },
  {
    name: 'keycloak',
    url: `${
      process.env.E2E_KEYCLOAK_URL ?? 'http://localhost:8081'
    }/realms/${process.env.E2E_KEYCLOAK_REALM ?? 'inventory'}`,
  },
];

async function getUnavailableServices() {
  const checks = await Promise.all(
    services.map(async (service) => {
      try {
        const response = await fetch(service.url, {
          signal: AbortSignal.timeout(5_000),
        });
        return response.ok ? null : `${service.name} (${response.status})`;
      } catch {
        return `${service.name} (sin respuesta)`;
      }
    }),
  );

  return checks.filter(Boolean);
}

async function waitForStack() {
  const deadline = Date.now() + timeoutMs;

  while (Date.now() < deadline) {
    const unavailableServices = await getUnavailableServices();
    if (unavailableServices.length === 0) {
      console.log('Stack E2E disponible.');
      return;
    }

    console.log(`Esperando servicios: ${unavailableServices.join(', ')}`);
    await new Promise((resolve) => setTimeout(resolve, pollIntervalMs));
  }

  throw new Error(`El stack E2E no estuvo disponible en ${timeoutMs} ms.`);
}

const unavailableServices = await getUnavailableServices();

if (unavailableServices.length > 0) {
  if (process.env.E2E_MANAGE_STACK === 'false') {
    throw new Error(
      `Servicios no disponibles: ${unavailableServices.join(', ')}.`,
    );
  }

  console.log('Iniciando el stack E2E con Docker Compose...');
  const result = spawnSync('docker', ['compose', 'up', '--build', '-d'], {
    cwd: repositoryRoot,
    env: process.env,
    stdio: 'inherit',
  });

  if (result.status !== 0) {
    throw new Error('Docker Compose no pudo iniciar el stack E2E.');
  }
}

await waitForStack();
