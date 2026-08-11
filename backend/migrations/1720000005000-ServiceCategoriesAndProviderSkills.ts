import { MigrationInterface, QueryRunner } from 'typeorm';

export class ServiceCategoriesAndProviderSkills1720000005000 implements MigrationInterface {
  name = 'ServiceCategoriesAndProviderSkills1720000005000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // Create service_categories table
    await queryRunner.query(`
      CREATE TABLE "service_categories" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "name" varchar(255) NOT NULL,
        "slug" varchar(255) NOT NULL,
        "description" text,
        "icon_name" varchar(100),
        "display_order" integer NOT NULL DEFAULT 0,
        "is_active" boolean NOT NULL DEFAULT true,
        "is_emergency" boolean NOT NULL DEFAULT false,
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_service_categories_id" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_service_categories_name" UNIQUE ("name"),
        CONSTRAINT "UQ_service_categories_slug" UNIQUE ("slug")
      )
    `);

    // Create provider_skills table
    await queryRunner.query(`
      CREATE TABLE "provider_skills" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "user_id" uuid NOT NULL,
        "service_category_id" uuid NOT NULL,
        "years_experience" integer,
        "hourly_rate_cents" integer,
        "visit_fee_cents" integer,
        "description" text,
        "is_verified" boolean NOT NULL DEFAULT false,
        "verification_notes" text,
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_provider_skills_id" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_provider_skills_user_service" UNIQUE ("user_id", "service_category_id")
      )
    `);

    // Add foreign key constraints
    await queryRunner.query(`
      ALTER TABLE "provider_skills"
      ADD CONSTRAINT "FK_provider_skills_user"
      FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE
    `);

    await queryRunner.query(`
      ALTER TABLE "provider_skills"
      ADD CONSTRAINT "FK_provider_skills_service_category"
      FOREIGN KEY ("service_category_id") REFERENCES "service_categories"("id") ON DELETE CASCADE
    `);

    // Create indexes for better query performance
    await queryRunner.query(`CREATE INDEX "IDX_service_categories_is_active" ON "service_categories" ("is_active")`);
    await queryRunner.query(`CREATE INDEX "IDX_service_categories_display_order" ON "service_categories" ("display_order")`);
    await queryRunner.query(`CREATE INDEX "IDX_service_categories_is_emergency" ON "service_categories" ("is_emergency")`);
    await queryRunner.query(`CREATE INDEX "IDX_provider_skills_user_id" ON "provider_skills" ("user_id")`);
    await queryRunner.query(`CREATE INDEX "IDX_provider_skills_service_category_id" ON "provider_skills" ("service_category_id")`);
    await queryRunner.query(`CREATE INDEX "IDX_provider_skills_is_verified" ON "provider_skills" ("is_verified")`);

    // Insert initial service categories
    await queryRunner.query(`
      INSERT INTO "service_categories" ("name", "slug", "description", "icon_name", "display_order", "is_active", "is_emergency")
      VALUES
        ('Plumbing', 'plumbing', 'Pipe repairs, leak fixes, toilet and faucet installation', 'plumbing', 1, true, false),
        ('Electrical', 'electrical', 'Wiring, outlet installation, electrical repairs', 'electrical_services', 2, true, false),
        ('HVAC', 'hvac', 'Air conditioning, heating system repairs and maintenance', 'hvac', 3, true, false),
        ('Appliance Repair', 'appliance-repair', 'Refrigerator, washer, dryer, and appliance fixes', 'home_repair_service', 4, true, false),
        ('Locksmith', 'locksmith', 'Lock installation, key duplication, lockout assistance', 'lock', 5, true, true),
        ('Handyman', 'handyman', 'General home repairs, furniture assembly, minor fixes', 'handyman', 6, true, false),
        ('Cleaning', 'cleaning', 'House cleaning, deep cleaning, maintenance cleaning', 'cleaning_services', 7, true, false),
        ('Pest Control', 'pest-control', 'Insect and rodent removal, prevention treatments', 'pest_control', 8, true, false),
        ('Emergency Repair', 'emergency-repair', 'Urgent home repairs and emergency services', 'emergency', 9, true, true),
        ('Carpentry', 'carpentry', 'Wood work, cabinet installation, custom carpentry', 'carpenter', 10, true, false)
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // Drop foreign key constraints first
    await queryRunner.query(`ALTER TABLE "provider_skills" DROP CONSTRAINT "FK_provider_skills_service_category"`);
    await queryRunner.query(`ALTER TABLE "provider_skills" DROP CONSTRAINT "FK_provider_skills_user"`);
    
    // Drop indexes
    await queryRunner.query(`DROP INDEX "IDX_provider_skills_is_verified"`);
    await queryRunner.query(`DROP INDEX "IDX_provider_skills_service_category_id"`);
    await queryRunner.query(`DROP INDEX "IDX_provider_skills_user_id"`);
    await queryRunner.query(`DROP INDEX "IDX_service_categories_is_emergency"`);
    await queryRunner.query(`DROP INDEX "IDX_service_categories_display_order"`);
    await queryRunner.query(`DROP INDEX "IDX_service_categories_is_active"`);
    
    // Drop tables
    await queryRunner.query(`DROP TABLE "provider_skills"`);
    await queryRunner.query(`DROP TABLE "service_categories"`);
  }
}