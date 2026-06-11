import { Component } from '@angular/core';
import { Routes } from '@angular/router';
import { authGuard, homeGuard, loginGuard, permissionGuard } from './auth/auth.guards';
import { DashboardPageComponent } from './dashboard-page.component';
import { ForbiddenComponent } from './forbidden.component';
import { LoginComponent } from './login.component';
import { ProductsComponent } from './products.component';

@Component({
  standalone: true,
  template: ''
})
class RoutePlaceholderComponent {}

export const routes: Routes = [
  {
    path: '',
    pathMatch: 'full',
    component: RoutePlaceholderComponent,
    canActivate: [homeGuard]
  },
  {
    path: 'login',
    component: LoginComponent,
    canActivate: [loginGuard]
  },
  {
    path: 'dashboard',
    component: DashboardPageComponent,
    canActivate: [permissionGuard],
    data: { permission: 'report:view' }
  },
  {
    path: 'productos',
    component: ProductsComponent,
    canActivate: [permissionGuard],
    data: { permission: 'product:view' }
  },
  {
    path: 'forbidden',
    component: ForbiddenComponent,
    canActivate: [authGuard]
  },
  {
    path: '**',
    redirectTo: ''
  }
];
