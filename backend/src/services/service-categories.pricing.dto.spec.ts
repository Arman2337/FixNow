import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { UpdateServiceCategoryDto } from './service-categories.dto';

function dto(value: unknown) {
  return plainToInstance(UpdateServiceCategoryDto, { pricing: value });
}

describe('Category pricing validation', () => {
  it('accepts a bounded INR price in minor units', async () => {
    const errors = await validate(dto({ amountMinor: 49900, currency: 'INR' }));
    expect(errors).toHaveLength(0);
  });

  it('allows explicit null to clear the published price', async () => {
    const errors = await validate(dto(null));
    expect(errors).toHaveLength(0);
  });

  it('rejects unsupported currencies', async () => {
    const errors = await validate(dto({ amountMinor: 100, currency: 'USD' }));
    expect(errors.some((error) => error.property === 'pricing')).toBe(true);
  });

  it('rejects negative amounts', async () => {
    const errors = await validate(dto({ amountMinor: -1, currency: 'INR' }));
    expect(errors.some((error) => error.property === 'pricing')).toBe(true);
  });

  it('rejects amounts above the published ceiling', async () => {
    const errors = await validate(
      dto({ amountMinor: 10_000_01, currency: 'INR' }),
    );
    expect(errors.some((error) => error.property === 'pricing')).toBe(true);
  });
});
