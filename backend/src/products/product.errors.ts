export class ProductNotFoundError extends Error {
  constructor() {
    super('Product was not found.');
    this.name = 'ProductNotFoundError';
  }
}

export class CategoryNotFoundError extends Error {
  constructor() {
    super('Category was not found.');
    this.name = 'CategoryNotFoundError';
  }
}

export class ProductSourceError extends Error {
  constructor() {
    super('Product catalogue source is unavailable.');
    this.name = 'ProductSourceError';
  }
}
