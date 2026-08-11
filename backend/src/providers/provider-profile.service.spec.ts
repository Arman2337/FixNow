/* eslint-disable @typescript-eslint/unbound-method */
import { NotFoundException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ProviderApplicationEntity } from './provider-application.entity';
import { ProviderProfileEntity } from './provider-profile.entity';
import { ProviderProfileService } from './provider-profile.service';
import { ProviderSkillEntity } from './provider-skill.entity';

describe('ProviderProfileService', () => {
  let service: ProviderProfileService;
  let profiles: jest.Mocked<Repository<ProviderProfileEntity>>;
  let applications: jest.Mocked<Repository<ProviderApplicationEntity>>;
  let skills: jest.Mocked<Repository<ProviderSkillEntity>>;

  const profile: ProviderProfileEntity = {
    id: 'profile-id',
    userId: 'provider-id',
    user: {} as never,
    displayName: 'FixNow Plumbing',
    bio: 'Local repairs',
    serviceRadiusKm: 10,
    baseLatitude: 12.9716,
    baseLongitude: 77.5946,
    createdAt: new Date('2026-08-11T00:00:00Z'),
    updatedAt: new Date('2026-08-11T00:00:00Z'),
  };

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [
        ProviderProfileService,
        {
          provide: getRepositoryToken(ProviderProfileEntity),
          useValue: { findOne: jest.fn(), create: jest.fn(), save: jest.fn() },
        },
        {
          provide: getRepositoryToken(ProviderApplicationEntity),
          useValue: { findOne: jest.fn() },
        },
        {
          provide: getRepositoryToken(ProviderSkillEntity),
          useValue: { find: jest.fn() },
        },
      ],
    }).compile();

    service = module.get(ProviderProfileService);
    profiles = module.get(getRepositoryToken(ProviderProfileEntity));
    applications = module.get(getRepositoryToken(ProviderApplicationEntity));
    skills = module.get(getRepositoryToken(ProviderSkillEntity));
    skills.find.mockResolvedValue([{ id: 'skill-id' } as ProviderSkillEntity]);
  });

  it('returns the owning provider profile with associated skill IDs', async () => {
    profiles.findOne.mockResolvedValue({ ...profile });

    await expect(service.getOwnProfile('provider-id')).resolves.toEqual({
      ...profile,
      skillIds: ['skill-id'],
    });
    expect(profiles.findOne).toHaveBeenCalledWith({
      where: { userId: 'provider-id' },
    });
    expect(skills.find).toHaveBeenCalledWith({
      where: { userId: 'provider-id' },
      select: { id: true },
      order: { createdAt: 'ASC' },
    });
  });

  it('rejects a profile write for a user without a provider application', async () => {
    applications.findOne.mockResolvedValue(null);

    await expect(
      service.upsertOwnProfile('customer-id', {
        displayName: 'Customer',
        serviceRadiusKm: 10,
        baseLatitude: 0,
        baseLongitude: 0,
      }),
    ).rejects.toThrow(NotFoundException);
    expect(profiles.save).not.toHaveBeenCalled();
  });

  it('creates a profile owned by the authenticated provider', async () => {
    applications.findOne.mockResolvedValue({} as ProviderApplicationEntity);
    profiles.findOne.mockResolvedValue(null);
    profiles.create.mockReturnValue(profile);
    profiles.save.mockResolvedValue(profile);

    const result = await service.upsertOwnProfile('provider-id', {
      displayName: profile.displayName,
      bio: profile.bio,
      serviceRadiusKm: profile.serviceRadiusKm,
      baseLatitude: profile.baseLatitude,
      baseLongitude: profile.baseLongitude,
    });

    expect(profiles.create).toHaveBeenCalledWith(
      expect.objectContaining({ userId: 'provider-id' }),
    );
    expect(result.skillIds).toEqual(['skill-id']);
  });

  it('updates only the profile selected by authenticated user ID', async () => {
    applications.findOne.mockResolvedValue({} as ProviderApplicationEntity);
    profiles.findOne.mockResolvedValue({ ...profile });
    profiles.save.mockImplementation((value) => Promise.resolve(value));

    await service.upsertOwnProfile('provider-id', {
      displayName: 'Updated Name',
      serviceRadiusKm: 25,
      baseLatitude: 13,
      baseLongitude: 78,
    });

    expect(profiles.findOne).toHaveBeenCalledWith({
      where: { userId: 'provider-id' },
    });
    expect(profiles.save).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: 'provider-id',
        displayName: 'Updated Name',
        serviceRadiusKm: 25,
      }),
    );
  });

  it('treats a point on the radius boundary as covered', async () => {
    profiles.findOne.mockResolvedValue({
      ...profile,
      baseLatitude: 0,
      baseLongitude: 0,
      serviceRadiusKm: ProviderProfileService.distanceKm(0, 0, 0, 1),
    });

    await expect(
      service.checkCoverage('provider-id', { latitude: 0, longitude: 1 }),
    ).resolves.toEqual({ isWithinServiceArea: true });
  });

  it('rejects a point immediately outside the radius', async () => {
    profiles.findOne.mockResolvedValue({
      ...profile,
      baseLatitude: 0,
      baseLongitude: 0,
      serviceRadiusKm: 100,
    });

    await expect(
      service.checkCoverage('provider-id', { latitude: 0, longitude: 1 }),
    ).resolves.toEqual({ isWithinServiceArea: false });
  });

  it('does not disclose the provider base coordinates in coverage results', async () => {
    profiles.findOne.mockResolvedValue(profile);

    const result = await service.checkCoverage('provider-id', {
      latitude: 12.98,
      longitude: 77.6,
    });

    expect(result).toEqual({ isWithinServiceArea: true });
    expect(result).not.toHaveProperty('baseLatitude');
    expect(result).not.toHaveProperty('baseLongitude');
    expect(result).not.toHaveProperty('distanceKm');
  });
});
