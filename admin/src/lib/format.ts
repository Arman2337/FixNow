export function shortId(id: string): string {
  if (!id) return "";
  return id.replaceAll("-", "").slice(0, 8).toUpperCase();
}

/** Invalid URL page values start at page one rather than producing NaN offsets. */
export function pageNumber(value?: string): number {
  const page = Number(value);
  return Number.isSafeInteger(page) && page > 0 && page <= 1_000_000 ? page : 1;
}
