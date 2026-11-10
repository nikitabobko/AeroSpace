/* AeroSpace tree simulator. A small JS port of AeroSpace's tree logic, used by docs/tutorial.adoc.
 * Keep in sync with (Sources/AppBundle/):
 *   new window  → tree/MacWindow.swift  unbindAndGetBindingDataForNewTilingWindow
 *   focus dir   → command/impl/FocusCommand.swift  closestParent + findLeafWindowRecursive
 *   move        → command/impl/MoveCommand.swift
 *   join-with   → command/impl/JoinWithCommand.swift
 *   normalize   → tree/normalizeContainers.swift (flatten + opposite orientation)
 *
 * Usage:
 *   const ws = Aero.parse("h[1 v[2 3]]", {focus: 2});   // h/v = tiles, H/V = accordion
 *   ws.newWindow(); ws.move("left"); ws.joinWith("right"); ws.focusDir("up"); ws.toString();
 *   Aero.mount(el, ws, {controls: ["new","focus","move","join","layout","flatten","reset"]});
 */
(function () {
  const COLORS = ["#e5484d", "#3e63dd", "#30a46c", "#f76b15", "#8e4ec6", "#12a594",
                  "#d6409f", "#e2a336", "#5b5bd6", "#a18072", "#3fb7a8", "#8b8d98"];
  const DIR = {
    left:  { orient: "h", off: -1, ins: 0, pos: false },
    right: { orient: "h", off: +1, ins: 1, pos: true },
    up:    { orient: "v", off: -1, ins: 0, pos: false },
    down:  { orient: "v", off: +1, ins: 1, pos: true },
  };
  const opposite = (o) => (o === "h" ? "v" : "h");

  class Node {
    constructor(kind, props = {}) {
      this.kind = kind; // "w" | "c"
      this.parent = null;
      this.children = [];
      this.mru = []; // most recent last
      Object.assign(this, props);
    }
    get isWindow() { return this.kind === "w"; }
    get index() { return this.parent ? this.parent.children.indexOf(this) : -1; }
    get mostRecentChild() { return this.mru[this.mru.length - 1] || this.children[this.children.length - 1] || null; }
    get mostRecentWindow() { return this.isWindow ? this : this.mostRecentChild?.mostRecentWindow || null; }
    unbind() {
      const p = this.parent;
      if (!p) return null;
      const index = p.children.indexOf(this);
      p.children.splice(index, 1);
      p.mru = p.mru.filter((n) => n !== this);
      this.parent = null;
      return { parent: p, index };
    }
    bind(parent, index) {
      this.unbind();
      if (index < 0 || index > parent.children.length) index = parent.children.length;
      parent.children.splice(index, 0, this);
      this.parent = parent;
      this.markMru();
    }
    markMru() {
      let n = this;
      while (n.parent) {
        n.parent.mru = n.parent.mru.filter((x) => x !== n);
        n.parent.mru.push(n);
        n = n.parent;
      }
    }
    windows() { return this.isWindow ? [this] : this.children.flatMap((c) => c.windows()); }
  }

  const container = (orient, layout = "tiles") => new Node("c", { orient, layout });

  class Workspace {
    constructor() {
      this.root = container("h");
      this.focused = null;
      this.counter = 0;
      this.log = [];
    }
    window(label) {
      this.counter = Math.max(this.counter, Number(label) || this.counter + 1);
      const id = label ?? String(this.counter);
      return new Node("w", { id: String(id), color: COLORS[(Number(id) - 1 + COLORS.length) % COLORS.length] || COLORS[0] });
    }
    focus(win) { if (win) { this.focused = win; win.markMru(); } return this; }
    find(id) { return this.root.windows().find((w) => w.id === String(id)); }
    get isRootParent() { return this.focused?.parent === this.root; }

    /* ——— commands ——— */
    newWindow() {
      const w = this.window(String(this.counter + 1));
      const mruWin = this.root.mostRecentWindow;
      if (mruWin && mruWin.parent) w.bind(mruWin.parent, mruWin.index + 1);
      else w.bind(this.root, -1);
      this.focus(w);
      this.normalize();
      return this.done(`open window ${w.id}`);
    }

    close() {
      const w = this.focused; if (!w) return this;
      w.unbind(); this.normalize();
      this.focused = this.root.mostRecentWindow; this.focused?.markMru();
      return this.done(`close ${w.id}`);
    }

    closestParent(node, d) {
      for (let n = node; n.parent; n = n.parent) {
        const p = n.parent;
        const i = p.children.indexOf(n) + d.off;
        if (p.orient === d.orient && i >= 0 && i < p.children.length) return { parent: p, index: p.children.indexOf(n) };
      }
      return null;
    }

    focusDir(dir) {
      const d = DIR[dir], w = this.focused; if (!w) return this;
      const cp = this.closestParent(w, d);
      if (!cp) return this.done(`focus ${dir} (edge — nothing)`);
      const snap = (n) => {
        if (n.isWindow) return n;
        if (n.orient === d.orient) return snap(d.pos ? n.children[0] : n.children[n.children.length - 1]);
        return snap(n.mostRecentChild);
      };
      this.focus(snap(cp.parent.children[cp.index + d.off]));
      return this.done(`focus ${dir}`);
    }

    move(dir) {
      const d = DIR[dir], w = this.focused; if (!w) return this;
      const parent = w.parent, i = w.index, t = i + d.off;
      if (parent.orient === d.orient && t >= 0 && t < parent.children.length) {
        const sib = parent.children[t];
        if (sib.isWindow) { w.bind(parent, t); }
        else { // deep move in
          const deep = (n) => n.isWindow ? n : n.orient === d.orient ? n : deep(n.mostRecentChild);
          const target = deep(sib);
          if (target.isWindow) { const p = target.parent, ti = target.index; w.unbind(); w.bind(p, p.children.indexOf(target) + 1); }
          else w.bind(target, 0);
        }
      } else { // move out: first ancestor container whose parent has the move orientation (or the root)
        let c = w.parent;
        while (c !== this.root && c.parent.orient !== d.orient) c = c.parent;
        if (c !== this.root) {
          const gp = c.parent;
          w.unbind();
          w.bind(gp, gp.children.indexOf(c) + d.ins);
        } else { // workspace boundary → implicit container (MoveCommand.createImplicitContainerAndMoveWindow)
          const prev = this.root;
          this.root = container(d.orient, "tiles");
          prev.bind(this.root, 0);
          w.bind(this.root, d.ins);
        }
      }
      this.focus(w); this.normalize();
      return this.done(`move ${dir}`);
    }

    joinWith(dir) {
      const d = DIR[dir], w = this.focused; if (!w) return this;
      const cp = this.closestParent(w, d);
      if (!cp) return this.done(`join-with ${dir} (no window there)`);
      const parent = cp.parent, target = parent.children[cp.index + d.off];
      const prev = target.unbind();
      const np = container(opposite(parent.orient), "tiles");
      np.bind(parent, prev.index);
      w.unbind();
      target.bind(np, 0);
      w.bind(np, d.pos ? 0 : -1);
      this.focus(w); this.normalize();
      return this.done(`join-with ${dir}`);
    }

    layout(...args) { // e.g. layout("tiles","horizontal","vertical") — first non-current wins
      const c = this.focused?.parent || this.root;
      const cur = { tiles: c.layout === "tiles", accordion: c.layout === "accordion",
                    horizontal: c.orient === "h", vertical: c.orient === "v" };
      const combo = { h_tiles: ["tiles", "h"], v_tiles: ["tiles", "v"], h_accordion: ["accordion", "h"], v_accordion: ["accordion", "v"] };
      // changeOrientation (TilingContainer.swift): with normalization on, self + all ancestors alternate
      const setOrient = (o) => { if (c.orient === o) return; for (let n = c; n; n = n.parent) { n.orient = o; o = opposite(o); } };
      for (const a of args) {
        if (combo[a]) { const [l, o] = combo[a]; if (c.layout !== l || c.orient !== o) { c.layout = l; setOrient(o); break; } continue; }
        if (cur[a]) continue;
        if (a === "tiles" || a === "accordion") c.layout = a; else setOrient(a === "horizontal" ? "h" : "v");
        break;
      }
      this.normalize(c);
      return this.done(`layout ${args.join(" ")}`);
    }

    flatten() {
      const ws = this.root.windows();
      const f = this.focused;
      this.root = container(this.root.orient, this.root.layout);
      ws.forEach((w) => { w.parent = null; w.mru = []; w.bind(this.root, -1); });
      this.focus(f);
      return this.done("flatten-workspace-tree");
    }

    /* ——— normalization ——— */
    normalize(changed) {
      const flatten = (c) => {
        if (c.children.length === 1 && (!c.isWindow) && (c.children[0].kind === "c" || c !== this.root)) {
          const child = c.children[0];
          if (c === this.root) { child.unbind(); this.root = child; child.parent = null; return flatten(child); }
          const p = c.parent, i = c.index, mru = p.mostRecentChild;
          child.unbind(); c.unbind(); child.bind(p, i);
          if (mru !== c) mru?.markMru();
          if (!child.isWindow) flatten(child);
          return;
        }
        [...c.children].forEach((ch) => !ch.isWindow && flatten(ch));
        if (c.children.length === 0 && c !== this.root) c.unbind();
      };
      flatten(this.root);
      const orient = (c) => {
        if (c.parent && c.parent.orient === c.orient) c.orient = opposite(c.orient);
        c.children.forEach((ch) => !ch.isWindow && orient(ch));
      };
      orient(this.root);
      if (this.focused) this.focused.markMru();
    }

    done(msg) { this.log.push(msg); this.onchange?.(msg); return this; }

    /* ——— text ——— */
    toString() {
      const name = (c) => `${c.orient}_${c.layout}`;
      const lines = [];
      const walk = (n, prefix, last, isRoot) => {
        const label = n.isWindow ? `window ${n.id}${n === this.focused ? " (focused)" : ""}` : name(n) + (isRoot ? " (root)" : "");
        lines.push(isRoot ? label : prefix + (last ? "└── " : "├── ") + label);
        if (!n.isWindow) n.children.forEach((c, i) =>
          walk(c, isRoot ? "" : prefix + (last ? "    " : "│   "), i === n.children.length - 1, false));
      };
      walk(this.root, "", true, true);
      return lines.join("\n");
    }
    compact(n = this.root) { // "h[1 v[2 3]]"
      if (n.isWindow) return n.id;
      const t = n.layout === "tiles" ? n.orient : n.orient.toUpperCase();
      return `${t}[${n.children.map((c) => this.compact(c)).join(" ")}]`;
    }
    clone() { const ws = Aero.parse(this.compact(), { focus: this.focused?.id }); return ws; }
  }

  /* ——— parsing: "h[1 v[2 3]]"  h/v = tiles, H/V = accordion ——— */
  function parse(src, { focus } = {}) {
    const ws = new Workspace();
    const toks = src.match(/[hvHV]\[|\]|\d+/g) || [];
    let i = 0;
    const node = () => {
      const t = toks[i++];
      if (/^\d+$/.test(t)) return ws.window(t);
      const c = container(t[0].toLowerCase(), t[0] === t[0].toUpperCase() ? "accordion" : "tiles");
      while (toks[i] !== "]") { const ch = node(); ch.bind(c, -1); }
      i++; c.mru = [];
      return c;
    };
    ws.root = toks.length ? node() : container("h");
    ws.root.parent = null;
    const all = ws.root.windows();
    // MRU default: document order, so the last window is most recent; then the focused one
    all.forEach((w) => w.markMru());
    ws.focus(focus != null ? ws.find(focus) : all[all.length - 1]);
    ws.normalize();
    return ws;
  }

  /* ——— rendering ——— */
  const PAD = 14; // accordion padding (px, scaled)
  function rects(n, x, y, w, h, out, ws) {
    if (n.isWindow) { out.push({ n, x, y, w, h }); return; }
    const k = n.children.length;
    if (n.layout === "accordion") {
      const mr = n.mostRecentChild;
      n.children.forEach((c, i) => {
        const before = i < n.children.indexOf(mr), after = i > n.children.indexOf(mr);
        if (c !== mr) return;
        const padA = n.children.indexOf(mr) > 0 ? PAD : 0, padB = n.children.indexOf(mr) < k - 1 ? PAD : 0;
        if (n.orient === "h") rects(c, x + padA, y, w - padA - padB, h, out, ws);
        else rects(c, x, y + padA, w, h - padA - padB, out, ws);
      });
      // ghost edges for hidden siblings
      n.children.forEach((c, i) => {
        if (c === mr) return;
        const mi = n.children.indexOf(mr);
        const g = i < mi ? (n.orient === "h" ? { x, y, w: PAD, h } : { x, y, w, h: PAD })
                         : (n.orient === "h" ? { x: x + w - PAD, y, w: PAD, h } : { x, y: y + h - PAD, w, h: PAD });
        out.unshift({ n: c.mostRecentWindow, ...g, ghost: true });
      });
      return;
    }
    let off = 0;
    n.children.forEach((c) => {
      if (n.orient === "h") { const cw = w / k; rects(c, x + off, y, cw, h, out, ws); off += cw; }
      else { const ch = h / k; rects(c, x, y + off, w, ch, out, ws); off += ch; }
    });
  }

  function renderScreen(el, ws, { width = 480, height = 280 } = {}) {
    const out = []; rects(ws.root, 0, 0, width, height, out, ws);
    el.innerHTML = "";
    el.classList.add("aero-screen");
    el.style.width = width + "px"; el.style.height = height + "px";
    out.forEach(({ n, x, y, w, h, ghost }) => {
      const d = document.createElement("div");
      d.className = "aero-win" + (n === ws.focused ? " focused" : "") + (ghost ? " ghost" : "");
      Object.assign(d.style, { left: x + "px", top: y + "px", width: w + "px", height: h + "px", background: n.color });
      if (!ghost) d.textContent = n.id;
      d.title = ghost ? `window ${n.id} (hidden in accordion)` : `window ${n.id} — click to focus`;
      d.onclick = () => { ws.focus(n); ws.done(`focus window ${n.id} (click)`); };
      el.appendChild(d);
    });
  }

  function renderTree(el, ws) {
    el.classList.add("aero-tree");
    el.textContent = ws.toString();
  }

  /* ——— interactive widget ——— */
  const CONTROL_SETS = {
    new:     [["open new window", (ws) => ws.newWindow(), "n"]],
    focus:   ["left", "down", "up", "right"].map((d) => [`focus ${d}`, (ws) => ws.focusDir(d), { left: "h", down: "j", up: "k", right: "l" }[d]]),
    move:    ["left", "down", "up", "right"].map((d) => [`move ${d}`, (ws) => ws.move(d), { left: "H", down: "J", up: "K", right: "L" }[d]]),
    join:    ["left", "down", "up", "right"].map((d) => [`join-with ${d}`, (ws) => ws.joinWith(d), null]),
    layout:  [["layout tiles horizontal vertical", (ws) => ws.layout("tiles", "horizontal", "vertical"), "/"],
              ["layout accordion horizontal vertical", (ws) => ws.layout("accordion", "horizontal", "vertical"), ","]],
    close:   [["close", (ws) => ws.close(), "x"]],
    flatten: [["flatten-workspace-tree", (ws) => ws.flatten(), null]],
  };

  function mount(el, initial, { controls = ["new", "focus", "move", "join", "layout", "close", "flatten"], width, height, keys = true } = {}) {
    const start = typeof initial === "string" ? initial : initial.compact();
    const startFocus = typeof initial === "string" ? undefined : initial.focused?.id;
    let ws;
    el.classList.add("aero-sim");
    el.innerHTML = `<div class="aero-row"><div class="aero-screen-wrap"></div><pre class="aero-tree"></pre></div>
      <div class="aero-controls"></div><div class="aero-log"></div>`;
    const screen = el.querySelector(".aero-screen-wrap"), tree = el.querySelector(".aero-tree"),
          ctr = el.querySelector(".aero-controls"), log = el.querySelector(".aero-log");
    const draw = (msg) => { renderScreen(screen, ws, { width, height }); renderTree(tree, ws); if (msg) log.textContent = "› " + msg; };
    const reset = () => { ws = parse(start, { focus: startFocus }); ws.onchange = draw; draw("reset"); api.ws = ws; };
    const api = { el, reset, get ws() { return ws; }, set ws(v) { ws = v; } };
    const bindings = [];
    controls.forEach((set) => {
      const group = document.createElement("div"); group.className = "aero-group";
      (CONTROL_SETS[set] || []).forEach(([label, fn, key]) => {
        const b = document.createElement("button");
        b.innerHTML = label + (key ? ` <kbd>${key}</kbd>` : "");
        b.onclick = () => fn(ws);
        group.appendChild(b);
        if (key) bindings.push([key, fn]);
      });
      ctr.appendChild(group);
    });
    const r = document.createElement("button"); r.textContent = "reset"; r.className = "aero-reset"; r.onclick = reset; ctr.appendChild(r);
    if (keys) {
      el.tabIndex = 0;
      el.addEventListener("keydown", (e) => {
        const hit = bindings.find(([k]) => k === e.key);
        if (hit) { e.preventDefault(); hit[1](ws); }
      });
    }
    reset();
    return api;
  }

  window.Aero = { parse, mount, renderScreen, renderTree, Workspace };
})();
