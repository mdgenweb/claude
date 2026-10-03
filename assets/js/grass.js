/* ==========================================================================
   Hero-Signature: „Wir mähen das.“
   Ein generatives Rasenfeld (Canvas 2D) wächst beim Laden hoch, wiegt sich im
   Wind und weicht dem Mauszeiger aus. Beim Scrollen fährt eine unsichtbare
   Mählinie von links nach rechts: Halme werden gekürzt, Mähstreifen entstehen,
   die große Headline wird vollständig frei.
   – zwei Ebenen: hinter der Headline (dicht) und davor (locker, für Tiefe)
   – läuft nur, solange der Hero sichtbar ist; DPR auf 2 begrenzt
   – prefers-reduced-motion: ein ruhiges Standbild, halb gemäht
   ========================================================================== */
(() => {
  'use strict';

  const hero = document.querySelector('[data-grass]');
  if (!hero) return;
  const back = hero.querySelector('[data-grass-layer="back"]');
  const front = hero.querySelector('[data-grass-layer="front"]');
  if (!back || !front || !back.getContext) return;

  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)');
  const ctxB = back.getContext('2d');
  const ctxF = front.getContext('2d');

  // Farben: Basis dunkel → Spitze heller (Licht von oben)
  const PAL = {
    back: [['#0F2016', '#1B3A28'], ['#0F2016', '#21452F'], ['#102318', '#264E35'], ['#0E1D15', '#1E3F2C']],
    front: [['#132A1D', '#2F5A3C'], ['#132A1D', '#3A6A45'], ['#14301F', '#467A4E'], ['#132A1D', '#548A58'], ['#14301F', '#2A5236']],
    // Mähstreifen: hell / dunkel im Wechsel
    stripeA: ['#1D3B29', '#5F9461'],
    stripeB: ['#15301F', '#3B6B45'],
  };

  let W = 0, H = 0, dpr = 1;
  let blades = { back: [], front: [] };
  let grads = null;
  let particles = [];
  let mow = 0, mowTarget = 0, lastMowX = -999;
  let grow = 0;
  let running = false, visible = true, raf = 0;
  const start = performance.now();
  const pointer = { x: -9999, y: -9999, on: false };

  function rng(seed) {
    let s = seed >>> 0;
    return () => {
      s = (s + 0x6d2b79f5) >>> 0;
      let t = s;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  function build() {
    const r = front.getBoundingClientRect();
    W = Math.max(1, r.width);
    H = Math.max(1, r.height);
    dpr = Math.min(2, window.devicePixelRatio || 1);
    [back, front].forEach((c) => {
      c.width = Math.round(W * dpr);
      c.height = Math.round(H * dpr);
    });
    [ctxB, ctxF].forEach((c) => c.setTransform(dpr, 0, 0, dpr, 0, 0));

    const rand = rng(11);
    const narrow = W < 700;
    const make = (count, hMin, hMax, palLen, wMin, wMax) => {
      const arr = [];
      for (let i = 0; i < count; i++) {
        const x = rand() * (W + 40) - 20;
        const tall = rand() < 0.08 ? 1.25 : 1;
        arr.push({
          x,
          h: H * (hMin + rand() * (hMax - hMin)) * tall,
          w: wMin + rand() * (wMax - wMin),
          c: Math.floor(rand() * palLen),
          ph: rand() * Math.PI * 2,
          lean: (rand() - 0.5) * 0.32,
          cut: H * (0.07 + rand() * 0.05),
          cur: 0,
          delay: rand() * 0.35 + (x / W) * 0.45,
          stripe: Math.floor((x + 40) / (narrow ? 70 : 110)) % 2,
        });
      }
      return arr;
    };
    const k = narrow ? 0.55 : 1;
    blades.back = make(Math.round(W * 0.85 * k), 0.38, 0.95, PAL.back.length, 3, 7);
    blades.front = make(Math.round(W * 0.2 * k), 0.1, 0.42, PAL.front.length, 3.5, 7.5);

    const g = (ctx, [a, b]) => {
      const lg = ctx.createLinearGradient(0, H, 0, H * 0.05);
      lg.addColorStop(0, a);
      lg.addColorStop(1, b);
      return lg;
    };
    grads = {
      back: PAL.back.map((p) => g(ctxB, p)),
      front: PAL.front.map((p) => g(ctxF, p)),
      stripeA: [g(ctxB, PAL.stripeA), g(ctxF, PAL.stripeA)],
      stripeB: [g(ctxB, PAL.stripeB), g(ctxF, PAL.stripeB)],
    };
    if (reduce.matches) {
      grow = 1;
      mow = mowTarget = 0.55;
      blades.back.concat(blades.front).forEach((b) => { b.cur = b.x < mowX() ? Math.min(b.h, b.cut) : b.h; });
    }
  }

  const mowX = () => mow * (W + 160) - 80;
  const easeOut = (t) => 1 - Math.pow(1 - t, 3);

  function drawLayer(ctx, list, layer, time, mx) {
    ctx.clearRect(0, 0, W, H);
    const pal = grads[layer];
    const li = layer === 'back' ? 0 : 1;
    // nach Füllung gruppieren → wenige fill()-Aufrufe
    const groups = new Map();
    const wind = Math.sin(time * 0.35) * 0.5 + 0.5;
    const gust = Math.max(0, Math.sin(time * 0.23 + 1.3)) * 0.12;

    for (const b of list) {
      const cut = b.x < mx;
      const g0 = Math.min(1, Math.max(0, (grow - b.delay) / 0.55));
      const target = (cut ? Math.min(b.h, b.cut) : b.h) * easeOut(g0);
      b.cur += (target - b.cur) * (cut && b.cur > target ? 0.35 : 0.09);
      const h = b.cur;
      if (h < 1) continue;

      let ang = b.lean
        + Math.sin(time * 1.3 + b.x * 0.011 + b.ph) * (0.04 + wind * 0.05)
        + Math.sin(time * 0.55 + b.x * 0.0035) * (0.06 + gust);
      if (pointer.on) {
        const dx = b.x - pointer.x;
        const dy = (H - h * 0.6) - pointer.y;
        const R = 140;
        if (Math.abs(dx) < R && Math.abs(dy) < h + 60) {
          const f = 1 - Math.abs(dx) / R;
          ang += Math.sign(dx || 1) * f * f * 0.85;
        }
      }
      ang *= cut ? 0.35 : 1;

      const tipX = b.x + Math.sin(ang) * h;
      const tipY = H - Math.cos(ang) * h;
      const cx = b.x + Math.sin(ang * 0.5) * h * 0.5;
      const cy = H - Math.cos(ang * 0.5) * h * 0.55;
      const w = b.w * (cut ? 1.1 : 1);

      const key = cut ? (b.stripe ? 'A' : 'B') : b.c;
      let arr = groups.get(key);
      if (!arr) groups.set(key, (arr = []));
      arr.push(b.x - w / 2, cx - w * 0.28, cy, tipX, tipY, cx + w * 0.28, b.x + w / 2);
    }

    for (const [key, a] of groups) {
      ctx.fillStyle = key === 'A' ? grads.stripeA[li] : key === 'B' ? grads.stripeB[li] : pal[key];
      ctx.beginPath();
      for (let i = 0; i < a.length; i += 7) {
        ctx.moveTo(a[i], H + 2);
        ctx.quadraticCurveTo(a[i + 1], a[i + 2], a[i + 3], a[i + 4]);
        ctx.quadraticCurveTo(a[i + 5], a[i + 2], a[i + 6], H + 2);
      }
      ctx.fill();
    }
  }

  function drawParticles(ctx, dt) {
    if (!particles.length) return;
    ctx.fillStyle = '#7FA35E';
    for (let i = particles.length - 1; i >= 0; i--) {
      const p = particles[i];
      p.life -= dt;
      if (p.life <= 0) { particles.splice(i, 1); continue; }
      p.vy += 520 * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.r += p.vr * dt;
      ctx.save();
      ctx.globalAlpha = Math.min(1, p.life * 2.5);
      ctx.translate(p.x, p.y);
      ctx.rotate(p.r);
      ctx.fillRect(-p.s, -0.8, p.s * 2, 1.6);
      ctx.restore();
    }
    ctx.globalAlpha = 1;
  }

  let lastT = performance.now();
  function frame(now) {
    raf = 0;
    const dt = Math.min(0.05, (now - lastT) / 1000);
    lastT = now;
    const time = (now - start) / 1000;
    grow = Math.min(1.6, grow + dt / 1.5);
    mow += (mowTarget - mow) * Math.min(1, dt * 6);
    const mx = mowX();

    // Schnittgut an der Mählinie, nur solange gemäht wird
    if (mx > lastMowX + 1 && mx > 0 && mx < W) {
      const n = Math.min(14, Math.round((mx - lastMowX) * 0.5));
      for (let i = 0; i < n && particles.length < 220; i++) {
        particles.push({
          x: mx - Math.random() * 18, y: H - H * (0.08 + Math.random() * 0.25),
          vx: -40 - Math.random() * 160, vy: -120 - Math.random() * 220,
          r: Math.random() * 3, vr: (Math.random() - 0.5) * 14,
          s: 2 + Math.random() * 3.5, life: 0.6 + Math.random() * 0.6,
        });
      }
    }
    lastMowX = mx;

    drawLayer(ctxB, blades.back, 'back', time, mx);
    drawLayer(ctxF, blades.front, 'front', time, mx);
    drawParticles(ctxF, dt);

    if (running) raf = requestAnimationFrame(frame);
  }

  function drawStatic() {
    drawLayer(ctxB, blades.back, 'back', 2, mowX());
    drawLayer(ctxF, blades.front, 'front', 2, mowX());
  }

  function setRunning(on) {
    running = on && visible && !reduce.matches && !document.hidden;
    if (running && !raf) { lastT = performance.now(); raf = requestAnimationFrame(frame); }
  }

  function onScroll() {
    const r = hero.getBoundingClientRect();
    const span = Math.max(1, r.height * 0.55);
    mowTarget = Math.min(1, Math.max(0, -r.top / span));
  }

  build();
  onScroll();
  if (reduce.matches) drawStatic(); else setRunning(true);

  new IntersectionObserver(([en]) => { visible = en.isIntersecting; setRunning(true); }).observe(hero);
  document.addEventListener('visibilitychange', () => setRunning(true));
  window.addEventListener('scroll', onScroll, { passive: true });
  let rt = 0;
  window.addEventListener('resize', () => {
    clearTimeout(rt);
    rt = setTimeout(() => { const g = grow; build(); grow = g; blades.back.concat(blades.front).forEach((b) => { b.cur = b.h; }); if (reduce.matches) drawStatic(); }, 150);
  });
  reduce.addEventListener('change', () => { build(); if (reduce.matches) { running = false; drawStatic(); } else setRunning(true); });

  hero.addEventListener('pointermove', (e) => {
    if (e.pointerType !== 'mouse') return;
    const r = front.getBoundingClientRect();
    pointer.x = e.clientX - r.left;
    pointer.y = e.clientY - r.top;
    pointer.on = true;
  });
  hero.addEventListener('pointerleave', () => { pointer.on = false; });
})();
