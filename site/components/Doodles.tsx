import type { ReactNode, SVGProps } from "react";

/*
 * Hand-inked doodles: thick round strokes in the ink color with flat fills from Stint's
 * palette. The .doodle class adds a slight wobble, so lines look drawn rather than plotted.
 */

type DoodleProps = SVGProps<SVGSVGElement> & { size?: number };

function Doodle({ size = 64, viewBox = "0 0 64 64", className = "", children, ...rest }: DoodleProps & { children: ReactNode }) {
  return (
    <svg width={size} height={size} viewBox={viewBox} fill="none" stroke="currentColor" strokeWidth={3}
         strokeLinecap="round" strokeLinejoin="round" aria-hidden className={`doodle ${className}`} {...rest}>
      {children}
    </svg>
  );
}

/** A wavy underline for a word in a heading. */
export function Squiggle({ className = "" }: { className?: string }) {
  return (
    <svg viewBox="0 0 220 18" preserveAspectRatio="none" aria-hidden className={`doodle ${className}`}
         fill="none" stroke="currentColor" strokeWidth={5} strokeLinecap="round">
      <path d="M4 12c18-9 30 7 48 0s30-9 48-1 30 9 48 1 30-9 48-2 14 4 20 1" />
    </svg>
  );
}

/** A loose curved arrow, pointing right and down. */
export function CurlyArrow(props: DoodleProps) {
  return (
    <Doodle viewBox="0 0 90 60" {...props}>
      <path d="M6 10c22-6 44 0 54 14s6 22-6 20-10-16 6-20 22 4 22 18" />
      <path d="M74 36l8 8 4-11" />
    </Doodle>
  );
}

export function Sparkle(props: DoodleProps) {
  return (
    <Doodle {...props}>
      <path d="M32 8c2 13 6 18 20 24-14 6-18 11-20 24-2-13-6-18-20-24 14-6 18-11 20-24z" fill="var(--mustard)" />
    </Doodle>
  );
}

/** Stint's ring as a sticker: the menu bar's little timer. */
export function MenuBarDoodle(props: DoodleProps) {
  return (
    <Doodle viewBox="0 0 64 64" {...props}>
      <rect x="6" y="18" width="52" height="28" rx="8" fill="var(--paper-2)" />
      <circle cx="20" cy="32" r="7" />
      <path d="M20 25a7 7 0 1 1-6.6 9.4" stroke="var(--teal)" strokeWidth={4} />
      <path d="M33 28v8M39 28v8M45 28h4v8M33 32h6" strokeWidth={2.6} />
    </Doodle>
  );
}

/** A little clock with the four faces' hands. */
export function ClockDoodle(props: DoodleProps) {
  return (
    <Doodle {...props}>
      <circle cx="32" cy="34" r="22" fill="var(--paper-2)" />
      <path d="M32 34L32 20" />
      <path d="M32 34l10 6" />
      <path d="M24 9h16M32 9v4" />
      <path d="M32 12a22 22 0 0 1 22 22H32z" fill="var(--teal)" stroke="none" opacity={0.9} />
      <circle cx="32" cy="34" r="22" />
      <circle cx="32" cy="34" r="2.5" fill="currentColor" />
    </Doodle>
  );
}

export function LockDoodle(props: DoodleProps) {
  return (
    <Doodle {...props}>
      <path d="M21 28v-7a11 11 0 0 1 22 0v7" />
      <rect x="14" y="28" width="36" height="28" rx="7" fill="var(--mustard)" />
      <path d="M32 38v8" strokeWidth={4} />
      <circle cx="32" cy="38" r="2.5" fill="currentColor" />
    </Doodle>
  );
}

/** A "no entry" sign over a browser window: blocking distractions. */
export function BlockDoodle(props: DoodleProps) {
  return (
    <Doodle {...props}>
      <rect x="6" y="12" width="40" height="32" rx="5" fill="var(--paper-2)" />
      <path d="M6 20h40M11 16h1M16 16h1" />
      <circle cx="44" cy="42" r="14" fill="var(--tomato)" />
      <path d="M35 42h18" stroke="var(--paper)" strokeWidth={5} />
      <circle cx="44" cy="42" r="14" />
    </Doodle>
  );
}

export function ChartDoodle(props: DoodleProps) {
  return (
    <Doodle {...props}>
      <path d="M8 54h48" />
      <rect x="12" y="34" width="9" height="20" rx="2" fill="var(--teal)" />
      <rect x="27" y="22" width="9" height="32" rx="2" fill="var(--mint)" />
      <rect x="42" y="12" width="9" height="42" rx="2" fill="var(--focus)" />
    </Doodle>
  );
}

export function PaletteDoodle(props: DoodleProps) {
  return (
    <Doodle {...props}>
      <path d="M32 8C17 8 7 18 7 31s10 25 24 25c4 0 6-2 6-5 0-4-4-5-1-8 2-2 6-1 10-1 7 0 11-5 11-12C57 17 46 8 32 8z" fill="var(--paper-2)" />
      <circle cx="21" cy="25" r="4" fill="var(--tomato)" />
      <circle cx="33" cy="19" r="4" fill="var(--mustard)" />
      <circle cx="45" cy="25" r="4" fill="var(--teal)" />
      <circle cx="19" cy="38" r="4" fill="var(--lilac)" />
    </Doodle>
  );
}

/** A steaming cup: breaks. */
export function CupDoodle(props: DoodleProps) {
  return (
    <Doodle {...props}>
      <path d="M14 26h30v14a12 12 0 0 1-12 12h-6a12 12 0 0 1-12-12z" fill="var(--paper-2)" />
      <path d="M44 30h4a6 6 0 0 1 0 12h-5" />
      <path d="M22 18c-3-4 3-6 0-10M30 18c-3-4 3-6 0-10M38 18c-3-4 3-6 0-10" />
      <path d="M10 56h40" />
    </Doodle>
  );
}

/** A closed padlock on a house: data stays home. */
export function HomeDoodle(props: DoodleProps) {
  return (
    <Doodle {...props}>
      <path d="M8 30L32 10l24 20" />
      <path d="M14 26v28h36V26" fill="var(--paper-2)" />
      <rect x="26" y="38" width="12" height="16" rx="2" fill="var(--teal)" />
    </Doodle>
  );
}

/** Two hands-on brackets: open source. */
export function CodeDoodle(props: DoodleProps) {
  return (
    <Doodle {...props}>
      <rect x="6" y="12" width="52" height="40" rx="8" fill="var(--paper-2)" />
      <path d="M24 24l-8 8 8 8M40 24l8 8-8 8M35 20l-6 24" />
    </Doodle>
  );
}

/**
 * Stint's ring as ink clip art, matching app/icon.svg. The tile's outline and shadow use the
 * page's ink, so they turn to chalk in dark mode; the ring keeps its dark outline.
 */
export function StintMark({ size = 64, className = "" }: { size?: number; className?: string }) {
  const ring = "M29.5 15a14.5 14.5 0 1 1-13.63 9.54";
  return (
    <svg width={size} height={size} viewBox="0 0 64 64" fill="none" strokeLinecap="round" aria-hidden className={className}>
      <rect x="7.5" y="7.5" width="52" height="52" rx="14" fill="var(--ink)" />
      <rect x="3.5" y="3.5" width="52" height="52" rx="14" fill="#29a3ad" stroke="var(--ink)" strokeWidth={3} />
      <path d="M10 18c1.5-4 4-6.5 8-8" stroke="#fbf5e9" strokeWidth={3} />
      <circle cx="29.5" cy="29.5" r="14.5" stroke="#1d1b19" strokeOpacity={0.22} strokeWidth={7} />
      <path d={ring} stroke="#1d1b19" strokeWidth={9} />
      <path d={ring} stroke="#fbf5e9" strokeWidth={4} />
      <circle cx="15.87" cy="24.54" r="3" fill="#f4bd3e" stroke="#1d1b19" strokeWidth={2} />
    </svg>
  );
}
