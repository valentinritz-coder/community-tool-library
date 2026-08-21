import { readFileSync, statSync } from "node:fs";
import { resolve } from "node:path";

import { describe, expect, it } from "vitest";

const root = resolve(import.meta.dirname, "../..");
const objectIllustrationNames = [
  "objects/raclette.svg",
  "objects/projector.svg",
  "objects/table.svg",
  "objects/hedge-trimmer.svg",
  "objects/console.svg",
  "objects/drill.svg",
  "objects/watering-can.svg",
] as const;

const mainIllustrations = [
  ["hero-exchange.webp", 1556, 1011],
  ["handshake.webp", 1672, 941],
  ["council-ballot.webp", 1536, 1024],
] as const;

function readUInt24LE(asset: Buffer, offset: number): number {
  return asset[offset] | (asset[offset + 1] << 8) | (asset[offset + 2] << 16);
}

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

    expect(stylesheet).toContain(
      "--landing-text-display: clamp(2.75rem, 1.95rem + 4vw, 5rem);",
    );
    expect(stylesheet).toMatch(
      /--landing-text-section-heading:\s*clamp\([^;]+\);/,
    );
    expect(stylesheet).toContain("font-size: var(--landing-text-display);");
    expect(stylesheet).toContain(
      "font-size: var(--landing-text-section-heading);",
    );
  });

  it("gives desktop compositions more room while preserving bounded content", () => {
    const stylesheet = readFileSync(
      resolve(root, "src/app/landing-foundations.css"),
      "utf8",
    );

    expect(stylesheet).toContain("--landing-content-width: 90rem;");
    expect(stylesheet).toMatch(
      /\.landing-hero\s*{\s*grid-template-columns:\s*minmax\(0, 0\.8fr\) minmax\(0, 1\.2fr\);\s*}/,
    );
    expect(stylesheet).toContain("max-width: var(--landing-content-width);");
  });

  it("keeps the major landing modules in one column with thin white joints", () => {
    const stylesheet = readFileSync(
      resolve(root, "src/app/landing-foundations.css"),
      "utf8",
    );

    expect(stylesheet).toMatch(
      /\.landing-modules\s*{[\s\S]*?display:\s*grid;[\s\S]*?gap:\s*0\.75rem;/,
    );
    expect(stylesheet).not.toMatch(
      /\.landing-modules\s*{[^}]*grid-template-columns:/,
    );
    expect(stylesheet).toMatch(
      /@media \(max-width: 41\.999rem\)[\s\S]*?\.landing-modules\s*{[^}]*gap:\s*0\.5rem;/,
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

  it.each(objectIllustrationNames)(
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

  it.each(mainIllustrations)(
    "keeps %s as a reasonably sized WebP with stable intrinsic dimensions",
    (name, expectedWidth, expectedHeight) => {
      const path = resolve(root, "public/illustrations/landing", name);
      const asset = readFileSync(path);

      expect(name).toMatch(/\.webp$/);
      expect(asset.length).toBeGreaterThan(0);
      expect(asset.subarray(0, 4).toString("ascii")).toBe("RIFF");
      expect(asset.subarray(8, 12).toString("ascii")).toBe("WEBP");
      expect(statSync(path).size).toBeLessThan(2_000_000);

      expect(asset.subarray(12, 16).toString("ascii")).toBe("VP8X");

      const featureFlags = asset[20];
      expect(featureFlags & 0x10).not.toBe(0);

      expect(readUInt24LE(asset, 24) + 1).toBe(expectedWidth);
      expect(readUInt24LE(asset, 27) + 1).toBe(expectedHeight);
    },
  );
});
