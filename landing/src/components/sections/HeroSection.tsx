"use client";

import { useEffect, useRef } from "react";
import gsap from "gsap";
import { SECTION_IDS } from "@/lib/constants";
import WaitlistForm from "@/components/ui/WaitlistForm";
import TrustBadge from "@/components/ui/TrustBadge";
import PhoneMockup from "@/components/mockups/PhoneMockup";
import ChatMockupScreen from "@/components/mockups/ChatMockupScreen";

export default function HeroSection() {
  const sectionRef = useRef<HTMLElement>(null);

  useEffect(() => {
    const prefersReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (prefersReduced || !sectionRef.current) return;

    const ctx = gsap.context(() => {
      const tl = gsap.timeline({ defaults: { ease: "power3.out" } });
      tl.fromTo(".hero-badge", { y: 30, opacity: 0 }, { y: 0, opacity: 1, duration: 0.6 })
        .fromTo(".hero-title", { y: 40, opacity: 0 }, { y: 0, opacity: 1, duration: 0.8 }, "-=0.3")
        .fromTo(".hero-subtitle", { y: 30, opacity: 0 }, { y: 0, opacity: 1, duration: 0.7 }, "-=0.4")
        .fromTo(".hero-form", { y: 30, opacity: 0 }, { y: 0, opacity: 1, duration: 0.7 }, "-=0.3")
        .fromTo(".hero-badges", { y: 20, opacity: 0 }, { y: 0, opacity: 1, duration: 0.6 }, "-=0.3")
        .fromTo(
          ".hero-phone",
          { x: 80, opacity: 0, rotation: 5 },
          { x: 0, opacity: 1, rotation: 0, duration: 1 },
          "-=0.8"
        );
    }, sectionRef);

    return () => ctx.revert();
  }, []);

  return (
    <section
      ref={sectionRef}
      id={SECTION_IDS.hero}
      className="relative min-h-screen flex items-center pt-20 overflow-hidden"
    >
      {/* Background gradient */}
      <div className="absolute inset-0 bg-gradient-to-br from-white via-gray-50/50 to-primary/5 pointer-events-none" />
      <div className="absolute top-0 right-0 w-[600px] h-[600px] bg-primary/5 rounded-full blur-[120px] pointer-events-none" />

      <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 lg:py-20">
        <div className="grid lg:grid-cols-2 gap-12 lg:gap-16 items-center">
          {/* Text column */}
          <div className="max-w-xl">
            <div className="hero-badge inline-flex items-center gap-2 px-4 py-2 rounded-full bg-primary/10 border border-primary/20 mb-8">
              <svg className="w-4 h-4 text-primary-dark" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
              </svg>
              <span className="text-sm font-medium text-gray-700">
                HIPAA Compliant Healthcare Messaging
              </span>
            </div>

            <h1 className="hero-title text-4xl sm:text-5xl lg:text-6xl font-bold tracking-tight text-gray-900 leading-[1.1] mb-6">
              Secure Messaging{" "}
              <span className="relative">
                Built for
                <svg className="absolute -bottom-2 left-0 w-full h-3 text-primary" viewBox="0 0 200 12" preserveAspectRatio="none">
                  <path d="M2 8 Q50 2 100 6 T198 4" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" />
                </svg>
              </span>{" "}
              Healthcare Teams
            </h1>

            <p className="hero-subtitle text-lg sm:text-xl text-gray-500 leading-relaxed mb-8">
              End-to-end encrypted communication for healthcare teams.
              Replace fragmented tools with one HIPAA-compliant platform.
            </p>

            <div className="hero-form mb-8">
              <WaitlistForm />
            </div>

            <div className="hero-badges flex flex-wrap gap-6">
              <TrustBadge icon="shield" label="HIPAA Compliant" />
              <TrustBadge icon="lock" label="AES-256 Encrypted" />
              <TrustBadge icon="check" label="SOC 2 Ready" />
            </div>
          </div>

          {/* Phone mockup */}
          <div className="hero-phone hidden lg:flex justify-center">
            <div className="animate-float">
              <PhoneMockup>
                <ChatMockupScreen />
              </PhoneMockup>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
