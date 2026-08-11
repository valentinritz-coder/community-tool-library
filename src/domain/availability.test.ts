import { describe, expect, it } from "vitest";

import { availabilityLabel, validateAvailabilityDates } from "./availability";

describe("availability calendar dates", () => {
  it("accepts inclusive same-day and ordered ranges without timezone conversion", () => {
    expect(validateAvailabilityDates("2026-08-11", "2026-08-11")).toBeNull();
    expect(validateAvailabilityDates("2026-08-11", "2026-08-15")).toBeNull();
    expect(
      availabilityLabel({
        id: "range-a",
        item_id: "item-a",
        kind: "available",
        start_date: "2026-08-11",
        end_date: "2026-08-11",
      }),
    ).toBe("Available on 2026-08-11");
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
