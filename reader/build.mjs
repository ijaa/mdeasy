import * as esbuild from "esbuild";
import { cpSync, mkdirSync, rmSync, existsSync } from "node:fs";
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

async function run() {
  if (existsSync(dist)) {
    rmSync(dist, { recursive: true, force: true });
  }
  copyStatic();

  const ctx = await esbuild.context({
    entryPoints: [join(__dirname, "src/app.js")],
    bundle: true,
    minify: !watch,
    sourcemap: watch,
    outfile: join(dist, "app.js"),
    format: "iife",
    target: ["safari15"],
    logLevel: "info",
  });

  if (watch) {
    await ctx.watch();
    console.log("watching reader…");
  } else {
    await ctx.rebuild();
    await ctx.dispose();
    console.log("reader build → dist/");
  }
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
