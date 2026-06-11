import { TestBed } from '@angular/core/testing';
import Keycloak from 'keycloak-js';
import { KEYCLOAK_FACTORY, SESSION_NAVIGATOR, SessionNavigator } from './auth.config';
import { AuthService } from './auth.service';

describe('AuthService', () => {
  let service: AuthService;
  let keycloak: jasmine.SpyObj<Keycloak>;
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
        { provide: KEYCLOAK_FACTORY, useValue: () => keycloak },
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
});
