import { Test, TestingModule } from '@nestjs/testing';
import { HealthController } from './health.controller';
import { HealthCheckService, TypeOrmHealthIndicator } from '@nestjs/terminus';

describe('HealthController', () => {
  let controller: HealthController;
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
      ],
    }).compile();

    controller = module.get<HealthController>(HealthController);
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
  });

  describe('checkReadiness', () => {
    it('should check database readiness', async () => {
      const mockResult = {
        status: 'ok',
        info: { database: { status: 'up' } },
        error: {},
        details: { database: { status: 'up' } },
      };
      check.mockResolvedValue(mockResult);

      const result = await controller.checkReadiness();
      expect(check).toHaveBeenCalled();
      expect(result).toEqual(mockResult);
    });
  });
});
