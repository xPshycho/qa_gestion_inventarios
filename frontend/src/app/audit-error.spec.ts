import { HttpErrorResponse } from '@angular/common/http';
import { auditErrorMessage } from './audit-error';

describe('auditErrorMessage', () => {
  it('traduce errores de conectividad permiso y producto inexistente', () => {
    expect(auditErrorMessage(httpError(0), 'fallback')).toBe(
      'No se pudo conectar con la API de inventario.'
    );
    expect(auditErrorMessage(httpError(403), 'fallback')).toBe(
      'No tienes permiso para consultar auditoria.'
    );
    expect(auditErrorMessage(httpError(404), 'fallback')).toBe(
      'El producto solicitado no existe.'
    );
  });

  it('prioriza el detalle valido de la API', () => {
    expect(auditErrorMessage(
      httpError(500, { message: 'Error auditable' }),
      'fallback'
    )).toBe('Error auditable');
  });

  it('usa fallback para valores ajenos a HTTP o detalles invalidos', () => {
    expect(auditErrorMessage(new Error('local'), 'fallback')).toBe('fallback');
    expect(auditErrorMessage(httpError(500), 'fallback')).toBe('fallback');
    expect(auditErrorMessage(
      httpError(500, { message: 42 }),
      'fallback'
    )).toBe('fallback');
  });

  function httpError(status: number, error?: unknown): HttpErrorResponse {
    return new HttpErrorResponse({ status, error });
  }
});
