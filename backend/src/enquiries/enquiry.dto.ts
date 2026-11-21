import { z } from 'zod';

const internationalPhonePattern = /^\+[1-9]\d{7,14}$/;

const phoneSchema = z
  .string()
  .trim()
  .max(30)
  .optional()
  .transform((phone) => {
    if (phone === undefined) return undefined;
    const normalized = phone.replace(/[\s().-]/g, '');
    return normalized.length > 0 ? normalized : undefined;
  })
  .refine((phone) => phone === undefined || internationalPhonePattern.test(phone), {
    message: 'Phone must be an international number in E.164 format.',
  });

export const enquiryRequestSchema = z.object({
  productId: z.number().int().positive().safe(),
  name: z.string().trim().min(1).max(100),
  email: z.string().trim().toLowerCase().email().max(254),
  phone: phoneSchema,
  message: z.string().trim().min(1).max(2_000),
});

export type EnquiryDTO = z.infer<typeof enquiryRequestSchema>;
