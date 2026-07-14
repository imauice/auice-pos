export const apiBase =
  import.meta.env.VITE_API_BASE_URL || "http://localhost:3000/api";

export interface Branch {
  id: string;
  code: string;
  name: string;
  timezone: string;
  currency: string;
  active: boolean;
}

export interface Page<T> {
  items: T[];
  nextCursor?: string;
}

async function json<T>(url: string): Promise<T> {
  const response = await globalThis.fetch(url);
  if (!response.ok) throw new Error(`API returned ${response.status}`);
  return (await response.json()) as T;
}

export function fetchBranches() {
  return json<Branch[]>(`${apiBase}/branches`);
}

export function fetchReadOnlyPage(
  kind: "products" | "productUnits" | "productPrices" | "devices",
  branchId: string,
  cursor?: string,
) {
  const params = new URLSearchParams({ branchId, limit: "25" });
  if (cursor) params.set("cursor", cursor);
  const path = kind === "devices" ? "device" : `catalog-view/${kind}`;
  return json<Page<Record<string, unknown>>>(`${apiBase}/${path}?${params}`);
}
