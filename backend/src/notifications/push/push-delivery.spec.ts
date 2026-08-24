import { ServiceUnavailableException } from '@nestjs/common';
import { FakePushDelivery, FcmPushDelivery } from './push-delivery';

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
