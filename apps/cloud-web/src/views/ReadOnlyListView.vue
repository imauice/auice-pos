<script setup lang="ts">
import { onMounted, ref } from "vue";
const props = defineProps<{
  title: string;
  kind: "products" | "productUnits" | "productPrices" | "devices";
}>();
const rows = ref<Record<string, unknown>[]>([]);
const error = ref("");
const base = import.meta.env.VITE_API_BASE_URL || "http://localhost:3000/api";
onMounted(async () => {
  try {
    if (props.kind === "devices") {
      const response = await globalThis.fetch(`${base}/device`);
      if (!response.ok) throw new Error(`API returned ${response.status}`);
      rows.value = (await response.json()) as Record<string, unknown>[];
      return;
    }
    const branchResponse = await globalThis.fetch(`${base}/branches`);
    const branches = (await branchResponse.json()) as Array<{ id: string }>;
    if (!branches[0]) return;
    const response = await globalThis.fetch(
      `${base}/catalog?branchId=${branches[0].id}&catalogVersion=0&limit=500`,
    );
    if (!response.ok) throw new Error(`API returned ${response.status}`);
    const catalog = (await response.json()) as Record<
      string,
      Record<string, unknown>[]
    >;
    rows.value = catalog[props.kind] ?? [];
  } catch (e) {
    error.value = e instanceof Error ? e.message : "Unable to load data";
  }
});
function primary(row: Record<string, unknown>) {
  return String(row.name ?? row.code ?? row.id ?? "");
}
function detail(row: Record<string, unknown>) {
  return props.kind === "productPrices"
    ? `${row.priceMinor} ${row.currency}`
    : String(
        row.platform ??
          row.sku ??
          row.barcode ??
          (row.active ? "Active" : "Inactive"),
      );
}
</script>
<template>
  <main>
    <h1>{{ title }}</h1>
    <p v-if="error" class="error">{{ error }}</p>
    <table>
      <thead>
        <tr>
          <th>Name / ID</th>
          <th>Details</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="row in rows" :key="String(row.id)">
          <td>{{ primary(row) }}</td>
          <td>{{ detail(row) }}</td>
        </tr>
        <tr v-if="!rows.length">
          <td colspan="2">No records</td>
        </tr>
      </tbody>
    </table>
  </main>
</template>
