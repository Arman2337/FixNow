import { IsString, IsNotEmpty, IsUUID } from 'class-validator';

/**
 * Admin command to schedule the remedy booking for an approved guarantee claim.
 *
 * SECURITY (SEC-007): `providerId` used to be read as a bare
 * `@Body('providerId')` with no DTO, no `ValidationPipe` and no check that it
 * named anyone at all - any account id, including a customer's, was written
 * onto a live booking. The shape is declared here so the global pipe can reject
 * a malformed id, and `GuaranteesService` independently proves the id names an
 * active, verified provider for the booking's category.
 */
export class ReServiceBookingDto {
  @IsUUID()
  @IsNotEmpty()
  @IsString()
  providerId: string;
}
