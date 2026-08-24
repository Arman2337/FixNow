import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { ProviderApplicationEntity } from './provider-application.entity';
import { ProviderSkillEntity } from './provider-skill.entity';
import { ServiceCategoryEntity } from '../services/service-category.entity';
import { ProviderRegistrationController } from './provider-registration.controller';
import { ProviderSkillsController } from './provider-skills.controller';
import { ProviderSkillsService } from './provider-skills.service';
import { ProviderProfileEntity } from './provider-profile.entity';
import { ProviderProfileController } from './provider-profile.controller';
import { ProviderProfileService } from './provider-profile.service';
import { ProviderDocumentEntity } from './documents/provider-document.entity';
import { ProviderDocumentAuditEntity } from './documents/provider-document-audit.entity';
import { ProviderDocumentController } from './documents/provider-document.controller';
import { ProviderDocumentService } from './documents/provider-document.service';
import { PRIVATE_OBJECT_STORAGE } from '../storage/private-object-storage';
import { S3PrivateObjectStorage } from '../storage/s3-private-object-storage';
import { MALWARE_SCANNER } from '../storage/malware-scanner';
import { ClamAvMalwareScanner } from '../storage/clamav-malware-scanner';
import { ProviderVerificationEventEntity } from './verification/provider-verification-event.entity';
import { ProviderVerificationController } from './verification/provider-verification.controller';
import { ProviderVerificationService } from './verification/provider-verification.service';
import { ProviderAvailabilityEntity } from './availability/provider-availability.entity';
import { ProviderAvailabilityController } from './availability/provider-availability.controller';
import { ProviderAvailabilityService } from './availability/provider-availability.service';
import { ProviderApplicationController } from './provider-application.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      ProviderApplicationEntity,
      ProviderSkillEntity,
      ServiceCategoryEntity,
      ProviderProfileEntity,
      ProviderDocumentEntity,
      ProviderDocumentAuditEntity,
      ProviderVerificationEventEntity,
      ProviderAvailabilityEntity,
    ]),
    AuthModule,
  ],
  controllers: [
    ProviderRegistrationController,
    ProviderSkillsController,
    ProviderProfileController,
    ProviderDocumentController,
    ProviderVerificationController,
    ProviderAvailabilityController,
    ProviderApplicationController,
  ],
  providers: [
    ProviderSkillsService,
    ProviderProfileService,
    ProviderDocumentService,
    S3PrivateObjectStorage,
    ClamAvMalwareScanner,
    ProviderVerificationService,
    ProviderAvailabilityService,
    { provide: PRIVATE_OBJECT_STORAGE, useExisting: S3PrivateObjectStorage },
    { provide: MALWARE_SCANNER, useExisting: ClamAvMalwareScanner },
  ],
  exports: [
    PRIVATE_OBJECT_STORAGE,
    MALWARE_SCANNER,
    ProviderSkillsService,
    ProviderProfileService,
    ProviderDocumentService,
    ProviderVerificationService,
  ],
})
export class ProvidersModule {}
