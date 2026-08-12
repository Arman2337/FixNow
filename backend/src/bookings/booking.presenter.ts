import type { BookingContract } from '../../../shared/booking-lifecycle.types';
import type { Booking } from './domain/booking.entity';

const toIsoString = (value: Date | null | undefined): string | null =>
  value ? value.toISOString() : null;

export const presentBooking = (booking: Booking): BookingContract => ({
  id: booking.id,
  customerId: booking.customerId,
  providerId: booking.providerId,
  serviceCategoryId: booking.serviceCategoryId,
  status: booking.status,
  description: booking.description,
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
