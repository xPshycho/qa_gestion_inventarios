import { ComponentFixture, TestBed } from '@angular/core/testing';
import { FormsModule } from '@angular/forms';
import { By } from '@angular/platform-browser';
import { of } from 'rxjs';
import { AppComponent } from './app.component';
import { DashboardResponse } from './dashboard.model';
import { DashboardService } from './dashboard.service';
import { ProductPage, ProductQuery } from './product.model';
import { ProductService } from './product.service';

describe('AppComponent', () => {
  let fixture: ComponentFixture<AppComponent>;
  let dashboardService: jasmine.SpyObj<DashboardService>;
  let productService: jasmine.SpyObj<ProductService>;

  const dashboard: DashboardResponse = {
    metrics: {
      totalProducts: 4,
      activeProducts: 3,
      inactiveProducts: 1,
      criticalProducts: 1,
      totalStockUnits: 26,
      inventoryValue: 1728000,
      totalMovements: 8,
      initialMovements: 4,
      entryMovements: 2,
      exitMovements: 1,
      adjustmentMovements: 1
    },
    criticalProducts: [
      {
        id: 1,
        sku: 'DELL-LAT-5440',
        name: 'Dell Latitude 5440',
        category: 'Laptops',
        currentStock: 2,
        minimumStock: 5,
        shortage: 3,
        status: 'ACTIVE',
        updatedAt: '2026-06-07T12:00:00Z'
      }
    ],
    mostMovedProducts: [
      {
        productId: 1,
        productSku: 'DELL-LAT-5440',
        productName: 'Dell Latitude 5440',
        category: 'Laptops',
        movementCount: 3,
        totalMovedUnits: 18,
        lastMovementAt: '2026-06-07T12:00:00Z'
      }
    ],
    recentMovements: [
      {
        id: 10,
        productId: 1,
        productSku: 'DELL-LAT-5440',
        productName: 'Dell Latitude 5440',
        userId: null,
        username: null,
        userDisplayName: null,
        movementType: 'EXIT',
        previousQuantity: 8,
        newQuantity: 2,
        deltaQuantity: -6,
        observations: 'Movimiento de prueba',
        stockAlert: true,
        createdAt: '2026-06-07T12:00:00Z'
      }
    ]
  };

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
    dashboardService = jasmine.createSpyObj<DashboardService>('DashboardService', ['getDashboard']);
    productService = jasmine.createSpyObj<ProductService>('ProductService', ['listProducts']);
    dashboardService.getDashboard.and.returnValue(of(dashboard));
    productService.listProducts.and.returnValue(of(page));

    await TestBed.configureTestingModule({
      imports: [AppComponent, FormsModule],
      providers: [
        { provide: DashboardService, useValue: dashboardService },
        { provide: ProductService, useValue: productService }
      ]
    }).compileComponents();

    fixture = TestBed.createComponent(AppComponent);
    fixture.detectChanges();
  });

  it('muestra el listado de productos recibido desde la api', () => {
    const compiled = fixture.nativeElement as HTMLElement;

    expect(compiled.textContent).toContain('Inventario operativo');
    expect(compiled.textContent).toContain('DELL-LAT-5440');
    expect(compiled.textContent).toContain('Dell Latitude 5440');
    expect(productService.listProducts).toHaveBeenCalled();
  });

  it('muestra metricas y secciones del dashboard', () => {
    const compiled = fixture.nativeElement as HTMLElement;

    expect(compiled.textContent).toContain('Indicadores operacionales');
    expect(compiled.textContent).toContain('Stock critico');
    expect(compiled.textContent).toContain('Productos mas movidos');
    expect(compiled.textContent).toContain('Historial reciente');
    expect(dashboardService.getDashboard).toHaveBeenCalled();
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
