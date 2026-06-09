import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { ProductPage, ProductQuery } from './product.model';

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
}
