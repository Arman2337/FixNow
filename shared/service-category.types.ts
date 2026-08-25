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
  /**
   * Number of verified providers who offer this category and hold an active
   * account. Real data derived from provider skills; 0 until providers
   * register — never a placeholder.
   */
  verifiedProCount: number;
  /**
   * Of the verified providers, how many are online right now (real-time
   * presence). Real data; 0 when none are live.
   */
  onlineProCount: number;
  /**
   * Average rating (1–5, one decimal) across published reviews for this
   * category, or null when it has no reviews yet.
   */
  rating: number | null;
  /** Number of published reviews behind {@link rating}. 0 when none. */
  reviewCount: number;
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
