/**
 * FN-051 payment contracts. Money is always integer minor units (paise for
 * INR) — floating-point money is prohibited at every boundary. INR is the
 * only supported currency until an approved decision widens the set.
 */
export type PaymentCurrency = 'INR';

export interface CreatePaymentOrderRequest {
  amountMinor: number;
  currency: PaymentCurrency;
  /** Caller-scoped idempotency reference (e.g. booking-scoped key). */
  receipt: string;
  notes?: Record<string, string>;
}

export interface PaymentGatewayOrder {
  gatewayOrderId: string;
  amountMinor: number;
  currency: string;
  /** Provider status string (e.g. Razorpay `created`). */
  status: string;
}

export interface VerifyCheckoutParams {
  gatewayOrderId: string;
  gatewayPaymentId: string;
  signature: string;
}

export type PaymentOrderStatus = 'CREATED' | 'PAID' | 'FAILED' | 'CANCELLED';

export interface PaymentOrderContract {
  id: string;
  bookingId: string;
  amountMinor: number;
  currency: string;
  status: PaymentOrderStatus;
  gatewayOrderId: string;
  createdAt: string;
}
