import request from 'supertest';
import { describe, expect, it, vi } from 'vitest';
import { createApp } from '../../src/app.js';
import type { AppConfig } from '../../src/config/env.js';
import type { ProductDTO } from '../../src/products/product.dto.js';
import { ProductSourceError } from '../../src/products/product.errors.js';
import { ProductService } from '../../src/products/product.service.js';
import { EnquiryService } from '../../src/enquiries/enquiry.service.js';

const config: AppConfig = {
  nodeEnv: 'test',
  host: '127.0.0.1',
  port: 3000,
  corsOrigins: [],
  jsonBodyLimit: '100kb',
  fakeStoreBaseUrl: 'https://fakestoreapi.com',
  productCacheTtlMs: 60_000,
  upstreamTimeoutMs: 5_000,
  smtpHost: '127.0.0.1',
  smtpPort: 1025,
  smtpSecure: false,
  smtpUsername: undefined,
  smtpPassword: undefined,
  emailFrom: 'catalogue@example.local',
  enquiryRecipient: 'enquiries@example.local',
};

function product(id: string, category = 'electronics'): ProductDTO {
  return {
    id,
    title: `Product ${id}`,
    description: `Description ${id}`,
    category,
    imageUrl: `https://images.example/${id}.jpg`,
    price: 12,
    rating: { rate: Number(id), count: 1 },
  };
}

function appFor(products: readonly ProductDTO[]) {
  const repository = { getAllProducts: vi.fn().mockResolvedValue(products) };
  return createApp(config, {
    productService: new ProductService(repository),
    enquiryService: new EnquiryService(repository, { sendEnquiry: vi.fn().mockResolvedValue(undefined) }),
  });
}

describe('product API', () => {
  it('serves featured products and category navigation under the approved versioned API path', async () => {
    const app = appFor([product('1'), product('2'), product('3', 'jewelery')]);

    const featured = await request(app).get('/api/v1/products/featured');
    const categories = await request(app).get('/api/v1/categories');

    expect(featured.status).toBe(200);
    expect(featured.body.data.map((item: ProductDTO) => item.id)).toEqual(['3', '2', '1']);
    expect(categories.body).toEqual({ data: ['electronics', 'jewelery'] });
  });

  it('serves category partitions and search results with contract envelopes', async () => {
    const app = appFor([product('1'), product('3'), product('2', 'bags')]);

    const category = await request(app).get('/api/v1/categories/electronics/products');
    const search = await request(app).get('/api/v1/products/search?q=%20DESCRIPTION%202%20');

    expect(category.body.data.featured.map((item: ProductDTO) => item.id)).toEqual(['3', '1']);
    expect(category.body.data.remaining).toEqual([]);
    expect(search.body).toMatchObject({ data: [{ id: '2' }], meta: { query: 'DESCRIPTION 2', count: 1 } });
  });

  it('returns product detail and common not-found responses', async () => {
    const app = appFor([product('1')]);

    expect((await request(app).get('/api/v1/products/1')).body.data).toMatchObject({ id: '1', imageUrl: 'https://images.example/1.jpg' });
    expect((await request(app).get('/api/v1/products/99')).status).toBe(404);
    expect((await request(app).get('/api/v1/categories/missing/products')).status).toBe(404);
  });

  it('rejects empty search and invalid product IDs', async () => {
    const app = appFor([product('1')]);

    expect((await request(app).get('/api/v1/products/search?q=%20%20')).status).toBe(400);
    expect((await request(app).get('/api/v1/products/search')).status).toBe(400);
    expect((await request(app).get('/api/v1/products/not-an-id')).status).toBe(400);
  });

  it('returns a generic upstream error response', async () => {
    const service = new ProductService({
      getAllProducts: vi.fn().mockRejectedValue(new ProductSourceError()),
    });
    const repository = { getAllProducts: vi.fn().mockRejectedValue(new ProductSourceError()) };
    const app = createApp(config, {
      productService: service,
      enquiryService: new EnquiryService(repository, { sendEnquiry: vi.fn() }),
    });

    const response = await request(app).get('/api/v1/categories');
    expect(response.status).toBe(502);
    expect(response.body.error.message).toBe('The product catalogue is temporarily unavailable.');
    expect(JSON.stringify(response.body)).not.toContain('fakestoreapi');
  });
});
