CREATE TEMP TABLE seed_demo_users (
  external_id TEXT PRIMARY KEY,
  username TEXT NOT NULL,
  display_name TEXT NOT NULL,
  email TEXT NOT NULL,
  role_code TEXT NOT NULL
) ON COMMIT DROP;

INSERT INTO seed_demo_users (external_id, username, display_name, email, role_code) VALUES
  ('user-carlos', 'carlos', 'Carlos Hernandez', 'carlos@example.local', 'INVENTORY_ADMIN'),
  ('user-edwin', 'edwin', 'Edwin Balbuena', 'edwin@example.local', 'STOCK_OPERATOR'),
  ('user-viewer', 'viewer', 'Usuario Consulta', 'viewer@example.local', 'INVENTORY_VIEWER'),
  ('user-auditor', 'auditor', 'Usuario Auditoria', 'auditor@example.local', 'AUDIT_REVIEWER');

UPDATE inventory_users u
SET external_id = s.external_id,
    display_name = s.display_name,
    email = s.email,
    status = 'ACTIVE'
FROM seed_demo_users s
WHERE u.username = s.username;

INSERT INTO inventory_users (external_id, username, display_name, email, status)
SELECT external_id, username, display_name, email, 'ACTIVE'
FROM seed_demo_users s
WHERE NOT EXISTS (
  SELECT 1
  FROM inventory_users u
  WHERE u.username = s.username
);

INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM seed_demo_users s
JOIN inventory_users u ON u.username = s.username
JOIN roles r ON r.code = s.role_code
ON CONFLICT DO NOTHING;

CREATE TEMP TABLE seed_demo_products (
  sku TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  category TEXT NOT NULL,
  price NUMERIC(12, 2) NOT NULL,
  current_stock INTEGER NOT NULL,
  minimum_stock INTEGER NOT NULL,
  status TEXT NOT NULL
) ON COMMIT DROP;

INSERT INTO seed_demo_products (
  sku,
  name,
  description,
  category,
  price,
  current_stock,
  minimum_stock,
  status
) VALUES
  ('MON-DELL-P2422H', 'Dell P2422H 24"', 'Monitor empresarial Full HD con base ajustable', 'Monitores', 14250.00, 18, 5, 'ACTIVE'),
  ('MON-LG-27QN600', 'LG 27QN600 QHD', 'Monitor QHD de 27 pulgadas para productividad', 'Monitores', 18900.00, 4, 6, 'ACTIVE'),
  ('MON-SAM-ODYSSEY-G5', 'Samsung Odyssey G5', 'Monitor curvo QHD para estaciones graficas', 'Monitores', 26800.00, 0, 3, 'ACTIVE'),
  ('MOU-LOGI-MX-MASTER-3S', 'Logitech MX Master 3S', 'Mouse inalambrico ergonomico para oficina', 'Perifericos', 6950.00, 26, 8, 'ACTIVE'),
  ('KEY-LOGI-MX-KEYS', 'Logitech MX Keys', 'Teclado inalambrico retroiluminado', 'Perifericos', 7850.00, 11, 4, 'ACTIVE'),
  ('HEAD-JABRA-EVOLVE2-65', 'Jabra Evolve2 65', 'Audifonos con microfono para llamadas corporativas', 'Perifericos', 12900.00, 3, 5, 'ACTIVE'),
  ('DOCK-DELL-WD19S', 'Dell Dock WD19S', 'Dock USB-C para estaciones Dell', 'Accesorios', 11200.00, 1, 5, 'ACTIVE'),
  ('ADP-LEN-USB-C-65W', 'Lenovo USB-C 65W Adapter', 'Adaptador de corriente USB-C de 65W', 'Accesorios', 2450.00, 32, 10, 'ACTIVE'),
  ('CAB-HDMI-2M', 'Cable HDMI 2m', 'Cable HDMI certificado para salas de reuniones', 'Accesorios', 650.00, 0, 15, 'ACTIVE'),
  ('SSD-SAM-980-1TB', 'Samsung 980 1TB NVMe', 'Unidad SSD NVMe de alto rendimiento', 'Almacenamiento', 6200.00, 14, 6, 'ACTIVE'),
  ('SSD-KING-NV2-500', 'Kingston NV2 500GB', 'Unidad SSD NVMe para upgrades basicos', 'Almacenamiento', 3250.00, 2, 8, 'ACTIVE'),
  ('HDD-WD-BLUE-2TB', 'WD Blue 2TB', 'Disco duro mecanico para respaldo', 'Almacenamiento', 3900.00, 9, 4, 'ACTIVE'),
  ('RAM-KING-16GB-DDR4', 'Kingston 16GB DDR4', 'Memoria RAM DDR4 para laptops empresariales', 'Componentes', 2850.00, 21, 7, 'ACTIVE'),
  ('RAM-CRUCIAL-32GB-DDR5', 'Crucial 32GB DDR5', 'Memoria RAM DDR5 para equipos recientes', 'Componentes', 6400.00, 5, 5, 'ACTIVE'),
  ('SW-UBI-USW-LITE-8', 'Ubiquiti UniFi Switch Lite 8', 'Switch administrable para red pequena', 'Redes', 7200.00, 7, 3, 'ACTIVE'),
  ('RTR-MKT-HAP-AX2', 'MikroTik hAP ax2', 'Router Wi-Fi 6 compacto para oficinas', 'Redes', 5800.00, 0, 2, 'ACTIVE'),
  ('AP-UBI-U6-LITE', 'Ubiquiti UniFi U6 Lite', 'Access point Wi-Fi 6 para interiores', 'Redes', 6900.00, 13, 5, 'ACTIVE'),
  ('UPS-APC-BV650', 'APC BV650', 'UPS compacto para estaciones de trabajo', 'Energia', 4100.00, 6, 6, 'ACTIVE'),
  ('UPS-CDP-RUPR758', 'CDP R-UPR758', 'UPS regulado para equipos criticos', 'Energia', 3650.00, 19, 7, 'ACTIVE'),
  ('PRN-HP-LJ-M404', 'HP LaserJet Pro M404', 'Impresora laser monocromatica para oficina', 'Impresoras', 24800.00, 2, 2, 'ACTIVE'),
  ('TON-HP-58A', 'HP 58A Toner', 'Toner original para impresoras HP LaserJet', 'Consumibles', 5100.00, 0, 6, 'ACTIVE'),
  ('PAPER-A4-500', 'Resma Papel A4 500 hojas', 'Papel bond A4 para impresion diaria', 'Consumibles', 420.00, 85, 30, 'ACTIVE'),
  ('CAM-LOGI-C920', 'Logitech C920', 'Camara web Full HD para videollamadas', 'Perifericos', 5600.00, 0, 4, 'INACTIVE'),
  ('TAB-SAM-A8', 'Samsung Galaxy Tab A8', 'Tableta Android para consulta movil', 'Tablets', 15400.00, 3, 6, 'INACTIVE');

INSERT INTO products (
  sku,
  name,
  description,
  category,
  price,
  current_stock,
  minimum_stock,
  status,
  created_at,
  updated_at
)
SELECT
  sku,
  name,
  description,
  category,
  price,
  current_stock,
  minimum_stock,
  status,
  CURRENT_TIMESTAMP - INTERVAL '12 days',
  CURRENT_TIMESTAMP - INTERVAL '1 day'
FROM seed_demo_products
ON CONFLICT (sku) DO NOTHING;

CREATE TEMP TABLE seed_demo_movements (
  sku TEXT NOT NULL,
  username TEXT NOT NULL,
  movement_type TEXT NOT NULL,
  previous_quantity INTEGER NOT NULL,
  new_quantity INTEGER NOT NULL,
  delta_quantity INTEGER NOT NULL,
  observations TEXT,
  created_at TIMESTAMPTZ NOT NULL
) ON COMMIT DROP;

INSERT INTO seed_demo_movements (
  sku,
  username,
  movement_type,
  previous_quantity,
  new_quantity,
  delta_quantity,
  observations,
  created_at
) VALUES
  ('MON-DELL-P2422H', 'carlos', 'INITIAL', 0, 20, 20, 'Carga inicial de monitores Dell', CURRENT_TIMESTAMP - INTERVAL '11 days'),
  ('MON-DELL-P2422H', 'edwin', 'EXIT', 20, 16, -4, 'Asignacion a nuevas estaciones de ventas', CURRENT_TIMESTAMP - INTERVAL '5 days'),
  ('MON-DELL-P2422H', 'edwin', 'ENTRY', 16, 18, 2, 'Reposicion parcial de proveedor local', CURRENT_TIMESTAMP - INTERVAL '2 days'),
  ('MON-LG-27QN600', 'carlos', 'INITIAL', 0, 8, 8, 'Carga inicial de monitores QHD', CURRENT_TIMESTAMP - INTERVAL '10 days'),
  ('MON-LG-27QN600', 'edwin', 'EXIT', 8, 4, -4, 'Instalacion para equipo de diseno', CURRENT_TIMESTAMP - INTERVAL '3 days'),
  ('MON-SAM-ODYSSEY-G5', 'carlos', 'INITIAL', 0, 3, 3, 'Carga inicial de monitores graficos', CURRENT_TIMESTAMP - INTERVAL '9 days'),
  ('MON-SAM-ODYSSEY-G5', 'edwin', 'EXIT', 3, 0, -3, 'Entrega a laboratorio multimedia', CURRENT_TIMESTAMP - INTERVAL '1 day'),
  ('MOU-LOGI-MX-MASTER-3S', 'carlos', 'INITIAL', 0, 30, 30, 'Carga inicial de mouse premium', CURRENT_TIMESTAMP - INTERVAL '11 days'),
  ('MOU-LOGI-MX-MASTER-3S', 'edwin', 'EXIT', 30, 24, -6, 'Entrega a gerencia y compras', CURRENT_TIMESTAMP - INTERVAL '6 days'),
  ('MOU-LOGI-MX-MASTER-3S', 'edwin', 'ADJUSTMENT', 24, 26, 2, 'Ajuste por inventario fisico', CURRENT_TIMESTAMP - INTERVAL '2 hours'),
  ('KEY-LOGI-MX-KEYS', 'carlos', 'INITIAL', 0, 12, 12, 'Carga inicial de teclados', CURRENT_TIMESTAMP - INTERVAL '11 days'),
  ('KEY-LOGI-MX-KEYS', 'edwin', 'EXIT', 12, 11, -1, 'Reemplazo por falla de teclado anterior', CURRENT_TIMESTAMP - INTERVAL '8 hours'),
  ('HEAD-JABRA-EVOLVE2-65', 'carlos', 'INITIAL', 0, 6, 6, 'Carga inicial de audifonos corporativos', CURRENT_TIMESTAMP - INTERVAL '8 days'),
  ('HEAD-JABRA-EVOLVE2-65', 'edwin', 'EXIT', 6, 3, -3, 'Asignacion a call center', CURRENT_TIMESTAMP - INTERVAL '2 days'),
  ('DOCK-DELL-WD19S', 'carlos', 'INITIAL', 0, 5, 5, 'Carga inicial de docks Dell', CURRENT_TIMESTAMP - INTERVAL '10 days'),
  ('DOCK-DELL-WD19S', 'edwin', 'EXIT', 5, 1, -4, 'Asignacion a puestos hibridos', CURRENT_TIMESTAMP - INTERVAL '7 hours'),
  ('ADP-LEN-USB-C-65W', 'carlos', 'INITIAL', 0, 35, 35, 'Carga inicial de adaptadores USB-C', CURRENT_TIMESTAMP - INTERVAL '10 days'),
  ('ADP-LEN-USB-C-65W', 'edwin', 'EXIT', 35, 32, -3, 'Reemplazos por perdida de cargadores', CURRENT_TIMESTAMP - INTERVAL '4 days'),
  ('CAB-HDMI-2M', 'carlos', 'INITIAL', 0, 20, 20, 'Carga inicial de cables HDMI', CURRENT_TIMESTAMP - INTERVAL '7 days'),
  ('CAB-HDMI-2M', 'edwin', 'EXIT', 20, 0, -20, 'Instalacion masiva de salas', CURRENT_TIMESTAMP - INTERVAL '1 hour'),
  ('SSD-SAM-980-1TB', 'carlos', 'INITIAL', 0, 18, 18, 'Carga inicial de SSD 1TB', CURRENT_TIMESTAMP - INTERVAL '9 days'),
  ('SSD-SAM-980-1TB', 'edwin', 'EXIT', 18, 12, -6, 'Upgrades de laptops de desarrollo', CURRENT_TIMESTAMP - INTERVAL '4 days'),
  ('SSD-SAM-980-1TB', 'edwin', 'ENTRY', 12, 14, 2, 'Reposicion por orden de compra', CURRENT_TIMESTAMP - INTERVAL '18 hours'),
  ('SSD-KING-NV2-500', 'carlos', 'INITIAL', 0, 10, 10, 'Carga inicial de SSD 500GB', CURRENT_TIMESTAMP - INTERVAL '9 days'),
  ('SSD-KING-NV2-500', 'edwin', 'EXIT', 10, 2, -8, 'Actualizacion de equipos administrativos', CURRENT_TIMESTAMP - INTERVAL '3 hours'),
  ('HDD-WD-BLUE-2TB', 'carlos', 'INITIAL', 0, 9, 9, 'Carga inicial de discos de respaldo', CURRENT_TIMESTAMP - INTERVAL '8 days'),
  ('RAM-KING-16GB-DDR4', 'carlos', 'INITIAL', 0, 24, 24, 'Carga inicial de memoria DDR4', CURRENT_TIMESTAMP - INTERVAL '8 days'),
  ('RAM-KING-16GB-DDR4', 'edwin', 'EXIT', 24, 21, -3, 'Ampliacion de equipos de soporte', CURRENT_TIMESTAMP - INTERVAL '2 days'),
  ('RAM-CRUCIAL-32GB-DDR5', 'carlos', 'INITIAL', 0, 8, 8, 'Carga inicial de memoria DDR5', CURRENT_TIMESTAMP - INTERVAL '8 days'),
  ('RAM-CRUCIAL-32GB-DDR5', 'edwin', 'EXIT', 8, 5, -3, 'Actualizacion de estaciones nuevas', CURRENT_TIMESTAMP - INTERVAL '5 hours'),
  ('SW-UBI-USW-LITE-8', 'carlos', 'INITIAL', 0, 8, 8, 'Carga inicial de switches UniFi', CURRENT_TIMESTAMP - INTERVAL '7 days'),
  ('SW-UBI-USW-LITE-8', 'edwin', 'EXIT', 8, 7, -1, 'Instalacion en oficina secundaria', CURRENT_TIMESTAMP - INTERVAL '1 day'),
  ('RTR-MKT-HAP-AX2', 'carlos', 'INITIAL', 0, 2, 2, 'Carga inicial de routers MikroTik', CURRENT_TIMESTAMP - INTERVAL '7 days'),
  ('RTR-MKT-HAP-AX2', 'edwin', 'EXIT', 2, 0, -2, 'Salida para sucursal temporal', CURRENT_TIMESTAMP - INTERVAL '12 hours'),
  ('AP-UBI-U6-LITE', 'carlos', 'INITIAL', 0, 14, 14, 'Carga inicial de access points', CURRENT_TIMESTAMP - INTERVAL '7 days'),
  ('AP-UBI-U6-LITE', 'edwin', 'EXIT', 14, 13, -1, 'Expansion de cobertura Wi-Fi', CURRENT_TIMESTAMP - INTERVAL '4 hours'),
  ('UPS-APC-BV650', 'carlos', 'INITIAL', 0, 8, 8, 'Carga inicial de UPS APC', CURRENT_TIMESTAMP - INTERVAL '6 days'),
  ('UPS-APC-BV650', 'edwin', 'EXIT', 8, 6, -2, 'Proteccion de estaciones criticas', CURRENT_TIMESTAMP - INTERVAL '2 days'),
  ('UPS-CDP-RUPR758', 'carlos', 'INITIAL', 0, 20, 20, 'Carga inicial de UPS CDP', CURRENT_TIMESTAMP - INTERVAL '6 days'),
  ('UPS-CDP-RUPR758', 'edwin', 'EXIT', 20, 19, -1, 'Reemplazo preventivo', CURRENT_TIMESTAMP - INTERVAL '9 hours'),
  ('PRN-HP-LJ-M404', 'carlos', 'INITIAL', 0, 4, 4, 'Carga inicial de impresoras HP', CURRENT_TIMESTAMP - INTERVAL '5 days'),
  ('PRN-HP-LJ-M404', 'edwin', 'EXIT', 4, 2, -2, 'Entrega a contabilidad y archivo', CURRENT_TIMESTAMP - INTERVAL '2 days'),
  ('TON-HP-58A', 'carlos', 'INITIAL', 0, 12, 12, 'Carga inicial de toner HP', CURRENT_TIMESTAMP - INTERVAL '5 days'),
  ('TON-HP-58A', 'edwin', 'EXIT', 12, 0, -12, 'Consumo por cierre mensual', CURRENT_TIMESTAMP - INTERVAL '30 minutes'),
  ('PAPER-A4-500', 'carlos', 'INITIAL', 0, 90, 90, 'Carga inicial de papel A4', CURRENT_TIMESTAMP - INTERVAL '5 days'),
  ('PAPER-A4-500', 'edwin', 'EXIT', 90, 85, -5, 'Consumo semanal administrativo', CURRENT_TIMESTAMP - INTERVAL '6 hours'),
  ('CAM-LOGI-C920', 'carlos', 'INITIAL', 0, 0, 0, 'Producto inactivo sin stock disponible', CURRENT_TIMESTAMP - INTERVAL '4 days'),
  ('TAB-SAM-A8', 'carlos', 'INITIAL', 0, 5, 5, 'Carga inicial de tabletas', CURRENT_TIMESTAMP - INTERVAL '4 days'),
  ('TAB-SAM-A8', 'edwin', 'EXIT', 5, 3, -2, 'Baja operativa de tabletas demo', CURRENT_TIMESTAMP - INTERVAL '1 day');

INSERT INTO stock_movements (
  product_id,
  user_id,
  movement_type,
  previous_quantity,
  new_quantity,
  delta_quantity,
  observations,
  created_at
)
SELECT
  p.id,
  u.id,
  m.movement_type,
  m.previous_quantity,
  m.new_quantity,
  m.delta_quantity,
  m.observations,
  m.created_at
FROM seed_demo_movements m
JOIN products p ON p.sku = m.sku
JOIN inventory_users u ON u.username = m.username;

INSERT INTO audit_log (table_name, record_id, action, actor_user_id, new_values, correlation_id, event_at)
SELECT
  'products',
  p.id::TEXT,
  'INSERT',
  u.id,
  jsonb_build_object(
    'sku', p.sku,
    'name', p.name,
    'category', p.category,
    'currentStock', p.current_stock,
    'minimumStock', p.minimum_stock,
    'status', p.status
  ),
  'seed-006-demo-products',
  p.created_at
FROM seed_demo_products s
JOIN products p ON p.sku = s.sku
JOIN inventory_users u ON u.username = 'carlos';

INSERT INTO audit_log (table_name, record_id, action, actor_user_id, new_values, correlation_id, event_at)
SELECT
  'stock_movements',
  m.id::TEXT,
  'INSERT',
  m.user_id,
  jsonb_build_object(
    'productId', m.product_id,
    'movementType', m.movement_type,
    'previousQuantity', m.previous_quantity,
    'newQuantity', m.new_quantity,
    'deltaQuantity', m.delta_quantity
  ),
  'seed-006-demo-stock',
  m.created_at
FROM stock_movements m
JOIN products p ON p.id = m.product_id
JOIN seed_demo_products s ON s.sku = p.sku;

CREATE TEMP TABLE seed_demo_revision (
  id INTEGER PRIMARY KEY
) ON COMMIT DROP;

WITH created_revision AS (
  INSERT INTO audit_revisions (revision_timestamp, username)
  VALUES ((EXTRACT(EPOCH FROM CURRENT_TIMESTAMP) * 1000)::BIGINT, 'seed-demo')
  RETURNING id
)
INSERT INTO seed_demo_revision (id)
SELECT id
FROM created_revision;

INSERT INTO products_aud (
  id,
  rev,
  rev_type,
  sku,
  name,
  description,
  category,
  price,
  current_stock,
  minimum_stock,
  status,
  created_at,
  updated_at
)
SELECT
  p.id,
  r.id,
  0,
  p.sku,
  p.name,
  p.description,
  p.category,
  p.price,
  p.current_stock,
  p.minimum_stock,
  p.status,
  p.created_at,
  p.updated_at
FROM seed_demo_products s
JOIN products p ON p.sku = s.sku
CROSS JOIN seed_demo_revision r;

INSERT INTO stock_movements_aud (
  id,
  rev,
  rev_type,
  product_id,
  user_id,
  movement_type,
  previous_quantity,
  new_quantity,
  delta_quantity,
  observations,
  created_at
)
SELECT
  m.id,
  r.id,
  0,
  m.product_id,
  m.user_id,
  m.movement_type,
  m.previous_quantity,
  m.new_quantity,
  m.delta_quantity,
  m.observations,
  m.created_at
FROM stock_movements m
JOIN products p ON p.id = m.product_id
JOIN seed_demo_products s ON s.sku = p.sku
CROSS JOIN seed_demo_revision r;
