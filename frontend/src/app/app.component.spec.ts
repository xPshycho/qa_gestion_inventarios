import { ComponentFixture, TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { provideRouter } from '@angular/router';
import { AppComponent } from './app.component';
import { AuthService } from './auth/auth.service';

describe('AppComponent', () => {
  let fixture: ComponentFixture<AppComponent>;
  let authService: jasmine.SpyObj<AuthService>;

  beforeEach(async () => {
    authService = {
      user: signal({ id: 'user-1', username: 'carlos', displayName: 'Carlos Hernandez' }),
      isAuthenticated: jasmine.createSpy('isAuthenticated'),
      hasPermission: jasmine.createSpy('hasPermission'),
      logout: jasmine.createSpy('logout')
    } as unknown as jasmine.SpyObj<AuthService>;
    authService.isAuthenticated.and.returnValue(false);
    authService.hasPermission.and.returnValue(false);
    authService.logout.and.returnValue(Promise.resolve());

    await TestBed.configureTestingModule({
      imports: [AppComponent],
      providers: [
        { provide: AuthService, useValue: authService },
        provideRouter([])
      ]
    }).compileComponents();

    fixture = TestBed.createComponent(AppComponent);
    fixture.detectChanges();
  });

  it('renderiza el contenedor principal de rutas', () => {
    const compiled = fixture.nativeElement as HTMLElement;

    expect(compiled.querySelector('router-outlet')).not.toBeNull();
  });

  it('muestra el enlace de seguridad solo con user manage', () => {
    authService.isAuthenticated.and.returnValue(true);
    authService.hasPermission.withArgs('user:manage').and.returnValue(true);
    fixture.detectChanges();

    const compiled = fixture.nativeElement as HTMLElement;

    expect(compiled.textContent).toContain('Seguridad');
  });
});
