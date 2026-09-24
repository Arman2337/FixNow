import { Controller, Get, Param, Patch, Req } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { InAppNotification } from './in-app-notification.entity';
import type { AuthorizedRequest } from '../../common/authorization/authorization.guard';

@Controller('users/:userId/notifications')
export class InboxController {
  constructor(
    @InjectRepository(InAppNotification)
    private readonly notificationRepo: Repository<InAppNotification>,
  ) {}

  @Get()
  async getInbox(
    @Param('userId') userIdParam: string,
    @Req() req: AuthorizedRequest,
  ) {
    const userId =
      userIdParam === 'me' ? req.authorizationPrincipal?.userId : userIdParam;

    if (!userId) {
      return [];
    }

    const items = await this.notificationRepo.find({
      where: { userId },
      order: { createdAt: 'DESC' },
    });

    return items.map((n) => ({
      id: n.id,
      title: n.title,
      body: n.body,
      kind: n.kind,
      category: n.kind,
      bookingId: n.bookingId,
      paymentId: n.paymentId,
      timestamp: n.createdAt.toISOString(),
      createdAt: n.createdAt.toISOString(),
      isRead: n.readAt !== null,
    }));
  }

  @Patch(':id/read')
  async markRead(
    @Param('userId') userIdParam: string,
    @Param('id') id: string,
    @Req() req: AuthorizedRequest,
  ) {
    const userId =
      userIdParam === 'me' ? req.authorizationPrincipal?.userId : userIdParam;

    if (!userId) {
      return { success: false };
    }

    await this.notificationRepo.update(
      { id, userId },
      { readAt: new Date() },
    );
    return { success: true };
  }
}
