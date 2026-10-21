# Stint website

A one-page site for Stint, built with Next.js and Tailwind CSS and exported as static files.

```bash
npm install
npm run dev     # http://localhost:3000
npm run build   # writes the static site to out/
```

## Links

Every Download, Source and Releases link is built from `repositoryUrl` in [`site.config.ts`](site.config.ts); Download points at the repository's latest release.

## Layout

| File | What it is |
|---|---|
| `app/page.tsx` | The page: header, hero, features, privacy, call to action, footer |
| `components/PanelDemo.tsx` | The live timer panel and menu bar item, with a clock-style switcher |
| `components/ClockFaces.tsx` | Ring, dial, split-flap and rolling digits, drawn as in the app |
| `components/Features.tsx` | The feature grid |
| `app/globals.css` | Colors (taken from the app icon and the Lagoon theme) and the flip and roll animations |
| `app/icon.png` | The app icon, rendered by `Scripts/make-icon.swift` |

The page follows the visitor's light or dark appearance and honors Reduce Motion.

## Deploying

`out/` is plain HTML, CSS and JavaScript, so any static host works: GitHub Pages, Netlify, Cloudflare Pages, or Vercel (which also detects Next.js and builds it directly). To serve from a subpath such as `https://you.github.io/stint/`, set `basePath: "/stint"` in `next.config.ts`.
