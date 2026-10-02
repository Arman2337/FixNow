import {
  Controller,
  Get,
  Post,
  Body,
  Req,
  Param,
  Delete,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CustomerAddressEntity } from './customer-address.entity';
import { RequireOwnPermission } from '../common/authorization/authorization.decorators';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import {
  assertOwnedCollection,
  assertOwnedResource,
} from '../common/authorization/resource-ownership';
import { CreateCustomerAddressDto } from './dto/create-customer-address.dto';

@Controller('users/me/addresses')
export class CustomerAddressesController {
  constructor(
    @InjectRepository(CustomerAddressEntity)
    private readonly addressRepo: Repository<CustomerAddressEntity>,
  ) {}

  @Get()
  @RequireOwnPermission(PERMISSIONS.profileReadSelf)
  async list(@Req() request: AuthorizedRequest) {
    const principal = request.authorizationPrincipal!;
    const userId = principal.userId;
    const rows = await this.addressRepo.findBy({ userId });
    // SEC-002: the guarantee here is the `where: { userId }` predicate, which a
    // reader cannot verify and a later edit can silently drop. Handing the rows
    // actually read to the assertion makes it checkable.
    assertOwnedCollection(principal, rows, 'userId');
    return rows;
  }

  @Post()
  @RequireOwnPermission(PERMISSIONS.profileUpdateSelf)
  async create(
    @Req() request: AuthorizedRequest,
    // SEC-011: was a bare `type` alias, which the ValidationPipe skips entirely,
    // so latitude/longitude reached the database unchecked.
    @Body() body: CreateCustomerAddressDto,
  ) {
    const principal = request.authorizationPrincipal!;
    const userId = principal.userId;
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
    const saved = await this.addressRepo.save(address);
    assertOwnedResource(principal, saved.userId, 'customerAddress.userId');
    return saved;
  }

  @Delete(':id')
  @RequireOwnPermission(PERMISSIONS.profileUpdateSelf)
  async remove(@Req() request: AuthorizedRequest, @Param('id') id: string) {
    const principal = request.authorizationPrincipal!;
    const userId = principal.userId;
    // SEC-002. `delete({ id, userId })` was already scoped, but a scoped
    // DELETE that matched nothing still returned `{ success: true }`, so
    // deleting somebody else's id answered exactly like deleting your own —
    // indistinguishable, and a silent 200 on a write that never happened.
    // Load the row the caller owns first: absent is a 404, present is proven.
    const existing = await this.addressRepo.findOneBy({ id, userId });
    if (!existing) {
      throw new NotFoundException(`Address with ID ${id} not found`);
    }
    assertOwnedResource(principal, existing.userId, 'customerAddress.userId');
    await this.addressRepo.delete({ id });
    return { success: true };
  }
}
