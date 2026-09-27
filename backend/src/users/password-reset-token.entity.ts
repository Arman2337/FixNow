import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from 'typeorm';

/**
 * A single-use, expiring password-reset claim.
 *
 * The token is stored as a SHA-256 hash, matching how refresh tokens are
 * handled: a database disclosure must not yield usable reset links. The
 * plaintext exists only in the outbound email.
 *
 * Rows are not deleted after use. `consumed_at` is set instead, so that a
 * replayed link is detectable rather than merely inert - which matters
 * because "this token was already used" is a signal that a link leaked.
 */
@Entity({ name: 'password_reset_tokens' })
@Index('IDX_password_reset_tokens_identity', ['identityId'])
export class PasswordResetTokenEntity {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'identity_id', type: 'uuid' })
  identityId!: string;

  @Column({ name: 'token_hash', type: 'varchar', length: 64, unique: true })
  tokenHash!: string;

  @Column({ name: 'expires_at', type: 'timestamptz' })
  expiresAt!: Date;

  @Column({
    name: 'consumed_at',
    type: 'timestamptz',
    nullable: true,
    default: null,
  })
  consumedAt!: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;
}
