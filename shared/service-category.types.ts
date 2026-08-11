export interface ServiceCategory {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  iconName: string | null;
  displayOrder: number;
  isActive: boolean;
  isEmergency: boolean;
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
}

export interface UpdateServiceCategoryRequest {
  name?: string;
  slug?: string;
  description?: string;
  iconName?: string;
  displayOrder?: number;
  isActive?: boolean;
  isEmergency?: boolean;
}