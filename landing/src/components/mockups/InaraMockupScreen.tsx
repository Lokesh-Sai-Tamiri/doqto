"use client";

import { useEffect, useState } from "react";

const messages = [
  {
    role: "user" as const,
    text: "Patient presents with crushing chest pain, diaphoresis, and shortness of breath. Troponin I: 2.1 ng/mL. What's the differential?",
  },
  {
    role: "assistant" as const,
    text: "Based on the clinical presentation and elevated troponin, the primary differential includes:\n\n1. **STEMI/NSTEMI** — Most likely given troponin elevation and symptom profile\n2. **Unstable Angina** — If ECG shows no ST elevation\n3. **Pulmonary Embolism** — Consider with D-dimer and CT angiography\n4. **Aortic Dissection** — Rule out with chest CT\n\n**Immediate:** 12-lead ECG, serial troponins q3h, aspirin 325mg, heparin per ACC/AHA guidelines.",
  },
];

export default function InaraMockupScreen() {
  const [visibleMessages, setVisibleMessages] = useState(0);
  const [showTyping, setShowTyping] = useState(false);

  useEffect(() => {
    const prefersReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (prefersReduced) {
      setVisibleMessages(messages.length);
      return;
    }

    const timers: NodeJS.Timeout[] = [];
    timers.push(setTimeout(() => setVisibleMessages(1), 800));
    timers.push(setTimeout(() => setShowTyping(true), 1600));
    timers.push(setTimeout(() => {
      setShowTyping(false);
      setVisibleMessages(2);
    }, 3200));
    return () => timers.forEach(clearTimeout);
  }, []);

  const formatText = (text: string) => {
    return text.split("\n").map((line, i) => {
      const boldFormatted = line.replace(
        /\*\*(.*?)\*\*/g,
        '<strong class="text-primary font-semibold">$1</strong>'
      );
      return (
        <span key={i}>
          {i > 0 && <br />}
          <span dangerouslySetInnerHTML={{ __html: boldFormatted }} />
        </span>
      );
    });
  };

  return (
    <div className="flex flex-col h-full bg-dark text-white">
      {/* Status bar */}
      <div className="flex items-center justify-between px-5 pt-12 pb-2 text-[10px] text-gray-400">
        <span>9:41</span>
        <div className="flex items-center gap-1">
          <div className="w-4 h-2 border border-gray-400 rounded-sm relative">
            <div className="absolute inset-0.5 bg-green-400 rounded-[1px]" style={{ width: "70%" }} />
          </div>
        </div>
      </div>

      {/* Header */}
      <div className="flex items-center gap-3 px-4 py-3 border-b border-white/5">
        <div className="w-9 h-9 rounded-full bg-gradient-to-br from-primary/80 to-primary-dark flex items-center justify-center">
          <svg className="w-5 h-5 text-black" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M12 2a8 8 0 0 0-8 8c0 3.4 2 6.3 5 7.6V20h6v-2.4c3-1.3 5-4.2 5-7.6a8 8 0 0 0-8-8z" />
            <path d="M9 22h6" />
            <path d="M10 14h.01M14 14h.01M10 11h4" />
          </svg>
        </div>
        <div className="flex-1">
          <div className="text-sm font-semibold">Inara</div>
          <div className="text-[10px] text-primary flex items-center gap-1">
            <span className="w-1.5 h-1.5 rounded-full bg-primary inline-block" />
            AI Clinical Assistant
          </div>
        </div>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-hidden px-3 py-4 space-y-3">
        {visibleMessages >= 1 && (
          <div className="flex justify-end animate-[fadeInUp_0.4s_ease-out]">
            <div className="max-w-[90%] bg-surface-light rounded-2xl rounded-tr-sm px-3.5 py-2.5">
              <p className="text-[10px] leading-relaxed text-gray-200">
                {messages[0].text}
              </p>
              <span className="text-[8px] text-gray-500 mt-1 block text-right">9:41 AM</span>
            </div>
          </div>
        )}

        {showTyping && (
          <div className="flex gap-2 max-w-[85%]">
            <div className="bg-surface rounded-2xl px-4 py-3">
              <div className="flex items-center gap-1.5">
                <div className="typing-dot w-1.5 h-1.5 rounded-full bg-primary" />
                <div className="typing-dot w-1.5 h-1.5 rounded-full bg-primary" />
                <div className="typing-dot w-1.5 h-1.5 rounded-full bg-primary" />
              </div>
            </div>
          </div>
        )}

        {visibleMessages >= 2 && (
          <div className="flex gap-2 max-w-[95%] animate-[fadeInUp_0.4s_ease-out]">
            <div className="bg-surface rounded-2xl rounded-tl-sm px-3.5 py-2.5">
              <div className="flex items-center gap-1.5 mb-2">
                <div className="w-4 h-4 rounded-full bg-primary/20 flex items-center justify-center">
                  <svg className="w-2.5 h-2.5 text-primary" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <path d="M12 2a8 8 0 0 0-8 8c0 3.4 2 6.3 5 7.6V20h6v-2.4c3-1.3 5-4.2 5-7.6a8 8 0 0 0-8-8z" />
                  </svg>
                </div>
                <span className="text-[9px] text-primary font-medium">Inara</span>
              </div>
              <div className="text-[10px] leading-relaxed text-gray-200">
                {formatText(messages[1].text)}
              </div>
              <span className="text-[8px] text-gray-500 mt-2 block">9:41 AM</span>
            </div>
          </div>
        )}
      </div>

      {/* Input */}
      <div className="px-3 pb-8 pt-2 border-t border-white/5">
        <div className="flex items-center gap-2 bg-surface rounded-full px-4 py-2.5">
          <svg className="w-4 h-4 text-gray-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <rect width="18" height="18" x="3" y="3" rx="2" ry="2" />
            <circle cx="9" cy="9" r="2" />
            <path d="m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21" />
          </svg>
          <span className="text-[11px] text-gray-500 flex-1">Ask Inara...</span>
          <svg className="w-4 h-4 text-primary" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <line x1="22" x2="11" y1="2" y2="13" />
            <polygon points="22 2 15 22 11 13 2 9 22 2" />
          </svg>
        </div>
      </div>
    </div>
  );
}
