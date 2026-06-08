INSERT INTO permissions (code, module, description) VALUES
  ('product:view', 'Productos', 'Ver productos'),
  ('product:manage', 'Productos', 'Crear, editar y eliminar productos'),
  ('stock:view', 'Stock', 'Ver existencia e historial'),
  ('stock:manage', 'Stock', 'Registrar entradas, salidas y ajustes'),
  ('report:view', 'Reportes', 'Ver reportes y dashboard'),
  ('user:manage', 'Seguridad', 'Gestionar usuarios, roles y permisos'),
  ('audit:view', 'Auditoria', 'Consultar auditoria del sistema');

INSERT INTO roles (code, name, description) VALUES
  ('INVENTORY_ADMIN', 'Administrador de inventario', 'Acceso completo a operacion y seguridad'),
  ('STOCK_OPERATOR', 'Operador de stock', 'Gestiona entradas, salidas y ajustes'),
  ('INVENTORY_VIEWER', 'Consultor de inventario', 'Consulta productos, stock y reportes'),
  ('AUDIT_REVIEWER', 'Revisor de auditoria', 'Consulta trazabilidad y auditoria');

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN (
  'product:view',
  'product:manage',
  'stock:view',
  'stock:manage',
  'report:view',
  'user:manage',
  'audit:view'
)
WHERE r.code = 'INVENTORY_ADMIN';

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN ('product:view', 'stock:view', 'stock:manage', 'report:view')
WHERE r.code = 'STOCK_OPERATOR';

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN ('product:view', 'stock:view', 'report:view')
WHERE r.code = 'INVENTORY_VIEWER';

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN ('product:view', 'stock:view', 'audit:view')
WHERE r.code = 'AUDIT_REVIEWER';

INSERT INTO inventory_users (external_id, username, display_name, email) VALUES
  ('demo-carlos', 'carlos', 'Carlos Hernandez', 'carlos@example.local'),
  ('demo-edwin', 'edwin', 'Edwin Balbuena', 'edwin@example.local'),
  ('demo-viewer', 'viewer', 'Usuario Consulta', 'viewer@example.local');

INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM inventory_users u
JOIN roles r ON r.code = 'INVENTORY_ADMIN'
WHERE u.username = 'carlos';

INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM inventory_users u
JOIN roles r ON r.code = 'STOCK_OPERATOR'
WHERE u.username = 'edwin';

INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM inventory_users u
JOIN roles r ON r.code = 'INVENTORY_VIEWER'
WHERE u.username = 'viewer';

INSERT INTO products (sku, name, description, category, price, current_stock, minimum_stock, status) VALUES
  ('DELL-LAT-5440', 'Dell Latitude 5440', 'Laptop empresarial Dell Latitude 5440 con pantalla de 14 pulgadas', 'Laptops', 68500.00, 12, 4, 'ACTIVE'),
  ('LEN-T14-G4', 'Lenovo ThinkPad T14 Gen 4', 'Laptop Lenovo ThinkPad T14 Gen 4 para productividad empresarial', 'Laptops', 74500.00, 8, 3, 'ACTIVE'),
  ('HP-EB840-G10', 'HP EliteBook 840 G10', 'Laptop HP EliteBook 840 G10 orientada a usuarios corporativos', 'Laptops', 71500.00, 6, 2, 'ACTIVE'),
  ('APP-MBA13-M2', 'Apple MacBook Air 13 M2', 'MacBook Air de 13 pulgadas con chip Apple M2', 'Laptops', 82900.00, 0, 2, 'INACTIVE');

INSERT INTO stock_movements (
  product_id,
  user_id,
  movement_type,
  previous_quantity,
  new_quantity,
  delta_quantity,
  observations
)
SELECT p.id, u.id, 'INITIAL', 0, p.current_stock, p.current_stock, 'Seed inicial de inventario'
FROM products p
CROSS JOIN inventory_users u
WHERE u.username = 'carlos'
  AND p.sku IN ('DELL-LAT-5440', 'LEN-T14-G4', 'HP-EB840-G10', 'APP-MBA13-M2');

INSERT INTO audit_log (table_name, record_id, action, actor_user_id, new_values, correlation_id)
SELECT 'products', p.id::TEXT, 'INSERT', u.id,
       jsonb_build_object('sku', p.sku, 'currentStock', p.current_stock, 'status', p.status),
       'seed-004'
FROM products p
CROSS JOIN inventory_users u
WHERE u.username = 'carlos'
  AND p.sku IN ('DELL-LAT-5440', 'LEN-T14-G4', 'HP-EB840-G10', 'APP-MBA13-M2');
