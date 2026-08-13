import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Brackets, Repository } from 'typeorm';
import { Booking } from '../bookings/domain/booking.entity';
import { BookingEvent } from '../bookings/domain/booking-event.entity';
import { BookingsService } from '../bookings/bookings.service';
import { ServiceCategoryEntity } from '../services/service-category.entity';
import {
  CreateServiceCategoryDto,
  UpdateServiceCategoryDto,
} from '../services/service-categories.dto';
import { BookingPageQueryDto } from './admin-management.dto';

@Injectable()
export class AdminOperationsService {
  constructor(
    @InjectRepository(ServiceCategoryEntity)
    private readonly categories: Repository<ServiceCategoryEntity>,
    @InjectRepository(Booking) private readonly bookings: Repository<Booking>,
    @InjectRepository(BookingEvent)
    private readonly bookingEvents: Repository<BookingEvent>,
    private readonly bookingCommands: BookingsService,
  ) {}

  listCategories() {
    return this.categories.find({
      order: { displayOrder: 'ASC', name: 'ASC' },
    });
  }
  createCategory(input: CreateServiceCategoryDto) {
    return this.categories.save(this.categories.create(input));
  }
  async updateCategory(id: string, input: UpdateServiceCategoryDto) {
    const category = await this.categories.findOneBy({ id });
    if (!category) throw new NotFoundException('Service category not found');
    return this.categories.save(Object.assign(category, input));
  }
  async deleteCategory(id: string) {
    const result = await this.categories.delete(id);
    if (!result.affected)
      throw new NotFoundException('Service category not found');
  }

  async listBookings(query: BookingPageQueryDto) {
    const cursor = this.decodeCursor(query.cursor);
    const builder = this.bookings
      .createQueryBuilder('booking')
      .orderBy('booking.updated_at', 'DESC')
      .addOrderBy('booking.id', 'DESC')
      .take(query.limit + 1);
    if (query.status)
      builder.andWhere('booking.status = :status', { status: query.status });
    if (query.search)
      builder.andWhere(
        '(CAST(booking.id AS text) ILIKE :search OR CAST(booking.customer_id AS text) ILIKE :search OR CAST(booking.provider_id AS text) ILIKE :search)',
        { search: `${query.search}%` },
      );
    if (cursor)
      builder.andWhere(
        new Brackets((where) =>
          where
            .where('booking.updated_at < :updatedAt', {
              updatedAt: cursor.updatedAt,
            })
            .orWhere(
              'booking.updated_at = :updatedAt AND booking.id < :id',
              cursor,
            ),
        ),
      );
    const rows = await builder.getMany();
    const page = rows.slice(0, query.limit);
    return {
      items: page.map((booking) => this.projectBooking(booking)),
      nextCursor:
        rows.length > query.limit ? this.encodeCursor(page.at(-1)!) : null,
    };
  }

  async bookingDetail(id: string) {
    const booking = await this.bookings.findOneBy({ id });
    if (!booking) throw new NotFoundException('Booking not found');
    const events = await this.bookingEvents.find({
      where: { bookingId: id },
      order: { createdAt: 'DESC' },
      take: 100,
    });
    return {
      ...this.projectBooking(booking),
      events: events.map(
        ({
          id: eventId,
          actorUserId,
          fromStatus,
          toStatus,
          reason,
          bookingVersion,
          createdAt,
        }) => ({
          id: eventId,
          actorUserId,
          fromStatus,
          toStatus,
          reason,
          bookingVersion,
          createdAt,
        }),
      ),
    };
  }

  cancelBooking(id: string, actor: string, reason: string, version: number) {
    return this.bookingCommands.cancelBookingAsAdmin(
      id,
      actor,
      reason,
      version,
    );
  }
  private projectBooking({
    id,
    customerId,
    providerId,
    serviceCategoryId,
    status,
    description,
    scheduledAt,
    cancellationReason,
    version,
    createdAt,
    updatedAt,
  }: Booking) {
    return {
      id,
      customerId,
      providerId,
      serviceCategoryId,
      status,
      description,
      scheduledAt,
      cancellationReason,
      version,
      createdAt,
      updatedAt,
    };
  }
  private decodeCursor(
    value?: string,
  ): { updatedAt: string; id: string } | null {
    if (!value) return null;
    try {
      const parsed = JSON.parse(Buffer.from(value, 'base64url').toString()) as {
        updatedAt: string;
        id: string;
      };
      if (!parsed.id || Number.isNaN(Date.parse(parsed.updatedAt)))
        throw new Error();
      return parsed;
    } catch {
      throw new BadRequestException('Invalid pagination cursor');
    }
  }
  private encodeCursor(value: { id: string; updatedAt: Date }) {
    return Buffer.from(
      JSON.stringify({
        id: value.id,
        updatedAt: value.updatedAt.toISOString(),
      }),
    ).toString('base64url');
  }
}
