/* Jest service mocks are intentionally asserted as detached functions. */
/* eslint-disable @typescript-eslint/unbound-method */
import { Test, TestingModule } from '@nestjs/testing';
import { ServiceCategoriesController } from './service-categories.controller';
import { ServiceCategoriesService } from './service-categories.service';
import {
  CreateServiceCategoryDto,
  UpdateServiceCategoryDto,
  ServiceCategoryQueryDto,
} from './service-categories.dto';

describe('ServiceCategoriesController', () => {
  let controller: ServiceCategoriesController;
  let service: jest.Mocked<ServiceCategoriesService>;

  const mockCategory = {
    id: 'test-id',
    name: 'Test Service',
    slug: 'test-service',
    description: 'Test Description',
    iconName: 'test-icon',
    displayOrder: 1,
    isActive: true,
    isEmergency: false,
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  beforeEach(async () => {
    const mockService = {
      findAll: jest.fn(),
      findById: jest.fn(),
      findBySlug: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
      getActiveCategories: jest.fn(),
      getEmergencyCategories: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [ServiceCategoriesController],
      providers: [
        {
          provide: ServiceCategoriesService,
          useValue: mockService,
        },
      ],
    }).compile();

    controller = module.get<ServiceCategoriesController>(
      ServiceCategoriesController,
    );
    service = module.get(ServiceCategoriesService);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('findAll', () => {
    it('should return all categories', async () => {
      const query: ServiceCategoryQueryDto = { isActive: true };
      service.findAll.mockResolvedValue([mockCategory]);

      const result = await controller.findAll(query);

      expect(service.findAll).toHaveBeenCalledWith(query);
      expect(result).toEqual([mockCategory]);
    });
  });

  describe('getActiveCategories', () => {
    it('should return active categories', async () => {
      service.getActiveCategories.mockResolvedValue([mockCategory]);

      const result = await controller.getActiveCategories();

      expect(service.getActiveCategories).toHaveBeenCalled();
      expect(result).toEqual([mockCategory]);
    });
  });

  describe('getEmergencyCategories', () => {
    it('should return emergency categories', async () => {
      service.getEmergencyCategories.mockResolvedValue([mockCategory]);

      const result = await controller.getEmergencyCategories();

      expect(service.getEmergencyCategories).toHaveBeenCalled();
      expect(result).toEqual([mockCategory]);
    });
  });

  describe('findById', () => {
    it('should return category by ID', async () => {
      service.findById.mockResolvedValue(mockCategory);

      const result = await controller.findById('test-id');

      expect(service.findById).toHaveBeenCalledWith('test-id');
      expect(result).toEqual(mockCategory);
    });
  });

  describe('findBySlug', () => {
    it('should return category by slug', async () => {
      service.findBySlug.mockResolvedValue(mockCategory);

      const result = await controller.findBySlug('test-service');

      expect(service.findBySlug).toHaveBeenCalledWith('test-service');
      expect(result).toEqual(mockCategory);
    });
  });

  describe('create', () => {
    it('should create new category', async () => {
      const createDto: CreateServiceCategoryDto = {
        name: 'New Service',
        slug: 'new-service',
        description: 'New Description',
      };
      service.create.mockResolvedValue(mockCategory);

      const result = await controller.create(createDto);

      expect(service.create).toHaveBeenCalledWith(createDto);
      expect(result).toEqual(mockCategory);
    });
  });

  describe('update', () => {
    it('should update category', async () => {
      const updateDto: UpdateServiceCategoryDto = {
        name: 'Updated Service',
      };
      service.update.mockResolvedValue({ ...mockCategory, ...updateDto });

      const result = await controller.update('test-id', updateDto);

      expect(service.update).toHaveBeenCalledWith('test-id', updateDto);
      expect(result).toEqual(expect.objectContaining(updateDto));
    });
  });

  describe('delete', () => {
    it('should delete category', async () => {
      service.delete.mockResolvedValue(undefined);

      await controller.delete('test-id');

      expect(service.delete).toHaveBeenCalledWith('test-id');
    });
  });
});
