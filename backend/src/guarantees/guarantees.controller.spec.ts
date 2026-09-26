import 'reflect-metadata';
import { GuaranteesController } from './guarantees.controller';
import {
  OWN_RESOURCE_KEY,
  REQUIRED_PERMISSION_KEY,
} from '../common/authorization/authorization.decorators';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import { validate } from 'class-validator';
import { UpdateGuaranteeClaimDto } from './dto/update-guarantee-claim.dto';

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
