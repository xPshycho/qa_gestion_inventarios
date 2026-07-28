import { HttpErrorResponse } from '@angular/common/http';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, convertToParamMap, provideRouter } from '@angular/router';
import { of, throwError } from 'rxjs';
import { AuthService } from './auth/auth.service';
import { Product } from './product.model';
import { ProductService } from './product.service';
import { StockMovement } from './stock-movement.model';
import { StockMovementService } from './stock-movement.service';
import { StockMovementsPageComponent } from './stock-movements-page.component';

describe('StockMovementsPageComponent', () => {
  let fixture: ComponentFixture<StockMovementsPageComponent>;
  let component: StockMovementsPageComponent;
  let productService: jasmine.SpyObj<ProductService>;
  let stockMovementService: jasmine.SpyObj<StockMovementService>;
  let authService: jasmine.SpyObj<AuthService>;

  const product: Product = {
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
  };

  const movement: StockMovement = {
    id: 10,
    productId: product.id,
    productSku: product.sku,
    productName: product.name,
    userId: 1,
    username: 'carlos',
    userDisplayName: 'Carlos Hernandez',
    movementType: 'INITIAL',
    previousQuantity: 0,
    newQuantity: 12,
    deltaQuantity: 12,
    observations: 'Seed inicial',
    stockAlert: false,
    createdAt: '2026-06-07T12:00:00Z'
  };

  beforeEach(async () => {
    productService = jasmine.createSpyObj<ProductService>('ProductService', ['getProduct']);
    stockMovementService = jasmine.createSpyObj<StockMovementService>(
      'StockMovementService',
      ['listMovements', 'registerEntry', 'registerExit', 'registerAdjustment']
    );
    authService = jasmine.createSpyObj<AuthService>('AuthService', ['hasPermission']);

    productService.getProduct.and.returnValue(of(product));
    stockMovementService.listMovements.and.returnValue(of([movement]));
    stockMovementService.registerEntry.and.returnValue(of({
      ...movement,
      id: 11,
      movementType: 'ENTRY',
      previousQuantity: 12,
      newQuantity: 16,
      deltaQuantity: 4,
      observations: 'Recepcion'
    }));
    stockMovementService.registerExit.and.returnValue(of({
      ...movement,
      id: 12,
      movementType: 'EXIT',
      previousQuantity: 12,
      newQuantity: 10,
      deltaQuantity: -2,
      observations: 'Salida'
    }));
    stockMovementService.registerAdjustment.and.returnValue(of({
      ...movement,
      id: 13,
      movementType: 'ADJUSTMENT',
      previousQuantity: 12,
      newQuantity: 8,
      deltaQuantity: -4,
      observations: 'Conteo'
    }));
    authService.hasPermission.and.callFake((permission) => permission === 'stock:manage');

    await TestBed.configureTestingModule({
      imports: [StockMovementsPageComponent],
      providers: [
        provideRouter([]),
        { provide: ProductService, useValue: productService },
        { provide: StockMovementService, useValue: stockMovementService },
        { provide: AuthService, useValue: authService },
        {
          provide: ActivatedRoute,
          useValue: {
            snapshot: {
              paramMap: convertToParamMap({ id: '1' })
            }
          }
        }
      ]
    }).compileComponents();

    fixture = TestBed.createComponent(StockMovementsPageComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('carga el producto y el historial de movimientos', () => {
    const compiled = fixture.nativeElement as HTMLElement;

    expect(compiled.textContent).toContain('Movimientos de stock');
    expect(compiled.textContent).toContain(product.sku);
    expect(compiled.textContent).toContain('Seed inicial');
    expect(productService.getProduct).toHaveBeenCalledWith(1);
    expect(stockMovementService.listMovements).toHaveBeenCalledWith(1);
  });

  it('registra una entrada y refresca producto e historial', () => {
    productService.getProduct.calls.reset();
    stockMovementService.listMovements.calls.reset();
    component.movementForm.patchValue({
      quantity: 4,
      observations: ' Recepcion '
    });

    component.submitMovement();

    expect(stockMovementService.registerEntry).toHaveBeenCalledWith(1, {
      quantity: 4,
      observations: 'Recepcion'
    });
    expect(component.successMessage).toBe('Entrada registrada correctamente. Stock actual: 16.');
    expect(productService.getProduct).toHaveBeenCalledWith(1);
    expect(stockMovementService.listMovements).toHaveBeenCalledWith(1);
  });

  it('registra un ajuste usando el nuevo stock absoluto', () => {
    component.selectOperation('ADJUSTMENT');
    component.movementForm.patchValue({
      newQuantity: 8,
      observations: ' Conteo '
    });

    component.submitMovement();

    expect(stockMovementService.registerAdjustment).toHaveBeenCalledWith(1, {
      newQuantity: 8,
      observations: 'Conteo'
    });
    expect(component.successMessage).toBe('Ajuste registrado correctamente. Stock actual: 8.');
  });

  it('muestra modo de solo consulta sin stock manage', () => {
    authService.hasPermission.and.returnValue(false);
    fixture.detectChanges();

    const compiled = fixture.nativeElement as HTMLElement;

    expect(compiled.textContent).toContain('Consulta de stock');
    expect(compiled.textContent).not.toContain('Registrar movimiento');
  });

  it('muestra errores de negocio de la API', () => {
    stockMovementService.registerExit.and.returnValue(throwError(() => new HttpErrorResponse({
      status: 400,
      error: {
        message: 'Stock insuficiente para producto 1'
      }
    })));
    component.selectOperation('EXIT');
    component.movementForm.patchValue({ quantity: 99 });

    component.submitMovement();

    expect(component.errorMessage).toContain('Stock insuficiente');
  });
});
