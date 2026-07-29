import { HttpErrorResponse } from '@angular/common/http';
import { stockMovementErrorMessage } from './stock-movement-error';

describe('stockMovementErrorMessage', () => {
  it('traduce conectividad permisos y producto inexistente', () => {
    expect(stockMovementErrorMessage(httpError(0), 'fallback')).toBe(
      'No se pudo conectar con la API de inventario.'
    );
    expect(stockMovementErrorMessage(httpError(403), 'fallback')).toBe(
      'No tienes permiso para gestionar movimientos de stock.'
    );
    expect(stockMovementErrorMessage(httpError(404), 'fallback')).toBe(
      'El producto solicitado no existe.'
    );
  });

  it('describe validaciones 400 con y sin detalle', () => {
    expect(stockMovementErrorMessage(
      httpError(400, { message: 'Stock insuficiente' }),
      'fallback'
    )).toBe('Revisa el movimiento ingresado: Stock insuficiente');
    expect(stockMovementErrorMessage(httpError(400), 'fallback')).toBe(
      'Revisa el movimiento ingresado.'
    );
    expect(stockMovementErrorMessage(
      httpError(400, { message: 42 }),
      'fallback'
    )).toBe('Revisa el movimiento ingresado.');
  });

  it('usa fallback para errores no HTTP o no reconocidos', () => {
    expect(stockMovementErrorMessage('invalid', 'fallback')).toBe('fallback');
    expect(stockMovementErrorMessage(httpError(500), 'fallback')).toBe('fallback');
  });

  function httpError(status: number, error?: unknown): HttpErrorResponse {
    return new HttpErrorResponse({ status, error });
  }
});
