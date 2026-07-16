import type { Metadata } from "next";
import { Outfit } from "next/font/google";
import SmoothScrollProvider from "@/providers/SmoothScrollProvider";
import "./globals.css";

const outfit = Outfit({
  subsets: ["latin"],
  variable: "--font-outfit",
  display: "swap",
});

export const metadata: Metadata = {
  title: "Doqto — Secure Healthcare Messaging",
  description:
    "HIPAA-compliant messaging platform with E2E encryption, voice messaging, and organization management. Built for healthcare teams.",
  keywords: [
    "HIPAA compliant messaging",
    "healthcare communication",
    "encrypted messaging",
    
    "medical messaging app",
    "secure healthcare chat",
  ],
  openGraph: {
    title: "Doqto — Secure Healthcare Messaging",
    description:
      "HIPAA-compliant messaging with E2E encryption. Built for healthcare teams.",
    type: "website",
    siteName: "Doqto",
  },
  twitter: {
    card: "summary_large_image",
    title: "Doqto — Secure Healthcare Messaging",
    description:
      "HIPAA-compliant messaging with E2E encryption.",
  },
  robots: {
    index: true,
    follow: true,
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className={outfit.variable}>
      <body className="bg-white text-gray-900 antialiased">
        <SmoothScrollProvider>{children}</SmoothScrollProvider>
      </body>
    </html>
  );
}
