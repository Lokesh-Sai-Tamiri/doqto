"use client";

import { useEffect, useRef } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { SECTION_IDS } from "@/lib/constants";
import WaitlistForm from "@/components/ui/WaitlistForm";
import { CreditCard, Rocket, Shield } from "lucide-react";

gsap.registerPlugin(ScrollTrigger);

export default function FinalCTASection() {
  const sectionRef = useRef<HTMLElement>(null);

  useEffect(() => {
    const prefersReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (prefersReduced || !sectionRef.current) return;

    const ctx = gsap.context(() => {
      gsap.fromTo(
        ".cta-content",
        { y: 60, opacity: 0 },
        {
          y: 0,
          opacity: 1,
          duration: 0.8,
          ease: "power3.out",
          scrollTrigger: {
            trigger: sectionRef.current,
            start: "top 75%",
          },
        }
      );
    }, sectionRef);

    return () => ctx.revert();
  }, []);

  return (
    <section
      ref={sectionRef}
      id={SECTION_IDS.cta}
      className="relative py-24 sm:py-32 bg-dark overflow-hidden"
    >
      {/* Background pattern */}
      <div className="absolute inset-0 pointer-events-none">
        <div
          className="absolute inset-0 opacity-[0.03]"
          style={{
            backgroundImage:
              "repeating-linear-gradient(45deg, #FFFC00 0, #FFFC00 1px, transparent 0, transparent 50%)",
            backgroundSize: "40px 40px",
          }}
        />
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[400px] bg-primary/5 rounded-full blur-[150px]" />
      </div>

      <div className="cta-content relative max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <h2 className="text-3xl sm:text-4xl lg:text-5xl font-bold text-white tracking-tight leading-tight mb-6">
          Ready to Secure Your{" "}
          <span className="gradient-text">Healthcare Communication</span>?
        </h2>

        <p className="text-lg text-gray-400 leading-relaxed mb-10 max-w-2xl mx-auto">
          Join thousands of healthcare professionals who are transforming
          how they communicate. Get early access to Dox2Dox.
        </p>

        <div className="max-w-lg mx-auto mb-10">
          <WaitlistForm large />
        </div>

        <div className="flex flex-wrap justify-center gap-8 text-sm text-gray-500">
          <div className="flex items-center gap-2">
            <CreditCard className="w-4 h-4 text-gray-600" />
            <span>No credit card required</span>
          </div>
          <div className="flex items-center gap-2">
            <Rocket className="w-4 h-4 text-gray-600" />
            <span>14-day free trial on launch</span>
          </div>
          <div className="flex items-center gap-2">
            <Shield className="w-4 h-4 text-primary-dark" />
            <span>HIPAA compliant from day one</span>
          </div>
        </div>
      </div>
    </section>
  );
}
