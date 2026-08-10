import { Injectable } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { AuthAuditEventEntity } from '../auth/auth-audit-event.entity';
import { CustomerProfileResponse } from './customer-profile.dto';
import { CustomerProfileEntity } from './customer-profile.entity';

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
      return { displayName: profile?.displayName ?? null };
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
      return { displayName: profile.displayName };
    });
  }
}
