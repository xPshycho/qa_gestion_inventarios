#!/usr/bin/env node

import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

const startedAt = new Date(
  process.env.STAGING_CHECK_STARTED_AT ?? Date.now(),
);
if (Number.isNaN(startedAt.getTime())) {
  throw new Error('STAGING_CHECK_STARTED_AT is not a valid timestamp');
}
const evidenceDirectory = path.resolve(
  process.env.STAGING_POST_DEPLOY_EVIDENCE_DIR
    ?? '.staging/evidence/post-deploy',
);

const config = {
  frontendUrl: required('STAGING_FRONTEND_URL'),
  backendUrl: required('STAGING_BACKEND_URL'),
  keycloakUrl: required('STAGING_KEYCLOAK_URL'),
  keycloakRealm: required('KEYCLOAK_REALM'),
  keycloakClientId: required('KEYCLOAK_CLIENT_ID'),
  adminUsername: required('E2E_ADMIN_USERNAME'),
  adminPassword: required('E2E_ADMIN_PASSWORD'),
  deploymentId: required('STAGING_DEPLOYMENT_ID'),
  composeProject: required('COMPOSE_PROJECT_NAME'),
  observabilityLogMarker: required('STAGING_OBSERVABILITY_LOG_MARKER'),
  lifecycle: required('STAGING_LIFECYCLE'),
  visibility: required('STAGING_VISIBILITY'),
  prometheusUrl: process.env.STAGING_PROMETHEUS_URL
    ?? `http://127.0.0.1:${required('PROMETHEUS_PORT')}`,
  grafanaUrl: process.env.STAGING_GRAFANA_URL
    ?? `http://127.0.0.1:${required('GRAFANA_PORT')}`,
  lokiUrl: process.env.STAGING_LOKI_URL
    ?? `http://127.0.0.1:${required('LOKI_PORT')}`,
  tempoUrl: process.env.STAGING_TEMPO_URL
    ?? `http://127.0.0.1:${required('TEMPO_PORT')}`,
  alertmanagerUrl: process.env.STAGING_ALERTMANAGER_URL
    ?? `http://127.0.0.1:${required('ALERTMANAGER_PORT')}`,
  alloyUrl: process.env.STAGING_ALLOY_URL
    ?? `http://127.0.0.1:${required('ALLOY_HTTP_PORT')}`,
  grafanaUsername: required('GRAFANA_ADMIN_USER'),
  grafanaPassword: required('GRAFANA_ADMIN_PASSWORD'),
};

const results = [];
let accessToken;
let temporaryProduct;
let temporaryProductDeleted = false;

function required(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Required environment variable is empty: ${name}`);
  }
  return value;
}

function joinUrl(base, pathname) {
  return new URL(pathname, `${base.replace(/\/$/, '')}/`).toString();
}

function basicAuthentication(username, password) {
  return `Basic ${Buffer.from(`${username}:${password}`).toString('base64')}`;
}

async function responseBody(response) {
  const text = await response.text();
  if (!text) {
    return null;
  }
  const contentType = response.headers.get('content-type') ?? '';
  if (contentType.includes('json')) {
    try {
      return JSON.parse(text);
    } catch {
      throw new Error(`Invalid JSON returned by ${response.url}`);
    }
  }
  return text;
}

async function request(url, options = {}, expectedStatuses = [200]) {
  const controller = new AbortController();
  const timeout = setTimeout(
    () => controller.abort(),
    Number(process.env.STAGING_REQUEST_TIMEOUT_MS ?? 15_000),
  );

  try {
    const response = await fetch(url, {
      redirect: 'follow',
      ...options,
      signal: controller.signal,
    });
    const body = await responseBody(response);
    if (!expectedStatuses.includes(response.status)) {
      const excerpt = typeof body === 'string'
        ? body.slice(0, 300)
        : JSON.stringify(body).slice(0, 300);
      throw new Error(
        `${options.method ?? 'GET'} ${url} returned ${response.status}; expected `
        + `${expectedStatuses.join(', ')}. Body: ${excerpt}`,
      );
    }
    return { response, body };
  } finally {
    clearTimeout(timeout);
  }
}

async function poll(description, operation, timeoutMs = 75_000) {
  const deadline = Date.now() + timeoutMs;
  let lastError;

  while (Date.now() < deadline) {
    try {
      const value = await operation();
      if (value) {
        return value;
      }
    } catch (error) {
      lastError = error;
    }
    await new Promise((resolve) => setTimeout(resolve, 3_000));
  }

  throw new Error(
    `${description} did not become verifiable within ${timeoutMs} ms`
    + (lastError ? `: ${lastError.message}` : ''),
  );
}

async function check(suite, name, operation) {
  const checkStartedAt = Date.now();
  try {
    const detail = await operation();
    results.push({
      suite,
      name,
      status: 'passed',
      durationMs: Date.now() - checkStartedAt,
      detail: detail ?? null,
    });
    process.stdout.write(`PASS [${suite}] ${name}\n`);
  } catch (error) {
    results.push({
      suite,
      name,
      status: 'failed',
      durationMs: Date.now() - checkStartedAt,
      error: error instanceof Error ? error.message : String(error),
    });
    process.stderr.write(`FAIL [${suite}] ${name}: ${error.message}\n`);
  }
}

function authenticatedHeaders(extra = {}) {
  if (!accessToken) {
    throw new Error('The Keycloak token was not obtained');
  }
  return {
    Authorization: `Bearer ${accessToken}`,
    ...extra,
  };
}

async function api(pathname, options = {}, expectedStatuses = [200]) {
  return request(
    joinUrl(config.frontendUrl, `api/${pathname.replace(/^\//, '')}`),
    {
      ...options,
      headers: authenticatedHeaders(options.headers),
    },
    expectedStatuses,
  );
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function quotedQueryValue(value) {
  return value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
}

await mkdir(evidenceDirectory, { recursive: true, mode: 0o700 });

await check('health', 'frontend health endpoint', async () => {
  const { body } = await request(joinUrl(config.frontendUrl, 'health'));
  assert(String(body).trim() === 'ok', 'Frontend health body was not "ok"');
  return { status: 'UP' };
});

await check('health', 'backend Actuator health', async () => {
  const { body } = await request(joinUrl(config.backendUrl, 'actuator/health'));
  assert(body?.status === 'UP', `Backend status was ${body?.status ?? 'missing'}`);
  return { status: body.status };
});

await check('integration', 'Keycloak OIDC discovery and public issuer', async () => {
  const discoveryUrl = joinUrl(
    config.keycloakUrl,
    `realms/${config.keycloakRealm}/.well-known/openid-configuration`,
  );
  const { body } = await request(discoveryUrl);
  const expectedIssuer = joinUrl(
    config.keycloakUrl,
    `realms/${config.keycloakRealm}`,
  ).replace(/\/$/, '');
  assert(body?.issuer === expectedIssuer, `Unexpected issuer: ${body?.issuer}`);
  assert(body?.token_endpoint, 'OIDC discovery did not expose token_endpoint');
  return { issuer: body.issuer };
});

await check('api', 'Swagger UI and OpenAPI contract', async () => {
  const swagger = await request(joinUrl(config.backendUrl, 'swagger-ui/index.html'));
  assert(
    String(swagger.body).includes('Swagger UI'),
    'Swagger UI HTML did not contain its expected title',
  );
  const { body: openApi } = await request(joinUrl(config.backendUrl, 'v3/api-docs'));
  assert(openApi?.openapi?.startsWith('3.'), 'OpenAPI 3 document was not returned');
  for (const requiredPath of ['/products', '/reports/dashboard']) {
    assert(openApi.paths?.[requiredPath], `OpenAPI path is missing: ${requiredPath}`);
  }
  return {
    openapi: openApi.openapi,
    requiredPaths: ['/products', '/reports/dashboard'],
  };
});

await check('security', 'unauthenticated inventory API is rejected', async () => {
  const { response } = await request(
    joinUrl(config.frontendUrl, 'api/products'),
    {},
    [401],
  );
  assert(
    response.headers.get('www-authenticate')?.toLowerCase().includes('bearer'),
    'The API rejection did not advertise Bearer authentication',
  );
  return { status: response.status };
});

await check('security', 'configured staging origin passes CORS preflight', async () => {
  const { response } = await request(
    joinUrl(config.backendUrl, 'products'),
    {
      method: 'OPTIONS',
      headers: {
        Origin: config.frontendUrl,
        'Access-Control-Request-Method': 'GET',
        'Access-Control-Request-Headers': 'authorization',
      },
    },
    [200],
  );
  assert(
    response.headers.get('access-control-allow-origin') === config.frontendUrl,
    'CORS did not return the configured staging origin',
  );
  return { allowedOrigin: config.frontendUrl };
});

await check('integration', 'Keycloak login returns an application token', async () => {
  const tokenUrl = joinUrl(
    config.keycloakUrl,
    `realms/${config.keycloakRealm}/protocol/openid-connect/token`,
  );
  const form = new URLSearchParams({
    grant_type: 'password',
    client_id: config.keycloakClientId,
    username: config.adminUsername,
    password: config.adminPassword,
  });
  const { body } = await request(
    tokenUrl,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: form,
    },
  );
  assert(body?.access_token, 'Keycloak response did not contain access_token');
  accessToken = body.access_token;
  return {
    tokenType: body.token_type,
    expiresIn: body.expires_in,
  };
});

await check('api', 'authenticated products API returns seeded inventory', async () => {
  const { body } = await api('products?size=100');
  assert(Array.isArray(body?.content), 'Products response did not contain content');
  assert(body.content.length >= 4, 'Seeded product dataset was not available');
  assert(
    body.content.some((product) => product.sku === 'DELL-LAT-5440'),
    'Expected seeded product DELL-LAT-5440 was not found',
  );
  return {
    returnedProducts: body.content.length,
    totalElements: body.totalElements,
  };
});

await check('integration', 'backend can administer users through Keycloak', async () => {
  const { body } = await api('security/users');
  assert(Array.isArray(body), 'Security users endpoint did not return a list');
  assert(
    body.some((user) => user.username === config.adminUsername),
    `Keycloak user ${config.adminUsername} was not returned by the backend`,
  );
  return { users: body.length };
});

await check('api', 'dashboard main flow returns operational data', async () => {
  const { body } = await api('reports/dashboard');
  assert(body && typeof body === 'object', 'Dashboard response was empty');
  assert(
    Object.keys(body).length > 0,
    'Dashboard response did not contain any data',
  );
  return { fields: Object.keys(body).sort() };
});

await check('api', 'product CRUD and product audit work against staging', async () => {
  const uniqueSuffix = `${Date.now()}-${process.pid}`;
  const sku = `STG-${uniqueSuffix}`;
  const original = {
    sku,
    name: `Staging verification ${uniqueSuffix}`,
    description: `Temporary product for ${config.deploymentId}`,
    category: 'Staging verification',
    price: 1250.50,
    currentStock: 0,
    minimumStock: 2,
    status: 'ACTIVE',
  };
  const created = await api(
    'products',
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(original),
    },
    [201],
  );
  temporaryProduct = created.body;
  assert(temporaryProduct?.id, 'Created product did not contain an id');

  const updatedPayload = {
    ...original,
    name: `${original.name} updated`,
    price: 1299.99,
    minimumStock: 3,
    status: 'INACTIVE',
  };
  const updated = await api(
    `products/${temporaryProduct.id}`,
    {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(updatedPayload),
    },
  );
  assert(updated.body.name === updatedPayload.name, 'Product update was not persisted');

  const revisions = await poll(
    'product audit revisions',
    async () => {
      const { body } = await api(
        `audit/products/${temporaryProduct.id}/revisions`,
      );
      return Array.isArray(body)
        && body.length >= 2
        && body.some((revision) => (
          JSON.stringify(revision).includes(updatedPayload.name)
        ))
        ? body
        : null;
    },
    30_000,
  );

  await api(`products/${temporaryProduct.id}`, { method: 'DELETE' }, [204]);
  temporaryProductDeleted = true;
  await request(
    joinUrl(config.frontendUrl, `api/products/${temporaryProduct.id}`),
    { headers: authenticatedHeaders() },
    [404],
  );

  return {
    sku,
    revisions: revisions.length,
    deletionVerified: true,
  };
});

await check('api', 'stock movement and audit flow restore their initial state', async () => {
  const search = await api('products?search=DELL-LAT-5440&size=10');
  const product = search.body?.content?.find(
    (candidate) => candidate.sku === 'DELL-LAT-5440',
  );
  assert(product?.id, 'Stock test product was not found');
  const initialStock = product.currentStock;
  const marker = `staging-${config.deploymentId}-${Date.now()}`;
  let restoreRequired = false;

  try {
    const entry = await api(
      `products/${product.id}/stock/entries`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ quantity: 1, observations: marker }),
      },
    );
    restoreRequired = true;
    assert(
      entry.body?.newQuantity === initialStock + 1,
      'Stock entry did not increment the product',
    );

    const movements = await api(`products/${product.id}/stock-movements`);
    assert(
      movements.body.some((movement) => movement.observations === marker),
      'Created stock movement was not present in history',
    );

    await api(
      `products/${product.id}/stock/adjustments`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          newQuantity: initialStock,
          observations: `${marker}-restore`,
        }),
      },
    );
    restoreRequired = false;

    const revisions = await poll(
      'stock audit revisions',
      async () => {
        const { body } = await api(
          `audit/products/${product.id}/stock-movements/revisions`,
        );
        return Array.isArray(body)
          && body.length >= 2
          && body.some((revision) => JSON.stringify(revision).includes(marker))
          ? body
          : null;
      },
      30_000,
    );
    return {
      sku: product.sku,
      initialStock,
      restoredStock: initialStock,
      auditRevisions: revisions.length,
    };
  } finally {
    if (restoreRequired) {
      await api(
        `products/${product.id}/stock/adjustments`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            newQuantity: initialStock,
            observations: `${marker}-emergency-restore`,
          }),
        },
      ).catch(() => undefined);
    }
  }
});

const readinessEndpoints = [
  ['Prometheus', joinUrl(config.prometheusUrl, '-/ready')],
  ['Grafana', joinUrl(config.grafanaUrl, 'api/health')],
  ['Loki', joinUrl(config.lokiUrl, 'ready')],
  ['Tempo', joinUrl(config.tempoUrl, 'ready')],
  ['Alertmanager', joinUrl(config.alertmanagerUrl, '-/ready')],
  ['Alloy', joinUrl(config.alloyUrl, '-/ready')],
];

for (const [serviceName, readinessUrl] of readinessEndpoints) {
  await check('observability', `${serviceName} readiness`, async () => {
    const { response, body } = await poll(
      `${serviceName} readiness`,
      async () => {
        try {
          return await request(readinessUrl);
        } catch {
          return null;
        }
      },
      60_000,
    );
    return {
      status: response.status,
      response: typeof body === 'string' ? body.trim().slice(0, 120) : body,
    };
  });
}

await check('observability', 'Prometheus scrapes the staging backend', async () => {
  const targetsUrl = joinUrl(config.prometheusUrl, 'api/v1/targets?state=active');
  const target = await poll(
    'Prometheus backend target',
    async () => {
      const { body } = await request(targetsUrl);
      const activeTargets = body?.data?.activeTargets;
      if (!Array.isArray(activeTargets)) {
        return null;
      }
      return activeTargets.find((candidate) => (
        candidate?.labels?.job === 'inventory-backend'
        && candidate.health === 'up'
        && Date.parse(candidate.lastScrape) >= startedAt.getTime()
      )) ?? null;
    },
  );
  return {
    job: target.labels.job,
    health: target.health,
    lastScrape: target.lastScrape,
  };
});

await check('observability', 'Grafana has provisioned all staging datasources', async () => {
  const { body } = await request(
    joinUrl(config.grafanaUrl, 'api/datasources'),
    {
      headers: {
        Authorization: basicAuthentication(
          config.grafanaUsername,
          config.grafanaPassword,
        ),
      },
    },
  );
  assert(Array.isArray(body), 'Grafana datasources response was not a list');
  const expectedDatasources = [
    {
      name: 'Prometheus',
      uid: 'prometheus',
      type: 'prometheus',
      url: 'http://prometheus:9090',
    },
    {
      name: 'Loki',
      uid: 'loki',
      type: 'loki',
      url: 'http://loki:3100',
    },
    {
      name: 'Tempo',
      uid: 'tempo',
      type: 'tempo',
      url: 'http://tempo:3200',
    },
  ];
  for (const expected of expectedDatasources) {
    const datasource = body.find((candidate) => candidate.uid === expected.uid);
    assert(
      datasource,
      `Grafana datasource UID was not provisioned: ${expected.uid}`,
    );
    assert(
      datasource.name === expected.name
        && datasource.type === expected.type
        && datasource.url === expected.url
        && datasource.access === 'proxy',
      `Grafana datasource ${expected.uid} does not match its provisioned contract`,
    );
  }
  return {
    datasources: expectedDatasources.map(({ name, uid, type, url }) => ({
      name,
      uid,
      type,
      url,
    })),
  };
});

await check('observability', 'Loki ingested this run from the isolated staging project', async () => {
  const query = `{compose_project="${quotedQueryValue(config.composeProject)}"}`
    + ` |= "${quotedQueryValue(config.observabilityLogMarker)}"`;
  const queryUrl = new URL(joinUrl(config.lokiUrl, 'loki/api/v1/query_range'));
  queryUrl.searchParams.set('query', query);
  queryUrl.searchParams.set('start', String(startedAt.getTime() * 1_000_000));
  queryUrl.searchParams.set('end', String(Date.now() * 1_000_000));
  queryUrl.searchParams.set('limit', '20');

  const streams = await poll(
    'current staging Loki log ingestion',
    async () => {
      queryUrl.searchParams.set('end', String(Date.now() * 1_000_000));
      const { body } = await request(queryUrl);
      const result = body?.data?.result;
      return Array.isArray(result)
        && result.some((stream) => (
          stream?.stream?.compose_project === config.composeProject
          && Array.isArray(stream.values)
          && stream.values.some((entry) => entry?.[1]?.includes(
            config.observabilityLogMarker,
          ))
        ))
        ? result
        : null;
    },
  );
  return {
    composeProject: config.composeProject,
    currentRunMarkerFound: true,
    streams: streams.length,
  };
});

await check('observability', 'Tempo received traces from this staging deployment', async () => {
  const searchUrl = new URL(joinUrl(config.tempoUrl, 'api/search'));
  searchUrl.searchParams.set(
    'q',
    `{ resource.service.name = "inventory-backend" `
      + `&& resource.deployment.id = "${quotedQueryValue(config.deploymentId)}" }`,
  );
  searchUrl.searchParams.set('start', String(Math.floor(startedAt.getTime() / 1000)));
  searchUrl.searchParams.set('end', String(Math.floor(Date.now() / 1000)));
  searchUrl.searchParams.set('limit', '20');
  const traces = await poll(
    'current staging Tempo trace ingestion',
    async () => {
      searchUrl.searchParams.set('end', String(Math.floor(Date.now() / 1000)));
      const { body } = await request(searchUrl);
      if (!Array.isArray(body?.traces)) {
        return null;
      }
      return body.traces.filter((trace) => (
        trace.rootServiceName === 'inventory-backend'
        && Number(trace.startTimeUnixNano) >= startedAt.getTime() * 1_000_000
      )).length > 0
        ? body.traces
        : null;
    },
  );
  return {
    deploymentId: config.deploymentId,
    traces: traces.length,
  };
});

await check('observability', 'Alertmanager exposes its runtime status', async () => {
  const { body } = await request(
    joinUrl(config.alertmanagerUrl, 'api/v2/status'),
  );
  assert(body?.cluster, 'Alertmanager status did not contain cluster data');
  return {
    clusterStatus: body.cluster.status,
    version: body.versionInfo?.version,
  };
});

if (temporaryProduct && !temporaryProductDeleted && accessToken) {
  await api(`products/${temporaryProduct.id}`, { method: 'DELETE' }, [204])
    .catch(() => undefined);
}

const finishedAt = new Date();
const failed = results.filter((result) => result.status === 'failed');
const report = {
  environment: 'staging',
  lifecycle: config.lifecycle,
  visibility: config.visibility,
  deploymentId: config.deploymentId,
  startedAt: startedAt.toISOString(),
  finishedAt: finishedAt.toISOString(),
  durationMs: finishedAt.getTime() - startedAt.getTime(),
  totals: {
    checks: results.length,
    passed: results.length - failed.length,
    failed: failed.length,
  },
  urls: {
    frontend: config.frontendUrl,
    backendDiagnostics: config.backendUrl,
    keycloak: config.keycloakUrl,
  },
  results,
};

function xmlEscape(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
}

const testCases = results.map((result) => {
  const failure = result.status === 'failed'
    ? `\n    <failure message="${xmlEscape(result.error)}">${xmlEscape(result.error)}</failure>`
    : '';
  return `  <testcase classname="staging.${xmlEscape(result.suite)}" `
    + `name="${xmlEscape(result.name)}" time="${(result.durationMs / 1000).toFixed(3)}">`
    + `${failure}\n  </testcase>`;
}).join('\n');
const junit = `<?xml version="1.0" encoding="UTF-8"?>\n`
  + `<testsuite name="staging-post-deploy" tests="${results.length}" `
  + `failures="${failed.length}" time="${(report.durationMs / 1000).toFixed(3)}">\n`
  + `${testCases}\n</testsuite>\n`;

const markdownLines = [
  '# Staging post-deploy verification',
  '',
  `- Result: **${failed.length === 0 ? 'PASS' : 'FAIL'}**`,
  `- Deployment: \`${config.deploymentId}\``,
  `- Started: \`${report.startedAt}\``,
  `- Finished: \`${report.finishedAt}\``,
  `- Checks: ${report.totals.checks}`,
  `- Passed: ${report.totals.passed}`,
  `- Failed: ${report.totals.failed}`,
  `- Lifecycle: ${config.lifecycle}`,
  `- Visibility: ${config.visibility} (loopback only)`,
  '',
  '| Suite | Check | Result | Duration |',
  '|---|---|---:|---:|',
  ...results.map((result) => (
    `| ${result.suite} | ${result.name.replaceAll('|', '\\|')} `
    + `| ${result.status === 'passed' ? 'PASS' : 'FAIL'} `
    + `| ${result.durationMs} ms |`
  )),
];
if (failed.length > 0) {
  markdownLines.push('', '## Failures', '');
  for (const result of failed) {
    markdownLines.push(
      `- **${result.suite} / ${result.name}:** ${result.error}`,
    );
  }
}
markdownLines.push('', 'No credentials or access tokens are included in this report.', '');

await Promise.all([
  writeFile(
    path.join(evidenceDirectory, 'results.json'),
    `${JSON.stringify(report, null, 2)}\n`,
    { mode: 0o600 },
  ),
  writeFile(
    path.join(evidenceDirectory, 'junit.xml'),
    junit,
    { mode: 0o600 },
  ),
  writeFile(
    path.join(evidenceDirectory, 'summary.md'),
    markdownLines.join('\n'),
    { mode: 0o600 },
  ),
]);

process.stdout.write(
  `Post-deploy evidence: ${evidenceDirectory} `
  + `(${report.totals.passed}/${report.totals.checks} passed)\n`,
);
if (failed.length > 0) {
  process.exitCode = 1;
}
