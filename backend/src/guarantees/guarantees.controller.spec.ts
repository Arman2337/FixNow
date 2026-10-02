import 'reflect-metadata';
import { GuaranteesController } from './guarantees.controller';
import {
  OWN_RESOURCE_KEY,
  REQUIRED_PERMISSION_KEY,
} from '../common/authorization/authorization.decorators';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';
import { CreateGuaranteeClaimDto } from './dto/create-guarantee-claim.dto';
import { UpdateGuaranteeClaimDto } from './dto/update-guarantee-claim.dto';

const UUID = '3f7c1a52-8d4e-4b16-9c33-2a5e7f0b91d4';

const getHandlerMetadata = (
  methodName: string,
  metadataKey: string,
): unknown => {
  const descriptor = Object.getOwnPropertyDescriptor(
    GuaranteesController.prototype,
    methodName,
  );
  const handler: unknown = descriptor?.value;
  if (typeof handler !== 'function') {
    throw new Error(`GuaranteesController.${methodName} is not defined`);
  }
  return Reflect.getMetadata(metadataKey, handler);
};

describe('GuaranteesController authorization metadata', () => {
  it('protects self-service creation and separates admin reads from updates', () => {
    expect(getHandlerMetadata('createClaim', REQUIRED_PERMISSION_KEY)).toBe(
      PERMISSIONS.guaranteeClaimCreateSelf,
    );
    expect(getHandlerMetadata('createClaim', OWN_RESOURCE_KEY)).toBe(true);
    expect(getHandlerMetadata('findAll', REQUIRED_PERMISSION_KEY)).toBe(
      PERMISSIONS.adminGuaranteesRead,
    );
    expect(getHandlerMetadata('findOne', REQUIRED_PERMISSION_KEY)).toBe(
      PERMISSIONS.adminGuaranteesRead,
    );
    expect(getHandlerMetadata('updateStatus', REQUIRED_PERMISSION_KEY)).toBe(
      PERMISSIONS.adminGuaranteesUpdate,
    );
    expect(
      getHandlerMetadata('createReServiceBooking', REQUIRED_PERMISSION_KEY),
    ).toBe(PERMISSIONS.adminGuaranteesUpdate);
  });

  it('accepts the documented guarantee status payload', async () => {
    const dto = Object.assign(new UpdateGuaranteeClaimDto(), {
      status: 'IN_REVIEW',
    });

    await expect(validate(dto)).resolves.toHaveLength(0);
  });
});

/**
 * SEC-010. The regression that let a dead endpoint survive: a DTO with no
 * class-validator decorators has no validation metadata, so the global pipe's
 * `whitelist: true, forbidNonWhitelisted: true` rejects every one of its own
 * declared properties. `POST /guarantees/claims` therefore answered 400 for
 * every possible request body, and nothing failed at boot or at compile time.
 *
 * These assertions run the real `validate` against the real DTO, which is what
 * the pipe does. Adding a field to a DTO without a decorator reintroduces the
 * bug for that field, so this test is the thing that has to be extended.
 */
describe('CreateGuaranteeClaimDto validation (SEC-010)', () => {
  const build = (plain: Record<string, unknown>) =>
    plainToInstance(CreateGuaranteeClaimDto, plain);

  it('accepts a well-formed claim, which it previously rejected outright', async () => {
    const dto = build({
      bookingId: UUID,
      description: 'The electrician never arrived and nobody called me back.',
    });

    await expect(validate(dto)).resolves.toHaveLength(0);
  });

  it('accepts a claim carrying evidence links', async () => {
    const dto = build({
      bookingId: UUID,
      description: 'The work was done but the fan is still not turning.',
      evidenceUrls: ['https://cdn.example.com/photo.jpg'],
    });

    await expect(validate(dto)).resolves.toHaveLength(0);
  });

  it('rejects a non-uuid bookingId', async () => {
    const dto = build({
      bookingId: 'not-a-uuid',
      description: 'A description long enough to pass the length bound.',
    });

    const errors = await validate(dto);
    expect(errors.map((e) => e.property)).toContain('bookingId');
  });

  it('rejects a description too short to be actionable', async () => {
    const dto = build({ bookingId: UUID, description: 'broken' });

    const errors = await validate(dto);
    expect(errors.map((e) => e.property)).toContain('description');
  });

  it('rejects more than ten evidence links', async () => {
    const dto = build({
      bookingId: UUID,
      description: 'A description long enough to pass the length bound.',
      evidenceUrls: Array.from(
        { length: 11 },
        (_, i) => `https://cdn.example.com/${i}.jpg`,
      ),
    });

    const errors = await validate(dto);
    expect(errors.map((e) => e.property)).toContain('evidenceUrls');
  });

  it('rejects a non-http evidence link', async () => {
    const dto = build({
      bookingId: UUID,
      description: 'A description long enough to pass the length bound.',
      evidenceUrls: ['javascript:alert(1)'],
    });

    const errors = await validate(dto);
    expect(errors.map((e) => e.property)).toContain('evidenceUrls');
  });
});
