export interface ServiceCategory {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  iconName: string | null;
  displayOrder: number;
  isActive: boolean;
  isEmergency: boolean;
  pricing: ServiceCategoryPricing | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface ServiceCategoryQuery {
  isActive?: boolean;
  isEmergency?: boolean;
}

export interface CreateServiceCategoryRequest {
  name: string;
  slug: string;
  description?: string;
  iconName?: string;
  displayOrder?: number;
  isActive?: boolean;
  isEmergency?: boolean;
  pricing?: CategoryPricingInput;
}

export interface UpdateServiceCategoryRequest {
  /** Absent leaves pricing unchanged; null clears to "price on request". */
  pricing?: CategoryPricingInput | null;
  name?: string;
  slug?: string;
  description?: string;
  iconName?: string;
  displayOrder?: number;
  isActive?: boolean;
  isEmergency?: boolean;
}
export interface ServiceCategoryPricing {
  /** Minor currency units (paise for INR). Non-negative. */
  amountMinor: number;
  currency: string;
}

export interface CategoryPricingInput {
  amountMinor: number;
  currency: string;
}
