/* Jest repository mocks are intentionally asserted as detached functions. */
/* eslint-disable @typescript-eslint/unbound-method */
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { NotFoundException } from '@nestjs/common';
import { ServiceCategoriesService } from './service-categories.service';
import { ServiceCategoryEntity } from './service-category.entity';
import {
  CreateServiceCategoryDto,
  UpdateServiceCategoryDto,
  ServiceCategoryQueryDto,
} from './service-categories.dto';

describe('ServiceCategoriesService', () => {
  let service: ServiceCategoriesService;
  let repository: jest.Mocked<Repository<ServiceCategoryEntity>>;

  const mockCategory: ServiceCategoryEntity = {
    id: 'test-id',
    name: 'Test Service',
    slug: 'test-service',
    description: 'Test Description',
    iconName: 'test-icon',
    displayOrder: 1,
    isActive: true,
    isEmergency: false,
    providerSkills: [],
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  const mockQueryBuilder = {
    andWhere: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    addOrderBy: jest.fn().mockReturnThis(),
    getMany: jest.fn(),
  };

  beforeEach(async () => {
    const mockRepository = {
      createQueryBuilder: jest.fn(() => mockQueryBuilder),
      findOne: jest.fn(),
      create: jest.fn(),
      save: jest.fn(),
      delete: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ServiceCategoriesService,
        {
          provide: getRepositoryToken(ServiceCategoryEntity),
          useValue: mockRepository,
        },
      ],
    }).compile();

    service = module.get<ServiceCategoriesService>(ServiceCategoriesService);
    repository = module.get(getRepositoryToken(ServiceCategoryEntity));
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('findAll', () => {
    it('should return all categories with no filters', async () => {
      const query: ServiceCategoryQueryDto = {};
      mockQueryBuilder.getMany.mockResolvedValue([mockCategory]);

      const result = await service.findAll(query);

      expect(repository.createQueryBuilder).toHaveBeenCalledWith('category');
      expect(mockQueryBuilder.orderBy).toHaveBeenCalledWith(
        'category.displayOrder',
        'ASC',
      );
      expect(mockQueryBuilder.addOrderBy).toHaveBeenCalledWith(
        'category.name',
        'ASC',
      );
      expect(result).toEqual([mockCategory]);
    });

    it('should filter by isActive when provided', async () => {
      const query: ServiceCategoryQueryDto = { isActive: true };
      mockQueryBuilder.getMany.mockResolvedValue([mockCategory]);

      await service.findAll(query);

      expect(mockQueryBuilder.andWhere).toHaveBeenCalledWith(
        'category.isActive = :isActive',
        { isActive: true },
      );
    });

    it('should filter by isEmergency when provided', async () => {
      const query: ServiceCategoryQueryDto = { isEmergency: true };
      mockQueryBuilder.getMany.mockResolvedValue([mockCategory]);

      await service.findAll(query);

      expect(mockQueryBuilder.andWhere).toHaveBeenCalledWith(
        'category.isEmergency = :isEmergency',
        { isEmergency: true },
      );
    });
  });

  describe('findById', () => {
    it('should return category when found', async () => {
      repository.findOne.mockResolvedValue(mockCategory);

      const result = await service.findById('test-id');

      expect(repository.findOne).toHaveBeenCalledWith({
        where: { id: 'test-id' },
        relations: { providerSkills: true },
      });
      expect(result).toEqual(mockCategory);
    });

    it('should throw NotFoundException when category not found', async () => {
      repository.findOne.mockResolvedValue(null);

      await expect(service.findById('non-existent')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('findBySlug', () => {
    it('should return category when found by slug', async () => {
      repository.findOne.mockResolvedValue(mockCategory);

      const result = await service.findBySlug('test-service');

      expect(repository.findOne).toHaveBeenCalledWith({
        where: { slug: 'test-service' },
        relations: { providerSkills: true },
      });
      expect(result).toEqual(mockCategory);
    });

    it('should throw NotFoundException when category not found by slug', async () => {
      repository.findOne.mockResolvedValue(null);

      await expect(service.findBySlug('non-existent')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('create', () => {
    it('should create and save new category', async () => {
      const createDto: CreateServiceCategoryDto = {
        name: 'New Service',
        slug: 'new-service',
        description: 'New Description',
      };

      repository.create.mockReturnValue(mockCategory);
      repository.save.mockResolvedValue(mockCategory);

      const result = await service.create(createDto);

      expect(repository.create).toHaveBeenCalledWith({
        ...createDto,
        priceAmount: null,
        priceCurrency: null,
      });
      expect(repository.save).toHaveBeenCalledWith(mockCategory);
      expect(result).toEqual(mockCategory);
    });
  });

  describe('update', () => {
    it('should update existing category', async () => {
      const updateDto: UpdateServiceCategoryDto = {
        name: 'Updated Service',
        description: 'Updated Description',
      };

      repository.findOne.mockResolvedValue(mockCategory);
      const updatedCategory = { ...mockCategory, ...updateDto };
      repository.save.mockResolvedValue(updatedCategory);

      const result = await service.update('test-id', updateDto);

      expect(repository.findOne).toHaveBeenCalledWith({
        where: { id: 'test-id' },
        relations: { providerSkills: true },
      });
      expect(repository.save).toHaveBeenCalledWith(
        expect.objectContaining(updateDto),
      );
      expect(result).toEqual(updatedCategory);
    });

    it('should throw NotFoundException for non-existent category', async () => {
      repository.findOne.mockResolvedValue(null);

      await expect(service.update('non-existent', {})).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('delete', () => {
    it('should delete category successfully', async () => {
      repository.delete.mockResolvedValue({ affected: 1, raw: {} });

      await service.delete('test-id');

      expect(repository.delete).toHaveBeenCalledWith('test-id');
    });

    it('should throw NotFoundException when no category affected', async () => {
      repository.delete.mockResolvedValue({ affected: 0, raw: {} });

      await expect(service.delete('non-existent')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('getActiveCategories', () => {
    it('should return only active categories', async () => {
      mockQueryBuilder.getMany.mockResolvedValue([mockCategory]);

      const result = await service.getActiveCategories();

      expect(mockQueryBuilder.andWhere).toHaveBeenCalledWith(
        'category.isActive = :isActive',
        { isActive: true },
      );
      expect(result).toEqual([mockCategory]);
    });
  });

  describe('getEmergencyCategories', () => {
    it('should return only emergency categories', async () => {
      mockQueryBuilder.getMany.mockResolvedValue([mockCategory]);

      const result = await service.getEmergencyCategories();

      expect(mockQueryBuilder.andWhere).toHaveBeenCalledWith(
        'category.isActive = :isActive',
        { isActive: true },
      );
      expect(mockQueryBuilder.andWhere).toHaveBeenCalledWith(
        'category.isEmergency = :isEmergency',
        { isEmergency: true },
      );
      expect(result).toEqual([mockCategory]);
    });
  });
});

describe('ServiceCategoriesService pricing', () => {
  let service: ServiceCategoriesService;
  let repository: {
    create: jest.Mock;
    save: jest.Mock;
    findOne: jest.Mock;
  };

  const baseCategory = () => ({
    id: 'cat-1',
    name: 'AC Service',
    slug: 'ac-service',
    description: null,
    iconName: null,
    displayOrder: 1,
    isActive: true,
    isEmergency: false,
    priceAmount: null,
    priceCurrency: null,
    providerSkills: [],
    createdAt: new Date(),
    updatedAt: new Date(),
  });

  beforeEach(() => {
    repository = {
      create: jest.fn(<T extends object>(value: T): T => value),
      save: jest.fn(<T extends object>(entity: T): Promise<T> =>
        Promise.resolve(entity),
      ),
      findOne: jest.fn().mockResolvedValue(baseCategory()),
    };
    service = new ServiceCategoriesService(repository as never);
  });

  it('creates a category with a published price', async () => {
    const dto: CreateServiceCategoryDto = {
      name: 'AC Service',
      slug: 'ac-service',
      pricing: { amountMinor: 49900, currency: 'INR' },
    };
    const result = await service.create(dto);
    expect(result.priceAmount).toBe(49900);
    expect(result.priceCurrency).toBe('INR');
  });

  it('creates a price-on-request category when pricing is absent', async () => {
    const result = await service.create({ name: 'Plumbing', slug: 'plumbing' });
    expect(result.priceAmount).toBeNull();
    expect(result.priceCurrency).toBeNull();
  });

  it('sets pricing on update', async () => {
    const result = await service.update('cat-1', {
      pricing: { amountMinor: 79900, currency: 'INR' },
    });
    expect(result.priceAmount).toBe(79900);
    expect(result.priceCurrency).toBe('INR');
  });

  it('clears pricing back to price-on-request with explicit null', async () => {
    const existing = baseCategory();
    existing.priceAmount = 49900;
    existing.priceCurrency = 'INR';
    repository.findOne.mockResolvedValue(existing);
    const result = await service.update('cat-1', { pricing: null });
    expect(result.priceAmount).toBeNull();
    expect(result.priceCurrency).toBeNull();
  });

  it('leaves pricing untouched when the field is absent from the update', async () => {
    const existing = baseCategory();
    existing.priceAmount = 49900;
    existing.priceCurrency = 'INR';
    repository.findOne.mockResolvedValue(existing);
    const result = await service.update('cat-1', { name: 'Renamed' });
    expect(result.name).toBe('Renamed');
    expect(result.priceAmount).toBe(49900);
    expect(result.priceCurrency).toBe('INR');
  });
});
