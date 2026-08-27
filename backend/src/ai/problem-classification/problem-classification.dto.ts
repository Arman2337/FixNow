import { IsOptional, IsString, Matches, MaxLength } from 'class-validator';

/**
 * Optional multipart body for the voice and combined problem-analysis
 * endpoints. The image endpoint takes no body fields.
 *
 * `languageHint` is a best-effort steer for transcription/classification
 * (e.g. `en`, `hi`, `gu`, `en-IN`, `mixed`). It is intentionally permissive
 * but bounded — the AI layer treats it as advisory only.
 */
export class ProblemAnalysisMediaDto {
  @IsOptional()
  @IsString()
  @MaxLength(20)
  @Matches(/^[A-Za-z-]+$/, {
    message:
      'languageHint must be a short language code or name (letters and hyphens only)',
  })
  languageHint?: string;
}
