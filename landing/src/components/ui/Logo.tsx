import Image from "next/image";
import { cn } from "@/lib/utils";

interface LogoProps {
  size?: "sm" | "md";
  dark?: boolean;
  className?: string;
}

export default function Logo({ size = "md", className }: LogoProps) {
  const px = size === "sm" ? 40 : 48;

  return (
    <Image
      src="/logo-square.png"
      alt="Doqto"
      width={px}
      height={px}
      priority
      className={cn("shrink-0 rounded-[22%]", className)}
    />
  );
}
