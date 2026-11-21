import cors from 'cors';
import express, { type Express } from 'express';
import helmet from 'helmet';
import type { AppConfig } from './config/env.js';
import { createDependencies, type AppDependencies } from './di/container.js';
import { errorHandler, notFoundHandler } from './http/middleware/errors.js';
import { createProductRoutes } from './http/routes/product.routes.js';
import { createEnquiryRoutes } from './http/routes/enquiry.routes.js';

export function createApp(
  config: AppConfig,
  dependencies: AppDependencies = createDependencies(config),
): Express {
  const app = express();

  app.disable('x-powered-by');
  app.use(helmet());
  app.use(cors({ origin: [...config.corsOrigins] }));
  app.use(express.json({ limit: config.jsonBodyLimit, strict: true }));

  app.get('/health', (_request, response) => {
    response.status(200).json({ status: 'ok' });
  });

  app.use('/api/v1', createProductRoutes(dependencies.productService));
  app.use('/api/v1', createEnquiryRoutes(dependencies.enquiryService));
  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
