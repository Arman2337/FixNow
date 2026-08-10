import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import nodemailer from 'nodemailer';

export const OTP_DELIVERY = Symbol('OTP_DELIVERY');

export interface OtpDelivery {
  sendVerificationCode(email: string, code: string): Promise<void>;
}

@Injectable()
export class SmtpOtpDelivery implements OtpDelivery {
  constructor(private readonly config: ConfigService) {}

  async sendVerificationCode(email: string, code: string): Promise<void> {
    const host = this.config.get<string>('SMTP_HOST');
    const user = this.config.get<string>('SMTP_USER');
    const pass = this.config.get<string>('SMTP_PASS');
    const from = this.config.get<string>('SMTP_FROM');
    if (!host || !user || !pass || !from) {
      throw new ServiceUnavailableException('Email delivery is unavailable');
    }
    const port = this.config.get<number>('SMTP_PORT') ?? 587;
    const transporter = nodemailer.createTransport({
      host,
      port,
      secure: port === 465,
      auth: { user, pass },
    });
    await transporter.sendMail({
      from,
      to: email,
      subject: 'Your FixNow verification code',
      text: `Your FixNow verification code is ${code}. It expires in 10 minutes.`,
    });
  }
}
