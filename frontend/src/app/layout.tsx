import type { Metadata } from "next";
import { Inter, Space_Grotesk } from "next/font/google";
import { Providers } from "@/providers/Providers";
import "./globals.css";
import { cn } from "@/lib/utils";

/**
 * Inter — headlines, body copy (Stitch: font-headline + font-body)
 * Space Grotesk — all label/data text: nav items, seat IDs, times,
 *                 route codes, stats (Stitch: font-label)
 */
const inter = Inter({
  subsets: ["latin"],
  variable: "--font-sans",
  display: "swap",
});

const spaceGrotesk = Space_Grotesk({
  subsets: ["latin"],
  variable: "--font-mono",
  display: "swap",
});

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_API_URL || "http://localhost"),
  title: {
    default: "Shuttle Office — Smart Commute",
    template: "%s | Shuttle Office",
  },
  description:
    "Find and book office shuttle rides. Browse schedules, compare routes, and reserve your seat.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      className={cn("h-full antialiased", inter.variable, spaceGrotesk.variable)}
    >
      <body className="min-h-full flex flex-col font-sans">
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
