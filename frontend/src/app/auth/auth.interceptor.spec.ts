import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed, fakeAsync, flushMicrotasks } from '@angular/core/testing';
import { ProductService } from '../product.service';
import { authInterceptor } from './auth.interceptor';
import { AuthService } from './auth.service';

describe('authInterceptor', () => {
  let httpTesting: HttpTestingController;
  let productService: ProductService;
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
});
