/**
 * A metrics registry in the Prometheus text exposition format.
 *
 * The audit's finding was not "there is no metrics library" — it was that nine
 * of the top ten failure modes announce themselves with silence. Nothing in the
 * system could answer "how long does matching take", "what is the no-provider
 * rate", or "is the outbox falling behind", and uptime stayed green throughout.
 *
 * `prom-client` would do this, and it is the right choice at a scale where
 * somebody is maintaining that dependency. This is a deliberate smaller thing,
 * for three reasons that are specific to this codebase rather than general:
 *
 *  1. The metric set is fixed and small. Six gauges and three histograms, all
 *     named in `registerMetrics` below. There is no label cardinality to manage,
 *     so there is nothing here that a general library is buying.
 *  2. `/health/readiness` already refuses to report ready when a dependency is
 *     down. A metrics endpoint that stays scrapable through a Redis outage is the
 *     only way an operator finds out, so this endpoint must not depend on any
 *     external service — which is also the condition for it to have no
 *     dependencies of its own.
 *  3. The exposition format is a few lines and is stable. Adding a real client
 *     later is a contained change to this file, not a rewrite of its callers.
 *
 * What this deliberately does not do: persist anything, or aggregate across
 * instances. Scraping is the storage layer, which is what makes it work
 * identically on one replica and on ten.
 */

export type MetricType = 'gauge' | 'counter' | 'histogram';

interface Sample {
  readonly name: string;
  readonly help: string;
  readonly type: MetricType;
  readonly labelNames: readonly string[];
}

interface HistogramSeries {
  readonly counts: number[];
  sum: number;
  count: number;
}

interface Histogram {
  readonly sample: Sample;
  /** Upper bounds, in the units of the observation. Ascending. */
  readonly bounds: readonly number[];
  observe(value: number, labels?: Labels): void;
  series(): ReadonlyMap<string, HistogramSeries>;
}

interface Gauge {
  readonly sample: Sample;
  values: Map<string, number>;
}

interface Counter {
  readonly sample: Sample;
  values: Map<string, number>;
}

/**
 * The internal map key for a label set.
 *
 * Values are stored raw, not quoted: quoting here and unquoting on render is
 * where the doubled-quote bug comes from. A unit separator is used rather than a
 * comma because a label value legitimately contains commas — `match,failed` is a
 * plausible value and would otherwise split into two label slots.
 */
const LABEL_SEPARATOR = '';

function labelKey(labelNames: readonly string[], labels: Labels): string {
  // Canonicalised by declared label order, so `{method, route}` and
  // `{route, method}` resolve to the same series rather than two series that look
  // identical in a query.
  return labelNames
    .map((name) => escapeLabelValue(labels[name] ?? ''))
    .join(LABEL_SEPARATOR);
}

/**
 * Escape a label value for the exposition format.
 *
 * Prometheus label values escape `\`, `"` and newlines. A label containing an
 * unescaped quote or newline would produce a malformed scrape target — and the
 * failure is silent, because the scrape still returns 200 with garbage in it.
 */
function escapeLabelValue(value: string): string {
  return value
    .replace(/\\/g, '\\\\')
    .replace(/\n/g, '\\n')
    .replace(/"/g, '\\"');
}

function renderLabels(labelNames: readonly string[], key: string): string {
  if (!labelNames.length) return '';
  const values = key.split(LABEL_SEPARATOR);
  return `{${labelNames
    .map((name, index) => `${name}="${values[index] ?? ''}"`)
    .join(',')}}`;
}

export type Labels = Readonly<Record<string, string>>;

export class MetricRegistry {
  private readonly gauges = new Map<string, Gauge>();
  private readonly counters = new Map<string, Counter>();
  private readonly histograms = new Map<string, Histogram>();

  /**
   * Declares a gauge. Re-declaring the same name with different help or labels
   * is a programming error and throws, because a silent redefinition is how two
   * call sites end up writing to series that look alike but are not.
   */
  gauge(name: string, help: string, labelNames: readonly string[] = []): void {
    this.declare(this.gauges, name, help, labelNames, () => ({
      sample: { name, help, type: 'gauge', labelNames },
      values: new Map<string, number>(),
    }));
  }

  counter(
    name: string,
    help: string,
    labelNames: readonly string[] = [],
  ): void {
    this.declare(this.counters, name, help, labelNames, () => ({
      sample: { name, help, type: 'counter', labelNames },
      values: new Map<string, number>(),
    }));
  }

  histogram(
    name: string,
    help: string,
    bounds: readonly number[],
    labelNames: readonly string[] = [],
  ): Histogram {
    const existing = this.histograms.get(name);
    if (existing) return existing;
    const sorted = [...bounds].sort((a, b) => a - b);
    const byLabel = new Map<string, HistogramSeries>();

    const created: Histogram = {
      sample: { name, help, type: 'histogram', labelNames },
      bounds: sorted,
      series: () => byLabel,
      observe(value: number, labels: Labels = {}): void {
        const key = labelKey(labelNames, labels);
        let entry = byLabel.get(key);
        if (!entry) {
          entry = {
            counts: new Array<number>(sorted.length + 1).fill(0),
            sum: 0,
            count: 0,
          };
          byLabel.set(key, entry);
        }
        entry.sum += value;
        entry.count += 1;
        // Prometheus buckets are cumulative, so an observation belongs to every
        // bound at or above it. Writing only its own bucket would make `le`
        // meaningless and would leave `_count` disagreeing with the `+Inf`
        // bucket — the two things a histogram query actually reads.
        for (let i = 0; i < sorted.length; i++) {
          if (value <= sorted[i]) entry.counts[i] += 1;
        }
        entry.counts[sorted.length] += 1;
      },
    };
    this.histograms.set(name, created);
    return created;
  }

  private declare<T extends { sample: Sample }>(
    store: Map<string, T>,
    name: string,
    help: string,
    labelNames: readonly string[],
    build: () => T,
  ): void {
    const existing = store.get(name);
    if (existing) {
      const same =
        existing.sample.help === help &&
        existing.sample.labelNames.join(',') === labelNames.join(',');
      if (!same) {
        throw new Error(
          `Metric "${name}" is already declared with different help or labels. ` +
            'Two call sites writing to the same metric name with a different shape ' +
            'produce series that look alike and are not.',
        );
      }
      return;
    }
    store.set(name, build());
  }

  set(name: string, value: number, labels: Labels = {}): void {
    const gauge = this.gauges.get(name);
    if (!gauge) throw new Error(`No gauge named "${name}"`);
    gauge.values.set(labelKey(gauge.sample.labelNames, labels), value);
  }

  inc(name: string, labels: Labels = {}, by = 1): void {
    const counter = this.counters.get(name);
    if (!counter) throw new Error(`No counter named "${name}"`);
    const key = labelKey(counter.sample.labelNames, labels);
    counter.values.set(key, (counter.values.get(key) ?? 0) + by);
  }

  /**
   * Renders the registry in the Prometheus text exposition format.
   *
   * Deliberately free of any dependency, so it keeps answering while Redis is
   * down — which is precisely when an operator needs it.
   */
  render(): string {
    const lines: string[] = [];
    const push = (sample: Sample): void => {
      lines.push(`# HELP ${sample.name} ${sample.help}`);
      lines.push(`# TYPE ${sample.name} ${sample.type}`);
    };

    for (const gauge of this.gauges.values()) {
      push(gauge.sample);
      if (gauge.values.size === 0) continue;
      for (const [key, value] of gauge.values) {
        lines.push(
          `${gauge.sample.name}${renderLabels(gauge.sample.labelNames, key)} ${value}`,
        );
      }
    }

    for (const counter of this.counters.values()) {
      push(counter.sample);
      for (const [key, value] of counter.values) {
        lines.push(
          `${counter.sample.name}${renderLabels(counter.sample.labelNames, key)} ${value}`,
        );
      }
    }

    for (const histogram of this.histograms.values()) {
      push(histogram.sample);
      const labelNames = histogram.sample.labelNames;
      // One block per label set. A histogram that aggregated every route into a
      // single series would still "work" and still be useless: the question a
      // duration histogram answers is always "which one is slow".
      for (const [key, entry] of histogram.series()) {
        const rendered = renderLabels(labelNames, key);
        // `le` is appended inside the existing brace group, which is why the
        // closing brace is trimmed rather than concatenated.
        const withLe = (le: string): string =>
          rendered ? `${rendered.slice(0, -1)},le="${le}"}` : `{le="${le}"}`;

        histogram.bounds.forEach((bound, index) => {
          lines.push(
            `${histogram.sample.name}_bucket${withLe(String(bound))} ${entry.counts[index]}`,
          );
        });
        lines.push(
          `${histogram.sample.name}_bucket${withLe('+Inf')} ${entry.counts[entry.counts.length - 1]}`,
        );
        lines.push(`${histogram.sample.name}_sum${rendered} ${entry.sum}`);
        lines.push(`${histogram.sample.name}_count${rendered} ${entry.count}`);
      }
    }

    return `${lines.join('\n')}\n`;
  }
}
