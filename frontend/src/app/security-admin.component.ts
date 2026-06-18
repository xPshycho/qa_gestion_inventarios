import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { forkJoin, Subscription, finalize } from 'rxjs';
import { SecurityPermission, SecurityRole, SecurityUser, SecurityUserRequest } from './security-admin.model';
import { SecurityAdminService } from './security-admin.service';
import { MATERIAL_IMPORTS } from './shared/material.imports';

const EMPTY_FORM: SecurityUserRequest = {
  username: '',
  firstName: '',
  lastName: '',
  email: '',
  enabled: true,
  roleCodes: []
};

@Component({
  selector: 'app-security-admin',
  standalone: true,
  imports: [CommonModule, FormsModule, ...MATERIAL_IMPORTS],
  templateUrl: './security-admin.component.html',
  styleUrl: './security-admin.component.css'
})
export class SecurityAdminComponent implements OnInit, OnDestroy {
  private readonly securityAdminService = inject(SecurityAdminService);
  private subscription?: Subscription;

  users: SecurityUser[] = [];
  roles: SecurityRole[] = [];
  permissions: SecurityPermission[] = [];
  selectedUser: SecurityUser | null = null;
  form: SecurityUserRequest = { ...EMPTY_FORM };
  roleSelection: Record<string, boolean> = {};
  loading = false;
  saving = false;
  errorMessage = '';
  successMessage = '';

  ngOnInit(): void {
    this.loadSecurityData();
  }

  ngOnDestroy(): void {
    this.subscription?.unsubscribe();
  }

  loadSecurityData(): void {
    this.loading = true;
    this.errorMessage = '';
    this.subscription?.unsubscribe();
    this.subscription = forkJoin({
      users: this.securityAdminService.listUsers(),
      roles: this.securityAdminService.listRoles(),
      permissions: this.securityAdminService.listPermissions()
    })
      .pipe(finalize(() => {
        this.loading = false;
      }))
      .subscribe({
        next: ({ users, roles, permissions }) => {
          this.users = users;
          this.roles = roles;
          this.permissions = permissions;
          this.resetRoleSelection(this.form.roleCodes);
        },
        error: () => {
          this.errorMessage = 'No se pudo cargar la configuración de seguridad.';
        }
      });
  }

  startCreate(): void {
    this.selectedUser = null;
    this.form = { ...EMPTY_FORM, roleCodes: [] };
    this.resetRoleSelection([]);
    this.successMessage = '';
    this.errorMessage = '';
  }

  selectUser(user: SecurityUser): void {
    this.selectedUser = user;
    this.form = {
      username: user.username,
      firstName: user.firstName,
      lastName: user.lastName,
      email: user.email ?? '',
      enabled: user.enabled,
      roleCodes: [...user.roleCodes]
    };
    this.resetRoleSelection(user.roleCodes);
    this.successMessage = '';
    this.errorMessage = '';
  }

  saveUser(): void {
    this.saving = true;
    this.errorMessage = '';
    this.successMessage = '';
    const request = this.currentRequest();
    const selectedUser = this.selectedUser;
    const editing = selectedUser !== null;
    const operation = editing
      ? this.securityAdminService.updateUser(selectedUser.id, request)
      : this.securityAdminService.createUser(request);

    operation
      .pipe(finalize(() => {
        this.saving = false;
      }))
      .subscribe({
        next: (user) => {
          this.upsertUser(user);
          this.selectUser(user);
          this.successMessage = editing
            ? 'Usuario actualizado correctamente.'
            : 'Usuario creado correctamente.';
        },
        error: () => {
          this.errorMessage = 'No se pudo guardar el usuario.';
        }
      });
  }

  saveRoles(): void {
    if (!this.selectedUser) {
      return;
    }

    this.saving = true;
    this.errorMessage = '';
    this.successMessage = '';
    const roleCodes = this.selectedRoleCodes();

    this.securityAdminService.replaceUserRoles(this.selectedUser.id, roleCodes)
      .pipe(finalize(() => {
        this.saving = false;
      }))
      .subscribe({
        next: (user) => {
          this.upsertUser(user);
          this.selectUser(user);
          this.successMessage = 'Roles actualizados correctamente.';
        },
        error: () => {
          this.errorMessage = 'No se pudieron actualizar los roles.';
        }
      });
  }

  roleLabel(code: string): string {
    return this.roles.find((role) => role.code === code)?.name ?? code;
  }

  permissionModules(): string[] {
    return [...new Set(this.permissions.map((permission) => permission.module))];
  }

  permissionsByModule(module: string): SecurityPermission[] {
    return this.permissions.filter((permission) => permission.module === module);
  }

  trackByUserId(_: number, user: SecurityUser): string {
    return user.id;
  }

  trackByRoleCode(_: number, role: SecurityRole): string {
    return role.code;
  }

  private currentRequest(): SecurityUserRequest {
    return {
      ...this.form,
      username: this.form.username.trim(),
      firstName: this.form.firstName.trim(),
      lastName: this.form.lastName.trim(),
      email: this.form.email.trim(),
      roleCodes: this.selectedRoleCodes()
    };
  }

  private selectedRoleCodes(): string[] {
    return Object.entries(this.roleSelection)
      .filter(([, selected]) => selected)
      .map(([roleCode]) => roleCode)
      .sort();
  }

  private resetRoleSelection(roleCodes: string[]): void {
    const selectedRoles = new Set(roleCodes);
    this.roleSelection = Object.fromEntries(
      this.roles.map((role) => [role.code, selectedRoles.has(role.code)])
    );
  }

  private upsertUser(user: SecurityUser): void {
    const index = this.users.findIndex((current) => current.id === user.id);
    if (index === -1) {
      this.users = [...this.users, user].sort((left, right) => left.username.localeCompare(right.username));
      return;
    }

    this.users = this.users.map((current) => current.id === user.id ? user : current);
  }
}
