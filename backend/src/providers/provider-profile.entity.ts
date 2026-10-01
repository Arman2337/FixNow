import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  OneToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { UserEntity } from '../users/user.entity';

@Entity({ name: 'provider_profiles' })
export class ProviderProfileEntity {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'user_id', type: 'uuid', unique: true })
  userId!: string;

  @OneToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: UserEntity;

  @Column({ name: 'display_name', type: 'varchar', length: 120 })
  displayName!: string;

  @Column({ type: 'varchar', length: 1000, nullable: true })
  bio!: string | null;

  @Column({ name: 'service_radius_km', type: 'double precision' })
  serviceRadiusKm!: number;

  @Column({ name: 'base_latitude', type: 'double precision' })
  baseLatitude!: number;

  @Column({ name: 'base_longitude', type: 'double precision' })
  baseLongitude!: number;

  /**
   * BUG-016. When this dispatch base location was last set.
   *
   * The distance predicate in `matching.service.ts` consumes
   * `base_latitude`/`base_longitude` and nothing else, so without a timestamp a
   * profile pinned eight months ago ranked identically to one set a second ago -
   * inside or outside every radius, with nothing to tell the two apart.
   *
   * A base location is a home base rather than a live position: a provider
   * legitimately sets it about once a week. So this is used for a staleness
   * bound, not for continuous tracking, and `MatchingService` excludes a profile
   * older than `PROVIDER_MAX_LOCATION_AGE_DAYS` rather than demanding live GPS.
   *
   * Defaults at the database as well as on the entity. A profile is also created
   * by `upsertOwnProfile`, where the coordinates come from the request body, so
   * a column that only the location endpoint set would be null for every provider
   * who registered with coordinates - and a NOT NULL column with no default is
   * how BUG-002 took booking creation down.
   */
  @Column({
    name: 'base_location_updated_at',
    type: 'timestamptz',
    default: () => 'now()',
  })
  baseLocationUpdatedAt!: Date;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt!: Date;
}
