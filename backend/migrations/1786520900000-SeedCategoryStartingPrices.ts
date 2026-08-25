import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Seeds honest "from" starting prices for the service categories created in
 * {@link ServiceCategoriesAndProviderSkills1720000005000}. Categories shipped
 * with no price, so every card rendered "Price on request"; these give each a
 * concrete starting figure (e.g. "from ₹149") without inventing anything else.
 *
 * Amounts are stored in minor units (paise) per the `price_amount` column, with
 * `price_currency = 'INR'`, satisfying the CHK_service_categories_pricing_pair
 * constraint (both fields set). Figures are conservative visit/starting fees for
 * the Indian on-demand market and are intended to be tuned by admins later.
 *
 * `up` only fills rows still on "price on request" (`price_amount IS NULL`), so
 * it never overwrites a price an admin has already published. `down` reverts a
 * row to "price on request" only if it still holds the exact value seeded here,
 * so a rollback leaves any admin-adjusted price untouched.
 */
export class SeedCategoryStartingPrices1786520900000
  implements MigrationInterface
{
  name = 'SeedCategoryStartingPrices1786520900000';

  // slug → starting price in paise (₹ = paise / 100).
  private static readonly prices: ReadonlyArray<[string, number]> = [
    ['plumbing', 14900], // ₹149
    ['electrical', 14900], // ₹149
    ['hvac', 39900], // ₹399
    ['appliance-repair', 19900], // ₹199
    ['locksmith', 24900], // ₹249
    ['handyman', 14900], // ₹149
    ['cleaning', 49900], // ₹499
    ['pest-control', 59900], // ₹599
    ['emergency-repair', 29900], // ₹299
    ['carpentry', 19900], // ₹199
  ];

  private static valuesList(): string {
    return SeedCategoryStartingPrices1786520900000.prices
      .map(([slug, amount]) => `('${slug}', ${amount})`)
      .join(', ');
  }

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `UPDATE "service_categories" AS c
       SET "price_amount" = v.amount, "price_currency" = 'INR'
       FROM (VALUES ${SeedCategoryStartingPrices1786520900000.valuesList()}) AS v(slug, amount)
       WHERE c."slug" = v.slug AND c."price_amount" IS NULL`,
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `UPDATE "service_categories" AS c
       SET "price_amount" = NULL, "price_currency" = NULL
       FROM (VALUES ${SeedCategoryStartingPrices1786520900000.valuesList()}) AS v(slug, amount)
       WHERE c."slug" = v.slug
         AND c."price_amount" = v.amount
         AND c."price_currency" = 'INR'`,
    );
  }
}
