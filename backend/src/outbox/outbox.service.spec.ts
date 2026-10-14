import {
  DataSource,
  EntityManager,
  QueryFailedError,
  QueryRunner,
  Repository,
} from 'typeorm';
import { OutboxService } from './outbox.service';
import { OutboxMessage } from './outbox-message.entity';

describe('OutboxService', () => {
  let service: OutboxService;
  let dataSource: jest.Mocked<DataSource>;
  let outboxRepo: jest.Mocked<Repository<OutboxMessage>>;
  let queryRunner: jest.Mocked<QueryRunner>;

  beforeEach(() => {
    outboxRepo = {
      count: jest.fn(),
      insert: jest.fn(),
      update: jest.fn(),
      findOneBy: jest.fn(),
      createQueryBuilder: jest.fn(),
    } as unknown as jest.Mocked<Repository<OutboxMessage>>;

    queryRunner = {
      connect: jest.fn().mockResolvedValue(undefined),
      startTransaction: jest.fn().mockResolvedValue(undefined),
      commitTransaction: jest.fn().mockResolvedValue(undefined),
      rollbackTransaction: jest.fn().mockResolvedValue(undefined),
      release: jest.fn().mockResolvedValue(undefined),
      manager: {
        getRepository: jest.fn().mockReturnValue(outboxRepo),
      } as unknown as EntityManager,
    } as unknown as jest.Mocked<QueryRunner>;

    dataSource = {
      getRepository: jest.fn().mockReturnValue(outboxRepo),
      createQueryRunner: jest.fn().mockReturnValue(queryRunner),
    } as unknown as jest.Mocked<DataSource>;

    service = new OutboxService(dataSource);
  });

  describe('pendingBacklog', () => {
    it('counts rows with processedAt is null and claimedAt is null', async () => {
      (outboxRepo.count as jest.Mock).mockResolvedValue(5);

      const count = await service.pendingBacklog();

      expect(count).toBe(5);
      expect(outboxRepo.count).toHaveBeenCalledWith({
        where: expect.objectContaining({
          processedAt: expect.anything(),
          claimedAt: expect.anything(),
        }),
      });
    });
  });

  describe('enqueue', () => {
    it('inserts a message into the outbox within caller transaction and returns true', async () => {
      const managerRepo = {
        insert: jest.fn().mockResolvedValue({ identifiers: [{ id: 'msg-1' }] }),
      };
      const manager = {
        getRepository: jest.fn().mockReturnValue(managerRepo),
      } as unknown as EntityManager;

      const result = await service.enqueue(manager, {
        kind: 'booking.provider-fanout',
        dedupeKey: 'booking:b1:fanout',
        payload: { bookingId: 'b1' },
      });

      expect(result).toBe(true);
      expect(managerRepo.insert).toHaveBeenCalledWith(
        expect.objectContaining({
          kind: 'booking.provider-fanout',
          dedupeKey: 'booking:b1:fanout',
          attempts: 0,
        }),
      );
    });

    it('returns false when dedupe key unique violation occurs', async () => {
      const uniqueError = new QueryFailedError(
        'INSERT INTO outbox_messages...',
        [],
        {
          code: '23505',
        } as any,
      );
      const managerRepo = {
        insert: jest.fn().mockRejectedValue(uniqueError),
      };
      const manager = {
        getRepository: jest.fn().mockReturnValue(managerRepo),
      } as unknown as EntityManager;

      const result = await service.enqueue(manager, {
        kind: 'booking.provider-fanout',
        dedupeKey: 'booking:b1:fanout',
        payload: { bookingId: 'b1' },
      });

      expect(result).toBe(false);
    });
  });

  describe('claimBatch (lease locking)', () => {
    it('claims available rows using SKIP LOCKED and marks them claimed inside transaction', async () => {
      const mockMessages = [
        Object.assign(new OutboxMessage(), {
          id: 'm1',
          kind: 'booking.provider-fanout',
        }),
        Object.assign(new OutboxMessage(), {
          id: 'm2',
          kind: 'booking.provider-fanout',
        }),
      ];

      const qb: any = {
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        orderBy: jest.fn().mockReturnThis(),
        addOrderBy: jest.fn().mockReturnThis(),
        limit: jest.fn().mockReturnThis(),
        setLock: jest.fn().mockReturnThis(),
        setOnLocked: jest.fn().mockReturnThis(),
        getMany: jest.fn().mockResolvedValue(mockMessages),
      };
      (queryRunner.manager.getRepository as jest.Mock).mockReturnValue({
        createQueryBuilder: jest.fn().mockReturnValue(qb),
        update: jest.fn().mockResolvedValue({ affected: 2 }),
      });

      const claimed = await service.claimBatch(10);

      expect(claimed).toEqual(mockMessages);
      expect(qb.setLock).toHaveBeenCalledWith('pessimistic_write');
      expect(qb.setOnLocked).toHaveBeenCalledWith('skip_locked');
      expect(queryRunner.commitTransaction).toHaveBeenCalled();
      expect(queryRunner.release).toHaveBeenCalled();
    });

    it('rolls back and releases connection on failure', async () => {
      const qb: any = {
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        orderBy: jest.fn().mockReturnThis(),
        addOrderBy: jest.fn().mockReturnThis(),
        limit: jest.fn().mockReturnThis(),
        setLock: jest.fn().mockReturnThis(),
        setOnLocked: jest.fn().mockReturnThis(),
        getMany: jest.fn().mockRejectedValue(new Error('DB failure')),
      };
      (queryRunner.manager.getRepository as jest.Mock).mockReturnValue({
        createQueryBuilder: jest.fn().mockReturnValue(qb),
      });

      await expect(service.claimBatch(5)).rejects.toThrow('DB failure');
      expect(queryRunner.rollbackTransaction).toHaveBeenCalled();
      expect(queryRunner.release).toHaveBeenCalled();
    });
  });

  describe('markProcessed', () => {
    it('updates processedAt and clears claimedAt for given ids', async () => {
      (outboxRepo.update as jest.Mock).mockResolvedValue({ affected: 2 });

      await service.markProcessed(['m1', 'm2']);

      expect(outboxRepo.update).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({
          claimedAt: null,
          lastError: null,
          processedAt: expect.any(Date),
        }),
      );
    });

    it('does nothing when ids array is empty', async () => {
      await service.markProcessed([]);
      expect(outboxRepo.update).not.toHaveBeenCalled();
    });
  });

  describe('release (retries and dead-lettering)', () => {
    it('retries with exponential backoff when attempts are below max', async () => {
      const message = Object.assign(new OutboxMessage(), {
        id: 'm1',
        kind: 'booking.provider-fanout',
        attempts: 2,
      });
      (outboxRepo.findOneBy as jest.Mock).mockResolvedValue(message);
      (outboxRepo.update as jest.Mock).mockResolvedValue({ affected: 1 });

      await service.release('m1', new Error('Network timeout'));

      expect(outboxRepo.update).toHaveBeenCalledWith(
        { id: 'm1' },
        expect.objectContaining({
          claimedAt: null,
          availableAt: expect.any(Date),
          lastError: expect.stringContaining('Network timeout'),
        }),
      );
    });

    it('dead-letters/abandons message when attempts >= MAX_ATTEMPTS (5)', async () => {
      const message = Object.assign(new OutboxMessage(), {
        id: 'm1',
        kind: 'booking.provider-fanout',
        attempts: 5,
      });
      (outboxRepo.findOneBy as jest.Mock).mockResolvedValue(message);
      (outboxRepo.update as jest.Mock).mockResolvedValue({ affected: 1 });

      await service.release('m1', new Error('Permanent failure'));

      expect(outboxRepo.update).toHaveBeenCalledWith(
        { id: 'm1' },
        expect.objectContaining({
          claimedAt: null,
          processedAt: expect.any(Date),
          lastError: expect.stringContaining('Permanent failure'),
        }),
      );
    });
  });

  describe('prune', () => {
    it('deletes processed rows older than retention threshold', async () => {
      const qb: any = {
        delete: jest.fn().mockReturnThis(),
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        execute: jest.fn().mockResolvedValue({ affected: 12 }),
      };
      (outboxRepo.createQueryBuilder as jest.Mock).mockReturnValue(qb);

      const deletedCount = await service.prune(new Date('2026-08-01'));

      expect(deletedCount).toBe(12);
      expect(qb.where).toHaveBeenCalledWith('"processed_at" IS NOT NULL');
    });
  });
});
