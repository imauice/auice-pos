<script setup lang="ts">
import { onMounted, ref } from "vue";
interface Branch {
  id: string;
  code: string;
  name: string;
  timezone: string;
  currency: string;
  active: boolean;
}
const rows = ref<Branch[]>([]);
const error = ref("");
onMounted(async () => {
  try {
    const base =
      import.meta.env.VITE_API_BASE_URL || "http://localhost:3000/api";
    const response = await globalThis.fetch(`${base}/branches`);
    if (!response.ok) throw new Error(`API returned ${response.status}`);
    rows.value = (await response.json()) as Branch[];
  } catch (e) {
    error.value = e instanceof Error ? e.message : "Unable to load branches";
  }
});
</script>
<template>
  <main>
    <h1>Branches</h1>
    <p v-if="error" class="error">{{ error }}</p>
    <table>
      <thead>
        <tr>
          <th>Code</th>
          <th>Name</th>
          <th>Timezone</th>
          <th>Currency</th>
          <th>Active</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="row in rows" :key="row.id">
          <td>{{ row.code }}</td>
          <td>{{ row.name }}</td>
          <td>{{ row.timezone }}</td>
          <td>{{ row.currency }}</td>
          <td>{{ row.active }}</td>
        </tr>
      </tbody>
    </table>
  </main>
</template>
