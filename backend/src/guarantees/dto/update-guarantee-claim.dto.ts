import {
  IsEnum,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
} from 'class-validator';
import { GuaranteeClaimStatus } from '../domain/guarantee-claim.entity';

export class UpdateGuaranteeClaimDto {
  @IsOptional()
  @IsEnum(GuaranteeClaimStatus)
  status?: GuaranteeClaimStatus;

  @IsOptional()
  @IsString()
  @MaxLength(5000)
  adminNotes?: string;

  @IsOptional()
  @IsUUID()
  assignedProviderId?: string;
}
