"use client";

import { useEffect } from "react";

export function useLenisScroll(targetId: string) {
  const scrollTo = () => {
    const lenis = (window as unknown as { lenis?: { scrollTo: (target: string, options?: Record<string, unknown>) => void } }).lenis;
    if (lenis) {
      lenis.scrollTo(`#${targetId}`, { offset: -80, duration: 1.2 });
    } else {
      document.getElementById(targetId)?.scrollIntoView({ behavior: "smooth" });
    }
  };

  return scrollTo;
}

export function useLenisScrollToHash() {
  useEffect(() => {
    const handleClick = (e: MouseEvent) => {
      const target = e.target as HTMLAnchorElement;
      if (target.tagName === "A" && target.hash) {
        e.preventDefault();
        const id = target.hash.slice(1);
        const lenis = (window as unknown as { lenis?: { scrollTo: (target: string, options?: Record<string, unknown>) => void } }).lenis;
        if (lenis) {
          lenis.scrollTo(`#${id}`, { offset: -80, duration: 1.2 });
        } else {
          document.getElementById(id)?.scrollIntoView({ behavior: "smooth" });
        }
      }
    };

    document.addEventListener("click", handleClick);
    return () => document.removeEventListener("click", handleClick);
  }, []);
}
