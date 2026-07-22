import { renderMarkdown, extractOutlineFromHtml, documentHasMermaid } from "./md.js";
// Static import so esbuild can emit a single IIFE (no dynamic import / ESM chunks).
// Dynamic import() is broken under WKWebView file:// and custom-scheme without module support.
import mermaid from "mermaid";

const $ = (sel) => document.querySelector(sel);

const state = {
  path: null,
  baseDir: null,
  text: "",
  theme: "sepia",
  outlineOpen: true,
  mermaidReady: false,
  printPreparation: null,
  fontSizeScale: 1.0,
  contentMaxWidth: 672,
  findOpen: false,
};

function post(msg) {
  try {
    window.webkit?.messageHandlers?.mdeye?.postMessage(msg);
  } catch (err) {
    console.warn("bridge post failed", err);
  }
}

function setTheme(name) {
  const theme = ["light", "dark", "sepia", "green"].includes(name) ? name : "sepia";
  state.theme = theme;
  document.documentElement.setAttribute("data-theme", theme);
  const select = $("#theme-select");
  if (select) select.value = theme;
  if (state.mermaidReady && document.querySelector(".mermaid, .mermaid-block svg")) {
    renderMermaidBlocks().catch(() => {});
  }
}

function setOutlineOpen(open) {
  state.outlineOpen = open;
  $("#outline")?.classList.toggle("hidden", !open);
}

function clamp(v, lo, hi) {
  return Math.min(hi, Math.max(lo, v));
}

// F1：把屏幕字号/栏宽偏好写到 :root CSS 变量。PDF 打印用 @media print 固定值，不沿用。
function applyPrefsToDom() {
  const html = document.documentElement;
  html.style.setProperty("--font-scale", String(state.fontSizeScale));
  html.style.setProperty("--content-max-width-px", `${state.contentMaxWidth}px`);
}

// F6：阅读器内轻提示浮层（富文本命中、编辑器说明等），3 秒自动消失。
function showToast(message, level = "info") {
  if (!message) return;
  const old = document.querySelector(".mdeye-toast");
  if (old) old.remove();
  const el = document.createElement("div");
  el.className = `mdeye-toast ${level === "warn" ? "warn" : "info"}`;
  el.textContent = message;
  document.body.appendChild(el);
  setTimeout(() => el.remove(), 3000);
}

function basename(path) {
  if (!path) return "MDEye";
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
      if (el) {
        el.scrollIntoView({ behavior: "smooth", block: "start" });
        // The smooth-scroll emits many scroll events; updateActiveOutline ties active
        // to scroll position, so it'll converge — but nudge it now so the clicked
        // entry is reflected immediately rather than a beat later.
        updateActiveOutline();
      }
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

function ensureMermaid() {
  if (state.mermaidReady) return mermaid;
  mermaid.initialize(mermaidConfig());
  window.mermaid = mermaid;
  state.mermaidReady = true;
  return mermaid;
}

// Single source for mermaid init/theme config. theme follows the dark family only in
// the dark theme; light/sepia/green all render with the default (light) mermaid theme.
function mermaidConfig() {
  return {
    startOnLoad: false,
    securityLevel: "strict",
    theme: state.theme === "dark" ? "dark" : "default",
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif",
  };
}

async function renderMermaidBlocks() {
  const nodes = [...document.querySelectorAll(".mermaid-block .mermaid, pre.mermaid")];
  if (!nodes.length) return;

  let m;
  try {
    m = ensureMermaid();
  } catch (err) {
    nodes.forEach((node) => {
      const wrap = node.closest(".mermaid-block") || node;
      wrap.innerHTML = `<div class="mermaid-error">Mermaid failed: ${escapeHtml(String(err?.message || err))}</div>`;
    });
    return;
  }

  // Re-apply theme so a mid-session theme switch re-skins existing diagrams.
  m.initialize(mermaidConfig());

  try {
    await m.run({ nodes, suppressErrors: true });
  } catch (err) {
    console.warn("mermaid.run error", err);
  }
}

async function showDoc({ path, text }) {
  const sameFile = path === state.path;
  state.path = path;
  state.text = text ?? "";
  state.printPreparation = null;
  const title = basename(path);
  const titleEl = $("#doc-title");
  if (titleEl) titleEl.textContent = title;
  document.title = `${title} · MDEye`;

  const html = renderMarkdown(state.text);
  const content = $("#content");
  if (!content) return;
  content.classList.remove("empty");
  content.innerHTML = html;
  // Machine-readable marker for automated smoke tests (and debugging).
  content.setAttribute("data-mdeye-path", path || "");
  content.setAttribute("data-mdeye-rendered", "1");
  content.setAttribute("data-mdeye-chars", String((text || "").length));
  const outline = extractOutlineFromHtml(html);
  renderOutline(outline);
  // Preserve scroll position when the same file is refreshed on disk (external save),
  // reset to top only when opening a different file.
  if (!sameFile) content.scrollTop = 0;
  requestAnimationFrame(updateActiveOutline);

  if (documentHasMermaid(state.text) || content.querySelector(".mermaid")) {
    await renderMermaidBlocks();
  }

  post({
    type: "doc-shown",
    path: path || "",
    chars: (text || "").length,
    hasMermaid: documentHasMermaid(text || ""),
    hasMath: !!content.querySelector(".katex"),
  });
}

async function preparePrint() {
  if (state.printPreparation) return state.printPreparation;

  state.printPreparation = (async () => {
    if (document.fonts?.ready) {
      await Promise.race([document.fonts.ready, delay(2000)]);
    }

    const images = [...document.images];
    await Promise.all(
      images.map(async (img) => {
        if (!img.complete) {
          await Promise.race([
            new Promise((resolve) => {
              img.addEventListener("load", resolve, { once: true });
              img.addEventListener("error", resolve, { once: true });
            }),
            delay(5000),
          ]);
        }
        if (typeof img.decode === "function") {
          await Promise.race([img.decode().catch(() => {}), delay(5000)]);
        }
      })
    );

    await waitForLayoutFrame();
    await waitForLayoutFrame();
    post({ type: "print-ready" });
  })().catch((err) => {
    state.printPreparation = null;
    post({ type: "error", message: `Print preparation failed: ${String(err?.message || err)}` });
  });

  return state.printPreparation;
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function waitForLayoutFrame() {
  return new Promise((resolve) => {
    let settled = false;
    const finish = () => {
      if (settled) return;
      settled = true;
      resolve();
    };
    requestAnimationFrame(finish);
    // Offscreen WKWebViews can suspend animation frames; a timer still lets WebKit
    // flush style and layout before printing in headless CI and background exports.
    setTimeout(finish, 100);
  });
}

function showEmpty() {
  state.path = null;
  state.text = "";
  const titleEl = $("#doc-title");
  if (titleEl) titleEl.textContent = "MDEye";
  document.title = "MDEye";
  const content = $("#content");
  if (!content) return;
  content.classList.add("empty");
  content.innerHTML = `<div class="empty-state"><h1>MDEye</h1><p>Open a Markdown file to start reading.</p><p class="hint">⌘O open · drag & drop · double-click .md<br/>Menu: MDEye → Set as Default Markdown App</p></div>`;
  renderOutline([]);
}

function handleNativeEvent(msg) {
  if (!msg || typeof msg !== "object") return;
  try {
    switch (msg.type) {
      case "doc":
        state.baseDir = msg.baseDir;
        console.info("mdeye: doc received", msg.path, "chars=", (msg.text || "").length);
        showDoc({ path: msg.path, text: msg.text });
        break;
      case "file-changed":
        showDoc({ path: msg.path || state.path, text: msg.text });
        break;
      case "theme":
        setTheme(msg.name);
        break;
      case "toggle-outline":
        toggleOutline();
        break;
      case "prepare-print":
        preparePrint();
        break;
      case "apply-prefs":
        // F1：屏幕字号/栏宽偏好（number 进 JS 后 typeof 判断即可）。
        if (typeof msg.fontSizeScale === "number") {
          state.fontSizeScale = clamp(msg.fontSizeScale, 0.85, 2.0);
        }
        if (typeof msg.contentMaxWidth === "number") {
          state.contentMaxWidth = clamp(msg.contentMaxWidth | 0, 600, 1100);
        }
        applyPrefsToDom();
        break;
      case "toast":
        // F6：纯文本轻提示。
        showToast(msg.message || "", msg.level || "info");
        break;
      case "ping":
        post({ type: "pong", version: window.__mdeyeVersion || "unknown" });
        break;
      default:
        break;
    }
  } catch (err) {
    console.error("mdeye: handle failed", err);
    post({ type: "error", message: String(err?.message || err) });
  }
}

function toggleOutline() {
  setOutlineOpen(!state.outlineOpen);
  post({ type: "set-preference", key: "outlineOpen", value: state.outlineOpen });
}

function bindUi() {
  $("#btn-outline")?.addEventListener("click", toggleOutline);
  $("#btn-export-pdf")?.addEventListener("click", () => {
    post({ type: "export-pdf" });
  });

  $("#theme-select")?.addEventListener("change", (e) => {
    const name = e.target.value;
    setTheme(name);
    post({ type: "set-preference", key: "theme", value: name });
  });

  $("#content")?.addEventListener("scroll", () => {
    updateActiveOutline();
  });

  // 正文链接点击委托：只截"同类 .md 相对链接"，交给原生在当前文档 baseDir 树内解析打开。
  // 页内锚点(#id)与绝对外链(http(s)/mailto/tel/data)放行系统默认；非 md 相对链接不拦以防误吞示例。
  $("#content")?.addEventListener("click", (e) => {
    const a = e.target?.closest?.("a[href]");
    if (!a) return;
    const href = a.getAttribute("href") || "";
    if (href.startsWith("#")) return;
    if (/^(https?:|mailto:|tel:|data:)/i.test(href)) return;
    if (/^\.md$|(?:^|\/|\.)(?:md|markdown|mdx|mdown|mkd|mkdn|mdwn)$/i.test(href)) {
      e.preventDefault();
      post({ type: "open-md-link", href });
    }
  });

  document.addEventListener("keydown", (e) => {
    const meta = e.metaKey || e.ctrlKey;
    if (meta && e.key.toLowerCase() === "b") {
      e.preventDefault();
      toggleOutline();
    }
  });

  // F5：文内查找（纯 JS TreeWalker 高亮，不碰桥接）。
  setupFindBar();
}

// F5：查找条。纯 JS TreeWalker 高亮，不碰桥接。
function setupFindBar() {
  const bar = document.createElement("div");
  bar.id = "find-bar";
  bar.className = "find-bar hidden";
  bar.innerHTML = `
    <input id="find-input" type="text" placeholder="查找…" autocomplete="off" />
    <button id="find-prev" title="上一个 (⇧⌘G)">▲</button>
    <button id="find-next" title="下一个 (⌘G)">▼</button>
    <label class="find-case"><input type="checkbox" id="find-case" /> 大小写</label>
    <button id="find-close" title="关闭 (esc)">✕</button>
  `;
  document.body.appendChild(bar);

  const input = bar.querySelector("#find-input");
  const caseCb = bar.querySelector("#find-case");
  let matches = [];
  let idx = -1;

  function clearMarks() {
    document.querySelectorAll("mark.mdeye-find").forEach((m) => {
      const parent = m.parentNode;
      parent.replaceChild(document.createTextNode(m.textContent), m);
      parent.normalize?.();
    });
    matches = [];
    idx = -1;
  }

  function search(query) {
    clearMarks();
    if (!query) return;
    const root = document.getElementById("content");
    if (!root) return;
    const flags = caseCb.checked ? "g" : "gi";
    const re = new RegExp(query.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), flags);
    // 仅在文本节点遍历，避免拆坏 KaTeX/mermaid/代码块既有 DOM。
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
      acceptNode(n) {
        if (!n.nodeValue.trim()) return NodeFilter.FILTER_REJECT;
        const p = n.parentElement;
        if (p && p.closest("script, style, mark.mdeye-find")) {
          return NodeFilter.FILTER_REJECT;
        }
        return NodeFilter.FILTER_ACCEPT;
      },
    });
    const nodes = [];
    while (walker.nextNode()) nodes.push(walker.currentNode);
    for (const tn of nodes) {
      const text = tn.nodeValue;
      let last = 0;
      let m;
      const frag = document.createDocumentFragment();
      while ((m = re.exec(text))) {
        if (m.index > last) {
          frag.appendChild(document.createTextNode(text.slice(last, m.index)));
        }
        const mk = document.createElement("mark");
        mk.className = "mdeye-find";
        mk.textContent = m[0];
        frag.appendChild(mk);
        matches.push(mk);
        last = m.index + m[0].length;
        if (m.index === re.lastIndex) re.lastIndex++; // 防零宽死循环
      }
      if (last) {
        frag.appendChild(document.createTextNode(text.slice(last)));
        tn.parentNode.replaceChild(frag, tn);
      }
    }
    idx = matches.length ? 0 : -1;
    highlightCurrent();
  }

  function highlightCurrent() {
    matches.forEach((m, i) => m.classList.toggle("current", i === idx));
    if (matches[idx]) {
      matches[idx].scrollIntoView({ block: "center", behavior: "smooth" });
    }
  }

  function next() {
    if (!matches.length) return;
    idx = (idx + 1) % matches.length;
    highlightCurrent();
  }

  function prev() {
    if (!matches.length) return;
    idx = (idx - 1 + matches.length) % matches.length;
    highlightCurrent();
  }

  function openFindBar() {
    state.findOpen = true;
    bar.classList.remove("hidden");
    input.focus();
    input.select();
  }

  function closeFindBar() {
    state.findOpen = false;
    bar.classList.add("hidden");
    clearMarks();
    input.value = "";
  }

  bar.querySelector("#find-next").addEventListener("click", next);
  bar.querySelector("#find-prev").addEventListener("click", prev);
  bar.querySelector("#find-close").addEventListener("click", closeFindBar);
  input.addEventListener("input", () => search(input.value));
  caseCb.addEventListener("change", () => search(input.value));

  document.addEventListener("keydown", (e) => {
    // 查找条打开时输入框优先处理 Esc；否则全局 ⌘F 唤起。
    if (state.findOpen && e.key === "Escape") {
      e.preventDefault();
      closeFindBar();
      return;
    }
    const meta = e.metaKey || e.ctrlKey;
    if (!meta) return;
    const k = e.key.toLowerCase();
    if (k === "f") {
      e.preventDefault();
      openFindBar();
    } else if (state.findOpen && k === "g") {
      e.preventDefault();
      if (e.shiftKey) prev();
      else next();
    }
  });
}

window.__mdeye = {
  handle: handleNativeEvent,
};
// Injected at build time from App/Info.plist via esbuild `define`. Keeps the JS
// "ready" version in sync with the native app version (single source of truth).
window.__mdeyeVersion = __MDEYE_VERSION__;

bindUi();
setTheme("sepia");
applyPrefsToDom();
showEmpty();
post({ type: "ready", version: window.__mdeyeVersion });
setTimeout(() => post({ type: "ready", version: window.__mdeyeVersion }), 50);

// Browser-only preview (no native bridge)
if (!window.webkit?.messageHandlers?.mdeye) {
  const demo = `# MDEye preview

Browser preview of the **IIFE** full pack.

## Features

- GFM tables
- Task lists
- Mermaid (bundled)

\`\`\`js
console.log("hello mdeye");
\`\`\`

| A | B |
| - | - |
| 1 | 2 |

\`\`\`mermaid
graph LR
  A[Open .md] --> B[Render]
  B --> C[Read]
\`\`\`
`;
  showDoc({ path: "preview.md", text: demo });
  console.info("mdeye reader: browser preview mode");
}
