import 'reflect-metadata';
import { ForbiddenException } from '@nestjs/common';
import { PATH_METADATA } from '@nestjs/common/constants';
import type { AuthorizedRequest } from './authorization/authorization.guard';
import { REQUIRED_PERMISSION_KEY } from './authorization/authorization.decorators';
import { ProviderEarningsController } from '../payments/provider-earnings.controller';
import { ProviderApplicationController } from '../providers/provider-application.controller';
import { ProviderProfileController } from '../providers/provider-profile.controller';
import { ProviderAvailabilityController } from '../providers/availability/provider-availability.controller';
import { ProviderDocumentController } from '../providers/documents/provider-document.controller';
import { ProviderVerificationController } from '../providers/verification/provider-verification.controller';
import { RatingsController } from '../ratings/ratings.controller';
import { ProviderOnboardingStatus } from '../providers/provider-onboarding-status';

const request = (): AuthorizedRequest =>
  ({
    authorizationPrincipal: {
      userId: 'caller',
      sessionId: 'session',
      roles: [],
    },
  }) as unknown as AuthorizedRequest;

describe('Previously untested controller security boundaries', () => {
  it.each([
    ProviderEarningsController,
    ProviderApplicationController,
    ProviderProfileController,
    ProviderAvailabilityController,
    ProviderDocumentController,
    ProviderVerificationController,
    RatingsController,
  ])(
    '%p protects every exposed route with an explicit permission',
    (controller) => {
      const prototype = controller.prototype as unknown as Record<
        string,
        unknown
      >;
      const handlers = Object.getOwnPropertyNames(prototype)
        .filter((key) => key !== 'constructor')
        .map((key) => prototype[key])
        .filter(
          (handler) =>
            typeof handler === 'function' &&
            Reflect.hasMetadata(PATH_METADATA, handler),
        );
      expect(handlers.length).toBeGreaterThan(0);
      for (const handler of handlers) {
        expect(
          typeof Reflect.getMetadata(
            REQUIRED_PERMISSION_KEY,
            handler as object,
          ),
        ).toBe('string');
      }
    },
  );

  it('earnings derives identity from the authenticated principal and passes ownership proof for booking payments', async () => {
    const service = {
      providerEarnings: jest.fn().mockResolvedValue({ netMinor: 0 }),
      providerBookingPaymentStatus: jest
        .fn()
        .mockResolvedValue({ paid: false }),
    };
    const controller = new ProviderEarningsController(service as never);
    const req = request();
    await controller.earnings(req);
    expect(service.providerEarnings).toHaveBeenCalledWith('caller');
    expect(req.authorizationPrincipal!.ownershipProven).toBe(true);
    await controller.bookingPaymentStatus('booking', req);
    expect(service.providerBookingPaymentStatus).toHaveBeenCalledWith(
      'caller',
      'booking',
      req.authorizationPrincipal,
    );
  });

  it('application read refuses a foreign row even if a repository query were mis-scoped', async () => {
    const repository = {
      findOneBy: jest.fn().mockResolvedValue({ userId: 'other' }),
    };
    const controller = new ProviderApplicationController(
      repository as never,
      {} as never,
    );
    await expect(controller.getOwn(request())).rejects.toBeInstanceOf(
      ForbiddenException,
    );
    expect(repository.findOneBy).toHaveBeenCalledWith({ userId: 'caller' });
  });

  it.each([
    [
      'profile',
      (service: unknown) => new ProviderProfileController(service as never),
      'getOwnProfile',
    ],
    [
      'availability',
      (service: unknown) =>
        new ProviderAvailabilityController(service as never),
      'getOwn',
    ],
  ] as const)(
    '%s refuses foreign response ownership',
    async (_name, build, method) => {
      const service = {
        [method]: jest.fn().mockResolvedValue({ userId: 'other' }),
      };
      const controller = build(service);
      const read =
        controller instanceof ProviderProfileController
          ? () => controller.getOwnProfile(request())
          : () => controller.getOwn(request());
      await expect(read()).rejects.toBeInstanceOf(ForbiddenException);
    },
  );

  it('document list permits empty self data but rejects a foreign document before projection', async () => {
    const service = { listOwn: jest.fn().mockResolvedValue([]) };
    const controller = new ProviderDocumentController(service as never);
    await expect(controller.list(request())).resolves.toEqual({
      documents: [],
    });
    service.listOwn.mockResolvedValue([{ userId: 'other' }] as never);
    await expect(controller.list(request())).rejects.toBeInstanceOf(
      ForbiddenException,
    );
  });

  it('verification passes the real reviewer and expected version to the decision boundary', async () => {
    const service = { decide: jest.fn().mockResolvedValue({}) };
    const controller = new ProviderVerificationController(service as never);
    await controller.decide(request(), 'application', {
      expectedVersion: 3,
      decision: ProviderOnboardingStatus.Approved,
      reason: 'Evidence verified',
    });
    expect(service.decide).toHaveBeenCalledWith(
      'application',
      'caller',
      3,
      'approved',
      'Evidence verified',
    );
  });

  it('review reads pass the principal to service ownership checks and preserve an honest empty review', async () => {
    const ratings = { getForBooking: jest.fn().mockResolvedValue(null) };
    const controller = new RatingsController(ratings as never, {} as never);
    const req = request();
    await expect(controller.get('booking', req)).resolves.toEqual({
      review: null,
      providerRating: null,
    });
    expect(ratings.getForBooking).toHaveBeenCalledWith(
      'booking',
      'caller',
      req.authorizationPrincipal,
    );
  });
});
