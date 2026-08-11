import { describe, expect, it } from "vitest";

import {
  availabilityLabel,
  isDateAvailable,
  validateAvailabilityDates,
  type Availability,
} from "./availability";

describe("availability calendar dates", () => {
  const range: Availability = {
    id: "range-a",
    item_id: "item-a",
    start_date: "2026-08-11",
    end_date: "2026-08-15",
  };

  it("accepts inclusive same-day and ordered ranges without timezone conversion", () => {
    expect(validateAvailabilityDates("2026-08-11", "2026-08-11")).toBeNull();
    expect(validateAvailabilityDates("2026-08-11", "2026-08-15")).toBeNull();
    expect(availabilityLabel({ ...range, end_date: "2026-08-11" })).toBe(
      "Available on 2026-08-11",
    );
  });

  it("treats only dates inside inclusive ranges as available", () => {
    expect(isDateAvailable([range], "2026-08-11")).toBe(true);
    expect(isDateAvailable([range], "2026-08-15")).toBe(true);
    expect(isDateAvailable([range], "2026-08-16")).toBe(false);
    expect(isDateAvailable([], "2026-08-12")).toBe(false);
  });

  it("rejects missing, malformed, and reversed dates", () => {
    expect(validateAvailabilityDates("", "2026-08-11")).toMatch(/both/);
    expect(validateAvailabilityDates("08/11/2026", "2026-08-11")).toMatch(
      /both/,
    );
    expect(validateAvailabilityDates("2026-08-12", "2026-08-11")).toMatch(
      /on or after/,
    );
  });
});
