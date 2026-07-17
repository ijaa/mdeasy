import { renderMarkdown, extractOutlineFromHtml, documentHasMermaid } from "./md.js";

const $ = (sel) => document.querySelector(sel);

const state = {
  path: null,
  baseDir: null,
  text: "",
  theme: "light",
  outlineOpen: true,
  mermaidReady: false,
  mermaidLoading: null,
};

function post(msg) {
  try {
    window.webkit?.messageHandlers?.mdeasy?.postMessage(msg);
  } catch (err) {
    console.warn("bridge post failed", err);
  }
}

function setTheme(name) {
  const theme = ["light", "dark", "sepia", "green"].includes(name) ? name : "light";
  state.theme = theme;
  document.documentElement.setAttribute("data-theme", theme);
  const select = $("#theme-select");
  if (select) select.value = theme;
  // Re-theme mermaid diagrams if present
  if (state.mermaidReady && document.querySelector(".mermaid, .mermaid-block svg")) {
    renderMermaidBlocks().catch(() => {});
  }
}

function setOutlineOpen(open) {
  state.outlineOpen = open;
  $("#outline")?.classList.toggle("hidden", !open);
}

function basename(path) {
  if (!path) return "mdeasy";
  const parts = path.split(/[/\\]/);
  return parts[parts.length - 1] || path;
}

function renderOutline(items) {
  const root = $("#outline");
  if (!root) return;
  if (!items.length) {
    root.innerHTML = `<h2>Outline</h2><div style="padding:8px;color:var(--fg-muted);font-size:12px;">No headings</div>`;
    return;
  }
  const links = items
    .map(
      (it) =>
        `<a href="#${it.id}" class="l${it.level}" data-id="${it.id}">${escapeHtml(it.text)}</a>`
    )
    .join("");
  root.innerHTML = `<h2>Outline</h2>${links}`;
  root.querySelectorAll("a").forEach((a) => {
    a.addEventListener("click", (e) => {
      e.preventDefault();
      const el = document.getElementById(a.dataset.id);
      el?.scrollIntoView({ behavior: "smooth", block: "start" });
    });
  });
}

function escapeHtml(s) {
  return String(s)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function updateActiveOutline() {
  const links = [...document.querySelectorAll("#outline a[data-id]")];
  if (!links.length) return;
  const headings = links
    .map((a) => document.getElementById(a.dataset.id))
    .filter(Boolean);
  let current = headings[0];
  const top = 96;
  for (const h of headings) {
    const rect = h.getBoundingClientRect();
    if (rect.top <= top) current = h;
  }
  links.forEach((a) => {
    a.classList.toggle("active", a.dataset.id === current?.id);
  });
}

async function ensureMermaid() {
  if (state.mermaidReady) return window.mermaid;
  if (state.mermaidLoading) return state.mermaidLoading;

  state.mermaidLoading = (async () => {
    const mod = await import("./mermaid-runtime.js");
    const mermaid = mod.default;
    const dark = state.theme === "dark";
    mermaid.initialize({
      startOnLoad: false,
      securityLevel: "strict",
      theme: dark ? "dark" : "default",
      fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif",
    });
    window.mermaid = mermaid;
    state.mermaidReady = true;
    return mermaid;
  })();

  try {
    return await state.mermaidLoading;
  } catch (err) {
    state.mermaidLoading = null;
    throw err;
  }
}

async function renderMermaidBlocks() {
  const nodes = [...document.querySelectorAll(".mermaid-block .mermaid, pre.mermaid")];
  if (!nodes.length) return;

  let mermaid;
  try {
    mermaid = await ensureMermaid();
  } catch (err) {
    nodes.forEach((node) => {
      const wrap = node.closest(".mermaid-block") || node;
      wrap.innerHTML = `<div class="mermaid-error">Mermaid failed to load: ${escapeHtml(String(err?.message || err))}</div>`;
    });
    return;
  }

  const dark = state.theme === "dark";
  mermaid.initialize({
    startOnLoad: false,
    securityLevel: "strict",
    theme: dark ? "dark" : "default",
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif",
  });

  // mermaid.run expects elements with class mermaid still containing source text
  try {
    await mermaid.run({ nodes, suppressErrors: true });
  } catch (err) {
    console.warn("mermaid.run error", err);
  }
}

async function showDoc({ path, text }) {
  state.path = path;
  state.text = text ?? "";
  const title = basename(path);
  $("#doc-title").textContent = title;
  document.title = `${title} · mdeasy`;

  const html = renderMarkdown(state.text);
  const content = $("#content");
  content.classList.remove("empty");
  content.innerHTML = html;
  const outline = extractOutlineFromHtml(html);
  renderOutline(outline);
  content.scrollTop = 0;
  requestAnimationFrame(updateActiveOutline);

  if (documentHasMermaid(state.text) || content.querySelector(".mermaid")) {
    await renderMermaidBlocks();
  }
}

function showEmpty() {
  state.path = null;
  state.text = "";
  $("#doc-title").textContent = "mdeasy";
  document.title = "mdeasy";
  const content = $("#content");
  content.classList.add("empty");
  content.innerHTML = `<div class="empty-state"><h1>mdeasy</h1><p>Open a Markdown file to start reading.</p><p class="hint">⌘O open · drag & drop · double-click .md<br/>Menu: mdeasy → Set as Default Markdown App</p></div>`;
  renderOutline([]);
}

function buildExportHtml() {
  const theme = state.theme;
  const body = $("#content")?.innerHTML ?? "";
  const title = basename(state.path) || "export";
  let css = "";
  try {
    for (const sheet of document.styleSheets) {
      try {
        for (const rule of sheet.cssRules) {
          css += rule.cssText + "\n";
        }
      } catch {
        // ignore
      }
    }
  } catch {
    // ignore
  }

  return `<!DOCTYPE html>
<html lang="zh-CN" data-theme="${theme}">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>${escapeHtml(title)}</title>
<style>
${css}
body { margin: 0; background: var(--bg); color: var(--fg); }
.markdown-body { padding: 32px 24px 64px; }
.markdown-body > * { max-width: 42rem; margin-left: auto; margin-right: auto; }
</style>
</head>
<body>
<article class="markdown-body">
${body}
</article>
</body>
</html>`;
}

function handleNativeEvent(msg) {
  if (!msg || typeof msg !== "object") return;
  try {
    switch (msg.type) {
      case "doc":
        state.baseDir = msg.baseDir;
        console.info("mdeasy: doc received", msg.path, "chars=", (msg.text || "").length);
        showDoc({ path: msg.path, text: msg.text });
        break;
      case "file-changed":
        showDoc({ path: msg.path || state.path, text: msg.text });
        break;
      case "theme":
        setTheme(msg.name);
        break;
      case "toggle-outline":
        setOutlineOpen(!state.outlineOpen);
        post({ type: "set-preference", key: "outlineOpen", value: state.outlineOpen });
        break;
      case "request-export": {
        if (!state.path) return;
        const html = buildExportHtml();
        const base = basename(state.path).replace(/\.(md|markdown|mdx|mdown|mkd|mkdn|mdwn)$/i, "");
        post({ type: "export-html", html, suggestedName: `${base}.html` });
        break;
      }
      default:
        break;
    }
  } catch (err) {
    console.error("mdeasy: handle failed", err);
    post({ type: "error", message: String(err?.message || err) });
  }
}

function bindUi() {
  $("#btn-outline")?.addEventListener("click", () => {
    setOutlineOpen(!state.outlineOpen);
    post({ type: "set-preference", key: "outlineOpen", value: state.outlineOpen });
  });

  $("#theme-select")?.addEventListener("change", (e) => {
    const name = e.target.value;
    setTheme(name);
    post({ type: "set-preference", key: "theme", value: name });
  });

  $("#content")?.addEventListener("scroll", () => {
    updateActiveOutline();
  });

  document.addEventListener("keydown", (e) => {
    const meta = e.metaKey || e.ctrlKey;
    if (meta && e.key.toLowerCase() === "b") {
      e.preventDefault();
      setOutlineOpen(!state.outlineOpen);
      post({ type: "set-preference", key: "outlineOpen", value: state.outlineOpen });
    }
  });
}

window.__mdeasy = {
  handle: handleNativeEvent,
};

// Expose a simple fingerprint for native probing.
window.__mdeasyVersion = "0.2.2";

bindUi();
setTheme("light");
showEmpty();
// ready may race with native openFile — native side keeps latestDoc and retries.
post({ type: "ready" });
// Second ready tick helps if the first message was sent before the handler was attached on the native side.
setTimeout(() => post({ type: "ready" }), 50);

// Browser-only preview helper (no native bridge)
if (!window.webkit?.messageHandlers?.mdeasy) {
  const demo = `# mdeasy preview

This is the **browser** preview of the full reader pack.

## Features

- GFM tables
- Task lists
- Mermaid diagrams (bundled)

\`\`\`js
console.log("hello mdeasy");
\`\`\`

| A | B |
| - | - |
| 1 | 2 |

- [x] Offline
- [x] Mermaid

\`\`\`mermaid
graph LR
  A[Open .md] --> B[Render]
  B --> C[Read]
\`\`\`
`;
  showDoc({ path: "preview.md", text: demo });
  console.info("mdeasy reader: browser preview mode (full)");
}
