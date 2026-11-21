import type { ProductDTO } from './product.dto.js';
import { CategoryNotFoundError, ProductNotFoundError } from './product.errors.js';
import type { ProductRepository } from './product.repository.js';

const FEATURED_PRODUCT_COUNT = 5;

export interface CategoryProductsDTO {
  readonly category: string;
  readonly featured: readonly ProductDTO[];
  readonly remaining: readonly ProductDTO[];
}

export class ProductService {
  constructor(private readonly repository: ProductRepository) {}

  async getFeaturedProducts(): Promise<readonly ProductDTO[]> {
    return sortByRating(await this.getUniqueProducts()).slice(0, FEATURED_PRODUCT_COUNT);
  }

  async getCategories(): Promise<readonly string[]> {
    const categories = new Set((await this.getUniqueProducts()).map((product) => product.category));
    return [...categories].sort(compareText);
  }

  async getCategoryProducts(categoryInput: string): Promise<CategoryProductsDTO> {
    const products = await this.getUniqueProducts();
    const canonicalCategory = products.find(
      (product) => product.category.toLowerCase() === categoryInput.toLowerCase(),
    )?.category;
    if (!canonicalCategory) throw new CategoryNotFoundError();

    const sorted = sortByRating(
      products.filter((product) => product.category === canonicalCategory),
    );
    return {
      category: canonicalCategory,
      featured: sorted.slice(0, FEATURED_PRODUCT_COUNT),
      remaining: sorted.slice(FEATURED_PRODUCT_COUNT),
    };
  }

  async searchProducts(queryInput: string): Promise<readonly ProductDTO[]> {
    const query = queryInput.trim().toLowerCase();
    return (await this.getUniqueProducts())
      .filter((product) =>
        [product.title, product.description, product.category]
          .some((field) => field.toLowerCase().includes(query)),
      )
      .sort((left, right) => compareText(left.id, right.id));
  }

  async getProductById(id: string): Promise<ProductDTO> {
    const product = (await this.getUniqueProducts()).find((item) => item.id === id);
    if (!product) throw new ProductNotFoundError();
    return product;
  }

  private async getUniqueProducts(): Promise<readonly ProductDTO[]> {
    const products = await this.repository.getAllProducts();
    const seenIds = new Set<string>();
    return products.filter((product) => {
      if (seenIds.has(product.id)) return false;
      seenIds.add(product.id);
      return true;
    });
  }
}

function sortByRating(products: readonly ProductDTO[]): ProductDTO[] {
  return [...products].sort((left, right) =>
    right.rating.rate - left.rating.rate
    || right.rating.count - left.rating.count
    || compareText(left.id, right.id),
  );
}

function compareText(left: string, right: string): number {
  return left < right ? -1 : left > right ? 1 : 0;
}
