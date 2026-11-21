import type { AppConfig } from '../config/env.js';
import { FakeStoreProductRepository } from '../products/fake-store-product.repository.js';
import { ProductService } from '../products/product.service.js';
import { EnquiryService } from '../enquiries/enquiry.service.js';
import { NodemailerEmailProvider } from '../infrastructure/email/nodemailer-email.provider.js';

export interface AppDependencies {
  readonly productService: ProductService;
  readonly enquiryService: EnquiryService;
}

export function createDependencies(config: AppConfig): AppDependencies {
  const productRepository = new FakeStoreProductRepository(
    config.fakeStoreBaseUrl,
    config.productCacheTtlMs,
    config.upstreamTimeoutMs,
  );
  const emailProvider = new NodemailerEmailProvider(config);
  return {
    productService: new ProductService(productRepository),
    enquiryService: new EnquiryService(productRepository, emailProvider),
  };
}
