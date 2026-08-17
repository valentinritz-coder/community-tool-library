import type { Metadata } from "next";
import type { ReactNode } from "react";

import "./globals.css";
import "./landing-foundations.css";

export const metadata: Metadata = {
  title: "Communément",
  description:
    "Partagez des objets et organisez votre communauté locale ensemble.",
};

export default function RootLayout({
  children,
}: Readonly<{ children: ReactNode }>) {
  return (
    <html lang="fr">
      <body>{children}</body>
    </html>
  );
}
