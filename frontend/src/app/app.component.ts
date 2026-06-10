import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Subscription, finalize } from 'rxjs';
import { Product, ProductPage, ProductQuery, ProductStatus, SortField } from './product.model';
import { ProductService } from './product.service';

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
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './app.component.html',
  styleUrl: './app.component.css'
})
export class AppComponent implements OnInit, OnDestroy {
  private readonly productService = inject(ProductService);
  private productsSubscription?: Subscription;
  private searchTimer?: ReturnType<typeof setTimeout>;

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

  ngOnInit(): void {
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
