import { Controller, Get } from '@nestjs/common';
import { Public } from '../common/authorization/authorization.decorators';

@Controller('notifications/inbox')
export class NotificationInboxController {
  @Public()
  @Get()
  getInbox(): { notifications: unknown[] } {
    return {
      notifications: [],
    };
  }
}
