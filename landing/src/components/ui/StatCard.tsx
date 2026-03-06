"use client";

import { cn } from "@/lib/utils";
import { useCountUp } from "@/hooks/useCountUp";

interface StatCardProps {
  value: number;
  prefix?: string;
  suffix?: string;
  label: string;
  className?: string;
}

export default function StatCard({
  value,
  prefix = "",
  suffix = "",
  label,
  className,
}: StatCardProps) {
  const { count, ref } = useCountUp(value, { duration: 2500 });

  return (
    <div
      ref={ref as React.RefObject<HTMLDivElement>}
      className={cn(
        "relative p-8 rounded-2xl bg-white border border-gray-100 shadow-sm text-center",
        "hover:shadow-lg hover:border-primary/20 transition-all duration-500",
        className
      )}
    >
      <div className="text-4xl sm:text-5xl font-bold text-gray-900 mb-3 tabular-nums">
        {prefix}
        {count}
        {suffix}
      </div>
      <p className="text-gray-500 text-sm sm:text-base">{label}</p>
    </div>
  );
}
