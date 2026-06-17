import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit, inject } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { forkJoin, Subscription, finalize } from 'rxjs';
import { auditErrorMessage } from './audit-error';
import { AuditFieldChange, AuditRevision, AuditRevisionType } from './audit.model';
import { AuditService } from './audit.service';
import { Product } from './product.model';
import { ProductService } from './product.service';

const FIELD_LABELS: Record<string, string> = {
  id: 'ID',
  sku: 'SKU',
  name: 'Nombre',
  description: 'Descripcion',
  category: 'Categoria',
  price: 'Precio',
  currentStock: 'Stock actual',
  minimumStock: 'Stock minimo',
  status: 'Estado',
  productId: 'Producto',
  userId: 'Usuario',
  movementType: 'Tipo de movimiento',
  previousQuantity: 'Cantidad anterior',
  newQuantity: 'Cantidad nueva',
  deltaQuantity: 'Delta',
  observations: 'Observaciones',
  createdAt: 'Creado',
  updatedAt: 'Actualizado'
};

@Component({
  selector: 'app-audit-page',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './audit-page.component.html',
  styleUrl: './audit-page.component.css'
})
export class AuditPageComponent implements OnInit, OnDestroy {
  private readonly route = inject(ActivatedRoute);
  private readonly productService = inject(ProductService);
  private readonly auditService = inject(AuditService);
  private auditSubscription?: Subscription;

  productId?: number;
  product: Product | null = null;
  productRevisions: AuditRevision[] = [];
  stockMovementRevisions: AuditRevision[] = [];
  loading = true;
  errorMessage = '';

  ngOnInit(): void {
    const productId = Number(this.route.snapshot.paramMap.get('id'));
    if (!Number.isSafeInteger(productId) || productId <= 0) {
      this.loading = false;
      this.errorMessage = 'El identificador del producto no es valido.';
      return;
    }

    this.productId = productId;
    this.loadAudit(productId);
  }

  ngOnDestroy(): void {
    this.auditSubscription?.unsubscribe();
  }

  refreshAudit(): void {
    if (this.productId) {
      this.loadAudit(this.productId);
    }
  }

  revisionTypeLabel(type: AuditRevisionType): string {
    const labels: Record<AuditRevisionType, string> = {
      ADD: 'Alta',
      MOD: 'Modificacion',
      DEL: 'Eliminacion'
    };

    return labels[type] ?? type;
  }

  entityLabel(entityName: string): string {
    if (entityName === 'Product') {
      return 'Producto';
    }

    if (entityName === 'StockMovement') {
      return 'Movimiento de stock';
    }

    return entityName;
  }

  actorLabel(revision: AuditRevision): string {
    return revision.username || 'Sistema';
  }

  fieldLabel(field: string): string {
    return FIELD_LABELS[field] ?? field;
  }

  formatValue(value: unknown): string {
    if (value === null || value === undefined || value === '') {
      return '-';
    }

    if (typeof value === 'object') {
      return JSON.stringify(value);
    }

    return String(value);
  }

  changesFor(revision: AuditRevision): AuditFieldChange[] {
    const fields = new Set([
      ...Object.keys(revision.previousValues ?? {}),
      ...Object.keys(revision.currentValues ?? {})
    ]);

    return [...fields]
      .filter((field) => this.formatValue(revision.previousValues?.[field]) !== this.formatValue(revision.currentValues?.[field]))
      .map((field) => ({
        field,
        previousValue: revision.previousValues?.[field],
        currentValue: revision.currentValues?.[field]
      }));
  }

  trackByRevision(_: number, revision: AuditRevision): string {
    return `${revision.entityName}-${revision.entityId}-${revision.revision}`;
  }

  trackByField(_: number, change: AuditFieldChange): string {
    return change.field;
  }

  private loadAudit(productId: number): void {
    this.loading = true;
    this.errorMessage = '';
    this.auditSubscription?.unsubscribe();
    this.auditSubscription = forkJoin({
      product: this.productService.getProduct(productId),
      productRevisions: this.auditService.listProductRevisions(productId),
      stockMovementRevisions: this.auditService.listStockMovementRevisions(productId)
    })
      .pipe(finalize(() => {
        this.loading = false;
      }))
      .subscribe({
        next: ({ product, productRevisions, stockMovementRevisions }) => {
          this.product = product;
          this.productRevisions = productRevisions;
          this.stockMovementRevisions = stockMovementRevisions;
        },
        error: (error: unknown) => {
          this.product = null;
          this.productRevisions = [];
          this.stockMovementRevisions = [];
          this.errorMessage = auditErrorMessage(error, 'No se pudo cargar la auditoria del producto.');
        }
      });
  }
}
