import { describe, expect, it } from 'vitest';
import { loadConfig } from '../src/config/env.js';

describe('environment configuration', () => {
  it('uses valid development defaults', () => {
    expect(loadConfig({})).toEqual({
      nodeEnv: 'development',
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
    });
  });

  it('accepts a valid configured JSON body limit', () => {
    expect(loadConfig({ JSON_BODY_LIMIT: '1mb' }).jsonBodyLimit).toBe('1mb');
  });

  it.each(['', 'unlimited', '0b', '11mb', '-1kb'])('rejects invalid JSON_BODY_LIMIT %j', (limit) => {
    expect(() => loadConfig({ JSON_BODY_LIMIT: limit })).toThrow('Invalid environment configuration');
  });

  it('rejects invalid ports', () => {
    expect(() => loadConfig({ PORT: 'not-a-port' })).toThrow('Invalid environment configuration');
  });

  it('uses Mailpit SMTP defaults without authentication', () => {
    const config = loadConfig({});
    expect(config).toMatchObject({
      smtpHost: '127.0.0.1',
      smtpPort: 1025,
      smtpSecure: false,
      emailFrom: 'catalogue@example.local',
      enquiryRecipient: 'enquiries@example.local',
    });
    expect(config.smtpUsername).toBeUndefined();
    expect(config.smtpPassword).toBeUndefined();
  });

  it('validates SMTP port, sender, recipient, and paired credentials', () => {
    expect(() => loadConfig({ SMTP_PORT: '70000' })).toThrow('Invalid environment configuration');
    expect(() => loadConfig({ EMAIL_FROM: 'not-an-email' })).toThrow('Invalid environment configuration');
    expect(() => loadConfig({ ENQUIRY_RECIPIENT: 'not-an-email' })).toThrow('Invalid environment configuration');
    expect(() => loadConfig({ SMTP_USERNAME: 'user' })).toThrow('Invalid environment configuration');
    expect(() => loadConfig({ SMTP_PASSWORD: 'pass' })).toThrow('Invalid environment configuration');
  });

  it('accepts SMTP credentials when both values are provided', () => {
    expect(loadConfig({ SMTP_USERNAME: 'mail-user', SMTP_PASSWORD: 'mail-pass' })).toMatchObject({
      smtpUsername: 'mail-user',
      smtpPassword: 'mail-pass',
    });
  });
});
