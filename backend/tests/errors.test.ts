import express from 'express';
import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { errorHandler } from '../src/http/middleware/errors.js';

describe('error middleware', () => {
  it('does not expose unexpected error messages or stack traces', async () => {
    const app = express();
    app.get('/failure', (_request, _response, next) => {
      next(new Error('private provider response with sensitive details'));
    });
    app.use(errorHandler);

    const response = await request(app).get('/failure');

    expect(response.status).toBe(500);
    expect(response.body).toEqual({
      error: {
        code: 'INTERNAL_SERVER_ERROR',
        message: 'An unexpected error occurred.',
        details: [],
      },
    });
    expect(JSON.stringify(response.body)).not.toContain('private provider response');
    expect(JSON.stringify(response.body)).not.toContain('stack');
  });
});
