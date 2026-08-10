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

    const skipLink = screen.getByRole("link", {
      name: "Skip to main content",
    });

    expect(skipLink).toHaveAttribute("href", "#main");
    expect(screen.getByRole("main")).toHaveAttribute("id", "main");
  });
});
