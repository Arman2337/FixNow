import {
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { Transform } from 'class-transformer';

/**
 * API-003. The shared bound for list endpoints that have no cursor.
 *
 * Four read endpoints had no limit at all and returned `getMany()` straight off
 * a query builder:
 *
 *   - `GET /guarantees/claims`          (admin)
 *   - `GET /service-categories`
 *   - `GET /sub-services`
 *   - `GET /provider-skills/user/:userId`
 *
 * The first is the one that matters: `guarantee_claims` is append-only and grows
 * with every claim filed, and the admin console loaded the entire table to
 * render a list. The catalogue endpoints are bounded by the catalogue today, but
 * "the table is small now" is not a property an endpoint should depend on — the
 * count is data-driven, not schema-driven, and nothing stops a category with
 * thousands of sub-services.
 *
 * These are bounded rather than cursor-paginated on purpose. They are reference
 * data that a client fetches once and caches, so a cap that is generous relative
 * to the real cardinality is the honest fix; inventing a cursor for them would
 * add a paging contract the clients do not need.
 *
 * The cap is deliberately generous (200) and deliberately enforced rather than
 * assumed: the failure being fixed is a query whose row count is set by the
 * data, not by the code.
 */
export const LIST_ENDPOINT_MAX_LIMIT = 200;
export const LIST_ENDPOINT_DEFAULT_LIMIT = 50;

/**
 * A query-string `limit` arrives as a string, and `?limit=` arrives as an empty
 * string. Two separate hazards:
 *
 *  - without coercion, `'25'` fails `@IsInt()` and a valid page request 400s
 *  - with `@Type(() => Number)` alone, `''` becomes `0` and fails `@Min(1)`,
 *    which turns "the client sent no limit" into a client error
 *
 * So the coercion is explicit and it treats blank as absent, which is what the
 * caller meant. A non-numeric value is passed through untouched so the
 * validators can reject it with a real message rather than silently becoming
 * `NaN`.
 */
export function coerceOptionalLimit({ value }: { value: unknown }): unknown {
  if (value === undefined || value === null) return undefined;
  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (trimmed === '') return undefined;
    const parsed = Number(trimmed);
    return Number.isFinite(parsed) ? parsed : value;
  }
  return value;
}

export class ListQueryDto {
  /**
   * Optional rather than defaulted, so a direct TypeScript caller can pass `{}`
   * and have the service apply the default. `limit: number = …` would make it
   * required in the type while only defaulting at runtime through the
   * ValidationPipe — a mismatch that breaks every internal caller and every
   * unit test that constructs the DTO literally.
   */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(LIST_ENDPOINT_MAX_LIMIT)
  @Transform(coerceOptionalLimit)
  limit?: number;
}

export class GuaranteesPageQueryDto extends ListQueryDto {
  @IsOptional()
  @IsString()
  @MaxLength(40)
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  status?: string;
}

/** Kept separate so the enum stays the single source of truth. */
export class SubServiceListQueryDto extends ListQueryDto {
  @IsOptional()
  @IsString()
  @MaxLength(120)
  categoryId?: string;
}
