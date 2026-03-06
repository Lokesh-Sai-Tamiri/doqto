"use client";

import { useEffect, useRef } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { SECTION_IDS, SECURITY_FEATURES } from "@/lib/constants";
import SectionHeading from "@/components/ui/SectionHeading";
import FeatureCard from "@/components/ui/FeatureCard";

gsap.registerPlugin(ScrollTrigger);

export default function SecuritySection() {
  const sectionRef = useRef<HTMLElement>(null);

  useEffect(() => {
    const prefersReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (prefersReduced || !sectionRef.current) return;

    const ctx = gsap.context(() => {
      gsap.fromTo(
        ".security-shield",
        { scale: 0.5, opacity: 0, rotation: -20 },
        {
          scale: 1,
          opacity: 1,
          rotation: 0,
          duration: 0.8,
          ease: "back.out(1.7)",
          scrollTrigger: {
            trigger: sectionRef.current,
            start: "top 75%",
          },
        }
      );
      gsap.fromTo(
        ".security-heading",
        { y: 40, opacity: 0 },
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
      gsap.fromTo(
        ".security-card",
        { y: 80, opacity: 0 },
        {
          y: 0,
          opacity: 1,
          duration: 0.8,
          stagger: 0.12,
          ease: "power3.out",
          scrollTrigger: {
            trigger: ".security-grid",
            start: "top 85%",
          },
        }
      );
      gsap.fromTo(
        ".compliance-badge",
        { y: 20, opacity: 0 },
        {
          y: 0,
          opacity: 1,
          duration: 0.6,
          stagger: 0.1,
          ease: "power3.out",
          scrollTrigger: {
            trigger: ".compliance-badges",
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
      id={SECTION_IDS.security}
      className="py-24 sm:py-32"
    >
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Shield icon */}
        <div className="flex justify-center mb-6">
          <div className="security-shield w-20 h-20 rounded-3xl bg-primary/10 flex items-center justify-center">
            <svg className="w-10 h-10 text-primary-dark" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
              <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
              <path d="m9 12 2 2 4-4" />
            </svg>
          </div>
        </div>

        <div className="security-heading">
          <SectionHeading
            badge="Security"
            title="Enterprise-Grade Security, Built In"
            subtitle="Every layer of Dox2Dox is designed with HIPAA compliance and data protection as the foundation — not an afterthought."
          />
        </div>

        <div className="security-grid grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6 lg:gap-8 mb-16">
          {SECURITY_FEATURES.map((feature, i) => (
            <div key={i} className="security-card">
              <FeatureCard
                title={feature.title}
                description={feature.description}
                icon={feature.icon}
              />
            </div>
          ))}
        </div>

        {/* Compliance badges */}
        <div className="compliance-badges flex flex-wrap justify-center gap-6">
          {[
            { label: "HIPAA Compliant", icon: "shield" },
            { label: "SOC 2 Roadmap", icon: "check" },
            { label: "BAA Ready", icon: "file" },
          ].map((badge, i) => (
            <div
              key={i}
              className="compliance-badge flex items-center gap-3 px-6 py-3 rounded-full bg-gray-50 border border-gray-100"
            >
              <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center">
                <svg className="w-4 h-4 text-primary-dark" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  {badge.icon === "shield" && <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />}
                  {badge.icon === "check" && <><path d="M12 22c5.523 0 10-4.477 10-10S17.523 2 12 2 2 6.477 2 12s4.477 10 10 10z" /><path d="m9 12 2 2 4-4" /></>}
                  {badge.icon === "file" && <><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" /><polyline points="14 2 14 8 20 8" /><path d="m9 15 2 2 4-4" /></>}
                </svg>
              </div>
              <span className="font-medium text-gray-700">{badge.label}</span>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
