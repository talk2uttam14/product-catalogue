import nodemailer from 'nodemailer';
import type { SmtpConfig } from '../../config/env.js';
import type { EmailProvider, EnquiryEmail } from '../../enquiries/email-provider.js';

export class NodemailerEmailProvider implements EmailProvider {
  private readonly transporter: nodemailer.Transporter;

  constructor(private readonly config: SmtpConfig) {
    const auth = config.smtpUsername !== undefined && config.smtpPassword !== undefined
      ? { user: config.smtpUsername, pass: config.smtpPassword }
      : undefined;

    this.transporter = nodemailer.createTransport({
      host: config.smtpHost,
      port: config.smtpPort,
      secure: config.smtpSecure,
      ...(auth ? { auth } : {}),
    });
  }

  async sendEnquiry({ enquiry, product }: EnquiryEmail): Promise<void> {
    const lines = [
      `Product: ${product.title} (ID: ${product.id})`,
      `Name: ${enquiry.name}`,
      `Email: ${enquiry.email}`,
    ];
    if (enquiry.phone) lines.push(`Phone: ${enquiry.phone}`);
    lines.push('', 'Message:', enquiry.message);

    const result = await this.transporter.sendMail({
      from: this.config.emailFrom,
      to: this.config.enquiryRecipient,
      replyTo: enquiry.email,
      subject: `Product enquiry for product ${product.id}`,
      text: lines.join('\n'),
    });

    if (!Array.isArray(result.accepted) || result.accepted.length === 0) {
      throw new Error('SMTP did not accept the configured recipient.');
    }
  }
}
