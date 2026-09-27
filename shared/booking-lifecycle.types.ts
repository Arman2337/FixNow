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

export interface CreateBookingLineItemRequest {
  subServiceId: string;
  quantity: number;
}

/**
 * What a client is allowed to send for one itemized task line.
 *
 * SECURITY: a client may select a catalogue entry and a quantity. It may NOT
 * send a price. `unitPriceMinor` and `name` are resolved server-side from
 * `sub_services`, so the amount charged can never be chosen by the buyer.
 */
export interface BookingItemRequestContract {
  subServiceId: string;
  quantity: number;
}

/**
 * The persisted, server-priced snapshot of one itemized task line
 * (e.g. "Tap & Mixer Repair" x2). `unitPriceMinor` and `durationMinutes` are
 * per-unit. Amounts are paise. This is an OUTPUT shape — the backend is the
 * only writer. `computeBookingTotals` derives every total from these lines.
 */
export interface BookingItemContract {
  id: string;
  name: string;
  quantity: number;
  unitPriceMinor: number;
  durationMinutes?: number | null;
}

/** Server-computed pricing snapshot derived from the booking's items. */
export interface BookingPricingContract {
  subtotalMinor: number;
  gstMinor: number;
  totalMinor: number;
  currency: string;
}

export interface CreateBookingRequest {
  serviceCategoryId: string;
  description: string;
  locationLat: number;
  locationLng: number;
  scheduledAt?: string | null;
  items?: BookingItemRequestContract[] | null;
  lineItems?: CreateBookingLineItemRequest[];
}

/**
 * Provider command to replace the booking's itemized lines after finding more
 * (or less) work on site. The provider selects catalogue entries and
 * quantities only; every price is re-resolved from `sub_services`.
 */
export interface UpdateBookingItemsRequest {
  items: BookingItemRequestContract[];
  expectedVersion: number;
  reason?: string;
}

export interface BookingContract {
  id: string;
  customerId: string;
  providerId: string | null;
  serviceCategoryId: string;
  status: BookingStatus;
  description: string;
  items: BookingItemContract[] | null;
  pricing: BookingPricingContract | null;
  estimatedDurationMinutes: number | null;
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
  customerPhone?: string | null;
  providerPhone?: string | null;
  providerName?: string | null;
  providerRating?: number | null;
  providerJobsCount?: number | null;
  lineItems?: Array<{
    id: string;
    subServiceId: string;
    quantity: number;
    priceMinor: number;
  }>;
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
  items: BookingItemContract[] | null;
  pricing: BookingPricingContract | null;
  estimatedDurationMinutes: number | null;
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
