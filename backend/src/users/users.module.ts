import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { IdentityEntity } from './identity.entity';
import { RoleEntity } from './role.entity';
import { UserRoleEntity } from './user-role.entity';
import { UserEntity } from './user.entity';
import { UsersRepository } from './users.repository';
import { CredentialEntity } from './credential.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      UserEntity,
      IdentityEntity,
      RoleEntity,
      UserRoleEntity,
      CredentialEntity,
    ]),
  ],
  providers: [UsersRepository],
  exports: [UsersRepository],
})
export class UsersModule {}
