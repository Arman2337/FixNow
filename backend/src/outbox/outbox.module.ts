import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { OutboxMessage } from './outbox-message.entity';
import { OutboxService, OutboxWorker } from './outbox.service';

/**
 * Global, and deliberately so. The outbox is infrastructure the way Redis is
 * infrastructure: a booking writes to it, an emergency writes to it, the
 * notification and realtime paths drain it, and none of those modules should
 * have to know which tier the worker lives in.
 *
 * The alternative - each feature module importing the outbox - produces the
 * same wiring with more coupling, because a fan-out handler for
 * `booking.provider-fanout` needs notifications, matching and projections, and
 * those live in three different modules.
 */
@Module({
  imports: [TypeOrmModule.forFeature([OutboxMessage])],
  providers: [OutboxService, OutboxWorker],
  exports: [OutboxService, OutboxWorker],
})
export class OutboxModule {}
