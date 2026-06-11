import { HttpErrorResponse } from '@angular/common/http';
import { ApiError } from './product.model';

export function productErrorMessage(error: unknown, fallback: string): string {
  if (!(error instanceof HttpErrorResponse)) {
    return fallback;
  }

  if (error.status === 0) {
    return 'No se pudo conectar con la API de inventario.';
  }

  if (error.status === 400) {
    const detail = apiErrorDetail(error);
    return detail ? `Revisa los datos ingresados: ${detail}` : 'Revisa los datos ingresados.';
  }

  if (error.status === 403) {
    return 'No tienes permiso para gestionar productos.';
  }

  if (error.status === 404) {
    return 'El producto solicitado no existe.';
  }

  if (error.status === 409) {
    return 'Ya existe un producto con el SKU indicado.';
  }

  return fallback;
}

function apiErrorDetail(error: HttpErrorResponse): string {
  const body = error.error as Partial<ApiError> | null;
  return typeof body?.message === 'string' ? body.message : '';
}
