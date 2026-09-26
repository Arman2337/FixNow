import {
  Controller,
  ForbiddenException,
  Get,
  Param,
  Patch,
  Req,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { InAppNotification } from './in-app-notification.entity';
import type { AuthorizedRequest } from '../../common/authorization/authorization.guard';
import { RequireOwnPermission } from '../../common/authorization/authorization.decorators';
import { PERMISSIONS } from '../../common/authorization/permission-policies';

@Controller('users/:userId/notifications')
export class InboxController {
  constructor(
    @InjectRepository(InAppNotification)
    private readonly notificationRepo: Repository<InAppNotification>,
  ) {}

  @Get()
  @RequireOwnPermission(PERMISSIONS.notificationInboxReadSelf)
  async getInbox(
    @Param('userId') userIdParam: string,
    @Req() req: AuthorizedRequest,
  ) {
    const userId = this.resolveUserId(userIdParam, req);

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
  @RequireOwnPermission(PERMISSIONS.notificationInboxReadSelf)
  async markRead(
    @Param('userId') userIdParam: string,
    @Param('id') id: string,
    @Req() req: AuthorizedRequest,
  ) {
    const userId = this.resolveUserId(userIdParam, req);

    if (!userId) {
      return { success: false };
    }

    await this.notificationRepo.update({ id, userId }, { readAt: new Date() });
    return { success: true };
  }

  private resolveUserId(
    userIdParam: string,
    request: AuthorizedRequest,
  ): string | undefined {
    const authenticatedUserId = request.authorizationPrincipal?.userId;
    if (!authenticatedUserId) return undefined;
    if (userIdParam !== 'me' && userIdParam !== authenticatedUserId) {
      throw new ForbiddenException('You cannot access another user inbox');
    }
    return authenticatedUserId;
  }
}
