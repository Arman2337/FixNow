import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import {
  CoverageCheckDto,
  UpsertProviderProfileDto,
} from './provider-profile.dto';

describe('Provider profile DTO validation', () => {
  it('accepts bounded profile and geographic values', async () => {
    const dto = plainToInstance(UpsertProviderProfileDto, {
      displayName: 'FixNow Plumbing',
      bio: 'Local repairs',
      serviceRadiusKm: 100,
      baseLatitude: 90,
      baseLongitude: -180,
    });
    await expect(validate(dto)).resolves.toHaveLength(0);
  });

  it.each([
    { serviceRadiusKm: 0, baseLatitude: 0, baseLongitude: 0 },
    { serviceRadiusKm: 101, baseLatitude: 0, baseLongitude: 0 },
    { serviceRadiusKm: 10, baseLatitude: 91, baseLongitude: 0 },
    { serviceRadiusKm: 10, baseLatitude: 0, baseLongitude: 181 },
  ])('rejects an out-of-bounds profile: %o', async (coordinates) => {
    const dto = plainToInstance(UpsertProviderProfileDto, {
      displayName: 'FixNow Plumbing',
      ...coordinates,
    });
    expect(await validate(dto)).not.toHaveLength(0);
  });

  it('rejects invalid coverage coordinates', async () => {
    const dto = plainToInstance(CoverageCheckDto, {
      latitude: -91,
      longitude: 181,
    });
    expect(await validate(dto)).toHaveLength(2);
  });
});
