import { cn } from "@/lib/utils";
import * as Icons from "lucide-react";

interface FeatureCardProps {
  title: string;
  description: string;
  icon: string;
  className?: string;
}

export default function FeatureCard({
  title,
  description,
  icon,
  className,
}: FeatureCardProps) {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const Icon = (Icons as any)[icon] ?? Icons.Circle;

  return (
    <div
      className={cn(
        "group relative p-8 rounded-2xl bg-white border border-gray-100",
        "hover:border-primary/30 hover:shadow-xl hover:shadow-primary/5",
        "transition-all duration-500",
        className
      )}
    >
      <div className="flex items-center justify-center w-14 h-14 rounded-2xl bg-primary/10 text-primary-dark mb-6 transition-transform duration-500 group-hover:scale-110 group-hover:rotate-3">
        <Icon className="w-7 h-7" />
      </div>
      <h3 className="text-xl font-bold text-gray-900 mb-3">{title}</h3>
      <p className="text-gray-500 leading-relaxed">{description}</p>
    </div>
  );
}
