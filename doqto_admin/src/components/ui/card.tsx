import type { HTMLAttributes } from "react";

import { cn } from "@/lib/cn";

export function Card({ className, ...props }: HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn(
        "rounded-lg bg-white p-6 shadow-[0_2px_12px_rgba(26,86,219,0.08)]",
        className,
      )}
      {...props}
    />
  );
}
