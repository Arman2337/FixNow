import { Injectable, NotFoundException, ConflictException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { OptimisticLockVersionMismatchError } from 'typeorm';
import { Booking } from './domain/booking.entity';
import { CreateBookingDto } from './bookings.dto';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';

@Injectable()
export class BookingsService {
  constructor(
    @InjectRepository(Booking)
    private readonly bookingRepository: Repository<Booking>,
  ) {}

  async create(userId: string, input: CreateBookingDto): Promise<Booking> {
    const booking = new Booking();
    booking.customerId = userId;
    booking.serviceCategoryId = input.serviceCategoryId;
    booking.description = input.description;
    booking.locationLat = input.locationLat;
    booking.locationLng = input.locationLng;
    if (input.scheduledAt) {
      booking.scheduledAt = input.scheduledAt;
    }
    
    booking.status = BookingStatus.REQUESTED;
    
    return this.bookingRepository.save(booking);
  }

  async acceptBooking(bookingId: string, providerId: string): Promise<Booking> {
    const booking = await this.bookingRepository.findOne({ where: { id: bookingId } });
    if (!booking) {
      throw new NotFoundException('Booking not found');
    }
    if (booking.status !== BookingStatus.REQUESTED) {
      throw new ConflictException('Booking is no longer available');
    }
    
    booking.providerId = providerId;
    booking.transitionTo(BookingStatus.ASSIGNED);
    
    try {
      return await this.bookingRepository.save(booking);
    } catch (error) {
      if (error instanceof OptimisticLockVersionMismatchError || error?.name === 'OptimisticLockVersionMismatchError') {
        throw new ConflictException('Booking was already accepted by another provider');
      }
      throw error;
    }
  }

  async updateStatus(bookingId: string, providerId: string, status: string): Promise<Booking> {
    const booking = await this.bookingRepository.findOne({ where: { id: bookingId } });
    if (!booking) {
      throw new NotFoundException('Booking not found');
    }
    if (booking.providerId !== providerId) {
      throw new ForbiddenException('You are not assigned to this booking');
    }
    
    booking.transitionTo(status as BookingStatus);
    return this.bookingRepository.save(booking);
  }

  async cancelBooking(bookingId: string, userId: string, reason: string): Promise<Booking> {
    const booking = await this.bookingRepository.findOne({ where: { id: bookingId } });
    if (!booking) {
      throw new NotFoundException('Booking not found');
    }
    if (booking.customerId !== userId && booking.providerId !== userId) {
      throw new ForbiddenException('You are not authorized to cancel this booking');
    }
    if (booking.status === BookingStatus.COMPLETED) {
      throw new ConflictException('Cannot cancel a completed booking');
    }
    if (booking.status === BookingStatus.CANCELLED) {
      throw new ConflictException('Booking is already cancelled');
    }

    booking.transitionTo(BookingStatus.CANCELLED, reason);
    
    try {
      return await this.bookingRepository.save(booking);
    } catch (error) {
      if (error instanceof OptimisticLockVersionMismatchError || error?.name === 'OptimisticLockVersionMismatchError') {
        throw new ConflictException('Booking was modified by another user concurrently');
      }
      throw error;
    }
  }

  async getBookingHistory(userId: string, isProvider: boolean, limit: number = 10, offset: number = 0): Promise<Booking[]> {
    const query = this.bookingRepository.createQueryBuilder('booking');
    if (isProvider) {
      query.where('booking.providerId = :userId', { userId });
    } else {
      query.where('booking.customerId = :userId', { userId });
    }
    query.orderBy('booking.createdAt', 'DESC');
    query.take(limit);
    query.skip(offset);

    const bookings = await query.getMany();
    
    // Privacy: Redact exact location for completed/cancelled jobs from provider view
    return bookings.map(b => {
       if (isProvider && (b.status === BookingStatus.COMPLETED || b.status === BookingStatus.CANCELLED)) {
         b.locationLat = 0; // Redacted
         b.locationLng = 0; // Redacted
       }
       return b;
    });
  }
}
