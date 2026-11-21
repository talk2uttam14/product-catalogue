import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

const optionalCredential = z.preprocess(
  (value: unknown) => typeof value === 'string' && value.trim() === '' ? undefined : value,
  z.string().trim().min(1).optional(),
);

const environmentSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  HOST: z.string().trim().min(1).default('127.0.0.1'),
  PORT: z.coerce.number().int().min(1).max(65_535).default(3000),
  CORS_ORIGINS: z.string().default(''),
  JSON_BODY_LIMIT: z
    .string()
    .trim()
    .regex(/^\d+\s*(?:b|kb|mb)?$/i, 'must be a byte size such as 100kb or 1mb')
    .refine(isWithinJsonBodyLimit, 'must be between 1 byte and 10mb')
    .default('100kb'),
  FAKE_STORE_BASE_URL: z.string().url().default('https://fakestoreapi.com'),
  PRODUCT_CACHE_TTL_MS: z.coerce.number().int().min(0).max(300_000).default(60_000),
  UPSTREAM_TIMEOUT_MS: z.coerce.number().int().min(100).max(30_000).default(5_000),
  SMTP_HOST: z.string().trim().min(1).default('127.0.0.1'),
  SMTP_PORT: z.coerce.number().int().min(1).max(65_535).default(1025),
  SMTP_SECURE: z.enum(['true', 'false']).default('false').transform((value) => value === 'true'),
  SMTP_USERNAME: optionalCredential,
  SMTP_PASSWORD: optionalCredential,
  EMAIL_FROM: z.string().trim().email().default('catalogue@example.local'),
  ENQUIRY_RECIPIENT: z.string().trim().email().default('enquiries@example.local'),
}).superRefine((config, context) => {
  if ((config.SMTP_USERNAME === undefined) !== (config.SMTP_PASSWORD === undefined)) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['SMTP_USERNAME'],
      message: 'SMTP_USERNAME and SMTP_PASSWORD must both be set or both omitted',
    });
  }
});

const MAX_JSON_BODY_LIMIT_BYTES = 10 * 1024 * 1024;

function isWithinJsonBodyLimit(value: string): boolean {
  const match = /^(\d+)\s*(b|kb|mb)?$/i.exec(value.trim());
  if (!match) return false;

  const size = Number(match[1]);
  const unit = (match[2] ?? 'b').toLowerCase();
  const multiplier = unit === 'mb' ? 1024 * 1024 : unit === 'kb' ? 1024 : 1;
  const bytes = size * multiplier;

  return Number.isSafeInteger(bytes) && bytes >= 1 && bytes <= MAX_JSON_BODY_LIMIT_BYTES;
}

export interface SmtpConfig {
  readonly smtpHost: string;
  readonly smtpPort: number;
  readonly smtpSecure: boolean;
  readonly smtpUsername: string | undefined;
  readonly smtpPassword: string | undefined;
  readonly emailFrom: string;
  readonly enquiryRecipient: string;
}

export interface AppConfig extends SmtpConfig {
  readonly nodeEnv: 'development' | 'test' | 'production';
  readonly host: string;
  readonly port: number;
  readonly corsOrigins: readonly string[];
  readonly jsonBodyLimit: string;
  readonly fakeStoreBaseUrl: string;
  readonly productCacheTtlMs: number;
  readonly upstreamTimeoutMs: number;
}

export function loadConfig(environment: NodeJS.ProcessEnv = process.env): AppConfig {
  const parsed = environmentSchema.safeParse(environment);

  if (!parsed.success) {
    const details = parsed.error.issues
      .map((issue) => `${issue.path.join('.') || 'environment'}: ${issue.message}`)
      .join('; ');
    throw new Error(`Invalid environment configuration: ${details}`);
  }

  const corsOrigins = parsed.data.CORS_ORIGINS
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);

  return {
    nodeEnv: parsed.data.NODE_ENV,
    host: parsed.data.HOST,
    port: parsed.data.PORT,
    corsOrigins,
    jsonBodyLimit: parsed.data.JSON_BODY_LIMIT,
    fakeStoreBaseUrl: parsed.data.FAKE_STORE_BASE_URL.replace(/\/$/, ''),
    productCacheTtlMs: parsed.data.PRODUCT_CACHE_TTL_MS,
    upstreamTimeoutMs: parsed.data.UPSTREAM_TIMEOUT_MS,
    smtpHost: parsed.data.SMTP_HOST,
    smtpPort: parsed.data.SMTP_PORT,
    smtpSecure: parsed.data.SMTP_SECURE,
    smtpUsername: parsed.data.SMTP_USERNAME,
    smtpPassword: parsed.data.SMTP_PASSWORD,
    emailFrom: parsed.data.EMAIL_FROM,
    enquiryRecipient: parsed.data.ENQUIRY_RECIPIENT,
  };
}
