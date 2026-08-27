/**
 * Strict structured-output schema for problem classification. Raw model text
 * is never trusted: this parses the JSON the prompt asks for, enforces bounds,
 * pins the category to the FixNow taxonomy, and salvages an unknown category
 * to "Other" with capped confidence rather than trusting an invented label.
 *
 * Used with `parseStructuredOutput`, which already rejects oversized output and
 * non-JSON before `parse` runs.
 */

import { ProblemUrgency } from '../../../../shared/problem-analysis.types';
import { StructuredOutputSchema } from '../validation/structured-output.validator';
import {
  OTHER_CATEGORY,
  findCategoryByName,
  subcategoriesFor,
} from './categories.config';

/**
 * A validated, taxonomy-pinned classification. `category` is always a canonical
 * taxonomy name (or "Other"); `subcategory` is always one of that category's
 * allowed subcategories (or "Other"); `confidence` is always in [0, 1].
 */
export interface ClassifiedProblem {
  readonly category: string;
  readonly subcategory: string;
  readonly problemSummary: string;
  readonly urgency: ProblemUrgency;
  readonly confidence: number;
}

/** Longest summary we keep; longer output is clamped, not rejected. */
const MAX_SUMMARY_CHARACTERS = 400;

/**
 * Ceiling applied to confidence whenever we coerce an unmappable category to
 * "Other", so a mislabelled result cannot present as a confident match.
 */
const OTHER_CONFIDENCE_CAP = 0.5;

const URGENCIES: readonly ProblemUrgency[] = ['low', 'medium', 'high'];

export const problemAnalysisSchema: StructuredOutputSchema<ClassifiedProblem> =
  {
    parse(value: unknown): ClassifiedProblem | null {
      if (!value || typeof value !== 'object') return null;
      const record = value as Record<string, unknown>;

      const rawCategory = readString(record, 'category');
      const rawSummary = readString(
        record,
        'problem_summary',
        'problemSummary',
      );
      const rawUrgency = readString(record, 'urgency')?.toLowerCase();
      const confidence = readNumber(record, 'confidence');

      // Required fields. A missing/blank summary, unknown urgency, or absent
      // confidence is malformed output, not something to guess at.
      if (!rawCategory) return null;
      if (!rawSummary) return null;
      if (!isUrgency(rawUrgency)) return null;
      if (confidence === undefined) return null;

      const problemSummary = clamp(rawSummary, MAX_SUMMARY_CHARACTERS);
      const boundedConfidence = clampNumber(confidence, 0, 1);

      const matched = findCategoryByName(rawCategory);
      if (!matched) {
        // Unknown / invented category: salvage to "Other" with capped confidence
        // so the caller drops to manual selection rather than crashing.
        return {
          category: OTHER_CATEGORY,
          subcategory: OTHER_CATEGORY,
          problemSummary,
          urgency: rawUrgency,
          confidence: Math.min(boundedConfidence, OTHER_CONFIDENCE_CAP),
        };
      }

      return {
        category: matched.name,
        subcategory: resolveSubcategory(
          matched.name,
          readString(record, 'subcategory'),
        ),
        problemSummary,
        urgency: rawUrgency,
        confidence: boundedConfidence,
      };
    },
  };

function resolveSubcategory(
  categoryName: string,
  candidate: string | undefined,
): string {
  if (!candidate) return OTHER_CATEGORY;
  const normalized = candidate.trim().toLowerCase();
  const match = subcategoriesFor(categoryName).find(
    (subcategory) => subcategory.toLowerCase() === normalized,
  );
  return match ?? OTHER_CATEGORY;
}

function readString(
  record: Record<string, unknown>,
  ...keys: string[]
): string | undefined {
  for (const key of keys) {
    const value = record[key];
    if (typeof value === 'string' && value.trim().length > 0)
      return value.trim();
  }
  return undefined;
}

function readNumber(
  record: Record<string, unknown>,
  ...keys: string[]
): number | undefined {
  for (const key of keys) {
    const value = record[key];
    if (typeof value === 'number' && Number.isFinite(value)) return value;
  }
  return undefined;
}

function isUrgency(value: string | undefined): value is ProblemUrgency {
  return value !== undefined && URGENCIES.includes(value as ProblemUrgency);
}

function clamp(value: string, maxCharacters: number): string {
  return value.length > maxCharacters ? value.slice(0, maxCharacters) : value;
}

function clampNumber(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}
