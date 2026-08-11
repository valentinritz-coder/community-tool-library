import { describe, expect, it } from "vitest";

import {
  inventoryItems,
  photoExtension,
  priceToCents,
  type InventoryItem,
} from "./item";

const item = (overrides: Partial<InventoryItem>): InventoryItem => ({
  id: "item-a",
  community_id: "community-a",
  name: "Cordless screwdriver",
  category: "small_diy",
  description: "Compact screwdriver",
  photo_path: "item-a/photo.jpg",
  is_free: true,
  price_per_day_cents: null,
  is_owned: false,
  ...overrides,
});

describe("item input conversion", () => {
  it("converts decimal prices to deterministic integer cents", () => {
    expect(priceToCents("4.50")).toBe(450);
    expect(priceToCents("4,5")).toBe(450);
    expect(priceToCents("0")).toBeNull();
    expect(priceToCents("1.234")).toBeNull();
  });

  it("accepts only the bucket's image formats", () => {
    expect(
      photoExtension(new File([], "photo.jpg", { type: "image/jpeg" })),
    ).toBe("jpg");
    expect(
      photoExtension(new File([], "photo.gif", { type: "image/gif" })),
    ).toBeNull();
  });
});

describe("inventoryItems", () => {
  const items = [
    item({}),
    item({ id: "item-b", name: "Picnic set", category: "leisure" }),
  ];

  it("keeps the complete authorized inventory when search is empty", () => {
    expect(inventoryItems(items, "").map(({ id }) => id)).toEqual([
      "item-a",
      "item-b",
    ]);
  });

  it("matches names and human-readable categories without fuzzy ranking", () => {
    expect(inventoryItems(items, "screw").map(({ id }) => id)).toEqual([
      "item-a",
    ]);
    expect(inventoryItems(items, "LEISURE").map(({ id }) => id)).toEqual([
      "item-b",
    ]);
    expect(inventoryItems(items, "missing")).toEqual([]);
  });
});
