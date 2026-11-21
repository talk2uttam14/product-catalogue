export interface ProductDTO {
  readonly id: string;
  readonly title: string;
  readonly description: string;
  readonly category: string;
  readonly imageUrl: string;
  readonly price: number;
  readonly rating: {
    readonly rate: number;
    readonly count: number;
  };
}
