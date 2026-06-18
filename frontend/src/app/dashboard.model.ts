export type StockMovementType = 'INITIAL' | 'ENTRY' | 'EXIT' | 'ADJUSTMENT';

export interface DashboardMetrics {
  totalProducts: number;
  activeProducts: number;
  inactiveProducts: number;
  criticalProducts: number;
  totalStockUnits: number;
  inventoryValue: number;
  totalMovements: number;
  initialMovements: number;
  entryMovements: number;
  exitMovements: number;
  adjustmentMovements: number;
}

export interface CriticalProduct {
  id: number;
  sku: string;
  name: string;
  category: string;
  currentStock: number;
  minimumStock: number;
  shortage: number;
  status: 'ACTIVE' | 'INACTIVE';
  updatedAt: string;
}

export interface TopMovedProduct {
  productId: number;
  productSku: string;
  productName: string;
  category: string;
  movementCount: number;
  totalMovedUnits: number;
  lastMovementAt: string;
}

export interface RecentStockMovement {
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

export interface DashboardResponse {
  metrics: DashboardMetrics;
  criticalProducts: CriticalProduct[];
  mostMovedProducts: TopMovedProduct[];
  recentMovements: RecentStockMovement[];
}
