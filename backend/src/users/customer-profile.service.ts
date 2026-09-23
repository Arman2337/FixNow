import { Injectable } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { AuthAuditEventEntity } from '../auth/auth-audit-event.entity';
import { CustomerProfileResponse } from './customer-profile.dto';
import { CustomerProfileEntity } from './customer-profile.entity';
import { Booking } from '../bookings/domain/booking.entity';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';

@Injectable()
export class CustomerProfileService {
  constructor(private readonly dataSource: DataSource) {}

  async read(userId: string): Promise<CustomerProfileResponse> {
    return this.dataSource.transaction(async (manager) => {
      const profile = await manager.findOneBy(CustomerProfileEntity, {
        userId,
      });
      await manager.save(
        manager.create(AuthAuditEventEntity, {
          userId,
          eventType: 'customer_profile.read',
          outcome: 'success',
        }),
      );
      const completedJobs = await manager.count(Booking, {
        where: { customerId: userId, status: BookingStatus.COMPLETED },
      });

      // Warranties apply to bookings completed in the last 30 days
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

      const activeWarranties = await manager
        .getRepository(Booking)
        .createQueryBuilder('booking')
        .where('booking.customerId = :userId', { userId })
        .andWhere('booking.status = :status', { status: BookingStatus.COMPLETED })
        .andWhere('booking.completedAt > :date', { date: thirtyDaysAgo })
        .getCount();

      return {
        displayName: profile?.displayName ?? null,
        stats: {
          completedJobs,
          cashbackMinor: 0, // Placeholder until cashback feature is built
          activeWarranties,
        },
      };
    });
  }

  async update(
    userId: string,
    displayName: string,
  ): Promise<CustomerProfileResponse> {
    return this.dataSource.transaction(async (manager) => {
      const existing = await manager.findOneBy(CustomerProfileEntity, {
        userId,
      });
      const profile =
        existing ?? manager.create(CustomerProfileEntity, { userId });
      profile.displayName = displayName;
      await manager.save(profile);
      await manager.save(
        manager.create(AuthAuditEventEntity, {
          userId,
          eventType: 'customer_profile.update',
          outcome: 'success',
        }),
      );
      const completedJobs = await manager.count(Booking, {
        where: { customerId: userId, status: BookingStatus.COMPLETED },
      });

      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

      const activeWarranties = await manager
        .getRepository(Booking)
        .createQueryBuilder('booking')
        .where('booking.customerId = :userId', { userId })
        .andWhere('booking.status = :status', { status: BookingStatus.COMPLETED })
        .andWhere('booking.completedAt > :date', { date: thirtyDaysAgo })
        .getCount();

      return {
        displayName: profile.displayName,
        stats: {
          completedJobs,
          cashbackMinor: 0,
          activeWarranties,
        },
      };
    });
  }
}
