import { renderMarkdown, extractOutlineFromHtml } from "./md.js";

const $ = (sel) => document.querySelector(sel);

const state = {
  path: null,
  baseDir: null,
  text: "",
  theme: "light",
  outlineOpen: true,
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

function showDoc({ path, text }) {
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
}

function showEmpty() {
  state.path = null;
  state.text = "";
  $("#doc-title").textContent = "mdeasy";
  document.title = "mdeasy";
  const content = $("#content");
  content.classList.add("empty");
  content.innerHTML = `<div class="empty-state"><h1>mdeasy</h1><p>Open a Markdown file to start reading.</p><p class="hint">⌘O open · drag & drop · double-click .md</p></div>`;
  renderOutline([]);
}

function buildExportHtml() {
  const theme = state.theme;
  const body = $("#content")?.innerHTML ?? "";
  const title = basename(state.path) || "export";
  // Inline minimal CSS by reading stylesheets text is hard offline; embed current computed tokens via style tags linked as absolute file won't work in export.
  // We snapshot the three CSS files content from the page's styleSheets cssRules when possible.
  let css = "";
  try {
    for (const sheet of document.styleSheets) {
      try {
        for (const rule of sheet.cssRules) {
          css += rule.cssText + "\n";
        }
      } catch {
        // ignore cross-origin
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
  switch (msg.type) {
    case "doc":
      state.baseDir = msg.baseDir;
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
      const base = basename(state.path).replace(/\.(md|markdown|mdx|mdown)$/i, "");
      post({ type: "export-html", html, suggestedName: `${base}.html` });
      break;
    }
    default:
      break;
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

// Public bridge for Swift evaluateJavaScript
window.__mdeasy = {
  handle: handleNativeEvent,
};

bindUi();
setTheme("light");
showEmpty();
post({ type: "ready" });

// Browser-only preview helper (no native bridge)
if (!window.webkit?.messageHandlers?.mdeasy) {
  const demo = `# mdeasy preview

This is the **browser** preview of the reader.

## Features

- GFM tables
- Task lists
- \`inline code\`

\`\`\`js
console.log("hello mdeasy");
\`\`\`

| A | B |
| - | - |
| 1 | 2 |

- [x] Offline
- [ ] Mermaid engine (optional pack)

\`\`\`mermaid
graph LR
  A[md] --> B[reader]
\`\`\`
`;
  showDoc({ path: "preview.md", text: demo });
  console.info("mdeasy reader: browser preview mode");
}
