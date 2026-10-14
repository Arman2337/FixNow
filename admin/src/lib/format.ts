export function shortId(id: string): string {
  if (!id) return "";
  return id.replaceAll("-", "").slice(0, 8).toUpperCase();
}
