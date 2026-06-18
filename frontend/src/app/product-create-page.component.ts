import { CommonModule } from '@angular/common';
import { Component, inject } from '@angular/core';
import { Router } from '@angular/router';
import { finalize } from 'rxjs';
import { ProductFormComponent } from './product-form.component';
import { ProductRequest } from './product.model';
import { productErrorMessage } from './product-error';
import { ProductService } from './product.service';
import { MATERIAL_IMPORTS } from './shared/material.imports';

@Component({
  selector: 'app-product-create-page',
  standalone: true,
  imports: [CommonModule, ProductFormComponent, ...MATERIAL_IMPORTS],
  templateUrl: './product-create-page.component.html',
  styleUrl: './product-form.component.css'
})
export class ProductCreatePageComponent {
  private readonly productService = inject(ProductService);
  private readonly router = inject(Router);

  saving = false;
  errorMessage = '';

  createProduct(request: ProductRequest): void {
    this.saving = true;
    this.errorMessage = '';

    this.productService.createProduct(request)
      .pipe(finalize(() => {
        this.saving = false;
      }))
      .subscribe({
        next: (product) => {
          void this.router.navigate(['/productos'], {
            state: {
              successMessage: `Producto ${product.sku} creado correctamente.`
            }
          });
        },
        error: (error: unknown) => {
          this.errorMessage = productErrorMessage(
            error,
            'No se pudo crear el producto.'
          );
        }
      });
  }
}
