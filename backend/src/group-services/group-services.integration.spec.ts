import { ConflictException, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { DataSource } from 'typeorm';
import { createTestDataSource } from '../../test/support/test-data-source';
import { GroupServicesService } from './group-services.service';

describe('Group services (PostgreSQL)', () => {
  let db: DataSource;
  let service: GroupServicesService;
  const [organizer, member, stranger, firstProvider, secondProvider] =
    Array.from({ length: 5 }, () => randomUUID());
  const categoryId = randomUUID();
  const organizerPhone = '+919000001701';
  const providerPhone = '+919000001702';

  beforeAll(async () => {
    db = await createTestDataSource().initialize();
    service = new GroupServicesService(db);
    await db.query(
      `INSERT INTO users (id, status, phone) VALUES ($1, 'active', $6),
       ($2, 'active', NULL), ($3, 'active', NULL), ($4, 'active', $7), ($5, 'active', NULL)`,
      [
        organizer,
        member,
        stranger,
        firstProvider,
        secondProvider,
        organizerPhone,
        providerPhone,
      ],
    );
    await db.query(
      'INSERT INTO service_categories (id, name, slug) VALUES ($1, $2, $3)',
      [categoryId, `Group AC ${categoryId}`, `group-ac-${categoryId}`],
    );
    await db.query(
      `INSERT INTO provider_profiles (user_id, display_name, service_radius_km, base_latitude, base_longitude)
       VALUES ($1, 'First AC Provider', 10, 12, 77), ($2, 'Second AC Provider', 10, 12, 77)`,
      [firstProvider, secondProvider],
    );
    await db.query(
      'INSERT INTO provider_skills (user_id, service_category_id) VALUES ($1, $3), ($2, $3)',
      [firstProvider, secondProvider, categoryId],
    );
    await db.query(
      "INSERT INTO provider_applications (user_id, status) VALUES ($1, 'unverified'), ($2, 'approved')",
      [firstProvider, secondProvider],
    );
  });

  afterAll(async () => {
    if (!db?.isInitialized) return;
    await db.transaction(async (tx) => {
      await tx.query(
        'DELETE FROM group_service_requests WHERE category_id = $1',
        [categoryId],
      );
      await tx.query('DELETE FROM service_categories WHERE id = $1', [
        categoryId,
      ]);
      await tx.query('DELETE FROM users WHERE id = ANY($1::uuid[])', [
        [organizer, member, stranger, firstProvider, secondProvider],
      ]);
    });
    await db.destroy();
  });

  it('keeps invitations, competing quotes, selection and contacts scoped to their parties', async () => {
    const input = {
      categoryId,
      area: 'Indiranagar',
      description: 'One split AC cleaning per household',
      requestKey: 'a'.repeat(32),
    };
    const [{ id }, retry] = await Promise.all([
      service.create(organizer, input),
      service.create(organizer, input),
    ]);
    expect(retry.id).toBe(id);
    const draft = (await service.detail(organizer, id)) as {
      inviteToken: string;
    };
    expect(draft.inviteToken).toHaveLength(48);
    await expect(service.detail(stranger, id)).rejects.toBeInstanceOf(
      NotFoundException,
    );
    await expect(service.request(organizer, id)).rejects.toBeInstanceOf(
      ConflictException,
    );
    await Promise.all([
      service.join(member, draft.inviteToken),
      service.join(member, draft.inviteToken),
    ]);
    await expect(service.request(member, id)).rejects.toBeInstanceOf(
      NotFoundException,
    );
    await service.request(organizer, id);
    await expect(
      service.join(stranger, draft.inviteToken),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(await service.listProvider(firstProvider)).toEqual([
      expect.objectContaining({ id, memberCount: 2, ownQuoteId: null }),
    ]);

    const firstTerms = {
      regularMinor: 100000,
      groupMinor: 75000,
      note: 'Filter and coil cleaning',
    };
    await expect(
      service.quote(stranger, id, firstTerms),
    ).rejects.toBeInstanceOf(NotFoundException);
    const [firstQuote, secondQuote] = await Promise.all([
      service.quote(firstProvider, id, firstTerms),
      service.quote(secondProvider, id, { ...firstTerms, groupMinor: 85000 }),
    ]);
    expect(await service.quote(firstProvider, id, firstTerms)).toEqual(
      firstQuote,
    );
    expect(await service.detail(member, id)).toMatchObject({
      inviteToken: null,
      memberCount: 2,
      providerPhone: null,
      quotes: [
        expect.objectContaining({
          id: firstQuote.id,
          groupMinor: 75000,
          verified: false,
        }),
        expect.objectContaining({
          id: secondQuote.id,
          groupMinor: 85000,
          verified: true,
        }),
      ],
    });
    await expect(
      service.select(member, id, firstQuote.id),
    ).rejects.toBeInstanceOf(NotFoundException);
    await service.select(organizer, id, firstQuote.id);
    await expect(
      service.select(organizer, id, secondQuote.id),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(await service.detail(organizer, id)).toMatchObject({
      selectedQuoteId: firstQuote.id,
      providerPhone,
    });
    expect(await service.detail(member, id)).toMatchObject({
      selectedQuoteId: firstQuote.id,
      providerPhone: null,
    });
    expect(await service.listProvider(firstProvider)).toEqual([
      expect.objectContaining({ organizerPhone }),
    ]);
    expect(await service.listProvider(secondProvider)).toEqual([
      expect.objectContaining({ organizerPhone: null }),
    ]);
  });
});
