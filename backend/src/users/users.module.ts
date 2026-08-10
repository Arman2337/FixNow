import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { IdentityEntity } from './identity.entity';
import { RoleEntity } from './role.entity';
import { UserRoleEntity } from './user-role.entity';
import { UserEntity } from './user.entity';
import { UsersRepository } from './users.repository';
import { CredentialEntity } from './credential.entity';
import { CustomerProfileController } from './customer-profile.controller';
import { CustomerProfileEntity } from './customer-profile.entity';
import { CustomerProfileService } from './customer-profile.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      UserEntity,
      IdentityEntity,
      RoleEntity,
      UserRoleEntity,
      CredentialEntity,
      CustomerProfileEntity,
    ]),
  ],
  controllers: [CustomerProfileController],
  providers: [UsersRepository, CustomerProfileService],
  exports: [UsersRepository],
})
export class UsersModule {}
