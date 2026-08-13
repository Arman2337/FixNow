export type UserSummary = Readonly<{
  id: string;
  status: string;
  roles: readonly string[];
  createdAt: string;
  updatedAt: string;
}>;

export type UserPage = Readonly<{ items: readonly UserSummary[]; nextCursor: string | null }>;
