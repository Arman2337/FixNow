import 'reflect-metadata';
import { GuaranteesModule } from './guarantees.module';
import { MatchingModule } from '../matching/matching.module';
import { BookingsModule } from '../bookings/bookings.module';

describe('GuaranteesModule wiring', () => {
  // SEC-007/BUG-011: the re-service path now depends on BookingsService (for
  // the state machine) and MatchingService (to prove the named provider is
  // qualified). If either import is dropped, Nest fails at BOOT with a missing
  // dependency, which is exactly the kind of thing that reaches production
  // unnoticed without this assertion.
  it('imports the modules the re-service path depends on', () => {
    const imports =
      (Reflect.getMetadata('imports', GuaranteesModule) as unknown[]) ?? [];
    expect(imports).toContain(BookingsModule);
    expect(imports).toContain(MatchingModule);
  });
});
