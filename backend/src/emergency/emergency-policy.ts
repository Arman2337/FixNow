/**
 * FN-063 policy constants, approved in
 * docs/safety/emergency-dispatch-policy-v1.md §5–6. Versioned and pinned by
 * evaluation tests: changing any value must be a conscious policy decision
 * that updates this block and the pinning test together.
 */
export const EMERGENCY_POLICY_V1 = {
  /** Max providers pushed per wave (policy §5). */
  fanOutCap: 50,
  /** Minutes after the previous wave before wave 2 fires. */
  wave2AfterMinutes: 3,
  /** Minutes after the previous wave before wave 3 fires. */
  wave3AfterMinutes: 8,
  /** Radius widening applied when wave 2 fans out. */
  radiusMultiplierWave2: 2,
  /** Max emergencies per rolling 24 hours per customer (policy §6). */
  dailyCustomerCap: 3,
  /** Minimum minutes between two emergencies for one customer. */
  cooldownMinutes: 30,
  /** Days of history that raises a HIGH-severity trust signal at >=3 uses. */
  trustSignalWindowDays: 7,
  trustSignalThreshold: 3,
} as const;

/** Customer-facing fallback guidance (policy §7). Fixed copy; never edited ad hoc. */
export const EMERGENCY_FALLBACK_GUIDANCE =
  'No professional is available right now. If this is dangerous, call your local emergency services. You can keep waiting or cancel.';
