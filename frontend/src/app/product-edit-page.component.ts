import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { finalize } from 'rxjs';
import { ProductFormComponent } from './product-form.component';
import { ProductRequest } from './product.model';
import { productErrorMessage } from './product-error';
import { ProductService } from './product.service';

@Component({
  selector: 'app-product-edit-page',
  standalone: true,
  imports: [CommonModule, ProductFormComponent, RouterLink],
  templateUrl: './product-edit-page.component.html',
  styleUrl: './product-form.component.css'
})
export class ProductEditPageComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly productService = inject(ProductService);
  private readonly router = inject(Router);

  productId?: number;
  productValue: ProductRequest | null = null;
  loading = true;
  saving = false;
  errorMessage = '';

  ngOnInit(): void {
    const productId = Number(this.route.snapshot.paramMap.get('id'));
    if (!Number.isSafeInteger(productId) || productId <= 0) {
      this.loading = false;
      this.errorMessage = 'El identificador del producto no es valido.';
      return;
    }

    this.productId = productId;
    this.loadProduct(productId);
  }

  updateProduct(request: ProductRequest): void {
    if (!this.productId || this.saving) {
      return;
    }

    this.saving = true;
    this.errorMessage = '';

    this.productService.updateProduct(this.productId, request)
      .pipe(finalize(() => {
        this.saving = false;
      }))
      .subscribe({
        next: (product) => {
          void this.router.navigate(['/productos'], {
            state: {
              successMessage: `Producto ${product.sku} actualizado correctamente.`
            }
          });
        },
        error: (error: unknown) => {
          this.errorMessage = productErrorMessage(
            error,
            'No se pudo actualizar el producto.'
          );
        }
      });
  }

  private loadProduct(productId: number): void {
    this.loading = true;
    this.errorMessage = '';
    this.productValue = null;

    this.productService.getProduct(productId)
      .pipe(finalize(() => {
        this.loading = false;
      }))
      .subscribe({
        next: (product) => {
          this.productValue = {
            sku: product.sku,
            name: product.name,
            description: product.description,
            category: product.category,
            price: product.price,
            currentStock: product.currentStock,
            minimumStock: product.minimumStock,
            status: product.status
          };
        },
        error: (error: unknown) => {
          this.errorMessage = productErrorMessage(
            error,
            'No se pudo cargar el producto.'
          );
        }
      });
  }
}
