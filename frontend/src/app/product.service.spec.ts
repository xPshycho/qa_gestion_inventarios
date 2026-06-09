import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { ProductPage, ProductQuery } from './product.model';
import { ProductService } from './product.service';

describe('ProductService', () => {
  let service: ProductService;
  let httpTesting: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        ProductService,
        provideHttpClient(),
        provideHttpClientTesting()
      ]
    });

    service = TestBed.inject(ProductService);
    httpTesting = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpTesting.verify();
  });

  it('envia paginacion busqueda filtros y ordenamiento al backend', () => {
    const query: ProductQuery = {
      page: 1,
      size: 20,
      search: 'DELL',
      category: 'Laptops',
      status: 'ACTIVE',
      sort: 'name',
      direction: 'desc'
    };
    const page: ProductPage = {
      content: [],
      page: 1,
      size: 20,
      totalElements: 0,
      totalPages: 0
    };

    service.listProducts(query).subscribe((response) => {
      expect(response).toEqual(page);
    });

    const request = httpTesting.expectOne((req) => req.url === '/api/products');
    expect(request.request.method).toBe('GET');
    expect(request.request.params.get('page')).toBe('1');
    expect(request.request.params.get('size')).toBe('20');
    expect(request.request.params.get('search')).toBe('DELL');
    expect(request.request.params.get('category')).toBe('Laptops');
    expect(request.request.params.get('status')).toBe('ACTIVE');
    expect(request.request.params.get('sort')).toBe('name');
    expect(request.request.params.get('direction')).toBe('desc');
    request.flush(page);
  });
});
