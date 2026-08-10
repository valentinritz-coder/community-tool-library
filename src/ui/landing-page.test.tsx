import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import { LandingPage } from "./landing-page";

describe("LandingPage", () => {
  it("introduces the service with a single main heading", () => {
    render(<LandingPage />);

    expect(
      screen.getByRole("heading", {
        level: 1,
        name: "Useful tools, shared by neighbours.",
      }),
    ).toBeInTheDocument();
    expect(
      screen.getByText("Pilot application in development"),
    ).toBeInTheDocument();
  });

  it("provides a keyboard-accessible skip link", () => {
    render(<LandingPage />);

    expect(
      screen.getByRole("link", { name: /skip to main content/i }),
    ).toHaveAttribute("href", "#main");
  });
});
