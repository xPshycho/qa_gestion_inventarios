import { HttpErrorResponse } from '@angular/common/http';
import { ApiError } from './product.model';

export function stockMovementErrorMessage(error: unknown, fallback: string): string {
  if (!(error instanceof HttpErrorResponse)) {
    return fallback;
  }

  if (error.status === 0) {
    return 'No se pudo conectar con la API de inventario.';
  }

  if (error.status === 400) {
    const detail = apiErrorDetail(error);
    return detail ? `Revisa el movimiento ingresado: ${detail}` : 'Revisa el movimiento ingresado.';
  }

  if (error.status === 403) {
    return 'No tienes permiso para gestionar movimientos de stock.';
  }

  if (error.status === 404) {
    return 'El producto solicitado no existe.';
  }

  return fallback;
}

function apiErrorDetail(error: HttpErrorResponse): string {
  const body = error.error as Partial<ApiError> | null;
  return typeof body?.message === 'string' ? body.message : '';
}
