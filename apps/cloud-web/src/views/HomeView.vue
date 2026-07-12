<script setup lang="ts">
import { onMounted } from 'vue';
import ApiStatusCard from '../components/ApiStatusCard.vue';
import { useHealthStore } from '../stores/health';
const store = useHealthStore();
onMounted(() => void store.refresh());
</script>
<template><main><h1>Auice POS Cloud</h1><ApiStatusCard /></main></template>

