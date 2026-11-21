import { afterEach, describe, expect, it, vi } from 'vitest';
import type { ProductDTO } from '../../src/products/product.dto.js';
import { ProductNotFoundError } from '../../src/products/product.errors.js';
import type { ProductRepository } from '../../src/products/product.repository.js';
import type { EmailProvider } from '../../src/enquiries/email-provider.js';
import { EnquiryService } from '../../src/enquiries/enquiry.service.js';
import { EmailDeliveryError } from '../../src/enquiries/enquiry.errors.js';
import { enquiryRequestSchema } from '../../src/enquiries/enquiry.dto.js';

const product: ProductDTO = {
  id: '1',
  title: 'Example product',
  description: 'Example description',
  category: 'electronics',
  imageUrl: 'https://example.test/image.jpg',
  price: 10,
  rating: { rate: 4, count: 5 },
};

const enquiry = enquiryRequestSchema.parse({
  productId: 1,
  name: 'John Doe',
  email: 'john@example.com',
  phone: '+919876543210',
  message: 'I would like to know more about this product.',
});

afterEach(() => vi.restoreAllMocks());

describe('EnquiryService', () => {
  it('verifies the product and sends a normalized enquiry to the provider', async () => {
    const repository: ProductRepository = { getAllProducts: vi.fn().mockResolvedValue([product]) };
    const emailProvider: EmailProvider = { sendEnquiry: vi.fn().mockResolvedValue(undefined) };
    const service = new EnquiryService(repository, emailProvider);

    await expect(service.submit(enquiry)).resolves.toBeUndefined();
    expect(emailProvider.sendEnquiry).toHaveBeenCalledWith({ enquiry, product });
  });

  it('does not send email when the product does not exist', async () => {
    const repository: ProductRepository = { getAllProducts: vi.fn().mockResolvedValue([]) };
    const emailProvider: EmailProvider = { sendEnquiry: vi.fn().mockResolvedValue(undefined) };

    await expect(new EnquiryService(repository, emailProvider).submit(enquiry))
      .rejects.toBeInstanceOf(ProductNotFoundError);
    expect(emailProvider.sendEnquiry).not.toHaveBeenCalled();
  });

  it('converts provider failures into a safe delivery error', async () => {
    const repository: ProductRepository = { getAllProducts: vi.fn().mockResolvedValue([product]) };
    const emailProvider: EmailProvider = {
      sendEnquiry: vi.fn().mockRejectedValue(new Error('smtp private host and credentials')),
    };
    const errorLog = vi.spyOn(console, 'error').mockImplementation(() => undefined);

    await expect(new EnquiryService(repository, emailProvider).submit(enquiry))
      .rejects.toBeInstanceOf(EmailDeliveryError);
    expect(errorLog).toHaveBeenCalledWith('Enquiry email delivery failed.');
    expect(errorLog).not.toHaveBeenCalledWith(expect.stringContaining('credentials'));
  });
});
