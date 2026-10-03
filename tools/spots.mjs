// Leistungs-Illustrationen im Siebdruck-Stil.
//   node tools/spots.mjs  →  assets/img/spots/*.svg + assets/img/grain.png
//
// Gestaltungsregeln (bewusst „gemacht“, nicht generiert):
// – wenige Druckfarben: Waldgrün, Moos, Blattgrün, Lehm (nur für die Aktion),
//   dazu Papiertöne; keine Verläufe
// – Flächen mit gestalteten Mustern statt Zufallsstreuung: Laub als
//   Schuppenmuster, Erde als Punktraster, Kies als Körnung, Rasen als Mähstreifen
// – leichter Passerversatz: große Formen haben eine hellere Kante oben links,
//   wie beim Siebdruck mit zwei Farben
// – organische Kurven werden geglättet (Catmull-Rom), keine Zickzack-Kanten
// – Bewegung: einzelne Triebe und Halme wiegen sich leicht. Damit nicht das
//   ganze Bild mit seinen Mustern in jedem Frame neu gezeichnet wird, entstehen
//   je Motiv drei Dateien:  name.svg (komplett, still – Kacheln, Unterseite),
//   name-base.svg (ohne bewegte Teile) und name-motion.svg (nur die bewegten
//   Teile, transparent, darübergelegt). Ohne „reduzierte Bewegung“ animiert.
// Die Papierkörnung liegt als CSS-Ebene über den Bildern (assets/img/grain.png).

import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { deflateSync } from 'node:zlib';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const OUT = join(ROOT, 'assets', 'img', 'spots');
mkdirSync(OUT, { recursive: true });

const C = {
  night: '#0E1D15', forest: '#1E3A2B', moss: '#2F5A3C', grass: '#4E7F45', grass2: '#5E9050',
  leaf: '#8DB86A', leafLight: '#A6CA86', pale: '#CFE0BA',
  clay: '#AE542D', ochre: '#C98A3E', yellow: '#E2B13C',
  soil: '#8C6A4A', soilDark: '#5E4631',
  stone: '#CFC9BD', stoneDark: '#A39D90', stoneLight: '#E2DDD3',
  wood: '#9A7652', woodDark: '#6E5238',
};

/* ── Werkzeuge ─────────────────────────────────────────────────────────── */
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
const pt = ([x, y]) => `${n(x)} ${n(y)}`;

// Catmull-Rom → kubische Bézierkurven: weiche, gezeichnet wirkende Konturen
function smooth(pts, closed = true, k = 0.5) {
  const P = closed ? [pts[pts.length - 1], ...pts, pts[0], pts[1]] : [pts[0], ...pts, pts[pts.length - 1]];
  let d = `M${pt(P[1])}`;
  for (let i = 1; i < P.length - 2; i++) {
    const [p0, p1, p2, p3] = [P[i - 1], P[i], P[i + 1], P[i + 2]];
    const c1 = [p1[0] + ((p2[0] - p0[0]) * k) / 3, p1[1] + ((p2[1] - p0[1]) * k) / 3];
    const c2 = [p2[0] - ((p3[0] - p1[0]) * k) / 3, p2[1] - ((p3[1] - p1[1]) * k) / 3];
    d += `C${pt(c1)} ${pt(c2)} ${pt(p2)}`;
  }
  return d + (closed ? 'Z' : '');
}
// nur die Kurvensegmente (aktueller Punkt = pts[0]) – für Konturen mit geraden Kanten
const smoothSeg = (pts, k = 0.5) => smooth(pts, false, k).replace(/^M[^C]*/, '');

// Blatt (Mandelform) als Pfad-Daten
const leafD = (x, y, len, ang, wf = 0.42) => {
  const c = Math.cos(ang), s = Math.sin(ang), w = len * wf;
  const T = (u, v) => `${n(x + u * c - v * s)} ${n(y + u * s + v * c)}`;
  return `M${T(0, 0)}C${T(len * 0.25, w)} ${T(len * 0.7, w * 0.9)} ${T(len, 0)}C${T(len * 0.7, -w * 0.9)} ${T(len * 0.25, -w)} ${T(0, 0)}Z`;
};
const g = (attrs, body) => `<g ${attrs}>${body}</g>`;
const path = (d, fill, extra = '') => `<path d="${d}" fill="${fill}"${extra ? ' ' + extra : ''}/>`;

// Muster (Druckraster)
const PATTERNS = {
  // Laub: Schuppenmuster, groß (Hecke) und klein (Strauch, Buchs)
  foliage: (id, bg = C.forest, fg = C.moss, s = 1) => {
    const w = 18 * s, h = 13 * s;
    return `<pattern id="${id}" width="${n(w)}" height="${n(h)}" patternUnits="userSpaceOnUse"><rect width="${n(w)}" height="${n(h)}" fill="${bg}"/>`
      + `<path d="M0 ${n(h)}Q${n(w / 2)} ${n(h * 0.1)} ${n(w)} ${n(h)}M${n(-w / 2)} ${n(h / 2)}Q0 ${n(-h * 0.4)} ${n(w / 2)} ${n(h / 2)}Q${n(w)} ${n(-h * 0.4)} ${n(w * 1.5)} ${n(h / 2)}" fill="none" stroke="${fg}" stroke-width="${n(1.7 * s)}" stroke-linecap="round"/></pattern>`;
  },
  // Erde: Punktraster
  stipple: (id, bg = C.soil, fg = C.soilDark) => `<pattern id="${id}" width="11" height="11" patternUnits="userSpaceOnUse"><rect width="11" height="11" fill="${bg}"/><circle cx="2.5" cy="2.5" r="1.15" fill="${fg}"/><circle cx="8" cy="8" r="1.15" fill="${fg}"/></pattern>`,
  // Kies: Körnung in drei Steintönen
  gravel: (id) => `<pattern id="${id}" width="22" height="16" patternUnits="userSpaceOnUse"><rect width="22" height="16" fill="${C.stoneLight}"/><ellipse cx="4" cy="4" rx="2.6" ry="2" fill="${C.stone}"/><ellipse cx="14" cy="3" rx="2" ry="1.6" fill="${C.stoneDark}"/><ellipse cx="9" cy="11" rx="2.8" ry="2.1" fill="${C.stone}"/><ellipse cx="19" cy="12" rx="2.2" ry="1.7" fill="#BDB6A9"/></pattern>`,
  // hohes Gras: kurze Halme im Raster
  blades: (id, bg = C.grass, fg = C.grass2) => `<pattern id="${id}" width="12" height="16" patternUnits="userSpaceOnUse"><rect width="12" height="16" fill="${bg}"/><path d="M1 16L3.5 4 5 16ZM7 9 9.5-2 11 9Z" fill="${fg}"/></pattern>`,
};

const STYLE = `<style>@media (prefers-reduced-motion:no-preference){.sway{animation:sway 5.4s ease-in-out infinite alternate;transform-box:fill-box;transform-origin:50% 100%}.s2{animation-duration:6.6s;animation-delay:-2.4s}.s3{animation-duration:4.8s;animation-delay:-3.6s}.float{animation:float 6.5s ease-in-out infinite alternate;transform-box:fill-box;transform-origin:50% 50%}}@keyframes sway{from{transform:rotate(-2deg)}to{transform:rotate(2.2deg)}}@keyframes float{from{transform:translate(0,-2px) rotate(-7deg)}to{transform:translate(1px,3px) rotate(9deg)}}</style>`;

// Motiv registrieren; Ausgabe in drei Varianten siehe unten
const svg = (w, h, bg, defs, body, label, motion = true) => ({ w, h, bg, defs, body, label, motion });
const MOVING = /<g class="(?:sway|float)[^"]*">.*?<\/g>/g;
const render = ({ w, h, bg, defs, body, label }, variant) => {
  const head = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}"`;
  if (variant === 'motion') return `${head} aria-hidden="true">${STYLE}${(body.match(MOVING) || []).join('')}</svg>\n`;
  const b = variant === 'base' ? body.replace(MOVING, '') : body;
  return `${head} role="img" aria-label="${label}"><defs>${defs}</defs><rect width="${w}" height="${h}" fill="${bg}"/>${b}</svg>\n`;
};

// Passerversatz: hellere Kopie leicht nach oben links hinter der Form
const offsetEdge = (d, color, dx = -3.5, dy = -3.5) => path(d, color, `transform="translate(${dx} ${dy})"`);

// Mähstreifen in Perspektive
function stripes(y0, y1, W, a = C.leaf, b = C.leafLight, count = 9, spreadTop = 1, spreadBot = 1.5) {
  let o = `<rect y="${y0}" width="${W}" height="${y1 - y0}" fill="${a}"/>`;
  const cx = W / 2, wt = (W / count) * spreadTop, wb = (W / count) * spreadBot;
  for (let i = -2; i < count + 2; i += 2) {
    const t0 = cx + (i - count / 2) * wt, b0 = cx + (i - count / 2) * wb;
    o += path(`M${n(t0)} ${y0}H${n(t0 + wt)}L${n(b0 + wb)} ${y1}H${n(b0)}Z`, b);
  }
  return o;
}

// Grasbüschel (ein Pfad); optional mit leichtem Wiegen
function tuft(x, y, h, fill, seed, count = 6, cls = null) {
  const r = rng(seed);
  let d = '';
  for (let i = 0; i < count; i++) {
    const bx = x + (i - count / 2) * 3.2 + r() * 2, hh = h * (0.6 + r() * 0.5), lean = (r() - 0.5) * hh * 0.7, w = 2.2 + r() * 1.6;
    d += `M${n(bx - w)} ${y}Q${n(bx + lean * 0.3)} ${n(y - hh * 0.6)} ${n(bx + lean)} ${n(y - hh)}Q${n(bx + lean * 0.35 + w * 0.3)} ${n(y - hh * 0.55)} ${n(bx + w)} ${y}Z`;
  }
  return cls === null ? path(d, fill) : g(`class="sway ${cls}"`, path(d, fill));
}

// Trieb mit Blättern (für ungeschnittene Hecken und Sträucher)
function sprig(x, y, len, ang, seed, stem = C.moss, leaf = C.grass, cls = 's2') {
  const r = rng(seed);
  const ex = x + Math.cos(ang) * len, ey = y + Math.sin(ang) * len;
  const mx = (x + ex) / 2 + (r() - 0.5) * 10, my = (y + ey) / 2 + (r() - 0.5) * 6;
  let o = `<path d="M${n(x)} ${n(y)}Q${n(mx)} ${n(my)} ${n(ex)} ${n(ey)}" fill="none" stroke="${stem}" stroke-width="2.4" stroke-linecap="round"/>`;
  let ld = '';
  for (let k = 1; k <= 3; k++) {
    const t = k / 3.6, px = x + (ex - x) * t + (mx - (x + ex) / 2) * 0.5, py = y + (ey - y) * t + (my - (y + ey) / 2) * 0.5;
    ld += leafD(px, py, 11 + r() * 4, ang + (k % 2 ? -0.95 : 0.95), 0.45);
  }
  ld += leafD(ex, ey, 13, ang, 0.42);
  o += path(ld, leaf);
  return cls === null ? o : g(`class="sway ${cls}"`, o);
}

// Löwenzahnblatt mit rückwärts gerichteten, weich gerundeten Lappen
function dandelionLeaf(cx, cy, L, ang, seed) {
  const r = rng(seed);
  const side = (sgn) => [[0.06, 0.04], [0.16, 0.17], [0.27, 0.07], [0.37, 0.21], [0.5, 0.08], [0.58, 0.19], [0.7, 0.09], [0.8, 0.15], [0.93, 0.06]]
    .map(([u, v]) => [u + (r() - 0.5) * 0.02, sgn * (v + (r() - 0.5) * 0.02)]);
  const pts = [[0, 0], ...side(1), [1, 0], ...side(-1).reverse()];
  const c = Math.cos(ang), s = Math.sin(ang);
  const T = ([u, v]) => [cx + u * L * c - v * L * s, cy + u * L * s + v * L * c];
  return smooth(pts.map(T), true, 0.55);
}

// Rosette (Salat, junge Pflanzen): fünf Blätter fächerförmig
function rosette(x, y, size, light, dark) {
  let d1 = '', d2 = '';
  [-2.5, -1.95, -1.57, -1.2, -0.65].forEach((a, i) => {
    const d = leafD(x, y, size * (i === 2 ? 1.05 : 0.86), a, 0.5);
    if (i % 2) d2 += d; else d1 += d;
  });
  return path(d1, dark) + path(d2, light);
}

const files = {};

/* ── 1 Heckenschnitt: links noch zottig, rechts schon gerade geschnitten ── */
{
  const W = 480, H = 360;
  const defs = PATTERNS.foliage('fh');
  let b = '';
  b += stripes(276, H, W, C.leaf, C.leafLight, 8, 1.1, 1.6);
  b += `<rect x="40" y="280" width="400" height="12" rx="6" fill="${C.forest}" opacity=".22"/>`;
  const r = rng(5);
  const top = [[52, 150]];
  for (let x = 66; x <= 252; x += 16) top.push([x, 150 - (12 + r() * 18)]);
  top.push([268, 150]);
  const shag = `M52 170L${pt(top[0])}${smoothSeg(top, 0.6)}L268 170Z`;
  const body = 'M66 150H414Q432 150 432 168V270Q432 286 416 286H64Q48 286 48 270V168Q48 150 66 150Z';
  b += offsetEdge(shag, C.leafLight) + offsetEdge(body, C.leafLight);
  b += path(shag, 'url(#fh)') + path(body, 'url(#fh)');
  b += path('M268 150H414Q432 150 432 166V168H268Z', C.grass);
  [[82, 128, 34, -1.85], [118, 118, 40, -1.55], [160, 124, 30, -1.25], [204, 116, 38, -1.7], [240, 130, 28, -1.2]]
    .forEach(([x, y, l, a], i) => { b += sprig(x, y, l, a, 30 + i, C.moss, i % 2 ? C.grass : C.grass2, ['s2', 's3', ''][i % 3]); });
  b += `<path d="M38 150H446" stroke="${C.clay}" stroke-width="2.6" stroke-dasharray="9 7" stroke-linecap="round"/>`;
  b += path('M448 150l14-9v18z', C.clay);
  let clip = '';
  [[300, 296, 0.4], [326, 302, 2.6], [352, 297, 1.4], [378, 304, 5.1], [404, 298, 3.3]].forEach(([x, y, a]) => { clip += leafD(x, y, 10, a, 0.45); });
  b += path(clip, C.grass);
  b += g('class="float"', path(leafD(296, 214, 12, 0.8, 0.45), C.grass2));
  files['heckenschnitt.svg'] = svg(W, H, '#E6ECDB', defs, b, 'Illustration: Hecke, links ungeschnitten, rechts gerade geschnitten');
}

/* ── 2 Rasenpflege: gemähte Streifen, rechts noch hohes Gras ─────────── */
{
  const W = 480, H = 360;
  const defs = PATTERNS.foliage('fr', C.moss, C.grass, 0.7) + PATTERNS.blades('gb');
  let b = '';
  const hedge = smooth([[0, 128], [60, 112], [130, 118], [200, 106], [280, 116], [360, 104], [430, 114], [480, 108], [480, 150], [0, 150]], true, 0.4);
  b += offsetEdge(hedge, C.leafLight, -3, -3) + path(hedge, 'url(#fr)');
  b += stripes(150, H, W, C.leaf, C.leafLight, 9, 0.9, 1.7);
  b += path(`M322 150H${W}V${H}H272Z`, 'url(#gb)');
  b += tuft(300, 300, 34, C.moss, 3, 9, 's2') + tuft(340, 250, 26, C.moss, 4, 8, '') + tuft(356, 200, 20, C.moss, 5, 7, 's3') + tuft(400, 300, 30, C.moss, 8, 9, 's3');
  b += tuft(420, 356, 46, C.moss, 6, 12, '') + tuft(452, 356, 40, C.moss, 7, 10, 's2');
  b += `<path d="M322 150L272 ${H}" stroke="#F4F0E6" stroke-width="2.2" opacity=".8"/>`;
  b += `<path d="M310 150L262 ${H}" stroke="${C.clay}" stroke-width="2.4" stroke-dasharray="8 8" stroke-linecap="round"/>`;
  const r = rng(31);
  let cl = '';
  for (let i = 0; i < 14; i++) { const x = 220 + r() * 70, y = 170 + r() * 170, a = r() * 3.1; cl += leafD(x, y, 7, a, 0.3); }
  b += path(cl, C.pale);
  files['rasenpflege.svg'] = svg(W, H, '#E3EAD6', defs, b, 'Illustration: Rasen mit Mähstreifen, rechts noch ungemäht');
}

/* ── 3 Unkraut entfernen: Löwenzahn samt Pfahlwurzel gezogen ─────────── */
{
  const W = 480, H = 360;
  const defs = PATTERNS.stipple('st');
  let b = '';
  b += `<rect y="228" width="${W}" height="${H - 228}" fill="url(#st)"/>`;
  b += `<rect y="222" width="${W}" height="10" fill="${C.leaf}"/>`;
  for (let x = -6; x < W; x += 36) b += `<rect x="${x}" y="226" width="30" height="12" rx="5" fill="${C.stone}"/><rect x="${x}" y="234" width="30" height="4" rx="2" fill="${C.stoneDark}"/>`;
  b += rosette(70, 262, 34, C.leaf, C.grass) + rosette(150, 270, 28, C.leaf, C.grass);
  b += `<ellipse cx="70" cy="264" rx="22" ry="4" fill="${C.soilDark}" opacity=".5"/><ellipse cx="150" cy="272" rx="18" ry="3.5" fill="${C.soilDark}" opacity=".5"/>`;
  b += `<ellipse cx="318" cy="252" rx="30" ry="7" fill="${C.soilDark}"/>`;
  b += `<path d="M318 150C322 176 312 196 318 228" fill="none" stroke="${C.soilDark}" stroke-width="5.5" stroke-linecap="round"/>`;
  b += `<path d="M318 176q-12 4-18 14M317 192q12 3 17 13M316 207q-10 3-13 11M319 218q8 2 10 9" fill="none" stroke="${C.soilDark}" stroke-width="1.8" stroke-linecap="round"/>`;
  [[306, 232], [326, 238], [314, 242], [331, 228]].forEach(([x, y], i) => { b += `<circle cx="${x}" cy="${y}" r="${n(2.4 - i * 0.3)}" fill="${C.soilDark}"/>`; });
  let dk = '', lt = '', rib = '';
  [[-2.75, 92], [-2.25, 104], [-1.85, 86], [-1.3, 98], [-0.85, 104], [-0.4, 90]].forEach(([a, L], i) => {
    const d = dandelionLeaf(318, 146, L, a, 70 + i);
    if (i % 2) lt += d; else dk += d;
    rib += `M318 146L${n(318 + Math.cos(a) * L * 0.85)} ${n(146 + Math.sin(a) * L * 0.85)}`;
  });
  b += path(dk, C.grass) + path(lt, C.leaf);
  b += `<path d="${rib}" stroke="${C.pale}" stroke-width="1.1" opacity=".7"/>`;
  b += g('class="sway"', `<path d="M318 140C314 112 322 88 318 66" fill="none" stroke="${C.grass}" stroke-width="3" stroke-linecap="round"/>`
    + `<circle cx="318" cy="60" r="14" fill="${C.yellow}"/><circle cx="318" cy="60" r="14" fill="none" stroke="${C.ochre}" stroke-width="2" stroke-dasharray="2 3"/><circle cx="318" cy="60" r="5" fill="${C.ochre}"/>`);
  b += `<path d="M408 210V96" stroke="${C.clay}" stroke-width="3" stroke-linecap="round"/><path d="M396 110l12-15 12 15" fill="none" stroke="${C.clay}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>`;
  files['unkraut.svg'] = svg(W, H, '#ECE3D3', defs, b, 'Illustration: Löwenzahn wird samt Wurzel aus dem Beet entfernt');
}

/* ── 4 Sträucher: links ausgewachsen, rechts in Form geschnitten ─────── */
{
  const W = 480, H = 360;
  const defs = PATTERNS.foliage('fs', C.forest, C.moss, 0.75);
  let b = '';
  b += `<rect y="288" width="${W}" height="${H - 288}" fill="${C.leaf}"/>`;
  b += `<rect y="288" width="${W}" height="5" fill="${C.leafLight}"/>`;
  b += `<ellipse cx="240" cy="292" rx="170" ry="9" fill="${C.forest}" opacity=".22"/>`;
  const r = rng(8);
  const wild = [];
  const steps = 9;
  for (let i = 0; i <= steps; i++) {
    const a = Math.PI + (i / steps) * Math.PI * 0.5;
    const rad = i === 0 || i === steps ? 160 : 162 + (i % 2 ? 16 : 4) + r() * 8;
    wild.push([240 + Math.cos(a) * rad, 290 + Math.sin(a) * rad * 0.94]);
  }
  wild[0][1] = 290; wild[steps][0] = 240;
  const wildD = `M240 290L${pt(wild[0])}${smoothSeg(wild, 0.55)}Z`;
  const dome = 'M240 290V140A150 150 0 0 1 390 290Z';
  b += offsetEdge(wildD, C.leafLight) + offsetEdge(dome, C.leafLight);
  b += path(wildD, 'url(#fs)') + path(dome, 'url(#fs)');
  b += path('M240 140A150 150 0 0 1 300 152L296 162A140 140 0 0 0 240 151Z', C.moss);
  [[-2.95, 40], [-2.55, 46], [-2.15, 44], [-1.8, 40], [-1.62, 34]].forEach(([a, l], i) => {
    const x = 240 + Math.cos(a) * 150, y = 290 + Math.sin(a) * 150 * 0.94;
    b += sprig(x, y, l, a + (i % 2 ? 0.12 : -0.1), 40 + i, C.moss, i % 2 ? C.grass : C.grass2, ['s3', '', 's2'][i % 3]);
  });
  b += `<path d="M90 290A150 150 0 0 1 240 140" fill="none" stroke="${C.clay}" stroke-width="2.6" stroke-dasharray="9 7" stroke-linecap="round"/>`;
  b += `<path d="M240 300V128" stroke="${C.clay}" stroke-width="2" stroke-dasharray="4 6" opacity=".8"/>`;
  files['straeucher.svg'] = svg(W, H, '#E2E9D7', defs, b, 'Illustration: Strauch, links ausgewachsen, rechts in Form geschnitten');
}

/* ── 5 Allgemeine Gartenpflege: Hochbeet, Weg, Laub mit Rechen ───────── */
{
  const W = 480, H = 360;
  const defs = PATTERNS.stipple('sg', C.soilDark, '#4B3826');
  let b = '';
  b += stripes(150, H, W, C.leaf, C.leafLight, 7, 1, 1.4);
  b += `<rect x="36" y="196" width="300" height="102" rx="4" fill="url(#sg)"/>`;
  b += `<rect x="30" y="286" width="312" height="22" rx="3" fill="${C.wood}"/><path d="M30 297H342" stroke="${C.woodDark}" stroke-width="1.5"/>`;
  b += `<rect x="30" y="188" width="312" height="12" rx="3" fill="${C.wood}"/>`;
  b += `<rect x="30" y="188" width="10" height="120" fill="${C.woodDark}"/><rect x="332" y="188" width="10" height="120" fill="${C.woodDark}"/>`;
  for (let row = 0; row < 2; row++) {
    for (let i = 0; i < 5; i++) {
      if (row && i === 4) continue;
      const x = 76 + i * 56 + (row ? 28 : 0), y = 238 + row * 36;
      b += rosette(x, y, 22 - row * 2, row ? C.leaf : C.leafLight, row ? C.grass : C.grass2);
    }
  }
  [[70, 334], [150, 328], [230, 334], [310, 328]].forEach(([x, y]) => { b += `<ellipse cx="${x}" cy="${y + 3}" rx="30" ry="9" fill="${C.stoneDark}"/><ellipse cx="${x}" cy="${y}" rx="30" ry="9" fill="${C.stoneLight}"/>`; });
  const r = rng(61);
  let l1 = '', l2 = '', l3 = '';
  for (let i = 0; i < 26; i++) {
    const t = i / 26, x = 402 + Math.sin(t * 9.4) * 34 * (1 - t * 0.5), y = 300 - t * 46 + r() * 8;
    const d = leafD(x, y, 16 + r() * 5, r() * 6.28, 0.48);
    if (i % 3 === 0) l1 += d; else if (i % 3 === 1) l2 += d; else l3 += d;
  }
  b += `<ellipse cx="402" cy="304" rx="54" ry="8" fill="${C.forest}" opacity=".2"/>`;
  b += path(l1, C.clay) + path(l2, C.ochre) + path(l3, C.grass);
  b += `<path d="M300 66L374 272" stroke="${C.wood}" stroke-width="5" stroke-linecap="round"/>`;
  b += `<path d="M350 282L398 264" stroke="${C.night}" stroke-width="5" stroke-linecap="round"/><path d="M354 281l4 12M364 277l4 12M374 274l4 12M384 270l4 12M394 266l4 12" stroke="${C.night}" stroke-width="2.6" stroke-linecap="round"/>`;
  b += g('class="float"', path(leafD(430, 196, 15, 2.2, 0.48), C.clay));
  b += g('class="float s2"', path(leafD(380, 150, 13, 0.4, 0.48), C.ochre));
  files['gartenpflege.svg'] = svg(W, H, '#EAE5D9', defs, b, 'Illustration: aufgeräumtes Hochbeet, Weg und Laub mit Rechen');
}

/* ── 6 Grabpflege: ruhig, gedämpft, ohne Lehm, ohne Bewegung ─────────── */
{
  const W = 480, H = 360;
  const defs = PATTERNS.gravel('gv') + PATTERNS.foliage('fb', '#3E5C47', '#4F6E57', 0.6);
  let b = '';
  b += `<rect y="262" width="${W}" height="${H - 262}" fill="#D9D5CC"/>`;
  b += `<path d="M96 276H384L414 344H66Z" fill="url(#gv)"/>`;
  b += `<path d="M90 270H390L422 350H58Z" fill="none" stroke="${C.stoneDark}" stroke-width="6" stroke-linejoin="round"/>`;
  const stone = 'M172 276V140A68 68 0 0 1 308 140V276Z';
  b += offsetEdge(stone, C.stoneLight, -4, -4) + path(stone, C.stone);
  b += `<path d="M188 262V146A52 52 0 0 1 292 146V262" fill="none" stroke="${C.stoneDark}" stroke-width="1.6"/>`;
  b += `<rect x="164" y="270" width="152" height="12" rx="3" fill="${C.stoneDark}"/>`;
  b += offsetEdge('M322 306a30 27 0 1 1 60 0z', '#8FA796', -3, -3) + path('M322 306a30 27 0 1 1 60 0z', 'url(#fb)');
  b += `<path d="M110 332C150 314 196 304 236 290" fill="none" stroke="#3E5C47" stroke-width="2.4" stroke-linecap="round"/>`;
  let ol = '';
  for (let i = 0; i < 7; i++) { const t = 0.12 + i * 0.12, x = 110 + t * 126, y = 332 - t * 42; ol += leafD(x, y, 22, -0.95 - (i % 2) * 0.85, 0.36); }
  b += path(ol, '#5F7D68');
  files['grabpflege.svg'] = svg(W, H, '#E7E4DD', defs, b, 'Illustration: gepflegte Grabstätte mit Kiesbett und Buchskugel', false);
}

/* ── 7 Vorher / Nachher: gleiche Szene, 1200 × 800, ohne Bewegung ────── */
{
  const BW = 1200, BH = 800;
  const trees = smooth([[0, 360], [120, 300], [260, 330], [400, 280], [560, 320], [720, 276], [880, 318], [1040, 284], [1200, 312], [1200, 430], [0, 430]], true, 0.45);
  {
    const defs = PATTERNS.foliage('ft', '#9BB98A', '#AFC99D', 1.6) + PATTERNS.foliage('fv', C.forest, C.moss, 1.7) + PATTERNS.blades('bv');
    let b = path(trees, 'url(#ft)');
    b += `<rect y="560" width="${BW}" height="240" fill="url(#bv)"/>`;
    const r = rng(82);
    const edge = [[104, 600]];
    for (let y = 560; y >= 340; y -= 44) edge.push([96 - r() * 22, y]);
    for (let x = 120; x <= 1080; x += 40) edge.push([x, 296 - r() * 52]);
    for (let y = 340; y <= 560; y += 44) edge.push([1104 + r() * 22, y]);
    edge.push([1096, 600]);
    const hedge = `M${pt(edge[0])}${smoothSeg(edge, 0.55)}Z`;
    b += offsetEdge(hedge, C.leafLight, -6, -6) + path(hedge, 'url(#fv)');
    for (let i = 0; i < 14; i++) b += sprig(150 + i * 66 + r() * 20, 268 + r() * 40, 70 + r() * 60, -Math.PI / 2 + (r() - 0.5) * 1.0, 90 + i, C.moss, i % 2 ? C.grass : C.grass2, null);
    for (let i = 0; i < 26; i++) b += tuft(20 + i * 46 + r() * 20, 800, 110 + r() * 60, i % 2 ? C.moss : C.grass2, 120 + i, 12);
    for (let i = 0; i < 6; i++) { const x = 120 + i * 190 + r() * 60, y = 690 + r() * 80; b += `<path d="M${n(x)} ${n(y)}V${n(y - 74)}" stroke="${C.moss}" stroke-width="3"/><circle cx="${n(x)}" cy="${n(y - 78)}" r="12" fill="${C.yellow}"/>`; }
    b = `<rect y="490" width="${BW}" height="${BH - 490}" fill="url(#bv)"/><g transform="translate(0 -70)">${b}</g>`;
    files['vorher.svg'] = svg(BW, BH, '#EEF1E6', defs, b, 'Illustration: zugewachsene Hecke und hoher Rasen', false);
  }
  {
    const defs = PATTERNS.foliage('ft', '#9BB98A', '#AFC99D', 1.6) + PATTERNS.foliage('fn', C.forest, C.moss, 1.7) + PATTERNS.stipple('sn');
    let b = path(trees, 'url(#ft)');
    b += stripes(560, BH, BW, C.leaf, C.leafLight, 10, 1, 1.5);
    b += `<path d="M150 574H1050L1072 604H128Z" fill="url(#sn)"/>`;
    const hedge = 'M190 300H1010Q1030 300 1030 320V570Q1030 590 1010 590H190Q170 590 170 570V320Q170 300 190 300Z';
    b += offsetEdge(hedge, C.leafLight, -6, -6) + path(hedge, 'url(#fn)');
    b += path('M190 300H1010Q1030 300 1030 318V324H170V318Q170 300 190 300Z', C.grass);
    b = stripes(490, BH, BW, C.leaf, C.leafLight, 10, 1, 1.5) + `<g transform="translate(0 -70)">${b}</g>`;
    files['nachher.svg'] = svg(BW, BH, '#EEF1E6', defs, b, 'Illustration: gerade geschnittene Hecke und gemähter Rasen', false);
  }
}

for (const [name, art] of Object.entries(files)) {
  writeFileSync(join(OUT, name), render(art, 'full'));
  if (art.motion && MOVING.test(art.body)) {
    MOVING.lastIndex = 0;
    writeFileSync(join(OUT, name.replace('.svg', '-base.svg')), render(art, 'base'));
    writeFileSync(join(OUT, name.replace('.svg', '-motion.svg')), render(art, 'motion'));
  }
  MOVING.lastIndex = 0;
}

/* ── Papierkörnung: kleine Graustufen-Kachel (PNG) für die CSS-Ebene ──── */
{
  const S = 128, r = rng(2024);
  const raw = Buffer.alloc((S + 1) * S);
  for (let y = 0; y < S; y++) {
    raw[y * (S + 1)] = 0; // Zeilenfilter: keiner
    for (let x = 0; x < S; x++) {
      const v = r(), w = r();
      // überwiegend hell, wenige dunklere Körner → bei „multiply“ nur leichte Struktur
      raw[y * (S + 1) + 1 + x] = Math.round(255 - (v * v * 60 + (w > 0.985 ? 70 : 0)));
    }
  }
  const crc = (buf) => { let c = ~0; for (const b of buf) { c ^= b; for (let k = 0; k < 8; k++) c = (c >>> 1) ^ (0xedb88320 & -(c & 1)); } return ~c >>> 0; };
  const chunk = (type, data) => { const len = Buffer.alloc(4); len.writeUInt32BE(data.length); const td = Buffer.concat([Buffer.from(type), data]); const cr = Buffer.alloc(4); cr.writeUInt32BE(crc(td)); return Buffer.concat([len, td, cr]); };
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(S, 0); ihdr.writeUInt32BE(S, 4); ihdr[8] = 8;
  const png = Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
  writeFileSync(join(ROOT, 'assets', 'img', 'grain.png'), png);
}

console.log('ok', Object.keys(files).join(', '), '+ grain.png');
