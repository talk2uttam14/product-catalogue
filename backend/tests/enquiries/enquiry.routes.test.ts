import request from 'supertest';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { createApp } from '../../src/app.js';
import type { AppConfig } from '../../src/config/env.js';
import { EnquiryService } from '../../src/enquiries/enquiry.service.js';
import type { EmailProvider } from '../../src/enquiries/email-provider.js';
import type { ProductDTO } from '../../src/products/product.dto.js';
import type { ProductRepository } from '../../src/products/product.repository.js';
import { ProductService } from '../../src/products/product.service.js';

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

const product: ProductDTO = {
  id: '1',
  title: 'Example product',
  description: 'Example description',
  category: 'electronics',
  imageUrl: 'https://example.test/image.jpg',
  price: 10,
  rating: { rate: 4, count: 5 },
};

function appFor(products: readonly ProductDTO[], emailProvider: EmailProvider) {
  const repository: ProductRepository = { getAllProducts: vi.fn().mockResolvedValue(products) };
  return createApp(config, {
    productService: new ProductService(repository),
    enquiryService: new EnquiryService(repository, emailProvider),
  });
}

afterEach(() => vi.restoreAllMocks());

describe('POST /api/v1/enquiries', () => {
  it('normalizes valid contact details and returns 201 after provider acceptance', async () => {
    const emailProvider: EmailProvider = { sendEnquiry: vi.fn().mockResolvedValue(undefined) };
    const response = await request(appFor([product], emailProvider))
      .post('/api/v1/enquiries')
      .send({
        productId: 1,
        name: '  John Doe  ',
        email: ' JOHN@EXAMPLE.COM ',
        phone: '+91 98765-43210',
        message: '  I would like to know more about this product.  ',
      });

    expect(response.status).toBe(201);
    expect(response.body).toEqual({ data: { status: 'sent' } });
    expect(emailProvider.sendEnquiry).toHaveBeenCalledWith(expect.objectContaining({
      enquiry: {
        productId: 1,
        name: 'John Doe',
        email: 'john@example.com',
        phone: '+919876543210',
        message: 'I would like to know more about this product.',
      },
      product,
    }));
  });

  it('allows the optional phone field to be omitted', async () => {
    const emailProvider: EmailProvider = { sendEnquiry: vi.fn().mockResolvedValue(undefined) };
    const response = await request(appFor([product], emailProvider))
      .post('/api/v1/enquiries')
      .send({ productId: 1, name: 'John Doe', email: 'john@example.com', message: 'Hello' });

    expect(response.status).toBe(201);
    expect(emailProvider.sendEnquiry).toHaveBeenCalled();
  });

  it('rejects invalid email, missing fields, invalid phone, and invalid product IDs', async () => {
    const emailProvider: EmailProvider = { sendEnquiry: vi.fn().mockResolvedValue(undefined) };
    const app = appFor([product], emailProvider);
    const valid = {
      productId: 1,
      name: 'John Doe',
      email: 'john@example.com',
      phone: '+919876543210',
      message: 'Please contact me.',
    };

    const invalidEmail = await request(app).post('/api/v1/enquiries').send({ ...valid, email: 'invalid' });
    const missingFields = await request(app).post('/api/v1/enquiries').send({ productId: 1 });
    const invalidPhone = await request(app).post('/api/v1/enquiries').send({ ...valid, phone: '9876543210' });
    const invalidProductId = await request(app).post('/api/v1/enquiries').send({ ...valid, productId: 1.5 });

    for (const response of [invalidEmail, missingFields, invalidPhone, invalidProductId]) {
      expect(response.status).toBe(400);
      expect(response.body.error.code).toBe('VALIDATION_ERROR');
    }
    expect(emailProvider.sendEnquiry).not.toHaveBeenCalled();
  });

  it('returns PRODUCT_NOT_FOUND and does not send email when product is missing', async () => {
    const emailProvider: EmailProvider = { sendEnquiry: vi.fn().mockResolvedValue(undefined) };
    const response = await request(appFor([], emailProvider))
      .post('/api/v1/enquiries')
      .send({ productId: 1, name: 'John Doe', email: 'john@example.com', message: 'Hello' });

    expect(response.status).toBe(404);
    expect(response.body.error.code).toBe('PRODUCT_NOT_FOUND');
    expect(emailProvider.sendEnquiry).not.toHaveBeenCalled();
  });

  it('returns a generic provider failure without disclosing SMTP details', async () => {
    vi.spyOn(console, 'error').mockImplementation(() => undefined);
    const emailProvider: EmailProvider = {
      sendEnquiry: vi.fn().mockRejectedValue(new Error('smtp secret.internal credentials')),
    };
    const response = await request(appFor([product], emailProvider))
      .post('/api/v1/enquiries')
      .send({ productId: 1, name: 'John Doe', email: 'john@example.com', message: 'Hello' });

    expect(response.status).toBe(502);
    expect(response.body).toEqual({
      error: {
        code: 'EMAIL_DELIVERY_FAILED',
        message: 'Unable to send the enquiry at this time.',
        details: [],
      },
    });
    expect(JSON.stringify(response.body)).not.toContain('secret.internal');
  });
});
