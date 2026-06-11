import { ComponentFixture, TestBed } from '@angular/core/testing';
import { By } from '@angular/platform-browser';
import { provideRouter } from '@angular/router';
import { of, throwError } from 'rxjs';
import { AuthService } from './auth/auth.service';
import { ProductPage, ProductQuery } from './product.model';
import { ProductService } from './product.service';
import { ProductsComponent } from './products.component';

describe('ProductsComponent', () => {
  let fixture: ComponentFixture<ProductsComponent>;
  let component: ProductsComponent;
  let productService: jasmine.SpyObj<ProductService>;
  let authService: jasmine.SpyObj<AuthService>;

  const page: ProductPage = {
    content: [
      {
        id: 1,
        sku: 'DELL-LAT-5440',
        name: 'Dell Latitude 5440',
        description: 'Laptop empresarial',
        category: 'Laptops',
        price: 68500,
        currentStock: 12,
        minimumStock: 4,
        stockAlert: false,
        status: 'ACTIVE',
        createdAt: '2026-06-07T12:00:00Z',
        updatedAt: '2026-06-07T12:00:00Z'
      }
    ],
    page: 0,
    size: 10,
    totalElements: 1,
    totalPages: 1
  };

  beforeEach(async () => {
    productService = jasmine.createSpyObj<ProductService>(
      'ProductService',
      ['listProducts', 'deleteProduct']
    );
    productService.listProducts.and.returnValue(of(page));
    productService.deleteProduct.and.returnValue(of(void 0));
    authService = jasmine.createSpyObj<AuthService>('AuthService', ['hasPermission']);
    authService.hasPermission.and.returnValue(false);

    await TestBed.configureTestingModule({
      imports: [ProductsComponent],
      providers: [
        { provide: ProductService, useValue: productService },
        { provide: AuthService, useValue: authService },
        provideRouter([])
      ]
    }).compileComponents();

    fixture = TestBed.createComponent(ProductsComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('muestra el listado de productos recibido desde la api', () => {
    const compiled = fixture.nativeElement as HTMLElement;

    expect(compiled.textContent).toContain('Catalogo de inventario');
    expect(compiled.textContent).toContain('DELL-LAT-5440');
    expect(compiled.textContent).toContain('Dell Latitude 5440');
    expect(productService.listProducts).toHaveBeenCalled();
  });

  it('solicita ordenamiento por columna al seleccionar nombre', () => {
    const nameSortButton = fixture.debugElement
      .queryAll(By.css('.sort-button'))
      .find((button) => (button.nativeElement as HTMLElement).textContent?.includes('Nombre'));

    nameSortButton?.triggerEventHandler('click');
    fixture.detectChanges();

    const latestQuery = productService.listProducts.calls.mostRecent().args[0] as ProductQuery;
    expect(latestQuery.sort).toBe('name');
    expect(latestQuery.direction).toBe('asc');
  });

  it('muestra la accion de crear solo con product manage', () => {
    authService.hasPermission.and.returnValue(true);
    fixture.detectChanges();

    const createLink = fixture.debugElement.query(By.css('a[routerLink="/productos/nuevo"]'));

    expect(createLink).not.toBeNull();
    expect(authService.hasPermission).toHaveBeenCalledWith('product:manage');
  });

  it('muestra la accion de editar solo con product manage', () => {
    authService.hasPermission.and.returnValue(true);
    fixture.detectChanges();

    const editLink = fixture.debugElement.query(By.css('a.row-action'));

    expect(editLink).not.toBeNull();
    expect(editLink.attributes['ng-reflect-router-link']).toContain('1');
  });

  it('permite cancelar la eliminacion sin llamar a la api', () => {
    component.requestDelete(page.content[0]);

    component.cancelDelete();

    expect(component.productPendingDelete).toBeNull();
    expect(productService.deleteProduct).not.toHaveBeenCalled();
  });

  it('cierra el dialogo con la tecla escape', () => {
    component.requestDelete(page.content[0]);

    component.closeDeleteDialog();

    expect(component.productPendingDelete).toBeNull();
  });

  it('elimina el producto confirmado y actualiza el listado', () => {
    component.requestDelete(page.content[0]);
    productService.listProducts.calls.reset();

    component.confirmDelete();

    expect(productService.deleteProduct).toHaveBeenCalledWith(1);
    expect(component.successMessage).toBe('Producto DELL-LAT-5440 eliminado correctamente.');
    expect(component.productPendingDelete).toBeNull();
    expect(productService.listProducts).toHaveBeenCalled();
  });

  it('retrocede una pagina si elimina el ultimo producto de la pagina actual', () => {
    component.query.page = 1;
    component.products = [page.content[0]];
    component.requestDelete(page.content[0]);

    component.confirmDelete();

    expect(component.query.page).toBe(0);
  });

  it('muestra error y conserva el listado cuando la api rechaza la eliminacion', () => {
    productService.deleteProduct.and.returnValue(throwError(() => new Error('delete failed')));
    component.requestDelete(page.content[0]);

    component.confirmDelete();

    expect(component.products).toEqual(page.content);
    expect(component.errorMessage).toContain('movimientos de inventario asociados');
    expect(component.productPendingDelete).toBeNull();
  });
});
