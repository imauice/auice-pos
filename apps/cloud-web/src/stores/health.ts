import { defineStore } from "pinia";
import { fetchHealth, type HealthResponse } from "../api/health";
export const useHealthStore = defineStore("health", {
  state: () => ({
    health: null as HealthResponse | null,
    loading: false,
    error: "",
  }),
  actions: {
    async refresh() {
      this.loading = true;
      this.error = "";
      try {
        this.health = await fetchHealth();
      } catch (error) {
        this.error =
          error instanceof Error ? error.message : "Unable to reach API";
      } finally {
        this.loading = false;
      }
    },
  },
});
