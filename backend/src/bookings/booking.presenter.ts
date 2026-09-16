import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import type {
  BookingContract,
  BookingPricingContract,
  ProviderBookingRequestContract,
} from '../../../shared/booking-lifecycle.types';
import type { Booking } from './domain/booking.entity';
import { computeBookingTotals } from './domain/booking-items';

const toIsoString = (value: Date | null | undefined): string | null =>
  value ? value.toISOString() : null;

/**
 * Display pricing is always re-derived from the stored item snapshot so it
 * matches what the service persisted at creation time. Bookings without
 * line items present no pricing (payment falls back to category price).
 */
const presentPricing = (booking: Booking): BookingPricingContract | null => {
  const totals = computeBookingTotals(booking.items);
  if (!booking.items?.length || !booking.totalAmountMinor) return null;
  return {
    subtotalMinor: totals.subtotalMinor,
    gstMinor: totals.gstMinor,
    totalMinor: booking.totalAmountMinor,
    currency: 'INR',
  };
};

export const presentBooking = (booking: Booking): BookingContract => ({
  id: booking.id,
  customerId: booking.customerId,
  providerId: booking.providerId,
  serviceCategoryId: booking.serviceCategoryId,
  status: booking.status,
  description: booking.description,
  items: booking.items,
  pricing: presentPricing(booking),
  estimatedDurationMinutes: booking.estimatedDurationMinutes,
  locationLat:
    booking.locationLat === null ? null : Number(booking.locationLat),
  locationLng:
    booking.locationLng === null ? null : Number(booking.locationLng),
  scheduledAt: toIsoString(booking.scheduledAt),
  assignedAt: toIsoString(booking.assignedAt),
  enRouteAt: toIsoString(booking.enRouteAt),
  startedAt: toIsoString(booking.startedAt),
  completedAt: toIsoString(booking.completedAt),
  cancelledAt: toIsoString(booking.cancelledAt),
  cancellationReason: booking.cancellationReason,
  createdAt: booking.createdAt.toISOString(),
  updatedAt: booking.updatedAt.toISOString(),
  version: booking.version,
});

export const presentProviderBookingRequest = (
  booking: Booking,
  distanceKm: number,
): ProviderBookingRequestContract => ({
  id: booking.id,
  serviceCategoryId: booking.serviceCategoryId,
  status: BookingStatus.REQUESTED,
  description: booking.description,
  items: booking.items,
  pricing: presentPricing(booking),
  estimatedDurationMinutes: booking.estimatedDurationMinutes,
  scheduledAt: toIsoString(booking.scheduledAt),
  createdAt: booking.createdAt.toISOString(),
  version: booking.version,
  distanceKm,
});
