import type { ErrorRequestHandler, RequestHandler } from 'express';
import { ZodError } from 'zod';
import {
  CategoryNotFoundError,
  ProductNotFoundError,
  ProductSourceError,
} from '../../products/product.errors.js';
import { EmailDeliveryError } from '../../enquiries/enquiry.errors.js';

interface ErrorEnvelope {
  error: {
    code: string;
    message: string;
    details: readonly unknown[];
  };
}

export const notFoundHandler: RequestHandler = (_request, response) => {
  const body: ErrorEnvelope = {
    error: {
      code: 'NOT_FOUND',
      message: 'The requested resource was not found.',
      details: [],
    },
  };
  response.status(404).json(body);
};

export const errorHandler: ErrorRequestHandler = (error: unknown, _request, response, _next) => {
  if (error instanceof ProductNotFoundError || error instanceof CategoryNotFoundError) {
    const isProduct = error instanceof ProductNotFoundError;
    response.status(404).json({
      error: {
        code: isProduct ? 'PRODUCT_NOT_FOUND' : 'CATEGORY_NOT_FOUND',
        message: isProduct ? 'The requested product was not found.' : 'The requested category was not found.',
        details: [],
      },
    });
    return;
  }

  if (error instanceof ProductSourceError) {
    response.status(502).json({
      error: {
        code: 'UPSTREAM_ERROR',
        message: 'The product catalogue is temporarily unavailable.',
        details: [],
      },
    });
    return;
  }

  if (error instanceof EmailDeliveryError) {
    response.status(502).json({
      error: {
        code: 'EMAIL_DELIVERY_FAILED',
        message: 'Unable to send the enquiry at this time.',
        details: [],
      },
    });
    return;
  }

  if (error instanceof ZodError) {
    const body: ErrorEnvelope = {
      error: {
        code: 'VALIDATION_ERROR',
        message: 'The request is invalid.',
        details: error.issues.map((issue) => ({ path: issue.path, message: issue.message })),
      },
    };
    response.status(400).json(body);
    return;
  }

  if (isMalformedJsonError(error)) {
    const body: ErrorEnvelope = {
      error: {
        code: 'VALIDATION_ERROR',
        message: 'The request body must contain valid JSON.',
        details: [],
      },
    };
    response.status(400).json(body);
    return;
  }

  if (isPayloadTooLargeError(error)) {
    const body: ErrorEnvelope = {
      error: {
        code: 'PAYLOAD_TOO_LARGE',
        message: 'The request body is too large.',
        details: [],
      },
    };
    response.status(413).json(body);
    return;
  }

  // Keep provider, parser, and programming error details in server logs only.
  const body: ErrorEnvelope = {
    error: {
      code: 'INTERNAL_SERVER_ERROR',
      message: 'An unexpected error occurred.',
      details: [],
    },
  };
  response.status(500).json(body);
};

function isPayloadTooLargeError(error: unknown): error is { type: 'entity.too.large' } {
  return typeof error === 'object' && error !== null && 'type' in error && error.type === 'entity.too.large';
}

function isMalformedJsonError(error: unknown): error is { type: 'entity.parse.failed' } {
  return typeof error === 'object' && error !== null && 'type' in error && error.type === 'entity.parse.failed';
}
