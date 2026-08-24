export type ScheduleCadence = 'WEEKLY' | 'MONTHLY';

export type ScheduleStatus = 'ACTIVE' | 'PAUSED' | 'CANCELLED';

export interface RecurringScheduleContract {
  id: string;
  serviceCategoryId: string;
  description: string;
  locationLat: number;
  locationLng: number;
  cadence: ScheduleCadence;
  status: ScheduleStatus;
  /** Next unconfirmed occurrence; null once the schedule is terminal. */
  nextOccurrenceAt: string | null;
}

export type ScheduleAction = 'pause' | 'resume' | 'cancel';
