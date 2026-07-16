"use client";

import { useEffect, useRef } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { SECTION_IDS, AUDIENCES } from "@/lib/constants";
import SectionHeading from "@/components/ui/SectionHeading";
import AudienceCard from "@/components/ui/AudienceCard";

gsap.registerPlugin(ScrollTrigger);

export default function AudienceSection() {
  const sectionRef = useRef<HTMLElement>(null);

  useEffect(() => {
    const prefersReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (prefersReduced || !sectionRef.current) return;

    const ctx = gsap.context(() => {
      gsap.fromTo(
        ".audience-heading",
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
      gsap.fromTo(
        ".audience-card",
        { y: 60, opacity: 0 },
        {
          y: 0,
          opacity: 1,
          duration: 0.7,
          stagger: 0.1,
          ease: "power3.out",
          scrollTrigger: {
            trigger: ".audience-grid",
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
      id={SECTION_IDS.audience}
      className="py-24 sm:py-32"
    >
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="audience-heading">
          <SectionHeading
            badge="Who It's For"
            title="Built for Every Healthcare Team"
            subtitle="From solo practitioners to large health networks — Doqto scales with your organization."
          />
        </div>

        <div className="audience-grid grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-4 lg:gap-6">
          {AUDIENCES.map((audience, i) => (
            <div key={i} className="audience-card">
              <AudienceCard
                title={audience.title}
                size={audience.size}
                icon={audience.icon}
              />
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
