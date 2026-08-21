import { Injectable } from '@nestjs/common';
import { ServiceCategoriesService } from '../services/service-categories.service';
import { AiService } from './ai.service';
import { StructuredOutputSchema } from './validation/structured-output.validator';

export type IssueRecommendationResponse =
  | {
      kind: 'RECOMMENDATION';
      recommendation: {
        serviceCategoryId: string;
        serviceName: string;
        confidenceLabel: 'Strong match' | 'Possible match';
        reason: string;
      };
      safetyNotice: string | null;
    }
  | {
      kind: 'CLARIFICATION';
      clarificationQuestion: string;
      safetyNotice: string | null;
    }
  | { kind: 'NO_MATCH'; safetyNotice: string | null }
  | { kind: 'UNAVAILABLE' };

type Candidate =
  | {
      kind: 'recommendation';
      serviceCategoryId: string;
      confidence: number;
      reason: string;
      safetyNotice?: string;
    }
  | {
      kind: 'clarification';
      clarificationQuestion: string;
      safetyNotice?: string;
    }
  | { kind: 'no_match'; safetyNotice?: string };

const candidateSchema: StructuredOutputSchema<Candidate> = {
  parse(value: unknown): Candidate | null {
    if (!value || typeof value !== 'object') return null;
    const record = value as Record<string, unknown>;
    const safetyNotice =
      typeof record.safetyNotice === 'string' ? record.safetyNotice : undefined;
    if (
      record.kind === 'recommendation' &&
      typeof record.serviceCategoryId === 'string' &&
      typeof record.confidence === 'number' &&
      record.confidence >= 0 &&
      record.confidence <= 1 &&
      typeof record.reason === 'string'
    )
      return {
        kind: 'recommendation',
        serviceCategoryId: record.serviceCategoryId,
        confidence: record.confidence,
        reason: record.reason,
        safetyNotice,
      };
    if (
      record.kind === 'clarification' &&
      typeof record.clarificationQuestion === 'string'
    )
      return {
        kind: 'clarification',
        clarificationQuestion: record.clarificationQuestion,
        safetyNotice,
      };
    if (record.kind === 'no_match') return { kind: 'no_match', safetyNotice };
    return null;
  },
};

@Injectable()
export class IssueRecommendationService {
  constructor(
    private readonly ai: AiService,
    private readonly categories: ServiceCategoriesService,
  ) {}

  async recommend(input: {
    userId: string;
    description: string;
    clarificationContext?: string;
    requestId?: string;
  }): Promise<IssueRecommendationResponse> {
    const categories = await this.categories.getActiveCategories();
    const issueText = [input.description, input.clarificationContext]
      .filter(
        (value): value is string =>
          typeof value === 'string' && value.trim().length > 0,
      )
      .join('\n');
    const result = await this.ai.executeStructured({
      operation: 'structured_text',
      userId: input.userId,
      issueText,
      schema: candidateSchema,
      requestId: input.requestId,
      catalog: categories.map((category) => ({
        id: category.id,
        name: category.name,
        ...(category.description ? { description: category.description } : {}),
      })),
    });
    if (result.kind === 'fallback') return { kind: 'UNAVAILABLE' };
    const value = result.value;
    if (value.kind === 'recommendation') {
      const category = categories.find(
        (item) => item.id === value.serviceCategoryId && item.isActive,
      );
      if (!category || value.confidence < 0.85)
        return { kind: 'NO_MATCH', safetyNotice: value.safetyNotice ?? null };
      return {
        kind: 'RECOMMENDATION',
        recommendation: {
          serviceCategoryId: category.id,
          serviceName: category.name,
          confidenceLabel:
            value.confidence >= 0.85 ? 'Strong match' : 'Possible match',
          reason: value.reason,
        },
        safetyNotice: value.safetyNotice ?? null,
      };
    }
    if (value.kind === 'clarification')
      return {
        kind: 'CLARIFICATION',
        clarificationQuestion: value.clarificationQuestion,
        safetyNotice: value.safetyNotice ?? null,
      };
    return { kind: 'NO_MATCH', safetyNotice: value.safetyNotice ?? null };
  }
}
