"use client";

import { useEffect, useRef } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { SECTION_IDS, STEPS } from "@/lib/constants";
import SectionHeading from "@/components/ui/SectionHeading";
import StepCard from "@/components/ui/StepCard";

gsap.registerPlugin(ScrollTrigger);

export default function HowItWorksSection() {
  const sectionRef = useRef<HTMLElement>(null);

  useEffect(() => {
    const prefersReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (prefersReduced || !sectionRef.current) return;

    const ctx = gsap.context(() => {
      gsap.fromTo(
        ".hiw-heading",
        { y: 60, opacity: 0 },
        {
          y: 0,
          opacity: 1,
          duration: 0.8,
          ease: "power3.out",
          scrollTrigger: {
            trigger: sectionRef.current,
            start: "top 80%",
          },
        }
      );

      // Animate the connecting line
      gsap.fromTo(
        ".hiw-line",
        { strokeDashoffset: 1000 },
        {
          strokeDashoffset: 0,
          duration: 1.5,
          ease: "power2.inOut",
          scrollTrigger: {
            trigger: ".hiw-steps",
            start: "top 85%",
          },
        }
      );

      // Animate steps sequentially
      gsap.fromTo(
        ".hiw-step",
        { y: 60, opacity: 0 },
        {
          y: 0,
          opacity: 1,
          duration: 0.7,
          stagger: 0.25,
          ease: "power3.out",
          scrollTrigger: {
            trigger: ".hiw-steps",
            start: "top 85%",
          },
        }
      );
    }, sectionRef);

    return () => ctx.revert();
  }, []);

  return (
    <section
      ref={sectionRef}
      id={SECTION_IDS.howItWorks}
      className="py-24 sm:py-32 bg-light-bg"
    >
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="hiw-heading">
          <SectionHeading
            badge="How It Works"
            title="Get Started in Minutes"
            subtitle="Three simple steps to transform your healthcare communication."
          />
        </div>

        <div className="hiw-steps relative">
          {/* Connecting line (desktop) */}
          <svg
            className="hidden lg:block absolute top-8 left-[16.6%] right-[16.6%] h-1 pointer-events-none"
            preserveAspectRatio="none"
            viewBox="0 0 1000 4"
          >
            <line
              className="hiw-line"
              x1="0" y1="2" x2="1000" y2="2"
              stroke="#E5E7EB"
              strokeWidth="3"
              strokeDasharray="8 8"
              strokeDashoffset="0"
              style={{ strokeDasharray: 1000 }}
            />
          </svg>

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-12 lg:gap-8">
            {STEPS.map((step) => (
              <div key={step.step} className="hiw-step">
                <StepCard
                  step={step.step}
                  title={step.title}
                  description={step.description}
                />
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
