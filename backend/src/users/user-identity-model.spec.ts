import { getMetadataArgsStorage } from 'typeorm';
import { IdentityEntity } from './identity.entity';
import { RoleEntity } from './role.entity';
import { UserRoleEntity } from './user-role.entity';

describe('user identity model boundaries', () => {
  it('enforces unique external identities, role codes, and user role assignments', () => {
    const uniques = getMetadataArgsStorage().uniques;
    expect(uniques.find((item) => item.target === IdentityEntity)?.name).toBe(
      'uq_user_identities_provider_subject',
    );
    expect(uniques.find((item) => item.target === RoleEntity)?.name).toBe(
      'uq_roles_code',
    );
    expect(uniques.find((item) => item.target === UserRoleEntity)?.name).toBe(
      'uq_user_roles_user_role',
    );
  });

  it('contains no credential or plaintext-secret columns', () => {
    const identityColumns = getMetadataArgsStorage()
      .columns.filter((column) => column.target === IdentityEntity)
      .map((column) => column.propertyName);
    expect(identityColumns).toEqual(
      expect.arrayContaining(['provider', 'subject', 'verifiedAt']),
    );
    expect(identityColumns).not.toEqual(
      expect.arrayContaining(['password', 'secret', 'token']),
    );
  });
});
