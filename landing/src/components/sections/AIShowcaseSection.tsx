"use client";

import { useEffect, useRef } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { SECTION_IDS, AI_CAPABILITIES } from "@/lib/constants";
import PhoneMockup from "@/components/mockups/PhoneMockup";
import InaraMockupScreen from "@/components/mockups/InaraMockupScreen";

gsap.registerPlugin(ScrollTrigger);

export default function AIShowcaseSection() {
  const sectionRef = useRef<HTMLElement>(null);

  useEffect(() => {
    const prefersReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (prefersReduced || !sectionRef.current) return;

    const ctx = gsap.context(() => {
      gsap.fromTo(
        ".ai-phone",
        { x: -100, opacity: 0 },
        {
          x: 0,
          opacity: 1,
          duration: 1,
          ease: "power3.out",
          scrollTrigger: {
            trigger: sectionRef.current,
            start: "top 70%",
          },
        }
      );
      gsap.fromTo(
        ".ai-text",
        { x: 60, opacity: 0 },
        {
          x: 0,
          opacity: 1,
          duration: 0.8,
          ease: "power3.out",
          scrollTrigger: {
            trigger: sectionRef.current,
            start: "top 70%",
          },
        }
      );
      gsap.fromTo(
        ".ai-pill",
        { y: 20, opacity: 0 },
        {
          y: 0,
          opacity: 1,
          duration: 0.5,
          stagger: 0.1,
          ease: "power3.out",
          scrollTrigger: {
            trigger: ".ai-pills",
            start: "top 90%",
          },
        }
      );
    }, sectionRef);

    return () => ctx.revert();
  }, []);

  return (
    <section
      ref={sectionRef}
      id={SECTION_IDS.ai}
      className="relative py-24 sm:py-32 bg-dark overflow-hidden"
    >
      {/* Background texture */}
      <div className="absolute inset-0 opacity-30 pointer-events-none"
        style={{
          backgroundImage: "radial-gradient(circle at 1px 1px, rgba(255,252,0,0.07) 1px, transparent 0)",
          backgroundSize: "40px 40px",
        }}
      />

      <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid lg:grid-cols-2 gap-12 lg:gap-20 items-center">
          {/* Phone mockup */}
          <div className="ai-phone flex justify-center lg:justify-end order-2 lg:order-1">
            <div className="animate-float" style={{ animationDelay: "1s" }}>
              <PhoneMockup>
                <InaraMockupScreen />
              </PhoneMockup>
            </div>
          </div>

          {/* Text content */}
          <div className="ai-text order-1 lg:order-2">
            <span className="inline-block px-4 py-1.5 rounded-full text-sm font-medium mb-6 bg-white/10 text-white/80 border border-white/10">
              AI-Powered
            </span>

            <h2 className="text-3xl sm:text-4xl lg:text-5xl font-bold text-white tracking-tight leading-tight mb-6">
              Meet{" "}
              <span className="gradient-text">Inara</span>,{" "}
              Your AI Clinical Assistant
            </h2>

            <p className="text-lg text-gray-400 leading-relaxed mb-8">
              Powered by GPT-5.2 with strict medical guardrails. Inara assists with
              differential diagnoses, drug interaction lookups, clinical guidelines
              from ACC/AHA, WHO, CDC — and even analyzes medical imaging.
            </p>

            <div className="ai-pills flex flex-wrap gap-3 mb-10">
              {AI_CAPABILITIES.map((cap) => (
                <span
                  key={cap}
                  className="ai-pill inline-flex items-center px-4 py-2 rounded-full text-sm font-medium bg-white/5 text-gray-300 border border-white/10 hover:border-primary/30 hover:text-primary transition-colors duration-300"
                >
                  {cap}
                </span>
              ))}
            </div>

            <div className="flex items-center gap-3 text-sm text-gray-500">
              <div className="flex items-center gap-1.5">
                <svg className="w-4 h-4 text-primary" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
                </svg>
                <span>Medical guardrails enforced</span>
              </div>
              <span className="text-gray-700">|</span>
              <div className="flex items-center gap-1.5">
                <svg className="w-4 h-4 text-primary" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <path d="M12 22c5.523 0 10-4.477 10-10S17.523 2 12 2 2 6.477 2 12s4.477 10 10 10z" />
                  <path d="m9 12 2 2 4-4" />
                </svg>
                <span>HIPAA compliant</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
