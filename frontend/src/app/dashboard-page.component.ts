import { Component } from '@angular/core';
import { DashboardComponent } from './dashboard.component';

@Component({
  selector: 'app-dashboard-page',
  standalone: true,
  imports: [DashboardComponent],
  template: `
    <main class="dashboard-page">
      <section class="page-heading">
        <div>
          <p>Dashboard</p>
          <h1>Inventario operativo</h1>
        </div>
      </section>
      <app-dashboard></app-dashboard>
    </main>
  `,
  styles: [`
    .dashboard-page {
      width: min(1180px, calc(100% - 32px));
      margin: 0 auto;
      padding: 32px 0 48px;
    }

    .page-heading {
      margin-bottom: 20px;
    }

    p {
      margin: 0 0 6px;
      color: var(--primary);
      font-size: 0.78rem;
      font-weight: 800;
      text-transform: uppercase;
    }

    h1 {
      margin: 0;
      font-size: clamp(1.65rem, 3vw, 2.35rem);
    }
  `]
})
export class DashboardPageComponent {}
