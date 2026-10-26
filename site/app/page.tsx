import { CodeDoodle, CupDoodle, CurlyArrow, HomeDoodle, Sparkle, Squiggle, StintMark } from "@/components/Doodles";
import { Features } from "@/components/Features";
import { PanelDemo } from "@/components/PanelDemo";
import { site } from "@/site.config";

function AppleLogo() {
  return (
    <svg width="15" height="18" viewBox="0 0 17 20" fill="currentColor" aria-hidden>
      <path d="M14.1 10.6c0-2.6 2.1-3.8 2.2-3.9-1.2-1.8-3.1-2-3.7-2-1.6-.2-3.1.9-3.9.9-.8 0-2-.9-3.3-.9-1.7 0-3.3 1-4.2 2.5-1.8 3.1-.5 7.7 1.3 10.2.8 1.2 1.8 2.6 3.1 2.6 1.2-.1 1.7-.8 3.2-.8s1.9.8 3.2.8c1.3 0 2.2-1.2 3-2.4.9-1.4 1.3-2.7 1.3-2.8 0 0-2.5-1-2.2-4.2ZM11.6 3c.7-.8 1.1-1.9 1-3-1 0-2.1.7-2.8 1.5-.6.7-1.2 1.8-1 2.9 1.1.1 2.1-.6 2.8-1.4Z" />
    </svg>
  );
}

function DownloadButton({ className = "" }: { className?: string }) {
  return (
    <a href={site.downloadUrl}
       className={`ink-button inline-flex items-center gap-2 bg-mustard px-6 py-3 font-display text-base font-extrabold text-[#1d1b19] ${className}`}>
      <AppleLogo /> Download for Mac
    </a>
  );
}

export default function Home() {
  return (
    <>
      <header className="sticky top-0 z-10 border-b-[2.5px] border-ink bg-paper/90 backdrop-blur-sm">
        <nav className="mx-auto flex h-16 max-w-6xl items-center justify-between px-5">
          <a href="#" className="flex items-center gap-2.5 font-display text-xl font-extrabold tracking-tight">
            <StintMark size={34} />
            {site.name}
          </a>
          <div className="flex items-center gap-5 text-sm font-semibold">
            <a href="#features" className="hidden hover:underline sm:inline">Features</a>
            <a href="#privacy" className="hidden hover:underline sm:inline">Privacy</a>
            <a href={site.repositoryUrl} className="hover:underline">GitHub</a>
            <a href={site.downloadUrl} className="ink-button bg-ink px-4 py-1.5 text-paper">Download</a>
          </div>
        </nav>
      </header>

      <main>
        <section className="relative mx-auto grid max-w-6xl items-center gap-14 px-5 pt-14 pb-24 md:pt-20 lg:grid-cols-[1.1fr_1fr]">
          <div className="relative text-center lg:text-left">
            <span className="ink-button mb-6 inline-block -rotate-2 bg-paper px-3 py-1 text-sm font-semibold [box-shadow:2px_2px_0_var(--ink)]">
              free &amp; open source · for Mac
            </span>
            <h1 className="font-display text-5xl leading-[1.02] font-extrabold tracking-tight text-balance sm:text-7xl">
              Focus, one{" "}
              <span className="relative inline-block">
                stint
                <Squiggle className="absolute -bottom-2 left-0 h-4 w-full text-tomato" />
              </span>{" "}
              at a time.
            </h1>
            <p className="mx-auto mt-7 max-w-xl text-lg leading-relaxed text-muted text-pretty lg:mx-0">
              A calm Pomodoro timer that lives in your menu bar. Work in focused stretches, take real breaks, and see
              where your time went.
            </p>
            <div className="mt-9 flex flex-col items-center gap-4 sm:flex-row sm:justify-center lg:justify-start">
              <DownloadButton />
              <a href={site.repositoryUrl} className="font-display font-bold underline decoration-2 underline-offset-4 hover:decoration-tomato">
                View the source
              </a>
            </div>
            <p className="mt-5 text-[13px] text-muted">Version {site.version} · {site.requirements}</p>
            <p className="mt-1 text-[13px] text-muted">{site.firstLaunch}</p>

            {/* A note in the margin, pointing at the demo. */}
            <div className="pointer-events-none absolute -right-6 bottom-6 hidden -rotate-6 flex-col items-end text-teal lg:flex">
              <span className="font-hand text-[28px] leading-none text-ink">psst, it&apos;s live. try it!</span>
              <CurlyArrow size={86} className="mt-1 text-ink" />
            </div>
          </div>

          <div className="relative">
            <Sparkle size={44} className="bob absolute -top-4 -left-2 z-10 text-ink" />
            <CupDoodle size={58} className="bob absolute -right-1 bottom-20 z-10 hidden text-ink [animation-delay:-2s] sm:block" />
            <PanelDemo />
          </div>
        </section>

        <section id="features" className="mx-auto max-w-6xl scroll-mt-24 px-5 py-20">
          <div className="mx-auto mb-14 max-w-2xl text-center">
            <h2 className="font-display text-4xl font-extrabold tracking-tight sm:text-5xl">
              Everything a focus timer needs.
            </h2>
            <p className="mt-3 font-hand text-[28px] text-muted">…and nothing it doesn&apos;t.</p>
          </div>
          <Features />
        </section>

        <section id="privacy" className="mx-auto grid max-w-6xl scroll-mt-24 gap-8 px-5 py-12 md:grid-cols-2">
          <div className="ink-card relative bg-paper-2 p-8 md:-rotate-1">
            <HomeDoodle size={52} className="mb-3 text-ink" />
            <h2 className="font-display text-2xl font-extrabold tracking-tight">Your focus stays yours.</h2>
            <p className="mt-3 leading-relaxed text-muted">
              No account, no analytics, no servers. Sessions live in a small file on your Mac, and summaries are written
              by the on-device model, so nothing you work on leaves your computer.
            </p>
          </div>
          <div className="ink-card relative bg-paper-2 p-8 md:rotate-1">
            <CodeDoodle size={52} className="mb-3 text-ink" />
            <h2 className="font-display text-2xl font-extrabold tracking-tight">Open source, and yours to shape.</h2>
            <p className="mt-3 leading-relaxed text-muted">
              Written in Swift. Automate it with shortcuts, AppleScript or{" "}
              <code className="rounded-md border-2 border-ink bg-paper px-1.5 text-[0.85em]">stint://</code> links, log
              sessions to Calendar, or read the code and make it your own.
            </p>
          </div>
        </section>

        <section className="mx-auto max-w-3xl px-5 py-24">
          <div className="ink-card relative bg-teal px-6 py-14 text-center text-[#1d1b19] [box-shadow:8px_8px_0_var(--ink)]">
            <Sparkle size={38} className="bob absolute top-5 right-8 text-[#1d1b19]" />
            <StintMark size={96} className="mx-auto mb-4 -rotate-3" />
            <h2 className="font-display text-4xl font-extrabold tracking-tight">Start your first stint.</h2>
            <p className="mt-2 font-hand text-[26px]">free, private, ready in a minute</p>
            <DownloadButton className="mt-7" />
          </div>
        </section>
      </main>

      <footer className="border-t-[2.5px] border-ink">
        <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-3 px-5 py-8 text-[13px] text-muted sm:flex-row">
          <span>{site.name} is free and open source, built with the help of AI tools.</span>
          <div className="flex gap-5 font-semibold">
            <a href={site.repositoryUrl} className="hover:underline">Source</a>
            <a href={`${site.repositoryUrl}/releases`} className="hover:underline">Releases</a>
            <a href={`${site.repositoryUrl}/issues`} className="hover:underline">Report an issue</a>
          </div>
        </div>
      </footer>
    </>
  );
}
