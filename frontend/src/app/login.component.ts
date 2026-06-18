import { CommonModule } from '@angular/common';
import { Component, inject } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { AuthService } from './auth/auth.service';
import { MATERIAL_IMPORTS } from './shared/material.imports';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, ...MATERIAL_IMPORTS],
  templateUrl: './login.component.html',
  styleUrl: './login.component.css'
})
export class LoginComponent {
  private readonly route = inject(ActivatedRoute);
  private readonly authService = inject(AuthService);

  loginInProgress = false;
  loginError = '';

  get sessionExpired(): boolean {
    return this.route.snapshot.queryParamMap.get('reason') === 'expired';
  }

  get authenticationUnavailable(): boolean {
    return this.authService.status() === 'error';
  }

  async login(): Promise<void> {
    this.loginInProgress = true;
    this.loginError = '';

    try {
      const returnUrl = this.route.snapshot.queryParamMap.get('returnUrl') ?? '/';
      await this.authService.login(returnUrl);
    } catch {
      this.loginError = 'No se pudo iniciar el proceso de autenticación.';
      this.loginInProgress = false;
    }
  }
}
