import { MigrationInterface, QueryRunner, Table, TableColumn, TableForeignKey } from 'typeorm';

export class DynamicDataPass1786521400000 implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.createTable(
      new Table({
        name: 'sub_services',
        columns: [
          { name: 'id', type: 'uuid', isPrimary: true, default: 'uuid_generate_v4()' },
          { name: 'category_id', type: 'uuid' },
          { name: 'name', type: 'varchar', length: '255' },
          { name: 'description', type: 'text', isNullable: true },
          { name: 'price_minor', type: 'integer', isNullable: true },
          { name: 'currency', type: 'varchar', length: '3', default: "'INR'", isNullable: true },
          { name: 'estimated_duration_minutes', type: 'integer', isNullable: true },
          { name: 'badge', type: 'varchar', length: '100', isNullable: true },
          { name: 'image_url', type: 'varchar', length: '1024', isNullable: true },
          { name: 'is_active', type: 'boolean', default: true },
          { name: 'created_at', type: 'timestamptz', default: 'now()' },
          { name: 'updated_at', type: 'timestamptz', default: 'now()' },
        ],
      }),
      true,
    );

    await queryRunner.createForeignKey(
      'sub_services',
      new TableForeignKey({
        columnNames: ['category_id'],
        referencedColumnNames: ['id'],
        referencedTableName: 'service_categories',
        onDelete: 'CASCADE',
      }),
    );

    await queryRunner.createTable(
      new Table({
        name: 'customer_addresses',
        columns: [
          { name: 'id', type: 'uuid', isPrimary: true, default: 'uuid_generate_v4()' },
          { name: 'user_id', type: 'uuid' },
          { name: 'label', type: 'varchar', length: '50', isNullable: true },
          { name: 'street', type: 'varchar', length: '255' },
          { name: 'city', type: 'varchar', length: '100' },
          { name: 'state', type: 'varchar', length: '100' },
          { name: 'zip', type: 'varchar', length: '20' },
          { name: 'latitude', type: 'decimal', precision: 10, scale: 7 },
          { name: 'longitude', type: 'decimal', precision: 10, scale: 7 },
          { name: 'is_default', type: 'boolean', default: false },
          { name: 'created_at', type: 'timestamptz', default: 'now()' },
          { name: 'updated_at', type: 'timestamptz', default: 'now()' },
        ],
      }),
      true,
    );

    await queryRunner.createForeignKey(
      'customer_addresses',
      new TableForeignKey({
        columnNames: ['user_id'],
        referencedColumnNames: ['user_id'],
        referencedTableName: 'customer_profiles',
        onDelete: 'CASCADE',
      }),
    );

    await queryRunner.createTable(
      new Table({
        name: 'booking_line_items',
        columns: [
          { name: 'id', type: 'uuid', isPrimary: true, default: 'uuid_generate_v4()' },
          { name: 'booking_id', type: 'uuid' },
          { name: 'sub_service_id', type: 'uuid' },
          { name: 'quantity', type: 'integer' },
          { name: 'price_minor', type: 'integer' },
          { name: 'created_at', type: 'timestamptz', default: 'now()' },
          { name: 'updated_at', type: 'timestamptz', default: 'now()' },
        ],
      }),
      true,
    );

    await queryRunner.createForeignKey(
      'booking_line_items',
      new TableForeignKey({
        columnNames: ['booking_id'],
        referencedColumnNames: ['id'],
        referencedTableName: 'bookings',
        onDelete: 'CASCADE',
      }),
    );

    await queryRunner.createTable(
      new Table({
        name: 'in_app_notifications',
        columns: [
          { name: 'id', type: 'uuid', isPrimary: true, default: 'uuid_generate_v4()' },
          { name: 'user_id', type: 'uuid' },
          { name: 'title', type: 'varchar', length: '255' },
          { name: 'body', type: 'text' },
          { name: 'kind', type: 'varchar', length: '64' },
          { name: 'booking_id', type: 'uuid', isNullable: true },
          { name: 'payment_id', type: 'uuid', isNullable: true },
          { name: 'read_at', type: 'timestamptz', isNullable: true },
          { name: 'created_at', type: 'timestamptz', default: 'now()' },
        ],
      }),
      true,
    );

    await queryRunner.addColumns('invoices', [
      new TableColumn({ name: 'subtotal_amount_minor', type: 'integer', default: 0 }),
      new TableColumn({ name: 'tax_amount_minor', type: 'integer', default: 0 }),
      new TableColumn({ name: 'discount_amount_minor', type: 'integer', default: 0 }),
    ]);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.dropColumns('invoices', ['subtotal_amount_minor', 'tax_amount_minor', 'discount_amount_minor']);
    await queryRunner.dropTable('in_app_notifications');
    await queryRunner.dropTable('booking_line_items');
    await queryRunner.dropTable('customer_addresses');
    await queryRunner.dropTable('sub_services');
  }
}
