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

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt!: Date;
}
