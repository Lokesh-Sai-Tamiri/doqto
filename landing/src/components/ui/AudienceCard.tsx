import { cn } from "@/lib/utils";
import * as Icons from "lucide-react";

interface AudienceCardProps {
  title: string;
  size: string;
  icon: string;
  className?: string;
}

export default function AudienceCard({
  title,
  size,
  icon,
  className,
}: AudienceCardProps) {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const Icon = (Icons as any)[icon] ?? Icons.Users;

  return (
    <div
      className={cn(
        "group p-6 rounded-2xl bg-white border border-gray-100 text-center",
        "hover:border-primary/30 hover:shadow-lg hover:shadow-primary/5",
        "transition-all duration-500",
        className
      )}
    >
      <div className="flex items-center justify-center w-14 h-14 rounded-2xl bg-gray-50 text-gray-600 mx-auto mb-4 transition-all duration-500 group-hover:bg-primary/10 group-hover:text-primary-dark">
        <Icon className="w-7 h-7" />
      </div>
      <h3 className="text-lg font-bold text-gray-900 mb-1">{title}</h3>
      <p className="text-sm text-gray-400">{size}</p>
    </div>
  );
}
