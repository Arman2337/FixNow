import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "FixNow Admin",
  description: "Secure operations workspace for FixNow administrators.",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
