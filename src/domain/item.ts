export const itemCategories = [
  { value: "household", label: "Household" },
  { value: "small_diy", label: "Small, low-risk DIY" },
  { value: "garden", label: "Small garden tools" },
  { value: "leisure", label: "Leisure" },
] as const;

export type ItemCategory = (typeof itemCategories)[number]["value"];

export interface Item {
  id: string;
  community_id: string;
  owner_id: string;
  name: string;
  category: ItemCategory;
  description: string;
  photo_path: string;
  is_free: boolean;
  price_per_day_cents: number | null;
  archived: boolean;
  photo_uploaded: boolean;
}

export interface InventoryItem {
  id: string;
  community_id: string;
  name: string;
  category: ItemCategory;
  description: string;
  photo_path: string;
  is_free: boolean;
  price_per_day_cents: number | null;
  is_owned: boolean;
  availability_summary: string;
}

export function itemCategoryLabel(category: ItemCategory): string {
  return (
    itemCategories.find((candidate) => candidate.value === category)?.label ??
    category
  );
}

export function inventoryItems(
  items: InventoryItem[],
  search: string,
): InventoryItem[] {
  const query = search.trim().toLocaleLowerCase();

  return items.filter((item) => {
    if (!query) return true;

    return (
      item.name.toLocaleLowerCase().includes(query) ||
      itemCategoryLabel(item.category).toLocaleLowerCase().includes(query)
    );
  });
}

export function priceToCents(price: string): number | null {
  const normalized = price.trim();
  if (!/^\d{1,4}([.,]\d{1,2})?$/.test(normalized)) return null;
  const [units, fraction = ""] = normalized.replace(",", ".").split(".");
  const cents = Number(units) * 100 + Number(fraction.padEnd(2, "0"));
  return cents > 0 && cents <= 100_000 ? cents : null;
}

export function photoExtension(file: File): "jpg" | "png" | "webp" | null {
  if (file.type === "image/jpeg") return "jpg";
  if (file.type === "image/png") return "png";
  if (file.type === "image/webp") return "webp";
  return null;
}
