const { Client } = require('pg');
const client = new Client('postgresql://postgres:parin@localhost:5432/fixnow');

async function run() {
  await client.connect();
  const categories = await client.query('SELECT id, slug, name FROM service_categories');
  
  for (const row of categories.rows) {
    if (row.slug === 'plumbing') {
      await client.query(`INSERT INTO sub_services (category_id, name, price_minor, estimated_duration_minutes) VALUES 
      ('${row.id}', 'Tap Repair', 19900, 30),
      ('${row.id}', 'Pipe Leak Fix', 49900, 60),
      ('${row.id}', 'Toilet Installation', 99900, 120) ON CONFLICT DO NOTHING`);
    } else if (row.slug === 'electrical') {
      await client.query(`INSERT INTO sub_services (category_id, name, price_minor, estimated_duration_minutes) VALUES 
      ('${row.id}', 'Switch Replacement', 9900, 20),
      ('${row.id}', 'Fan Installation', 39900, 45) ON CONFLICT DO NOTHING`);
    } else {
      await client.query(`INSERT INTO sub_services (category_id, name, price_minor, estimated_duration_minutes) VALUES 
      ('${row.id}', 'Standard ${row.name}', 29900, 45) ON CONFLICT DO NOTHING`);
    }
  }
  console.log('Done inserting sub-services');
  await client.end();
}

run().catch(console.error);
