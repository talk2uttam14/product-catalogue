import { Router, type RequestHandler } from 'express';
import { z } from 'zod';
import type { ProductService } from '../../products/product.service.js';

const querySchema = z.string().trim().min(1).max(100);
const categorySchema = z.string().trim().min(1).max(100);
const productIdSchema = z.string().regex(/^\d+$/).refine((value) => Number(value) > 0);

export function createProductRoutes(productService: ProductService): Router {
  const router = Router();

  router.get('/products/featured', asyncHandler(async (_request, response) => {
    response.json({ data: await productService.getFeaturedProducts() });
  }));

  router.get('/categories', asyncHandler(async (_request, response) => {
    response.json({ data: await productService.getCategories() });
  }));

  router.get('/categories/:category/products', asyncHandler(async (request, response) => {
    const category = categorySchema.parse(request.params.category);
    response.json({ data: await productService.getCategoryProducts(category) });
  }));

  // Keep the fixed search path before the parameterized product ID path.
  router.get('/products/search', asyncHandler(async (request, response) => {
    const query = querySchema.parse(request.query.q);
    const products = await productService.searchProducts(query);
    response.json({ data: products, meta: { query, count: products.length } });
  }));

  router.get('/products/:id', asyncHandler(async (request, response) => {
    const id = productIdSchema.parse(request.params.id);
    response.json({ data: await productService.getProductById(id) });
  }));

  return router;
}

function asyncHandler(handler: (request: Parameters<RequestHandler>[0], response: Parameters<RequestHandler>[1]) => Promise<void>): RequestHandler {
  return (request, response, next) => {
    void handler(request, response).catch(next);
  };
}
