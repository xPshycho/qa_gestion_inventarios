import { HttpErrorResponse } from '@angular/common/http';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, convertToParamMap, provideRouter } from '@angular/router';
import { of, throwError } from 'rxjs';
import { AuditRevision } from './audit.model';
import { AuditPageComponent } from './audit-page.component';
import { AuditService } from './audit.service';
import { Product } from './product.model';
import { ProductService } from './product.service';

describe('AuditPageComponent', () => {
  let fixture: ComponentFixture<AuditPageComponent>;
  let component: AuditPageComponent;
  let productService: jasmine.SpyObj<ProductService>;
  let auditService: jasmine.SpyObj<AuditService>;

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

  const productRevision: AuditRevision = {
    entityName: 'Product',
    entityId: 1,
    revision: 3,
    revisionType: 'MOD',
    changedAt: '2026-06-17T12:00:00Z',
    username: 'carlos',
    previousValues: { name: 'Dell Latitude 5430' },
    currentValues: { name: 'Dell Latitude 5440' }
  };

  const stockRevision: AuditRevision = {
    entityName: 'StockMovement',
    entityId: 10,
    revision: 4,
    revisionType: 'ADD',
    changedAt: '2026-06-17T13:00:00Z',
    username: 'edwin',
    previousValues: {},
    currentValues: {
      movementType: 'ENTRY',
      newQuantity: 15,
      observations: 'Recepcion'
    }
  };

  beforeEach(async () => {
    productService = jasmine.createSpyObj<ProductService>('ProductService', ['getProduct']);
    auditService = jasmine.createSpyObj<AuditService>(
      'AuditService',
      ['listProductRevisions', 'listStockMovementRevisions']
    );

    productService.getProduct.and.returnValue(of(product));
    auditService.listProductRevisions.and.returnValue(of([productRevision]));
    auditService.listStockMovementRevisions.and.returnValue(of([stockRevision]));

    await TestBed.configureTestingModule({
      imports: [AuditPageComponent],
      providers: [
        provideRouter([]),
        { provide: ProductService, useValue: productService },
        { provide: AuditService, useValue: auditService },
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

    fixture = TestBed.createComponent(AuditPageComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('carga producto y revisiones de auditoria', () => {
    const compiled = fixture.nativeElement as HTMLElement;

    expect(compiled.textContent).toContain('Historial de producto y stock');
    expect(compiled.textContent).toContain('DELL-LAT-5440');
    expect(compiled.textContent).toContain('Cambios del producto');
    expect(compiled.textContent).toContain('Revisiones de movimientos de stock');
    expect(compiled.textContent).toContain('Dell Latitude 5430');
    expect(compiled.textContent).toContain('Recepcion');
    expect(productService.getProduct).toHaveBeenCalledWith(1);
    expect(auditService.listProductRevisions).toHaveBeenCalledWith(1);
    expect(auditService.listStockMovementRevisions).toHaveBeenCalledWith(1);
  });

  it('muestra etiquetas legibles para revision y entidad', () => {
    expect(component.revisionTypeLabel('ADD')).toBe('Alta');
    expect(component.revisionTypeLabel('MOD')).toBe('Modificación');
    expect(component.entityLabel('StockMovement')).toBe('Movimiento de stock');
  });

  it('calcula los campos modificados entre valores previos y actuales', () => {
    const changes = component.changesFor(productRevision);

    expect(changes).toEqual([
      {
        field: 'name',
        previousValue: 'Dell Latitude 5430',
        currentValue: 'Dell Latitude 5440'
      }
    ]);
  });

  it('muestra estados vacios cuando no hay revisiones', () => {
    auditService.listProductRevisions.and.returnValue(of([]));
    auditService.listStockMovementRevisions.and.returnValue(of([]));

    component.refreshAudit();
    fixture.detectChanges();

    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.textContent).toContain('No hay revisiones del producto');
    expect(compiled.textContent).toContain('No hay revisiones de movimientos de stock');
  });

  it('muestra error cuando la API rechaza la carga', () => {
    productService.getProduct.and.returnValue(throwError(() => new HttpErrorResponse({
      status: 404,
      error: { message: 'Product not found with id 99' }
    })));

    component.refreshAudit();
    fixture.detectChanges();

    expect(component.errorMessage).toBe('El producto solicitado no existe.');
    expect(component.product).toBeNull();
  });
});
