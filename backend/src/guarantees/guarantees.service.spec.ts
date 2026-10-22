import 'reflect-metadata';
import { BadRequestException, ConflictException } from '@nestjs/common';
import { GuaranteesService } from './guarantees.service';
import {
  GuaranteeClaim,
  GuaranteeClaimStatus,
} from './domain/guarantee-claim.entity';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import type { AssignedBookingInput } from '../bookings/bookings.service';
import type { Booking } from '../bookings/domain/booking.entity';

const CLAIM_ID = '00000000-0000-4000-8000-000000000001';
const CUSTOMER_ID = '00000000-0000-4000-8000-000000000002';
const PROVIDER_ID = '00000000-0000-4000-8000-000000000003';
const ORIGINAL_ID = '00000000-0000-4000-8000-000000000004';
const CATEGORY_ID = '00000000-0000-4000-8000-000000000005';
const ADMIN_ID = '00000000-0000-4000-8000-000000000006';
const RESERVICE_ID = '00000000-0000-4000-8000-000000000007';

const approvedClaim = (
  overrides: Partial<GuaranteeClaim> = {},
): GuaranteeClaim =>
  Object.assign(new GuaranteeClaim(), {
    id: CLAIM_ID,
    bookingId: ORIGINAL_ID,
    customerId: CUSTOMER_ID,
    status: GuaranteeClaimStatus.APPROVED,
    description: 'Leaking pipe replaced badly',
    reServiceBookingId: null,
    ...overrides,
  });

const originalBooking = (overrides: Partial<Booking> = {}): Booking =>
  ({
    id: ORIGINAL_ID,
    customerId: CUSTOMER_ID,
    serviceCategoryId: CATEGORY_ID,
    status: BookingStatus.COMPLETED,
    locationLat: 22.3072,
    locationLng: 73.1812,
    items: [
      {
        id: 'sub-1',
        name: 'Tap & Mixer Repair',
        quantity: 1,
        unitPriceMinor: 49900,
        durationMinutes: 60,
      },
    ],
    ...overrides,
  }) as Booking;

describe('GuaranteesService.createReServiceBooking (BUG-011 / SEC-007)', () => {
  let claimsRepository: {
    findOne: jest.Mock;
    createQueryBuilder: jest.Mock;
  };
  let bookingsRepository: { findOne: jest.Mock };
  let bookingsService: {
    createAssignedBooking: jest.Mock<Promise<Booking>, [AssignedBookingInput]>;
  };
  let matchingService: { isProviderQualifiedForCategory: jest.Mock };
  let service: GuaranteesService;
  let claimUpdate: { set: jest.Mock; where: jest.Mock; execute: jest.Mock };

  beforeEach(() => {
    claimUpdate = {
      set: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      execute: jest.fn().mockResolvedValue({ affected: 1 }),
    };
    claimsRepository = {
      findOne: jest.fn(),
      createQueryBuilder: jest.fn().mockReturnValue({
        update: jest.fn().mockReturnValue(claimUpdate),
      }),
    };
    bookingsRepository = { findOne: jest.fn() };
    bookingsService = {
      createAssignedBooking: jest
        .fn<Promise<Booking>, [AssignedBookingInput]>()
        .mockResolvedValue({
          id: RESERVICE_ID,
          status: BookingStatus.ASSIGNED,
          providerId: PROVIDER_ID,
        } as Booking),
    };
    matchingService = {
      isProviderQualifiedForCategory: jest.fn().mockResolvedValue(true),
    };
    service = new GuaranteesService(
      claimsRepository as never,
      bookingsRepository as never,
      bookingsService as never,
      matchingService as never,
    );
  });

  it('creates the re-service through the booking state machine, not a raw INSERT', async () => {
    claimsRepository.findOne.mockResolvedValue(approvedClaim());
    bookingsRepository.findOne.mockResolvedValue(originalBooking());

    const booking = await service.createReServiceBooking(
      CLAIM_ID,
      PROVIDER_ID,
      ADMIN_ID,
    );

    expect(booking.id).toBe(RESERVICE_ID);
    expect(bookingsService.createAssignedBooking).toHaveBeenCalledTimes(1);

    const input = bookingsService.createAssignedBooking.mock.calls[0]?.[0];
    expect(input).toMatchObject({
      customerId: CUSTOMER_ID,
      providerId: PROVIDER_ID,
      serviceCategoryId: CATEGORY_ID,
      idempotencyKey: `guarantee-${CLAIM_ID}`,
      actorUserId: ADMIN_ID,
      isGuaranteeClaim: true,
      parentBookingId: ORIGINAL_ID,
      // Carried forward so the remedy is priced as it was quoted.
      items: originalBooking().items,
    });
  });

  it('refuses a provider who is not a verified provider for the category', async () => {
    claimsRepository.findOne.mockResolvedValue(approvedClaim());
    bookingsRepository.findOne.mockResolvedValue(originalBooking());
    matchingService.isProviderQualifiedForCategory.mockResolvedValue(false);

    await expect(
      service.createReServiceBooking(CLAIM_ID, PROVIDER_ID, ADMIN_ID),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(matchingService.isProviderQualifiedForCategory).toHaveBeenCalledWith(
      PROVIDER_ID,
      CATEGORY_ID,
    );
    expect(bookingsService.createAssignedBooking).not.toHaveBeenCalled();
  });

  it('refuses a claim that already has a re-service booking', async () => {
    claimsRepository.findOne.mockResolvedValue(
      approvedClaim({ reServiceBookingId: RESERVICE_ID }),
    );

    await expect(
      service.createReServiceBooking(CLAIM_ID, PROVIDER_ID, ADMIN_ID),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(bookingsService.createAssignedBooking).not.toHaveBeenCalled();
  });

  it('refuses a claim that has not been approved', async () => {
    claimsRepository.findOne.mockResolvedValue(
      approvedClaim({ status: GuaranteeClaimStatus.PENDING }),
    );

    await expect(
      service.createReServiceBooking(CLAIM_ID, PROVIDER_ID, ADMIN_ID),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(bookingsService.createAssignedBooking).not.toHaveBeenCalled();
  });

  it('refuses a re-service when the original booking has no coordinates', async () => {
    claimsRepository.findOne.mockResolvedValue(approvedClaim());
    bookingsRepository.findOne.mockResolvedValue(
      originalBooking({ locationLat: null, locationLng: null }),
    );

    await expect(
      service.createReServiceBooking(CLAIM_ID, PROVIDER_ID, ADMIN_ID),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(bookingsService.createAssignedBooking).not.toHaveBeenCalled();
  });

  it('claims the re-service slot conditionally and reports the loser of a double submit', async () => {
    claimsRepository.findOne.mockResolvedValue(approvedClaim());
    bookingsRepository.findOne.mockResolvedValue(originalBooking());

    await service.createReServiceBooking(CLAIM_ID, PROVIDER_ID, ADMIN_ID);

    expect(claimUpdate.where).toHaveBeenCalledWith(
      'id = :id AND re_service_booking_id IS NULL AND status = :status',
      { id: CLAIM_ID, status: GuaranteeClaimStatus.APPROVED },
    );
    expect(claimUpdate.set).toHaveBeenCalledWith({
      status: GuaranteeClaimStatus.COMPLETED,
      assignedProviderId: PROVIDER_ID,
      reServiceBookingId: RESERVICE_ID,
    });

    // The genuine race: this request read the claim before anyone else wrote,
    //    then lost the conditional update to a concurrent admin. The read still
    //    shows a free claim, so only the `affected` count reveals the loss.
    claimUpdate.execute.mockResolvedValue({ affected: 0 });
    claimsRepository.findOne
      .mockResolvedValueOnce(approvedClaim())
      .mockResolvedValueOnce(
        approvedClaim({ reServiceBookingId: RESERVICE_ID }),
      );
    await expect(
      service.createReServiceBooking(CLAIM_ID, PROVIDER_ID, ADMIN_ID),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('short-circuits before booking creation when the claim is already taken', async () => {
    claimsRepository.findOne.mockResolvedValue(
      approvedClaim({ reServiceBookingId: RESERVICE_ID }),
    );

    await expect(
      service.createReServiceBooking(CLAIM_ID, PROVIDER_ID, ADMIN_ID),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(bookingsService.createAssignedBooking).not.toHaveBeenCalled();
    expect(claimUpdate.execute).not.toHaveBeenCalled();
  });

  it('does not attach a losing reviewer provider to an existing remedy booking', async () => {
    claimsRepository.findOne.mockResolvedValue(approvedClaim());
    bookingsRepository.findOne.mockResolvedValue(originalBooking());
    bookingsService.createAssignedBooking.mockResolvedValue({
      id: RESERVICE_ID,
      providerId: 'another-provider',
    } as Booking);
    await expect(
      service.createReServiceBooking(CLAIM_ID, PROVIDER_ID, ADMIN_ID),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(claimUpdate.execute).not.toHaveBeenCalled();
  });
});

describe('Guarantee lifecycle and concurrent review', () => {
  const updatedAt = new Date('2026-10-20T12:00:00Z');
  let repository: { findOne: jest.Mock; update: jest.Mock };
  let service: GuaranteesService;

  beforeEach(() => {
    repository = {
      findOne: jest.fn().mockResolvedValue(
        approvedClaim({
          status: GuaranteeClaimStatus.PENDING,
          updatedAt,
          version: 4,
        }),
      ),
      update: jest.fn().mockResolvedValue({ affected: 1 }),
    };
    service = new GuaranteesService(
      repository as never,
      {} as never,
      {} as never,
      {} as never,
    );
  });

  it('rejects reopening a completed claim before writing', async () => {
    repository.findOne.mockResolvedValue(
      approvedClaim({ status: GuaranteeClaimStatus.COMPLETED, updatedAt }),
    );
    await expect(
      service.updateStatus(CLAIM_ID, { status: GuaranteeClaimStatus.PENDING }),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(repository.update).not.toHaveBeenCalled();
  });

  it('compares both previous status and version so stale notes cannot overwrite newer work', async () => {
    await service.updateStatus(CLAIM_ID, {
      status: GuaranteeClaimStatus.IN_REVIEW,
      adminNotes: 'Reviewing evidence',
    });
    expect(repository.update).toHaveBeenCalledWith(
      { id: CLAIM_ID, status: GuaranteeClaimStatus.PENDING, version: 4 },
      {
        status: GuaranteeClaimStatus.IN_REVIEW,
        adminNotes: 'Reviewing evidence',
      },
    );
  });

  it('reports a conflict when another review wins the conditional update', async () => {
    repository.update.mockResolvedValue({ affected: 0 });
    await expect(
      service.updateStatus(CLAIM_ID, { status: GuaranteeClaimStatus.APPROVED }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('requires provider assignment through the validated re-service workflow', async () => {
    await expect(
      service.updateStatus(CLAIM_ID, { assignedProviderId: PROVIDER_ID }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(repository.update).not.toHaveBeenCalled();
  });
});

describe('Guarantee queue pagination', () => {
  it('filters before applying offset and limit, with deterministic ordering', async () => {
    const query = {
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      addOrderBy: jest.fn().mockReturnThis(),
      take: jest.fn().mockReturnThis(),
      skip: jest.fn().mockReturnThis(),
      getMany: jest.fn().mockResolvedValue([]),
    };
    const repository = { createQueryBuilder: jest.fn().mockReturnValue(query) };
    const service = new GuaranteesService(
      repository as never,
      {} as never,
      {} as never,
      {} as never,
    );
    await service.findAll(GuaranteeClaimStatus.PENDING, 21, 40, 'pipe');
    expect(query.where).toHaveBeenCalledWith('claim.status = :status', {
      status: GuaranteeClaimStatus.PENDING,
    });
    expect(query.andWhere).toHaveBeenCalledWith(expect.any(String), {
      search: '%pipe%',
    });
    expect(query.take).toHaveBeenCalledWith(21);
    expect(query.skip).toHaveBeenCalledWith(40);
    expect(query.andWhere.mock.invocationCallOrder[0]).toBeLessThan(
      query.take.mock.invocationCallOrder[0],
    );
    expect(query.addOrderBy).toHaveBeenCalledWith('claim.id', 'DESC');
  });
});
