import type { ReactNode } from "react";
import { BlockDoodle, ChartDoodle, ClockDoodle, LockDoodle, MenuBarDoodle, PaletteDoodle } from "./Doodles";

type Feature = { title: string; body: string; doodle: ReactNode; tint: string; tilt: string };

const features: Feature[] = [
  {
    title: "Lives in your menu bar",
    body: "A ring, a dial, digits or flip tiles show your session at a glance, with a second hand that sweeps while you work. Click for the timer, right-click for everything else.",
    doodle: <MenuBarDoodle size={46} />,
    tint: "var(--teal)",
    tilt: "-rotate-1",
  },
  {
    title: "Four clock faces",
    body: "A progress ring, a kitchen-timer dial, clean digits, or a mechanical split-flap that flips every second. The window resizes from a slim bar to full screen.",
    doodle: <ClockDoodle size={46} />,
    tint: "var(--mustard)",
    tilt: "rotate-1",
  },
  {
    title: "Lock-In",
    body: "Once a focus session starts, pausing and skipping stay off until it's done. Breaks can take over the screen so you actually step away.",
    doodle: <LockDoodle size={46} />,
    tint: "var(--lilac)",
    tilt: "-rotate-[0.6deg]",
  },
  {
    title: "Fewer distractions",
    body: "Hide chosen apps and swap blocked sites for a quiet page, only while you're focusing. Breaks are never blocked.",
    doodle: <BlockDoodle size={46} />,
    tint: "var(--tomato)",
    tilt: "rotate-[0.8deg]",
  },
  {
    title: "History that explains itself",
    body: "Days, weeks, months and years by tag, CSV export, and a short summary of how your focus went, written on your Mac by Apple Intelligence.",
    doodle: <ChartDoodle size={46} />,
    tint: "var(--mint)",
    tilt: "-rotate-1",
  },
  {
    title: "Made for your desk",
    body: "An inked panel like this page, or Liquid Glass. Six themes, a color of your own, or colors from your wallpaper. Tags can carry their own timer lengths.",
    doodle: <PaletteDoodle size={46} />,
    tint: "var(--focus)",
    tilt: "rotate-[0.6deg]",
  },
];

export function Features() {
  return (
    <div className="grid gap-7 sm:grid-cols-2 lg:grid-cols-3">
      {features.map((feature) => (
        <div key={feature.title} className={`ink-card bg-paper p-6 transition-transform hover:rotate-0 ${feature.tilt}`}>
          <div className="mb-4 inline-grid size-16 place-items-center rounded-2xl border-[2.5px] border-ink"
               style={{ background: `color-mix(in srgb, ${feature.tint} 30%, var(--paper))` }}>
            {feature.doodle}
          </div>
          <h3 className="mb-2 font-display text-xl font-extrabold tracking-tight">{feature.title}</h3>
          <p className="text-[15px] leading-relaxed text-muted">{feature.body}</p>
        </div>
      ))}
    </div>
  );
}
