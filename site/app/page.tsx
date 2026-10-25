import { Features } from "@/components/Features";
import { PanelDemo } from "@/components/PanelDemo";
import { site } from "@/site.config";

/** A file in public/, under the path the site is served from. */
const asset = (path: string) => `${process.env.NEXT_PUBLIC_BASE_PATH ?? ""}${path}`;

function AppleLogo() {
  return (
    <svg width="15" height="18" viewBox="0 0 17 20" fill="currentColor" aria-hidden>
      <path d="M14.1 10.6c0-2.6 2.1-3.8 2.2-3.9-1.2-1.8-3.1-2-3.7-2-1.6-.2-3.1.9-3.9.9-.8 0-2-.9-3.3-.9-1.7 0-3.3 1-4.2 2.5-1.8 3.1-.5 7.7 1.3 10.2.8 1.2 1.8 2.6 3.1 2.6 1.2-.1 1.7-.8 3.2-.8s1.9.8 3.2.8c1.3 0 2.2-1.2 3-2.4.9-1.4 1.3-2.7 1.3-2.8 0 0-2.5-1-2.2-4.2ZM11.6 3c.7-.8 1.1-1.9 1-3-1 0-2.1.7-2.8 1.5-.6.7-1.2 1.8-1 2.9 1.1.1 2.1-.6 2.8-1.4Z" />
    </svg>
  );
}

function DownloadButton({ className = "" }: { className?: string }) {
  return (
    <a
      href={site.downloadUrl}
      className={`inline-flex items-center gap-2 rounded-full bg-foreground px-6 py-3 text-[15px] font-medium text-background transition-opacity hover:opacity-85 ${className}`}
    >
      <AppleLogo /> Download for Mac
    </a>
  );
}

export default function Home() {
  return (
    <>
      <header className="sticky top-0 z-10 border-b border-hairline bg-background/80 backdrop-blur-xl">
        <nav className="mx-auto flex h-14 max-w-6xl items-center justify-between px-5">
          <a href="#" className="flex items-center gap-2 font-semibold tracking-tight">
            {/* eslint-disable-next-line @next/next/no-img-element -- a static export can't optimize images */}
            <img src={asset("/stint-icon.png")} alt="" width={26} height={26} />
            {site.name}
          </a>
          <div className="flex items-center gap-6 text-sm">
            <a href="#features" className="hidden text-muted hover:text-foreground sm:inline">Features</a>
            <a href="#privacy" className="hidden text-muted hover:text-foreground sm:inline">Privacy</a>
            <a href={site.repositoryUrl} className="text-muted hover:text-foreground">GitHub</a>
            <a href={site.downloadUrl} className="rounded-full bg-foreground px-3.5 py-1.5 font-medium text-background hover:opacity-85">Download</a>
          </div>
        </nav>
      </header>

      <main>
        <section className="relative overflow-clip">
          {/* Soft light in Stint's focus and break colors. */}
          <div className="pointer-events-none absolute -top-40 right-[-10%] size-[640px] rounded-full bg-focus/20 blur-[120px]" />
          <div className="pointer-events-none absolute top-40 left-[-15%] size-[520px] rounded-full bg-rest/15 blur-[120px]" />

          <div className="relative mx-auto grid max-w-6xl items-center gap-14 px-5 pt-16 pb-24 md:pt-24 lg:grid-cols-[1.1fr_1fr]">
            <div className="text-center lg:text-left">
              <p className="mb-4 text-sm font-medium text-focus">Free and open source for macOS</p>
              <h1 className="font-display text-5xl font-semibold tracking-tight text-balance sm:text-6xl">
                Focus, one stint at a time.
              </h1>
              <p className="mx-auto mt-6 max-w-xl text-lg leading-relaxed text-muted text-pretty lg:mx-0">
                Stint is a calm Pomodoro timer that lives in your menu bar. Work in focused stretches, take real breaks,
                and see where your time went, all in a pane of Liquid Glass.
              </p>
              <div className="mt-9 flex flex-col items-center gap-3 sm:flex-row sm:justify-center lg:justify-start">
                <DownloadButton />
                <a href={site.repositoryUrl} className="rounded-full px-5 py-3 text-[15px] font-medium text-focus hover:underline">
                  View the source →
                </a>
              </div>
              <p className="mt-5 text-[13px] text-muted">Version {site.version} · {site.requirements}</p>
              <p className="mt-1 text-[13px] text-muted">{site.firstLaunch}</p>
            </div>

            <PanelDemo />
          </div>
        </section>

        <section id="features" className="mx-auto max-w-6xl scroll-mt-20 px-5 py-20">
          <div className="mx-auto mb-12 max-w-2xl text-center">
            <h2 className="font-display text-3xl font-semibold tracking-tight sm:text-4xl">Everything a focus timer needs. Nothing it doesn&apos;t.</h2>
            <p className="mt-4 text-lg text-muted">Start a session from the menu bar, a shortcut or a link, and let Stint keep the rhythm.</p>
          </div>
          <Features />
        </section>

        <section id="privacy" className="mx-auto max-w-6xl scroll-mt-20 px-5 py-12">
          <div className="grid gap-8 rounded-3xl border border-hairline bg-surface p-8 sm:p-12 md:grid-cols-2">
            <div>
              <h2 className="font-display text-2xl font-semibold tracking-tight">Your focus stays yours.</h2>
              <p className="mt-3 leading-relaxed text-muted">
                No account, no analytics, no servers. Sessions are saved in a small file on your Mac, and summaries are written by
                the on-device model, so nothing you work on leaves your computer.
              </p>
            </div>
            <div>
              <h2 className="font-display text-2xl font-semibold tracking-tight">Open source, and yours to shape.</h2>
              <p className="mt-3 leading-relaxed text-muted">
                Stint is written in Swift and SwiftUI. Automate it with global shortcuts, AppleScript or <code className="rounded bg-hairline px-1.5 py-0.5 text-[0.9em]">stint://</code> links,
                log sessions to Calendar, or read the code and make it your own.
              </p>
            </div>
          </div>
        </section>

        <section className="mx-auto max-w-6xl px-5 py-24 text-center">
          {/* eslint-disable-next-line @next/next/no-img-element -- a static export can't optimize images */}
          <img src={asset("/stint-icon.png")} alt="" width={88} height={88} className="mx-auto mb-6 drop-shadow-xl" />
          <h2 className="font-display text-4xl font-semibold tracking-tight">Start your first stint.</h2>
          <p className="mt-3 text-lg text-muted">Free, private, and ready in a minute.</p>
          <DownloadButton className="mt-8" />
          <p className="mt-4 text-[13px] text-muted">Version {site.version} · {site.requirements}</p>
        </section>
      </main>

      <footer className="border-t border-hairline">
        <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-3 px-5 py-8 text-[13px] text-muted sm:flex-row">
          <span>{site.name} is free and open source, built with the help of AI tools.</span>
          <div className="flex gap-5">
            <a href={site.repositoryUrl} className="hover:text-foreground">Source</a>
            <a href={`${site.repositoryUrl}/releases`} className="hover:text-foreground">Releases</a>
            <a href={`${site.repositoryUrl}/issues`} className="hover:text-foreground">Report an issue</a>
          </div>
        </div>
      </footer>
    </>
  );
}
