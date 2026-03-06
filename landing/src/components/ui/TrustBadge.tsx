import { cn } from "@/lib/utils";
import { Shield, Lock, CheckCircle } from "lucide-react";

const icons = {
  shield: Shield,
  lock: Lock,
  check: CheckCircle,
};

interface TrustBadgeProps {
  icon: keyof typeof icons;
  label: string;
  light?: boolean;
  className?: string;
}

export default function TrustBadge({
  icon,
  label,
  light = false,
  className,
}: TrustBadgeProps) {
  const Icon = icons[icon];
  return (
    <div
      className={cn(
        "flex items-center gap-2 text-sm font-medium",
        light ? "text-gray-400" : "text-gray-500",
        className
      )}
    >
      <Icon
        className={cn("w-4 h-4", light ? "text-primary" : "text-primary-dark")}
      />
      <span>{label}</span>
    </div>
  );
}
