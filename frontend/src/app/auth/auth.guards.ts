import { inject } from '@angular/core';
import { ActivatedRouteSnapshot, CanActivateFn, Router, RouterStateSnapshot } from '@angular/router';
import { AuthService } from './auth.service';

export const authGuard: CanActivateFn = (_route, state) => {
  const authService = inject(AuthService);
  const router = inject(Router);

  if (authService.isAuthenticated()) {
    return true;
  }

  return router.createUrlTree(['/login'], {
    queryParams: { returnUrl: state.url }
  });
};

export const permissionGuard: CanActivateFn = (route, state) => {
  const authService = inject(AuthService);
  const router = inject(Router);

  if (!authService.isAuthenticated()) {
    return router.createUrlTree(['/login'], {
      queryParams: { returnUrl: state.url }
    });
  }

  const permission = route.data['permission'];
  if (typeof permission === 'string' && authService.hasPermission(permission)) {
    return true;
  }

  return router.createUrlTree(['/forbidden']);
};

export const loginGuard: CanActivateFn = () => {
  const authService = inject(AuthService);

  if (!authService.isAuthenticated()) {
    return true;
  }

  return defaultAuthenticatedRoute(authService, inject(Router));
};

export const homeGuard: CanActivateFn = (
  _route: ActivatedRouteSnapshot,
  _state: RouterStateSnapshot
) => defaultAuthenticatedRoute(inject(AuthService), inject(Router));

function defaultAuthenticatedRoute(authService: AuthService, router: Router) {
  if (!authService.isAuthenticated()) {
    return router.createUrlTree(['/login']);
  }

  if (authService.hasPermission('report:view')) {
    return router.createUrlTree(['/dashboard']);
  }

  if (authService.hasPermission('product:view')) {
    return router.createUrlTree(['/productos']);
  }

  return router.createUrlTree(['/forbidden']);
}
