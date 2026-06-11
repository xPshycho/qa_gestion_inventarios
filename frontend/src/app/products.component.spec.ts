import { ComponentFixture, TestBed } from '@angular/core/testing';
import { By } from '@angular/platform-browser';
import { of } from 'rxjs';
import { ProductPage, ProductQuery } from './product.model';
import { ProductService } from './product.service';
import { ProductsComponent } from './products.component';

describe('ProductsComponent', () => {
  let fixture: ComponentFixture<ProductsComponent>;
  let productService: jasmine.SpyObj<ProductService>;

  const page: ProductPage = {
    content: [
      {
        id: 1,
        sku: 'DELL-LAT-5440',
        name: 'Dell Latitude 5440',
        description: 'Laptop empresarial',
        category: 'Laptops',
        price: 68500,
        currentStock: 12,
        minimumStock: 4,
        status: 'ACTIVE',
        createdAt: '2026-06-07T12:00:00Z',
        updatedAt: '2026-06-07T12:00:00Z'
      }
    ],
    page: 0,
    size: 10,
    totalElements: 1,
    totalPages: 1
  };

  beforeEach(async () => {
    productService = jasmine.createSpyObj<ProductService>('ProductService', ['listProducts']);
    productService.listProducts.and.returnValue(of(page));

    await TestBed.configureTestingModule({
      imports: [ProductsComponent],
      providers: [
        { provide: ProductService, useValue: productService }
      ]
    }).compileComponents();

    fixture = TestBed.createComponent(ProductsComponent);
    fixture.detectChanges();
  });

  it('muestra el listado de productos recibido desde la api', () => {
    const compiled = fixture.nativeElement as HTMLElement;

    expect(compiled.textContent).toContain('Catalogo de inventario');
    expect(compiled.textContent).toContain('DELL-LAT-5440');
    expect(compiled.textContent).toContain('Dell Latitude 5440');
    expect(productService.listProducts).toHaveBeenCalled();
  });

  it('solicita ordenamiento por columna al seleccionar nombre', () => {
    const nameSortButton = fixture.debugElement
      .queryAll(By.css('.sort-button'))
      .find((button) => (button.nativeElement as HTMLElement).textContent?.includes('Nombre'));

    nameSortButton?.triggerEventHandler('click');
    fixture.detectChanges();

    const latestQuery = productService.listProducts.calls.mostRecent().args[0] as ProductQuery;
    expect(latestQuery.sort).toBe('name');
    expect(latestQuery.direction).toBe('asc');
  });
});
