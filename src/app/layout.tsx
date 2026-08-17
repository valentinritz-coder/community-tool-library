import type { Metadata } from "next";
import type { ReactNode } from "react";

import "./globals.css";
import "./landing-foundations.css";

export const metadata: Metadata = {
  title: "Community Tool Library",
  description: "Share useful tools with people in your local community.",
};

export default function RootLayout({
  children,
}: Readonly<{ children: ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
