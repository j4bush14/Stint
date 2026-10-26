import type { Metadata, Viewport } from "next";
import { Bricolage_Grotesque, Caveat } from "next/font/google";
import { site } from "@/site.config";
import "./globals.css";

// Self-hosted at build time: the page makes no requests to Google or anyone else.
const display = Bricolage_Grotesque({ subsets: ["latin"], variable: "--font-bricolage", weight: ["600", "800"] });
const hand = Caveat({ subsets: ["latin"], variable: "--font-caveat", weight: ["600"] });

export const metadata: Metadata = {
  title: `${site.name}: ${site.tagline}`,
  description: site.description,
  openGraph: {
    title: site.name,
    description: site.description,
    type: "website",
  },
};

export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#fbf5e9" },
    { media: "(prefers-color-scheme: dark)", color: "#1a1b1e" },
  ],
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en" className={`${display.variable} ${hand.variable} h-full antialiased`}>
      <body className="min-h-full font-sans">
        {/* The hand-drawn wobble every .doodle uses: a little noise pushes the lines about. */}
        <svg width="0" height="0" className="absolute" aria-hidden>
          <filter id="wobble">
            <feTurbulence type="fractalNoise" baseFrequency="0.035" numOctaves="2" seed="4" />
            <feDisplacementMap in="SourceGraphic" scale="2.6" />
          </filter>
        </svg>
        {children}
      </body>
    </html>
  );
}
