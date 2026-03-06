"use client";

import { useState, useEffect } from "react";
import { cn } from "@/lib/utils";
import { NAV_LINKS } from "@/lib/constants";
import { Menu, X } from "lucide-react";
import Button from "@/components/ui/Button";
import Logo from "@/components/ui/Logo";

export default function Navbar() {
  const [scrolled, setScrolled] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);

  useEffect(() => {
    const handleScroll = () => setScrolled(window.scrollY > 20);
    window.addEventListener("scroll", handleScroll, { passive: true });
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  const scrollTo = (href: string) => {
    setMobileOpen(false);
    const id = href.replace("#", "");
    const lenis = (window as unknown as { lenis?: { scrollTo: (target: string, options?: Record<string, unknown>) => void } }).lenis;
    if (lenis) {
      lenis.scrollTo(`#${id}`, { offset: -80, duration: 1.2 });
    } else {
      document.getElementById(id)?.scrollIntoView({ behavior: "smooth" });
    }
  };

  return (
    <>
      <nav
        className={cn(
          "fixed top-0 left-0 right-0 z-50 transition-all duration-500",
          scrolled
            ? "bg-white/80 navbar-glass border-b border-gray-100 shadow-sm"
            : "bg-transparent"
        )}
      >
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-20">
            {/* Logo */}
            <button
              onClick={() => scrollTo("#hero")}
              className="cursor-pointer"
            >
              <Logo />
            </button>

            {/* Desktop nav */}
            <div className="hidden md:flex items-center gap-8">
              {NAV_LINKS.map((link) => (
                <button
                  key={link.href}
                  onClick={() => scrollTo(link.href)}
                  className={cn(
                    "text-sm font-medium transition-colors duration-300 cursor-pointer hover:text-primary-dark",
                    scrolled ? "text-gray-600" : "text-gray-600"
                  )}
                >
                  {link.label}
                </button>
              ))}
            </div>

            {/* CTA */}
            <div className="hidden md:block">
              <Button
                size="sm"
                onClick={() => scrollTo("#join-waitlist")}
              >
                Join Waitlist
              </Button>
            </div>

            {/* Mobile hamburger */}
            <button
              className="md:hidden p-2 cursor-pointer"
              onClick={() => setMobileOpen(!mobileOpen)}
              aria-label={mobileOpen ? "Close menu" : "Open menu"}
            >
              {mobileOpen ? (
                <X className="w-6 h-6 text-gray-700" />
              ) : (
                <Menu className="w-6 h-6 text-gray-700" />
              )}
            </button>
          </div>
        </div>
      </nav>

      {/* Mobile drawer */}
      <div
        className={cn(
          "fixed inset-0 z-40 md:hidden transition-all duration-300",
          mobileOpen ? "visible" : "invisible"
        )}
      >
        <div
          className={cn(
            "absolute inset-0 bg-black/20 backdrop-blur-sm transition-opacity duration-300",
            mobileOpen ? "opacity-100" : "opacity-0"
          )}
          onClick={() => setMobileOpen(false)}
        />
        <div
          className={cn(
            "absolute top-20 right-4 left-4 bg-white rounded-2xl shadow-2xl p-6 transition-all duration-300",
            mobileOpen
              ? "opacity-100 translate-y-0"
              : "opacity-0 -translate-y-4"
          )}
        >
          <div className="flex flex-col gap-1">
            {NAV_LINKS.map((link) => (
              <button
                key={link.href}
                onClick={() => scrollTo(link.href)}
                className="text-left px-4 py-3 text-gray-700 font-medium rounded-xl hover:bg-gray-50 transition-colors cursor-pointer"
              >
                {link.label}
              </button>
            ))}
            <div className="mt-4 pt-4 border-t border-gray-100">
              <Button
                className="w-full"
                onClick={() => scrollTo("#join-waitlist")}
              >
                Join Waitlist
              </Button>
            </div>
          </div>
        </div>
      </div>
    </>
  );
}
