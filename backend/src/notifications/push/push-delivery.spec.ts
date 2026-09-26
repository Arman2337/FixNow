import { ServiceUnavailableException } from '@nestjs/common';
import {
  DisabledPushDelivery,
  FakePushDelivery,
  FcmPushDelivery,
} from './push-delivery';
import { PushProviderName } from './push.module';

describe('FakePushDelivery', () => {
  it('records lock-screen-safe content and reports delivery', async () => {
    const fake = new FakePushDelivery();
    const result = await fake.sendToToken('t'.repeat(64), {
      title: 'New job nearby',
      body: 'Open FixNow to review the request.',
    });
    expect(result).toEqual({ status: 'sent' });
    expect(fake.sent).toHaveLength(1);
  });
});

// Regression: PUSH_PROVIDER=disabled used to resolve to FakePushDelivery, so a
// default or misconfigured deployment recorded SENT for every notification
// while nothing was delivered anywhere.
describe('DisabledPushDelivery', () => {
  it('reports unavailable instead of claiming a send', async () => {
    const disabled = new DisabledPushDelivery();
    await expect(
      disabled.sendToToken('t'.repeat(64), { title: 'x', body: 'y' }),
    ).resolves.toEqual({ status: 'unavailable' });
  });
});

describe('push provider selection', () => {
  const select = (provider: string | undefined) => {
    const fcm = { name: 'fcm' };
    const fake = { name: 'fake' };
    const disabled = { name: 'disabled' };
    switch (provider) {
      case PushProviderName.Fcm:
        return fcm;
      case PushProviderName.Fake:
        return fake;
      default:
        return disabled;
    }
  };

  it('never falls back to the fake provider, which reports sent', () => {
    expect(select(PushProviderName.Disabled).name).toBe('disabled');
    expect(select(undefined).name).toBe('disabled');
    expect(select('typo').name).toBe('disabled');
  });
});

describe('FcmPushDelivery configuration boundary', () => {
  const config = { get: jest.fn() } as never;

  it('refuses to send when no credential file is configured', async () => {
    config.get = jest.fn().mockReturnValue(undefined);
    const fcm = new FcmPushDelivery(config);
    await expect(
      fcm.sendToToken('e'.repeat(64), { title: 'x', body: 'y' }),
    ).rejects.toThrow(ServiceUnavailableException);
  });
});
