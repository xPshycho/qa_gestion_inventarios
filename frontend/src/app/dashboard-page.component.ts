import { Component } from '@angular/core';
import { DashboardComponent } from './dashboard.component';
import { MATERIAL_IMPORTS } from './shared/material.imports';

@Component({
  selector: 'app-dashboard-page',
  standalone: true,
  imports: [DashboardComponent, ...MATERIAL_IMPORTS],
  template: `
    <main class="dashboard-page page-shell">
      <mat-card class="page-heading-card">
        <mat-card-content class="page-heading-content">
          <div>
            <p class="eyebrow">Dashboard</p>
          <h1>Inventario operativo</h1>
            <p class="page-subtitle">Indicadores de productos, stock y movimientos recientes.</p>
          </div>
        </mat-card-content>
      </mat-card>
      <app-dashboard></app-dashboard>
    </main>
  `,
  styles: [`
    .dashboard-page {
      display: grid;
      gap: 16px;
    }
  `]
})
export class DashboardPageComponent {}
