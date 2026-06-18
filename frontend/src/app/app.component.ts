import { CommonModule } from '@angular/common';
import { Component, inject } from '@angular/core';
import { RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { AuthService } from './auth/auth.service';
import { MATERIAL_IMPORTS } from './shared/material.imports';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, RouterLink, RouterLinkActive, RouterOutlet, ...MATERIAL_IMPORTS],
  templateUrl: './app.component.html',
  styleUrl: './app.component.css'
})
export class AppComponent {
  readonly auth = inject(AuthService);
  logoutInProgress = false;

  async logout(): Promise<void> {
    this.logoutInProgress = true;

    try {
      await this.auth.logout();
    } finally {
      this.logoutInProgress = false;
    }
  }
}
