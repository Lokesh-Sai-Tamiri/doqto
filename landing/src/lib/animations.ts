import gsap from "gsap";

export const fadeInUp = (
  element: gsap.TweenTarget,
  options?: { delay?: number; duration?: number; y?: number }
) => {
  return gsap.fromTo(
    element,
    { y: options?.y ?? 60, opacity: 0 },
    {
      y: 0,
      opacity: 1,
      duration: options?.duration ?? 1,
      delay: options?.delay ?? 0,
      ease: "power3.out",
    }
  );
};

export const staggerCards = (
  elements: gsap.TweenTarget,
  options?: { stagger?: number; y?: number }
) => {
  return gsap.fromTo(
    elements,
    { y: options?.y ?? 80, opacity: 0 },
    {
      y: 0,
      opacity: 1,
      duration: 0.8,
      stagger: options?.stagger ?? 0.15,
      ease: "power3.out",
    }
  );
};

export const slideFromLeft = (
  element: gsap.TweenTarget,
  options?: { duration?: number; x?: number }
) => {
  return gsap.fromTo(
    element,
    { x: options?.x ?? -100, opacity: 0 },
    {
      x: 0,
      opacity: 1,
      duration: options?.duration ?? 1,
      ease: "power3.out",
    }
  );
};

export const slideFromRight = (
  element: gsap.TweenTarget,
  options?: { duration?: number; x?: number }
) => {
  return gsap.fromTo(
    element,
    { x: options?.x ?? 100, opacity: 0 },
    {
      x: 0,
      opacity: 1,
      duration: options?.duration ?? 1,
      ease: "power3.out",
    }
  );
};

export const scaleIn = (
  element: gsap.TweenTarget,
  options?: { duration?: number; scale?: number; rotation?: number }
) => {
  return gsap.fromTo(
    element,
    {
      scale: options?.scale ?? 0.8,
      opacity: 0,
      rotation: options?.rotation ?? 0,
    },
    {
      scale: 1,
      opacity: 1,
      rotation: 0,
      duration: options?.duration ?? 0.8,
      ease: "back.out(1.7)",
    }
  );
};

export const drawLine = (
  element: gsap.TweenTarget,
  options?: { duration?: number }
) => {
  return gsap.fromTo(
    element,
    { strokeDashoffset: 1000 },
    {
      strokeDashoffset: 0,
      duration: options?.duration ?? 2,
      ease: "power2.inOut",
    }
  );
};
