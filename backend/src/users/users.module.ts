import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { IdentityEntity } from './identity.entity';
import { RoleEntity } from './role.entity';
import { UserRoleEntity } from './user-role.entity';
import { UserEntity } from './user.entity';
import { UsersRepository } from './users.repository';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      UserEntity,
      IdentityEntity,
      RoleEntity,
      UserRoleEntity,
    ]),
  ],
  providers: [UsersRepository],
  exports: [UsersRepository],
})
export class UsersModule {}
