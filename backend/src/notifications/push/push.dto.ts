import { IsEnum, Length } from 'class-validator';
import { PushPlatform } from './push-device-token.entity';

export class RegisterPushDeviceDto {
  @Length(32, 4096)
  token!: string;

  @IsEnum(PushPlatform)
  platform!: PushPlatform;
}

/** Minimized device view. The raw token is never included. */
export interface PushDeviceResponse {
  id: string;
  platform: PushPlatform;
  createdAt: Date;
}
