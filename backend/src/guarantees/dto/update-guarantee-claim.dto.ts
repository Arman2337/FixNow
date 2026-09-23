import { GuaranteeClaimStatus } from '../domain/guarantee-claim.entity';

export class UpdateGuaranteeClaimDto {
  status?: GuaranteeClaimStatus;
  adminNotes?: string;
  assignedProviderId?: string;
}
