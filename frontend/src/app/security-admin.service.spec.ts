import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { SecurityUserRequest } from './security-admin.model';
import { SecurityAdminService } from './security-admin.service';

describe('SecurityAdminService', () => {
  let service: SecurityAdminService;
  let httpTesting: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        SecurityAdminService,
        provideHttpClient(),
        provideHttpClientTesting()
      ]
    });

    service = TestBed.inject(SecurityAdminService);
    httpTesting = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpTesting.verify();
  });

  it('consulta usuarios desde el endpoint de seguridad', () => {
    service.listUsers().subscribe();

    const request = httpTesting.expectOne('/api/security/users');
    expect(request.request.method).toBe('GET');
    request.flush([]);
  });

  it('crea usuarios con el payload esperado', () => {
    const userRequest: SecurityUserRequest = {
      username: 'carlos',
      firstName: 'Carlos',
      lastName: 'Hernandez',
      email: 'carlos@example.local',
      enabled: true,
      roleCodes: ['INVENTORY_ADMIN']
    };

    service.createUser(userRequest).subscribe();

    const request = httpTesting.expectOne('/api/security/users');
    expect(request.request.method).toBe('POST');
    expect(request.request.body).toEqual(userRequest);
    request.flush({ ...userRequest, id: 'user-1', displayName: 'Carlos Hernandez' });
  });

  it('reemplaza roles de un usuario', () => {
    service.replaceUserRoles('user-1', ['INVENTORY_VIEWER']).subscribe();

    const request = httpTesting.expectOne('/api/security/users/user-1/roles');
    expect(request.request.method).toBe('PUT');
    expect(request.request.body).toEqual({ roleCodes: ['INVENTORY_VIEWER'] });
    request.flush({});
  });
});
