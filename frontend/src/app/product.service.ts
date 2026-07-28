import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { Product, ProductPage, ProductQuery, ProductRequest } from './product.model';

@Injectable({
  providedIn: 'root'
})
export class ProductService {
  private readonly http = inject(HttpClient);
  private readonly apiUrl = '/api/products';

  listProducts(query: ProductQuery): Observable<ProductPage> {
    let params = new HttpParams()
      .set('page', query.page)
      .set('size', query.size)
      .set('sort', query.sort)
      .set('direction', query.direction);

    if (query.search.trim()) {
      params = params.set('search', query.search.trim());
    }

    if (query.category.trim()) {
      params = params.set('category', query.category.trim());
    }

    if (query.status) {
      params = params.set('status', query.status);
    }

    return this.http.get<ProductPage>(this.apiUrl, { params });
  }

  getProduct(productId: number): Observable<Product> {
    return this.http.get<Product>(`${this.apiUrl}/${productId}`);
  }

  createProduct(request: ProductRequest): Observable<Product> {
    return this.http.post<Product>(this.apiUrl, request);
  }

  updateProduct(productId: number, request: ProductRequest): Observable<Product> {
    return this.http.put<Product>(`${this.apiUrl}/${productId}`, request);
  }

  deleteProduct(productId: number): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}/${productId}`);
  }
}
