import { NotFoundException } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { DataSource } from 'typeorm';
import { createTestDataSource } from '../../test/support/test-data-source';
import type { AuthorizationPrincipal } from '../common/authorization/authorization.types';
import { PaymentOrder } from './domain/payment-order.entity';
import { FakePaymentGateway } from './payment-gateway';
import { PaymentsService } from './payments.service';

describe('Group checkout (PostgreSQL)', () => {
  const [owner, member, outsider, provider, categoryId, groupId, quoteId] =
    Array.from({ length: 7 }, () => randomUUID());
  const principal = (userId: string): AuthorizationPrincipal => ({
    userId,
    sessionId: 'integration-session',
    roles: ['customer'],
  });
  let db: DataSource;
  let payments: PaymentsService;

  beforeAll(async () => {
    db = await createTestDataSource().initialize();
    const gateway = new FakePaymentGateway();
    Object.defineProperty(gateway, 'capturedUpiOnly', { value: true });
    payments = new PaymentsService(db, db.getRepository(PaymentOrder), gateway);
    await db.query(
      "INSERT INTO users (id, status) SELECT id, 'active' FROM unnest($1::uuid[]) AS id",
      [[owner, member, outsider, provider]],
    );
    await db.query(
      'INSERT INTO service_categories (id, name, slug) VALUES ($1, $2, $2)',
      [categoryId, `ac-${categoryId}`],
    );
    await db.query(
      `INSERT INTO group_service_requests
       (id, organizer_id, category_id, area, description, request_key, invite_token, requested_at)
       VALUES ($1, $2, $3, 'Test area', 'AC cleaning', $4, $5, now())`,
      [
        groupId,
        owner,
        categoryId,
        groupId.replaceAll('-', ''),
        randomUUID().replaceAll('-', '') + 'a'.repeat(16),
      ],
    );
    await db.query(
      'INSERT INTO group_service_members VALUES ($1, $2), ($1, $3)',
      [groupId, owner, member],
    );
    await db.query(
      `INSERT INTO group_service_quotes
       (id, group_id, provider_id, regular_minor, group_minor, note)
       VALUES ($1, $2, $3, 100000, 75000, 'AC cleaning')`,
      [quoteId, groupId, provider],
    );
    await db.query(
      'UPDATE group_service_requests SET selected_quote_id = $2 WHERE id = $1',
      [groupId, quoteId],
    );
  });

  afterAll(async () => {
    if (!db?.isInitialized) return;
    await db.transaction(async (tx) => {
      await tx.query('DELETE FROM payment_orders WHERE group_service_id = $1', [
        groupId,
      ]);
      await tx.query('DELETE FROM group_service_requests WHERE id = $1', [
        groupId,
      ]);
      await tx.query('DELETE FROM service_categories WHERE id = $1', [
        categoryId,
      ]);
      await tx.query('DELETE FROM users WHERE id = ANY($1::uuid[])', [
        [owner, member, outsider, provider],
      ]);
    });
    await db.destroy();
  });

  it('keeps each household order, captured status, and invoice independently scoped', async () => {
    await expect(
      payments.groupOrder(outsider, groupId, principal(outsider), true),
    ).rejects.toBeInstanceOf(NotFoundException);
    await expect(
      payments.groupOrder(owner, groupId, principal(owner)),
    ).resolves.toBeNull();
    const [first, retry, second] = await Promise.all([
      payments.groupOrder(owner, groupId, principal(owner), true),
      payments.groupOrder(owner, groupId, principal(owner), true),
      payments.groupOrder(member, groupId, principal(member), true),
    ]);
    expect(first).toMatchObject({
      groupServiceId: groupId,
      bookingId: null,
      amountMinor: 75000,
      status: 'CREATED',
    });
    expect(retry?.id).toBe(first?.id);
    expect(second?.id).not.toBe(first?.id);
    const body = JSON.stringify({
      event: 'payment.captured',
      payload: {
        payment: {
          entity: {
            id: 'pay_group_capture',
            order_id: first!.gatewayOrderId,
            amount: 75000,
            currency: 'INR',
            method: 'upi',
          },
        },
      },
    });
    await payments.processWebhook(body, `fake-${body.length}`);
    await expect(
      payments.groupOrder(owner, groupId, principal(owner)),
    ).resolves.toMatchObject({ status: 'PAID' });
    await expect(
      payments.groupOrder(member, groupId, principal(member)),
    ).resolves.toMatchObject({ status: 'CREATED' });
    await expect(
      payments.getInvoice(owner, first!.id, principal(owner)),
    ).resolves.toMatchObject({ amountMinor: 75000 });
    await expect(
      payments.getInvoice(member, first!.id, principal(member)),
    ).rejects.toBeInstanceOf(NotFoundException);
    await expect(payments.providerEarnings(provider)).resolves.toMatchObject({
      paidOrderCount: 1,
      grossMinor: 75000,
    });
  });
});
