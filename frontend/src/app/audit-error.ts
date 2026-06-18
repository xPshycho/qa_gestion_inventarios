import { HttpErrorResponse } from '@angular/common/http';
import { ApiError } from './product.model';

export function auditErrorMessage(error: unknown, fallback: string): string {
  if (!(error instanceof HttpErrorResponse)) {
    return fallback;
  }

  if (error.status === 0) {
    return 'No se pudo conectar con la API de inventario.';
  }

  if (error.status === 403) {
    return 'No tienes permiso para consultar auditoria.';
  }

  if (error.status === 404) {
    return 'El producto solicitado no existe.';
  }

  const detail = apiErrorDetail(error);
  return detail || fallback;
}

function apiErrorDetail(error: HttpErrorResponse): string {
  const body = error.error as Partial<ApiError> | null;
  return typeof body?.message === 'string' ? body.message : '';
}
