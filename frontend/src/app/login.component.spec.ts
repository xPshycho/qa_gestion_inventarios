import { signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { ActivatedRoute, convertToParamMap } from '@angular/router';
import { AuthService, AuthStatus } from './auth/auth.service';
import { LoginComponent } from './login.component';

describe('LoginComponent', () => {
  let authService: jasmine.SpyObj<AuthService>;

  function createComponent(queryParams: Record<string, string> = {}) {
    TestBed.configureTestingModule({
      providers: [
        {
          provide: ActivatedRoute,
          useValue: {
            snapshot: { queryParamMap: convertToParamMap(queryParams) }
          }
        },
        { provide: AuthService, useValue: authService }
      ]
    });
    return TestBed.runInInjectionContext(() => new LoginComponent());
  }

  beforeEach(() => {
    authService = jasmine.createSpyObj<AuthService>('AuthService', ['login'], {
      status: signal<AuthStatus>('anonymous').asReadonly()
    });
    authService.login.and.resolveTo();
  });

  it('detecta una sesion expirada y envia el retorno solicitado', async () => {
    const component = createComponent({
      reason: 'expired',
      returnUrl: '/productos'
    });

    expect(component.sessionExpired).toBeTrue();
    expect(component.authenticationUnavailable).toBeFalse();

    await component.login();

    expect(component.loginInProgress).toBeTrue();
    expect(authService.login).toHaveBeenCalledWith('/productos');
  });

  it('usa la raiz por defecto y muestra errores de autenticacion', async () => {
    authService.login.and.rejectWith(new Error('unavailable'));
    const component = createComponent();

    await component.login();

    expect(component.sessionExpired).toBeFalse();
    expect(component.loginInProgress).toBeFalse();
    expect(component.loginError).toBe(
      'No se pudo iniciar el proceso de autenticación.'
    );
    expect(authService.login).toHaveBeenCalledWith('/');
  });
});
