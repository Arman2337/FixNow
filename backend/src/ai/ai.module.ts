import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { EnvironmentVariables, AiProviderName } from '../config/env.validation';
import { AppLoggerModule } from '../logging/logger.module';
import { AiProvider } from './contracts/ai-provider.contract';
import {
  DeterministicAiProvider,
  DisabledAiProvider,
} from './providers/deterministic-ai.provider';
import { HuggingFaceAiProvider } from './providers/huggingface-ai.provider';
import { AiService } from './ai.service';
import { ServicesModule } from '../services/services.module';
import { IssueRecommendationService } from './issue-recommendation.service';
import { IssueRecommendationController } from './issue-recommendation.controller';
import { PriceEstimateService } from './pricing/price-estimate.service';
import { PriceEstimateController } from './pricing/price-estimate.controller';
import { ProblemClassificationService } from './problem-classification/problem-classification.service';
import { ProblemClassificationController } from './problem-classification/problem-classification.controller';

@Module({
  imports: [AppLoggerModule, ServicesModule],
  controllers: [
    IssueRecommendationController,
    PriceEstimateController,
    ProblemClassificationController,
  ],
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
        switch (config.get('AI_PROVIDER')) {
          case AiProviderName.Fake:
            return fakeProvider;
          case AiProviderName.HuggingFace:
            // Real, gated adapter (ADR-0014). Never selected by tests; only
            // when explicitly configured after the release gate passes.
            return new HuggingFaceAiProvider({
              token: config.get('HF_TOKEN') ?? '',
              chatBaseUrl: config.get<string>(
                'HF_INFERENCE_BASE_URL',
                'https://router.huggingface.co/v1',
              ),
              asrBaseUrl: config.get<string>(
                'HF_ASR_BASE_URL',
                'https://api-inference.huggingface.co/models',
              ),
              visionModel: config.get<string>(
                'HF_VISION_MODEL',
                'Qwen/Qwen2.5-VL-7B-Instruct',
              ),
              whisperModel: config.get<string>(
                'HF_WHISPER_MODEL',
                'openai/whisper-large-v3',
              ),
            });
          default:
            return disabledProvider;
        }
      },
      inject: [ConfigService, DeterministicAiProvider, DisabledAiProvider],
    },
    AiService,
    IssueRecommendationService,
    PriceEstimateService,
    ProblemClassificationService,
  ],
  exports: [AiService],
})
export class AiModule {}
