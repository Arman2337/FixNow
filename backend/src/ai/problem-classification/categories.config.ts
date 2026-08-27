/**
 * Centralized FixNow problem-classification taxonomy.
 *
 * This is the ONLY category label space the AI may choose from (ADR-0014: the
 * model never invents a category). It is deliberately a plain, editable array
 * so the taxonomy can change without touching prompt, schema, or service code.
 *
 * This taxonomy is the classification label space. It is NOT the authoritative
 * bookable catalog — the classification service grounds a chosen category
 * against the active DB catalog (`ServiceCategoriesService`) by `slug`/`name`
 * for the bookable handoff, and stays advisory-only when there is no match.
 */

export interface FixNowCategory {
  /** Human-readable label shown to technicians/customers. */
  readonly name: string;
  /** Stable slug used to ground against the DB service catalog. */
  readonly slug: string;
  /** Allowed subcategory hints for this category. */
  readonly subcategories: readonly string[];
}

/** The catch-all category used when no confident mapping exists. */
export const OTHER_CATEGORY = 'Other';

export const FIXNOW_CATEGORIES: readonly FixNowCategory[] = [
  {
    name: 'Plumbing',
    slug: 'plumbing',
    subcategories: [
      'Pipe Leakage',
      'Tap/Faucet Repair',
      'Drain Blockage',
      'Toilet Repair',
      'Water Tank/Overflow',
      'Low Water Pressure',
      'Other',
    ],
  },
  {
    name: 'Electrical',
    slug: 'electrical',
    subcategories: [
      'Power Outage',
      'Switch/Socket',
      'Wiring Fault',
      'Short Circuit',
      'Fan Install/Repair',
      'Light Fixture',
      'MCB/Fuse',
      'Other',
    ],
  },
  {
    name: 'AC Repair',
    slug: 'ac-repair',
    subcategories: [
      'Not Cooling',
      'Water Leakage',
      'Noise',
      'Gas Refill',
      'Installation',
      'Servicing/Cleaning',
      'Not Turning On',
      'Other',
    ],
  },
  {
    name: 'Refrigerator',
    slug: 'refrigerator',
    subcategories: [
      'Not Cooling',
      'Water Leakage',
      'Noise',
      'Ice Build-up',
      'Not Turning On',
      'Door/Seal',
      'Other',
    ],
  },
  {
    name: 'Washing Machine',
    slug: 'washing-machine',
    subcategories: [
      'Not Draining',
      'Not Spinning',
      'Water Leakage',
      'Noise/Vibration',
      'Not Turning On',
      'Door/Lid',
      'Other',
    ],
  },
  {
    name: 'Water Heater',
    slug: 'water-heater',
    subcategories: [
      'No Hot Water',
      'Water Leakage',
      'Thermostat',
      'Not Turning On',
      'Installation',
      'Other',
    ],
  },
  {
    name: 'Gas/Stove',
    slug: 'gas-stove',
    subcategories: [
      'Gas Leak',
      'Burner Not Igniting',
      'Low Flame',
      'Regulator/Pipe',
      'Installation',
      'Other',
    ],
  },
  {
    name: 'Carpentry',
    slug: 'carpentry',
    subcategories: [
      'Furniture Repair',
      'Door/Window',
      'Cabinet/Drawer',
      'Hinge/Lock',
      'Assembly',
      'Other',
    ],
  },
  {
    name: 'Painting',
    slug: 'painting',
    subcategories: [
      'Interior Wall',
      'Exterior Wall',
      'Waterproofing',
      'Touch-up',
      'Wood/Metal',
      'Other',
    ],
  },
  {
    name: 'Home Appliance',
    slug: 'home-appliance',
    subcategories: [
      'Microwave',
      'Television',
      'Chimney',
      'Mixer/Grinder',
      'Dishwasher',
      'Water Purifier',
      'Other',
    ],
  },
  {
    name: OTHER_CATEGORY,
    slug: 'other',
    subcategories: ['Other'],
  },
];

const CATEGORY_BY_NORMALIZED_NAME = new Map<string, FixNowCategory>(
  FIXNOW_CATEGORIES.map((category) => [normalize(category.name), category]),
);

function normalize(value: string): string {
  return value.trim().toLowerCase();
}

/** Ordered category names, e.g. for building a prompt allow-list. */
export function categoryNames(): string[] {
  return FIXNOW_CATEGORIES.map((category) => category.name);
}

/** Case-insensitive lookup by category name. */
export function findCategoryByName(name: string): FixNowCategory | undefined {
  return CATEGORY_BY_NORMALIZED_NAME.get(normalize(name));
}

/** True when `name` is one of the taxonomy categories. */
export function isAllowedCategory(name: string): boolean {
  return CATEGORY_BY_NORMALIZED_NAME.has(normalize(name));
}

/** Allowed subcategories for a category name (empty when unknown). */
export function subcategoriesFor(name: string): readonly string[] {
  return findCategoryByName(name)?.subcategories ?? [];
}

/** Grounding slug for a category name, if any. */
export function slugFor(name: string): string | undefined {
  return findCategoryByName(name)?.slug;
}
