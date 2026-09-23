import type { BookingItemContract } from '../../../../shared/booking-lifecycle.types';

/** Platform GST rate applied to itemized booking subtotals. */
export const BOOKING_GST_RATE = 0.18;

/** The persisted line-item snapshot stored on a booking. */
export type BookingItemSnapshot = BookingItemContract;

export interface BookingTotals {
  subtotalMinor: number;
  gstMinor: number;
  totalMinor: number;
  estimatedDurationMinutes: number | null;
}

const round = (value: number): number => Math.round(value);

/**
 * Recomputes booking money and duration from line items. This is the only
 * place totals are derived — the service persists them and the presenter
 * re-derives display pricing from the same snapshot, so stored and shown
 * amounts can never drift.
 */
export function computeBookingTotals(
  items: BookingItemSnapshot[] | null | undefined,
): BookingTotals {
  if (!items?.length) {
    return {
      subtotalMinor: 0,
      gstMinor: 0,
      totalMinor: 0,
      estimatedDurationMinutes: null,
    };
  }
  const subtotalMinor = round(
    items.reduce((sum, item) => sum + item.unitPriceMinor * item.quantity, 0),
  );
  const gstMinor = round(subtotalMinor * BOOKING_GST_RATE);
  const durationLines = items.filter(
    (item) => typeof item.durationMinutes === 'number',
  );
  return {
    subtotalMinor,
    gstMinor,
    totalMinor: subtotalMinor + gstMinor,
    estimatedDurationMinutes: durationLines.length
      ? round(
          durationLines.reduce(
            (sum, item) => sum + item.durationMinutes! * item.quantity,
            0,
          ),
        )
      : null,
  };
}
