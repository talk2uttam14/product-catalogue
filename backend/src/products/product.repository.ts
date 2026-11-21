import type { ProductDTO } from './product.dto.js';

export interface ProductRepository {
  getAllProducts(): Promise<readonly ProductDTO[]>;
}
