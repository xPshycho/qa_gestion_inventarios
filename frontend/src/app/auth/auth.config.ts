export interface AuthRuntimeConfig {
  url: string;
  realm: string;
  clientId: string;
}

const AUTH_CONFIG_URL = '/auth-config.json';

export async function loadAuthRuntimeConfig(): Promise<AuthRuntimeConfig> {
  const response = await fetch(AUTH_CONFIG_URL, { cache: 'no-store' });

  if (!response.ok) {
    throw new Error(`No se pudo cargar la configuracion de autenticacion (${response.status}).`);
  }

  const config: unknown = await response.json();

  if (!isAuthRuntimeConfig(config)) {
    throw new Error('La configuracion de autenticacion no es valida.');
  }

  return config;
}

function isAuthRuntimeConfig(value: unknown): value is AuthRuntimeConfig {
  if (!value || typeof value !== 'object') {
    return false;
  }

  const config = value as Record<string, unknown>;
  return isNonEmptyString(config['url'])
    && isNonEmptyString(config['realm'])
    && isNonEmptyString(config['clientId']);
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}
