import type { ProductRepository } from '../products/product.repository.js';
import { ProductNotFoundError } from '../products/product.errors.js';
import type { EnquiryDTO } from './enquiry.dto.js';
import type { EmailProvider } from './email-provider.js';
import { EmailDeliveryError } from './enquiry.errors.js';

export class EnquiryService {
  constructor(
    private readonly productRepository: ProductRepository,
    private readonly emailProvider: EmailProvider,
  ) {}

  async submit(enquiry: EnquiryDTO): Promise<void> {
    const product = (await this.productRepository.getAllProducts())
      .find((item) => item.id === String(enquiry.productId));
    if (!product) throw new ProductNotFoundError();

    try {
      await this.emailProvider.sendEnquiry({ enquiry, product });
    } catch {
      // Avoid logging the error object: SMTP failures can contain addresses and server details.
      console.error('Enquiry email delivery failed.');
      throw new EmailDeliveryError();
    }
  }
}
