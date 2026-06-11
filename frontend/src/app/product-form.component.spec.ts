import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { ProductRequest } from './product.model';
import { ProductFormComponent } from './product-form.component';

describe('ProductFormComponent', () => {
  let fixture: ComponentFixture<ProductFormComponent>;
  let component: ProductFormComponent;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [ProductFormComponent],
      providers: [provideRouter([])]
    }).compileComponents();

    fixture = TestBed.createComponent(ProductFormComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('no envia el formulario cuando faltan campos obligatorios', () => {
    spyOn(component.saveProduct, 'emit');
    component.form.patchValue({
      sku: '',
      name: '',
      category: ''
    });

    component.submit();

    expect(component.form.invalid).toBeTrue();
    expect(component.saveProduct.emit).not.toHaveBeenCalled();
    expect(component.form.controls.sku.touched).toBeTrue();
  });

  it('normaliza textos y emite una solicitud valida', () => {
    const request: ProductRequest = {
      sku: 'LAP-001',
      name: 'Laptop de prueba',
      description: null,
      category: 'Laptops',
      price: 1250.5,
      currentStock: 10,
      minimumStock: 2,
      status: 'ACTIVE'
    };
    spyOn(component.saveProduct, 'emit');
    component.form.setValue({
      ...request,
      sku: ` ${request.sku} `,
      name: ` ${request.name} `,
      description: '   ',
      category: ` ${request.category} `
    });

    component.submit();

    expect(component.saveProduct.emit).toHaveBeenCalledWith(request);
  });
});
