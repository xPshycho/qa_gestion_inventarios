import { HttpErrorResponse } from '@angular/common/http';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { of, throwError } from 'rxjs';
import { Product, ProductRequest } from './product.model';
import { ProductCreatePageComponent } from './product-create-page.component';
import { ProductService } from './product.service';

describe('ProductCreatePageComponent', () => {
  let fixture: ComponentFixture<ProductCreatePageComponent>;
  let component: ProductCreatePageComponent;
  let productService: jasmine.SpyObj<ProductService>;
  let router: Router;

  const request: ProductRequest = {
    sku: 'LAP-001',
    name: 'Laptop de prueba',
    description: null,
    category: 'Laptops',
    price: 1250.5,
    currentStock: 10,
    minimumStock: 2,
    status: 'ACTIVE'
  };

  const product: Product = {
    id: 8,
    ...request,
    stockAlert: false,
    createdAt: '2026-06-11T12:00:00Z',
    updatedAt: '2026-06-11T12:00:00Z'
  };

  beforeEach(async () => {
    productService = jasmine.createSpyObj<ProductService>('ProductService', ['createProduct']);
    productService.createProduct.and.returnValue(of(product));

    await TestBed.configureTestingModule({
      imports: [ProductCreatePageComponent],
      providers: [
        { provide: ProductService, useValue: productService },
        provideRouter([])
      ]
    }).compileComponents();

    fixture = TestBed.createComponent(ProductCreatePageComponent);
    component = fixture.componentInstance;
    router = TestBed.inject(Router);
    fixture.detectChanges();
  });

  it('crea el producto y regresa al catalogo con mensaje de exito', () => {
    spyOn(router, 'navigate').and.resolveTo(true);

    component.createProduct(request);

    expect(productService.createProduct).toHaveBeenCalledWith(request);
    expect(router.navigate).toHaveBeenCalledWith(['/productos'], {
      state: {
        successMessage: 'Producto LAP-001 creado correctamente.'
      }
    });
    expect(component.saving).toBeFalse();
  });

  it('muestra un mensaje claro cuando el sku esta duplicado', () => {
    productService.createProduct.and.returnValue(throwError(() => new HttpErrorResponse({
      status: 409,
      error: {
        status: 409,
        message: 'Product SKU already exists: LAP-001',
        timestamp: '2026-06-11T12:00:00Z'
      }
    })));

    component.createProduct(request);

    expect(component.errorMessage).toBe('Ya existe un producto con el SKU indicado.');
    expect(component.saving).toBeFalse();
  });
});
