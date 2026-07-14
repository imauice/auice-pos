<script setup lang="ts">
import { onMounted, ref, watch } from "vue";
import {
  fetchBranches,
  fetchReadOnlyPage,
  type Branch,
} from "../api/master-data";
const props = defineProps<{
  title: string;
  kind: "products" | "productUnits" | "productPrices" | "devices";
}>();
const rows = ref<Record<string, unknown>[]>([]);
const error = ref("");
const loading = ref(true);
const branches = ref<Branch[]>([]);
const branchId = ref("");
const cursor = ref<string>();
const nextCursor = ref<string>();
const history = ref<Array<string | undefined>>([]);

async function load(pageCursor?: string) {
  if (!branchId.value) {
    rows.value = [];
    loading.value = false;
    return;
  }
  loading.value = true;
  error.value = "";
  try {
    const page = await fetchReadOnlyPage(props.kind, branchId.value, pageCursor);
    rows.value = page.items;
    cursor.value = pageCursor;
    nextCursor.value = page.nextCursor;
  } catch (e) {
    error.value = e instanceof Error ? e.message : "Unable to load data";
    rows.value = [];
  } finally {
    loading.value = false;
  }
}

async function selectBranch() {
  history.value = [];
  await load();
}

async function next() {
  if (!nextCursor.value) return;
  history.value.push(cursor.value);
  await load(nextCursor.value);
}

async function previous() {
  if (!history.value.length) return;
  await load(history.value.pop());
}

onMounted(async () => {
  try {
    branches.value = await fetchBranches();
    branchId.value = branches.value[0]?.id ?? "";
    await load();
  } catch (e) {
    error.value = e instanceof Error ? e.message : "Unable to load data";
    loading.value = false;
  }
});
watch(() => props.kind, selectBranch);
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
    <label>
      Branch
      <select v-model="branchId" :disabled="loading" @change="selectBranch">
        <option v-for="branch in branches" :key="branch.id" :value="branch.id">
          {{ branch.code }} — {{ branch.name }}
        </option>
      </select>
    </label>
    <p v-if="loading" role="status">Loading {{ title.toLowerCase() }}…</p>
    <p v-if="error" class="error">{{ error }}</p>
    <p v-else-if="!loading && !rows.length">No {{ title.toLowerCase() }} found.</p>
    <table v-else-if="!loading">
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
      </tbody>
    </table>
    <div class="pagination" v-if="!loading && !error">
      <button :disabled="!history.length" @click="previous">Previous</button>
      <button :disabled="!nextCursor" @click="next">Next</button>
    </div>
  </main>
</template>
