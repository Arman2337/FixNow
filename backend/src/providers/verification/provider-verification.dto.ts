import { IsIn, IsInt, IsString, Length, Min } from 'class-validator';
import { ProviderOnboardingStatus } from '../provider-onboarding-status';

export class ProviderVerificationDecisionDto {
  @IsIn([
    ProviderOnboardingStatus.Approved,
    ProviderOnboardingStatus.Rejected,
    ProviderOnboardingStatus.ResubmissionRequested,
  ])
  decision!:
    | ProviderOnboardingStatus.Approved
    | ProviderOnboardingStatus.Rejected
    | ProviderOnboardingStatus.ResubmissionRequested;
  @IsString() @Length(3, 1000) reason!: string;
  @IsInt() @Min(0) expectedVersion!: number;
}

export class ClaimProviderApplicationDto {
  @IsInt() @Min(0) expectedVersion!: number;
}
