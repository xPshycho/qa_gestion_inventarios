import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { AuditRevision } from './audit.model';
import { AuditService } from './audit.service';

describe('AuditService', () => {
  let service: AuditService;
  let httpTesting: HttpTestingController;

  const revision: AuditRevision = {
    entityName: 'Product',
    entityId: 1,
    revision: 2,
    revisionType: 'MOD',
    changedAt: '2026-06-17T12:00:00Z',
    username: 'carlos',
    previousValues: { name: 'Producto anterior' },
    currentValues: { name: 'Producto actualizado' }
  };

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        AuditService,
        provideHttpClient(),
        provideHttpClientTesting()
      ]
    });

    service = TestBed.inject(AuditService);
    httpTesting = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpTesting.verify();
  });

  it('consulta revisiones de producto', () => {
    service.listProductRevisions(1).subscribe((response) => {
      expect(response).toEqual([revision]);
    });

    const request = httpTesting.expectOne('/api/audit/products/1/revisions');
    expect(request.request.method).toBe('GET');
    request.flush([revision]);
  });

  it('consulta revisiones de movimientos de stock', () => {
    const stockRevision: AuditRevision = {
      ...revision,
      entityName: 'StockMovement',
      entityId: 10,
      revisionType: 'ADD',
      currentValues: { movementType: 'ENTRY', newQuantity: 15 }
    };

    service.listStockMovementRevisions(1).subscribe((response) => {
      expect(response).toEqual([stockRevision]);
    });

    const request = httpTesting.expectOne('/api/audit/products/1/stock-movements/revisions');
    expect(request.request.method).toBe('GET');
    request.flush([stockRevision]);
  });
});
