import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';
import { getAccessToken, authHeaders, hasJsonContent } from './helpers/auth.js';
import { buildSummaryOutput } from './helpers/summary.js';
import { buildThresholds, loadEnvironment, publicContext, urlFor } from './helpers/environment.js';
import { resolveProfile } from './config/profiles.js';

const config = loadEnvironment();
const selectedProfile = resolveProfile(config.profile);
const context = publicContext(config);

const requestPattern = [
  'products', 'products', 'products', 'products', 'products',
  'products', 'products', 'products', 'products', 'products', 'products',
  'reports', 'reports', 'reports', 'reports', 'reports', 'reports',
  'health', 'health', 'health',
];

const endpointMetrics = {
  health: metricsFor('health'),
  products: metricsFor('products'),
  reports: metricsFor('reports'),
};

export const options = {
  scenarios: {
    inventory_read_mix: selectedProfile.scenario,
  },
  thresholds: buildThresholds(config),
  summaryTrendStats: ['avg', 'min', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
};

export function setup() {
  const token = getAccessToken(config);
  return { token };
}

export default function inventoryReadMix(data) {
  const endpoint = requestPattern[__ITER % requestPattern.length];

  if (endpoint === 'products') {
    requestProducts(data.token);
  } else if (endpoint === 'reports') {
    requestReports(data.token);
  } else {
    requestHealth();
  }

  sleep(config.sleepSeconds);
}

export function handleSummary(data) {
  return buildSummaryOutput(data, context);
}

function metricsFor(endpoint) {
  return {
    requests: new Counter(`endpoint_${endpoint}_requests`),
    failed: new Rate(`endpoint_${endpoint}_failed`),
    duration: new Trend(`endpoint_${endpoint}_duration`, true),
  };
}

function recordEndpoint(endpoint, response) {
  endpointMetrics[endpoint].requests.add(1);
  endpointMetrics[endpoint].failed.add(response.status === 0 || response.status >= 400);
  endpointMetrics[endpoint].duration.add(response.timings.duration);
}

function parseJson(response) {
  try {
    return response.json();
  } catch (error) {
    return null;
  }
}

function requestHealth() {
  const response = http.get(urlFor(config, config.healthPath), {
    headers: { Accept: 'application/json' },
    tags: {
      endpoint: 'health',
      name: 'GET /actuator/health',
    },
  });
  recordEndpoint('health', response);

  const body = parseJson(response);
  check(response, {
    'health status is 200': (res) => res.status === 200,
    'health response is json': (res) => hasJsonContent(res),
    'health status is UP': () => body !== null && body.status === 'UP',
  }, { endpoint: 'health' });
}

function requestProducts(token) {
  const response = http.get(urlFor(config, config.productsPath), {
    headers: authHeaders(token),
    tags: {
      endpoint: 'products',
      name: 'GET /products',
    },
  });
  recordEndpoint('products', response);

  const body = parseJson(response);
  const firstProduct = body && Array.isArray(body.content) && body.content.length > 0
    ? body.content[0]
    : null;

  check(response, {
    'products status is 200': (res) => res.status === 200,
    'products response is json': (res) => hasJsonContent(res),
    'products content is array': () => body !== null && Array.isArray(body.content),
    'products content is not empty': () => firstProduct !== null,
    'products pagination fields exist': () => body !== null
      && Number.isInteger(body.page)
      && Number.isInteger(body.size)
      && typeof body.totalElements === 'number'
      && Number.isInteger(body.totalPages),
    'products item has required fields': () => firstProduct !== null
      && typeof firstProduct.id === 'number'
      && typeof firstProduct.sku === 'string'
      && typeof firstProduct.name === 'string'
      && typeof firstProduct.category === 'string'
      && typeof firstProduct.currentStock === 'number'
      && typeof firstProduct.status === 'string',
  }, { endpoint: 'products' });
}

function requestReports(token) {
  const response = http.get(urlFor(config, config.reportsPath), {
    headers: authHeaders(token),
    tags: {
      endpoint: 'reports',
      name: 'GET /reports/dashboard',
    },
  });
  recordEndpoint('reports', response);

  const body = parseJson(response);
  const metrics = body && body.metrics ? body.metrics : null;

  check(response, {
    'reports status is 200': (res) => res.status === 200,
    'reports response is json': (res) => hasJsonContent(res),
    'reports metrics exist': () => metrics !== null,
    'reports metrics have numeric totals': () => metrics !== null
      && typeof metrics.totalProducts === 'number'
      && typeof metrics.activeProducts === 'number'
      && typeof metrics.criticalProducts === 'number'
      && typeof metrics.totalStockUnits === 'number'
      && typeof metrics.inventoryValue === 'number'
      && typeof metrics.totalMovements === 'number',
    'reports lists exist': () => body !== null
      && Array.isArray(body.criticalProducts)
      && Array.isArray(body.mostMovedProducts)
      && Array.isArray(body.recentMovements),
  }, { endpoint: 'reports' });
}
