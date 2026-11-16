/* Two-monitor simulator on top of tree.js. A small JS port of the workspace↔monitor logic:
 *   workspace monitor     → tree/Workspace.swift  workspaceMonitor (forced ?? visible-on ?? last shown ?? main)
 *   stub workspace        → tree/Workspace.swift  getStubWorkspace
 *   summon-workspace      → command/impl/SummonWorkspaceCommand.swift
 *   move-workspace-to-monitor → command/impl/MoveWorkspaceToMonitorCommand.swift
 *   move-node-to-monitor  → command/impl/MoveNodeToMonitorCommand.swift (index 0 if entering from the near side)
 *   focus/move --boundaries all-monitors-outer-frame → FocusCommand.swift / MoveCommand.swift
 *
 * Monitors.mount(el, { workspaces: {"1": "h[1 2]", "2": "", "B": "h[3]"}, visible: ["1", "B"], focus: 0,
 *                      forced: {"B": "secondary"}, persistent: ["1", "2"] })
 * Monitor 0 = main (left), monitor 1 = secondary (right).
 */
(function () {
  const NAMES = ["main", "secondary"];

  class Setup {
    constructor({ workspaces = {}, visible = ["1", "2"], focus = 0, forced = {}, persistent = [] } = {}) {
      this.ws = {};       // name → { tree: Aero.Workspace, last: monitor index | null }
      this.forced = Object.fromEntries(Object.entries(forced).map(([k, v]) => [k, NAMES.indexOf(v)]));
      this.persistent = new Set(persistent);
      this.counter = 0;
      for (const [name, src] of Object.entries(workspaces)) this.get(name).tree = Aero.parse(src || "");
      for (const w of Object.values(this.ws)) for (const win of w.tree.root.windows()) this.counter = Math.max(this.counter, +win.id);
      this.visible = [...visible];
      this.visible.forEach((n, m) => { this.get(n).last = m; });
      this.prevVisible = [null, null];
      this.focusedMon = focus;
      this.log = [];
    }
    get(name) { return (this.ws[name] ??= { tree: Aero.parse(""), last: null }); }
    isEmpty(name) { return this.get(name).tree.root.windows().length === 0; }
    visibleOn(name) { const m = this.visible.indexOf(name); return m < 0 ? null : m; }
    monitorOf(name) { return this.forced[name] ?? this.visibleOn(name) ?? this.get(name).last ?? 0; }
    get focusedWs() { return this.visible[this.focusedMon]; }
    get tree() { return this.get(this.focusedWs).tree; }
    names() { return Object.keys(this.ws).sort((a, b) => a.localeCompare(b, undefined, { numeric: true })); }

    gc() { // empty, invisible, non-persistent workspaces are destroyed (and forget their monitor)
      for (const n of this.names()) if (this.visibleOn(n) == null && this.isEmpty(n) && !this.persistent.has(n)) delete this.ws[n];
    }
    stub(m) {
      const prev = this.prevVisible[m];
      if (prev && this.ws[prev] && this.visibleOn(prev) == null && this.monitorOf(prev) === m && this.forced[prev] == null) return prev;
      const cand = this.names().find((n) => this.visibleOn(n) == null && this.monitorOf(n) === m);
      if (cand) return cand;
      for (let i = 1; ; i++) {
        const n = String(i);
        if (this.isEmpty(n) && this.visibleOn(n) == null && !this.persistent.has(n) && this.forced[n] == null) return n;
      }
    }
    setActive(m, name) {
      if (this.forced[name] != null && this.forced[name] !== m) return false;
      const was = this.visibleOn(name);
      if (was != null) { this.visible[was] = null; this.prevVisible[was] = name; }
      if (this.visible[m] != null) this.prevVisible[m] = this.visible[m];
      this.visible[m] = name; this.get(name).last = m;
      this.visible.forEach((v, i) => { if (v == null) { const s = this.stub(i); this.visible[i] = s; this.get(s).last = i; } });
      this.gc();
      return true;
    }
    done(msg) { this.log.push(msg); this.onchange?.(msg); return this; }

    /* ——— commands ——— */
    workspace(name) {
      const m = this.monitorOf(name);
      if (this.visibleOn(name) == null) this.setActive(m, name);
      this.focusedMon = m;
      return this.done(`workspace ${name}`);
    }
    summon(name) {
      const m = this.focusedMon;
      if (this.visible[m] === name) return this.done(`summon-workspace ${name} (already here)`);
      if (!this.setActive(m, name)) return this.done(`summon-workspace ${name} ✗ force-assigned to ${NAMES[this.forced[name]]}`);
      return this.done(`summon-workspace ${name}`);
    }
    moveWorkspaceToMonitor() { // --wrap-around next
      const name = this.focusedWs, target = 1 - this.focusedMon;
      if (!this.setActive(target, name)) return this.done(`move-workspace-to-monitor ✗ ${name} is force-assigned`);
      this.focusedMon = target;
      return this.done("move-workspace-to-monitor --wrap-around next");
    }
    focusMonitor(dir) { // focus --boundaries all-monitors-outer-frame left|right
      const target = this.focusedMon + (dir === "right" ? 1 : -1);
      const cmd = `focus --boundaries all-monitors-outer-frame ${dir}`;
      const t = this.tree;
      if (t.focused && t.closestParent(t.focused, { orient: "h", off: dir === "right" ? 1 : -1 })) { t.focusDir(dir); return this.done(cmd); }
      if (target < 0 || target > 1) return this.done(cmd + " (stop: outer edge)");
      this.focusedMon = target;
      const tt = this.tree; tt.focus(tt.root.mostRecentWindow);
      return this.done(cmd + " → most recent window there");
    }
    moveNodeToMonitor(dir, { follow = false, label } = {}) { // dir: left|right|next
      const src = this.tree, w = src.focused;
      if (!w) return this.done("no window focused");
      const target = dir === "left" ? this.focusedMon - 1 : dir === "right" ? this.focusedMon + 1 : 1 - this.focusedMon;
      if (target < 0 || target > 1) return this.done(`${label} (stop: outer edge)`);
      const dst = this.get(this.visible[target]).tree;
      const index = dir === "right" && dst.root.orient === "h" ? 0 : -1;
      w.unbind(); src.normalize(); src.focused = src.root.mostRecentWindow; src.focused?.markMru();
      w.bind(dst.root, index); dst.normalize();
      if (follow) { dst.focus(w); this.focusedMon = target; }
      return this.done(label ?? `move-node-to-monitor ${dir}`);
    }
    move(dir) { // move --boundaries all-monitors-outer-frame left|right
      const t = this.tree, w = t.focused, label = `move --boundaries all-monitors-outer-frame ${dir}`;
      if (!w) return this;
      // MoveCommand.swift: sibling in direction → swap/move in; else climb to the first ancestor whose parent is h.
      // Only if the climb reaches the root does the window cross to the other monitor.
      const p = w.parent, i = p.children.indexOf(w) + (dir === "right" ? 1 : -1);
      let inTree = p.orient === "h" && i >= 0 && i < p.children.length;
      for (let n = p; !inTree && n !== t.root; n = n.parent) if (n.parent.orient === "h") inTree = true;
      if (inTree) { t.move(dir); return this.done(label); }
      return this.moveNodeToMonitor(dir, { follow: true, label: label + " → other monitor" });
    }
    newWindow() { const t = this.tree; t.counter = this.counter; t.newWindow(); this.counter = t.counter; this.gc(); return this.done(`open window ${this.counter}`); }
    close() { this.tree.close(); return this.done("close"); }
  }

  function mount(el, opts, { width = 260, height = 150, buttons = ["workspace", "summon", "focus", "move", "node", "wsmove", "new"] } = {}) {
    let s;
    el.classList.add("aero-sim");
    el.innerHTML = `<div class="mon-row"></div><div class="mon-list"></div><div class="aero-controls"></div><div class="aero-log"></div>`;
    const row = el.querySelector(".mon-row"), list = el.querySelector(".mon-list"),
          ctr = el.querySelector(".aero-controls"), log = el.querySelector(".aero-log");
    const draw = (msg) => {
      row.innerHTML = "";
      s.visible.forEach((name, m) => {
        const box = document.createElement("div"); box.className = "mon" + (m === s.focusedMon ? " focused" : "");
        box.innerHTML = `<div class="mon-label">${NAMES[m]} · workspace <b>${name}</b></div><div class="mon-screen"></div>
          <code class="mon-tree">${s.get(name).tree.compact()}</code>`;
        row.appendChild(box);
        const t = s.get(name).tree;
        if (m !== s.focusedMon) { const f = t.focused; t.focused = null; Aero.renderScreen(box.querySelector(".mon-screen"), t, { width, height }); t.focused = f; }
        else Aero.renderScreen(box.querySelector(".mon-screen"), t, { width, height });
        t.onchange = (msg) => { s.focusedMon = m; draw(msg); };
      });
      list.innerHTML = "workspaces: " + s.names().map((n) =>
        `<code title="belongs to ${NAMES[s.monitorOf(n)]}${s.forced[n] != null ? " (forced)" : ""}">${n}${s.visibleOn(n) != null ? "●" : ""}→${s.monitorOf(n) ? "S" : "M"}${s.forced[n] != null ? "!" : ""}</code>`).join(" ")
        + ` <span>(● visible, →M/S monitor it belongs to, ! forced)</span>`;
      if (msg) log.textContent = "› " + msg;
    };
    const reset = () => { s = new Setup(opts); s.onchange = draw; draw("reset"); api.s = s; };
    const api = { reset, get s() { return s; } };
    const group = (items) => { const g = document.createElement("div"); g.className = "aero-group";
      items.forEach(([label, fn]) => { const b = document.createElement("button"); b.innerHTML = label; b.onclick = () => fn(s); g.appendChild(b); });
      ctr.appendChild(g); };
    const wsNames = Object.keys(opts.workspaces || {}).concat(opts.extra || []);
    const sets = {
      workspace: wsNames.map((n) => [`workspace ${n}`, (s) => s.workspace(n)]),
      summon:    wsNames.map((n) => [`summon-workspace ${n}`, (s) => s.summon(n)]),
      focus:     [["focus ← (all monitors)", (s) => s.focusMonitor("left")], ["focus → (all monitors)", (s) => s.focusMonitor("right")]],
      move:      [["move ← (all monitors)", (s) => s.move("left")], ["move → (all monitors)", (s) => s.move("right")]],
      node:      [["move-node-to-monitor next", (s) => s.moveNodeToMonitor("next")],
                  ["… --focus-follows-window", (s) => s.moveNodeToMonitor("next", { follow: true, label: "move-node-to-monitor --focus-follows-window next" })]],
      wsmove:    [["move-workspace-to-monitor next <kbd>alt-shift-tab</kbd>", (s) => s.moveWorkspaceToMonitor()]],
      new:       [["open new window", (s) => s.newWindow()], ["close", (s) => s.close()]],
    };
    buttons.forEach((b) => sets[b] && group(sets[b]));
    const r = document.createElement("button"); r.textContent = "reset"; r.className = "aero-reset"; r.onclick = reset; ctr.appendChild(r);
    reset();
    return api;
  }

  window.Monitors = { Setup, mount };
})();
