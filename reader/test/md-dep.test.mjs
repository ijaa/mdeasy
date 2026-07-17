import test from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";

// Build-free smoke: ensure package can resolve markdown-it
const require = createRequire(import.meta.url);

test("markdown-it dependency resolves", () => {
  const MarkdownIt = require("markdown-it");
  const md = new MarkdownIt();
  const html = md.render("# Hello\n\n**world**");
  assert.match(html, /<h1>/);
  assert.match(html, /<strong>world<\/strong>/);
});
