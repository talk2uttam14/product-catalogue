import { describe, expect, it, vi } from 'vitest';
import type { ProductDTO } from '../../src/products/product.dto.js';
import { ProductNotFoundError, ProductSourceError } from '../../src/products/product.errors.js';
import type { ProductRepository } from '../../src/products/product.repository.js';
import { ProductService } from '../../src/products/product.service.js';

function product(
  id: string,
  rating: number,
  count: number,
  category = 'electronics',
  title = `Product ${id}`,
  description = `Description ${id}`,
): ProductDTO {
  return {
    id,
    title,
    description,
    category,
    imageUrl: `https://images.example/${id}.jpg`,
    price: 10,
    rating: { rate: rating, count },
  };
}

function serviceWith(products: readonly ProductDTO[]): ProductService {
  const repository: ProductRepository = { getAllProducts: vi.fn().mockResolvedValue(products) };
  return new ProductService(repository);
}

describe('ProductService', () => {
  it('selects five featured products using rating, count, then ascending ID', async () => {
    const service = serviceWith([
      product('5', 5, 10),
      product('3', 5, 20),
      product('2', 5, 20),
      product('1', 4.9, 100),
      product('4', 4, 1),
      product('6', 3, 1),
    ]);

    expect((await service.getFeaturedProducts()).map(({ id }) => id)).toEqual(['2', '3', '5', '1', '4']);
  });

  it('returns sorted category partitions without duplicate IDs', async () => {
    const products = [
      product('7', 2, 1), product('6', 3, 1), product('5', 4, 1),
      product('4', 4, 2), product('3', 5, 1), product('2', 5, 2),
      product('1', 5, 2), product('1', 1, 0),
      product('8', 5, 10, 'jewelery'),
    ];
    const result = await serviceWith(products).getCategoryProducts('ELECTRONICS');

    expect(result.category).toBe('electronics');
    expect(result.featured.map(({ id }) => id)).toEqual(['1', '2', '3', '4', '5']);
    expect(result.remaining.map(({ id }) => id)).toEqual(['6', '7']);
    const allIds = [...result.featured, ...result.remaining].map(({ id }) => id);
    expect(new Set(allIds).size).toBe(allIds.length);
    expect(allIds.sort()).toEqual(['1', '2', '3', '4', '5', '6', '7']);
  });

  it('searches title, description, and category case-insensitively after trimming', async () => {
    const service = serviceWith([
      product('3', 1, 0, 'electronics', 'Other', 'contains widget'),
      product('2', 1, 0, 'WIDGETS', 'Other', 'nothing here'),
      product('1', 1, 0, 'electronics', 'Widget title', 'nothing here'),
      product('4', 1, 0, 'electronics', 'Other', 'unrelated'),
    ]);

    expect((await service.searchProducts('  WIDGET ')).map(({ id }) => id)).toEqual(['1', '2', '3']);
  });

  it('returns all available products when fewer than five exist', async () => {
    expect((await serviceWith([product('2', 1, 0), product('1', 2, 0)]).getFeaturedProducts()).length).toBe(2);
  });

  it('throws a not-found error for missing products', async () => {
    await expect(serviceWith([]).getProductById('99')).rejects.toBeInstanceOf(ProductNotFoundError);
  });

  it('propagates repository failures without depending on the data source', async () => {
    const repository: ProductRepository = {
      getAllProducts: vi.fn().mockRejectedValue(new ProductSourceError()),
    };
    await expect(new ProductService(repository).getCategories()).rejects.toBeInstanceOf(ProductSourceError);
  });
});
