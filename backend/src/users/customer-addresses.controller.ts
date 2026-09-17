import { Controller, Get, Post, Body, Req, Param, Delete } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CustomerAddressEntity } from './customer-address.entity';
import { RequireOwnPermission } from '../common/authorization/authorization.decorators';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';

@Controller('users/me/addresses')
export class CustomerAddressesController {
  constructor(
    @InjectRepository(CustomerAddressEntity)
    private readonly addressRepo: Repository<CustomerAddressEntity>,
  ) {}

  @Get()
  @RequireOwnPermission(PERMISSIONS.profileReadSelf)
  async list(@Req() request: AuthorizedRequest) {
    const userId = request.authorizationPrincipal!.userId;
    return await this.addressRepo.findBy({ userId });
  }

  @Post()
  @RequireOwnPermission(PERMISSIONS.profileUpdateSelf)
  async create(
    @Req() request: AuthorizedRequest,
    @Body() body: any,
  ) {
    const userId = request.authorizationPrincipal!.userId;
    // Set all other addresses to not default if this one is default
    if (body.isDefault) {
      await this.addressRepo.update({ userId }, { isDefault: false });
    }
    const address = this.addressRepo.create({
      userId,
      label: body.label,
      street: body.street,
      city: body.city,
      state: body.state,
      zip: body.zip,
      latitude: body.latitude,
      longitude: body.longitude,
      isDefault: body.isDefault,
    });
    return await this.addressRepo.save(address);
  }

  @Delete(':id')
  @RequireOwnPermission(PERMISSIONS.profileUpdateSelf)
  async remove(
    @Req() request: AuthorizedRequest,
    @Param('id') id: string,
  ) {
    const userId = request.authorizationPrincipal!.userId;
    await this.addressRepo.delete({ id, userId });
    return { success: true };
  }
}
