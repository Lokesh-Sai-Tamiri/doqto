import { cn } from "@/lib/utils";
import { Quote } from "lucide-react";

interface TestimonialCardProps {
  name: string;
  role: string;
  org: string;
  quote: string;
  initials: string;
  className?: string;
}

export default function TestimonialCard({
  name,
  role,
  org,
  quote,
  initials,
  className,
}: TestimonialCardProps) {
  return (
    <div
      className={cn(
        "relative p-8 rounded-2xl bg-white border border-gray-100",
        "hover:shadow-lg hover:border-primary/20 transition-all duration-500",
        className
      )}
    >
      <div className="absolute top-6 right-6">
        <span className="inline-block px-2.5 py-1 text-xs font-medium bg-primary/10 text-primary-dark rounded-full">
          Early Access
        </span>
      </div>
      <Quote className="w-8 h-8 text-primary/30 mb-4" />
      <p className="text-gray-600 leading-relaxed mb-6 italic">
        &ldquo;{quote}&rdquo;
      </p>
      <div className="flex items-center gap-4">
        <div className="flex items-center justify-center w-12 h-12 rounded-full bg-gradient-to-br from-primary/80 to-primary-dark text-white font-bold text-sm">
          {initials}
        </div>
        <div>
          <div className="font-semibold text-gray-900">{name}</div>
          <div className="text-sm text-gray-400">
            {role} &middot; {org}
          </div>
        </div>
      </div>
    </div>
  );
}
