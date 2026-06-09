export type ProductStatus = 'ACTIVE' | 'INACTIVE';
export type SortDirection = 'asc' | 'desc';

export type SortField =
  | 'id'
  | 'sku'
  | 'name'
  | 'category'
  | 'price'
  | 'currentStock'
  | 'minimumStock'
  | 'status'
  | 'updatedAt';

export interface Product {
  id: number;
  sku: string;
  name: string;
  description: string | null;
  category: string;
  price: number;
  currentStock: number;
  minimumStock: number;
  status: ProductStatus;
  createdAt: string;
  updatedAt: string;
}

export interface ProductPage {
  content: Product[];
  page: number;
  size: number;
  totalElements: number;
  totalPages: number;
}

export interface ProductQuery {
  page: number;
  size: number;
  search: string;
  category: string;
  status: ProductStatus | '';
  sort: SortField;
  direction: SortDirection;
}
