import { readFileSync, statSync } from "node:fs";
import { resolve } from "node:path";

import { describe, expect, it } from "vitest";

const root = resolve(import.meta.dirname, "../..");
const illustrationNames = [
  "hero-exchange.svg",
  "handshake.svg",
  "council-ballot.svg",
  "objects/raclette.svg",
  "objects/projector.svg",
  "objects/table.svg",
  "objects/hedge-trimmer.svg",
  "objects/console.svg",
  "objects/drill.svg",
  "objects/watering-can.svg",
] as const;

function luminance(hex: string): number {
  const channels = hex
    .slice(1)
    .match(/.{2}/g)
    ?.map((channel) => Number.parseInt(channel, 16) / 255)
    .map((channel) =>
      channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4,
    );

  if (!channels || channels.length !== 3) {
    throw new Error(`Invalid six-digit hex colour: ${hex}`);
  }

  return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722;
}

function contrast(foreground: string, background: string): number {
  const values = [luminance(foreground), luminance(background)].sort(
    (a, b) => b - a,
  );
  return (values[0] + 0.05) / (values[1] + 0.05);
}

describe("landing visual foundations", () => {
  it("defines distinct fluid roles for hero and section headings", () => {
    const stylesheet = readFileSync(
      resolve(root, "src/app/landing-foundations.css"),
      "utf8",
    );

    expect(stylesheet).toMatch(/--landing-text-display:\s*clamp\([^;]+\);/);
    expect(stylesheet).toMatch(
      /--landing-text-section-heading:\s*clamp\([^;]+\);/,
    );
    expect(stylesheet).toContain("font-size: var(--landing-text-display);");
    expect(stylesheet).toContain(
      "font-size: var(--landing-text-section-heading);",
    );
  });

  it("keeps functional colour pairs above WCAG AA contrast", () => {
    const surface = "#fffdf8";

    expect(contrast("#171b26", surface)).toBeGreaterThanOrEqual(4.5);
    expect(contrast("#4d5361", surface)).toBeGreaterThanOrEqual(4.5);
    expect(contrast("#092a67", surface)).toBeGreaterThanOrEqual(4.5);
    expect(contrast("#ffffff", "#092a67")).toBeGreaterThanOrEqual(4.5);
    expect(contrast("#ffffff", "#061f4e")).toBeGreaterThanOrEqual(4.5);
  });

  it.each(illustrationNames)(
    "keeps %s responsive, text-free, and small",
    (name) => {
      const path = resolve(root, "public/illustrations/landing", name);
      const asset = readFileSync(path, "utf8");

      expect(asset).toMatch(/<svg[^>]+viewBox="0 0 \d+ \d+"/);
      expect(asset).not.toMatch(/<(?:text|script|foreignObject)\b/i);
      expect(asset).not.toMatch(/(?:href|src)="(?:https?:|data:)/i);
      expect(statSync(path).size).toBeLessThan(10_000);

      const definedIds = [...asset.matchAll(/\bid="([^"]+)"/g)].map(
        ([, id]) => id,
      );
      const referencedIds = [
        ...asset.matchAll(/(?:url\(#|(?:href|xlink:href)="#)([^")]+)"?\)?/g),
      ].map(([, id]) => id);

      expect(asset).toMatch(/<filter id="paper"[^>]*>/);
      expect(asset).toContain("<feTurbulence");
      expect(asset).toContain("url(#paper)");
      expect(new Set(referencedIds)).toEqual(new Set(definedIds));
    },
  );
});
