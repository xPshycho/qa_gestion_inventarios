import { HttpClient, provideHttpClient, withInterceptors } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed, fakeAsync, flushMicrotasks } from '@angular/core/testing';
import { ProductService } from '../product.service';
import { authInterceptor } from './auth.interceptor';
import { AuthService } from './auth.service';

describe('authInterceptor', () => {
  let httpTesting: HttpTestingController;
  let productService: ProductService;
  let httpClient: HttpClient;
  let authService: jasmine.SpyObj<AuthService>;

  beforeEach(() => {
    authService = jasmine.createSpyObj<AuthService>(
      'AuthService',
      ['getValidAccessToken', 'forceRefreshAccessToken']
    );
    authService.getValidAccessToken.and.resolveTo('access-token');
    authService.forceRefreshAccessToken.and.resolveTo('refreshed-token');

    TestBed.configureTestingModule({
      providers: [
        ProductService,
        { provide: AuthService, useValue: authService },
        provideHttpClient(withInterceptors([authInterceptor])),
        provideHttpClientTesting()
      ]
    });

    productService = TestBed.inject(ProductService);
    httpClient = TestBed.inject(HttpClient);
    httpTesting = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpTesting.verify();
  });

  it('agrega el token Bearer a las solicitudes de la api', fakeAsync(() => {
    productService.listProducts({
      page: 0,
      size: 10,
      search: '',
      category: '',
      status: '',
      sort: 'id',
      direction: 'asc'
    }).subscribe();
    flushMicrotasks();

    const request = httpTesting.expectOne((candidate) => candidate.url === '/api/products');
    expect(request.request.headers.get('Authorization')).toBe('Bearer access-token');
    request.flush({
      content: [],
      page: 0,
      size: 10,
      totalElements: 0,
      totalPages: 0
    });
  }));

  it('renueva el token y reintenta una solicitud rechazada con 401', fakeAsync(() => {
    productService.listProducts({
      page: 0,
      size: 10,
      search: '',
      category: '',
      status: '',
      sort: 'id',
      direction: 'asc'
    }).subscribe();
    flushMicrotasks();

    const initialRequest = httpTesting.expectOne('/api/products?page=0&size=10&sort=id&direction=asc');
    initialRequest.flush(null, { status: 401, statusText: 'Unauthorized' });
    flushMicrotasks();

    const retriedRequest = httpTesting.expectOne('/api/products?page=0&size=10&sort=id&direction=asc');
    expect(retriedRequest.request.headers.get('Authorization')).toBe('Bearer refreshed-token');
    expect(authService.forceRefreshAccessToken).toHaveBeenCalled();
    retriedRequest.flush({
      content: [],
      page: 0,
      size: 10,
      totalElements: 0,
      totalPages: 0
    });
  }));

  it('no modifica solicitudes que no pertenecen a la API', fakeAsync(() => {
    httpClient.get('/health').subscribe();
    flushMicrotasks();

    const request = httpTesting.expectOne('/health');
    expect(request.request.headers.has('Authorization')).toBeFalse();
    expect(authService.getValidAccessToken).not.toHaveBeenCalled();
    request.flush({ status: 'UP' });
  }));

  it('envia solicitudes API anonimas cuando no existe token', fakeAsync(() => {
    authService.getValidAccessToken.and.resolveTo(null);
    httpClient.get('/api').subscribe();
    flushMicrotasks();

    const request = httpTesting.expectOne('/api');
    expect(request.request.headers.has('Authorization')).toBeFalse();
    request.flush({});
  }));

  it('propaga errores distintos de 401 sin forzar refresh', fakeAsync(() => {
    let responseStatus = 0;
    httpClient.get('/api/products').subscribe({
      error: (error) => responseStatus = error.status
    });
    flushMicrotasks();

    httpTesting.expectOne('/api/products').flush(null, {
      status: 500,
      statusText: 'Server Error'
    });
    flushMicrotasks();

    expect(responseStatus).toBe(500);
    expect(authService.forceRefreshAccessToken).not.toHaveBeenCalled();
  }));

  it('propaga el 401 cuando el refresh no entrega token', fakeAsync(() => {
    let responseStatus = 0;
    authService.forceRefreshAccessToken.and.resolveTo(null);
    httpClient.get('/api/products').subscribe({
      error: (error) => responseStatus = error.status
    });
    flushMicrotasks();

    httpTesting.expectOne('/api/products').flush(null, {
      status: 401,
      statusText: 'Unauthorized'
    });
    flushMicrotasks();

    expect(responseStatus).toBe(401);
    expect(authService.forceRefreshAccessToken).toHaveBeenCalled();
  }));
});
