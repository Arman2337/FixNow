import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Complaint } from './domain/complaint.entity';
import { TrustModule } from '../../trust/trust.module';
import { ComplaintEvidence } from './domain/complaint-evidence.entity';
import { ComplaintAudit } from './domain/complaint-audit.entity';
import { ComplaintsService } from './complaints.service';
import { ComplaintsController } from './complaints.controller';
import { AuthModule } from '../../auth/auth.module';
import { Booking } from '../../bookings/domain/booking.entity';
import { TrustedEvidenceUrl } from './trusted-evidence-url';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Complaint,
      ComplaintEvidence,
      ComplaintAudit,
      Booking,
    ]),
    AuthModule,
    TrustModule,
  ],
  controllers: [ComplaintsController],
  providers: [ComplaintsService, TrustedEvidenceUrl],
  exports: [ComplaintsService],
})
export class ComplaintsModule {}
