// Everything about Stint the site links to or states, in one place.
export const site = {
  name: "Stint",
  tagline: "A calm focus timer for your Mac's menu bar.",
  description:
    "Stint is a free, open-source Pomodoro timer for macOS: Liquid Glass design, four clock faces, Lock-In, app and website blocking, and private history with on-device summaries.",
  // TODO: point these at the real repository before publishing.
  repositoryUrl: "https://github.com/YOUR-USERNAME/stint",
  get downloadUrl() {
    return `${this.repositoryUrl}/releases/latest`;
  },
  requirements: "macOS 27 · Apple silicon",
} as const;
