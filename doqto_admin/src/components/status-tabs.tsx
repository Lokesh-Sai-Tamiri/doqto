"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";

import { cn } from "@/lib/cn";

const TABS = [
  { value: "pending", label: "Pending" },
  { value: "active", label: "Active" },
  { value: "suspended", label: "Rejected" },
  { value: "all", label: "All" },
] as const;

export function StatusTabs() {
  const params = useSearchParams();
  const current = params?.get("status") ?? "pending";

  return (
    <div className="flex gap-1 border-b border-gray-100">
      {TABS.map((tab) => {
        const active = current === tab.value;
        return (
          <Link
            key={tab.value}
            href={`/orgs?status=${tab.value}`}
            className={cn(
              "px-4 py-3 text-sm font-semibold border-b-2 -mb-px transition-colors",
              active
                ? "border-primary text-primary"
                : "border-transparent text-gray-400 hover:text-gray-600",
            )}
          >
            {tab.label}
          </Link>
        );
      })}
    </div>
  );
}
