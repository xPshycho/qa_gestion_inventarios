import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { SecurityPermission, SecurityRole, SecurityUser, SecurityUserRequest } from './security-admin.model';

@Injectable({
  providedIn: 'root'
})
export class SecurityAdminService {
  private readonly http = inject(HttpClient);
  private readonly apiUrl = '/api/security';

  listUsers(): Observable<SecurityUser[]> {
    return this.http.get<SecurityUser[]>(`${this.apiUrl}/users`);
  }

  createUser(request: SecurityUserRequest): Observable<SecurityUser> {
    return this.http.post<SecurityUser>(`${this.apiUrl}/users`, request);
  }

  updateUser(userId: string, request: SecurityUserRequest): Observable<SecurityUser> {
    return this.http.put<SecurityUser>(`${this.apiUrl}/users/${userId}`, request);
  }

  replaceUserRoles(userId: string, roleCodes: string[]): Observable<SecurityUser> {
    return this.http.put<SecurityUser>(`${this.apiUrl}/users/${userId}/roles`, { roleCodes });
  }

  listRoles(): Observable<SecurityRole[]> {
    return this.http.get<SecurityRole[]>(`${this.apiUrl}/roles`);
  }

  listPermissions(): Observable<SecurityPermission[]> {
    return this.http.get<SecurityPermission[]>(`${this.apiUrl}/permissions`);
  }
}
