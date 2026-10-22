import { BadRequestException, NotFoundException } from '@nestjs/common';
import { AdminOperationsService } from './admin-operations.service';

describe('AdminOperationsService', () => {
  const categories = {
    find: jest.fn(),
    findOneBy: jest.fn(),
    delete: jest.fn(),
  };
  const query = {
    orderBy: jest.fn(),
    addOrderBy: jest.fn(),
    take: jest.fn(),
    andWhere: jest.fn(),
    getMany: jest.fn(),
  };
  const bookings = { createQueryBuilder: jest.fn(() => query) };
  const commands = { cancelBooking: jest.fn() };
  const service = new AdminOperationsService(
    categories as never,
    bookings as never,
    {} as never,
    commands as never,
  );
  beforeEach(() => {
    jest.clearAllMocks();
    for (const key of ['orderBy', 'addOrderBy', 'take', 'andWhere'] as const)
      query[key].mockReturnValue(query);
  });

  it('bounds catalog reads and applies later-page offsets in the repository', async () => {
    categories.find.mockResolvedValue([{ id: 'later-category' }]);
    await expect(
      service.listCategories({ limit: 9, offset: 56 }),
    ).resolves.toEqual([{ id: 'later-category' }]);
    expect(categories.find).toHaveBeenCalledWith({
      order: { displayOrder: 'ASC', name: 'ASC' },
      take: 9,
      skip: 56,
    });
  });

  it('classifies emergencies from catalog flags, not the booking description, and preserves a continuation', async () => {
    const booking = {
      id: 'b1',
      serviceCategoryId: 'urgent',
      description: 'Routine wording',
      updatedAt: new Date(),
      createdAt: new Date(),
    };
    query.getMany.mockResolvedValue([booking, { ...booking, id: 'b2' }]);
    categories.find.mockResolvedValue([{ id: 'urgent', isEmergency: true }]);
    const page = await service.listBookings({
      limit: 1,
      status: 'REQUESTED' as never,
      search: 'b',
    });
    expect(page.items).toHaveLength(1);
    expect(page.items[0].isEmergency).toBe(true);
    expect(page.nextCursor).toEqual(expect.any(String));
    expect(query.take).toHaveBeenCalledWith(2);
    expect(query.andWhere).toHaveBeenCalledWith('booking.status = :status', {
      status: 'REQUESTED',
    });
    expect(query.andWhere).toHaveBeenCalledWith(
      expect.stringContaining('ILIKE'),
      { search: 'b%' },
    );
  });

  it('rejects malformed cursors without reading booking rows', async () => {
    await expect(
      service.listBookings({ limit: 20, cursor: 'invalid' }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(query.getMany).not.toHaveBeenCalled();
  });

  it('reports deletion of an absent catalog category instead of false success', async () => {
    categories.delete.mockResolvedValue({ affected: 0 });
    await expect(service.deleteCategory('missing')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });
});
