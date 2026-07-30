import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { DashboardResponse } from './dashboard.model';
import { DashboardService } from './dashboard.service';

describe('DashboardService', () => {
  let service: DashboardService;
  let httpTesting: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        DashboardService,
        provideHttpClient(),
        provideHttpClientTesting()
      ]
    });

    service = TestBed.inject(DashboardService);
    httpTesting = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpTesting.verify();
  });

  it('consulta las metricas operacionales del dashboard', () => {
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
      criticalProducts: [],
      bestSellingProducts: [],
      recentMovements: []
    };

    service.getDashboard().subscribe((response) => {
      expect(response).toEqual(dashboard);
    });

    const request = httpTesting.expectOne('/api/reports/dashboard');
    expect(request.request.method).toBe('GET');
    request.flush(dashboard);
  });
});
