import { ConflictException } from '@nestjs/common';
import type { ConfigService } from '@nestjs/config';
import { createTestDataSource } from './support/test-data-source';
import { Booking } from '../src/bookings/domain/booking.entity';
import { BookingMessage } from '../src/bookings/domain/booking-message.entity';
import { BookingMessagesService } from '../src/bookings/booking-messages.service';
import {
  GuaranteeClaim,
  GuaranteeClaimStatus,
} from '../src/guarantees/domain/guarantee-claim.entity';
import { GuaranteesService } from '../src/guarantees/guarantees.service';
import {
  Complaint,
  ComplaintTargetRole,
} from '../src/support/complaints/domain/complaint.entity';
import { ComplaintEvidence } from '../src/support/complaints/domain/complaint-evidence.entity';
import { ComplaintAudit } from '../src/support/complaints/domain/complaint-audit.entity';
import { ComplaintsService } from '../src/support/complaints/complaints.service';
import { TrustedEvidenceUrl } from '../src/support/complaints/trusted-evidence-url';

describe('Reconciled domain boundaries on isolated PostgreSQL', () => {
  const ds = createTestDataSource();
  const customer = '00000000-0000-4000-8000-000000000011';
  const provider = '00000000-0000-4000-8000-000000000012';
  const category = '00000000-0000-4000-8000-000000000013';
  const booking = '00000000-0000-4000-8000-000000000014';

  beforeAll(async () => {
    await ds.initialize();
  });
  afterAll(async () => {
    await ds.destroy();
  });
  beforeEach(async () => {
    await ds.query('TRUNCATE users, service_categories CASCADE');
    await ds.query(
      "INSERT INTO users (id, status) VALUES ($1, 'active'), ($2, 'active')",
      [customer, provider],
    );
    await ds.query(
      "INSERT INTO service_categories (id, name, slug) VALUES ($1, 'Reconciliation', 'reconciliation')",
      [category],
    );
    await ds.query(
      "INSERT INTO bookings (id, customer_id, provider_id, service_category_id, status, description, location_lat, location_lng, idempotency_key, request_fingerprint) VALUES ($1, $2, $3, $4, 'ASSIGNED', 'test booking', 22, 73, 'domain-test', 'domain-test')",
      [booking, customer, provider, category],
    );
  });

  it('returns one durable chat row and publishes once under simultaneous retries', async () => {
    const messages = ds.getRepository(BookingMessage);
    const original = messages.findOne.bind(messages);
    let readers = 0;
    let release!: () => void;
    const ready = new Promise<void>((resolve) => {
      release = resolve;
    });
    jest.spyOn(messages, 'findOne').mockImplementation(async (options) => {
      const row = await original(options);
      if (++readers <= 2) {
        if (readers === 2) release();
        await ready;
      }
      return row;
    });
    const projections = {
      publishChatMessage: jest.fn(),
      isSubscriberActive: () => true,
    };
    const service = new BookingMessagesService(
      ds.getRepository(Booking),
      messages,
      projections as never,
      {} as never,
    );
    const send = () =>
      service.sendMessage(booking, customer, {
        clientMessageId: 'retry',
        messageText: 'At the gate',
      });
    const [first, second] = await Promise.all([send(), send()]);
    expect(first.id).toBe(second.id);
    expect(await messages.count()).toBe(1);
    expect(projections.publishChatMessage).toHaveBeenCalledTimes(1);
  });

  it('permits exactly one concurrent guarantee review from the same version', async () => {
    const claims = ds.getRepository(GuaranteeClaim);
    const claim = await claims.save(
      claims.create({
        bookingId: booking,
        customerId: customer,
        description: 'Repair failed',
        status: GuaranteeClaimStatus.PENDING,
      }),
    );
    const original = claims.findOne.bind(claims);
    let readers = 0;
    let release!: () => void;
    const ready = new Promise<void>((resolve) => {
      release = resolve;
    });
    jest.spyOn(claims, 'findOne').mockImplementation(async (options) => {
      const row = await original(options);
      if (++readers <= 2) {
        if (readers === 2) release();
        await ready;
      }
      return row;
    });
    const service = new GuaranteesService(
      claims,
      ds.getRepository(Booking),
      {} as never,
      {} as never,
    );
    const results = await Promise.allSettled([
      service.updateStatus(claim.id, {
        status: GuaranteeClaimStatus.IN_REVIEW,
      }),
      service.updateStatus(claim.id, { status: GuaranteeClaimStatus.APPROVED }),
    ]);
    expect(
      results.filter((result) => result.status === 'fulfilled'),
    ).toHaveLength(1);
    const failure = results.find(
      (result) => result.status === 'rejected',
    ) as PromiseRejectedResult;
    expect(failure.reason).toBeInstanceOf(ConflictException);
    expect((await original({ where: { id: claim.id } }))?.version).toBe(2);
  });

  it('persists general platform support without a booking or arbitrary user target', async () => {
    const service = new ComplaintsService(
      ds.getRepository(Complaint),
      ds.getRepository(ComplaintEvidence),
      ds.getRepository(ComplaintAudit),
      ds.getRepository(Booking),
      new TrustedEvidenceUrl({
        get: () => undefined,
      } as unknown as ConfigService<never, true>),
    );
    const complaint = await service.createComplaint(customer, {
      targetRole: ComplaintTargetRole.PLATFORM,
      category: 'App issue',
      description: 'Settings do not save',
    });
    expect(complaint.bookingId).toBeNull();
    expect(complaint.targetId).toBeNull();
    expect(complaint.submitterId).toBe(customer);
  });

  it('enforces a new NOT VALID foreign key for future writes', async () => {
    await expect(
      ds.query(
        "INSERT INTO recurring_schedules (customer_id, service_category_id, description, location_lat, location_lng, cadence, next_occurrence_at) VALUES ($1, gen_random_uuid(), 'orphan category', 22, 73, 'WEEKLY', now())",
        [customer],
      ),
    ).rejects.toMatchObject({ code: '23503' });
  });

  it('retains authentication audit history when its user is deleted', async () => {
    const [user] = await ds.query<{ id: string }[]>(
      'INSERT INTO users DEFAULT VALUES RETURNING id',
    );
    const [audit] = await ds.query<{ id: string }[]>(
      "INSERT INTO auth_audit_events (user_id, event_type, outcome) VALUES ($1, 'test', 'success') RETURNING id",
      [user.id],
    );
    await ds.query('DELETE FROM users WHERE id=$1', [user.id]);
    const rows = await ds.query<{ user_id: null }[]>(
      'SELECT user_id FROM auth_audit_events WHERE id=$1',
      [audit.id],
    );
    expect(rows).toEqual([{ user_id: null }]);
  });
});
