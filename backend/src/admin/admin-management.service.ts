import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Brackets, IsNull, MoreThan, Repository } from 'typeorm';
import { UserEntity } from '../users/user.entity';
import { UserRoleEntity } from '../users/user-role.entity';
import { ProviderApplicationEntity } from '../providers/provider-application.entity';
import { ProviderProfileEntity } from '../providers/provider-profile.entity';
import { ProviderVerificationEventEntity } from '../providers/verification/provider-verification-event.entity';
import { ComplaintsService } from '../support/complaints/complaints.service';
import type {
  AdminPageQueryDto,
  ProviderApplicationPageQueryDto,
} from './admin-management.dto';

type Cursor = { updatedAt: string; id: string };

@Injectable()
export class AdminManagementService {
  constructor(
    @InjectRepository(UserEntity)
    private readonly users: Repository<UserEntity>,
    @InjectRepository(UserRoleEntity)
    private readonly roles: Repository<UserRoleEntity>,
    @InjectRepository(ProviderApplicationEntity)
    private readonly applications: Repository<ProviderApplicationEntity>,
    @InjectRepository(ProviderProfileEntity)
    private readonly profiles: Repository<ProviderProfileEntity>,
    @InjectRepository(ProviderVerificationEventEntity)
    private readonly events: Repository<ProviderVerificationEventEntity>,
    private readonly complaintsService: ComplaintsService,
  ) {}

  async listComplaints(adminId: string) {
    return this.complaintsService.getComplaints(adminId, true);
  }

  async getComplaintDetail(id: string, adminId: string) {
    return this.complaintsService.getComplaintById(id, adminId, true);
  }

  async listUsers(query: AdminPageQueryDto) {
    const cursor = this.decodeCursor(query.cursor);
    const builder = this.users
      .createQueryBuilder('user')
      .orderBy('user.updated_at', 'DESC')
      .addOrderBy('user.id', 'DESC')
      .take(query.limit + 1);
    if (query.search)
      builder.andWhere('CAST(user.id AS text) ILIKE :search', {
        search: `${query.search}%`,
      });
    if (cursor)
      builder.andWhere(
        new Brackets((where) =>
          where
            .where('user.updated_at < :updatedAt', {
              updatedAt: cursor.updatedAt,
            })
            .orWhere('user.updated_at = :updatedAt AND user.id < :id', cursor),
        ),
      );
    const rows = await builder.getMany();
    const page = rows.slice(0, query.limit);
    const assignments = page.length
      ? await this.roles.find({
          where: page.flatMap((user) => [
            { userId: user.id, expiresAt: IsNull() },
            { userId: user.id, expiresAt: MoreThan(new Date()) },
          ]),
          relations: { role: true },
        })
      : [];
    return {
      items: page.map((user) => ({
        id: user.id,
        status: user.status,
        roles: assignments
          .filter((role) => role.userId === user.id)
          .map((role) => role.role.code),
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      })),
      nextCursor:
        rows.length > query.limit ? this.encodeCursor(page.at(-1)!) : null,
    };
  }

  async listApplications(query: ProviderApplicationPageQueryDto) {
    const cursor = this.decodeCursor(query.cursor);
    const builder = this.applications
      .createQueryBuilder('application')
      .orderBy('application.updated_at', 'DESC')
      .addOrderBy('application.id', 'DESC')
      .take(query.limit + 1);
    if (query.status)
      builder.andWhere('application.status = :status', {
        status: query.status,
      });
    if (query.search)
      builder.andWhere(
        '(CAST(application.id AS text) ILIKE :search OR CAST(application.user_id AS text) ILIKE :search)',
        { search: `${query.search}%` },
      );
    if (cursor)
      builder.andWhere(
        new Brackets((where) =>
          where
            .where('application.updated_at < :updatedAt', {
              updatedAt: cursor.updatedAt,
            })
            .orWhere(
              'application.updated_at = :updatedAt AND application.id < :id',
              cursor,
            ),
        ),
      );
    const rows = await builder.getMany();
    const page = rows.slice(0, query.limit);
    const profiles = page.length
      ? await this.profiles.find({
          where: page.map((application) => ({ userId: application.userId })),
        })
      : [];
    return {
      items: page.map((application) => ({
        ...this.applicationProjection(application),
        displayName:
          profiles.find((profile) => profile.userId === application.userId)
            ?.displayName ?? null,
      })),
      nextCursor:
        rows.length > query.limit ? this.encodeCursor(page.at(-1)!) : null,
    };
  }

  async userDetail(userId: string) {
    const user = await this.users.findOneBy({ id: userId });
    if (!user) throw new NotFoundException('User not found');
    const assignments = await this.roles.find({
      where: [
        { userId, expiresAt: IsNull() },
        { userId, expiresAt: MoreThan(new Date()) },
      ],
      relations: { role: true },
    });
    return {
      id: user.id,
      status: user.status,
      roles: assignments.map((assignment) => assignment.role.code),
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    };
  }

  async applicationDetail(applicationId: string) {
    const application = await this.applications.findOneBy({
      id: applicationId,
    });
    if (!application)
      throw new NotFoundException('Provider application not found');
    const [profile, events] = await Promise.all([
      this.profiles.findOneBy({ userId: application.userId }),
      this.events.find({
        where: { applicationId },
        order: { createdAt: 'DESC' },
        take: 100,
      }),
    ]);
    return {
      ...this.applicationProjection(application),
      profile: profile
        ? {
            displayName: profile.displayName,
            bio: profile.bio,
            serviceRadiusKm: profile.serviceRadiusKm,
          }
        : null,
      events: events.map(
        ({
          id,
          actorUserId,
          fromStatus,
          toStatus,
          reason,
          applicationVersion,
          createdAt,
        }) => ({
          id,
          actorUserId,
          fromStatus,
          toStatus,
          reason,
          applicationVersion,
          createdAt,
        }),
      ),
    };
  }

  private applicationProjection(application: ProviderApplicationEntity) {
    const {
      id,
      userId,
      status,
      assignedReviewerUserId,
      decisionReason,
      reviewedAt,
      version,
      createdAt,
      updatedAt,
    } = application;
    return {
      id,
      userId,
      status,
      assignedReviewerUserId,
      decisionReason,
      reviewedAt,
      version,
      createdAt,
      updatedAt,
    };
  }

  private decodeCursor(value?: string): Cursor | null {
    if (!value) return null;
    try {
      const parsed = JSON.parse(
        Buffer.from(value, 'base64url').toString(),
      ) as Cursor;
      if (!parsed.id || Number.isNaN(Date.parse(parsed.updatedAt)))
        throw new Error();
      return parsed;
    } catch {
      throw new BadRequestException('Invalid pagination cursor');
    }
  }

  private encodeCursor(value: { id: string; updatedAt: Date }): string {
    return Buffer.from(
      JSON.stringify({
        id: value.id,
        updatedAt: value.updatedAt.toISOString(),
      }),
    ).toString('base64url');
  }
}
