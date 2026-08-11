import { describe, expect, it } from "vitest";

import { validateBookingDates } from "./booking";

describe("validateBookingDates", () => {
  it("requires two calendar dates", () => {
    expect(validateBookingDates("", "2026-08-12")).toBe(
      "Choose both a start date and an end date.",
    );
  });

  it("rejects an inverted range", () => {
    expect(validateBookingDates("2026-08-13", "2026-08-12")).toBe(
      "The end date must be on or after the start date.",
    );
  });

  it("allows a one-day range", () => {
    expect(validateBookingDates("2026-08-12", "2026-08-12")).toBeNull();
  });
});
