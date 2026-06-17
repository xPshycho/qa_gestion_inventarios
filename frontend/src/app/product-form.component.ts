import { CommonModule } from '@angular/common';
import { Component, EventEmitter, Input, Output, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { ProductRequest } from './product.model';

type ProductFormField = keyof ProductRequest;

const EMPTY_PRODUCT: ProductRequest = {
  sku: '',
  name: '',
  description: null,
  category: '',
  price: 0,
  currentStock: 0,
  minimumStock: 0,
  status: 'ACTIVE'
};

const FIELD_LABELS: Record<ProductFormField, string> = {
  sku: 'SKU',
  name: 'Nombre',
  description: 'Descripcion',
  category: 'Categoria',
  price: 'Precio',
  currentStock: 'Stock actual',
  minimumStock: 'Stock minimo',
  status: 'Estado'
};

@Component({
  selector: 'app-product-form',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, RouterLink],
  templateUrl: './product-form.component.html',
  styleUrl: './product-form.component.css'
})
export class ProductFormComponent {
  private readonly formBuilder = inject(FormBuilder);

  @Input() submitting = false;
  @Input() submitLabel = 'Guardar producto';
  @Input() currentStockReadonly = false;
  @Output() readonly saveProduct = new EventEmitter<ProductRequest>();

  readonly form = this.formBuilder.group({
    sku: this.formBuilder.nonNullable.control('', [
      Validators.required,
      Validators.maxLength(64)
    ]),
    name: this.formBuilder.nonNullable.control('', [
      Validators.required,
      Validators.maxLength(160)
    ]),
    description: this.formBuilder.control<string | null>(null, [
      Validators.maxLength(500)
    ]),
    category: this.formBuilder.nonNullable.control('', [
      Validators.required,
      Validators.maxLength(100)
    ]),
    price: this.formBuilder.nonNullable.control(0, [
      Validators.required,
      Validators.min(0),
      Validators.max(9999999999.99),
      Validators.pattern(/^\d{1,10}(?:\.\d{1,2})?$/)
    ]),
    currentStock: this.formBuilder.nonNullable.control(0, [
      Validators.required,
      Validators.min(0),
      Validators.pattern(/^\d+$/)
    ]),
    minimumStock: this.formBuilder.nonNullable.control(0, [
      Validators.required,
      Validators.min(0),
      Validators.pattern(/^\d+$/)
    ]),
    status: this.formBuilder.nonNullable.control<'ACTIVE' | 'INACTIVE'>('ACTIVE', [
      Validators.required
    ])
  });

  @Input()
  set initialValue(value: ProductRequest | null) {
    this.form.reset(value ?? EMPTY_PRODUCT);
  }

  submit(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }

    const value = this.form.getRawValue();
    const description = value.description?.trim();

    this.saveProduct.emit({
      ...value,
      sku: value.sku.trim(),
      name: value.name.trim(),
      description: description || null,
      category: value.category.trim()
    });
  }

  fieldError(field: ProductFormField): string {
    const control = this.form.controls[field];
    if (!control.touched || !control.errors) {
      return '';
    }

    if (control.errors['required']) {
      return `${FIELD_LABELS[field]} es obligatorio.`;
    }

    if (control.errors['maxlength']) {
      return `${FIELD_LABELS[field]} supera la longitud permitida.`;
    }

    if (control.errors['min']) {
      return `${FIELD_LABELS[field]} no puede ser negativo.`;
    }

    if (control.errors['max']) {
      return `${FIELD_LABELS[field]} supera el valor permitido.`;
    }

    if (control.errors['pattern']) {
      return field === 'price'
        ? 'Precio debe tener hasta 10 enteros y 2 decimales.'
        : `${FIELD_LABELS[field]} debe ser un numero entero.`;
    }

    return `${FIELD_LABELS[field]} no es valido.`;
  }
}
