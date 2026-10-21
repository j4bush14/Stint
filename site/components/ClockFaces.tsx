"use client";

import { useState } from "react";

/** "24:37" for a number of seconds. */
export function clock(seconds: number) {
  const s = Math.max(0, Math.ceil(seconds));
  return `${String(Math.floor(s / 60)).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`;
}

/** Digits that roll up into place when they change. */
export function RollingDigits({ text, className = "" }: { text: string; className?: string }) {
  return (
    <span className={`inline-flex tabular-nums ${className}`} aria-label={text}>
      {text.split("").map((character, index) => (
        // Keyed by value, so a changed digit remounts and plays its roll.
        <span key={`${index}-${character}`} className="roll-in" aria-hidden>
          {character}
        </span>
      ))}
    </span>
  );
}

/** The panel's ring: a faint track with the elapsed part drawn clockwise from 12. */
export function ProgressRing({ progress, size, stroke }: { progress: number; size: number; stroke: number }) {
  const radius = (size - stroke) / 2;
  const circumference = 2 * Math.PI * radius;
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} className="-rotate-90" aria-hidden>
      <circle cx={size / 2} cy={size / 2} r={radius} fill="none" stroke="currentColor" strokeOpacity={0.18} strokeWidth={stroke} />
      <circle
        cx={size / 2}
        cy={size / 2}
        r={radius}
        fill="none"
        stroke="currentColor"
        strokeWidth={stroke}
        strokeLinecap="round"
        strokeDasharray={circumference}
        strokeDashoffset={circumference * (1 - progress)}
        style={{ transition: "stroke-dashoffset 1s linear" }}
      />
    </svg>
  );
}

/** A pie slice from 12 o'clock, clockwise, covering `fraction` of a circle. */
export function wedgePath(center: number, radius: number, fraction: number) {
  const f = Math.min(Math.max(fraction, 0), 0.9999);
  const angle = f * 2 * Math.PI - Math.PI / 2;
  const x = center + radius * Math.cos(angle);
  const y = center + radius * Math.sin(angle);
  return `M ${center} ${center} L ${center} ${center - radius} A ${radius} ${radius} 0 ${f > 0.5 ? 1 : 0} 1 ${x} ${y} Z`;
}

/** The kitchen-timer dial: a wedge of time left that shrinks toward 12 o'clock. */
export function Dial({ remaining, size }: { remaining: number; size: number }) {
  const c = size / 2;
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} aria-hidden>
      <circle cx={c} cy={c} r={c} fill="currentColor" fillOpacity={0.1} />
      <path d={wedgePath(c, c * 0.78, remaining)} fill="currentColor" fillOpacity={0.6} style={{ transition: "d 1s linear" }} />
      {Array.from({ length: 60 }, (_, tick) => {
        const hour = tick % 5 === 0;
        const angle = (tick / 60) * 2 * Math.PI - Math.PI / 2;
        const outer = c - 2;
        const inner = outer - (hour ? c * 0.1 : c * 0.05);
        return (
          <line
            key={tick}
            x1={c + Math.cos(angle) * inner}
            y1={c + Math.sin(angle) * inner}
            x2={c + Math.cos(angle) * outer}
            y2={c + Math.sin(angle) * outer}
            stroke="currentColor"
            strokeOpacity={hour ? 0.7 : 0.3}
            strokeWidth={hour ? 2 : 1}
          />
        );
      })}
      <circle cx={c} cy={c} r={5} fill="currentColor" />
    </svg>
  );
}

/** One half of a split-flap tile, showing the top or bottom of `digits`. */
function FlapHalf({ digits, half, className = "" }: { digits: string; half: "top" | "bottom"; className?: string }) {
  return (
    <div
      className={`absolute inset-x-0 h-1/2 overflow-hidden bg-[#26303b] ${half === "top" ? "top-0 rounded-t-[inherit]" : "bottom-0 rounded-b-[inherit]"} ${className}`}
      style={{ backfaceVisibility: "hidden" }}
    >
      <div className={`absolute inset-x-0 flex h-[200%] items-center justify-center ${half === "top" ? "top-0" : "bottom-0"}`}>
        {digits}
      </div>
    </div>
  );
}

/** A mechanical split-flap tile. When its digits change, a flap turns over the hinge. */
export function SplitFlap({ value, className = "" }: { value: string; className?: string }) {
  // Remember what was shown before, to animate from it (React's "previous props" pattern).
  const [state, setState] = useState({ current: value, previous: value, flips: 0 });
  if (state.current !== value) {
    setState({ current: value, previous: state.current, flips: state.flips + 1 });
  }
  const { current, previous, flips } = state;
  return (
    <div className={`relative rounded-[14%] text-white tabular-nums shadow-lg [perspective:400px] ${className}`} aria-label={value}>
      <FlapHalf digits={current} half="top" />
      <FlapHalf digits={flips > 0 ? previous : current} half="bottom" />
      {flips > 0 && (
        <>
          <FlapHalf key={`top-${flips}`} digits={previous} half="top" className="flap-top" />
          <FlapHalf key={`bottom-${flips}`} digits={current} half="bottom" className="flap-bottom" />
        </>
      )}
      {/* The hinge. */}
      <div className="absolute inset-x-0 top-1/2 h-px -translate-y-1/2 bg-black/50" />
    </div>
  );
}
