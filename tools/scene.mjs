// Hero-Szene im Siebdruck-Stil: Schriftzug hinter geschnittener Hecke, davor
// Rasen in Perspektive. Beim Scrollen fährt die Mählinie über den Rasen
// (CSS-Variable --mow, gesetzt in motion.js).
//   node tools/scene.mjs  →  ersetzt den Block zwischen
//   <!-- szene:start --> und <!-- szene:end --> in index.html
//
// Ebenen (von hinten nach vorn): Schriftzug · Hecke (still) · Triebe (wiegen)
// · gemähter Rasen (Streifen) · hohes Gras (still, per clip-path) · Halme
// (wiegen, per clip-path) · helle Mähkante. Bewegte Teile liegen in eigenen,
// dünnen Ebenen, damit die Muster nicht in jedem Frame neu gezeichnet werden.

import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const C = {
  forest: '#1E3A2B', moss: '#2F5A3C', grass: '#4E7F45', grass2: '#5E9050',
  leaf: '#8DB86A', leafLight: '#A6CA86',
};

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
const n = (v) => +v.toFixed(1);
const leafD = (x, y, len, ang, wf = 0.44) => {
  const c = Math.cos(ang), s = Math.sin(ang), w = len * wf;
  const T = (u, v) => `${n(x + u * c - v * s)} ${n(y + u * s + v * c)}`;
  return `M${T(0, 0)}C${T(len * 0.25, w)} ${T(len * 0.7, w * 0.9)} ${T(len, 0)}C${T(len * 0.7, -w * 0.9)} ${T(len * 0.25, -w)} ${T(0, 0)}Z`;
};
const tuftD = (x, y, h, seed, count) => {
  const r = rng(seed);
  let d = '';
  for (let i = 0; i < count; i++) {
    const bx = x + (i - count / 2) * (h * 0.09) + r() * 2, hh = h * (0.6 + r() * 0.5), lean = (r() - 0.5) * hh * 0.7, w = h * 0.05 + r() * 1.5;
    d += `M${n(bx - w)} ${y}Q${n(bx + lean * 0.3)} ${n(y - hh * 0.6)} ${n(bx + lean)} ${n(y - hh)}Q${n(bx + lean * 0.35 + w * 0.3)} ${n(y - hh * 0.55)} ${n(bx + w)} ${y}Z`;
  }
  return d;
};
const sway = ['', 's2', 's3'];
// Körnung als Musterkachel (grain-soft.png, siehe tools/spots.mjs); 150 Einheiten
// ≈ 128 px bei üblicher Szenengröße
const grain = (id, w, h, y = 0) => ({
  def: `<pattern id="${id}" width="150" height="150" patternUnits="userSpaceOnUse"><image href="assets/img/grain-soft.png" width="150" height="150"/></pattern>`,
  rect: `<rect x="-10" y="${y}" width="${w + 20}" height="${h}" fill="url(#${id})" style="mix-blend-mode:soft-light"/>`,
});

// 1 Hecke (still): Schuppenmuster, gerade geschnittene Oberkante mit heller Deckfläche
// viewBox beginnt bei y = −70: Platz für die Triebe über der Heckenkante (y = 30)
const VB = '0 -70 2400 210';
const gH = grain('sz-korn-h', 2400, 116, 24);
const hedge = `<svg class="scene__hedge" viewBox="${VB}" preserveAspectRatio="xMidYMax slice" focusable="false">`
  + `<defs>${gH.def}<pattern id="sz-laub" width="40" height="28" patternUnits="userSpaceOnUse"><rect width="40" height="28" fill="${C.forest}"/>`
  + `<path d="M0 28Q20 3 40 28M-20 14Q0-11 20 14Q40-11 60 14" fill="none" stroke="${C.moss}" stroke-width="3.2" stroke-linecap="round"/></pattern></defs>`
  + `<rect x="-10" y="24" width="2420" height="120" fill="${C.leafLight}"/>`
  + `<rect x="-6" y="30" width="2412" height="114" fill="url(#sz-laub)"/>`
  + `<rect x="-6" y="30" width="2412" height="11" fill="${C.grass}"/>${gH.rect}</svg>`;

// 2 Triebe auf der Hecke (wiegen sich). Je Takt (sway/s2/s3) eine Gruppe, die
// als Ganzes um die Heckenkante geschert wird: wenige Ebenen statt vieler.
let sprigs = '';
{
  const r = rng(7), groups = ['', '', ''];
  [180, 520, 860, 1240, 1590, 1930, 2250].forEach((x, i) => {
    const len = 42 + r() * 22, ang = -Math.PI / 2 + (r() - 0.5) * 0.7;
    const ex = x + Math.cos(ang) * len, ey = 32 + Math.sin(ang) * len;
    let d = `<path d="M${x} 34Q${n(x + (ex - x) * 0.5 + 6)} ${n(34 + (ey - 34) * 0.5)} ${n(ex)} ${n(ey)}" fill="none" stroke="${C.moss}" stroke-width="3" stroke-linecap="round"/>`;
    let ld = '';
    for (let k = 1; k <= 3; k++) { const t = k / 3.6; ld += leafD(x + (ex - x) * t, 34 + (ey - 34) * t, 13 + r() * 4, ang + (k % 2 ? -0.95 : 0.95)); }
    ld += leafD(ex, ey, 15, ang);
    d += `<path d="${ld}" fill="${i % 2 ? C.grass : C.grass2}"/>`;
    groups[i % 3] += d;
  });
  groups.forEach((g, k) => { sprigs += `<g class="sway ${sway[k]}">${g}</g>`; });
}
const hedgeSprigs = `<svg class="scene__sprigs" viewBox="${VB}" preserveAspectRatio="xMidYMax slice" focusable="false">${sprigs}</svg>`;

// 3 gemähter Rasen: Streifen in Perspektive (unten 1,2-mal so breit wie oben),
// gleichmäßig skaliert wie die übrigen Ebenen, damit die Körnung nicht verzerrt
let stripes = `<rect x="-10" width="2420" height="260" fill="${C.leaf}"/>`;
{
  const count = 20, wt = 2400 / count, wb = wt * 1.2, cx = 1200;
  for (let i = -4; i < count + 4; i += 2) {
    const t0 = cx + (i - count / 2) * wt, b0 = cx + (i - count / 2) * wb;
    stripes += `<path d="M${n(t0)} 0H${n(t0 + wt)}L${n(b0 + wb)} 260H${n(b0)}Z" fill="${C.leafLight}"/>`;
  }
}
const gM = grain('sz-korn-m', 2400, 260);
const mown = `<svg class="scene__mown" viewBox="0 0 2400 260" preserveAspectRatio="xMidYMax slice" focusable="false"><defs>${gM.def}</defs>${stripes}${gM.rect}</svg>`;

// 4 hohes Gras (still): Halmraster
const gT = grain('sz-korn-t', 2400, 260);
const tall = `<div class="scene__tall"><svg viewBox="0 0 2400 260" preserveAspectRatio="xMidYMin slice" focusable="false">`
  + `<defs>${gT.def}<pattern id="sz-halme" width="16" height="22" patternUnits="userSpaceOnUse"><rect width="16" height="22" fill="${C.grass}"/><path d="M1.5 22L4.5 6 6.5 22ZM9.5 12 12.5-4 14.5 12Z" fill="${C.grass2}"/></pattern></defs>`
  + `<rect width="2400" height="260" fill="url(#sz-halme)"/>${gT.rect}</svg></div>`;

// 5 Halmbüschel (wiegen sich), nach vorn größer. Je Reihe und Takt ein Pfad:
// alle Büschel einer Reihe stehen auf derselben Linie, eine Scherung um diese
// Linie biegt jeden Büschel um seinen Fuß.
let tufts = '';
{
  const r = rng(21);
  // [Fußlinie, Höhe, Abstand, Halme je Büschel, Farbe]: hinten klein und blasser
  // (Luftperspektive), vorn groß und dunkel; unregelmäßige Abstände, teils Paare
  const rows = [[64, 15, 64, 5, '#3E6B40'], [146, 27, 92, 7, C.moss], [258, 56, 124, 9, C.forest]];
  rows.forEach(([y, h, gap, count, fill], ri) => {
    const d = ['', '', ''];
    for (let x = 20 + r() * gap; x < 2400; x += gap * (0.55 + r() * 0.9)) {
      // leicht versetzte Fußlinie gegen strenge Reihen; der Versatz verschiebt den
      // Fuß beim Scheren um weniger als einen Pixel
      const k = (ri + Math.round(x)) % 3, yy = y - r() * h * 0.45;
      d[k] += tuftD(x, n(yy), h * (0.75 + r() * 0.5), Math.round(x) + ri, count);
      if (r() < 0.35) d[k] += tuftD(x + h * (0.45 + r() * 0.3), n(yy + 2), h * (0.5 + r() * 0.3), Math.round(x) + 7 + ri, count - 2);
    }
    d.forEach((dd, k) => { if (dd) tufts += `<g class="sway ${sway[k]}"><path d="${dd}" fill="${fill}"/></g>`; });
  });
}
const tuftLayer = `<div class="scene__tufts"><svg viewBox="0 0 2400 260" preserveAspectRatio="xMidYMax slice" focusable="false">${tufts}</svg></div>`;

const scene = `<!-- szene:start -->
  <div class="scene" aria-hidden="true" data-scene>
    <p class="hero__giant" data-fit>
      <span class="hero__word">Hecke.</span> <span class="hero__word">Rasen.</span> <span class="hero__word">Beete.</span>
    </p>
    <div class="scene__hedge-wrap">${hedge}${hedgeSprigs}</div>
    <div class="scene__lawn">${mown}${tall}${tuftLayer}<span class="scene__edge"></span></div>
  </div>
  <!-- szene:end -->`;

const file = join(ROOT, 'index.html');
const html = readFileSync(file, 'utf8');
const a = html.indexOf('<!-- szene:start -->'), b = html.indexOf('<!-- szene:end -->');
if (a < 0 || b < 0) throw new Error('Markierungen <!-- szene:start/end --> fehlen in index.html');
writeFileSync(file, html.slice(0, a) + scene + html.slice(b + '<!-- szene:end -->'.length));
console.log('ok, Szene', scene.length, 'Zeichen');
