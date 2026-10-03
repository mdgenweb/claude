/* [FIRMENNAME] Gartenservice – Grundfunktionen
   Header, Navigation, Vorher/Nachher, Formular, mobile Kontaktleiste.
   Kein Framework. Ohne JS bleiben Links, Formular und FAQ benutzbar. */
(() => {
  'use strict';

  const $ = (s, c = document) => c.querySelector(s);
  const $$ = (s, c = document) => [...c.querySelectorAll(s)];
  const root = document.documentElement;
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');

  /* ── Header: hell/dunkel je nach Sektion, beim Runterscrollen ausblenden ─ */
  const header = $('[data-header]');
  const darkSections = $$('[data-theme-dark]');
  let lastY = window.scrollY;
  let ticking = false;
  const updateHeader = () => {
    ticking = false;
    if (!header) return;
    const y = window.scrollY;
    const probe = header.offsetHeight + 2;
    const onDark = darkSections.some((s) => {
      const r = s.getBoundingClientRect();
      return r.top <= probe && r.bottom > probe;
    });
    header.classList.toggle('is-scrolled', y > 12);
    header.classList.toggle('is-light', y > 12 && !onDark);
    const drawerOpen = root.classList.contains('drawer-open');
    if (!drawerOpen && !reduceMotion.matches) {
      header.classList.toggle('is-hidden', y > lastY + 4 && y > 640);
      if (y < lastY - 4 || y < 640) header.classList.remove('is-hidden');
    }
    lastY = y;
  };
  window.addEventListener('scroll', () => { if (!ticking) { ticking = true; requestAnimationFrame(updateHeader); } }, { passive: true });
  window.addEventListener('resize', updateHeader);
  updateHeader();

  /* ── Drawer ─────────────────────────────────────────────────────────── */
  const drawer = $('[data-drawer]');
  const openBtn = $('[data-menu-open]');
  const closeBtn = $('[data-menu-close]');
  const main = $('main');
  let lastFocus = null;
  let hideTimer = 0;
  if (drawer && openBtn && closeBtn) {
    const focusables = () => $$('a[href], button:not([disabled])', drawer).filter((el) => el.offsetParent !== null);
    const openDrawer = () => {
      clearTimeout(hideTimer); // erneut geöffnet, während es sich noch schließt
      lastFocus = document.activeElement;
      drawer.hidden = false;
      root.classList.add('drawer-open');
      requestAnimationFrame(() => requestAnimationFrame(() => drawer.classList.add('is-open')));
      openBtn.setAttribute('aria-expanded', 'true');
      root.style.overflow = 'hidden';
      if (main) main.inert = true;
      setTimeout(() => closeBtn.focus(), 80);
    };
    const closeDrawer = (restore = true) => {
      drawer.classList.remove('is-open');
      root.classList.remove('drawer-open');
      openBtn.setAttribute('aria-expanded', 'false');
      root.style.overflow = '';
      if (main) main.inert = false;
      hideTimer = setTimeout(() => { drawer.hidden = true; }, reduceMotion.matches ? 0 : 900); // Vorhang: 0,1 s + 0,75 s
      if (restore && lastFocus) lastFocus.focus();
    };
    openBtn.addEventListener('click', openDrawer);
    closeBtn.addEventListener('click', () => closeDrawer());
    drawer.addEventListener('click', (e) => { if (e.target.closest('a[href^="#"]')) closeDrawer(false); });
    drawer.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') closeDrawer();
      if (e.key !== 'Tab') return;
      const f = focusables();
      const first = f[0], last = f[f.length - 1];
      if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
      else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
    });
  }

  /* ── Aktiver Navigationspunkt ───────────────────────────────────────── */
  const navLinks = $$('.nav__list a, .drawer__list a');
  const targets = [...new Set(navLinks.map((a) => a.getAttribute('href')))].map((h) => $(h)).filter(Boolean);
  if ('IntersectionObserver' in window && targets.length) {
    const io = new IntersectionObserver((entries) => {
      entries.forEach((en) => {
        if (!en.isIntersecting) return;
        navLinks.forEach((a) => {
          if (a.getAttribute('href') === '#' + en.target.id) a.setAttribute('aria-current', 'true');
          else a.removeAttribute('aria-current');
        });
      });
    }, { rootMargin: '-45% 0px -50% 0px' });
    targets.forEach((s) => io.observe(s));
  }

  /* ── Vorher/Nachher ─────────────────────────────────────────────────── */
  $$('[data-compare]').forEach((cmp) => {
    const range = $('.compare__range', cmp);
    const set = (v) => cmp.style.setProperty('--pos', v + '%');
    range.addEventListener('input', () => { range.dataset.touched = '1'; set(range.value); });
    set(range.value);
    if (!reduceMotion.matches && 'IntersectionObserver' in window) {
      const io = new IntersectionObserver(([en]) => {
        if (!en.isIntersecting) return;
        io.disconnect();
        let t0 = null;
        const anim = (t) => {
          if (range.dataset.touched) return;
          t0 = t0 || t;
          const p = Math.min(1, (t - t0) / 1800);
          set(50 + Math.sin(p * Math.PI * 2) * 14 * (1 - p));
          if (p < 1) requestAnimationFrame(anim); else set(range.value);
        };
        setTimeout(() => requestAnimationFrame(anim), 600);
      }, { threshold: 0.6 });
      io.observe(cmp);
    }
  });

  /* ── Leistung im Formular vorauswählen ──────────────────────────────── */
  const prefill = (works, place) => {
    works.forEach((v) => {
      const box = $$('.chips input').find((i) => i.value === v);
      if (box && !box.checked) { box.checked = true; box.dispatchEvent(new Event('change', { bubbles: true })); }
    });
    const field = $('#f-place');
    if (place && field && !field.value) field.value = place;
  };
  $$('[data-service]').forEach((a) => a.addEventListener('click', () => prefill([a.dataset.service])));

  /* Schnellanfrage im Hero: Auswahl übernehmen, zum Formular springen */
  const quick = $('[data-quick]');
  const formEl = $('#anfrage');
  if (quick && formEl) {
    quick.addEventListener('submit', (e) => {
      e.preventDefault();
      prefill($$('input[name="arbeit"]:checked', quick).map((i) => i.value), $('#q-place', quick).value.trim());
      formEl.scrollIntoView({ behavior: reduceMotion.matches ? 'auto' : 'smooth', block: 'start' });
      setTimeout(() => $('#f-name').focus({ preventScroll: true }), reduceMotion.matches ? 0 : 750);
    });
  }
  /* Vorauswahl per Link, z. B. von Unterseiten: ?arbeit=Heckenschnitt#kontakt */
  const params = new URLSearchParams(window.location.search);
  if (params.has('arbeit') || params.has('ort')) prefill(params.getAll('arbeit'), params.get('ort') || '');

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
    ['dragenter', 'dragover'].forEach((ev) => upload.addEventListener(ev, (e) => { e.preventDefault(); upload.classList.add('is-dragover'); }));
    ['dragleave', 'drop'].forEach((ev) => upload.addEventListener(ev, (e) => { e.preventDefault(); upload.classList.remove('is-dragover'); }));
    upload.addEventListener('drop', (e) => { if (e.dataTransfer) addFiles(e.dataTransfer.files); });

    const rules = [
      { el: $('#f-name', form), err: $('#f-name-err', form), ok: (v) => v.trim().length > 1 },
      { el: $('#f-contact', form), err: $('#f-contact-err', form), ok: (v) => /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(v.trim()) || v.replace(/[^\d]/g, '').length >= 6 },
      { el: $('#f-place', form), err: $('#f-place-err', form), ok: (v) => v.trim().length > 1 },
    ];
    const chips = $('.chips', form);
    const workErr = $('#f-work-err', form);
    const showErr = (field, err, bad) => {
      field.classList.toggle('is-invalid', bad);
      err.hidden = !bad;
      const input = $('input, textarea', field);
      input.setAttribute('aria-invalid', bad ? 'true' : 'false');
      if (bad) input.setAttribute('aria-describedby', err.id); else input.removeAttribute('aria-describedby');
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
      const success = () => {
        form.hidden = true;
        const s = $('[data-form-success]');
        s.hidden = false;
        s.focus();
      };
      const endpoint = form.dataset.endpoint;
      if (!endpoint) { success(); return; } // Demo-Modus, siehe README → Formularversand
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
  const heroCta = $('[data-quick]');
  const contact = $('#kontakt');
  const footer = $('.site-footer');
  if (bar && heroCta && contact && footer && 'IntersectionObserver' in window) {
    const state = { hero: true, contact: false, footer: false };
    const update = () => bar.classList.toggle('is-visible', !state.hero && !state.contact && !state.footer);
    const watch = (el, key) => new IntersectionObserver(([en]) => { state[key] = en.isIntersecting; update(); }).observe(el);
    watch(heroCta, 'hero');
    watch(contact, 'contact');
    watch(footer, 'footer');
  }

  /* ── Jahr im Footer ─────────────────────────────────────────────────── */
  $$('[data-year]').forEach((n) => { n.textContent = new Date().getFullYear(); });
})();
