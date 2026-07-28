import { CommonModule, DOCUMENT } from '@angular/common';
import { Component, OnDestroy, inject } from '@angular/core';
import { NavigationEnd, Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { Subscription, filter } from 'rxjs';
import { AuthService } from './auth/auth.service';
import { MATERIAL_IMPORTS } from './shared/material.imports';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, RouterLink, RouterLinkActive, RouterOutlet, ...MATERIAL_IMPORTS],
  templateUrl: './app.component.html',
  styleUrl: './app.component.css'
})
export class AppComponent implements OnDestroy {
  readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  private readonly document = inject(DOCUMENT);
  private readonly navigationSubscription: Subscription;
  logoutInProgress = false;

  constructor() {
    this.navigationSubscription = this.router.events
      .pipe(filter((event): event is NavigationEnd => event instanceof NavigationEnd))
      .subscribe(() => {
        let route = this.router.routerState.snapshot.root;
        while (route.firstChild) {
          route = route.firstChild;
        }

        const routeTitle = route.data['title'];
        this.document.title = typeof routeTitle === 'string'
          ? `${routeTitle} | Inventario empresarial`
          : 'Inventario empresarial';

        setTimeout(() => {
          this.document.getElementById('main-content')?.focus({ preventScroll: true });
        });
      });
  }

  ngOnDestroy(): void {
    this.navigationSubscription.unsubscribe();
  }

  async logout(): Promise<void> {
    this.logoutInProgress = true;

    try {
      await this.auth.logout();
    } finally {
      this.logoutInProgress = false;
    }
  }
}
