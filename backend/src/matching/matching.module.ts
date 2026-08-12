import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MatchingService } from './matching.service';
import { ProviderProfileEntity } from '../providers/provider-profile.entity';
import { ProviderSkillEntity } from '../providers/provider-skill.entity';
import { ProviderAvailabilityEntity } from '../providers/availability/provider-availability.entity';
import { UserEntity } from '../users/user.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      ProviderProfileEntity,
      ProviderSkillEntity,
      ProviderAvailabilityEntity,
      UserEntity,
    ]),
  ],
  providers: [MatchingService],
  exports: [MatchingService],
})
export class MatchingModule {}
