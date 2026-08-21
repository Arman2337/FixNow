import { AiError } from '../contracts/ai-errors';

const MAX_ISSUE_TEXT_CHARACTERS = 1_000;
const EMAIL = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi;
const PHONE = /\b(?:\+?\d[\d\s().-]{7,}\d)\b/g;
const COORDINATE_PAIR = /[-+]?\d{1,2}\.\d{3,}\s*,\s*[-+]?\d{1,3}\.\d{3,}/g;
const OTP = /\b(?:otp|code)\s*[:=-]?\s*\d{4,8}\b/gi;
const AUTHORIZATION = /\b(?:bearer|token)\s+[A-Za-z0-9._~+/=-]+/gi;

export interface SanitizedAiInput {
  readonly issueText: string;
  readonly locale?: string;
}

export function sanitizeAiInput(input: {
  readonly issueText: unknown;
  readonly locale?: unknown;
}): SanitizedAiInput {
  if (
    typeof input.issueText !== 'string' ||
    !input.issueText.trim() ||
    input.issueText.length > MAX_ISSUE_TEXT_CHARACTERS
  ) {
    throw new AiError('INPUT_REJECTED');
  }
  if (input.locale !== undefined && !isSafeLocale(input.locale))
    throw new AiError('INPUT_REJECTED');

  return {
    issueText: redactSensitiveText(input.issueText.trim()),
    ...(input.locale ? { locale: input.locale } : {}),
  };
}

export function redactSensitiveText(value: string): string {
  return value
    .replace(EMAIL, '[REDACTED_EMAIL]')
    .replace(PHONE, '[REDACTED_PHONE]')
    .replace(COORDINATE_PAIR, '[REDACTED_COORDINATES]')
    .replace(OTP, '[REDACTED_OTP]')
    .replace(AUTHORIZATION, '[REDACTED_AUTHORIZATION]');
}

function isSafeLocale(value: unknown): value is string {
  return (
    typeof value === 'string' &&
    /^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})?$/.test(value)
  );
}
