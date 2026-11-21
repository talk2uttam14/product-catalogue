import { describe, expect, it, vi } from 'vitest';
import { FakeStoreProductRepository } from '../../src/products/fake-store-product.repository.js';
import { ProductSourceError } from '../../src/products/product.errors.js';

const fakeStorePayload = [
  {
    id: 12,
    title: 'Test product',
    description: 'A product for testing',
    category: 'electronics',
    image: 'https://images.example/test.jpg',
    price: 19.99,
    rating: { rate: 4.5, count: 12 },
  },
];

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
}

describe('FakeStoreProductRepository', () => {
  it('maps upstream fields into normalized product DTOs', async () => {
    const fetchProducts = vi.fn(async () => jsonResponse(fakeStorePayload));
    const repository = new FakeStoreProductRepository('https://fakestoreapi.com', 1000, 500, fetchProducts);

    await expect(repository.getAllProducts()).resolves.toEqual([{
      id: '12',
      title: 'Test product',
      description: 'A product for testing',
      category: 'electronics',
      imageUrl: 'https://images.example/test.jpg',
      price: 19.99,
      rating: { rate: 4.5, count: 12 },
    }]);
    expect(fetchProducts).toHaveBeenCalledWith('https://fakestoreapi.com/products', expect.objectContaining({
      signal: expect.any(AbortSignal),
    }));
  });

  it('reuses cached products until the TTL expires, then reloads', async () => {
    let now = 100;
    const fetchProducts = vi.fn(async () => jsonResponse(fakeStorePayload));
    const repository = new FakeStoreProductRepository(
      'https://fakestoreapi.com', 500, 500, fetchProducts, () => now,
    );

    await repository.getAllProducts();
    await repository.getAllProducts();
    expect(fetchProducts).toHaveBeenCalledTimes(1);

    now = 601;
    await repository.getAllProducts();
    expect(fetchProducts).toHaveBeenCalledTimes(2);
  });

  it.each([
    ['network failure', async () => { throw new Error('private network detail'); }],
    ['non-success response', async () => jsonResponse({ error: 'private response' }, 503)],
    ['invalid upstream payload', async () => jsonResponse([{ id: 'bad', title: 'invalid' }])],
  ])('normalizes %s to a source error', async (_caseName, fetcher) => {
    const repository = new FakeStoreProductRepository(
      'https://fakestoreapi.com', 1000, 500, fetcher as typeof fetch,
    );
    await expect(repository.getAllProducts()).rejects.toBeInstanceOf(ProductSourceError);
  });

  it('normalizes request timeouts to a source error', async () => {
    const fetchProducts: typeof fetch = async (_input, init) => new Promise((_resolve, reject) => {
      init?.signal?.addEventListener('abort', () => reject(init.signal?.reason), { once: true });
    });
    const repository = new FakeStoreProductRepository('https://fakestoreapi.com', 1000, 10, fetchProducts);

    await expect(repository.getAllProducts()).rejects.toBeInstanceOf(ProductSourceError);
  });
});
