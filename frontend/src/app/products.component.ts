import { CommonModule } from '@angular/common';
import { Component, ElementRef, HostListener, OnDestroy, OnInit, ViewChild, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { Subscription, finalize } from 'rxjs';
import { AuthService } from './auth/auth.service';
import { Product, ProductPage, ProductQuery, ProductStatus, SortField } from './product.model';
import { productErrorMessage } from './product-error';
import { ProductService } from './product.service';
import { MATERIAL_IMPORTS } from './shared/material.imports';

const DEFAULT_QUERY: ProductQuery = {
  page: 0,
  size: 10,
  search: '',
  category: '',
  status: '',
  sort: 'id',
  direction: 'asc'
};

@Component({
  selector: 'app-products',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, ...MATERIAL_IMPORTS],
  templateUrl: './products.component.html',
  styleUrl: './products.component.css'
})
export class ProductsComponent implements OnInit, OnDestroy {
  private readonly productService = inject(ProductService);
  readonly auth = inject(AuthService);
  private productsSubscription?: Subscription;
  private searchTimer?: ReturnType<typeof setTimeout>;

  @ViewChild('deleteConfirmButton') deleteConfirmButton?: ElementRef<HTMLButtonElement>;

  products: Product[] = [];
  page: ProductPage = {
    content: [],
    page: 0,
    size: DEFAULT_QUERY.size,
    totalElements: 0,
    totalPages: 0
  };
  query: ProductQuery = { ...DEFAULT_QUERY };
  loading = false;
  errorMessage = '';
  successMessage = '';
  productPendingDelete: Product | null = null;
  deletingProductId: number | null = null;

  ngOnInit(): void {
    const navigationMessage = window.history.state?.['successMessage'];
    this.successMessage = typeof navigationMessage === 'string' ? navigationMessage : '';
    this.loadProducts();
  }

  ngOnDestroy(): void {
    this.productsSubscription?.unsubscribe();
    this.clearSearchTimer();
  }

  loadProducts(): void {
    this.loading = true;
    this.errorMessage = '';
    this.productsSubscription?.unsubscribe();
    this.productsSubscription = this.productService.listProducts(this.query)
      .pipe(finalize(() => {
        this.loading = false;
      }))
      .subscribe({
        next: (page) => {
          this.page = page;
          this.products = page.content;
        },
        error: () => {
          this.errorMessage = 'No se pudo cargar el listado de productos.';
          this.products = [];
        }
      });
  }

  queueSearch(): void {
    this.clearSearchTimer();
    this.searchTimer = setTimeout(() => {
      this.query.page = 0;
      this.loadProducts();
    }, 300);
  }

  applyFilters(): void {
    this.query.page = 0;
    this.loadProducts();
  }

  clearFilters(): void {
    this.query = {
      ...DEFAULT_QUERY,
      size: this.query.size,
      sort: this.query.sort,
      direction: this.query.direction
    };
    this.loadProducts();
  }

  changeSort(field: SortField): void {
    if (this.query.sort === field) {
      this.query.direction = this.query.direction === 'asc' ? 'desc' : 'asc';
    } else {
      this.query.sort = field;
      this.query.direction = 'asc';
    }

    this.query.page = 0;
    this.loadProducts();
  }

  changePage(nextPage: number): void {
    if (nextPage < 0 || nextPage >= this.totalPages()) {
      return;
    }

    this.query.page = nextPage;
    this.loadProducts();
  }

  changePageSize(): void {
    this.query.page = 0;
    this.loadProducts();
  }

  requestDelete(product: Product): void {
    this.productPendingDelete = product;
    setTimeout(() => this.deleteConfirmButton?.nativeElement.focus());
  }

  cancelDelete(): void {
    if (this.deletingProductId === null) {
      this.productPendingDelete = null;
    }
  }

  confirmDelete(): void {
    const product = this.productPendingDelete;
    if (!product || this.deletingProductId !== null) {
      return;
    }

    this.deletingProductId = product.id;
    this.errorMessage = '';
    this.successMessage = '';

    this.productService.deleteProduct(product.id)
      .pipe(finalize(() => {
        this.deletingProductId = null;
      }))
      .subscribe({
        next: () => {
          this.productPendingDelete = null;
          this.successMessage = `Producto ${product.sku} eliminado correctamente.`;

          if (this.products.length === 1 && this.query.page > 0) {
            this.query.page -= 1;
          }

          this.loadProducts();
        },
        error: (error: unknown) => {
          this.productPendingDelete = null;
          this.errorMessage = productErrorMessage(
            error,
            'No se pudo eliminar el producto. Puede tener movimientos de inventario asociados.'
          );
        }
      });
  }

  @HostListener('document:keydown.escape')
  closeDeleteDialog(): void {
    this.cancelDelete();
  }

  totalPages(): number {
    return Math.max(this.page.totalPages, 1);
  }

  firstItem(): number {
    if (this.page.totalElements === 0) {
      return 0;
    }

    return this.page.page * this.page.size + 1;
  }

  lastItem(): number {
    return Math.min((this.page.page + 1) * this.page.size, this.page.totalElements);
  }

  sortLabel(field: SortField): string {
    if (this.query.sort !== field) {
      return '';
    }

    return this.query.direction.toUpperCase();
  }

  statusLabel(status: ProductStatus): string {
    return status === 'ACTIVE' ? 'Activo' : 'Inactivo';
  }

  trackByProductId(_: number, product: Product): number {
    return product.id;
  }

  hasFilters(): boolean {
    return Boolean(this.query.search.trim() || this.query.category.trim() || this.query.status);
  }

  private clearSearchTimer(): void {
    if (this.searchTimer) {
      clearTimeout(this.searchTimer);
    }
  }
}
