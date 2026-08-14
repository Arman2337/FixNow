export enum BookingStatus {
  REQUESTED = "REQUESTED",
  ASSIGNED = "ASSIGNED",
  EN_ROUTE = "EN_ROUTE",
  IN_PROGRESS = "IN_PROGRESS",
  COMPLETED = "COMPLETED",
  CANCELLED = "CANCELLED",
}

export const VALID_BOOKING_TRANSITIONS: Readonly<
  Record<BookingStatus, readonly BookingStatus[]>
> = {
  [BookingStatus.REQUESTED]: [BookingStatus.ASSIGNED, BookingStatus.CANCELLED],
  [BookingStatus.ASSIGNED]: [BookingStatus.EN_ROUTE, BookingStatus.CANCELLED],
  [BookingStatus.EN_ROUTE]: [
    BookingStatus.IN_PROGRESS,
    BookingStatus.CANCELLED,
  ],
  [BookingStatus.IN_PROGRESS]: [
    BookingStatus.COMPLETED,
    BookingStatus.CANCELLED,
  ],
  [BookingStatus.COMPLETED]: [],
  [BookingStatus.CANCELLED]: [],
};

export interface CreateBookingRequest {
  serviceCategoryId: string;
  description: string;
  locationLat: number;
  locationLng: number;
  scheduledAt?: string | null;
}

export interface BookingContract {
  id: string;
  customerId: string;
  providerId: string | null;
  serviceCategoryId: string;
  status: BookingStatus;
  description: string;
  locationLat: number | null;
  locationLng: number | null;
  scheduledAt: string | null;
  assignedAt: string | null;
  enRouteAt: string | null;
  startedAt: string | null;
  completedAt: string | null;
  cancelledAt: string | null;
  cancellationReason: string | null;
  createdAt: string;
  updatedAt: string;
  version: number;
}

export interface BookingResponse {
  booking: BookingContract;
}

export interface BookingHistoryResponse {
  bookings: BookingContract[];
  nextCursor: string | null;
}

/**
 * Provider-facing request preview. It intentionally excludes customer identity
 * and precise request coordinates until the provider accepts the booking.
 */
export interface ProviderBookingRequestContract {
  id: string;
  serviceCategoryId: string;
  status: BookingStatus.REQUESTED;
  description: string;
  scheduledAt: string | null;
  createdAt: string;
  version: number;
  distanceKm: number;
}

export interface ProviderBookingRequestResponse {
  bookings: ProviderBookingRequestContract[];
}

export interface VersionedBookingCommand {
  expectedVersion: number;
}
