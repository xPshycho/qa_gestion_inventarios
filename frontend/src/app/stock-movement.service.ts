import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import {
  StockAdjustmentRequest,
  StockMovement,
  StockMovementRequest
} from './stock-movement.model';

@Injectable({
  providedIn: 'root'
})
export class StockMovementService {
  private readonly http = inject(HttpClient);
  private readonly apiUrl = '/api/products';

  listMovements(productId: number): Observable<StockMovement[]> {
    return this.http.get<StockMovement[]>(`${this.apiUrl}/${productId}/stock-movements`);
  }

  registerEntry(productId: number, request: StockMovementRequest): Observable<StockMovement> {
    return this.http.post<StockMovement>(`${this.apiUrl}/${productId}/stock/entries`, request);
  }

  registerExit(productId: number, request: StockMovementRequest): Observable<StockMovement> {
    return this.http.post<StockMovement>(`${this.apiUrl}/${productId}/stock/exits`, request);
  }

  registerAdjustment(productId: number, request: StockAdjustmentRequest): Observable<StockMovement> {
    return this.http.post<StockMovement>(`${this.apiUrl}/${productId}/stock/adjustments`, request);
  }
}
