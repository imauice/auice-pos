<script setup lang="ts">
import { storeToRefs } from 'pinia';
import { useHealthStore } from '../stores/health';
const store = useHealthStore();
const { health, loading, error } = storeToRefs(store);
</script>
<template>
  <section class="card" aria-live="polite">
    <h2>API Status</h2>
    <p v-if="loading">Loading…</p>
    <p v-else-if="error" class="error">{{ error }}</p>
    <dl v-else-if="health"><dt>Service</dt><dd>{{ health.status }}</dd><dt>MongoDB</dt><dd>{{ health.database }}</dd><dt>API timestamp</dt><dd>{{ health.timestamp }}</dd></dl>
    <p v-else>Status has not been checked.</p>
    <button :disabled="loading" @click="store.refresh()">Refresh</button>
  </section>
</template>

