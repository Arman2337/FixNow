export enum ProviderAvailabilityStatus {
  Online = 'online',
  Busy = 'busy',
  Offline = 'offline',
}

export interface AvailabilityInterval {
  startMinute: number;
  endMinute: number;
}

export interface WeeklyAvailabilityRule {
  dayOfWeek: number;
  intervals: AvailabilityInterval[];
}

export interface AvailabilityException {
  date: string;
  unavailable: boolean;
  intervals: AvailabilityInterval[];
}
