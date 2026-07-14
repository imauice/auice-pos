<script setup lang="ts">
import { onMounted, ref } from "vue";
import { fetchBranches, type Branch } from "../api/master-data";
const rows = ref<Branch[]>([]);
const error = ref("");
const loading = ref(true);
onMounted(async () => {
  try {
    rows.value = await fetchBranches();
  } catch (e) {
    error.value = e instanceof Error ? e.message : "Unable to load branches";
  } finally {
    loading.value = false;
  }
});
</script>
<template>
  <main>
    <h1>Branches</h1>
    <p v-if="loading" role="status">Loading branches…</p>
    <p v-if="error" class="error">{{ error }}</p>
    <p v-else-if="!loading && !rows.length">No branches found.</p>
    <table v-else-if="!loading">
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
