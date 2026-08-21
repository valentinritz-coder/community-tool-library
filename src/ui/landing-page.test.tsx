import { render, screen, within } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import { LandingPage } from "./landing-page";

describe("LandingPage", () => {
  it("renders the approved sections in narrative order", () => {
    const { container } = render(<LandingPage />);
    const headings = within(container.querySelector("main")!).getAllByRole(
      "heading",
      { level: 2 },
    );

    expect(headings.map((heading) => heading.textContent)).toEqual([
      "Prêt, près, prêtez !",
      "Partager en confiance",
      "À voter !",
      "Comment rejoindre ?",
      "Et si votre communauté n’existe pas encore ?",
    ]);
    expect(screen.getByRole("heading", { level: 1 })).toHaveTextContent(
      /Des objets en commun\.\s*Des décisions en commun\./,
    );
    expect(screen.getByRole("banner")).toBeInTheDocument();
    expect(screen.getByRole("main")).toBeInTheDocument();
    expect(screen.getByRole("contentinfo")).toBeInTheDocument();
    expect(container.firstElementChild).toHaveAttribute("lang", "fr");
  });

  it("stacks every major idea as a direct module in one narrative column", () => {
    const { container } = render(<LandingPage />);
    const modules = container.querySelector(".landing-modules");

    expect(modules).toBeInTheDocument();
    expect(modules?.children).toHaveLength(6);
    expect(
      [...(modules?.children ?? [])].every((module) =>
        module.classList.contains("landing-section"),
      ),
    ).toBe(true);
  });

  it("explains invitation approval and council elections without unsupported claims", () => {
    const { container } = render(<LandingPage />);

    expect(
      screen.getByText(/chaque demande d’adhésion doit être acceptée/),
    ).toBeInTheDocument();
    expect(
      screen.getByText(/Les membres élisent leur conseil/),
    ).toBeInTheDocument();
    expect(screen.getAllByRole("listitem")).toHaveLength(3);
    expect(container).not.toHaveTextContent(
      /profil vérifié|identité vérifiée|adresse vérifiée/i,
    );
    expect(container).not.toHaveTextContent(
      /créer ma communauté|votes en cours|référendum/i,
    );
  });

  it("keeps unresolved calls to action explicit and non-interactive", () => {
    render(<LandingPage />);

    expect(
      screen.getByRole("button", { name: "Rejoindre une communauté" }),
    ).toBeDisabled();
    expect(
      screen.getByText("Accès sur invitation seulement"),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Nous contacter" }),
    ).toBeDisabled();
    expect(
      screen.getByText("Le parcours de contact sera bientôt disponible."),
    ).toBeInTheDocument();
  });

  it("treats every redundant illustration as decorative", () => {
    const { container } = render(<LandingPage />);
    const illustrations = [...container.querySelectorAll("img")];

    expect(illustrations).toHaveLength(10);
    expect(
      illustrations.every(
        (illustration) => illustration.getAttribute("alt") === "",
      ),
    ).toBe(true);
    expect(illustrations[0]).toHaveAttribute("width", "1556");
    expect(illustrations[0]).toHaveAttribute("height", "1011");
    expect(illustrations[8]).toHaveAttribute("width", "1672");
    expect(illustrations[8]).toHaveAttribute("height", "941");
    expect(illustrations[9]).toHaveAttribute("width", "1536");
    expect(illustrations[9]).toHaveAttribute("height", "1024");
  });

  it("keeps unresolved footer destinations as non-interactive labels", () => {
    render(<LandingPage />);

    expect(screen.queryByRole("navigation")).not.toBeInTheDocument();
    for (const label of [
      "Contact",
      "Accessibilité",
      "Confidentialité",
      "Mentions légales",
    ]) {
      expect(screen.getByText(label)).not.toHaveAttribute("href");
    }
  });
});
