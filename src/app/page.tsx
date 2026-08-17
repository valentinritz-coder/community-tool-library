import type { Metadata } from "next";

import { LandingPage } from "@/ui/landing-page";

export const metadata: Metadata = {
  title: "Communément",
  description:
    "Partagez des objets et organisez votre communauté locale ensemble.",
};

export default function Home() {
  return <LandingPage />;
}
