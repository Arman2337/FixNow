require('dotenv').config();
const { Client } = require('pg');
const connectionString = process.env.DATABASE_URL || 'postgresql://postgres:parin@localhost:5432/fixnow';
const client = new Client({
  connectionString,
  ssl: (connectionString.includes('localhost') || connectionString.includes('127.0.0.1')) ? false : { rejectUnauthorized: false }
});

const CATALOG = {
  'plumbing': [
    { name: 'Tap & Mixer Repair', desc: 'Fix leaking taps, replacement of spindles, washers & cartridges', price: 14900, duration: 30, badge: 'MOST POPULAR' },
    { name: 'Flush Tank & Jet Spray Fix', desc: 'Repair cistern siphon, ball valve or install health faucet', price: 24900, duration: 45, badge: null },
    { name: 'Shower & Water Pipe Leakage', desc: 'Under-sink pipe joints, concealed pipe leakage inspection', price: 34900, duration: 60, badge: 'BEST VALUE' },
    { name: 'Drain & Basin Clog Removal', desc: 'Deep unblocking of kitchen sinks, bathroom floor traps & gullies', price: 39900, duration: 45, badge: null },
    { name: 'Overhead Tank Overflow & Float', desc: 'Float valve replacement, overflow sensor troubleshooting', price: 49900, duration: 60, badge: null },
    { name: 'Toilet Installation & Commode Replacement', desc: 'Complete western/Indian commode fitting with wax ring seal', price: 99900, duration: 120, badge: null },
  ],
  'electrical': [
    { name: 'Switchboard / Socket Repair', desc: 'Repair loose connections, replace damaged 6A/16A switches', price: 14900, duration: 25, badge: 'MOST POPULAR' },
    { name: 'Ceiling Fan / Light Fixture Fix', desc: 'Installation, regulator check, capacitor replacement & balancing', price: 19900, duration: 35, badge: null },
    { name: 'MCB & Fuse Trip Troubleshooting', desc: 'Diagnose short circuits, replace tripped breaker or isolator', price: 29900, duration: 45, badge: 'EMERGENCY' },
    { name: 'Heavy Appliance Power Wiring', desc: 'Dedicated 25A point with earthing for AC, geyser or EV charger', price: 39900, duration: 60, badge: null },
    { name: 'Chandelier & Accent Lighting Setup', desc: 'Concealed wiring, bracket hanging and ambient light installation', price: 79900, duration: 90, badge: null },
  ],
  'hvac': [
    { name: 'AC Jet Foam Deep Service', desc: 'High-pressure foam wash for cooling coil, blower & filters', price: 49900, duration: 60, badge: 'BESTSELLER' },
    { name: 'AC Water Leakage & Drain Clear', desc: 'Unclog condensate drain pipe and fix indoor unit tray tilt', price: 39900, duration: 45, badge: null },
    { name: 'Refrigerant Gas Leak Check & Top-up', desc: 'Nitrogen pressure testing, flare nut tightening and gas charge', price: 79900, duration: 75, badge: 'BEST VALUE' },
    { name: 'AC Installation / Uninstallation', desc: 'Split or window AC mounting with copper pipe connection', price: 99900, duration: 90, badge: null },
  ],
  'appliance': [
    { name: 'Refrigerator Cooling & Defrost Fix', desc: 'Thermostat inspection, cooling coil defrost timer & fan motor', price: 19900, duration: 45, badge: 'POPULAR' },
    { name: 'Washing Machine Drum / Drain Repair', desc: 'Belt replacement, water drain pump unblocking & suspension rods', price: 29900, duration: 50, badge: null },
    { name: 'Microwave Heating / Turntable Fix', desc: 'Magnetron check, fuse replacement, roller ring repair', price: 24900, duration: 40, badge: null },
  ],
  'cleaning': [
    { name: 'Bathroom Deep Cleaning', desc: 'Hard water scale removal, tiles scrub, grout & sanitary sanitization', price: 49900, duration: 90, badge: 'TOP RATED' },
    { name: 'Kitchen Chimney & Counter Degrease', desc: 'Exhaustive grease removal from chimney filters, stove & tiles', price: 59900, duration: 120, badge: null },
    { name: 'Sofa & Upholstery Shampooing', desc: 'Deep extraction vacuuming & stain treatment per 3-seater sofa', price: 69900, duration: 90, badge: null },
    { name: 'Full Home Sanitization & Deep Cleaning', desc: 'Complete floor scrubbing, window dusting and germicidal spray', price: 149900, duration: 180, badge: 'BEST VALUE' },
  ],
  'locksmith': [
    { name: 'Door Lock Installation & Repair', desc: 'Mortise lock, cylinder replacement, alignment fixing', price: 24900, duration: 45, badge: null },
    { name: 'Emergency Lockout Assistance', desc: 'Rapid door unlock without destructive door damage', price: 39900, duration: 30, badge: 'URGENT' },
    { name: 'Smart Digital Lock Fitting', desc: 'Biometric fingerprint, keypad or RFID smart lock installation', price: 69900, duration: 60, badge: 'BEST VALUE' },
  ],
  'handyman': [
    { name: 'Wall Drill & Photo / Mirror Hanging', desc: 'Up to 3 items hung securely with rawl plugs & screws', price: 14900, duration: 30, badge: 'MOST POPULAR' },
    { name: 'Flat-Pack Furniture Assembly', desc: 'Bed, wardrobe, bookshelf, or table assembly according to manual', price: 34900, duration: 60, badge: null },
    { name: 'Curtain Rod & Shelf Mounting', desc: 'Wall brackets, curtain rails and floating shelves fixing', price: 29900, duration: 40, badge: null },
  ],
  'carpenter': [
    { name: 'Door Lock, Latch & Handle Fitting', desc: 'Main door lock, latch, peephole or handle fitment and alignment', price: 24900, duration: 30, badge: null },
    { name: 'Furniture Repair & Hinge Tightening', desc: 'Bed, wardrobe, drawer channel or hydraulic bed pump repair', price: 39900, duration: 60, badge: 'MOST POPULAR' },
    { name: 'Wooden Partition & Custom Shelving', desc: 'Drilling, shelf brackets, curtain rod or cabinet mounting', price: 59900, duration: 90, badge: null },
  ],
  'pest': [
    { name: 'Cockroach & Ant Gel Treatment', desc: 'Odorless herbal gel baiting across all kitchen corners and drain traps', price: 49900, duration: 45, badge: 'MOST POPULAR' },
    { name: 'Bed Bug Eradication Plan', desc: '2-stage intensive chemical spray treatment with 90-day warranty', price: 99900, duration: 60, badge: null },
    { name: 'Termite Deep Protection Barrier', desc: 'Drill-fill-seal subterranean perimeter defense barrier', price: 129900, duration: 90, badge: 'BEST VALUE' },
  ],
  'emergency': [
    { name: 'Emergency SOS Rapid Assessment', desc: 'Priority field response dispatch for urgent safety hazards', price: 29900, duration: 25, badge: 'EMERGENCY' },
    { name: 'Major Gas / Water Seepage Containment', desc: 'Main supply shutoff, emergency pipe clamps and hazardous isolation', price: 49900, duration: 45, badge: 'URGENT' },
  ],
};

function getCatalogForSlug(slug) {
  const s = slug.toLowerCase();
  if (s.includes('plumb')) return CATALOG['plumbing'];
  if (s.includes('electr')) return CATALOG['electrical'];
  if (s.includes('hvac') || s.includes('ac')) return CATALOG['hvac'];
  if (s.includes('appliance')) return CATALOG['appliance'];
  if (s.includes('clean')) return CATALOG['cleaning'];
  if (s.includes('lock')) return CATALOG['locksmith'];
  if (s.includes('handy')) return CATALOG['handyman'];
  if (s.includes('carpent')) return CATALOG['carpenter'];
  if (s.includes('pest')) return CATALOG['pest'];
  if (s.includes('emerg')) return CATALOG['emergency'];
  return null;
}

async function run() {
  await client.connect();
  const categories = await client.query('SELECT id, slug, name FROM service_categories');
  
  // Clear old minimal rows
  await client.query('DELETE FROM sub_services');

  for (const cat of categories.rows) {
    const items = getCatalogForSlug(cat.slug) || [
      { name: `Standard ${cat.name} Inspection`, desc: `On-site technician visit, problem assessment & repair`, price: 24900, duration: 45, badge: 'POPULAR' },
      { name: `Comprehensive ${cat.name} Overhaul`, desc: `Complete diagnostic, parts replacement and 30-day warranty`, price: 59900, duration: 90, badge: 'BEST VALUE' },
    ];

    for (const item of items) {
      await client.query(
        `INSERT INTO sub_services (category_id, name, description, price_minor, estimated_duration_minutes, badge, is_active)
         VALUES ($1, $2, $3, $4, $5, $6, true)`,
        [cat.id, item.name, item.desc, item.price, item.duration, item.badge]
      );
    }
  }

  console.log('Successfully seeded rich sub-services catalog into database!');
  await client.end();
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
