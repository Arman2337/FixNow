export interface ProviderSkill {
  id: string;
  userId: string;
  serviceCategoryId: string;
  yearsExperience: number | null;
  hourlyRateCents: number | null;
  visitFeeCents: number | null;
  description: string | null;
  isVerified: boolean;
  verificationNotes: string | null;
  createdAt: Date;
  updatedAt: Date;
  serviceCategory?: {
    id: string;
    name: string;
    slug: string;
    description: string | null;
    iconName: string | null;
    isEmergency: boolean;
  };
}

export interface ProviderSkillQuery {
  isVerified?: boolean;
  serviceCategoryId?: string;
}

export interface CreateProviderSkillRequest {
  serviceCategoryId: string;
  yearsExperience?: number;
  hourlyRateCents?: number;
  visitFeeCents?: number;
  description?: string;
}

export interface UpdateProviderSkillRequest {
  serviceCategoryId?: string;
  yearsExperience?: number;
  hourlyRateCents?: number;
  visitFeeCents?: number;
  description?: string;
}

export interface VerifyProviderSkillRequest {
  isVerified: boolean;
  verificationNotes?: string;
}

export interface ProviderSkillsCount {
  total: number;
  verified: number;
}