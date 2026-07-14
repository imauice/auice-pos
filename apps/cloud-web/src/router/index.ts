import { createRouter, createWebHistory } from "vue-router";
import HomeView from "../views/HomeView.vue";
import BranchesView from "../views/BranchesView.vue";
import ReadOnlyListView from "../views/ReadOnlyListView.vue";
export const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: "/", component: HomeView },
    { path: "/branches", component: BranchesView },
    {
      path: "/products",
      component: ReadOnlyListView,
      props: { title: "Products", kind: "products" },
    },
    {
      path: "/product-units",
      component: ReadOnlyListView,
      props: { title: "Product Units", kind: "productUnits" },
    },
    {
      path: "/prices",
      component: ReadOnlyListView,
      props: { title: "Prices", kind: "productPrices" },
    },
    {
      path: "/devices",
      component: ReadOnlyListView,
      props: { title: "Devices", kind: "devices" },
    },
  ],
});
