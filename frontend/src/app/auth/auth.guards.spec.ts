import { TestBed } from '@angular/core/testing';
import { ActivatedRouteSnapshot, Router, RouterStateSnapshot, UrlTree, provideRouter } from '@angular/router';
import { AuthService } from './auth.service';
import {
  authGuard,
  homeGuard,
  loginGuard,
  permissionGuard
} from './auth.guards';

describe('permissionGuard', () => {
  let authService: jasmine.SpyObj<AuthService>;
  let router: Router;

  beforeEach(() => {
    authService = jasmine.createSpyObj<AuthService>(
      'AuthService',
      ['isAuthenticated', 'hasPermission']
    );

    TestBed.configureTestingModule({
      providers: [
        { provide: AuthService, useValue: authService },
        provideRouter([])
      ]
    });

    router = TestBed.inject(Router);
  });

  it('permite acceder cuando el usuario posee el permiso requerido', () => {
    authService.isAuthenticated.and.returnValue(true);
    authService.hasPermission.and.returnValue(true);

    const result = executeGuard('product:view', '/productos');

    expect(result).toBeTrue();
    expect(authService.hasPermission).toHaveBeenCalledWith('product:view');
  });

  it('redirige al login cuando no existe una sesion autenticada', () => {
    authService.isAuthenticated.and.returnValue(false);

    const result = executeGuard('product:view', '/productos') as UrlTree;

    expect(router.serializeUrl(result)).toBe('/login?returnUrl=%2Fproductos');
  });

  it('redirige a acceso denegado cuando falta el permiso', () => {
    authService.isAuthenticated.and.returnValue(true);
    authService.hasPermission.and.returnValue(false);

    const result = executeGuard('report:view', '/dashboard') as UrlTree;

    expect(router.serializeUrl(result)).toBe('/forbidden');
  });

  it('authGuard permite sesion y conserva retorno para anonimos', () => {
    authService.isAuthenticated.and.returnValues(true, false);
    const route = new ActivatedRouteSnapshot();
    const state = { url: '/auditoria' } as RouterStateSnapshot;

    const allowed = TestBed.runInInjectionContext(() => authGuard(route, state));
    const redirected = TestBed.runInInjectionContext(
      () => authGuard(route, state)
    ) as UrlTree;

    expect(allowed).toBeTrue();
    expect(router.serializeUrl(redirected)).toBe(
      '/login?returnUrl=%2Fauditoria'
    );
  });

  it('loginGuard permite anonimos y envia sesiones al destino por defecto', () => {
    authService.isAuthenticated.and.returnValues(false, true, true);
    authService.hasPermission.and.returnValue(true);

    const anonymous = TestBed.runInInjectionContext(() => loginGuard(
      new ActivatedRouteSnapshot(),
      { url: '/login' } as RouterStateSnapshot
    ));
    const authenticated = TestBed.runInInjectionContext(() => loginGuard(
      new ActivatedRouteSnapshot(),
      { url: '/login' } as RouterStateSnapshot
    )) as UrlTree;

    expect(anonymous).toBeTrue();
    expect(router.serializeUrl(authenticated)).toBe('/dashboard');
  });

  it('homeGuard selecciona productos o forbidden segun permisos', () => {
    authService.isAuthenticated.and.returnValue(true);
    authService.hasPermission.and.callFake(
      (permission) => permission === 'product:view'
    );
    const route = new ActivatedRouteSnapshot();
    const state = { url: '/' } as RouterStateSnapshot;

    const products = TestBed.runInInjectionContext(
      () => homeGuard(route, state)
    ) as UrlTree;
    authService.hasPermission.and.returnValue(false);
    const forbidden = TestBed.runInInjectionContext(
      () => homeGuard(route, state)
    ) as UrlTree;

    expect(router.serializeUrl(products)).toBe('/productos');
    expect(router.serializeUrl(forbidden)).toBe('/forbidden');
  });

  it('homeGuard envia anonimos al login', () => {
    authService.isAuthenticated.and.returnValue(false);

    const result = TestBed.runInInjectionContext(() => homeGuard(
      new ActivatedRouteSnapshot(),
      { url: '/' } as RouterStateSnapshot
    )) as UrlTree;

    expect(router.serializeUrl(result)).toBe('/login');
  });

  function executeGuard(permission: string, url: string) {
    const route = new ActivatedRouteSnapshot();
    route.data = { permission };
    const state = { url } as RouterStateSnapshot;

    return TestBed.runInInjectionContext(() => permissionGuard(route, state));
  }
});
