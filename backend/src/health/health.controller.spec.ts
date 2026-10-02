import { Test, TestingModule } from '@nestjs/testing';
import { ServiceUnavailableException } from '@nestjs/common';
import { HealthController } from './health.controller';
import { HealthCheckService, TypeOrmHealthIndicator } from '@nestjs/terminus';
import { ReadinessState } from './readiness-state.service';

describe('HealthController', () => {
  let controller: HealthController;
  let readiness: ReadinessState;
  const check = jest.fn();

  beforeEach(async () => {
    const mockHealthCheckService = { check };

    const mockTypeOrmHealthIndicator = {
      pingCheck: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [HealthController],
      providers: [
        {
          provide: HealthCheckService,
          useValue: mockHealthCheckService,
        },
        {
          provide: TypeOrmHealthIndicator,
          useValue: mockTypeOrmHealthIndicator,
        },
        {
          provide: ReadinessState,
          useValue: new ReadinessState(),
        },
      ],
    }).compile();

    controller = module.get<HealthController>(HealthController);
    readiness = module.get<ReadinessState>(ReadinessState);
    jest.clearAllMocks();
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  describe('checkLiveness', () => {
    it('should return ok status', () => {
      const result = controller.checkLiveness();
      expect(result.status).toBe('ok');
      expect(result.timestamp).toBeDefined();
    });

    // OPS-002. Liveness answers "should this process be restarted", and a
    // restarting process cannot finish a drain. A liveness probe that failed
    // during a deploy would turn a graceful shutdown into a crash loop.
    it('stays ok while draining, so the platform does not restart us', () => {
      readiness.beginDraining('SIGTERM');
      expect(controller.checkLiveness().status).toBe('ok');
    });

    it('does not consult the database', () => {
      controller.checkLiveness();
      expect(check).not.toHaveBeenCalled();
    });
  });

  describe('checkReadiness', () => {
    const healthy = {
      status: 'ok',
      info: { database: { status: 'up' } },
      error: {},
      details: { database: { status: 'up' } },
    };

    it('should check database readiness', async () => {
      check.mockResolvedValue(healthy);

      const result = await controller.checkReadiness();
      expect(check).toHaveBeenCalled();
      expect(result).toMatchObject({ status: 'ok', ready: true });
    });

    // The whole point of the drain: a 503, because every load balancer in
    // common use keys off the status code and ignores a 200 body that says
    // "not ready".
    it('returns 503 while draining', async () => {
      check.mockResolvedValue(healthy);
      readiness.beginDraining('SIGTERM');

      await expect(controller.checkReadiness()).rejects.toBeInstanceOf(
        ServiceUnavailableException,
      );
    });

    // BUG-012. A Redis that dies after boot cannot be fixed by refusing to
    // start, so the instance leaves the rotation instead of silently serving
    // work whose location and consent state is local to this process.
    it('returns 503 when a required dependency is unavailable', async () => {
      check.mockResolvedValue(healthy);
      readiness.reportDependencyFailure('cache.redis', 'ECONNREFUSED');

      await expect(controller.checkReadiness()).rejects.toBeInstanceOf(
        ServiceUnavailableException,
      );
    });

    it('returns to ready once the dependency recovers', async () => {
      check.mockResolvedValue(healthy);
      readiness.reportDependencyFailure('cache.redis', 'ECONNREFUSED');
      readiness.reportDependencyRecovered('cache.redis');

      await expect(controller.checkReadiness()).resolves.toMatchObject({
        ready: true,
      });
    });
  });

  describe('readiness state', () => {
    it('reports the drain without treating it as an error', () => {
      readiness.beginDraining('SIGTERM');
      expect(controller.state_()).toMatchObject({
        ready: false,
        draining: true,
      });
    });
  });
});
