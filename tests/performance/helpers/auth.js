import http from 'k6/http';
import { check, fail } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

const authRequests = new Counter('endpoint_auth_requests');
const authFailed = new Rate('endpoint_auth_failed');
const authDuration = new Trend('endpoint_auth_duration', true);

function formEncode(values) {
  return Object.keys(values)
    .filter((key) => values[key] !== undefined && values[key] !== null && values[key] !== '')
    .map((key) => `${encodeURIComponent(key)}=${encodeURIComponent(values[key])}`)
    .join('&');
}

export function getAccessToken(config) {
  if (config.accessToken) {
    return config.accessToken;
  }

  const tokenUrl = `${config.keycloakUrl}/realms/${config.keycloakRealm}/protocol/openid-connect/token`;
  const payload = {
    grant_type: 'password',
    client_id: config.keycloakClientId,
    username: config.username,
    password: config.password,
  };

  if (config.keycloakClientSecret) {
    payload.client_secret = config.keycloakClientSecret;
  }

  const response = http.post(tokenUrl, formEncode(payload), {
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    tags: {
      endpoint: 'auth',
      name: 'POST Keycloak token',
    },
  });
  authRequests.add(1);
  authFailed.add(response.status === 0 || response.status >= 400);
  authDuration.add(response.timings.duration);

  const authOk = check(response, {
    'auth status is 200': (res) => res.status === 200,
    'auth response is json': (res) => hasJsonContent(res),
  });

  if (!authOk) {
    fail(`Keycloak token request failed with status ${response.status}`);
  }

  let body;
  try {
    body = response.json();
  } catch (error) {
    fail('Keycloak token response is not valid JSON');
  }

  if (!body || !body.access_token) {
    fail('Keycloak token response does not contain access_token');
  }

  return body.access_token;
}

export function authHeaders(token) {
  return {
    Accept: 'application/json',
    Authorization: `Bearer ${token}`,
  };
}

export function hasJsonContent(response) {
  const contentType = response.headers['Content-Type'] || response.headers['content-type'] || '';
  return contentType.toLowerCase().includes('application/json');
}
