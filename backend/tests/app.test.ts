import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { createApp } from '../src/app.js';
import type { AppConfig } from '../src/config/env.js';

const testConfig: AppConfig = {
  nodeEnv: 'test',
  host: '127.0.0.1',
  port: 3000,
  corsOrigins: ['http://localhost:5173'],
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

const app = createApp(testConfig);

describe('HTTP foundation', () => {
  it('returns a JSON health response without opening a listener', async () => {
    const response = await request(app).get('/health');

    expect(response.status).toBe(200);
    expect(response.body).toEqual({ status: 'ok' });
    expect(response.headers['content-type']).toMatch(/application\/json/);
    expect(response.headers['x-content-type-options']).toBe('nosniff');
  });

  it('returns the common error envelope for unknown paths', async () => {
    const response = await request(app).get('/missing');

    expect(response.status).toBe(404);
    expect(response.body).toEqual({
      error: {
        code: 'NOT_FOUND',
        message: 'The requested resource was not found.',
        details: [],
      },
    });
  });

  it('returns the common error envelope for malformed JSON', async () => {
    const response = await request(app)
      .post('/health')
      .set('content-type', 'application/json')
      .send('{ invalid json');

    expect(response.status).toBe(400);
    expect(response.body).toEqual({
      error: {
        code: 'VALIDATION_ERROR',
        message: 'The request body must contain valid JSON.',
        details: [],
      },
    });
  });

  it('returns a generic 413 response for oversized JSON bodies', async () => {
    const limitedApp = createApp({ ...testConfig, jsonBodyLimit: '10b' });
    const response = await request(limitedApp)
      .post('/health')
      .send({ payload: 'this is over the configured limit' });

    expect(response.status).toBe(413);
    expect(response.body.error.code).toBe('PAYLOAD_TOO_LARGE');
  });
});
