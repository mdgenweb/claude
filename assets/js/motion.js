/* [FIRMENNAME] Gartenservice – Bewegung
   Ladesequenz, Wort-Reveals, Marquee mit Scroll-Tempo, rollende Zahlen,
   wachsende Ablauf-Linie, magnetische Buttons. Alles mit transform/opacity,
   ein gemeinsamer rAF-Takt fürs Scrollen.
   prefers-reduced-motion: keine dieser Effekte, alles sofort sichtbar. */
(() => {
  'use strict';

  const $ = (s, c = document) => c.querySelector(s);
  const $$ = (s, c = document) => [...c.querySelectorAll(s)];
  const root = document.documentElement;
  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)');
  const fine = window.matchMedia('(pointer: fine)');
  const motion = !reduce.matches && 'IntersectionObserver' in window;
  const clamp = (v, a = 0, b = 1) => Math.min(b, Math.max(a, v));
  if (motion) root.classList.add('motion-ok');

  /* ── Riesentypo exakt auf Breite setzen ─────────────────────────────── */
  const fitAll = () => {
    $$('[data-fit]').forEach((el) => {
      el.style.fontSize = '';
      if (getComputedStyle(el).whiteSpace !== 'nowrap') return; // mobil: gestapelt
      const cs = getComputedStyle(el);
      const avail = el.clientWidth - parseFloat(cs.paddingLeft) - parseFloat(cs.paddingRight);
      const parts = $$('.hero__word', el);
      let width;
      if (parts.length) {
        width = parts[parts.length - 1].getBoundingClientRect().right - parts[0].getBoundingClientRect().left;
      } else {
        const r = document.createRange();
        r.selectNodeContents(el);
        width = r.getBoundingClientRect().width;
      }
      if (width > 0) el.style.fontSize = (parseFloat(cs.fontSize) * (avail / width) * 0.995) + 'px';
    });
  };

  /* ── Überschriften in Wörter zerlegen ───────────────────────────────── */
  const splitWords = (el, cls, inner = true) => {
    let i = 0;
    const walk = (node) => {
      [...node.childNodes].forEach((n) => {
        if (n.nodeType === 3) {
          const frag = document.createDocumentFragment();
          n.textContent.split(/(\s+)/).forEach((part) => {
            if (!part) return;
            if (/^\s+$/.test(part)) { frag.append(document.createTextNode(' ')); return; }
            const w = document.createElement('span');
            w.className = cls;
            w.style.setProperty('--i', i++);
            if (inner) { const s = document.createElement('span'); s.textContent = part; w.append(s); } else w.textContent = part;
            frag.append(w);
          });
          n.replaceWith(frag);
        } else if (n.nodeType === 1 && n.tagName !== 'BR') walk(n);
      });
    };
    walk(el);
  };
  $$('[data-split]').forEach((el) => splitWords(el, 'split-w'));

  /* ── Ladesequenz ────────────────────────────────────────────────────── */
  const ready = document.fonts && document.fonts.ready ? document.fonts.ready : Promise.resolve();
  ready.then(() => {
    fitAll();
    requestAnimationFrame(() => root.classList.add('is-loaded'));
  });
  let ft = 0;
  window.addEventListener('resize', () => { clearTimeout(ft); ft = setTimeout(fitAll, 120); });

  if (!motion) return;

  /* ── Einblenden beim Scrollen ───────────────────────────────────────── */
  const io = new IntersectionObserver((entries) => {
    entries.forEach((en) => {
      if (!en.isIntersecting) return;
      en.target.classList.add('is-in');
      io.unobserve(en.target);
      if (en.target.hasAttribute('data-reveal')) rollIn(en.target);
    });
  }, { rootMargin: '0px 0px -10% 0px', threshold: 0.12 });
  $$('[data-reveal], [data-split], [data-map]').forEach((el) => {
    const sib = el.parentElement ? [...el.parentElement.children].filter((c) => c.hasAttribute('data-reveal')) : [];
    const idx = sib.indexOf(el);
    if (idx > 0 && el.hasAttribute('data-reveal')) el.style.transitionDelay = Math.min(idx, 5) * 90 + 'ms';
    io.observe(el);
  });

  /* ── Rollende Ziffern ───────────────────────────────────────────────── */
  $$('[data-roll]').forEach((n) => {
    const target = parseInt(n.dataset.roll, 10) || 0;
    const steps = 10 + target;
    const wrap = document.createElement('span');
    wrap.className = 'roll';
    const strip = document.createElement('span');
    strip.className = 'roll__strip';
    for (let k = 0; k <= steps; k++) { const s = document.createElement('span'); s.textContent = k % 10; strip.append(s); }
    wrap.append(strip);
    wrap.dataset.rollSteps = steps;
    n.replaceChildren(wrap);
  });
  function rollIn(scope) {
    $$('.roll', scope).forEach((r) => {
      r.firstChild.style.transform = `translateY(-${r.dataset.rollSteps * 0.8}em)`;
    });
  }

  /* ── Marquee: Tempo und Richtung folgen dem Scrollen ────────────────── */
  const mq = $('[data-marquee]');
  if (mq) {
    const track = $('.marquee__track', mq);
    const base = [...track.children].map((c) => c.cloneNode(true));
    while (track.scrollWidth < window.innerWidth * 2.2) base.forEach((c) => track.append(c.cloneNode(true)));
    const half = () => track.scrollWidth / 2;
    // exakt verdoppeln, damit die Schleife nahtlos ist
    [...track.children].forEach((c) => track.append(c.cloneNode(true)));
    let x = 0, dir = -1, boost = 0, last = performance.now(), on = false, lastY = window.scrollY;
    const tick = (t) => {
      const dt = Math.min(0.05, (t - last) / 1000);
      last = t;
      boost *= 0.92;
      x += dir * (70 + boost) * dt;
      const h = half();
      if (x < -h) x += h;
      if (x > 0) x -= h;
      track.style.transform = `translate3d(${x}px,0,0)`;
      if (on) requestAnimationFrame(tick);
    };
    window.addEventListener('scroll', () => {
      const y = window.scrollY;
      const d = y - lastY;
      lastY = y;
      if (Math.abs(d) > 1) { dir = d > 0 ? -1 : 1; boost = Math.min(900, boost + Math.abs(d) * 6); }
    }, { passive: true });
    new IntersectionObserver(([en]) => {
      const was = on;
      on = en.isIntersecting;
      if (on && !was) { last = performance.now(); requestAnimationFrame(tick); }
    }).observe(mq);
  }

  /* ── Ablauf-Linie ───────────────────────────────────────────────────── */
  const steps = $('[data-steps]');
  const stepItems = steps ? $$('[data-step]', steps) : [];
  const stacked = window.matchMedia('(max-width: 1023px)'); // Ablauf untereinander
  const wide = window.matchMedia('(min-width: 1100px)');

  /* ── Hero-Parallaxe (nur breit, ohne Ausblenden – die Schnellanfrage bleibt bedienbar) ── */
  const heroInner = $('.hero__inner');

  let ticking = false;
  const frame = () => {
    ticking = false;
    const vh = window.innerHeight;

    if (heroInner) {
      const y = window.scrollY;
      if (wide.matches && y < vh * 1.2) heroInner.style.transform = `translate3d(0, ${(y * -0.12).toFixed(1)}px, 0)`;
      else if (!wide.matches) heroInner.style.transform = '';
    }

    if (steps) {
      const r = steps.getBoundingClientRect();
      if (stacked.matches) {
        const p = clamp((vh * 0.62 - r.top) / Math.max(1, r.height));
        steps.style.setProperty('--p', p.toFixed(3));
        stepItems.forEach((s) => s.classList.toggle('is-on', s.getBoundingClientRect().top < vh * 0.62));
      } else {
        const p = clamp((vh * 0.88 - r.top) / (vh * 0.5));
        steps.style.setProperty('--p', p.toFixed(3));
        stepItems.forEach((s, i) => s.classList.toggle('is-on', p > i / 4 + 0.02));
      }
    }
  };
  const onScroll = () => { if (!ticking) { ticking = true; requestAnimationFrame(frame); } };
  window.addEventListener('scroll', onScroll, { passive: true });
  window.addEventListener('resize', onScroll);
  ready.then(frame);
  frame();

  /* ── Magnetische Buttons ────────────────────────────────────────────── */
  if (fine.matches) {
    $$('[data-magnetic]').forEach((el) => {
      el.addEventListener('pointermove', (e) => {
        const r = el.getBoundingClientRect();
        const dx = e.clientX - (r.left + r.width / 2);
        const dy = e.clientY - (r.top + r.height / 2);
        el.style.transform = `translate(${(dx * 0.22).toFixed(1)}px, ${(dy * 0.32).toFixed(1)}px)`;
      });
      el.addEventListener('pointerleave', () => { el.style.transform = ''; });
    });
  }
})();
