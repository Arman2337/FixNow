import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { GuaranteesPageQueryDto, ListQueryDto } from './list-pagination.dto';
import { ServiceCategoryQueryDto } from '../services/service-categories.dto';
import { ProviderSkillQueryDto } from '../providers/provider-skills.dto';
import { SubServiceListQueryDto } from './list-pagination.dto';
import { LIST_ENDPOINT_MAX_LIMIT } from './list-pagination.dto';

/**
 * API-003. Four list endpoints returned `getMany()` with no `take()`, so their
 * row count was a property of the data rather than of the code:
 *
 *   - `GET /guarantees/claims`      append-only, one row per customer complaint
 *   - `GET /service-categories`     operator-published, unbounded by schema
 *   - `GET /sub-services`           operator-published, one row per task line
 *   - `GET /provider-skills/user/:id`  one row per provider per category
 *
 * The DTOs are the enforcement point, because a bound that lives only at a call
 * site is a bound a new call site can forget. These assertions pin the bound to
 * the request shape so the failure mode — an unbounded read whose cost is set by
 * whatever happens to be in the table — cannot come back unnoticed.
 */
describe('list endpoint bounds (API-003)', () => {
  const cases: Array<[string, new () => object]> = [
    ['GuaranteesPageQueryDto', GuaranteesPageQueryDto],
    ['ListQueryDto', ListQueryDto],
    ['ServiceCategoryQueryDto', ServiceCategoryQueryDto],
    ['ProviderSkillQueryDto', ProviderSkillQueryDto],
    ['SubServiceListQueryDto', SubServiceListQueryDto],
  ];

  it.each(cases)('%s rejects a limit above the cap', async (_name, cls) => {
    const errors = await validate(
      plainToInstance(cls, { limit: LIST_ENDPOINT_MAX_LIMIT + 1 }),
    );
    expect(errors.map((e) => e.property)).toContain('limit');
  });

  it.each(cases)('%s accepts the cap itself', async (_name, cls) => {
    const errors = await validate(
      plainToInstance(cls, { limit: LIST_ENDPOINT_MAX_LIMIT }),
    );
    expect(errors).toHaveLength(0);
  });

  it.each(cases)('%s accepts an absent limit', async (_name, cls) => {
    const errors = await validate(plainToInstance(cls, {}));
    expect(errors).toHaveLength(0);
  });

  it.each(cases)('%s rejects a fractional limit', async (_name, cls) => {
    const errors = await validate(plainToInstance(cls, { limit: 10.5 }));
    expect(errors.map((e) => e.property)).toContain('limit');
  });

  it.each(cases)('%s rejects a zero or negative limit', async (_name, cls) => {
    for (const limit of [0, -1]) {
      const errors = await validate(plainToInstance(cls, { limit }));
      expect(errors.map((e) => e.property)).toContain('limit');
    }
  });

  it('treats an empty query-string limit as absent rather than invalid', async () => {
    // `?limit=` arrives as an empty string. Without the transform this is a 400
    // on a request that should have fallen back to the default, which is how a
    // bound ends up looking user-hostile in production.
    const errors = await validate(
      plainToInstance(GuaranteesPageQueryDto, { limit: '' }),
    );
    expect(errors).toHaveLength(0);
  });

  it('coerces a string limit from the query string to a number', async () => {
    const dto = plainToInstance(GuaranteesPageQueryDto, { limit: '25' });
    expect(await validate(dto)).toHaveLength(0);
    expect(dto.limit).toBe(25);
  });
});
