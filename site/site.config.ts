// Everything about Stint the site links to or states, in one place.
export const site = {
  name: "Stint",
  tagline: "A calm focus timer for your Mac's menu bar.",
  description:
    "Stint is a free, open-source Pomodoro timer for macOS: a hand-inked or Liquid Glass panel, four clock faces, Lock-In, app and website blocking, and private history with on-device summaries.",
  repositoryUrl: "https://github.com/j4bush14/Stint",
  get downloadUrl() {
    return `${this.repositoryUrl}/releases/latest`;
  },
  version: "2.1.1",
  requirements: "macOS 27 · Apple silicon",
  /** Releases aren't notarized, so macOS asks once before the first launch. */
  firstLaunch: "First launch: open System Settings › Privacy & Security and click Open Anyway.",
} as const;
