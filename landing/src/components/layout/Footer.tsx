import Link from "next/link";
import { SECTION_IDS } from "@/lib/constants";
import Logo from "@/components/ui/Logo";

const footerLinks = {
  product: [
    { label: "Features", href: `#${SECTION_IDS.features}` },
    { label: "Security", href: `#${SECTION_IDS.security}` },
    { label: "How It Works", href: `#${SECTION_IDS.howItWorks}` },
  ],
  legal: [
    { label: "Privacy Policy", href: "/privacy" },
    { label: "Terms of Service", href: "/terms" },
    { label: "BAA", href: "/baa" },
    { label: "HIPAA Compliance", href: "/hipaa" },
  ],
  contact: [
    { label: "lokesh@doqto.ai", href: "mailto:lokesh@doqto.ai" },
    { label: "Support", href: "#" },
  ],
};

export default function Footer() {
  return (
    <footer className="bg-cream text-ink-soft pt-16 pb-8 border-t border-line">
      <div className="max-w-7xl mx-auto px-6 sm:px-8">
        <div className="grid grid-cols-2 md:grid-cols-4 gap-10 mb-12">
          {/* Brand */}
          <div className="col-span-2 md:col-span-1">
            <div className="mb-4 flex items-center gap-2">
              <Logo size="sm" />
              <span className="font-display text-2xl text-ink">Doqto</span>
            </div>
            <p className="text-sm leading-relaxed max-w-xs">
              HIPAA-compliant healthcare messaging with end-to-end encryption.
              Built for teams that care.
            </p>
          </div>

          {(
            [
              ["Product", footerLinks.product],
              ["Legal", footerLinks.legal],
              ["Contact", footerLinks.contact],
            ] as const
          ).map(([heading, links]) => (
            <div key={heading}>
              <h4 className="text-ink font-medium text-xs mb-4 uppercase tracking-[0.15em]">
                {heading}
              </h4>
              <ul className="space-y-3">
                {links.map((link) => (
                  <li key={link.label}>
                    {link.href.startsWith("/") ? (
                      <Link
                        href={link.href}
                        className="text-sm hover:text-primary transition-colors duration-300"
                      >
                        {link.label}
                      </Link>
                    ) : (
                      <a
                        href={link.href}
                        className="text-sm hover:text-primary transition-colors duration-300"
                      >
                        {link.label}
                      </a>
                    )}
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        {/* Bottom bar */}
        <div className="pt-8 border-t border-line flex flex-col sm:flex-row items-center justify-between gap-4">
          <p className="text-xs">
            &copy; {new Date().getFullYear()} DOQTO LLC &middot; 11213 Delmar
            St, Leawood, KS 66211. All rights reserved.
          </p>
          <p className="text-xs tracking-wide">
            HIPAA Compliant &middot; AES-256 Encrypted
          </p>
        </div>
      </div>
    </footer>
  );
}
