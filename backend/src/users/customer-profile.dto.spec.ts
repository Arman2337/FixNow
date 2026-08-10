import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { UpdateCustomerProfileDto } from './customer-profile.dto';

describe('UpdateCustomerProfileDto', () => {
  async function errors(displayName: unknown) {
    return validate(plainToInstance(UpdateCustomerProfileDto, { displayName }));
  }

  it('trims and accepts a bounded display name', async () => {
    const dto = plainToInstance(UpdateCustomerProfileDto, {
      displayName: '  Ada Lovelace  ',
    });
    await expect(validate(dto)).resolves.toHaveLength(0);
    expect(dto.displayName).toBe('Ada Lovelace');
  });

  it.each(['', ' '.repeat(3), 'a'.repeat(81), 'unsafe\nname'])(
    'rejects invalid display name %p',
    async (displayName) => {
      expect(await errors(displayName)).not.toHaveLength(0);
    },
  );

  it('rejects non-string values', async () => {
    expect(await errors(123)).not.toHaveLength(0);
  });
});
