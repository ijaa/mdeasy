import * as esbuild from "esbuild";
import { cpSync, mkdirSync, rmSync, existsSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const dist = join(__dirname, "dist");
const watch = process.argv.includes("--watch");

function copyStatic() {
  mkdirSync(dist, { recursive: true });
  cpSync(join(__dirname, "index.html"), join(dist, "index.html"));
  cpSync(join(__dirname, "styles"), join(dist, "styles"), { recursive: true });
}

function patchIndexForChunks() {
  // esbuild with splitting emits app.js + chunks; index already loads app.js only.
  // Ensure index exists after copy.
  const indexPath = join(dist, "index.html");
  if (!existsSync(indexPath)) return;
  // no-op placeholder for future integrity hashes
  void readFileSync;
  void writeFileSync;
}

async function run() {
  if (existsSync(dist)) {
    rmSync(dist, { recursive: true, force: true });
  }
  copyStatic();

  const options = {
    entryPoints: [join(__dirname, "src/app.js")],
    bundle: true,
    minify: !watch,
    sourcemap: watch,
    outdir: dist,
    entryNames: "[name]",
    chunkNames: "chunks/[name]-[hash]",
    format: "esm",
    splitting: true,
    target: ["safari15"],
    logLevel: "info",
    // Keep mermaid as its own async chunk via dynamic import()
  };

  const ctx = await esbuild.context(options);

  if (watch) {
    await ctx.watch();
    console.log("watching reader…");
  } else {
    await ctx.rebuild();
    await ctx.dispose();
    patchIndexForChunks();
    console.log("reader build → dist/");
  }
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
