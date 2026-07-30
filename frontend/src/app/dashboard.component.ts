import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit, inject } from '@angular/core';
import { Subscription, finalize } from 'rxjs';
import {
  CriticalProduct,
  DashboardResponse,
  RecentStockMovement,
  StockMovementType,
  BestSellingProduct
} from './dashboard.model';
import { DashboardService } from './dashboard.service';
import { MATERIAL_IMPORTS } from './shared/material.imports';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule, ...MATERIAL_IMPORTS],
  templateUrl: './dashboard.component.html',
  styleUrl: './dashboard.component.css'
})
export class DashboardComponent implements OnInit, OnDestroy {
  private readonly dashboardService = inject(DashboardService);
  private dashboardSubscription?: Subscription;

  dashboard?: DashboardResponse;
  dashboardLoading = false;
  dashboardErrorMessage = '';

  ngOnInit(): void {
    this.loadDashboard();
  }

  ngOnDestroy(): void {
    this.dashboardSubscription?.unsubscribe();
  }

  loadDashboard(): void {
    this.dashboardLoading = true;
    this.dashboardErrorMessage = '';
    this.dashboardSubscription?.unsubscribe();
    this.dashboardSubscription = this.dashboardService.getDashboard()
      .pipe(finalize(() => {
        this.dashboardLoading = false;
      }))
      .subscribe({
        next: (dashboard) => {
          this.dashboard = dashboard;
        },
        error: () => {
          this.dashboardErrorMessage = 'No se pudo cargar el dashboard operacional.';
          this.dashboard = undefined;
        }
      });
  }

  refreshDashboard(): void {
    this.loadDashboard();
  }

  movementTypeLabel(type: StockMovementType): string {
    const labels: Record<StockMovementType, string> = {
      INITIAL: 'Inicial',
      ENTRY: 'Entrada',
      EXIT: 'Salida',
      ADJUSTMENT: 'Ajuste'
    };

    return labels[type];
  }

  movementActor(movement: RecentStockMovement): string {
    return movement.userDisplayName || movement.username || 'Sistema';
  }

  movementDeltaLabel(deltaQuantity: number): string {
    if (deltaQuantity > 0) {
      return `+${deltaQuantity}`;
    }

    return `${deltaQuantity}`;
  }

  movementDeltaClass(deltaQuantity: number): string {
    if (deltaQuantity > 0) {
      return 'delta-positive';
    }

    if (deltaQuantity < 0) {
      return 'delta-negative';
    }

    return 'delta-neutral';
  }

  trackByCriticalProductId(_: number, product: CriticalProduct): number {
    return product.id;
  }

  trackByBestSellingProductId(_: number, product: BestSellingProduct): number {
    return product.productId;
  }

  trackByMovementId(_: number, movement: RecentStockMovement): number {
    return movement.id;
  }
}
