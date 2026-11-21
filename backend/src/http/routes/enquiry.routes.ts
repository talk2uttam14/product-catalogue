import { Router } from 'express';
import { enquiryRequestSchema } from '../../enquiries/enquiry.dto.js';
import type { EnquiryService } from '../../enquiries/enquiry.service.js';

export function createEnquiryRoutes(enquiryService: EnquiryService): Router {
  const router = Router();

  router.post('/enquiries', (request, response, next) => {
    const parsed = enquiryRequestSchema.safeParse(request.body);
    if (!parsed.success) {
      next(parsed.error);
      return;
    }

    void enquiryService.submit(parsed.data)
      .then(() => response.status(201).json({ data: { status: 'sent' } }))
      .catch(next);
  });

  return router;
}
