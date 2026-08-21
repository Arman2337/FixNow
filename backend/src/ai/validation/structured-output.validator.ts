import { AiError } from '../contracts/ai-errors';

export interface StructuredOutputSchema<T> {
  parse(value: unknown): T | null;
}

export function parseStructuredOutput<T>(
  rawOutput: string,
  schema: StructuredOutputSchema<T>,
  maximumCharacters: number,
): T {
  if (rawOutput.length > maximumCharacters)
    throw new AiError('INVALID_MODEL_OUTPUT');
  try {
    const parsed: unknown = JSON.parse(rawOutput);
    const result = schema.parse(parsed);
    if (result === null) throw new AiError('INVALID_MODEL_OUTPUT');
    return result;
  } catch (error) {
    if (error instanceof AiError) throw error;
    throw new AiError('INVALID_MODEL_OUTPUT');
  }
}
