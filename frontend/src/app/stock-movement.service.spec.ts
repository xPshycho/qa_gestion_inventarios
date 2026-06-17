import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { StockMovement } from './stock-movement.model';
import { StockMovementService } from './stock-movement.service';

describe('StockMovementService', () => {
  let service: StockMovementService;
  let httpTesting: HttpTestingController;

  const movement: StockMovement = {
    id: 10,
    productId: 1,
    productSku: 'DELL-LAT-5440',
    productName: 'Dell Latitude 5440',
    userId: 1,
    username: 'carlos',
    userDisplayName: 'Carlos Hernandez',
    movementType: 'ENTRY',
    previousQuantity: 12,
    newQuantity: 15,
    deltaQuantity: 3,
    observations: 'Recepcion',
    stockAlert: false,
    createdAt: '2026-06-17T12:00:00Z'
  };

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        StockMovementService,
        provideHttpClient(),
        provideHttpClientTesting()
      ]
    });

    service = TestBed.inject(StockMovementService);
    httpTesting = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpTesting.verify();
  });

  it('consulta el historial de movimientos por producto', () => {
    service.listMovements(1).subscribe((response) => {
      expect(response).toEqual([movement]);
    });

    const request = httpTesting.expectOne('/api/products/1/stock-movements');
    expect(request.request.method).toBe('GET');
    request.flush([movement]);
  });

  it('registra una entrada sin enviar userId', () => {
    service.registerEntry(1, { quantity: 3, observations: 'Recepcion' }).subscribe((response) => {
      expect(response).toEqual(movement);
    });

    const request = httpTesting.expectOne('/api/products/1/stock/entries');
    expect(request.request.method).toBe('POST');
    expect(request.request.body).toEqual({ quantity: 3, observations: 'Recepcion' });
    expect(request.request.body.userId).toBeUndefined();
    request.flush(movement);
  });

  it('registra una salida sin enviar userId', () => {
    service.registerExit(1, { quantity: 2, observations: null }).subscribe((response) => {
      expect(response).toEqual({ ...movement, movementType: 'EXIT', deltaQuantity: -2 });
    });

    const request = httpTesting.expectOne('/api/products/1/stock/exits');
    expect(request.request.method).toBe('POST');
    expect(request.request.body).toEqual({ quantity: 2, observations: null });
    expect(request.request.body.userId).toBeUndefined();
    request.flush({ ...movement, movementType: 'EXIT', deltaQuantity: -2 });
  });

  it('registra un ajuste con el nuevo stock absoluto', () => {
    service.registerAdjustment(1, { newQuantity: 8, observations: 'Conteo' }).subscribe((response) => {
      expect(response).toEqual({ ...movement, movementType: 'ADJUSTMENT', newQuantity: 8 });
    });

    const request = httpTesting.expectOne('/api/products/1/stock/adjustments');
    expect(request.request.method).toBe('POST');
    expect(request.request.body).toEqual({ newQuantity: 8, observations: 'Conteo' });
    expect(request.request.body.userId).toBeUndefined();
    request.flush({ ...movement, movementType: 'ADJUSTMENT', newQuantity: 8 });
  });
});
