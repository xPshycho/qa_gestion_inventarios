ALTER TABLE products
  ADD COLUMN archived BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE products_aud
  ADD COLUMN archived BOOLEAN;

CREATE INDEX idx_products_archived_status
  ON products (archived, status);
