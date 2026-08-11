import { describe, expect, it } from "vitest";

import { photoExtension, priceToCents } from "./item";

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
