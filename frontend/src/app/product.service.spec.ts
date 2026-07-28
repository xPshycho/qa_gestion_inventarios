import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { Product, ProductPage, ProductQuery, ProductRequest } from './product.model';
import { ProductService } from './product.service';

describe('ProductService', () => {
  let service: ProductService;
  let httpTesting: HttpTestingController;

  const product: Product = {
    id: 1,
    sku: 'DELL-LAT-5440',
    name: 'Dell Latitude 5440',
    description: 'Laptop empresarial',
    category: 'Laptops',
    price: 68500,
    currentStock: 12,
    minimumStock: 4,
    stockAlert: false,
    status: 'ACTIVE',
    createdAt: '2026-06-07T12:00:00Z',
    updatedAt: '2026-06-07T12:00:00Z'
  };

  const productRequest: ProductRequest = {
    sku: product.sku,
    name: product.name,
    description: product.description,
    category: product.category,
    price: product.price,
    currentStock: product.currentStock,
    minimumStock: product.minimumStock,
    status: product.status
  };

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

  it('consulta un producto por id', () => {
    service.getProduct(product.id).subscribe((response) => {
      expect(response).toEqual(product);
    });

    const request = httpTesting.expectOne('/api/products/1');
    expect(request.request.method).toBe('GET');
    request.flush(product);
  });

  it('crea un producto con el contrato esperado', () => {
    service.createProduct(productRequest).subscribe((response) => {
      expect(response).toEqual(product);
    });

    const request = httpTesting.expectOne('/api/products');
    expect(request.request.method).toBe('POST');
    expect(request.request.body).toEqual(productRequest);
    request.flush(product);
  });

  it('actualiza un producto existente', () => {
    service.updateProduct(product.id, productRequest).subscribe((response) => {
      expect(response).toEqual(product);
    });

    const request = httpTesting.expectOne('/api/products/1');
    expect(request.request.method).toBe('PUT');
    expect(request.request.body).toEqual(productRequest);
    request.flush(product);
  });

  it('elimina un producto por id', () => {
    let completed = false;

    service.deleteProduct(product.id).subscribe({
      complete: () => {
        completed = true;
      }
    });

    const request = httpTesting.expectOne('/api/products/1');
    expect(request.request.method).toBe('DELETE');
    request.flush(null, { status: 204, statusText: 'No Content' });
    expect(completed).toBeTrue();
  });
});
