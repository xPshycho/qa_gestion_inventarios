import { HttpErrorResponse } from '@angular/common/http';
import { productErrorMessage } from './product-error';

describe('productErrorMessage', () => {
  it('muestra el detalle de validacion para respuestas 400', () => {
    const error = httpError(400, 'name must not be blank');

    expect(productErrorMessage(error, 'Error')).toBe(
      'Revisa los datos ingresados: name must not be blank'
    );
  });

  it('traduce errores de permiso producto inexistente y sku duplicado', () => {
    expect(productErrorMessage(httpError(403), 'Error')).toBe(
      'No tienes permiso para gestionar productos.'
    );
    expect(productErrorMessage(httpError(404), 'Error')).toBe(
      'El producto solicitado no existe.'
    );
    expect(productErrorMessage(httpError(409), 'Error')).toBe(
      'Ya existe un producto con el SKU indicado.'
    );
  });

  it('usa el mensaje de respaldo para errores no reconocidos', () => {
    expect(productErrorMessage(httpError(500), 'No se pudo guardar.')).toBe(
      'No se pudo guardar.'
    );
  });

  function httpError(status: number, message?: string): HttpErrorResponse {
    return new HttpErrorResponse({
      status,
      error: message ? {
        status,
        message,
        timestamp: '2026-06-11T12:00:00Z'
      } : undefined
    });
  }
});
