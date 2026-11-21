import { createServer } from 'node:http';
import { once } from 'node:events';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { startServer } from '../src/server.js';
import type { AppConfig } from '../src/config/env.js';

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

const originalExitCode = process.exitCode;

afterEach(() => {
  process.exitCode = originalExitCode;
  vi.restoreAllMocks();
});

describe('server startup', () => {
  it('logs a generic startup failure when the configured port is occupied', async () => {
    const blocker = createServer();
    blocker.listen(0, '127.0.0.1');
    await once(blocker, 'listening');
    const address = blocker.address();
    if (!address || typeof address === 'string') throw new Error('Expected a TCP address');

    const errorLog = vi.spyOn(console, 'error').mockImplementation(() => undefined);
    const server = startServer({ ...config, port: address.port });

    await once(server, 'error');
    expect(errorLog).toHaveBeenCalledWith('HTTP server startup failed (EADDRINUSE).');
    expect(process.exitCode).toBe(1);

    await new Promise<void>((resolve, reject) => {
      blocker.close((error) => (error ? reject(error) : resolve()));
    });
  });
});
