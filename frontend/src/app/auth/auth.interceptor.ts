import { HttpErrorResponse, HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { catchError, from, switchMap, throwError } from 'rxjs';
import { AuthService } from './auth.service';

export const authInterceptor: HttpInterceptorFn = (request, next) => {
  if (!isApiRequest(request.url)) {
    return next(request);
  }

  const authService = inject(AuthService);

  return from(authService.getValidAccessToken()).pipe(
    switchMap((token) => {
      const authorizedRequest = token
        ? request.clone({ setHeaders: { Authorization: `Bearer ${token}` } })
        : request;

      return next(authorizedRequest).pipe(
        catchError((error: unknown) => {
          if (!(error instanceof HttpErrorResponse) || error.status !== 401 || !token) {
            return throwError(() => error);
          }

          return from(authService.forceRefreshAccessToken()).pipe(
            switchMap((refreshedToken) => {
              if (!refreshedToken) {
                return throwError(() => error);
              }

              return next(request.clone({
                setHeaders: { Authorization: `Bearer ${refreshedToken}` }
              }));
            })
          );
        })
      );
    })
  );
};

function isApiRequest(url: string): boolean {
  return url === '/api' || url.startsWith('/api/');
}
