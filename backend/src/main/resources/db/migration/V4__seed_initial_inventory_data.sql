CREATE TEMP TABLE seed_permissions (
  code TEXT PRIMARY KEY,
  module TEXT NOT NULL,
  description TEXT NOT NULL,
  grant_inventory_admin BOOLEAN NOT NULL,
  grant_stock_operator BOOLEAN NOT NULL,
  grant_inventory_viewer BOOLEAN NOT NULL,
  grant_audit_reviewer BOOLEAN NOT NULL
) ON COMMIT DROP;

INSERT INTO seed_permissions (
  code,
  module,
  description,
  grant_inventory_admin,
  grant_stock_operator,
  grant_inventory_viewer,
  grant_audit_reviewer
) VALUES
  ('product:view', 'Productos', 'Ver productos', TRUE, TRUE, TRUE, TRUE),
  ('product:manage', 'Productos', 'Crear, editar y eliminar productos', TRUE, FALSE, FALSE, FALSE),
  ('stock:view', 'Stock', 'Ver existencia e historial', TRUE, TRUE, TRUE, TRUE),
  ('stock:manage', 'Stock', 'Registrar entradas, salidas y ajustes', TRUE, TRUE, FALSE, FALSE),
  ('report:view', 'Reportes', 'Ver reportes y dashboard', TRUE, TRUE, TRUE, FALSE),
  ('user:manage', 'Seguridad', 'Gestionar usuarios, roles y permisos', TRUE, FALSE, FALSE, FALSE),
  ('audit:view', 'Auditoria', 'Consultar auditoria del sistema', TRUE, FALSE, FALSE, TRUE);

INSERT INTO permissions (code, module, description)
SELECT code, module, description
FROM seed_permissions;

CREATE TEMP TABLE seed_roles (
  code TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  permission_grant TEXT NOT NULL
) ON COMMIT DROP;

INSERT INTO seed_roles (code, name, description, permission_grant) VALUES
  ('INVENTORY_ADMIN', 'Administrador de inventario', 'Acceso completo a operacion y seguridad', 'inventory_admin'),
  ('STOCK_OPERATOR', 'Operador de stock', 'Gestiona entradas, salidas y ajustes', 'stock_operator'),
  ('INVENTORY_VIEWER', 'Consultor de inventario', 'Consulta productos, stock y reportes', 'inventory_viewer'),
  ('AUDIT_REVIEWER', 'Revisor de auditoria', 'Consulta trazabilidad y auditoria', 'audit_reviewer');

INSERT INTO roles (code, name, description)
SELECT code, name, description
FROM seed_roles;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN seed_roles sr ON sr.code = r.code
JOIN seed_permissions sp ON (
     (sr.permission_grant = 'inventory_admin' AND sp.grant_inventory_admin)
  OR (sr.permission_grant = 'stock_operator' AND sp.grant_stock_operator)
  OR (sr.permission_grant = 'inventory_viewer' AND sp.grant_inventory_viewer)
  OR (sr.permission_grant = 'audit_reviewer' AND sp.grant_audit_reviewer)
)
JOIN permissions p ON p.code = sp.code;

CREATE TEMP TABLE seed_users (
  external_id TEXT PRIMARY KEY,
  username TEXT NOT NULL,
  display_name TEXT NOT NULL,
  email TEXT NOT NULL,
  role_code TEXT NOT NULL REFERENCES seed_roles (code),
  initial_stock_actor BOOLEAN NOT NULL
) ON COMMIT DROP;

INSERT INTO seed_users (external_id, username, display_name, email, role_code, initial_stock_actor) VALUES
  ('demo-carlos', 'carlos', 'Carlos Hernandez', 'carlos@example.local', 'INVENTORY_ADMIN', TRUE),
  ('demo-edwin', 'edwin', 'Edwin Balbuena', 'edwin@example.local', 'STOCK_OPERATOR', FALSE),
  ('demo-viewer', 'viewer', 'Usuario Consulta', 'viewer@example.local', 'INVENTORY_VIEWER', FALSE);

INSERT INTO inventory_users (external_id, username, display_name, email)
SELECT external_id, username, display_name, email
FROM seed_users;

INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM seed_users su
JOIN inventory_users u ON u.username = su.username
JOIN roles r ON r.code = su.role_code;

CREATE TEMP TABLE seed_products (
  sku TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  price NUMERIC(12, 2) NOT NULL,
  current_stock INTEGER NOT NULL,
  minimum_stock INTEGER NOT NULL,
  active BOOLEAN NOT NULL
) ON COMMIT DROP;

INSERT INTO seed_products (
  sku,
  name,
  description,
  price,
  current_stock,
  minimum_stock,
  active
) VALUES
  ('DELL-LAT-5440', 'Dell Latitude 5440', 'Laptop empresarial Dell Latitude 5440 con pantalla de 14 pulgadas', 68500.00, 12, 4, TRUE),
  ('LEN-T14-G4', 'Lenovo ThinkPad T14 Gen 4', 'Laptop Lenovo ThinkPad T14 Gen 4 para productividad empresarial', 74500.00, 8, 3, TRUE),
  ('HP-EB840-G10', 'HP EliteBook 840 G10', 'Laptop HP EliteBook 840 G10 orientada a usuarios corporativos', 71500.00, 6, 2, TRUE),
  ('APP-MBA13-M2', 'Apple MacBook Air 13 M2', 'MacBook Air de 13 pulgadas con chip Apple M2', 82900.00, 0, 2, FALSE);

INSERT INTO products (sku, name, description, category, price, current_stock, minimum_stock, status)
SELECT
  sku,
  name,
  description,
  'Laptops',
  price,
  current_stock,
  minimum_stock,
  CASE active WHEN TRUE THEN 'ACTIVE' ELSE 'INACTIVE' END
FROM seed_products;

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
FROM seed_products sp
JOIN products p ON p.sku = sp.sku
CROSS JOIN inventory_users u
JOIN seed_users su ON su.username = u.username
WHERE su.initial_stock_actor;

INSERT INTO audit_log (table_name, record_id, action, actor_user_id, new_values, correlation_id)
SELECT 'products', p.id::TEXT, 'INSERT', u.id,
       jsonb_build_object('sku', p.sku, 'currentStock', p.current_stock, 'status', p.status),
       'seed-004'
FROM seed_products sp
JOIN products p ON p.sku = sp.sku
CROSS JOIN inventory_users u
JOIN seed_users su ON su.username = u.username
WHERE su.initial_stock_actor;
