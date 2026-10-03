/* [FIRMENNAME] Gartenservice – Interaktionen
   Kein Framework, keine Abhängigkeiten. Alles funktioniert auch ohne JS
   (Links, Formular-Fallback, Details/Summary); JS ergänzt nur. */
(() => {
  'use strict';

  const $ = (s, c = document) => c.querySelector(s);
  const $$ = (s, c = document) => [...c.querySelectorAll(s)];
  const root = document.documentElement;
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');

  /* ── Seite geladen (Unterstrich im Hero zeichnen) ───────────────────── */
  const markLoaded = () => requestAnimationFrame(() => root.classList.add('is-loaded'));
  (document.fonts && document.fonts.ready ? document.fonts.ready : Promise.resolve()).then(markLoaded);

  /* ── Header: kompakter nach leichtem Scrollen ───────────────────────── */
  const header = $('[data-header]');
  let ticking = false;
  const onScroll = () => {
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(() => {
      header.classList.toggle('is-scrolled', window.scrollY > 24);
      ticking = false;
    });
  };
  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();

  /* ── Drawer (Mobile-/Tablet-Navigation) ─────────────────────────────── */
  const drawer = $('[data-drawer]');
  const openBtn = $('[data-menu-open]');
  const closeBtn = $('[data-menu-close]');
  const main = $('main');
  let lastFocus = null;

  const focusables = () =>
    $$('a[href], button:not([disabled]), input, textarea, [tabindex]:not([tabindex="-1"])', drawer)
      .filter((el) => el.offsetParent !== null);

  const openDrawer = () => {
    lastFocus = document.activeElement;
    drawer.hidden = false;
    requestAnimationFrame(() => drawer.classList.add('is-open'));
    openBtn.setAttribute('aria-expanded', 'true');
    root.style.overflow = 'hidden';
    main.inert = true;
    setTimeout(() => closeBtn.focus(), 60);
  };
  const closeDrawer = (restore = true) => {
    drawer.classList.remove('is-open');
    openBtn.setAttribute('aria-expanded', 'false');
    root.style.overflow = '';
    main.inert = false;
    const done = () => { drawer.hidden = true; };
    if (reduceMotion.matches) done(); else setTimeout(done, 380);
    if (restore && lastFocus) lastFocus.focus();
  };

  openBtn.addEventListener('click', openDrawer);
  closeBtn.addEventListener('click', () => closeDrawer());
  drawer.addEventListener('click', (e) => {
    if (e.target === drawer) closeDrawer();
    if (e.target.closest('a[href^="#"]')) closeDrawer(false);
  });
  drawer.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeDrawer();
    if (e.key !== 'Tab') return;
    const f = focusables();
    const first = f[0], last = f[f.length - 1];
    if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
    else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
  });

  /* ── Aktiver Navigationspunkt ───────────────────────────────────────── */
  const navLinks = $$('.nav__list a');
  const sections = navLinks.map((a) => $(a.getAttribute('href'))).filter(Boolean);
  if ('IntersectionObserver' in window && sections.length) {
    const io = new IntersectionObserver((entries) => {
      entries.forEach((en) => {
        if (!en.isIntersecting) return;
        navLinks.forEach((a) => {
          if (a.getAttribute('href') === '#' + en.target.id) a.setAttribute('aria-current', 'true');
          else a.removeAttribute('aria-current');
        });
      });
    }, { rootMargin: '-45% 0px -50% 0px' });
    sections.forEach((s) => io.observe(s));
  }

  /* ── Sanftes Einblenden ─────────────────────────────────────────────── */
  const reveals = $$('.reveal');
  if ('IntersectionObserver' in window && !reduceMotion.matches) {
    const io = new IntersectionObserver((entries) => {
      entries.forEach((en) => {
        if (en.isIntersecting) { en.target.classList.add('is-in'); io.unobserve(en.target); }
      });
    }, { rootMargin: '0px 0px -8% 0px', threshold: 0.08 });
    reveals.forEach((el, i) => {
      // Geschwister leicht versetzt – ruhig, nicht verspielt
      const sib = el.parentElement ? [...el.parentElement.children].filter((c) => c.classList.contains('reveal')) : [];
      const idx = sib.indexOf(el);
      if (idx > 0) el.style.transitionDelay = Math.min(idx, 4) * 90 + 'ms';
      io.observe(el);
    });
  } else {
    reveals.forEach((el) => el.classList.add('is-in'));
  }

  /* ── Linien beim Eintritt zeichnen (mobil: Ablauf) ─────────────────── */
  const draws = $$('[data-draw]');
  if ('IntersectionObserver' in window && !reduceMotion.matches) {
    const io = new IntersectionObserver((entries) => {
      entries.forEach((en) => { if (en.isIntersecting) { en.target.classList.add('is-drawn'); io.unobserve(en.target); } });
    }, { threshold: 0.15 });
    draws.forEach((d) => io.observe(d));
  } else {
    draws.forEach((d) => d.classList.add('is-drawn'));
  }

  /* ── Vorher/Nachher ─────────────────────────────────────────────────── */
  $$('[data-compare]').forEach((cmp) => {
    const range = $('.compare__range', cmp);
    const set = (v) => cmp.style.setProperty('--pos', v + '%');
    range.addEventListener('input', () => set(range.value));
    set(range.value);
    // Einmaliger, dezenter Hinweis auf die Funktion beim ersten Sichtkontakt
    if (!reduceMotion.matches && 'IntersectionObserver' in window) {
      const io = new IntersectionObserver(([en]) => {
        if (!en.isIntersecting) return;
        io.disconnect();
        let t0 = null;
        const anim = (t) => {
          if (range.dataset.touched) return;
          t0 = t0 || t;
          const p = Math.min(1, (t - t0) / 1600);
          const v = 50 + Math.sin(p * Math.PI * 2) * 9 * (1 - p);
          set(v);
          if (p < 1) requestAnimationFrame(anim); else set(range.value);
        };
        setTimeout(() => requestAnimationFrame(anim), 500);
      }, { threshold: 0.6 });
      io.observe(cmp);
    }
    range.addEventListener('pointerdown', () => { range.dataset.touched = '1'; });
    range.addEventListener('keydown', () => { range.dataset.touched = '1'; });
  });

  /* ── Leistung vorauswählen ("Heckenschnitt anfragen" → Chip aktiv) ──── */
  $$('[data-service]').forEach((a) => {
    a.addEventListener('click', () => {
      const v = a.dataset.service;
      const box = $$('.chip input').find((i) => i.value === v);
      if (box) { box.checked = true; box.dispatchEvent(new Event('change', { bubbles: true })); }
    });
  });

  /* ── Formular ───────────────────────────────────────────────────────── */
  const form = $('[data-form]');
  if (form) {
    const MAX_FILES = 6;
    const MAX_MB = 12;
    const fileInput = $('#f-photos', form);
    const list = $('[data-upload-list]', form);
    const upload = $('[data-upload]', form);
    const status = $('[data-form-status]', form);
    let files = [];

    const syncInput = () => {
      try {
        const dt = new DataTransfer();
        files.forEach((f) => dt.items.add(f));
        fileInput.files = dt.files;
      } catch (_) { /* ältere Browser: Auswahl bleibt wie gewählt */ }
    };
    const renderFiles = () => {
      list.replaceChildren(...files.map((f, i) => {
        const li = document.createElement('li');
        li.className = 'upload__item';
        const img = document.createElement('img');
        img.alt = f.name;
        img.src = URL.createObjectURL(f);
        img.onload = () => URL.revokeObjectURL(img.src);
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.setAttribute('aria-label', `Foto ${f.name} entfernen`);
        btn.innerHTML = '<svg class="icon"><use href="#i-close"/></svg>';
        btn.addEventListener('click', () => { files.splice(i, 1); syncInput(); renderFiles(); fileInput.focus(); });
        li.append(img, btn);
        return li;
      }));
    };
    const addFiles = (incoming) => {
      const msgs = [];
      [...incoming].forEach((f) => {
        if (!f.type.startsWith('image/')) { msgs.push(`„${f.name}“ ist kein Bild.`); return; }
        if (f.size > MAX_MB * 1024 * 1024) { msgs.push(`„${f.name}“ ist größer als ${MAX_MB} MB.`); return; }
        if (files.length >= MAX_FILES) { msgs.push(`Maximal ${MAX_FILES} Fotos.`); return; }
        files.push(f);
      });
      syncInput();
      renderFiles();
      status.textContent = [...new Set(msgs)].join(' ');
    };

    fileInput.addEventListener('change', () => addFiles(fileInput.files));
    ['dragenter', 'dragover'].forEach((ev) => upload.addEventListener(ev, (e) => {
      e.preventDefault(); upload.classList.add('is-dragover');
    }));
    ['dragleave', 'drop'].forEach((ev) => upload.addEventListener(ev, (e) => {
      e.preventDefault(); upload.classList.remove('is-dragover');
    }));
    upload.addEventListener('drop', (e) => { if (e.dataTransfer) addFiles(e.dataTransfer.files); });

    const rules = [
      { el: $('#f-name', form), err: $('#f-name-err', form), ok: (v) => v.trim().length > 1 },
      {
        el: $('#f-contact', form), err: $('#f-contact-err', form),
        ok: (v) => /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(v.trim()) || v.replace(/[^\d]/g, '').length >= 6,
      },
      { el: $('#f-place', form), err: $('#f-place-err', form), ok: (v) => v.trim().length > 1 },
    ];
    const chips = $('.chips', form);
    const workErr = $('#f-work-err', form);

    const showErr = (field, err, bad) => {
      field.classList.toggle('is-invalid', bad);
      err.hidden = !bad;
      const input = $('input, textarea', field);
      if (input && input.type !== 'checkbox') {
        input.setAttribute('aria-invalid', bad ? 'true' : 'false');
        if (bad) input.setAttribute('aria-describedby', err.id); else input.removeAttribute('aria-describedby');
      }
    };
    const validate = () => {
      let firstBad = null;
      rules.forEach((r) => {
        const bad = !r.ok(r.el.value);
        showErr(r.el.closest('.field'), r.err, bad);
        if (bad && !firstBad) firstBad = r.el;
      });
      const workBad = !$$('input[type="checkbox"]:checked', chips).length;
      chips.classList.toggle('is-invalid', workBad);
      workErr.hidden = !workBad;
      if (workBad && !firstBad) firstBad = $('input', chips);
      return firstBad;
    };
    // Fehler nach Korrektur sofort entfernen – nicht schon beim ersten Tippen schimpfen
    rules.forEach((r) => r.el.addEventListener('input', () => {
      if (r.el.closest('.field').classList.contains('is-invalid') && r.ok(r.el.value)) showErr(r.el.closest('.field'), r.err, false);
    }));
    chips.addEventListener('change', () => {
      if ($$('input:checked', chips).length) { chips.classList.remove('is-invalid'); workErr.hidden = true; }
    });

    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      status.textContent = '';
      const bad = validate();
      if (bad) { bad.focus(); return; }

      const endpoint = form.dataset.endpoint;
      const success = () => {
        form.hidden = true;
        const s = $('[data-form-success]');
        s.hidden = false;
        s.focus();
      };
      if (!endpoint) {
        // Demo-Modus: kein Versand konfiguriert (siehe README → Formularversand)
        success();
        return;
      }
      form.classList.add('is-sending');
      try {
        const res = await fetch(endpoint, { method: 'POST', body: new FormData(form), headers: { Accept: 'application/json' } });
        if (!res.ok) throw new Error(res.status);
        success();
      } catch (_) {
        status.textContent = 'Das hat leider nicht geklappt. Bitte versuchen Sie es noch einmal oder rufen Sie uns kurz an.';
      } finally {
        form.classList.remove('is-sending');
      }
    });
  }

  /* ── Mobile Kontaktleiste ───────────────────────────────────────────── */
  const bar = $('[data-contact-bar]');
  const heroActions = $('.hero__actions');
  const contact = $('#kontakt');
  const footer = $('.site-footer');
  if (bar && 'IntersectionObserver' in window) {
    const state = { hero: true, contact: false, footer: false };
    const update = () => bar.classList.toggle('is-visible', !state.hero && !state.contact && !state.footer);
    const watch = (el, key) => new IntersectionObserver(([en]) => { state[key] = en.isIntersecting; update(); }).observe(el);
    watch(heroActions, 'hero');
    watch(contact, 'contact');
    watch(footer, 'footer');
  }

  /* ── Jahr im Footer ─────────────────────────────────────────────────── */
  const year = $('[data-year]');
  if (year) year.textContent = new Date().getFullYear();
})();
