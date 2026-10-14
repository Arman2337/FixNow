import { Controller, Get } from '@nestjs/common';
import { RequirePermission } from '../common/authorization/authorization.decorators';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import { AdminAnalyticsService } from './admin-analytics.service';

@Controller('admin/analytics')
export class AdminAnalyticsController {
  constructor(private readonly analytics: AdminAnalyticsService) {}

  @Get()
  @RequirePermission(PERMISSIONS.adminAnalyticsRead)
  getAnalytics() {
    return this.analytics.getOperationalAnalytics();
  }

  getOperationalAnalytics() {
    return this.getAnalytics();
  }
}
