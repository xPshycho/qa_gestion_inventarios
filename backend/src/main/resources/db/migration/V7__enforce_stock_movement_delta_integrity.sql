ALTER TABLE stock_movements
  ADD CONSTRAINT chk_stock_movements_delta_quantity
  CHECK (delta_quantity = new_quantity - previous_quantity);
