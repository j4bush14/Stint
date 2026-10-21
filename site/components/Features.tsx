import type { ReactNode } from "react";

type Feature = { title: string; body: string; icon: ReactNode };

/** Simple line icons in the style of SF Symbols. */
function Icon({ children }: { children: ReactNode }) {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7"
         strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      {children}
    </svg>
  );
}

const features: Feature[] = [
  {
    title: "Lives in your menu bar",
    body: "A ring, a dial, digits or flip tiles show your session at a glance, with a second hand that sweeps while you work. Click for the timer, right-click for everything else.",
    icon: <Icon><rect x="3" y="4" width="18" height="16" rx="3" /><path d="M3 9h18" /><circle cx="16.5" cy="6.5" r="0.6" fill="currentColor" /></Icon>,
  },
  {
    title: "Four clock faces",
    body: "A progress ring, a kitchen-timer dial, clean digits, or a mechanical split-flap that flips every second. The window resizes from a slim bar to full screen.",
    icon: <Icon><circle cx="12" cy="12" r="8.5" /><path d="M12 7.5V12l3 2" /></Icon>,
  },
  {
    title: "Lock-In",
    body: "Once a focus session starts, pausing and skipping stay off until it's done. Breaks can take over the screen so you actually step away.",
    icon: <Icon><rect x="5" y="10.5" width="14" height="10" rx="2.5" /><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5" /></Icon>,
  },
  {
    title: "Fewer distractions",
    body: "Hide chosen apps and swap blocked sites for a quiet page, only while you're focusing. Breaks are never blocked.",
    icon: <Icon><circle cx="12" cy="12" r="8.5" /><path d="m6 6 12 12" /></Icon>,
  },
  {
    title: "History that explains itself",
    body: "Days, weeks, months and years by tag, CSV export, and a short summary of how your focus went, written on your Mac by Apple Intelligence.",
    icon: <Icon><path d="M4 20V10M10 20V4M16 20v-7M22 20H2" /></Icon>,
  },
  {
    title: "Made for your desk",
    body: "Liquid Glass in a theme you choose, a color of your own, or one taken from the wallpaper behind it. Tags can carry their own timer lengths.",
    icon: <Icon><path d="M12 3a9 9 0 1 0 0 18c1.1 0 1.6-.9 1.2-1.8-.5-1-.1-2.2 1.1-2.2H17a4 4 0 0 0 4-4c0-5.5-4-10-9-10Z" /><circle cx="7.5" cy="11" r="1" fill="currentColor" /><circle cx="10.5" cy="7" r="1" fill="currentColor" /><circle cx="15.5" cy="7.5" r="1" fill="currentColor" /></Icon>,
  },
];

export function Features() {
  return (
    <div className="grid gap-px overflow-hidden rounded-3xl border border-hairline bg-hairline sm:grid-cols-2 lg:grid-cols-3">
      {features.map((feature) => (
        <div key={feature.title} className="bg-surface p-7">
          <div className="mb-4 grid size-10 place-items-center rounded-xl bg-focus/10 text-focus">{feature.icon}</div>
          <h3 className="mb-2 text-[17px] font-semibold tracking-tight">{feature.title}</h3>
          <p className="text-[15px] leading-relaxed text-muted">{feature.body}</p>
        </div>
      ))}
    </div>
  );
}
