export const AI_ERROR_CODES = [
  'AI_DISABLED',
  'PROVIDER_UNAVAILABLE',
  'TIMEOUT',
  'RATE_LIMITED',
  'INVALID_MODEL_OUTPUT',
  'UNSUPPORTED_OPERATION',
  'INPUT_REJECTED',
  'INTERNAL_AI_ERROR',
] as const;

export type AiErrorCode = (typeof AI_ERROR_CODES)[number];

export class AiError extends Error {
  constructor(
    readonly code: AiErrorCode,
    message = code,
  ) {
    super(message);
    this.name = 'AiError';
  }
}
