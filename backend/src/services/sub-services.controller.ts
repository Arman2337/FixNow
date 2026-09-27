import {
  BadRequestException,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Query,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { SubServiceEntity } from './sub-service.entity';
import { Public } from '../common/authorization/authorization.decorators';

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
/** A category slug, restricted to characters that are safe in a LIKE prefix. */
const SLUG_PATTERN = /^[a-z0-9-]{1,64}$/;

@Controller('sub-services')
export class SubServicesController {
  constructor(
    @InjectRepository(SubServiceEntity)
    private readonly subServiceRepo: Repository<SubServiceEntity>,
  ) {}

  /**
   * Public catalogue listing.
   *
   * Errors are deliberately NOT caught here. `AllExceptionsFilter` already maps
   * every failure to a safe `{ statusCode, message, timestamp, path }` body and
   * logs the detail server-side only. An earlier `catch` block returned the raw
   * error message and the full JavaScript stack trace as a 200 OK response to an
   * unauthenticated caller, which disclosed absolute filesystem paths, the
   * compiled output layout and TypeORM internals. Never re-introduce that.
   */
  @Public()
  @Get()
  async list(@Query('categoryId') categoryId?: string) {
    const query = this.subServiceRepo
      .createQueryBuilder('sub_service')
      .leftJoin('sub_service.category', 'category')
      .where('sub_service.isActive = :isActive', { isActive: true });

    if (categoryId) {
      if (UUID_PATTERN.test(categoryId)) {
        query.andWhere('sub_service.categoryId = :categoryId', {
          categoryId,
        });
      } else if (SLUG_PATTERN.test(categoryId)) {
        const rootSlug = categoryId
          .replace(/[-_]services?/i, '')
          .replace(/[-_]repair/i, '');
        query.andWhere(
          '(category.slug = :categoryId OR category.slug ILIKE :prefix)',
          { categoryId, prefix: `${rootSlug}%` },
        );
      } else {
        // Rejecting here keeps a hostile value out of the LIKE pattern entirely
        // and gives the caller a precise, safe error instead of an empty list.
        throw new BadRequestException(
          'categoryId must be a UUID or a category slug',
        );
      }
    }

    return await query.getMany();
  }

  @Public()
  @Get(':id')
  async getOne(@Param('id', new ParseUUIDPipe({ version: '4' })) id: string) {
    return await this.subServiceRepo.findOneByOrFail({ id });
  }
}
