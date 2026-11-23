import { defineConfig, type Plugin } from "vite";

// Source links are relative so opening index.html from disk in Chrome finds
// public/files. The dev server and the published build serve those files at /files.
function publishedFileLinks(): Plugin {
  return {
    name: "published-file-links",
    transformIndexHtml(html) {
      return html.replaceAll('href="public/files/', 'href="/files/');
    },
  };
}

export default defineConfig({
  plugins: [publishedFileLinks()],
});
