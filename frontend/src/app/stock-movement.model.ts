export type StockMovementType = 'INITIAL' | 'ENTRY' | 'EXIT' | 'ADJUSTMENT';
export type StockOperationType = 'ENTRY' | 'EXIT' | 'ADJUSTMENT';

export interface StockMovement {
  id: number;
  productId: number;
  productSku: string;
  productName: string;
  userId: number | null;
  username: string | null;
  userDisplayName: string | null;
  movementType: StockMovementType;
  previousQuantity: number;
  newQuantity: number;
  deltaQuantity: number;
  observations: string | null;
  stockAlert: boolean;
  createdAt: string;
}

export interface StockMovementRequest {
  quantity: number;
  observations: string | null;
}

export interface StockAdjustmentRequest {
  newQuantity: number;
  observations: string | null;
}
