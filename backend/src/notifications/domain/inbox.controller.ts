import { Controller, Get, Param, Patch } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { InAppNotification } from './in-app-notification.entity';
// import { JwtAuthGuard } from '../../auth/jwt-auth.guard'; // Apply as needed

@Controller('users/:userId/notifications')
export class InboxController {
  constructor(
    @InjectRepository(InAppNotification)
    private readonly notificationRepo: Repository<InAppNotification>,
  ) {}

  @Get()
  async getInbox(@Param('userId') userId: string) {
    return await this.notificationRepo.find({
      where: { userId },
      order: { createdAt: 'DESC' },
    });
  }

  @Patch(':id/read')
  async markRead(
    @Param('userId') userId: string,
    @Param('id') id: string,
  ) {
    await this.notificationRepo.update(
      { id, userId },
      { readAt: new Date() },
    );
    return { success: true };
  }
}
