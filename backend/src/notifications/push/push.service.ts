import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PushDeviceTokenEntity } from './push-device-token.entity';
import type { PushDeviceResponse, RegisterPushDeviceDto } from './push.dto';

function toResponse(entity: PushDeviceTokenEntity): PushDeviceResponse {
  return {
    id: entity.id,
    platform: entity.platform,
    createdAt: entity.createdAt,
  };
}

@Injectable()
export class PushDeviceService {
  constructor(
    @InjectRepository(PushDeviceTokenEntity)
    private readonly tokens: Repository<PushDeviceTokenEntity>,
  ) {}

  /**
   * Idempotent registration. A token is globally unique per device
   * installation; re-registration by a different account reassigns it because
   * only one account can be signed in on the installation.
   */
  async register(
    userId: string,
    input: RegisterPushDeviceDto,
  ): Promise<PushDeviceResponse> {
    const existing = await this.tokens.findOne({
      where: { token: input.token },
    });
    if (existing) {
      existing.userId = userId;
      existing.platform = input.platform;
      existing.enabled = true;
      return toResponse(await this.tokens.save(existing));
    }
    const created = this.tokens.create({
      userId,
      platform: input.platform,
      token: input.token,
      enabled: true,
    });
    return toResponse(await this.tokens.save(created));
  }

  async list(userId: string): Promise<PushDeviceResponse[]> {
    const rows = await this.tokens.find({
      where: { userId },
      order: { createdAt: 'DESC' },
    });
    return rows.map(toResponse);
  }

  /**
   * Revokes only when the device belongs to the requesting user.
   *
   * Returns the revoked row so the caller can prove ownership of it: the
   * delete resolves to `affected`, which says whether a row went but not whose
   * it was, and `PushDeviceResponse` deliberately omits the owner.
   */
  async revoke(
    userId: string,
    deviceId: string,
  ): Promise<PushDeviceTokenEntity> {
    const token = await this.tokens.findOneBy({ id: deviceId, userId });
    if (!token) {
      throw new NotFoundException('Device not found');
    }
    await this.tokens.delete({ id: deviceId });
    return token;
  }

  /** Removes a token reported as no longer registered by the provider. */
  async removeUnregistered(token: string): Promise<void> {
    await this.tokens.delete({ token });
  }
}
