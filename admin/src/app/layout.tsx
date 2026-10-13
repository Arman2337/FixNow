import type { Metadata } from "next";
import localFont from "next/font/local";
import "./globals.css";

// Self-hosted rather than `next/font/google`. The Google loader downloads every
// font at build time, which makes the build depend on reaching
// fonts.googleapis.com and fonts.gstatic.com: a build machine without that
// egress fails on "Module not found: @vercel/turbopack-next/internal/font/
// google/font" for every single @font-face it could not fetch, and the failure
// says nothing about the network. That is exactly what happened in CI.
//
// The files in this directory are the same woff2 binaries Google serves, taken
// for the latin and latin-ext subsets. Inter is a variable font, so one file
// covers 100-900. Plus Jakarta Sans is served per weight because these three
// are the weights the design system actually uses. Licence: OFL 1.1, in OFL.txt.

const inter = localFont({
  src: [
    { path: "./fonts/Inter-100-900-latin.woff2", weight: "100 900", style: "normal" },
    {
      path: "./fonts/Inter-100-900-latin-ext.woff2",
      weight: "100 900",
      style: "normal",
    },
  ],
  variable: "--font-inter",
  display: "swap",
});

const plusJakartaSans = localFont({
  src: [
    { path: "./fonts/PlusJakartaSans-600-latin.woff2", weight: "600", style: "normal" },
    {
      path: "./fonts/PlusJakartaSans-600-latin-ext.woff2",
      weight: "600",
      style: "normal",
    },
    { path: "./fonts/PlusJakartaSans-700-latin.woff2", weight: "700", style: "normal" },
    {
      path: "./fonts/PlusJakartaSans-700-latin-ext.woff2",
      weight: "700",
      style: "normal",
    },
    { path: "./fonts/PlusJakartaSans-800-latin.woff2", weight: "800", style: "normal" },
    {
      path: "./fonts/PlusJakartaSans-800-latin-ext.woff2",
      weight: "800",
      style: "normal",
    },
  ],
  variable: "--font-plus-jakarta-sans",
  display: "swap",
});

export const metadata: Metadata = {
  title: "FixNow Admin",
  description: "Secure operations workspace for FixNow administrators.",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en" className={`${inter.variable} ${plusJakartaSans.variable}`}>
      <head />
      <body>{children}</body>
    </html>
  );
}
