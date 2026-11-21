export class EmailDeliveryError extends Error {
  constructor() {
    super('Enquiry email delivery failed.');
    this.name = 'EmailDeliveryError';
  }
}
