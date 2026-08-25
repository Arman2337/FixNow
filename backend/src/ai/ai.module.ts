import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { EnvironmentVariables, AiProviderName } from '../config/env.validation';
import { AppLoggerModule } from '../logging/logger.module';
import { AiProvider } from './contracts/ai-provider.contract';
import {
  DeterministicAiProvider,
  DisabledAiProvider,
} from './providers/deterministic-ai.provider';
import { AiService } from './ai.service';
import { ServicesModule } from '../services/services.module';
import { IssueRecommendationService } from './issue-recommendation.service';
import { IssueRecommendationController } from './issue-recommendation.controller';
import { PriceEstimateService } from './pricing/price-estimate.service';
import { PriceEstimateController } from './pricing/price-estimate.controller';

@Module({
  imports: [AppLoggerModule, ServicesModule],
  controllers: [IssueRecommendationController, PriceEstimateController],
  providers: [
    {
      provide: DeterministicAiProvider,
      useFactory: () => new DeterministicAiProvider(),
    },
    DisabledAiProvider,
    {
      provide: AiProvider,
      useFactory: (
        config: ConfigService<EnvironmentVariables>,
        fakeProvider: DeterministicAiProvider,
        disabledProvider: DisabledAiProvider,
      ): AiProvider => {
        if (config.get('AI_PROVIDER') === AiProviderName.Fake)
          return fakeProvider;
        return disabledProvider;
      },
      inject: [ConfigService, DeterministicAiProvider, DisabledAiProvider],
    },
    AiService,
    IssueRecommendationService,
    PriceEstimateService,
  ],
  exports: [AiService],
})
export class AiModule {}
