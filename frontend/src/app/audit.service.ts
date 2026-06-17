import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { AuditRevision } from './audit.model';

@Injectable({
  providedIn: 'root'
})
export class AuditService {
  private readonly http = inject(HttpClient);
  private readonly apiUrl = '/api/audit/products';

  listProductRevisions(productId: number): Observable<AuditRevision[]> {
    return this.http.get<AuditRevision[]>(`${this.apiUrl}/${productId}/revisions`);
  }

  listStockMovementRevisions(productId: number): Observable<AuditRevision[]> {
    return this.http.get<AuditRevision[]>(`${this.apiUrl}/${productId}/stock-movements/revisions`);
  }
}
