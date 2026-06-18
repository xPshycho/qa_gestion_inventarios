import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { Observable, Subscription, finalize } from 'rxjs';
import { AuthService } from './auth/auth.service';
import { Product } from './product.model';
import { ProductService } from './product.service';
import { stockMovementErrorMessage } from './stock-movement-error';
import {
  StockAdjustmentRequest,
  StockMovement,
  StockMovementRequest,
  StockMovementType,
  StockOperationType
} from './stock-movement.model';
import { StockMovementService } from './stock-movement.service';
import { MATERIAL_IMPORTS } from './shared/material.imports';

type StockFormField = 'quantity' | 'newQuantity' | 'observations';

const STOCK_FIELD_LABELS: Record<StockFormField, string> = {
  quantity: 'Cantidad',
  newQuantity: 'Stock nuevo',
  observations: 'Observaciones'
};

@Component({
  selector: 'app-stock-movements-page',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, RouterLink, ...MATERIAL_IMPORTS],
  templateUrl: './stock-movements-page.component.html',
  styleUrl: './stock-movements-page.component.css'
})
export class StockMovementsPageComponent implements OnInit, OnDestroy {
  private readonly route = inject(ActivatedRoute);
  private readonly productService = inject(ProductService);
  private readonly stockMovementService = inject(StockMovementService);
  private readonly formBuilder = inject(FormBuilder);
  readonly auth = inject(AuthService);

  private productSubscription?: Subscription;
  private movementsSubscription?: Subscription;
  private submitSubscription?: Subscription;

  productId?: number;
  product: Product | null = null;
  movements: StockMovement[] = [];
  operationType: StockOperationType = 'ENTRY';
  productLoading = true;
  movementsLoading = true;
  submitting = false;
  errorMessage = '';
  successMessage = '';

  readonly movementForm = this.formBuilder.group({
    quantity: this.formBuilder.nonNullable.control(1, [
      Validators.required,
      Validators.min(1),
      Validators.pattern(/^\d+$/)
    ]),
    newQuantity: this.formBuilder.nonNullable.control(0, [
      Validators.required,
      Validators.min(0),
      Validators.pattern(/^\d+$/)
    ]),
    observations: this.formBuilder.control<string | null>(null, [
      Validators.maxLength(500)
    ])
  });

  ngOnInit(): void {
    const productId = Number(this.route.snapshot.paramMap.get('id'));
    if (!Number.isSafeInteger(productId) || productId <= 0) {
      this.productLoading = false;
      this.movementsLoading = false;
      this.errorMessage = 'El identificador del producto no es válido.';
      return;
    }

    this.productId = productId;
    this.loadProduct(productId);
    this.loadMovements(productId);
  }

  ngOnDestroy(): void {
    this.productSubscription?.unsubscribe();
    this.movementsSubscription?.unsubscribe();
    this.submitSubscription?.unsubscribe();
  }

  selectOperation(type: StockOperationType): void {
    this.operationType = type;
    this.successMessage = '';
    this.errorMessage = '';
    this.movementForm.reset({
      quantity: 1,
      newQuantity: this.product?.currentStock ?? 0,
      observations: null
    });
  }

  refreshHistory(): void {
    if (this.productId) {
      this.loadProduct(this.productId);
      this.loadMovements(this.productId);
    }
  }

  submitMovement(): void {
    if (!this.productId || this.submitting || !this.auth.hasPermission('stock:manage')) {
      return;
    }

    const activeControl = this.operationType === 'ADJUSTMENT'
      ? this.movementForm.controls.newQuantity
      : this.movementForm.controls.quantity;
    activeControl.markAsTouched();
    this.movementForm.controls.observations.markAsTouched();

    if (activeControl.invalid || this.movementForm.controls.observations.invalid) {
      return;
    }

    this.submitting = true;
    this.errorMessage = '';
    this.successMessage = '';

    this.submitSubscription?.unsubscribe();
    this.submitSubscription = this.submitRequest(this.productId)
      .pipe(finalize(() => {
        this.submitting = false;
      }))
      .subscribe({
        next: (movement) => {
          this.successMessage = `${this.operationSuccessLabel()} correctamente. Stock actual: ${movement.newQuantity}.`;
          this.movementForm.reset({
            quantity: 1,
            newQuantity: movement.newQuantity,
            observations: null
          });
          this.loadProduct(this.productId as number);
          this.loadMovements(this.productId as number);
        },
        error: (error: unknown) => {
          this.errorMessage = stockMovementErrorMessage(
            error,
            'No se pudo registrar el movimiento de stock.'
          );
        }
      });
  }

  fieldError(field: StockFormField): string {
    const control = this.movementForm.controls[field];
    if (!control.touched || !control.errors) {
      return '';
    }

    if (control.errors['required']) {
      return `${STOCK_FIELD_LABELS[field]} es obligatorio.`;
    }

    if (control.errors['maxlength']) {
      return `${STOCK_FIELD_LABELS[field]} supera la longitud permitida.`;
    }

    if (control.errors['min']) {
      return field === 'quantity'
        ? 'Cantidad debe ser mayor que 0.'
        : 'Stock nuevo no puede ser negativo.';
    }

    if (control.errors['pattern']) {
      return `${STOCK_FIELD_LABELS[field]} debe ser un número entero.`;
    }

    return `${STOCK_FIELD_LABELS[field]} no es válido.`;
  }

  operationLabel(type: StockOperationType = this.operationType): string {
    const labels: Record<StockOperationType, string> = {
      ENTRY: 'Entrada',
      EXIT: 'Salida',
      ADJUSTMENT: 'Ajuste'
    };

    return labels[type];
  }

  operationSuccessLabel(type: StockOperationType = this.operationType): string {
    const labels: Record<StockOperationType, string> = {
      ENTRY: 'Entrada registrada',
      EXIT: 'Salida registrada',
      ADJUSTMENT: 'Ajuste registrado'
    };

    return labels[type];
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

  movementActor(movement: StockMovement): string {
    return movement.userDisplayName || movement.username || 'Sistema';
  }

  movementDeltaLabel(deltaQuantity: number): string {
    return deltaQuantity > 0 ? `+${deltaQuantity}` : `${deltaQuantity}`;
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

  statusLabel(status: Product['status']): string {
    return status === 'ACTIVE' ? 'Activo' : 'Inactivo';
  }

  trackByMovementId(_: number, movement: StockMovement): number {
    return movement.id;
  }

  private loadProduct(productId: number): void {
    this.productLoading = true;
    this.errorMessage = '';
    this.productSubscription?.unsubscribe();
    this.productSubscription = this.productService.getProduct(productId)
      .pipe(finalize(() => {
        this.productLoading = false;
      }))
      .subscribe({
        next: (product) => {
          this.product = product;
          this.movementForm.controls.newQuantity.setValue(product.currentStock);
        },
        error: (error: unknown) => {
          this.product = null;
          this.errorMessage = stockMovementErrorMessage(
            error,
            'No se pudo cargar el producto.'
          );
        }
      });
  }

  private loadMovements(productId: number): void {
    this.movementsLoading = true;
    this.movementsSubscription?.unsubscribe();
    this.movementsSubscription = this.stockMovementService.listMovements(productId)
      .pipe(finalize(() => {
        this.movementsLoading = false;
      }))
      .subscribe({
        next: (movements) => {
          this.movements = movements;
        },
        error: (error: unknown) => {
          this.movements = [];
          this.errorMessage = stockMovementErrorMessage(
            error,
            'No se pudo cargar el historial de movimientos.'
          );
        }
      });
  }

  private submitRequest(productId: number): Observable<StockMovement> {
    const value = this.movementForm.getRawValue();
    const observations = value.observations?.trim() || null;

    if (this.operationType === 'ADJUSTMENT') {
      const request: StockAdjustmentRequest = {
        newQuantity: Number(value.newQuantity),
        observations
      };
      return this.stockMovementService.registerAdjustment(productId, request);
    }

    const request: StockMovementRequest = {
      quantity: Number(value.quantity),
      observations
    };

    return this.operationType === 'ENTRY'
      ? this.stockMovementService.registerEntry(productId, request)
      : this.stockMovementService.registerExit(productId, request);
  }
}
