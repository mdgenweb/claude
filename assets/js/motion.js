/* [FIRMENNAME] Gartenservice – Bewegung
   Ladesequenz, Wort-Reveals, Marquee mit Scroll-Tempo, rollende Zahlen,
   wachsende Ablauf-Linie, Mählinie der Hero-Szene. Alles mit transform/opacity,
   ein gemeinsamer rAF-Takt fürs Scrollen.
   prefers-reduced-motion: keine dieser Effekte, alles sofort sichtbar. */
(() => {
  'use strict';

  const $ = (s, c = document) => c.querySelector(s);
  const $$ = (s, c = document) => [...c.querySelectorAll(s)];
  const root = document.documentElement;
  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)');
  const motion = !reduce.matches && 'IntersectionObserver' in window;
  const clamp = (v, a = 0, b = 1) => Math.min(b, Math.max(a, v));
  // bildratenunabhängiges Nachziehen: Anteil, der in dt Sekunden aufgeholt wird
  const follow = (dt, k) => 1 - Math.exp(-dt * k);
  if (motion) root.classList.add('motion-ok');

  /* ── Riesentypo exakt auf Breite setzen ─────────────────────────────── */
  const fitOne = (el) => {
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
    if (width > 0) el.style.fontSize = (parseFloat(cs.fontSize) * (avail / width) * 0.999) + 'px';
  };
  const fitAll = () => {
    $$('[data-fit]').forEach((el) => {
      el.style.fontSize = '';
      if (getComputedStyle(el).whiteSpace !== 'nowrap') return; // mobil: gestapelt
      fitOne(el);
      fitOne(el); // zweiter Durchgang gleicht Rundung und Kerning aus
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
    if (idx > 0 && el.hasAttribute('data-reveal')) el.style.setProperty('--rd', Math.min(idx, 5) * 90 + 'ms');
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
  // Läuft als Web Animation auf dem Compositor (kein Haupt-Thread-Takt);
  // beim Scrollen wird nur die Wiedergabegeschwindigkeit weich nachgeführt.
  const mq = $('[data-marquee]');
  if (mq) {
    const track = $('.marquee__track', mq);
    const base = [...track.children].map((c) => c.cloneNode(true));
    while (track.scrollWidth < window.innerWidth * 2.2) base.forEach((c) => track.append(c.cloneNode(true)));
    // exakt verdoppeln, damit die Schleife bei −50 % nahtlos ist
    [...track.children].forEach((c) => track.append(c.cloneNode(true)));
    const SPEED = 70; // px/s
    const dur = () => (track.scrollWidth / 2 / SPEED) * 1000;
    const anim = track.animate(
      [{ transform: 'translate3d(0, 0, 0)' }, { transform: 'translate3d(-50%, 0, 0)' }],
      { duration: dur(), iterations: Infinity },
    );
    ready.then(() => anim.effect.updateTiming({ duration: dur() })); // Breite nach dem Laden der Schrift
    // außerhalb des Sichtbereichs Tempo 0 statt pause()/play(): play() wirft bei
    // rückwärts laufender Endlos-Animation (nach dem Hochscrollen) einen Fehler
    let dir = 1, boost = 0, rate = 1, last = 0, steering = false, lastY = window.scrollY, seen = true;
    const setRate = () => { anim.playbackRate = seen ? rate : 0; };
    const steer = (t) => {
      const dt = Math.min(0.05, (t - last) / 1000 || 0.016);
      last = t;
      boost *= Math.exp(-dt * 3.2);
      const target = dir * (1 + boost);
      rate += (target - rate) * follow(dt, 3.5);
      const settled = boost < 0.01 && Math.abs(target - rate) < 0.01;
      if (settled) rate = dir;
      setRate();
      if (settled) steering = false; else requestAnimationFrame(steer);
    };
    window.addEventListener('scroll', () => {
      const y = window.scrollY;
      const d = y - lastY;
      lastY = y;
      if (Math.abs(d) < 1) return;
      dir = d > 0 ? 1 : -1;
      boost = Math.min(10, boost + Math.abs(d) * 0.06);
      if (!steering) { steering = true; last = performance.now(); requestAnimationFrame(steer); }
    }, { passive: true });
    new IntersectionObserver(([en]) => { seen = en.isIntersecting; setRate(); }).observe(mq);
  }

  /* ── Ablauf-Linie ───────────────────────────────────────────────────── */
  const steps = $('[data-steps]');
  const stepItems = steps ? $$('[data-step]', steps) : [];
  const stacked = window.matchMedia('(max-width: 1023px)'); // Ablauf untereinander
  const wide = window.matchMedia('(min-width: 1100px)');

  /* ── Hero-Parallaxe (nur breit, ohne Ausblenden – die Schnellanfrage bleibt bedienbar) ── */
  const heroInner = $('.hero__inner');

  /* ── Hero-Szene: Mählinie fährt beim Laden ein Stück herein, Scrollen mäht weiter ── */
  const hero = $('.hero');
  const scene = $('[data-scene]');
  if (scene && hero) {
    new IntersectionObserver(([en]) => scene.classList.toggle('is-paused', !en.isIntersecting)).observe(hero);
  }

  // Ziele werden beim Scrollen gesetzt; ein kurzer rAF-Lauf gleitet hin und
  // stoppt, sobald alles angekommen ist (kein Springen bei Mausrad-Schritten)
  const cur = { par: 0, p: 0, mow: 0 };
  const tgt = { par: 0, p: 0, mow: 0 };
  let looping = false, lastT = 0;
  const measure = () => {
    const vh = window.innerHeight;
    const y = window.scrollY;
    if (!wide.matches) tgt.par = 0;
    else if (y < vh * 1.4) tgt.par = y * -0.12;
    if (scene) {
      const hr = hero.getBoundingClientRect();
      tgt.mow = 0.36 + 0.64 * clamp(-hr.top / Math.max(1, hr.height * 0.7));
    }
    const sr = steps && steps.getBoundingClientRect();
    if (sr && sr.bottom > -vh && sr.top < vh * 2) {
      if (stacked.matches) {
        tgt.p = clamp((vh * 0.62 - sr.top) / Math.max(1, sr.height));
        stepItems.forEach((s) => s.classList.toggle('is-on', s.getBoundingClientRect().top < vh * 0.62));
      } else {
        tgt.p = clamp((vh * 0.88 - sr.top) / (vh * 0.5));
        stepItems.forEach((s, i) => s.classList.toggle('is-on', tgt.p > i / 4 + 0.02));
      }
    }
  };
  const apply = () => {
    if (heroInner) heroInner.style.transform = cur.par ? `translate3d(0, ${cur.par.toFixed(2)}px, 0)` : '';
    if (steps) steps.style.setProperty('--p', cur.p.toFixed(4));
    if (scene) scene.style.setProperty('--mow', cur.mow.toFixed(4));
  };
  const loop = (t) => {
    const dt = Math.min(0.05, (t - lastT) / 1000 || 0.016);
    lastT = t;
    cur.par += (tgt.par - cur.par) * follow(dt, 11);
    cur.p += (tgt.p - cur.p) * follow(dt, 7);
    cur.mow += (tgt.mow - cur.mow) * follow(dt, 3.2);
    const done = Math.abs(tgt.par - cur.par) < 0.05 && Math.abs(tgt.p - cur.p) < 0.0005 && Math.abs(tgt.mow - cur.mow) < 0.0005;
    if (done) { cur.par = tgt.par; cur.p = tgt.p; cur.mow = tgt.mow; }
    apply();
    if (done) looping = false; else requestAnimationFrame(loop);
  };
  const onScroll = () => {
    measure();
    if (!looping) { looping = true; lastT = performance.now(); requestAnimationFrame(loop); }
  };
  window.addEventListener('scroll', onScroll, { passive: true });
  window.addEventListener('resize', onScroll);
  // Startzustand ohne Gleiten (z. B. nach Neuladen mitten auf der Seite);
  // nur die Mählinie fährt beim Laden sichtbar herein
  const settle = () => { measure(); cur.par = tgt.par; cur.p = tgt.p; apply(); };
  settle();
  ready.then(() => { settle(); onScroll(); });

})();
