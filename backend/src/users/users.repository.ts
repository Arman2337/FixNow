import {
  BadRequestException,
  ConflictException,
  Injectable,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AccountStatus, canTransitionAccountStatus } from './account-status';
import { UserEntity } from './user.entity';

@Injectable()
export class UsersRepository {
  constructor(
    @InjectRepository(UserEntity)
    private readonly users: Repository<UserEntity>,
  ) {}

  findById(id: string): Promise<UserEntity | null> {
    return this.users.findOneBy({ id });
  }

  create(): Promise<UserEntity> {
    return this.users.save(
      this.users.create({ status: AccountStatus.PendingVerification }),
    );
  }

  async transitionStatus(
    id: string,
    to: AccountStatus,
    reason: string,
  ): Promise<UserEntity | null> {
    const user = await this.users.findOneBy({ id });
    if (!user) return null;
    if (!reason.trim())
      throw new BadRequestException(
        'An account status change requires a reason',
      );
    if (!canTransitionAccountStatus(user.status, to)) {
      throw new BadRequestException(
        `Invalid account status transition: ${user.status} -> ${to}`,
      );
    }
    const result = await this.users.update(
      { id, status: user.status },
      {
        status: to,
        statusReason: reason.trim(),
        statusChangedAt: new Date(),
      },
    );
    if (result.affected !== 1) {
      throw new ConflictException('Account status changed concurrently');
    }
    return this.users.findOneBy({ id });
  }
}
