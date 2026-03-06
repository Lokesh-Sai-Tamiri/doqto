import { cn } from "@/lib/utils";

interface LogoProps {
  size?: "sm" | "md";
  dark?: boolean;
  className?: string;
}

export default function Logo({
  size = "md",
  dark = false,
  className,
}: LogoProps) {
  const iconPx = size === "sm" ? 32 : 36;

  return (
    <div className={cn("flex items-center gap-2.5", className)}>
      {/* Icon mark */}
      <svg
        width={iconPx}
        height={iconPx}
        viewBox="0 0 36 36"
        fill="none"
        aria-hidden="true"
        className="shrink-0"
        style={{
          filter: "drop-shadow(0 2px 6px rgba(255, 252, 0, 0.25))",
        }}
      >
        {/* Yellow rounded square */}
        <rect width="36" height="36" rx="10" fill="#FFFC00" />

        {/* Left chat bubble — solid, foreground */}
        <path
          d="M4 8.5a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2h-5l-3 3v-3H6a2 2 0 0 1-2-2v-7z"
          fill="#0A0A0A"
        />

        {/* Right chat bubble — translucent, background */}
        <path
          d="M16 13a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2h-1v3l-3-3h-6a2 2 0 0 1-2-2v-7z"
          fill="#0A0A0A"
          opacity="0.45"
        />

        {/* Medical cross — cut through left bubble in yellow */}
        <rect
          x="9.5"
          y="11"
          width="5"
          height="1.5"
          rx="0.75"
          fill="#FFFC00"
        />
        <rect
          x="11.25"
          y="9.25"
          width="1.5"
          height="5"
          rx="0.75"
          fill="#FFFC00"
        />
      </svg>

      {/* Wordmark */}
      <span
        className={cn(
          "font-bold tracking-tight flex items-center",
          size === "sm" ? "text-lg" : "text-xl",
          dark ? "text-white" : "text-gray-900"
        )}
      >
        Dox
        <span
          className={cn(
            "inline-flex items-center justify-center rounded-md bg-primary text-[#0A0A0A] font-black leading-none mx-[2px]",
            size === "sm"
              ? "w-[18px] h-[18px] text-[11px]"
              : "w-[22px] h-[22px] text-[13px]"
          )}
          style={{
            boxShadow: "0 1px 3px rgba(255, 252, 0, 0.3)",
          }}
        >
          2
        </span>
        Dox
      </span>
    </div>
  );
}
