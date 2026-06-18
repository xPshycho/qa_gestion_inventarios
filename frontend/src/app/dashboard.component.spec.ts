import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of } from 'rxjs';
import { DashboardComponent } from './dashboard.component';
import { DashboardResponse } from './dashboard.model';
import { DashboardService } from './dashboard.service';

describe('DashboardComponent', () => {
  let fixture: ComponentFixture<DashboardComponent>;
  let dashboardService: jasmine.SpyObj<DashboardService>;

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
    mostMovedProducts: [],
    recentMovements: []
  };

  beforeEach(async () => {
    dashboardService = jasmine.createSpyObj<DashboardService>('DashboardService', ['getDashboard']);
    dashboardService.getDashboard.and.returnValue(of(dashboard));

    await TestBed.configureTestingModule({
      imports: [DashboardComponent],
      providers: [
        { provide: DashboardService, useValue: dashboardService }
      ]
    }).compileComponents();

    fixture = TestBed.createComponent(DashboardComponent);
    fixture.detectChanges();
  });

  it('muestra las metricas operacionales recibidas desde la api', () => {
    const compiled = fixture.nativeElement as HTMLElement;

    expect(compiled.textContent).toContain('Indicadores operacionales');
    expect(compiled.textContent).toContain('Stock crítico');
    expect(compiled.textContent).toContain('Productos críticos');
    expect(dashboardService.getDashboard).toHaveBeenCalled();
  });
});
