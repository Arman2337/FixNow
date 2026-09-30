import { readdirSync, statSync } from 'fs';
import { join } from 'path';
import { ALL_ENTITIES } from './test-data-source';

/**
 * The entity list in `test-data-source.ts` is maintained by hand, so it can
 * fall behind the tree. Nine specs already drifted in exactly that way while
 * the suite was unrunnable, so the list now has a test of its own.
 */
describe('integration test harness entity registry', () => {
  const SRC = join(__dirname, '..', '..', 'src');

  function entityFiles(dir: string, found: string[] = []): string[] {
    for (const entry of readdirSync(dir)) {
      const full = join(dir, entry);
      if (statSync(full).isDirectory()) {
        entityFiles(full, found);
      } else if (entry.endsWith('.entity.ts')) {
        found.push(full);
      }
    }
    return found;
  }

  it('registers every entity file in src, matching the typeorm.config glob', () => {
    const files = entityFiles(SRC);
    expect(files.length).toBeGreaterThan(0);
    expect(ALL_ENTITIES).toHaveLength(files.length);
  });

  it('has no duplicate registrations', () => {
    const names = ALL_ENTITIES.map(
      (entity) => (entity as { name: string }).name,
    );
    expect(new Set(names).size).toBe(names.length);
  });
});
