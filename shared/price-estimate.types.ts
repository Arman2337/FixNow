/**
 * FN-060: advisory price estimation contracts. Estimates are explainable
 * guidance derived deterministically from catalog/paid-order data; they are
 * never a quote and never feed booking totals.
 */

export type PriceEstimateBasis = 'PUBLISHED' | 'OBSERVED';

export interface AdvisoryPriceEstimate {
  kind: 'ESTIMATE';
  serviceCategoryId: string;
  currency: string;
  /** Integer minor units (paise). */
  minAmountMinor: number;
  maxAmountMinor: number;
  typicalAmountMinor: number;
  basis: PriceEstimateBasis;
  /** Paid-order sample size for OBSERVED estimates; null for PUBLISHED. */
  sampleSize: number | null;
  explanation: string;
  advisoryNotice: string;
}

export interface PriceOnRequestOutcome {
  kind: 'PRICE_ON_REQUEST';
  serviceCategoryId: string;
  explanation: string;
}

export type PriceEstimateResponse =
  | AdvisoryPriceEstimate
  | PriceOnRequestOutcome;
