import { Injectable, inject, signal } from '@angular/core';
import Keycloak, { KeycloakTokenParsed } from 'keycloak-js';
import { KEYCLOAK_FACTORY, SESSION_NAVIGATOR, loadAuthRuntimeConfig } from './auth.config';

export type AuthStatus = 'initializing' | 'authenticated' | 'anonymous' | 'expired' | 'error';

export interface AuthUser {
  id: string;
  username: string;
  displayName: string;
}

interface InventoryTokenParsed extends KeycloakTokenParsed {
  permissions?: string[];
  scope?: string;
  preferred_username?: string;
  name?: string;
  given_name?: string;
  family_name?: string;
}

const TOKEN_MIN_VALIDITY_SECONDS = 60;

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private readonly createKeycloak = inject(KEYCLOAK_FACTORY);
  private readonly sessionNavigator = inject(SESSION_NAVIGATOR);
  private keycloak?: Keycloak;
  private refreshPromise?: Promise<string | null>;
  private refreshTimer?: ReturnType<typeof setTimeout>;
  private initialized = false;
  private expiringSession = false;

  private readonly statusState = signal<AuthStatus>('initializing');
  private readonly userState = signal<AuthUser | null>(null);
  private readonly permissionsState = signal<ReadonlySet<string>>(new Set());

  readonly status = this.statusState.asReadonly();
  readonly user = this.userState.asReadonly();
  readonly permissions = this.permissionsState.asReadonly();

  async initialize(): Promise<void> {
    if (this.initialized) {
      return;
    }

    this.initialized = true;

    try {
      const config = await loadAuthRuntimeConfig();
      this.keycloak = this.createKeycloak(config);
      this.registerCallbacks(this.keycloak);

      const authenticated = await this.keycloak.init({
        onLoad: 'check-sso',
        silentCheckSsoRedirectUri: `${window.location.origin}/silent-check-sso.html`,
        silentCheckSsoFallback: true,
        checkLoginIframe: true,
        flow: 'standard',
        pkceMethod: 'S256',
        responseMode: 'fragment'
      });

      if (authenticated) {
        this.synchronizeSession();
        this.scheduleRefresh();
      } else {
        this.clearSession('anonymous');
      }
    } catch {
      this.clearSession('error');
    }
  }

  isAuthenticated(): boolean {
    return this.statusState() === 'authenticated';
  }

  hasPermission(permission: string): boolean {
    return this.permissionsState().has(permission);
  }

  async login(returnUrl = '/'): Promise<void> {
    if (!this.keycloak) {
      throw new Error('El servicio de autenticación no está disponible.');
    }

    await this.keycloak.login({
      redirectUri: this.absoluteApplicationUrl(returnUrl)
    });
  }

  async logout(): Promise<void> {
    if (!this.keycloak) {
      this.clearSession('anonymous');
      this.sessionNavigator.assign('/login');
      return;
    }

    try {
      await this.keycloak.logout({
        redirectUri: `${window.location.origin}/login`
      });
    } catch {
      this.clearSession('anonymous');
      this.sessionNavigator.assign('/login');
    }
  }

  getValidAccessToken(minValidity = TOKEN_MIN_VALIDITY_SECONDS): Promise<string | null> {
    if (!this.keycloak?.authenticated) {
      return Promise.resolve(null);
    }

    return this.refreshAccessToken(minValidity);
  }

  forceRefreshAccessToken(): Promise<string | null> {
    return this.refreshAccessToken(-1);
  }

  private refreshAccessToken(minValidity: number): Promise<string | null> {
    if (!this.keycloak?.authenticated) {
      return Promise.resolve(null);
    }

    if (this.refreshPromise) {
      return this.refreshPromise;
    }

    const keycloak = this.keycloak;
    const refreshOperation = keycloak.updateToken(minValidity)
      .then(() => {
        this.synchronizeSession();
        this.scheduleRefresh();
        return keycloak.token ?? null;
      })
      .catch(() => {
        this.expireSession();
        return null;
      })
      .finally(() => {
        if (this.refreshPromise === refreshOperation) {
          this.refreshPromise = undefined;
        }
      });

    this.refreshPromise = refreshOperation;
    return refreshOperation;
  }

  private registerCallbacks(keycloak: Keycloak): void {
    keycloak.onAuthSuccess = () => {
      this.synchronizeSession();
      this.scheduleRefresh();
    };
    keycloak.onAuthRefreshSuccess = () => {
      this.synchronizeSession();
      this.scheduleRefresh();
    };
    keycloak.onAuthRefreshError = () => this.expireSession();
    keycloak.onAuthLogout = () => this.expireSession();
    keycloak.onTokenExpired = () => {
      void this.refreshAccessToken(TOKEN_MIN_VALIDITY_SECONDS);
    };
  }

  private synchronizeSession(): void {
    if (!this.keycloak?.authenticated || !this.keycloak.token) {
      this.clearSession('anonymous');
      return;
    }

    const token = this.keycloak.tokenParsed as InventoryTokenParsed | undefined;
    const username = token?.preferred_username ?? token?.sub ?? 'usuario';
    const displayName = token?.name
      ?? [token?.given_name, token?.family_name].filter(Boolean).join(' ')
      ?? username;

    this.userState.set({
      id: token?.sub ?? username,
      username,
      displayName: displayName || username
    });
    this.permissionsState.set(new Set([
      ...(token?.permissions ?? []),
      ...(token?.scope?.split(/\s+/).filter(Boolean) ?? [])
    ]));
    this.statusState.set('authenticated');
    this.expiringSession = false;
  }

  private scheduleRefresh(): void {
    this.clearRefreshTimer();

    const expiresAt = this.keycloak?.tokenParsed?.exp;
    if (!expiresAt) {
      return;
    }

    const nowInSeconds = Date.now() / 1000;
    const delay = Math.max(
      (expiresAt - nowInSeconds - TOKEN_MIN_VALIDITY_SECONDS) * 1000,
      0
    );

    this.refreshTimer = setTimeout(() => {
      void this.refreshAccessToken(TOKEN_MIN_VALIDITY_SECONDS);
    }, delay);
  }

  private expireSession(): void {
    if (this.expiringSession) {
      return;
    }

    this.expiringSession = true;
    this.keycloak?.clearToken();
    this.clearSession('expired');

    if (window.location.pathname !== '/login') {
      this.sessionNavigator.replace('/login?reason=expired');
    }
  }

  private clearSession(status: Exclude<AuthStatus, 'initializing' | 'authenticated'>): void {
    this.clearRefreshTimer();
    this.userState.set(null);
    this.permissionsState.set(new Set());
    this.statusState.set(status);
  }

  private clearRefreshTimer(): void {
    if (this.refreshTimer) {
      clearTimeout(this.refreshTimer);
      this.refreshTimer = undefined;
    }
  }

  private absoluteApplicationUrl(returnUrl: string): string {
    const safePath = returnUrl.startsWith('/') && !returnUrl.startsWith('//')
      ? returnUrl
      : '/';
    return new URL(safePath, window.location.origin).href;
  }
}
