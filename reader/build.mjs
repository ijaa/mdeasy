import * as esbuild from "esbuild";
import { cpSync, mkdirSync, rmSync, existsSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { dirname, join, extname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const dist = join(__dirname, "dist");
const watch = process.argv.includes("--watch");

// Single source of truth for the app version is App/Info.plist (CFBundleShortVersionString).
// Inject it into the bundle so the JS "ready" handshake reports the same version as the app.
function readAppVersion() {
  const plist = join(__dirname, "..", "App", "Info.plist");
  if (!existsSync(plist)) return "0.0.0";
  const m = readFileSync(plist, "utf8").match(
    /<key>CFBundleShortVersionString<\/key>\s*<string>([^<]+)<\/string>/
  );
  return m ? m[1] : "0.0.0";
}
const APP_VERSION = readAppVersion();

function copyStatic() {
  mkdirSync(dist, { recursive: true });
  // index.html is patched (see writeIndex) to use a classic IIFE script.
  cpSync(join(__dirname, "styles"), join(dist, "styles"), { recursive: true });

  // F4：仅拷贝 KaTeX 的 woff2 字体到 dist/fonts/（删 woff/ttf，省 ~800KB）。
  // katex.min.css 内的 url(fonts/KaTeX_*.woff2) 相对路径在 mdeye-app://reader/ 与
  // 打印 WebView 的 file://.../reader/ 两种 base 下都指向同目录，自洽。
  const katexFonts = join(__dirname, "node_modules", "katex", "dist", "fonts");
  if (existsSync(katexFonts)) {
    const outFonts = join(dist, "fonts");
    mkdirSync(outFonts, { recursive: true });
    for (const f of readdirSync(katexFonts)) {
      if (extname(f) === ".woff2") cpSync(join(katexFonts, f), join(outFonts, f));
    }
    // 拷一份剥离 woff/ttf src 的 katex.min.css（避免浏览器对不存在字体 404）。
    const cssOut = writeStrippedKatexCss(join(katexFonts, "..", "katex.min.css"), join(dist, "styles", "katex.min.css"));
    if (!cssOut) console.warn("katex.min.css not found; styles/katex.min.css not written");
  } else {
    console.warn("katex dist/fonts not found; formulas will render without fonts");
  }
}

// F4：删 katex.min.css 里的 woff/ttf url 声明，仅保留 woff2。
function writeStrippedKatexCss(srcPath, outPath) {
  if (!existsSync(srcPath)) return false;
  let css = readFileSync(srcPath, "utf8");
  // 形如 src:url(x.woff2) format("woff2"),url(x.woff) format("woff"),url(x.ttf)
  // 删除 woff/ttf 的 url 段，保留 woff2。
  css = css.replace(/,\s*url\([^)]*\.woff\)/g, "");
  css = css.replace(/,\s*url\([^)]*\.ttf\)/g, "");
  // 清理可能的尾随逗号 (src:url(x.woff2), → src:url(x.woff2))
  css = css.replace(/,\s*\)/g, ")");
  writeFileSync(outPath, css, "utf8");
  return true;
}

function writeIndex() {
  // Reuse the committed source index.html directly. It already ships as a classic
  // (non-module) script with the correct CSP for mdeye-app:// — no build-time rewrite
  // needed. Keeping a single copy avoids the source/produced-HTML divergence trap.
  cpSync(join(__dirname, "index.html"), join(dist, "index.html"));
}

async function run() {
  if (existsSync(dist)) {
    rmSync(dist, { recursive: true, force: true });
  }
  copyStatic();
  writeIndex();

  // Single IIFE bundle — no dynamic import chunks (file:// cannot load ESM modules).
  // Mermaid is included in the main bundle so diagrams work offline without import().
  const options = {
    entryPoints: [join(__dirname, "src/app.js")],
    bundle: true,
    minify: !watch,
    sourcemap: watch,
    outfile: join(dist, "app.js"),
    format: "iife",
    globalName: "mdeyeReader",
    target: ["safari14"],
    logLevel: "info",
    define: {
      __MDEYE_VERSION__: JSON.stringify(APP_VERSION),
    },
  };

  const ctx = await esbuild.context(options);

  if (watch) {
    await ctx.watch();
    console.log("watching reader (iife)…");
  } else {
    await ctx.rebuild();
    await ctx.dispose();
    const size = readFileSync(join(dist, "app.js")).byteLength;
    console.log(`reader build → dist/app.js (${(size / 1024).toFixed(0)} KB IIFE)`);
  }
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
