import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  OneToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { IdentityEntity } from './identity.entity';

@Entity({ name: 'auth_credentials' })
export class CredentialEntity {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'identity_id', type: 'uuid', unique: true })
  identityId!: string;

  @OneToOne(() => IdentityEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'identity_id' })
  identity!: IdentityEntity;

  @Column({ name: 'password_hash', type: 'varchar', length: 512 })
  passwordHash!: string;

  /**
   * Consecutive failed verifications, reset by any success.
   *
   * The global 5/minute throttle is keyed on the caller address, so a shared
   * NAT egress gets one bucket and a single attacker rotating addresses gets
   * effectively unlimited attempts against one account. This is the
   * per-account counter that closes that.
   */
  @Column({ name: 'failed_login_count', type: 'int', default: 0 })
  failedLoginCount!: number;

  /**
   * When an account-level lockout expires, or null when it is not locked.
   *
   * A lockout is a real availability cost - a user who trips it cannot log in
   * for the window - so it is time-boxed rather than requiring an
   * administrator, and the error deliberately does not say which of the two
   * limits was hit.
   */
  @Column({
    name: 'locked_until',
    type: 'timestamptz',
    nullable: true,
    default: null,
  })
  lockedUntil!: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt!: Date;
}
