import { fail } from 'k6';

function env(name, fallback = '') {
  const value = __ENV[name];
  return value === undefined || value === null || value === '' ? fallback : value;
}

function numberEnv(name, fallback, minimum = 0) {
  const rawValue = env(name, String(fallback));
  const value = Number(rawValue);

  if (!Number.isFinite(value) || value < minimum) {
    fail(`${name} must be a number greater than or equal to ${minimum}`);
  }

  return value;
}

function normalizeBaseUrl(value, variableName) {
  if (!value || !/^https?:\/\//i.test(value)) {
    fail(`${variableName} must be an absolute http(s) URL`);
  }

  return value.replace(/\/+$/, '');
}

function normalizePath(value, variableName) {
  if (!value || !value.startsWith('/')) {
    fail(`${variableName} must start with /`);
  }

  return value;
}

export function loadEnvironment() {
  const config = {
    profile: env('K6_PROFILE', 'smoke').toLowerCase(),
    baseUrl: normalizeBaseUrl(env('BASE_URL', 'http://localhost:8080'), 'BASE_URL'),
    keycloakUrl: normalizeBaseUrl(env('KEYCLOAK_URL', 'http://localhost:8081'), 'KEYCLOAK_URL'),
    keycloakRealm: env('KEYCLOAK_REALM', 'inventory'),
    keycloakClientId: env('KEYCLOAK_CLIENT_ID', 'inventory-frontend'),
    keycloakClientSecret: env('KEYCLOAK_CLIENT_SECRET'),
    username: env('K6_USERNAME', 'viewer'),
    password: env('K6_PASSWORD'),
    accessToken: env('K6_ACCESS_TOKEN'),
    healthPath: normalizePath(env('HEALTH_PATH', '/actuator/health'), 'HEALTH_PATH'),
    productsPath: normalizePath(
      env('PRODUCTS_PATH', '/products?page=0&size=20&sort=name&direction=asc'),
      'PRODUCTS_PATH',
    ),
    reportsPath: normalizePath(env('REPORTS_PATH', '/reports/dashboard'), 'REPORTS_PATH'),
    resultsDir: env('K6_RESULTS_DIR', 'test-results/performance/k6').replace(/\/+$/, ''),
    sleepSeconds: numberEnv('K6_SLEEP_SECONDS', 1, 0),
    thresholds: {
      errorRate: numberEnv('K6_ERROR_RATE', 0.01, 0),
      checkRate: numberEnv('K6_CHECK_RATE', 0.99, 0),
      p95: numberEnv('K6_P95_MS', 1200, 1),
      p99: numberEnv('K6_P99_MS', 2500, 1),
      healthP95: numberEnv('K6_HEALTH_P95_MS', 300, 1),
      productsP95: numberEnv('K6_PRODUCTS_P95_MS', 800, 1),
      reportsP95: numberEnv('K6_REPORTS_P95_MS', 1500, 1),
    },
  };

  if (!config.accessToken && !config.password) {
    fail('Set K6_ACCESS_TOKEN or K6_PASSWORD. The script never stores or prints credentials.');
  }

  if (!config.keycloakRealm) {
    fail('KEYCLOAK_REALM is required');
  }

  if (!config.keycloakClientId && !config.accessToken) {
    fail('KEYCLOAK_CLIENT_ID is required when K6_ACCESS_TOKEN is not provided');
  }

  if (!config.username && !config.accessToken) {
    fail('K6_USERNAME is required when K6_ACCESS_TOKEN is not provided');
  }

  return config;
}

export function urlFor(config, path) {
  return `${config.baseUrl}${path}`;
}

export function buildThresholds(config) {
  return {
    http_req_failed: [`rate<${config.thresholds.errorRate}`],
    checks: [`rate>${config.thresholds.checkRate}`],
    http_req_duration: [
      `p(95)<${config.thresholds.p95}`,
      `p(99)<${config.thresholds.p99}`,
    ],
    'http_req_duration{endpoint:health}': [`p(95)<${config.thresholds.healthP95}`],
    'http_req_duration{endpoint:products}': [`p(95)<${config.thresholds.productsP95}`],
    'http_req_duration{endpoint:reports}': [`p(95)<${config.thresholds.reportsP95}`],
  };
}

export function publicContext(config) {
  return {
    profile: config.profile,
    baseUrl: config.baseUrl,
    keycloakUrl: config.keycloakUrl,
    keycloakRealm: config.keycloakRealm,
    keycloakClientId: config.keycloakClientId,
    username: config.accessToken ? 'provided-token' : config.username,
    healthPath: config.healthPath,
    productsPath: config.productsPath,
    reportsPath: config.reportsPath,
    resultsDir: config.resultsDir,
    thresholds: config.thresholds,
  };
}
