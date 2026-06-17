import { ComponentFixture, TestBed } from '@angular/core/testing';
import { By } from '@angular/platform-browser';
import { of, throwError } from 'rxjs';
import { SecurityAdminService } from './security-admin.service';
import { SecurityAdminComponent } from './security-admin.component';

describe('SecurityAdminComponent', () => {
  let fixture: ComponentFixture<SecurityAdminComponent>;
  let component: SecurityAdminComponent;
  let securityAdminService: jasmine.SpyObj<SecurityAdminService>;

  const users = [
    {
      id: 'user-1',
      username: 'carlos',
      displayName: 'Carlos Hernandez',
      firstName: 'Carlos',
      lastName: 'Hernandez',
      email: 'carlos@example.local',
      enabled: true,
      roleCodes: ['INVENTORY_ADMIN']
    }
  ];
  const roles = [
    {
      code: 'INVENTORY_ADMIN',
      name: 'Administrador de inventario',
      description: 'Acceso completo',
      permissions: [
        { code: 'user:manage', module: 'Seguridad', description: 'Gestionar usuarios' }
      ]
    }
  ];
  const permissions = [
    { code: 'user:manage', module: 'Seguridad', description: 'Gestionar usuarios' }
  ];

  beforeEach(async () => {
    securityAdminService = jasmine.createSpyObj<SecurityAdminService>(
      'SecurityAdminService',
      ['listUsers', 'listRoles', 'listPermissions', 'createUser', 'updateUser', 'replaceUserRoles']
    );
    securityAdminService.listUsers.and.returnValue(of(users));
    securityAdminService.listRoles.and.returnValue(of(roles));
    securityAdminService.listPermissions.and.returnValue(of(permissions));
    securityAdminService.createUser.and.returnValue(of(users[0]));
    securityAdminService.updateUser.and.returnValue(of(users[0]));
    securityAdminService.replaceUserRoles.and.returnValue(of(users[0]));

    await TestBed.configureTestingModule({
      imports: [SecurityAdminComponent],
      providers: [
        { provide: SecurityAdminService, useValue: securityAdminService }
      ]
    }).compileComponents();

    fixture = TestBed.createComponent(SecurityAdminComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('muestra usuarios, roles y permisos recibidos desde la api', () => {
    const compiled = fixture.nativeElement as HTMLElement;

    expect(compiled.textContent).toContain('Usuarios, roles y permisos');
    expect(compiled.textContent).toContain('Carlos Hernandez');
    expect(compiled.textContent).toContain('Administrador de inventario');
    expect(compiled.textContent).toContain('user:manage');
  });

  it('carga un usuario seleccionado en el formulario', () => {
    component.selectUser(users[0]);
    fixture.detectChanges();

    const usernameInput = fixture.debugElement.query(By.css('input[name="username"]')).nativeElement as HTMLInputElement;

    expect(usernameInput.value).toBe('carlos');
    expect(component.roleSelection['INVENTORY_ADMIN']).toBeTrue();
  });

  it('crea usuarios nuevos con roles seleccionados', () => {
    component.startCreate();
    component.form = {
      username: 'viewer',
      firstName: 'Usuario',
      lastName: 'Consulta',
      email: 'viewer@example.local',
      enabled: true,
      roleCodes: []
    };
    component.roleSelection = { INVENTORY_ADMIN: true };

    component.saveUser();

    expect(securityAdminService.createUser).toHaveBeenCalledWith({
      username: 'viewer',
      firstName: 'Usuario',
      lastName: 'Consulta',
      email: 'viewer@example.local',
      enabled: true,
      roleCodes: ['INVENTORY_ADMIN']
    });
  });

  it('muestra un error cuando falla la carga inicial', async () => {
    securityAdminService.listUsers.and.returnValue(throwError(() => new Error('failed')));
    fixture = TestBed.createComponent(SecurityAdminComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();

    expect(component.errorMessage).toBe('No se pudo cargar la configuracion de seguridad.');
  });
});
