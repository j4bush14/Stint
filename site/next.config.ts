import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // A single static page: `next build` writes plain HTML, CSS and JS to out/, which any
  // static host (GitHub Pages, Vercel, Netlify…) can serve.
  output: "export",
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
