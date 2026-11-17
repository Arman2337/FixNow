import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomBytes } from 'node:crypto';
import { DataSource, EntityManager } from 'typeorm';
import {
  CreateGroupServiceDto,
  QuoteGroupServiceDto,
} from './group-services.dto';

interface GroupRow {
  id: string;
  organizerId: string;
  requestedAt: Date | null;
  selectedQuoteId: string | null;
  inviteOpen: boolean;
}

export interface QuoteRow {
  id: string;
  groupMinor: number;
  regularMinor: number;
  note: string;
  providerName: string;
  verified: boolean;
}

const groupProjection = `
  g.id, g.category_id AS "categoryId", c.name AS "service",
  g.area, g.description, g.requested_at AS "requestedAt",
  g.selected_quote_id AS "selectedQuoteId",
  (SELECT count(*)::int FROM group_service_members m WHERE m.group_id = g.id) AS "memberCount"
`;

const eligibleProvider = `EXISTS (
  SELECT 1 FROM provider_skills s
  JOIN provider_profiles p ON p.user_id = s.user_id
  JOIN users u ON u.id = s.user_id AND u.status = 'active'
  WHERE s.service_category_id = g.category_id AND s.user_id = $1
)`;

@Injectable()
export class GroupServicesService {
  constructor(private readonly data: DataSource) {}

  categories() {
    return this.data.query<{ id: string; name: string }[]>(
      'SELECT id, name FROM service_categories WHERE is_active AND NOT is_emergency ORDER BY display_order, name',
    );
  }

  listCustomer(userId: string) {
    return this.data.query<object[]>(
      `SELECT ${groupProjection}, (g.organizer_id = $1) AS organizer
       FROM group_service_members m
       JOIN group_service_requests g ON g.id = m.group_id
       JOIN service_categories c ON c.id = g.category_id
       WHERE m.customer_id = $1 ORDER BY g.created_at DESC LIMIT 100`,
      [userId],
    );
  }

  listProvider(userId: string) {
    return this.data.query<object[]>(
      `SELECT ${groupProjection}, q.id AS "ownQuoteId", q.group_minor AS "ownGroupMinor",
         CASE WHEN g.selected_quote_id = q.id THEN organizer.phone END AS "organizerPhone"
       FROM group_service_requests g
       JOIN service_categories c ON c.id = g.category_id
       LEFT JOIN group_service_quotes q ON q.group_id = g.id AND q.provider_id = $1
       JOIN users organizer ON organizer.id = g.organizer_id
       WHERE g.requested_at IS NOT NULL
         AND (q.id IS NOT NULL OR (g.selected_quote_id IS NULL AND c.is_active
           AND NOT c.is_emergency AND ${eligibleProvider}
           AND NOT EXISTS (SELECT 1 FROM group_service_members m WHERE m.group_id = g.id AND m.customer_id = $1)))
       ORDER BY g.created_at DESC LIMIT 100`,
      [userId],
    );
  }

  async create(userId: string, dto: CreateGroupServiceDto) {
    return this.data.transaction(async (tx) => {
      const [group] = await tx.query<{ id: string }[]>(
        `INSERT INTO group_service_requests (organizer_id, category_id, area, description, invite_token, request_key)
         SELECT $1, id, $3, $4, $5, $6 FROM service_categories
         WHERE id = $2 AND is_active AND NOT is_emergency
         ON CONFLICT (organizer_id, request_key) DO NOTHING RETURNING id`,
        [
          userId,
          dto.categoryId,
          dto.area,
          dto.description,
          randomBytes(24).toString('hex'),
          dto.requestKey,
        ],
      );
      if (!group) {
        const [existing] = await tx.query<
          { id: string; sameRequest: boolean }[]
        >(
          `SELECT id, (category_id = $3 AND area = $4 AND description = $5) AS "sameRequest"
           FROM group_service_requests WHERE organizer_id = $1 AND request_key = $2`,
          [userId, dto.requestKey, dto.categoryId, dto.area, dto.description],
        );
        if (!existing)
          throw new NotFoundException('Group service category unavailable');
        if (!existing.sameRequest)
          throw new ConflictException(
            'This group creation key was already used',
          );
        return { id: existing.id };
      }
      await tx.query('INSERT INTO group_service_members VALUES ($1, $2)', [
        group.id,
        userId,
      ]);
      return group;
    });
  }

  async detail(userId: string, id: string) {
    return this.data.transaction('REPEATABLE READ', async (tx) => {
      const [group] = await tx.query<object[]>(
        `SELECT ${groupProjection}, (g.organizer_id = $1) AS organizer,
           CASE WHEN g.organizer_id = $1 AND g.requested_at IS NULL
             AND g.created_at > now() - interval '7 days' THEN g.invite_token END AS "inviteToken",
           CASE WHEN g.organizer_id = $1 THEN provider.phone END AS "providerPhone"
         FROM group_service_requests g
         JOIN group_service_members m ON m.group_id = g.id AND m.customer_id = $1
         JOIN service_categories c ON c.id = g.category_id
         LEFT JOIN group_service_quotes selected ON selected.id = g.selected_quote_id
         LEFT JOIN users provider ON provider.id = selected.provider_id AND provider.status = 'active'
         WHERE g.id = $2`,
        [userId, id],
      );
      if (!group) throw new NotFoundException('Group unavailable');
      const quotes = await tx.query<QuoteRow[]>(
        `SELECT q.id, q.group_minor AS "groupMinor", q.regular_minor AS "regularMinor",
           q.note, COALESCE(p.display_name, 'Service provider') AS "providerName",
           COALESCE(a.status = 'approved', false) AS verified
         FROM group_service_quotes q
         LEFT JOIN provider_profiles p ON p.user_id = q.provider_id
         LEFT JOIN provider_applications a ON a.user_id = q.provider_id
         WHERE q.group_id = $1 ORDER BY q.group_minor, q.id`,
        [id],
      );
      return { ...group, quotes };
    });
  }

  async join(userId: string, token: string) {
    return this.data.transaction(async (tx) => {
      const group = await this.lock(tx, 'invite_token', token);
      const [existing] = await tx.query<{ found: boolean }[]>(
        'SELECT true AS found FROM group_service_members WHERE group_id = $1 AND customer_id = $2',
        [group.id, userId],
      );
      if (existing) return { id: group.id };
      if (!group.inviteOpen || group.requestedAt)
        throw new ConflictException(
          'This group is no longer accepting members',
        );
      const [count] = await tx.query<{ count: number }[]>(
        'SELECT count(*)::int AS count FROM group_service_members WHERE group_id = $1',
        [group.id],
      );
      if (count.count >= 50) throw new ConflictException('This group is full');
      await tx.query('INSERT INTO group_service_members VALUES ($1, $2)', [
        group.id,
        userId,
      ]);
      return { id: group.id };
    });
  }

  async request(userId: string, id: string) {
    return this.data.transaction(async (tx) => {
      const group = await this.lock(tx, 'id', id);
      if (group.organizerId !== userId)
        throw new NotFoundException('Group unavailable');
      if (group.requestedAt) return { id };
      const [ready] = await tx.query<{ id: string }[]>(
        `WITH updated AS (
           UPDATE group_service_requests g SET requested_at = now()
           FROM service_categories c WHERE g.id = $1 AND c.id = g.category_id
             AND c.is_active AND NOT c.is_emergency
             AND (SELECT count(*) FROM group_service_members m WHERE m.group_id = g.id) >= 2
           RETURNING g.id
         ) SELECT id FROM updated`,
        [id],
      );
      if (!ready)
        throw new ConflictException(
          'Invite at least one other customer and choose an available service',
        );
      return ready;
    });
  }

  async quote(userId: string, id: string, dto: QuoteGroupServiceDto) {
    if (dto.groupMinor >= dto.regularMinor)
      throw new BadRequestException(
        'The group price must be below your regular price',
      );
    return this.data.transaction(async (tx) => {
      const group = await this.lock(tx, 'id', id);
      const [existing] = await tx.query<QuoteRow[]>(
        `SELECT id, group_minor AS "groupMinor", regular_minor AS "regularMinor", note
         FROM group_service_quotes WHERE group_id = $1 AND provider_id = $2`,
        [id, userId],
      );
      if (existing) {
        if (
          existing.groupMinor === dto.groupMinor &&
          existing.regularMinor === dto.regularMinor &&
          existing.note === dto.note
        )
          return { id: existing.id };
        throw new ConflictException(
          'You have already submitted a quote for this group',
        );
      }
      if (!group.requestedAt || group.selectedQuoteId)
        throw new NotFoundException('Group unavailable for quotes');
      const [eligible] = await tx.query<{ id: string }[]>(
        `SELECT g.id FROM group_service_requests g JOIN service_categories c ON c.id = g.category_id
         WHERE g.id = $2 AND c.is_active AND NOT c.is_emergency AND ${eligibleProvider}
           AND NOT EXISTS (SELECT 1 FROM group_service_members m WHERE m.group_id = g.id AND m.customer_id = $1)`,
        [userId, id],
      );
      if (!eligible)
        throw new NotFoundException('Group unavailable for quotes');
      const [count] = await tx.query<{ count: number }[]>(
        'SELECT count(*)::int AS count FROM group_service_quotes WHERE group_id = $1',
        [id],
      );
      if (count.count >= 100)
        throw new ConflictException('This group has reached its quote limit');
      const [quote] = await tx.query<{ id: string }[]>(
        `INSERT INTO group_service_quotes (group_id, provider_id, regular_minor, group_minor, note)
         VALUES ($1, $2, $3, $4, $5) RETURNING id`,
        [id, userId, dto.regularMinor, dto.groupMinor, dto.note],
      );
      return quote;
    });
  }

  async select(userId: string, id: string, quoteId: string) {
    return this.data.transaction(async (tx) => {
      const group = await this.lock(tx, 'id', id);
      if (group.organizerId !== userId || !group.requestedAt)
        throw new NotFoundException('Group unavailable');
      if (group.selectedQuoteId === quoteId) return { id };
      if (group.selectedQuoteId)
        throw new ConflictException('A quote has already been selected');
      const [quote] = await tx.query<{ id: string }[]>(
        `SELECT q.id FROM group_service_quotes q JOIN users u ON u.id = q.provider_id
         WHERE q.id = $1 AND q.group_id = $2 AND u.status = 'active' FOR SHARE OF u`,
        [quoteId, id],
      );
      if (!quote)
        throw new NotFoundException('This quote is no longer available');
      await tx.query(
        'UPDATE group_service_requests SET selected_quote_id = $2 WHERE id = $1',
        [id, quoteId],
      );
      return { id };
    });
  }

  private async lock(
    tx: EntityManager,
    field: 'id' | 'invite_token',
    value: string,
  ): Promise<GroupRow> {
    const [group] = await tx.query<GroupRow[]>(
      `SELECT id, organizer_id AS "organizerId", requested_at AS "requestedAt",
         selected_quote_id AS "selectedQuoteId", created_at > now() - interval '7 days' AS "inviteOpen"
       FROM group_service_requests WHERE ${field} = $1 FOR UPDATE`,
      [value],
    );
    if (!group) throw new NotFoundException('Group unavailable');
    return group;
  }
}
