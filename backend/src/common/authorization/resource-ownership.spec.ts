import { ForbiddenException } from '@nestjs/common';
import type { AuthorizationPrincipal } from './authorization.types';
import {
  assertAssignedResource,
  assertIndependentApproval,
  assertNoResourceToProve,
  assertOwnedByParty,
  assertOwnedCollection,
  assertOwnedResource,
  assertScopedToCaller,
  assertTargetIsNotSelf,
} from './resource-ownership';

const caller = (): AuthorizationPrincipal => ({
  userId: 'caller',
  roles: [],
  sessionId: 'session',
});

describe('Deferred ownership proof boundaries', () => {
  it.each([assertOwnedResource, assertAssignedResource])(
    'rejects missing principals and foreign or null owners',
    (assertion) => {
      for (const owner of ['other', null, undefined]) {
        const principal = caller();
        expect(() => assertion(principal, owner)).toThrow(ForbiddenException);
        expect(principal.ownershipProven).toBeUndefined();
      }
      expect(() => assertion(undefined, 'caller')).toThrow(ForbiddenException);
      const principal = caller();
      assertion(principal, 'caller');
      expect(principal.ownershipProven).toBe(true);
    },
  );

  it('proves either actual booking party and rejects lists of absent/foreign parties', () => {
    const principal = caller();
    assertOwnedByParty(principal, null, 'caller');
    expect(principal.ownershipProven).toBe(true);
    expect(() => assertOwnedByParty(caller(), undefined, 'other')).toThrow(
      ForbiddenException,
    );
    expect(() => assertOwnedByParty(undefined, 'caller')).toThrow(
      ForbiddenException,
    );
  });

  it('refuses a mixed-owner collection even if its first row belongs to the caller', () => {
    for (const assertion of [assertOwnedCollection, assertScopedToCaller]) {
      const principal = caller();
      expect(() =>
        assertion(
          principal,
          [{ owner: 'caller' }, { owner: 'other' }],
          'owner',
        ),
      ).toThrow(ForbiddenException);
      expect(principal.ownershipProven).toBeUndefined();
      expect(() => assertion(undefined, [], 'owner')).toThrow(
        ForbiddenException,
      );
      assertion(principal, [{ owner: 'caller' }], 'owner');
      expect(principal.ownershipProven).toBe(true);
    }
  });

  it('distinguishes strict empty collection proof from an explicitly empty self collection', () => {
    expect(() => assertScopedToCaller(caller(), [], 'owner')).toThrow(
      ForbiddenException,
    );
    const principal = caller();
    assertOwnedCollection(principal, [], 'owner');
    expect(principal.ownershipProven).toBe(true);
  });

  it('requires a separate target and affirmative independent approval', () => {
    for (const target of ['caller', null, undefined]) {
      expect(() => assertTargetIsNotSelf(caller(), target)).toThrow(
        ForbiddenException,
      );
    }
    const principal = caller();
    assertTargetIsNotSelf(principal, 'other');
    expect(principal.ownershipProven).toBe(true);
    expect(() => assertIndependentApproval(caller(), false)).toThrow(
      ForbiddenException,
    );
    expect(() => assertIndependentApproval(undefined, true)).toThrow(
      ForbiddenException,
    );
    assertIndependentApproval(principal, true);
  });

  it('only discharges singleton routes for an authenticated principal', () => {
    expect(() => assertNoResourceToProve(undefined)).toThrow(
      ForbiddenException,
    );
    const principal = caller();
    assertNoResourceToProve(principal);
    expect(principal.ownershipProven).toBe(true);
  });
});
