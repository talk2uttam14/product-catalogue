import { z } from 'zod';
import type { ProductDTO } from './product.dto.js';
import type { ProductRepository } from './product.repository.js';
import { ProductSourceError } from './product.errors.js';

const fakeStoreProductSchema = z.object({
  id: z.union([z.number().int().positive(), z.string().regex(/^\d+$/)]),
  title: z.string().min(1),
  description: z.string(),
  category: z.string().min(1),
  image: z.string().url(),
  price: z.number().finite().nonnegative(),
  rating: z.object({
    rate: z.number().finite().min(0),
    count: z.number().int().nonnegative(),
  }),
});

const fakeStoreProductsSchema = z.array(fakeStoreProductSchema);

interface CacheEntry {
  readonly expiresAt: number;
  readonly products: readonly ProductDTO[];
}

export class FakeStoreProductRepository implements ProductRepository {
  private cache: CacheEntry | undefined;
  private inFlight: Promise<readonly ProductDTO[]> | undefined;

  constructor(
    private readonly baseUrl: string,
    private readonly cacheTtlMs: number,
    private readonly timeoutMs: number,
    private readonly fetchProducts: typeof fetch = fetch,
    private readonly now: () => number = Date.now,
  ) {}

  async getAllProducts(): Promise<readonly ProductDTO[]> {
    if (this.cache && this.cache.expiresAt > this.now()) return this.cache.products;
    if (this.inFlight) return this.inFlight;

    const request = this.loadProducts();
    this.inFlight = request;
    try {
      return await request;
    } finally {
      if (this.inFlight === request) this.inFlight = undefined;
    }
  }

  private async loadProducts(): Promise<readonly ProductDTO[]> {
    try {
      const response = await this.fetchProducts(`${this.baseUrl}/products`, {
        signal: AbortSignal.timeout(this.timeoutMs),
        headers: { accept: 'application/json' },
      });
      if (!response.ok) throw new ProductSourceError();

      const payload: unknown = await response.json();
      const parsed = fakeStoreProductsSchema.safeParse(payload);
      if (!parsed.success) throw new ProductSourceError();

      const products = parsed.data.map(toProductDTO);
      this.cache = { products, expiresAt: this.now() + this.cacheTtlMs };
      return products;
    } catch {
      // Keep network, timeout, HTTP, and upstream decoding details inside this adapter.
      throw new ProductSourceError();
    }
  }
}

function toProductDTO(product: z.infer<typeof fakeStoreProductSchema>): ProductDTO {
  return {
    id: String(product.id),
    title: product.title,
    description: product.description,
    category: product.category,
    imageUrl: product.image,
    price: product.price,
    rating: {
      rate: product.rating.rate,
      count: product.rating.count,
    },
  };
}
