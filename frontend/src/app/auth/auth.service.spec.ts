import { TestBed } from '@angular/core/testing';
import Keycloak from 'keycloak-js';
import {
  KEYCLOAK_FACTORY,
  KeycloakFactory,
  SESSION_NAVIGATOR,
  SessionNavigator
} from './auth.config';
import { AuthService } from './auth.service';

describe('AuthService', () => {
  let service: AuthService;
  let keycloak: jasmine.SpyObj<Keycloak>;
  let keycloakFactory: jasmine.Spy<KeycloakFactory>;
  let sessionNavigator: jasmine.SpyObj<SessionNavigator>;

  beforeEach(() => {
    keycloak = jasmine.createSpyObj<Keycloak>(
      'Keycloak',
      ['init', 'login', 'logout', 'updateToken', 'clearToken']
    );
    keycloak.authenticated = true;
    keycloak.token = 'access-token';
    keycloak.tokenParsed = {
      sub: 'user-1',
      preferred_username: 'viewer',
      name: 'Usuario Consulta',
      permissions: ['product:view'],
      scope: 'report:view'
    };
    keycloak.init.and.resolveTo(true);
    keycloak.updateToken.and.resolveTo(false);
    keycloak.login.and.resolveTo();
    keycloak.logout.and.resolveTo();
    keycloakFactory = jasmine.createSpy('keycloakFactory').and.returnValue(keycloak);
    sessionNavigator = jasmine.createSpyObj<SessionNavigator>(
      'SessionNavigator',
      ['assign', 'replace']
    );

    spyOn(window, 'fetch').and.resolveTo(new Response(JSON.stringify({
      url: 'http://localhost:8081',
      realm: 'inventory',
      clientId: 'inventory-frontend'
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    }));

    TestBed.configureTestingModule({
      providers: [
        AuthService,
        { provide: KEYCLOAK_FACTORY, useValue: keycloakFactory },
        { provide: SESSION_NAVIGATOR, useValue: sessionNavigator }
      ]
    });

    service = TestBed.inject(AuthService);
  });

  it('inicializa la sesion y obtiene usuario y permisos del token', async () => {
    await service.initialize();

    expect(service.isAuthenticated()).toBeTrue();
    expect(service.user()).toEqual({
      id: 'user-1',
      username: 'viewer',
      displayName: 'Usuario Consulta'
    });
    expect(service.hasPermission('product:view')).toBeTrue();
    expect(service.hasPermission('report:view')).toBeTrue();
    expect(keycloak.init).toHaveBeenCalledWith(jasmine.objectContaining({
      onLoad: 'check-sso',
      flow: 'standard',
      pkceMethod: 'S256'
    }));
  });

  it('renueva el token antes de entregarlo a una solicitud', async () => {
    await service.initialize();
    keycloak.updateToken.and.resolveTo(true);
    keycloak.token = 'refreshed-token';

    const token = await service.getValidAccessToken();

    expect(keycloak.updateToken).toHaveBeenCalledWith(60);
    expect(token).toBe('refreshed-token');
  });

  it('comparte una sola renovacion entre solicitudes concurrentes', async () => {
    await service.initialize();
    let resolveRefresh!: (refreshed: boolean) => void;
    keycloak.updateToken.and.returnValue(new Promise((resolve) => {
      resolveRefresh = resolve;
    }));

    const firstRequest = service.getValidAccessToken();
    const secondRequest = service.getValidAccessToken();
    resolveRefresh(true);

    expect(await firstRequest).toBe('access-token');
    expect(await secondRequest).toBe('access-token');
    expect(keycloak.updateToken).toHaveBeenCalledTimes(1);
  });

  it('limpia la sesion cuando falla la renovacion', async () => {
    await service.initialize();
    keycloak.updateToken.and.rejectWith(new Error('refresh failed'));

    const token = await service.getValidAccessToken();

    expect(token).toBeNull();
    expect(keycloak.clearToken).toHaveBeenCalled();
    expect(service.status()).toBe('expired');
    expect(service.user()).toBeNull();
    expect(sessionNavigator.replace).toHaveBeenCalledWith('/login?reason=expired');
  });

  it('no inicializa Keycloak mas de una vez', async () => {
    await service.initialize();
    await service.initialize();

    expect(keycloak.init).toHaveBeenCalledTimes(1);
    expect(keycloakFactory).toHaveBeenCalledTimes(1);
  });

  it('mantiene una sesion anonima cuando Keycloak no autentica', async () => {
    keycloak.init.and.resolveTo(false);

    await service.initialize();

    expect(service.status()).toBe('anonymous');
    expect(service.user()).toBeNull();
    expect(service.permissions().size).toBe(0);
  });

  it('expone error cuando la configuracion runtime no puede cargarse', async () => {
    (window.fetch as jasmine.Spy).and.resolveTo(new Response('', { status: 503 }));

    await service.initialize();

    expect(service.status()).toBe('error');
    expect(keycloakFactory).not.toHaveBeenCalled();
  });

  it('rechaza login antes de inicializar y sanea retornos externos', async () => {
    await expectAsync(service.login('/productos')).toBeRejectedWithError(
      'El servicio de autenticación no está disponible.'
    );
    await service.initialize();

    await service.login('//sitio-externo.example');

    expect(keycloak.login).toHaveBeenCalledWith({
      redirectUri: `${window.location.origin}/`
    });
  });

  it('cierra una sesion no inicializada mediante navegacion local', async () => {
    await service.logout();

    expect(service.status()).toBe('anonymous');
    expect(sessionNavigator.assign).toHaveBeenCalledWith('/login');
    expect(keycloak.logout).not.toHaveBeenCalled();
  });

  it('recupera localmente cuando Keycloak falla durante logout', async () => {
    await service.initialize();
    keycloak.logout.and.rejectWith(new Error('logout failed'));

    await service.logout();

    expect(service.status()).toBe('anonymous');
    expect(sessionNavigator.assign).toHaveBeenCalledWith('/login');
  });

  it('no intenta renovar sin sesion y fuerza refresh con validez negativa', async () => {
    expect(await service.getValidAccessToken()).toBeNull();
    await service.initialize();

    expect(await service.forceRefreshAccessToken()).toBe('access-token');
    expect(keycloak.updateToken).toHaveBeenCalledWith(-1);
  });

  it('procesa callbacks de Keycloak y evita expirar dos veces', async () => {
    await service.initialize();

    keycloak.onAuthRefreshError?.();
    keycloak.onAuthLogout?.();

    expect(service.status()).toBe('expired');
    expect(keycloak.clearToken).toHaveBeenCalledTimes(1);
    expect(sessionNavigator.replace).toHaveBeenCalledTimes(1);
  });

  it('construye el nombre desde claims parciales y combina scopes vacios', async () => {
    keycloak.tokenParsed = {
      sub: 'user-2',
      given_name: 'Ana',
      family_name: 'Pérez',
      scope: '  product:view   stock:view  '
    };

    await service.initialize();

    expect(service.user()).toEqual({
      id: 'user-2',
      username: 'user-2',
      displayName: 'Ana Pérez'
    });
    expect(service.permissions()).toEqual(new Set(['product:view', 'stock:view']));
  });
});
