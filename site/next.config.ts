import type { NextConfig } from "next";

// GitHub Pages serves the site from /Stint; the deploy workflow sets BASE_PATH to that.
// Locally it's empty, so the site is at the root of http://localhost:3000.
const basePath = process.env.BASE_PATH ?? "";

const nextConfig: NextConfig = {
  // A single static page: `next build` writes plain HTML, CSS and JS to out/, which any
  // static host (GitHub Pages, Vercel, Netlify…) can serve.
  output: "export",
  basePath,
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

export default nextConfig;
