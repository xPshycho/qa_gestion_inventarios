import { Component } from '@angular/core';
import { Routes } from '@angular/router';
import { AuditPageComponent } from './audit-page.component';
import { authGuard, homeGuard, loginGuard, permissionGuard } from './auth/auth.guards';
import { DashboardPageComponent } from './dashboard-page.component';
import { ForbiddenComponent } from './forbidden.component';
import { LoginComponent } from './login.component';
import { ProductCreatePageComponent } from './product-create-page.component';
import { ProductEditPageComponent } from './product-edit-page.component';
import { ProductsComponent } from './products.component';
import { SecurityAdminComponent } from './security-admin.component';
import { StockMovementsPageComponent } from './stock-movements-page.component';

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
    path: 'productos/nuevo',
    component: ProductCreatePageComponent,
    canActivate: [permissionGuard],
    data: { permission: 'product:manage' }
  },
  {
    path: 'productos/:id/editar',
    component: ProductEditPageComponent,
    canActivate: [permissionGuard],
    data: { permission: 'product:manage' }
  },
  {
    path: 'productos/:id/auditoria',
    component: AuditPageComponent,
    canActivate: [permissionGuard],
    data: { permission: 'audit:view' }
  },
  {
    path: 'productos',
    component: ProductsComponent,
    canActivate: [permissionGuard],
    data: { permission: 'product:view' }
  },
  {
    path: 'seguridad',
    component: SecurityAdminComponent,
    canActivate: [permissionGuard],
    data: { permission: 'user:manage' }
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
