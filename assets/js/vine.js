/* ==========================================================================
   Signature: „Der Garten wächst durch die Website“
   Eine feine Ranke zeichnet sich beim Scrollen Stück für Stück weiter.
   – Route relativ zu Layout-Elementen → passt sich jeder Breite an
   – zwei Ebenen: hinter Bildern (Standard) und davor ([data-vine-front])
   – Stop-Motion: Wachstum in kleinen Stufen mit ~14 fps statt butterweich
   – Desktop ab 1024 px; mobil entfällt sie (lokale Linie im Ablauf bleibt)
   – prefers-reduced-motion: Ranke steht fertig gezeichnet, ohne Bewegung
   ========================================================================== */
(() => {
  'use strict';

  const host = document.querySelector('[data-vine-root]');
  if (!host || !('IntersectionObserver' in window)) return;

  const NS = 'http://www.w3.org/2000/svg';
  const mqDesktop = window.matchMedia('(min-width: 1024px)');
  const mqReduce = window.matchMedia('(prefers-reduced-motion: reduce)');
  const debugFull = /[?&]vine=full\b/.test(location.search);

  const STEP_PX = 9;          // Länge einer „Zeichenstufe“
  const FRAME_MS = 70;        // ≈ 14 Bilder pro Sekunde
  const TIP_AT = 0.68;        // Spitze der Ranke bei 68 % der Fensterhöhe

  /* ── Route ──────────────────────────────────────────────────────────────
     x/y: Anteil der Element-Box (0…1, auch darüber hinaus)
     x: 'L' / 'R' = Mitte des linken/rechten Seitenrands
     leaf: 'l' | 'r' (links/rechts der Wuchsrichtung), 'lr' = Blattpaar
     calm: in diesem Abschnitt keine Blätter, kaum Schwung (Grabpflege)    */
  const ROUTE = [
    { el: '[data-vine-seed]', x: 0.5, y: 0.5 },
    { el: '.trust', x: 'L', y: 0.1 },
    { el: '.trust', x: 'L', y: 0.62, leaf: 'l' },
    { el: '#services-title', x: 'L', y: 0.2, leaf: 'r', size: 0.8 },
    { el: '#heckenschnitt .feature__media', x: 0.1, y: 0.1 },
    { el: '#heckenschnitt .feature__media', x: 0.5, y: 0.62 },
    { el: '#heckenschnitt .feature__media', x: 0.86, y: 1.07, leaf: 'r' },
    { el: '#rasenpflege .feature__media', x: 0.09, y: 0.14, leaf: 'l' },
    { el: '#rasenpflege .feature__media', x: 0.2, y: 0.78 },
    { el: '#rasenpflege .feature__media', x: 0.06, y: 1.1, leaf: 'lr', size: 0.9 },
    { el: '#straeucher .service__media', x: 0.62, y: 0.16, branch: 'services' },
    { el: '#straeucher .service__media', x: 0.2, y: 0.74 },
    { el: '#straeucher .service__media', x: -0.06, y: 0.97, leaf: 'l', size: 0.8 },
    { el: '#straeucher', x: -0.065, y: 0.78 },
    { el: '#straeucher', x: -0.02, y: 1.08 },
    { el: '.services__more', x: 0.5, y: -0.6 },
    { el: '.services__more', x: 0.53, y: 1.7, leaf: 'r' },
    { el: '.about__media', x: 0.96, y: 0.22 },
    { el: '.about__media', x: 0.62, y: 0.7 },
    { el: '.about__media', x: 0.86, y: 1.06, leaf: 'r' },
    { el: '.work .section-head', x: 0.5, y: 0.45, leaf: 'l', size: 0.85 },
    { el: '.compare', x: 0.58, y: 0.08 },
    { el: '.compare', x: 0.36, y: 0.88 },
    { el: '.compare', x: 0.18, y: 1.08, leaf: 'l' },
    { el: '.process .section-head', x: 'L', y: 0.55 },
    { el: '[data-vine-step]', idx: 0, x: 0.5, y: 0.5 },
    { el: '[data-vine-step]', idx: 1, x: 0.5, y: 0.5, leaf: 'lr', size: 0.75, mid: true },
    { el: '[data-vine-step]', idx: 2, x: 0.5, y: 0.5, leaf: 'lr', size: 0.75, mid: true },
    { el: '[data-vine-step]', idx: 3, x: 0.5, y: 0.5, leaf: 'lr', size: 0.75, mid: true },
    { el: '.steps', x: 'R', y: 0.55, leaf: 'r', size: 0.8 },
    { el: '.process__cta', x: 'R', y: 0.5 },
    { el: '.grave', x: 'R', y: 0.2, calm: true },
    { el: '.grave', x: 'R', y: 0.85, calm: true },
    { el: '.reviews', x: 'R', y: 0.45, leaf: 'l' },
    { el: '.area', x: 'R', y: 0.3 },
    { el: '.area', x: 'R', y: 0.78, leaf: 'l', size: 0.9 },
    { el: '.faq', x: 'R', y: 0.35 },
    { el: '.faq', x: 'R', y: 0.9, leaf: 'l' },
    { el: '.contact', x: 'R', y: 0.03 },
    { el: '.contact__panel', x: 0.55, y: -0.07, leaf: 'r', size: 0.8 },
    { el: '.contact__panel', x: -0.035, y: -0.02, end: true },
  ];

  // Seitenzweig im Leistungsbereich
  const BRANCHES = {
    services: [
      { el: '#straeucher .service__media', x: 0.62, y: 0.16 },
      { el: '#straeucher .service__media', x: 1.03, y: 0.02 },
      { el: '#gartenpflege .service__media', x: -0.04, y: -0.05, leaf: 'l', size: 0.8 },
      { el: '#gartenpflege .service__media', x: 0.22, y: -0.09, end: true, small: true },
    ],
  };

  /* ── Hilfen ─────────────────────────────────────────────────────────── */
  const rnd = (() => { let s = 7; return () => ((s = (s * 16807) % 2147483647) / 2147483647); })();
  const el = (name, attrs = {}) => {
    const n = document.createElementNS(NS, name);
    for (const k in attrs) n.setAttribute(k, attrs[k]);
    return n;
  };
  const f1 = (v) => Math.round(v * 10) / 10;

  // Layout-Position ohne Transforms (Einblend-Animationen verfälschen sonst die Route)
  function docRect(node) {
    let x = 0, y = 0, n = node;
    while (n) { x += n.offsetLeft; y += n.offsetTop; n = n.offsetParent; }
    return { x, y, w: node.offsetWidth, h: node.offsetHeight };
  }

  function margins() {
    const c = document.querySelector('.container');
    const r = c.getBoundingClientRect();
    const pad = parseFloat(getComputedStyle(c).paddingLeft) || 0;
    const left = r.left + pad;
    const right = r.right - pad;
    return { L: left / 2, R: right + (document.documentElement.clientWidth - right) / 2 };
  }

  function resolve(points, m) {
    const out = [];
    for (const p of points) {
      const list = document.querySelectorAll(p.el);
      const node = list[p.idx || 0];
      if (!node) continue;
      const r = docRect(node);
      if (!r.w && !r.h) continue;
      const x = p.x === 'L' ? m.L : p.x === 'R' ? m.R : r.x + r.w * p.x;
      const y = r.y + r.h * p.y;
      out.push({ ...p, px: x, py: y });
    }
    return out;
  }

  // Lange Strecken leicht organisch auflockern (gezeichnet, nicht konstruiert)
  function wobble(pts) {
    const out = [pts[0]];
    for (let i = 1; i < pts.length; i++) {
      const a = out[out.length - 1], b = pts[i];
      const dx = b.px - a.px, dy = b.py - a.py;
      const d = Math.hypot(dx, dy);
      const n = Math.floor(d / 230);
      const amp = (b.calm || a.calm) ? 3 : Math.min(15, 6 + d / 160);
      for (let k = 1; k <= n; k++) {
        const t = k / (n + 1);
        const off = Math.sin(t * Math.PI * (n + 1) + i) * amp * (0.7 + rnd() * 0.6);
        out.push({ px: a.px + dx * t + (-dy / d) * off, py: a.py + dy * t + (dx / d) * off, wob: true, calm: b.calm });
      }
      out.push(b);
    }
    return out;
  }

  // Zentripetale Catmull-Rom → kubische Béziers (keine Schlaufen)
  function toBeziers(pts) {
    const segs = [];
    const P = (i) => pts[Math.max(0, Math.min(pts.length - 1, i))];
    for (let i = 0; i < pts.length - 1; i++) {
      const p0 = P(i - 1), p1 = P(i), p2 = P(i + 1), p3 = P(i + 2);
      const d = (a, b) => Math.pow(Math.hypot(b.px - a.px, b.py - a.py), 0.5) || 1e-4;
      const t01 = d(p0, p1), t12 = d(p1, p2), t23 = d(p2, p3);
      const m1x = (p2.px - p1.px + t12 * ((p1.px - p0.px) / t01 - (p2.px - p0.px) / (t01 + t12)));
      const m1y = (p2.py - p1.py + t12 * ((p1.py - p0.py) / t01 - (p2.py - p0.py) / (t01 + t12)));
      const m2x = (p2.px - p1.px + t12 * ((p3.px - p2.px) / t23 - (p3.px - p1.px) / (t12 + t23)));
      const m2y = (p2.py - p1.py + t12 * ((p3.py - p2.py) / t23 - (p3.py - p1.py) / (t12 + t23)));
      segs.push({
        a: [p1.px, p1.py],
        c1: [p1.px + m1x / 3, p1.py + m1y / 3],
        c2: [p2.px - m2x / 3, p2.py - m2y / 3],
        b: [p2.px, p2.py],
        from: p1, to: p2,
      });
    }
    return segs;
  }

  const bez = (s, t) => {
    const u = 1 - t;
    return [
      u * u * u * s.a[0] + 3 * u * u * t * s.c1[0] + 3 * u * t * t * s.c2[0] + t * t * t * s.b[0],
      u * u * u * s.a[1] + 3 * u * u * t * s.c1[1] + 3 * u * t * t * s.c2[1] + t * t * t * s.b[1],
    ];
  };
  const segLen = (s) => {
    let L = 0, prev = s.a;
    for (let i = 1; i <= 20; i++) { const p = bez(s, i / 20); L += Math.hypot(p[0] - prev[0], p[1] - prev[1]); prev = p; }
    return L;
  };
  const tangentAt = (s, t) => {
    const a = bez(s, Math.max(0, t - 0.02)), b = bez(s, Math.min(1, t + 0.02));
    return Math.atan2(b[1] - a[1], b[0] - a[0]);
  };
  const dOf = (s) => `M${f1(s.a[0])} ${f1(s.a[1])}C${f1(s.c1[0])} ${f1(s.c1[1])} ${f1(s.c2[0])} ${f1(s.c2[1])} ${f1(s.b[0])} ${f1(s.b[1])}`;

  // Blatt (wie Logo-Linienblatt, aber schlanker), Basis am Stiel
  function leafPath(x, y, ang, L) {
    const W = L * 0.21;
    const c = Math.cos(ang), s = Math.sin(ang);
    const P = (px, py) => `${f1(x + px * c - py * s)} ${f1(y + px * s + py * c)}`;
    const pet = L * 0.22;
    const j = () => 0.92 + rnd() * 0.16;
    return {
      outline: `M${P(0, 0)}L${P(pet, 0)}C${P(pet + L * 0.16 * j(), W * 1.25 * j())} ${P(pet + L * 0.66, W * 0.95 * j())} ${P(pet + L, 0)}` +
               `C${P(pet + L * 0.68, -W * 0.9 * j())} ${P(pet + L * 0.18, -W * 1.2 * j())} ${P(pet, 0)}`,
      rib: `M${P(pet, 0)}Q${P(pet + L * 0.45, W * 0.06)} ${P(pet + L * 0.82, 0)}`,
    };
  }

  /* ── Aufbau ─────────────────────────────────────────────────────────── */
  let state = null;

  function destroy() {
    if (!state) return;
    state.layers.forEach((l) => l.remove());
    window.removeEventListener('scroll', state.onScroll);
    state = null;
  }

  function build() {
    destroy();
    if (!mqDesktop.matches) return;

    const m = margins();
    const main = wobble(resolve(ROUTE, m));
    if (main.length < 3) return;
    const docH = document.documentElement.scrollHeight;
    const docW = document.documentElement.clientWidth;

    const mkLayer = (cls) => {
      const svg = el('svg', { class: `vine__layer ${cls}`, width: docW, height: docH, viewBox: `0 0 ${docW} ${docH}`, 'aria-hidden': 'true', focusable: 'false' });
      host.appendChild(svg);
      return svg;
    };
    const back = mkLayer('vine__layer--back');
    const front = mkLayer('vine__layer--front');

    // Vordere Ebene nur dort sichtbar, wo Bilder als "davor" markiert sind
    const clip = el('clipPath', { id: 'vine-front-clip' });
    document.querySelectorAll('[data-vine-front]').forEach((n) => {
      const r = docRect(n);
      clip.appendChild(el('rect', { x: f1(r.x), y: f1(r.y), width: f1(r.w), height: f1(r.h) }));
    });
    const defs = el('defs');
    defs.appendChild(clip);
    front.appendChild(defs);
    const gBack = el('g');
    const gFront = el('g', { 'clip-path': 'url(#vine-front-clip)' });
    back.appendChild(gBack);
    front.appendChild(gFront);

    const chunks = [];   // { len, start, paths:[back,front] }
    const leaves = [];   // { at, nodes:[...] }
    const keys = [];     // { at, reveal } – Zuordnung Scroll → Länge
    let total = 0;

    const addLeaf = (x, y, ang, size, at, opts = {}) => {
      const L = (opts.small ? 13 : 19 + rnd() * 7) * (size || 1);
      const lp = leafPath(x, y, ang, L);
      const nodes = [gBack, gFront].map((g) => {
        const grp = el('g', { class: 'vine__leaf-g' + (opts.fill ? ' vine__leaf--fill' : '') });
        grp.style.transformOrigin = `${f1(x)}px ${f1(y)}px`;
        grp.style.transformBox = 'view-box';
        grp.appendChild(el('path', { class: 'vine__leaf' + (opts.fill ? ' vine__leaf--fill' : ''), d: lp.outline }));
        grp.appendChild(el('path', { class: 'vine__leaf vine__rib', d: lp.rib }));
        g.appendChild(grp);
        return grp;
      });
      leaves.push({ at, nodes, sway: !opts.noSway && rnd() < 0.35 });
    };

    const drawRun = (pts, baseAt, isBranch) => {
      const segs = toBeziers(pts);
      let at = baseAt;
      segs.forEach((s) => {
        const len = segLen(s);
        const d = dOf(s);
        const paths = [gBack, gFront].map((g) => {
          const p = el('path', { class: 'vine__stem', d });
          p.style.strokeDasharray = `${f1(len + 1)} ${f1(len + 2)}`;
          p.style.strokeDashoffset = f1(len + 1);
          if (isBranch) p.style.strokeWidth = '1.1';
          g.appendChild(p);
          return p;
        });
        chunks.push({ start: at, len, paths, drawn: -1 });

        const tgt = s.to;
        if (tgt.leaf && !tgt.calm) {
          const ang = tangentAt(s, 0.999);
          const sides = tgt.leaf === 'lr' ? [-1, 1] : [tgt.leaf === 'l' ? -1 : 1];
          // Blätter etwas vor dem Wegpunkt, damit sie nicht exakt auf Bildkanten sitzen
          const t = tgt.mid ? 0.55 : 0.9;
          const [x, y] = bez(s, t);
          const a2 = tangentAt(s, t);
          sides.forEach((side) => addLeaf(x, y, a2 + side * (0.95 + rnd() * 0.3), tgt.size, at + len * t));
          void ang;
        }
        if (tgt.end) {
          // Abschluss: wenige kleine Blätter
          const a = tangentAt(s, 1);
          const [x, y] = s.b;
          const n = tgt.small ? 2 : 4;
          for (let k = 0; k < n; k++) {
            const off = (k - (n - 1) / 2) * 0.62;
            addLeaf(x, y, a + off, tgt.small ? 0.8 : 0.9 - Math.abs(off) * 0.12, at + len + k * 14, { fill: k % 2 === 0, small: tgt.small });
          }
        }
        if (!isBranch) keys.push({ at: at + len, y: tgt.py, wob: tgt.wob, branch: tgt.branch });
        at += len;
      });
      return at;
    };

    // Startblatt (Samen) – Linienform des Logo-Blatts
    const seed = main[0];
    [gBack].forEach((g) => {
      const grp = el('g', { class: 'vine__leaf-g vine__seed-g' });
      grp.style.transformOrigin = `${f1(seed.px)}px ${f1(seed.py)}px`;
      grp.style.transformBox = 'view-box';
      const s = 0.42, ox = seed.px - 8 * s, oy = seed.py - 56 * s;
      grp.appendChild(el('path', {
        class: 'vine__seed',
        d: `M${f1(ox + 8 * s)} ${f1(oy + 56 * s)}A${48 * s} ${48 * s} 0 0 1 ${f1(ox + 41.1 * s)} ${f1(oy + 10.4 * s)}L${f1(ox + 53.6 * s)} ${f1(oy + 22.9 * s)}A${48 * s} ${48 * s} 0 0 1 ${f1(ox + 8 * s)} ${f1(oy + 56 * s)}Z`,
        transform: `rotate(-12 ${f1(seed.px)} ${f1(seed.py)})`,
      }));
      g.appendChild(grp);
      leaves.push({ at: 0, nodes: [grp], sway: false });
    });

    keys.push({ at: 0, y: seed.py });
    total = drawRun(main, 0, false);

    // Zweige anhängen
    Object.entries(BRANCHES).forEach(([name, pts]) => {
      const startKey = keys.find((k) => k.branch === name);
      if (!startKey) return;
      const bp = wobble(resolve(pts, m));
      if (bp.length < 2) return;
      drawRun(bp, startKey.at, true);
    });

    // Scroll → Länge: Wegpunkte erscheinen, wenn sie bei TIP_AT im Fenster stehen.
    // Waagerechte Strecken bekommen Mindest-Scrollweg, sonst „springt“ die Linie.
    keys.sort((a, b) => a.at - b.at);
    const vh = window.innerHeight;
    let prevR = -Infinity, prevAt = 0;
    keys.forEach((k) => {
      const want = k.y - vh * TIP_AT;
      k.reveal = Math.max(want, prevR + (k.at - prevAt) * 0.42);
      prevR = k.reveal; prevAt = k.at;
    });

    const lengthFor = (scroll) => {
      if (scroll <= keys[0].reveal) return 0;
      for (let i = 1; i < keys.length; i++) {
        const a = keys[i - 1], b = keys[i];
        if (scroll < b.reveal) {
          const t = (scroll - a.reveal) / Math.max(1, b.reveal - a.reveal);
          return a.at + (b.at - a.at) * t;
        }
      }
      return Infinity;
    };

    const static_ = mqReduce.matches || debugFull;
    let lastFrame = 0, raf = 0, shown = -1;

    const apply = (L) => {
      chunks.forEach((c) => {
        const vis = Math.max(0, Math.min(c.len, L - c.start));
        if (vis === c.drawn) return;
        c.drawn = vis;
        const off = f1(c.len + 1 - vis);
        c.paths.forEach((p) => { p.style.strokeDashoffset = off; });
      });
      leaves.forEach((lf) => {
        const on = L >= lf.at;
        if (on === lf.on) return;
        lf.on = on;
        lf.nodes.forEach((n) => {
          n.classList.toggle('is-grown', on);
          if (lf.sway && on && !static_) setTimeout(() => n.classList.add('is-sway'), 600);
        });
      });
    };

    const tick = (now) => {
      raf = 0;
      if (now - lastFrame < FRAME_MS) { raf = requestAnimationFrame(tick); return; }
      lastFrame = now;
      const raw = lengthFor(window.scrollY);
      const L = raw === Infinity ? Infinity : Math.floor(raw / STEP_PX) * STEP_PX;
      if (L !== shown) { shown = L; apply(L); }
    };
    const onScroll = () => { if (!raf) raf = requestAnimationFrame(tick); };

    host.classList.add('is-instant');
    setTimeout(() => host.classList.remove('is-instant'), 120);
    if (static_) {
      apply(Infinity);
    } else {
      // Samenblatt beim Laden kurz „wachsen“ lassen
      setTimeout(() => leaves[0].nodes.forEach((n) => n.classList.add('is-grown')), 900);
      leaves[0].on = true;
      window.addEventListener('scroll', onScroll, { passive: true });
      onScroll();
    }

    state = { layers: [back, front], onScroll, docH };
  }

  /* ── Lebenszyklus ───────────────────────────────────────────────────── */
  let t = 0;
  const schedule = () => { clearTimeout(t); t = setTimeout(build, 180); };

  const start = () => {
    build();
    window.addEventListener('resize', schedule);
    mqDesktop.addEventListener('change', schedule);
    mqReduce.addEventListener('change', schedule);
    // Layout-Änderungen (Bilder, FAQ öffnen, Formular) → Route neu vermessen
    if ('ResizeObserver' in window) {
      let lastH = document.documentElement.scrollHeight;
      new ResizeObserver(() => {
        const h = document.documentElement.scrollHeight;
        if (Math.abs(h - lastH) > 2) { lastH = h; schedule(); }
      }).observe(document.body);
    }
  };

  const ready = document.fonts && document.fonts.ready ? document.fonts.ready : Promise.resolve();
  ready.then(() => (document.readyState === 'complete' ? start() : window.addEventListener('load', start, { once: true })));
})();
