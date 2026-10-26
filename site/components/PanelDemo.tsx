"use client";

import { useEffect, useState } from "react";
import { clock, Dial, ProgressRing, RollingDigits, SplitFlap, wedgePath } from "./ClockFaces";

const styles = ["Ring", "Dial", "Digital", "Flip"] as const;
type Style = (typeof styles)[number];

const focusLength = 25 * 60;
const breakLength = 5 * 60;

type Timer = { onBreak: boolean; remaining: number };

/** The next phase, from its start. */
const next = ({ onBreak }: Timer): Timer => ({ onBreak: !onBreak, remaining: onBreak ? focusLength : breakLength });

/** One second later; a finished phase moves on to the next. */
const tick = (timer: Timer): Timer => (timer.remaining > 1 ? { ...timer, remaining: timer.remaining - 1 } : next(timer));

/**
 * Stint's timer panel and menu bar item, rebuilt for the web: pick a clock style and the
 * panel and menu bar change together, as in the app. The countdown runs for real.
 */
export function PanelDemo() {
  const [style, setStyle] = useState<Style>("Ring");
  const [{ onBreak, remaining }, setTimer] = useState({ onBreak: false, remaining: 18 * 60 + 37 });
  const [running, setRunning] = useState(true);
  const length = onBreak ? breakLength : focusLength;

  useEffect(() => {
    if (!running) return;
    const id = setInterval(() => setTimer(tick), 1000);
    return () => clearInterval(id);
  }, [running]);

  const skip = () => setTimer(next);
  /** Back to the full length, stopped, as the app's ↺ button does. */
  const reset = () => {
    setRunning(false);
    setTimer(({ onBreak }) => ({ onBreak, remaining: onBreak ? breakLength : focusLength }));
  };
  const started = running || remaining < length;

  const time = clock(remaining);
  const progress = 1 - remaining / length;

  return (
    <div className="mx-auto flex w-full max-w-[400px] flex-col items-center gap-5">
      <MenuBar style={style} time={time} progress={progress} running={running} started={started}
               elapsed={length - remaining} onBreak={onBreak} />

      <Panel
        style={style}
        time={time}
        progress={progress}
        remaining={remaining / length}
        running={running}
        onBreak={onBreak}
        started={started}
        onToggle={() => setRunning(!running)}
        onSkip={skip}
        onReset={reset}
      />

      <div role="tablist" aria-label="Clock style" className="ink-card flex gap-1 rounded-full bg-paper p-1.5 [box-shadow:3px_3px_0_var(--ink)]">
        {styles.map((option) => (
          <button
            key={option}
            role="tab"
            aria-selected={style === option}
            onClick={() => setStyle(option)}
            className={`rounded-full px-4 py-1.5 font-display text-sm font-semibold transition-colors ${
              style === option ? "bg-ink text-paper" : "text-muted hover:bg-paper-2 hover:text-ink"
            }`}
          >
            {option}
          </button>
        ))}
      </div>
    </div>
  );
}

type FaceProps = {
  style: Style;
  time: string;
  progress: number;
  running: boolean;
  onBreak: boolean;
};

/** ▶ when ready, ❚❚ when paused, drawn inside the ring or dial or beside the digits. */
function Mark({ started, size }: { started: boolean; size: number }) {
  return started ? (
    <svg width={size} height={size} viewBox="0 0 10 10" fill="currentColor" aria-hidden>
      <rect x="2.2" y="1.5" width="2" height="7" rx="0.6" /><rect x="5.8" y="1.5" width="2" height="7" rx="0.6" />
    </svg>
  ) : (
    <svg width={size} height={size} viewBox="0 0 10 10" fill="currentColor" aria-hidden><path d="M2.5 1.5v7l6-3.5z" /></svg>
  );
}

/**
 * A slice of the macOS menu bar with Stint's item, as the app draws it: the clock style's
 * shape, a second hand that sweeps once a minute while running, ▶ or ❚❚ when stopped, and
 * dimmed time whenever it isn't counting down.
 */
function MenuBar({ style, time, progress, running, started, elapsed, onBreak }: FaceProps & { started: boolean; elapsed: number }) {
  const dim = running ? "" : "opacity-50";
  const hand = (elapsed % 60) * 6; // degrees from 12 o'clock
  const glyph = onBreak ? (
    <span aria-hidden>☕︎</span>
  ) : style === "Ring" || style === "Dial" ? (
    <span className="relative grid size-[15px] place-items-center">
      {style === "Ring" ? (
        <ProgressRing progress={progress} size={15} stroke={2} />
      ) : (
        <svg width={15} height={15} viewBox="0 0 16 16" aria-hidden>
          <circle cx={8} cy={8} r={7} fill="none" stroke="currentColor" strokeWidth={1.25} />
          <path d={wedgePath(8, 5, 1 - progress)} fill="currentColor" opacity={running ? 1 : 0.45} />
        </svg>
      )}
      {running ? (
        <svg className="absolute inset-0" width={15} height={15} viewBox="0 0 16 16" aria-hidden>
          <line x1={8} y1={8} x2={8} y2={style === "Ring" ? 4 : 3.2} strokeLinecap="round" strokeWidth={1.3}
                stroke={style === "Ring" ? "currentColor" : "var(--paper-2)"} transform={`rotate(${hand} 8 8)`}
                style={{ transition: "transform 0.3s ease-out" }} />
        </svg>
      ) : (
        <span className="absolute inset-0 grid place-items-center"><Mark started={started} size={6} /></span>
      )}
    </span>
  ) : !running ? (
    <Mark started={started} size={9} />
  ) : null;

  return (
    <div className="ink-card flex h-10 w-full items-center justify-end gap-4 rounded-2xl bg-paper-2 px-4 text-[13px] font-medium text-ink [box-shadow:3px_3px_0_var(--ink)]">
      <span className="flex items-center gap-1.5" aria-label={`Stint menu bar item, ${time} left${running ? "" : started ? ", paused" : ", ready"}`}>
        {glyph}
        {style === "Flip" ? (
          <span className={`flex items-center gap-0.5 font-semibold ${dim}`}>
            {time.split(":").map((part, index) => (
              <span key={index} className="flex items-center gap-0.5">
                {index > 0 && <span>:</span>}
                <span className="rounded-[4px] bg-ink px-1 leading-[18px] text-paper tabular-nums">{part}</span>
              </span>
            ))}
          </span>
        ) : (
          <RollingDigits text={time} className={dim} />
        )}
      </span>
      <span className="text-muted">Wed 9:41 AM</span>
    </div>
  );
}

/** The timer panel: a pane of glass in the focus or break color. */
function Panel({
  style, time, progress, remaining, running, started, onBreak, onToggle, onSkip, onReset,
}: FaceProps & { remaining: number; started: boolean; onToggle: () => void; onSkip: () => void; onReset: () => void }) {
  // Flat colors, like the rest of the page: teal while focusing, blue on a break.
  const color = onBreak ? "var(--color-focus)" : "var(--color-teal)";
  return (
    <div
      className="relative aspect-[320/404] w-full max-w-[340px] overflow-hidden rounded-[34px] border-[3px] border-ink text-white transition-colors duration-700 [box-shadow:7px_7px_0_var(--ink)]"
      style={{ background: color }}
    >
      {/* Glass highlight. */}

      <div className="relative flex h-full flex-col items-center px-5 pt-4 pb-5">
        <div className="flex w-full items-center justify-between">
          <span className="grid size-6 place-items-center rounded-full border-2 border-[#1d1b19] bg-white/25 text-[11px] font-bold" aria-hidden>✕</span>
          <span className="text-[13px] font-semibold">
            {onBreak ? "Short Break" : "Focus"}
            {!onBreak && <span className="opacity-65"> · 1 of 4</span>}
          </span>
          <span className="grid size-6 place-items-center rounded-full border-2 border-[#1d1b19] bg-white/25 text-[13px] font-bold leading-none" aria-hidden>⋯</span>
        </div>

        <div className="flex flex-1 items-center justify-center">
          <Face style={style} time={time} progress={progress} remaining={remaining} />
        </div>

        <div className="flex items-center gap-4">
          <button
            onClick={onReset}
            disabled={!started}
            aria-label="Reset"
            title="Reset"
            className="grid size-10 place-items-center rounded-full border-[2.5px] border-[#1d1b19] bg-white/25 transition-all hover:bg-white/40 disabled:pointer-events-none disabled:opacity-0"
          >
            <svg width="17" height="17" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
              <path d="M4.5 10a5.5 5.5 0 1 0 1.8-4.1" /><path d="M4.2 3.2v3.6h3.6" />
            </svg>
          </button>
          <button
            onClick={onToggle}
            aria-label={running ? "Pause" : "Start"}
            className="grid size-14 place-items-center rounded-full border-[3px] border-[#1d1b19] bg-[#fbf5e9] shadow-[3px_3px_0_#1d1b19] transition-transform hover:-translate-y-0.5 active:translate-x-0.5 active:translate-y-0.5 active:shadow-none"
            style={{ color }}
          >
            {running ? (
              <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor" aria-hidden><rect x="4" y="3" width="4.5" height="14" rx="1.2" /><rect x="11.5" y="3" width="4.5" height="14" rx="1.2" /></svg>
            ) : (
              <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor" aria-hidden><path d="M5 3.5v13a1 1 0 0 0 1.5.86l11-6.5a1 1 0 0 0 0-1.72l-11-6.5A1 1 0 0 0 5 3.5Z" /></svg>
            )}
          </button>
          <button
            onClick={onSkip}
            aria-label={onBreak ? "Skip break" : "Skip to break"}
            className="grid size-10 place-items-center rounded-full border-[2.5px] border-[#1d1b19] bg-white/25 transition-colors hover:bg-white/40"
          >
            <svg width="16" height="16" viewBox="0 0 20 20" fill="currentColor" aria-hidden><path d="M3 4.5v11a1 1 0 0 0 1.55.83L12 11.2V15.5a1 1 0 0 0 1 1h1.5a1 1 0 0 0 1-1v-11a1 1 0 0 0-1-1H13a1 1 0 0 0-1 1v4.3L4.55 3.67A1 1 0 0 0 3 4.5Z" /></svg>
          </button>
        </div>

        <span className="mt-4 flex items-center gap-1.5 rounded-full border-2 border-[#1d1b19] bg-white/20 px-3 py-1 text-[11px] font-semibold">
          <span className="size-2 rounded-full border border-[#1d1b19] bg-[#f4bd3e]" /> Deep Work
        </span>
      </div>
    </div>
  );
}

function Face({ style, time, progress, remaining }: { style: Style; time: string; progress: number; remaining: number }) {
  const title = <span className="font-hand text-[22px] leading-none opacity-85">Draft chapter 3</span>;
  switch (style) {
    case "Ring":
      return (
        <div className="relative grid place-items-center">
          <ProgressRing progress={progress} size={210} stroke={9} />
          <div className="absolute flex flex-col items-center gap-2.5">
            <RollingDigits text={time} className="font-display text-[54px] font-extrabold leading-none tracking-tight" />
            {title}
          </div>
        </div>
      );
    case "Dial":
      return (
        <div className="flex flex-col items-center gap-3">
          <Dial remaining={remaining} size={170} />
          <RollingDigits text={time} className="font-display text-[36px] font-extrabold leading-none" />
        </div>
      );
    case "Digital":
      return (
        <div className="flex flex-col items-center gap-2">
          <RollingDigits text={time} className="font-display text-[74px] font-extrabold leading-none tracking-tight" />
          {title}
        </div>
      );
    case "Flip": {
      const [minutes, seconds] = time.split(":");
      return (
        <div className="flex flex-col items-center gap-4">
          <div className="flex items-center gap-2 font-display text-[64px] font-extrabold leading-none">
            <SplitFlap value={minutes} className="h-[100px] w-[100px]" />
            <SplitFlap value={seconds} className="h-[100px] w-[100px]" />
          </div>
          {title}
        </div>
      );
    }
  }
}
