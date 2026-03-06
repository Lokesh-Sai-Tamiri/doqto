import { cn } from "@/lib/utils";

interface PhoneMockupProps {
  children: React.ReactNode;
  className?: string;
}

export default function PhoneMockup({ children, className }: PhoneMockupProps) {
  return (
    <div className={cn("relative mx-auto", className)} style={{ width: 280, height: 580 }}>
      {/* Phone frame */}
      <svg
        viewBox="0 0 280 580"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
        className="absolute inset-0 w-full h-full z-10 pointer-events-none"
      >
        {/* Outer frame */}
        <rect
          x="2"
          y="2"
          width="276"
          height="576"
          rx="38"
          stroke="#1a1a1a"
          strokeWidth="4"
          fill="none"
        />
        {/* Inner bezel */}
        <rect
          x="6"
          y="6"
          width="268"
          height="568"
          rx="35"
          fill="#111"
        />
        {/* Screen cutout */}
        <rect
          x="14"
          y="14"
          width="252"
          height="552"
          rx="28"
          fill="black"
        />
        {/* Dynamic island */}
        <rect
          x="100"
          y="22"
          width="80"
          height="24"
          rx="12"
          fill="#111"
        />
        {/* Side button right */}
        <rect x="277" y="140" width="3" height="40" rx="1.5" fill="#222" />
        {/* Volume buttons left */}
        <rect x="0" y="120" width="3" height="30" rx="1.5" fill="#222" />
        <rect x="0" y="160" width="3" height="30" rx="1.5" fill="#222" />
      </svg>

      {/* Screen content */}
      <div
        className="absolute z-20 overflow-hidden bg-dark"
        style={{
          top: 14,
          left: 14,
          width: 252,
          height: 552,
          borderRadius: 28,
        }}
      >
        {children}
      </div>

      {/* Dynamic island (above screen content) */}
      <div
        className="absolute z-30 rounded-full bg-[#111]"
        style={{ top: 22, left: 100, width: 80, height: 24 }}
      />
    </div>
  );
}
