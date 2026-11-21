import type { ProductDTO } from '../products/product.dto.js';
import type { EnquiryDTO } from './enquiry.dto.js';

export interface EnquiryEmail {
  readonly enquiry: EnquiryDTO;
  readonly product: ProductDTO;
}

export interface EmailProvider {
  sendEnquiry(email: EnquiryEmail): Promise<void>;
}
