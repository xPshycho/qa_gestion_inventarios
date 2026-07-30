import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';
import { DashboardComponent } from './dashboard.component';
import { DashboardResponse, RecentStockMovement } from './dashboard.model';
import { DashboardService } from './dashboard.service';

describe('DashboardComponent', () => {
  let fixture: ComponentFixture<DashboardComponent>;
  let component: DashboardComponent;
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
    bestSellingProducts: [],
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
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('muestra las metricas operacionales recibidas desde la api', () => {
    const compiled = fixture.nativeElement as HTMLElement;

    expect(compiled.textContent).toContain('Indicadores operacionales');
    expect(compiled.textContent).toContain('Stock crítico');
    expect(compiled.textContent).toContain('Productos críticos');
    expect(dashboardService.getDashboard).toHaveBeenCalled();
  });

  it('traduce movimientos y selecciona actores con fallback seguro', () => {
    const movement = {
      id: 12,
      userDisplayName: 'Carlos Hernández',
      username: 'carlos'
    } as RecentStockMovement;

    expect(component.movementTypeLabel('INITIAL')).toBe('Inicial');
    expect(component.movementTypeLabel('ENTRY')).toBe('Entrada');
    expect(component.movementTypeLabel('EXIT')).toBe('Salida');
    expect(component.movementTypeLabel('ADJUSTMENT')).toBe('Ajuste');
    expect(component.movementActor(movement)).toBe('Carlos Hernández');
    expect(component.movementActor({
      ...movement,
      userDisplayName: ''
    })).toBe('carlos');
    expect(component.movementActor({
      ...movement,
      userDisplayName: '',
      username: ''
    })).toBe('Sistema');
  });

  it('formatea deltas y clases visuales para entradas salidas y neutros', () => {
    expect(component.movementDeltaLabel(4)).toBe('+4');
    expect(component.movementDeltaLabel(-2)).toBe('-2');
    expect(component.movementDeltaClass(4)).toBe('delta-positive');
    expect(component.movementDeltaClass(-2)).toBe('delta-negative');
    expect(component.movementDeltaClass(0)).toBe('delta-neutral');
  });

  it('expone identificadores estables para las listas', () => {
    expect(component.trackByCriticalProductId(0, dashboard.criticalProducts[0])).toBe(1);
    expect(component.trackByBestSellingProductId(0, {
      productId: 2
    } as never)).toBe(2);
    expect(component.trackByMovementId(0, {
      id: 3
    } as never)).toBe(3);
  });

  it('muestra el error y permite reintentar la carga', () => {
    dashboardService.getDashboard.and.returnValue(
      throwError(() => new Error('backend unavailable'))
    );

    component.refreshDashboard();

    expect(component.dashboard).toBeUndefined();
    expect(component.dashboardLoading).toBeFalse();
    expect(component.dashboardErrorMessage).toBe(
      'No se pudo cargar el dashboard operacional.'
    );
  });
});
