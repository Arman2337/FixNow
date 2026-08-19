import {
  IsString,
  IsNotEmpty,
  IsOptional,
  IsUUID,
  IsEnum,
  MaxLength,
  IsArray,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ComplaintTargetRole } from '../domain/complaint.entity';

export class EvidenceDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  fileUrl: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(50)
  fileType: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  description?: string;
}

export class CreateComplaintDto {
  @IsOptional()
  @IsUUID()
  bookingId?: string;

  @IsEnum(ComplaintTargetRole)
  targetRole: ComplaintTargetRole;

  @IsOptional()
  @IsUUID()
  targetId?: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  category: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(5000)
  description: string;

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => EvidenceDto)
  evidence?: EvidenceDto[];
}
