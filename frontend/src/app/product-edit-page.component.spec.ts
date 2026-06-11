import { HttpErrorResponse } from '@angular/common/http';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, Router, convertToParamMap, provideRouter } from '@angular/router';
import { of, throwError } from 'rxjs';
import { Product, ProductRequest } from './product.model';
import { ProductEditPageComponent } from './product-edit-page.component';
import { ProductService } from './product.service';

describe('ProductEditPageComponent', () => {
  let fixture: ComponentFixture<ProductEditPageComponent>;
  let component: ProductEditPageComponent;
  let productService: jasmine.SpyObj<ProductService>;
  let router: Router;

  const request: ProductRequest = {
    sku: 'LAP-001',
    name: 'Laptop actualizada',
    description: 'Equipo empresarial',
    category: 'Laptops',
    price: 1400,
    currentStock: 8,
    minimumStock: 2,
    status: 'ACTIVE'
  };

  const product: Product = {
    id: 8,
    ...request,
    stockAlert: false,
    createdAt: '2026-06-11T12:00:00Z',
    updatedAt: '2026-06-11T13:00:00Z'
  };

  beforeEach(async () => {
    productService = jasmine.createSpyObj<ProductService>(
      'ProductService',
      ['getProduct', 'updateProduct']
    );
    productService.getProduct.and.returnValue(of(product));
    productService.updateProduct.and.returnValue(of(product));

    await TestBed.configureTestingModule({
      imports: [ProductEditPageComponent],
      providers: [
        { provide: ProductService, useValue: productService },
        provideRouter([]),
        {
          provide: ActivatedRoute,
          useValue: {
            snapshot: {
              paramMap: convertToParamMap({ id: '8' })
            }
          }
        }
      ]
    }).compileComponents();

    fixture = TestBed.createComponent(ProductEditPageComponent);
    component = fixture.componentInstance;
    router = TestBed.inject(Router);
    fixture.detectChanges();
  });

  it('carga el producto y prepara el formulario de edicion', () => {
    expect(productService.getProduct).toHaveBeenCalledWith(8);
    expect(component.productValue).toEqual(request);
    expect(component.loading).toBeFalse();
  });

  it('actualiza el producto y regresa al catalogo', () => {
    spyOn(router, 'navigate').and.resolveTo(true);

    component.updateProduct(request);

    expect(productService.updateProduct).toHaveBeenCalledWith(8, request);
    expect(router.navigate).toHaveBeenCalledWith(['/productos'], {
      state: {
        successMessage: 'Producto LAP-001 actualizado correctamente.'
      }
    });
  });

  it('muestra un mensaje cuando el producto no existe', () => {
    productService.getProduct.and.returnValue(throwError(() => new HttpErrorResponse({
      status: 404
    })));

    component.ngOnInit();

    expect(component.productValue).toBeNull();
    expect(component.errorMessage).toBe('El producto solicitado no existe.');
  });
});
