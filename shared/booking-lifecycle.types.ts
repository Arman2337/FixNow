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

/**
 * Why a booking was abandoned rather than finished.
 *
 * BUG-020. The state machine has always allowed `IN_PROGRESS → CANCELLED`, but
 * `cancelBooking` only permitted a provider to cancel from `[ASSIGNED,
 * EN_ROUTE]`. So a provider who started a job and then found it misdescribed -
 * wrong job, unsafe, customer absent, no parts - had exactly two options:
 *
 *   1. finish it anyway, which starts the payment clock and generates a
 *      completion signal against them, or
 *   2. leave the booking IN_PROGRESS forever, stranding the customer's money and
 *      the platform's dispatch record.
 *
 * There is no third option, so providers lie to the platform. The report called
 * this the mechanism by which providers falsely complete work, and it is: a
 * rule with no honest exit is a rule people route around.
 *
 * A free-text `reason` was never enough on its own, because "the customer is not
 * answering" and "this is not the job I agreed to" need different responses -
 * one re-dispatches, the other opens a dispute. These codes are the minimum
 * vocabulary for a support team to tell them apart from the cancellation record.
 */
export const PROVIDER_ABANDONMENT_REASONS = [
  /** The customer is not present, or will not answer. */
  'CUSTOMER_UNAVAILABLE',
  /** What was found is not the work that was described or quoted. */
  'JOB_MISDESCRIBED',
  /** The provider judges it unsafe to proceed. */
  'UNSAFE_CONDITIONS',
  /** Parts, tools or materials needed are unavailable. */
  'RESOURCES_UNAVAILABLE',
  /** Any other reason, spelled out in the free-text field. */
  'OTHER',
] as const;

export type ProviderAbandonmentReason =
  (typeof PROVIDER_ABANDONMENT_REASONS)[number];

export const PROVIDER_ABANDONMENT_COPY: Readonly<
  Record<ProviderAbandonmentReason, string>
> = {
  CUSTOMER_UNAVAILABLE:
    'The provider could not reach the customer. The request is open again so another provider can be matched.',
  JOB_MISDESCRIBED:
    'The provider reported that the work did not match the request. Support will review this booking.',
  UNSAFE_CONDITIONS:
    'The provider judged the conditions unsafe to proceed. Support will review this booking.',
  RESOURCES_UNAVAILABLE:
    'The provider could not obtain what the job required. Support will review this booking.',
  OTHER: 'The provider ended this job. Support will review this booking.',
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

/**
 * FN-082 / BUG-014. The response to booking *creation*, which carries two facts
 * `BookingResponse` cannot.
 *
 * `status: REQUESTED` on its own is indistinguishable between "a search is
 * running" and "a search that will never resolve". On day one in a new city,
 * zero eligible providers is the *common* answer, and the customer had no way to
 * learn it - no count, no elapsed time, and a booking that stayed in REQUESTED
 * forever because nothing in the backend expired it.
 *
 * Separate from `BookingResponse` rather than an addition to it, because the
 * other eleven endpoints that return a booking have no eligible count to
 * report: by the time a provider accepts, supply is no longer the question.
 */
export interface BookingCreationResponse {
  booking: BookingContract;
  /** Providers who could take this request at the moment it was created. */
  eligibleProviderCount: number;
  /**
   * True when that count was zero. The client should offer alternatives -
   * widen the time, try another category, get notified - rather than enter a
   * search that is not going to resolve.
   */
  noProviderAvailable: boolean;
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
