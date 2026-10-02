import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { EmergencyService } from './emergency.service';
import { OutboxWorker } from '../outbox/outbox.service';
import type { OutboxMessage } from '../outbox/outbox-message.entity';

/**
 * FN-082. Binds `emergency.wave` messages to the emergency service.
 *
 * A separate provider from {@link EmergencyService} for one reason: the
 * emergency service must be able to `enqueue` a wave from inside a transaction
 * without also being responsible for draining one, and a module that both
 * produces and consumes its own messages is hard to test in either direction.
 */
@Injectable()
export class EmergencyWaveHandlers implements OnModuleInit {
  private readonly logger = new Logger(EmergencyWaveHandlers.name);

  constructor(
    private readonly worker: OutboxWorker,
    private readonly emergency: EmergencyService,
  ) {}

  onModuleInit(): void {
    this.worker.register('emergency.wave', (message) => this.run(message));
  }

  private async run(message: OutboxMessage): Promise<void> {
    const bookingId = message.payload?.bookingId;
    const wave = message.payload?.wave;
    if (typeof bookingId !== 'string' || typeof wave !== 'number') {
      throw new Error(
        `emergency.wave message ${message.id} has no bookingId/wave payload`,
      );
    }
    const dispatched = await this.emergency.runWave(bookingId, wave);
    this.logger.debug(
      `Emergency ${bookingId} wave ${wave}: ${dispatched} providers notified`,
    );
  }
}
