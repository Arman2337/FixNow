import { Test, TestingModule } from '@nestjs/testing';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { ServiceCategoriesService } from './service-categories.service';
import { ServiceCategoryEntity } from './service-category.entity';

describe('ServiceCategoriesService (Integration)', () => {
  let service: ServiceCategoriesService;
  let dataSource: DataSource;

  beforeAll(async () => {
    const module: TestingModule = await Test.createTestingModule({
      imports: [
        TypeOrmModule.forRoot({
          type: 'postgres',
          url: 'postgresql://localhost:5432/fixnow_test',
          entities: [ServiceCategoryEntity],
          synchronize: true,
          dropSchema: true,
        }),
        TypeOrmModule.forFeature([ServiceCategoryEntity]),
      ],
      providers: [ServiceCategoriesService],
    }).compile();

    service = module.get<ServiceCategoriesService>(ServiceCategoriesService);
    dataSource = module.get<DataSource>(DataSource);
  });

  afterAll(async () => {
    await dataSource.destroy();
  });

  beforeEach(async () => {
    // Clean database before each test
    await dataSource.getRepository(ServiceCategoryEntity).clear();
  });

  describe('CRUD operations', () => {
    it('should create and retrieve service category', async () => {
      const createDto = {
        name: 'Test Plumbing',
        slug: 'test-plumbing',
        description: 'Professional plumbing services',
        iconName: 'plumbing',
        displayOrder: 1,
        isActive: true,
        isEmergency: false,
      };

      const created = await service.create(createDto);
      expect(created.id).toBeDefined();
      expect(created.name).toBe(createDto.name);
      expect(created.slug).toBe(createDto.slug);

      const retrieved = await service.findById(created.id);
      expect(retrieved).toEqual(created);
    });

    it('should update service category', async () => {
      const category = await service.create({
        name: 'Original Name',
        slug: 'original-slug',
        displayOrder: 1,
      });

      const updateDto = {
        name: 'Updated Name',
        description: 'Updated description',
        isActive: false,
      };

      const updated = await service.update(category.id, updateDto);
      expect(updated.name).toBe(updateDto.name);
      expect(updated.description).toBe(updateDto.description);
      expect(updated.isActive).toBe(false);
      expect(updated.slug).toBe('original-slug'); // Should remain unchanged
    });

    it('should delete service category', async () => {
      const category = await service.create({
        name: 'To Delete',
        slug: 'to-delete',
        displayOrder: 1,
      });

      await service.delete(category.id);
      await expect(service.findById(category.id)).rejects.toThrow();
    });

    it('should enforce unique constraints', async () => {
      await service.create({
        name: 'Unique Service',
        slug: 'unique-service',
        displayOrder: 1,
      });

      // Should fail due to unique name constraint
      await expect(
        service.create({
          name: 'Unique Service',
          slug: 'different-slug',
          displayOrder: 2,
        }),
      ).rejects.toThrow();

      // Should fail due to unique slug constraint
      await expect(
        service.create({
          name: 'Different Service',
          slug: 'unique-service',
          displayOrder: 2,
        }),
      ).rejects.toThrow();
    });
  });

  describe('query operations', () => {
    beforeEach(async () => {
      // Set up test data
      await Promise.all([
        service.create({
          name: 'Active Emergency',
          slug: 'active-emergency',
          displayOrder: 1,
          isActive: true,
          isEmergency: true,
        }),
        service.create({
          name: 'Active Normal',
          slug: 'active-normal',
          displayOrder: 2,
          isActive: true,
          isEmergency: false,
        }),
        service.create({
          name: 'Inactive Service',
          slug: 'inactive-service',
          displayOrder: 3,
          isActive: false,
          isEmergency: false,
        }),
      ]);
    });

    it('should filter by active status', async () => {
      const activeCategories = await service.findAll({ isActive: true });
      expect(activeCategories).toHaveLength(2);
      expect(activeCategories.every((cat) => cat.isActive)).toBe(true);

      const inactiveCategories = await service.findAll({ isActive: false });
      expect(inactiveCategories).toHaveLength(1);
      expect(inactiveCategories[0].isActive).toBe(false);
    });

    it('should filter by emergency status', async () => {
      const emergencyCategories = await service.findAll({ isEmergency: true });
      expect(emergencyCategories).toHaveLength(1);
      expect(emergencyCategories[0].isEmergency).toBe(true);
    });

    it('should combine filters', async () => {
      const activeEmergencyCategories = await service.findAll({
        isActive: true,
        isEmergency: true,
      });
      expect(activeEmergencyCategories).toHaveLength(1);
      expect(activeEmergencyCategories[0].name).toBe('Active Emergency');
    });

    it('should order by display order and name', async () => {
      const categories = await service.findAll({});
      expect(categories).toHaveLength(3);
      expect(categories[0].displayOrder).toBeLessThanOrEqual(
        categories[1].displayOrder,
      );
    });

    it('should find by slug', async () => {
      const category = await service.findBySlug('active-normal');
      expect(category.name).toBe('Active Normal');
    });

    it('should get active categories shorthand', async () => {
      const activeCategories = await service.getActiveCategories();
      expect(activeCategories).toHaveLength(2);
      expect(activeCategories.every((cat) => cat.isActive)).toBe(true);
    });

    it('should get emergency categories shorthand', async () => {
      const emergencyCategories = await service.getEmergencyCategories();
      expect(emergencyCategories).toHaveLength(1);
      expect(emergencyCategories[0].isEmergency).toBe(true);
      expect(emergencyCategories[0].isActive).toBe(true);
    });
  });
});
