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
  serviceStatus: string;
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

export interface GroupMemberRow {
  customerId: string;
  displayName: string;
  phone: string | null;
  serviceAddress: string | null;
  status: 'pending' | 'approved' | 'rejected';
  organizer: boolean;
  joinedAt: Date;
}

const VALID_PROVIDER_STATUS_NEXT: Readonly<
  Record<string, readonly ('SCHEDULED' | 'IN_PROGRESS' | 'COMPLETED')[]>
> = {
  PROVIDER_SELECTED: ['SCHEDULED', 'IN_PROGRESS', 'COMPLETED'],
  SCHEDULED: ['IN_PROGRESS', 'COMPLETED'],
  IN_PROGRESS: ['COMPLETED'],
  COMPLETED: [],
};

const groupProjection = `
  g.id, g.category_id AS "categoryId", c.name AS "service",
  g.area, g.service_address AS "serviceAddress",
  g.preferred_schedule AS "preferredSchedule",
  g.description, g.requested_at AS "requestedAt",
  g.selected_quote_id AS "selectedQuoteId",
  g.service_status AS "serviceStatus",
  (SELECT count(*)::int FROM group_service_members m WHERE m.group_id = g.id AND m.status = 'approved') AS "memberCount",
  (SELECT count(*)::int FROM group_service_members m WHERE m.group_id = g.id AND m.status = 'pending') AS "pendingMemberCount"
`;

const legacyServiceStatusSql = `CASE
  WHEN g.selected_quote_id IS NOT NULL THEN 'PROVIDER_SELECTED'
  WHEN g.requested_at IS NOT NULL THEN 'COLLECTING_QUOTES'
  ELSE 'INVITING'
END`;

const legacyGroupProjection = `
  g.id, g.category_id AS "categoryId", c.name AS "service",
  g.area, NULL::varchar AS "serviceAddress",
  NULL::varchar AS "preferredSchedule",
  g.description, g.requested_at AS "requestedAt",
  g.selected_quote_id AS "selectedQuoteId",
  ${legacyServiceStatusSql} AS "serviceStatus",
  (SELECT count(*)::int FROM group_service_members m WHERE m.group_id = g.id) AS "memberCount",
  0::int AS "pendingMemberCount"
`;

const eligibleProvider = `EXISTS (
  SELECT 1 FROM provider_skills s
  JOIN provider_profiles p ON p.user_id = s.user_id
  JOIN users u ON u.id = s.user_id AND u.status = 'active'
  WHERE s.service_category_id = g.category_id AND s.user_id = $1
)`;

const SCHEMA_RECHECK_MS = 15_000;

@Injectable()
export class GroupServicesService {
  private enhancedSchemaVerified = false;
  private lastSchemaCheckMs = 0;

  constructor(private readonly data: DataSource) {}

  private async hasEnhancedSchema(): Promise<boolean> {
    if (this.enhancedSchemaVerified) return true;
    const now = Date.now();
    if (
      this.lastSchemaCheckMs > 0 &&
      now - this.lastSchemaCheckMs < SCHEMA_RECHECK_MS
    ) {
      return false;
    }
    this.lastSchemaCheckMs = now;
    try {
      const rows = await this.data.query<{ count: number }[]>(
        `SELECT count(*)::int AS count
         FROM information_schema.columns
         WHERE table_schema = current_schema()
           AND ((table_name = 'group_service_requests'
                 AND column_name IN ('service_address', 'preferred_schedule', 'service_status'))
             OR (table_name = 'group_service_members'
                 AND column_name IN ('status', 'service_address', 'joined_at')))`,
      );
      const ready = Number(rows[0]?.count ?? 0) === 6;
      if (ready) this.enhancedSchemaVerified = true;
      return ready;
    } catch {
      return false;
    }
  }

  categories() {
    return this.data.query<{ id: string; name: string }[]>(
      'SELECT id, name FROM service_categories WHERE is_active AND NOT is_emergency ORDER BY display_order, name',
    );
  }

  async listCustomer(userId: string) {
    const enhanced = await this.hasEnhancedSchema();
    if (!enhanced) {
      return this.data.query<object[]>(
        `SELECT ${legacyGroupProjection},
           (g.organizer_id = $1) AS organizer,
           'approved'::varchar AS "membershipStatus",
           NULL::varchar AS "myServiceAddress"
         FROM group_service_members m
         JOIN group_service_requests g ON g.id = m.group_id
         JOIN service_categories c ON c.id = g.category_id
         WHERE m.customer_id = $1
         ORDER BY g.created_at DESC LIMIT 100`,
        [userId],
      );
    }
    return this.data.query<object[]>(
      `SELECT ${groupProjection},
         (g.organizer_id = $1) AS organizer,
         m.status AS "membershipStatus",
         m.service_address AS "myServiceAddress"
       FROM group_service_members m
       JOIN group_service_requests g ON g.id = m.group_id
       JOIN service_categories c ON c.id = g.category_id
       WHERE m.customer_id = $1 AND m.status != 'rejected'
       ORDER BY g.created_at DESC LIMIT 100`,
      [userId],
    );
  }

  async listProvider(userId: string) {
    const enhanced = await this.hasEnhancedSchema();
    if (!enhanced) {
      const groups = await this.data.query<
        Array<{
          id: string;
          ownQuoteId: string | null;
          selectedQuoteId: string | null;
          [key: string]: unknown;
        }>
      >(
        `SELECT ${legacyGroupProjection},
           q.id AS "ownQuoteId",
           q.group_minor AS "ownGroupMinor",
           q.regular_minor AS "ownRegularMinor",
           q.note AS "ownNote",
           COALESCE(org_profile.display_name, 'Organizer') AS "organizerName",
           CASE WHEN g.selected_quote_id = q.id THEN organizer.phone END AS "organizerPhone"
         FROM group_service_requests g
         JOIN service_categories c ON c.id = g.category_id
         LEFT JOIN group_service_quotes q ON q.group_id = g.id AND q.provider_id = $1
         JOIN users organizer ON organizer.id = g.organizer_id
         LEFT JOIN customer_profiles org_profile ON org_profile.user_id = g.organizer_id
         WHERE g.requested_at IS NOT NULL
           AND (q.id IS NOT NULL OR (g.selected_quote_id IS NULL AND c.is_active
             AND NOT c.is_emergency AND ${eligibleProvider}
             AND NOT EXISTS (SELECT 1 FROM group_service_members m WHERE m.group_id = g.id AND m.customer_id = $1)))
         ORDER BY g.created_at DESC LIMIT 100`,
        [userId],
      );
      return groups.map((g) => ({ ...g, members: [] }));
    }

    const groups = await this.data.query<
      Array<{
        id: string;
        ownQuoteId: string | null;
        selectedQuoteId: string | null;
        [key: string]: unknown;
      }>
    >(
      `SELECT ${groupProjection},
         q.id AS "ownQuoteId",
         q.group_minor AS "ownGroupMinor",
         q.regular_minor AS "ownRegularMinor",
         q.note AS "ownNote",
         COALESCE(org_profile.display_name, 'Organizer') AS "organizerName",
         CASE WHEN g.selected_quote_id = q.id THEN organizer.phone END AS "organizerPhone",
         CASE WHEN g.selected_quote_id = q.id THEN g.service_address END AS "selectedServiceAddress"
       FROM group_service_requests g
       JOIN service_categories c ON c.id = g.category_id
       LEFT JOIN group_service_quotes q ON q.group_id = g.id AND q.provider_id = $1
       JOIN users organizer ON organizer.id = g.organizer_id
       LEFT JOIN customer_profiles org_profile ON org_profile.user_id = g.organizer_id
       WHERE g.requested_at IS NOT NULL
         AND (q.id IS NOT NULL OR (g.selected_quote_id IS NULL AND c.is_active
           AND NOT c.is_emergency AND ${eligibleProvider}
           AND NOT EXISTS (SELECT 1 FROM group_service_members m WHERE m.group_id = g.id AND m.customer_id = $1)))
       ORDER BY g.created_at DESC LIMIT 100`,
      [userId],
    );

    const selectedGroupIds = groups
      .filter((g) => g.ownQuoteId != null && g.selectedQuoteId === g.ownQuoteId)
      .map((g) => g.id);

    const membersByGroup = new Map<string, GroupMemberRow[]>();
    if (selectedGroupIds.length > 0) {
      const memberRows = await this.data.query<
        (GroupMemberRow & { groupId: string })[]
      >(
        `SELECT m.group_id AS "groupId",
           m.customer_id AS "customerId",
           COALESCE(cp.display_name, 'Customer') AS "displayName",
           u.phone,
           m.service_address AS "serviceAddress",
           m.status,
           (m.customer_id = g.organizer_id) AS organizer,
           m.joined_at AS "joinedAt"
         FROM group_service_members m
         JOIN group_service_requests g ON g.id = m.group_id
         JOIN users u ON u.id = m.customer_id
         LEFT JOIN customer_profiles cp ON cp.user_id = m.customer_id
         WHERE m.group_id = ANY($1::uuid[]) AND m.status = 'approved'
         ORDER BY (m.customer_id = g.organizer_id) DESC, m.joined_at ASC`,
        [selectedGroupIds],
      );
      for (const row of memberRows) {
        const list = membersByGroup.get(row.groupId) ?? [];
        list.push(row);
        membersByGroup.set(row.groupId, list);
      }
    }

    return groups.map((g) => {
      const { selectedServiceAddress, ...rest } = g;
      const isWinner =
        g.ownQuoteId != null && g.selectedQuoteId === g.ownQuoteId;
      return {
        ...rest,
        // Keep street address masked until this provider's quote wins; expose area/schedule upfront.
        serviceAddress: isWinner ? (selectedServiceAddress ?? g.area) : null,
        members: isWinner ? (membersByGroup.get(g.id) ?? []) : [],
      };
    });
  }

  async create(userId: string, dto: CreateGroupServiceDto) {
    const enhanced = await this.hasEnhancedSchema();
    return this.data.transaction(async (tx) => {
      const [group] = enhanced
        ? await tx.query<{ id: string }[]>(
            `INSERT INTO group_service_requests (
               organizer_id, category_id, area, service_address, preferred_schedule,
               description, invite_token, request_key, service_status
             )
             SELECT $1, id, $3, $4, $5, $6, $7, $8, 'INVITING'
             FROM service_categories
             WHERE id = $2 AND is_active AND NOT is_emergency
             ON CONFLICT (organizer_id, request_key) DO NOTHING RETURNING id`,
            [
              userId,
              dto.categoryId,
              dto.area,
              dto.serviceAddress ?? null,
              dto.preferredSchedule ?? null,
              dto.description,
              randomBytes(24).toString('hex'),
              dto.requestKey,
            ],
          )
        : await tx.query<{ id: string }[]>(
            `INSERT INTO group_service_requests (
               organizer_id, category_id, area, description, invite_token, request_key
             )
             SELECT $1, id, $3, $4, $5, $6
             FROM service_categories
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
      if (enhanced) {
        await tx.query(
          `INSERT INTO group_service_members (group_id, customer_id, status, service_address, reviewed_at)
           VALUES ($1, $2, 'approved', $3, now())`,
          [group.id, userId, dto.serviceAddress ?? null],
        );
      } else {
        await tx.query(
          'INSERT INTO group_service_members (group_id, customer_id) VALUES ($1, $2)',
          [group.id, userId],
        );
      }
      return group;
    });
  }

  async detail(userId: string, id: string): Promise<Record<string, unknown>> {
    const enhanced = await this.hasEnhancedSchema();
    return this.data.transaction('REPEATABLE READ', async (tx) => {
      if (!enhanced) {
        const [group] = await tx.query<
          { id: string; [key: string]: unknown }[]
        >(
          `SELECT ${legacyGroupProjection},
             (g.organizer_id = $1) AS organizer,
             'approved'::varchar AS "membershipStatus",
             NULL::varchar AS "myServiceAddress",
             COALESCE(org_profile.display_name, 'Organizer') AS "organizerName",
             CASE WHEN g.requested_at IS NULL
               AND g.created_at > now() - interval '7 days' THEN g.invite_token END AS "inviteToken",
             provider.phone AS "providerPhone"
           FROM group_service_requests g
           JOIN group_service_members m ON m.group_id = g.id AND m.customer_id = $1
           JOIN service_categories c ON c.id = g.category_id
           LEFT JOIN customer_profiles org_profile ON org_profile.user_id = g.organizer_id
           LEFT JOIN group_service_quotes selected ON selected.id = g.selected_quote_id
           LEFT JOIN users provider ON provider.id = selected.provider_id AND provider.status = 'active'
           WHERE g.id = $2`,
          [userId, id],
        );
        if (!group) throw new NotFoundException('Group unavailable');
        const quotes = await this.loadQuotes(tx, id);
        return { ...group, quotes, members: [] };
      }

      const [group] = await tx.query<
        {
          id: string;
          organizer: boolean;
          membershipStatus: 'pending' | 'approved' | 'rejected';
          serviceAddress: string | null;
          [key: string]: unknown;
        }[]
      >(
        `SELECT ${groupProjection},
           (g.organizer_id = $1) AS organizer,
           m.status AS "membershipStatus",
           m.service_address AS "myServiceAddress",
           COALESCE(org_profile.display_name, 'Organizer') AS "organizerName",
           CASE WHEN (g.organizer_id = $1 OR m.status = 'approved')
             AND g.requested_at IS NULL
             AND g.created_at > now() - interval '7 days' THEN g.invite_token END AS "inviteToken",
           CASE WHEN (g.organizer_id = $1 OR m.status = 'approved') THEN provider.phone END AS "providerPhone"
         FROM group_service_requests g
         JOIN group_service_members m ON m.group_id = g.id AND m.customer_id = $1 AND m.status != 'rejected'
         JOIN service_categories c ON c.id = g.category_id
         LEFT JOIN customer_profiles org_profile ON org_profile.user_id = g.organizer_id
         LEFT JOIN group_service_quotes selected ON selected.id = g.selected_quote_id
         LEFT JOIN users provider ON provider.id = selected.provider_id AND provider.status = 'active'
         WHERE g.id = $2`,
        [userId, id],
      );
      if (!group) throw new NotFoundException('Group unavailable');

      const approvedOrOrganizer =
        group.organizer || group.membershipStatus === 'approved';
      if (!approvedOrOrganizer) {
        return {
          ...group,
          serviceAddress: null,
          quotes: [],
          members: [],
        };
      }

      const quotes = await this.loadQuotes(tx, id);

      const members = await tx.query<GroupMemberRow[]>(
        `SELECT m.customer_id AS "customerId",
           COALESCE(cp.display_name, 'Customer') AS "displayName",
           CASE WHEN g.organizer_id = $2 THEN u.phone END AS phone,
           m.service_address AS "serviceAddress",
           m.status,
           (m.customer_id = g.organizer_id) AS organizer,
           m.joined_at AS "joinedAt"
         FROM group_service_members m
         JOIN group_service_requests g ON g.id = m.group_id
         JOIN users u ON u.id = m.customer_id
         LEFT JOIN customer_profiles cp ON cp.user_id = m.customer_id
         WHERE m.group_id = $1
           AND (m.status = 'approved' OR (g.organizer_id = $2 AND m.status = 'pending'))
         ORDER BY (m.status = 'pending') DESC, (m.customer_id = g.organizer_id) DESC, m.joined_at ASC`,
        [id, userId],
      );

      return { ...group, quotes, members };
    });
  }

  private loadQuotes(tx: EntityManager, id: string) {
    return tx.query<QuoteRow[]>(
      `SELECT q.id, q.group_minor AS "groupMinor", q.regular_minor AS "regularMinor",
         q.note, COALESCE(p.display_name, 'Service provider') AS "providerName",
         COALESCE(a.status = 'approved', false) AS verified
       FROM group_service_quotes q
       LEFT JOIN provider_profiles p ON p.user_id = q.provider_id
       LEFT JOIN provider_applications a ON a.user_id = q.provider_id
       WHERE q.group_id = $1 ORDER BY q.group_minor, q.id`,
      [id],
    );
  }

  async join(userId: string, token: string, serviceAddress?: string) {
    const enhanced = await this.hasEnhancedSchema();
    return this.data.transaction(async (tx) => {
      const group = await this.lock(tx, 'invite_token', token, enhanced);
      if (!enhanced) {
        const [existing] = await tx.query<{ group_id: string }[]>(
          'SELECT group_id FROM group_service_members WHERE group_id = $1 AND customer_id = $2',
          [group.id, userId],
        );
        if (existing) return { id: group.id, membershipStatus: 'approved' };
        if (!group.inviteOpen || group.requestedAt)
          throw new ConflictException(
            'This group is no longer accepting members',
          );
        const [count] = await tx.query<{ count: number }[]>(
          'SELECT count(*)::int AS count FROM group_service_members WHERE group_id = $1',
          [group.id],
        );
        if (count.count >= 50)
          throw new ConflictException('This group is full');
        await tx.query(
          'INSERT INTO group_service_members (group_id, customer_id) VALUES ($1, $2)',
          [group.id, userId],
        );
        return { id: group.id, membershipStatus: 'approved' };
      }

      const [existing] = await tx.query<{ status: string }[]>(
        'SELECT status FROM group_service_members WHERE group_id = $1 AND customer_id = $2',
        [group.id, userId],
      );
      if (existing) {
        if (existing.status === 'rejected') {
          throw new ConflictException(
            'Your request to join this group was declined',
          );
        }
        return { id: group.id, membershipStatus: existing.status };
      }
      if (!group.inviteOpen || group.requestedAt)
        throw new ConflictException(
          'This group is no longer accepting members',
        );
      const [count] = await tx.query<{ count: number }[]>(
        `SELECT count(*)::int AS count FROM group_service_members
         WHERE group_id = $1 AND status IN ('approved', 'pending')`,
        [group.id],
      );
      if (count.count >= 50) throw new ConflictException('This group is full');
      await tx.query(
        `INSERT INTO group_service_members (group_id, customer_id, status, service_address)
         VALUES ($1, $2, 'pending', $3)`,
        [group.id, userId, serviceAddress ?? null],
      );
      return { id: group.id, membershipStatus: 'pending' };
    });
  }

  async approveMember(userId: string, groupId: string, memberId: string) {
    if (!(await this.hasEnhancedSchema())) {
      throw new ConflictException(
        'Group member approvals are unavailable until database migrations complete',
      );
    }
    return this.data.transaction(async (tx) => {
      const group = await this.lock(tx, 'id', groupId, true);
      if (group.organizerId !== userId)
        throw new NotFoundException('Group unavailable');
      if (group.requestedAt)
        throw new ConflictException(
          'Members cannot be changed after quotes are requested',
        );
      const [count] = await tx.query<{ count: number }[]>(
        `SELECT count(*)::int AS count FROM group_service_members
         WHERE group_id = $1 AND status = 'approved'`,
        [groupId],
      );
      if (count.count >= 50) throw new ConflictException('This group is full');
      const [updated] = await tx.query<{ customerId: string }[]>(
        `UPDATE group_service_members
         SET status = 'approved', reviewed_at = now()
         WHERE group_id = $1 AND customer_id = $2 AND status IN ('pending', 'approved')
         RETURNING customer_id AS "customerId"`,
        [groupId, memberId],
      );
      if (!updated) throw new NotFoundException('Join request unavailable');
      return { groupId, customerId: memberId, status: 'approved' };
    });
  }

  async rejectMember(userId: string, groupId: string, memberId: string) {
    if (!(await this.hasEnhancedSchema())) {
      throw new ConflictException(
        'Group member management is unavailable until database migrations complete',
      );
    }
    return this.data.transaction(async (tx) => {
      const group = await this.lock(tx, 'id', groupId, true);
      if (group.organizerId !== userId)
        throw new NotFoundException('Group unavailable');
      if (memberId === userId)
        throw new BadRequestException('Organizer cannot be removed');
      if (group.requestedAt)
        throw new ConflictException(
          'Members cannot be changed after quotes are requested',
        );
      const [updated] = await tx.query<{ customerId: string }[]>(
        `UPDATE group_service_members
         SET status = 'rejected', reviewed_at = now()
         WHERE group_id = $1 AND customer_id = $2
         RETURNING customer_id AS "customerId"`,
        [groupId, memberId],
      );
      if (!updated) throw new NotFoundException('Group member unavailable');
      return { groupId, customerId: memberId, status: 'rejected' };
    });
  }

  async request(userId: string, id: string) {
    const enhanced = await this.hasEnhancedSchema();
    return this.data.transaction(async (tx) => {
      const group = await this.lock(tx, 'id', id, enhanced);
      if (group.organizerId !== userId)
        throw new NotFoundException('Group unavailable');
      if (group.requestedAt) return { id };
      const [ready] = enhanced
        ? await tx.query<{ id: string }[]>(
            `WITH updated AS (
               UPDATE group_service_requests g
               SET requested_at = now(), service_status = 'COLLECTING_QUOTES'
               FROM service_categories c WHERE g.id = $1 AND c.id = g.category_id
                 AND c.is_active AND NOT c.is_emergency
                 AND (SELECT count(*) FROM group_service_members m WHERE m.group_id = g.id AND m.status = 'approved') >= 2
               RETURNING g.id
             ) SELECT id FROM updated`,
            [id],
          )
        : await tx.query<{ id: string }[]>(
            `WITH updated AS (
               UPDATE group_service_requests g
               SET requested_at = now()
               FROM service_categories c WHERE g.id = $1 AND c.id = g.category_id
                 AND c.is_active AND NOT c.is_emergency
                 AND (SELECT count(*) FROM group_service_members m WHERE m.group_id = g.id) >= 2
               RETURNING g.id
             ) SELECT id FROM updated`,
            [id],
          );
      if (!ready)
        throw new ConflictException(
          'Approve at least one other household and choose an available service',
        );
      return ready;
    });
  }

  async quote(userId: string, id: string, dto: QuoteGroupServiceDto) {
    if (dto.groupMinor >= dto.regularMinor)
      throw new BadRequestException(
        'The group price must be below your regular price',
      );
    const enhanced = await this.hasEnhancedSchema();
    return this.data.transaction(async (tx) => {
      const group = await this.lock(tx, 'id', id, enhanced);
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
    const enhanced = await this.hasEnhancedSchema();
    return this.data.transaction(async (tx) => {
      const group = await this.lock(tx, 'id', id, enhanced);
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
        enhanced
          ? `UPDATE group_service_requests
             SET selected_quote_id = $2, service_status = 'PROVIDER_SELECTED'
             WHERE id = $1`
          : `UPDATE group_service_requests
             SET selected_quote_id = $2
             WHERE id = $1`,
        [id, quoteId],
      );
      return { id };
    });
  }

  async updateStatus(
    userId: string,
    id: string,
    nextStatus: 'SCHEDULED' | 'IN_PROGRESS' | 'COMPLETED',
  ) {
    if (!(await this.hasEnhancedSchema())) {
      throw new ConflictException(
        'Group status updates require database migrations to be applied',
      );
    }
    return this.data.transaction(async (tx) => {
      const group = await this.lock(tx, 'id', id, true);
      if (!group.selectedQuoteId) {
        throw new NotFoundException('Group unavailable');
      }
      const [selectedQuote] = await tx.query<{ providerId: string }[]>(
        `SELECT provider_id AS "providerId"
         FROM group_service_quotes WHERE id = $1 AND group_id = $2`,
        [group.selectedQuoteId, id],
      );
      if (!selectedQuote || selectedQuote.providerId !== userId) {
        throw new NotFoundException('Group unavailable');
      }
      if (group.serviceStatus === nextStatus) {
        return { id, serviceStatus: nextStatus };
      }
      const allowed = VALID_PROVIDER_STATUS_NEXT[group.serviceStatus] ?? [];
      if (!allowed.includes(nextStatus)) {
        throw new ConflictException(
          `Cannot move group service from ${group.serviceStatus} to ${nextStatus}`,
        );
      }
      await tx.query(
        'UPDATE group_service_requests SET service_status = $2 WHERE id = $1',
        [id, nextStatus],
      );
      return { id, serviceStatus: nextStatus };
    });
  }

  private async lock(
    tx: EntityManager,
    field: 'id' | 'invite_token',
    value: string,
    enhanced: boolean,
  ): Promise<GroupRow> {
    const statusSelect = enhanced
      ? 'service_status AS "serviceStatus"'
      : `CASE WHEN selected_quote_id IS NOT NULL THEN 'PROVIDER_SELECTED'
          WHEN requested_at IS NOT NULL THEN 'COLLECTING_QUOTES'
          ELSE 'INVITING' END AS "serviceStatus"`;
    const [group] = await tx.query<GroupRow[]>(
      `SELECT id, organizer_id AS "organizerId", requested_at AS "requestedAt",
         selected_quote_id AS "selectedQuoteId",
         ${statusSelect},
         created_at > now() - interval '7 days' AS "inviteOpen"
       FROM group_service_requests WHERE ${field} = $1 FOR UPDATE`,
      [value],
    );
    if (!group) throw new NotFoundException('Group unavailable');
    return group;
  }
}
