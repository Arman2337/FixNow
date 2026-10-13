import {
  BadRequestException,
  Controller,
  Get,
  Param,
  Post,
  Req,
} from '@nestjs/common';
import { Public } from '../common/authorization/authorization.decorators';
import { RequireOwnPermission } from '../common/authorization/authorization.decorators';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import { BookingsService } from './bookings.service';
import { ShareTokenService } from './share-token.service';

class CreateShareLinkDto {
  /** Minutes the link should stay valid. Clamped by the service. */
  ttlMinutes?: number;
}

/**
 * FN-145. Sharing a live ETA view.
 *
 * Split deliberately in two:
 *
 * - `POST /bookings/:id/share-link` is authenticated and participant-gated.
 *   It mints a capability; it discloses nothing.
 * - `GET /shares/:token` is public and read-only. It answers with a status
 *   label, a coarse arrival estimate and a short opaque reference — nothing
 *   else. It cannot be walked: without a valid signature the booking id is
 *   unknowable, and the token is the only input.
 */
@Controller()
export class BookingSharesController {
  constructor(
    private readonly bookings: BookingsService,
    private readonly tokens: ShareTokenService,
  ) {}

  @Post('bookings/:id/share-link')
  @RequireOwnPermission(PERMISSIONS.bookingShareLink)
  async create(
    @Req() request: AuthorizedRequest,
    @Param('id') bookingId: string,
  ): Promise<{ token: string; expiresAt: string }> {
    const principal = request.authorizationPrincipal!;
    const ttlMinutes = Number(
      (request.body as CreateShareLinkDto | undefined)?.ttlMinutes ?? 0,
    );
    const ttlSeconds = Number.isFinite(ttlMinutes)
      ? ttlMinutes * 60
      : ShareTokenService.maxTtlSeconds;
    // Mints only for somebody who can already see the booking, so the link can
    // never be a way to disclose a job to a third party.
    await this.bookings.assertParticipant(
      bookingId,
      principal.userId,
      principal,
    );
    const { token, expiresAt } = this.tokens.mint(bookingId, ttlSeconds);
    return { token, expiresAt: expiresAt.toISOString() };
  }

  /**
   * The public view.
   *
   * Deliberately minimal. It returns a status label, a coarse "arriving in"
   * figure and a short reference — and never the customer, the address, the
   * description, a phone number, or a live coordinate. A share link is handed
   * to whoever the customer chooses; the payload is the product, so it has to
   * be the least disclosing thing that is still useful.
   */
  @Public()
  @Get('shares/:token')
  async view(@Param('token') token: string): Promise<{
    reference: string;
    status: string;
    statusLabel: string;
    arrivingInMinutes: number | null;
    updatedAt: string;
  }> {
    const { bookingId } = this.tokens.verify(token);
    const booking = await this.bookings.findVisibleForShare(bookingId);
    if (!booking) {
      // Deliberately the same answer as a bad token: a caller must not be able
      // to learn that a booking id exists but is no longer shareable.
      throw new BadRequestException(
        'This share link is invalid or has expired',
      );
    }
    const active = [
      BookingStatus.ASSIGNED,
      BookingStatus.EN_ROUTE,
      BookingStatus.IN_PROGRESS,
    ].includes(booking.status);
    return {
      // Opaque and short: enough to correlate in a conversation, useless for
      // probing the API.
      reference: bookingId.slice(0, 8).toUpperCase(),
      status: booking.status,
      statusLabel: SHARE_STATUS_LABELS[booking.status] ?? 'Booking update',
      arrivingInMinutes: active ? this.coarseEta(booking) : null,
      updatedAt: (booking.enRouteAt ?? booking.createdAt).toISOString(),
    };
  }

  /**
   * Coarse on purpose.
   *
   * Bucketed to five-minute bands and never derived from a live coordinate, so
   * the shared view cannot be used to reconstruct where anybody is.
   */
  private coarseEta(booking: { enRouteAt: Date | null }): number | null {
    if (!booking.enRouteAt) return null;
    const elapsed = Math.max(
      0,
      Math.floor((Date.now() - booking.enRouteAt.getTime()) / 60000),
    );
    // A bucket, not a countdown: 0..30 means "arriving now", then a band every
    // five minutes up to an hour, then null because past an hour nobody should
    // be quoting a number.
    if (elapsed >= 60) return null;
    return elapsed <= 30
      ? Math.round(elapsed / 5) * 5
      : 30 + Math.round(((elapsed - 30) / 5) * 5);
  }
}

const SHARE_STATUS_LABELS: Record<string, string> = {
  REQUESTED: 'Finding a pro nearby',
  ASSIGNED: 'A pro has been assigned',
  EN_ROUTE: 'On the way to you',
  IN_PROGRESS: 'Work in progress',
  COMPLETED: 'Completed',
  CANCELLED: 'Cancelled',
};
