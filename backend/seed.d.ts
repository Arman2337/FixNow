export interface CatalogItem {
  name: string;
  desc: string;
  price: number;
  duration: number;
  badge: string | null;
}

export interface SeedResult {
  insertedCount: number;
  existingCount: number;
  categoriesCount: number;
}

export const CATALOG: Record<string, CatalogItem[]>;

export function getCatalogForSlug(slug: string): CatalogItem[] | null;

export function getDatabaseUrl(): string;

export function createClient(connectionString: string): any;

export function seedCatalog(client: any): Promise<SeedResult>;

export function run(): Promise<void>;
