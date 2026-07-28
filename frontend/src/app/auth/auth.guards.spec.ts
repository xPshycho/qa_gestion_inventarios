import { TestBed } from '@angular/core/testing';
import { ActivatedRouteSnapshot, Router, RouterStateSnapshot, UrlTree, provideRouter } from '@angular/router';
import { AuthService } from './auth.service';
import { permissionGuard } from './auth.guards';

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

  function executeGuard(permission: string, url: string) {
    const route = new ActivatedRouteSnapshot();
    route.data = { permission };
    const state = { url } as RouterStateSnapshot;

    return TestBed.runInInjectionContext(() => permissionGuard(route, state));
  }
});
