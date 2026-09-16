import { NotificationInboxController } from './inbox.controller';

describe('NotificationInboxController', () => {
  const controller = new NotificationInboxController();

  it('returns an empty notifications list', () => {
    const result = controller.getInbox();
    expect(result).toEqual({ notifications: [] });
  });
});
