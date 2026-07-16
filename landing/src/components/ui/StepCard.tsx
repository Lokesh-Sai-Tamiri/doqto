import { cn } from "@/lib/utils";

interface StepCardProps {
  step: number;
  title: string;
  description: string;
  className?: string;
}

export default function StepCard({
  step,
  title,
  description,
  className,
}: StepCardProps) {
  return (
    <div className={cn("relative flex flex-col items-center text-center", className)}>
      <div className="flex items-center justify-center w-16 h-16 rounded-full bg-primary text-white text-2xl font-bold mb-6 shadow-lg shadow-primary/20">
        {step}
      </div>
      <h3 className="text-xl font-bold text-gray-900 mb-3">{title}</h3>
      <p className="text-gray-500 leading-relaxed max-w-xs">{description}</p>
    </div>
  );
}
