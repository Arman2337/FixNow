import {
  Controller,
  ForbiddenException,
  Get,
  NotFoundException,
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
import {
  assertOwnedCollection,
  assertOwnedResource,
} from '../../common/authorization/resource-ownership';

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
    const principal = req.authorizationPrincipal!;
    const userId = this.resolveUserId(userIdParam, req);

    if (!userId) {
      return [];
    }

    const items = await this.notificationRepo.find({
      where: { userId },
      order: { createdAt: 'DESC' },
    });

    // SEC-002: ownership rides on the `where: { userId }` predicate. Check the
    // rows actually read, so a dropped predicate cannot become a leak.
    assertOwnedCollection(principal, items, 'userId');

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
    const principal = req.authorizationPrincipal!;
    const userId = this.resolveUserId(userIdParam, req);

    if (!userId) {
      return { success: false };
    }

    // SEC-002. `update({ id, userId })` was already scoped, but an update that
    // matched nothing still answered `{ success: true }` — a foreign id and a
    // non-existent one were indistinguishable from your own. Load the caller's
    // row first: absent is a 404, present is proven owned.
    const existing = await this.notificationRepo.findOneBy({ id, userId });
    if (!existing) {
      throw new NotFoundException(`Notification with ID ${id} not found`);
    }
    assertOwnedResource(principal, existing.userId, 'inAppNotification.userId');

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
