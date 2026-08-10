"use client";

import { useEffect, useRef } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { SECTION_IDS, AUDIENCES, SPECIALTIES } from "@/lib/constants";

gsap.registerPlugin(ScrollTrigger);

function MarqueeRow({ items, reverse }: { items: readonly string[]; reverse?: boolean }) {
  const doubled = [...items, ...items];
  return (
    <div className="relative overflow-hidden py-2 [mask-image:linear-gradient(to_right,transparent,black_8%,black_92%,transparent)]">
      <div
        className={`flex w-max items-center gap-3 ${reverse ? "animate-marquee-reverse" : "animate-marquee"}`}
      >
        {doubled.map((name, i) => (
          <span
            key={`${name}-${i}`}
            className="whitespace-nowrap rounded-full border border-line bg-card px-5 py-2.5 text-sm text-ink-soft"
          >
            {name}
          </span>
        ))}
      </div>
    </div>
  );
}

export default function AudienceSection() {
  const sectionRef = useRef<HTMLElement>(null);

  useEffect(() => {
    const prefersReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (prefersReduced || !sectionRef.current) return;

    const ctx = gsap.context(() => {
      gsap.fromTo(
        ".audience-reveal",
        { y: 50, opacity: 0 },
        {
          y: 0,
          opacity: 1,
          duration: 0.9,
          stagger: 0.1,
          ease: "power3.out",
          scrollTrigger: { trigger: sectionRef.current, start: "top 75%" },
        }
      );
    }, sectionRef);

    return () => ctx.revert();
  }, []);

  const half = Math.ceil(SPECIALTIES.length / 2);

  return (
    <section ref={sectionRef} id={SECTION_IDS.audience} className="py-28 sm:py-36 bg-cream-deep/60">
      <div className="audience-reveal text-center max-w-2xl mx-auto px-6 mb-14">
        <p className="text-sm uppercase tracking-[0.2em] text-ink-soft mb-6">
          Who it&rsquo;s for
        </p>
        <h2 className="font-display text-4xl sm:text-5xl lg:text-6xl text-ink leading-[1.08]">
          From solo practice to <em>health network.</em>
        </h2>
      </div>

      {/* Specialty marquee — Function pattern */}
      <div className="audience-reveal space-y-3">
        <MarqueeRow items={SPECIALTIES.slice(0, half)} />
        <MarqueeRow items={SPECIALTIES.slice(half)} reverse />
      </div>

      <div className="audience-reveal mt-14 max-w-4xl mx-auto px-6 flex flex-wrap justify-center gap-x-10 gap-y-4 text-sm text-ink-soft">
        {AUDIENCES.map((a) => (
          <span key={a.title} className="flex items-baseline gap-2">
            <span className="font-medium text-ink">{a.title}</span>
            <span>{a.size}</span>
          </span>
        ))}
      </div>
    </section>
  );
}
