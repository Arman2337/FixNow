import {
  ArrayMaxSize,
  IsArray,
  IsOptional,
  IsString,
  IsUrl,
  IsUUID,
  MaxLength,
  MinLength,
} from 'class-validator';

/**
 * SEC-010: `POST /guarantees/claims` answered 400 for every request.
 *
 * This DTO declared three properties and no decorators. The global pipe runs
 * `whitelist: true, forbidNonWhitelisted: true`, and `whitelist` strips (or here,
 * rejects) any property the target class has no validation metadata for. A bare
 * class therefore declares all three of its own fields as un-whitelisted, so
 * `bookingId`, `description` and `evidenceUrls` were each a 400. The guarantee
 * intake form — the customer reporting that a completed job was not done
 * properly — could not be submitted at all.
 *
 * The bug survived because the only guarantee-controller validation test
 * covered `UpdateGuaranteeClaimDto`, the one DTO in the file that does have
 * decorators. Adding a DTO without decorators is silent: nothing fails at boot,
 * nothing fails at compile time, and the endpoint is simply unusable.
 *
 * The bounds below are not decoration. `evidenceUrls` is a `simple-array`
 * column, so it is a single comma-joined text value; an unbounded array would be
 * an unbounded write on a customer-facing route, and an arbitrary `url` in it is
 * stored verbatim and later shown to admin staff reviewing the claim.
 */
export class CreateGuaranteeClaimDto {
  @IsUUID('4', { message: 'bookingId must be a valid booking id' })
  bookingId!: string;

  @IsString()
  @MinLength(10, {
    message:
      'description must be at least 10 characters so the claim is actionable',
  })
  @MaxLength(2000, {
    message: 'description must be at most 2000 characters',
  })
  description!: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10, {
    message: 'at most 10 evidence links may be attached to one claim',
  })
  @IsUrl(
    { require_tld: false, protocols: ['http', 'https'] },
    { each: true, message: 'each evidence link must be an http(s) URL' },
  )
  evidenceUrls?: string[];
}
