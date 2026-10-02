import 'reflect-metadata';
import { ArgumentMetadata, ValidationPipe } from '@nestjs/common';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { CustomerAddressesController } from './customer-addresses.controller';
import { CreateCustomerAddressDto } from './dto/create-customer-address.dto';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import {
  OWN_RESOURCE_KEY,
  REQUIRED_PERMISSION_KEY,
} from '../common/authorization/authorization.decorators';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';

/**
 * SEC-011. The customer address body was a bare `type` alias.
 *
 * `ValidationPipe` validates only when the target's metatype is a class. A type
 * alias is erased at runtime, so the pipe passed the whole body through
 * untouched and `latitude`/`longitude` were written to `customer_addresses` as
 * whatever the client sent. That row is what dispatch measures distance from, so
 * an out-of-range coordinate is not cosmetic.
 */
describe('CreateCustomerAddressDto (SEC-011)', () => {
  const build = (plain: Record<string, unknown>) =>
    plainToInstance(CreateCustomerAddressDto, plain);

  const valid = {
    street: '4 Palm Grove',
    city: 'Pune',
    state: 'MH',
    zip: '411001',
    latitude: 18.5074,
    longitude: 73.8577,
  };

  const propertyNames = async (plain: Record<string, unknown>) =>
    (await validate(build(plain))).map((e) => e.property);

  it('accepts a well-formed address', async () => {
    await expect(validate(build(valid))).resolves.toHaveLength(0);
  });

  it('rejects a latitude above 90', async () => {
    expect(await propertyNames({ ...valid, latitude: 91 })).toContain(
      'latitude',
    );
  });

  it('rejects a latitude below -90', async () => {
    expect(await propertyNames({ ...valid, latitude: -90.1 })).toContain(
      'latitude',
    );
  });

  it('rejects a longitude above 180', async () => {
    expect(await propertyNames({ ...valid, longitude: 181 })).toContain(
      'longitude',
    );
  });

  it('rejects a non-numeric coordinate', async () => {
    expect(await propertyNames({ ...valid, latitude: 'north' })).toContain(
      'latitude',
    );
  });

  it('rejects a missing street', async () => {
    const { street, ...withoutStreet } = valid;
    void street;
    expect(await propertyNames(withoutStreet)).toContain('street');
  });

  it('rejects an over-long street against the varchar column', async () => {
    expect(
      await propertyNames({ ...valid, street: 'x'.repeat(256) }),
    ).toContain('street');
  });

  it('rejects a non-boolean isDefault', async () => {
    expect(await propertyNames({ ...valid, isDefault: 'yes' })).toContain(
      'isDefault',
    );
  });
});

describe('CustomerAddressesController (SEC-011)', () => {
  const valid = {
    street: '4 Palm Grove',
    city: 'Pune',
    state: 'MH',
    zip: '411001',
    latitude: 18.5074,
    longitude: 73.8577,
  };

  const metadata = (method: string, key: string): unknown => {
    const descriptor = Object.getOwnPropertyDescriptor(
      CustomerAddressesController.prototype,
      method,
    );
    const handler: unknown = descriptor?.value;
    if (typeof handler !== 'function') {
      throw new Error(`CustomerAddressesController.${method} is missing`);
    }
    return Reflect.getMetadata(key, handler);
  };

  /**
   * The behavioural half of the bug: run the real `ValidationPipe`, configured
   * exactly as `main.ts` configures it, against this DTO. Before the fix the
   * parameter was a bare `type`, the pipe's `toValidate()` returned false, and
   * an out-of-range coordinate passed straight through to the database.
   *
   * This drives the pipe rather than reading `design:paramtypes`, because the
   * pipe's own answer is the property that matters and it is also the one that
   * survives a compiler-settings change.
   */
  it('is rejected by the real ValidationPipe for an out-of-range coordinate', async () => {
    const pipe = new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    });

    const metadata: ArgumentMetadata = {
      type: 'body',
      metatype: CreateCustomerAddressDto,
      data: undefined,
    };

    await expect(
      pipe.transform({ ...valid, latitude: 999 }, metadata),
    ).rejects.toThrow();

    await expect(pipe.transform(valid, metadata)).resolves.toMatchObject({
      latitude: 18.5074,
    });
  });

  it('is rejected by the real ValidationPipe when given no class at all', async () => {
    // The exact condition that hid the bug: a non-class metatype makes the pipe
    // a pass-through. Pinning it here documents why the DTO must be a class.
    const pipe = new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    });

    const erased: ArgumentMetadata = {
      type: 'body',
      metatype: Object,
      data: undefined,
    };

    await expect(
      pipe.transform({ ...valid, latitude: 999 }, erased),
    ).resolves.toMatchObject({ latitude: 999 });
  });

  it('keeps both address routes self-scoped', () => {
    expect(metadata('list', REQUIRED_PERMISSION_KEY)).toBe(
      PERMISSIONS.profileReadSelf,
    );
    expect(metadata('create', REQUIRED_PERMISSION_KEY)).toBe(
      PERMISSIONS.profileUpdateSelf,
    );
    expect(metadata('remove', REQUIRED_PERMISSION_KEY)).toBe(
      PERMISSIONS.profileUpdateSelf,
    );
    expect(metadata('create', OWN_RESOURCE_KEY)).toBe(true);
    expect(metadata('remove', OWN_RESOURCE_KEY)).toBe(true);
  });

  it("refuses to delete an address that is not the caller's, and says so", async () => {
    const repository = {
      findBy: jest.fn(),
      create: jest.fn(),
      save: jest.fn(),
      update: jest.fn(),
      findOneBy: jest.fn().mockResolvedValue(null),
      delete: jest.fn(),
    };
    const controller = new CustomerAddressesController(repository as never);
    const request = {
      authorizationPrincipal: { userId: 'user-1', sessionId: 's', roles: [] },
    } as unknown as AuthorizedRequest;

    await expect(
      controller.remove(request, 'someone-elses-address'),
    ).rejects.toThrow(/not found/i);

    expect(repository.delete).not.toHaveBeenCalled();
  });
});
