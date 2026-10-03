// Botanische Linienzeichnungen als SVG erzeugen.
//   node tools/botanics.mjs
// Alle Motive entstehen aus wenigen Grundformen (Blatt, Halm, Zweig) mit
// festem Zufalls-Seed – so wirken sie gezeichnet, bleiben aber reproduzierbar.

import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const OUT = join(ROOT, 'assets', 'img', 'illustrations');
mkdirSync(OUT, { recursive: true });

// ---------------------------------------------------------------- helpers
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
const lerp = (a, b, t) => a + (b - a) * t;
const rad = (d) => (d * Math.PI) / 180;

function cubic(p0, p1, p2, p3, t) {
  const u = 1 - t;
  return [
    u * u * u * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t * t * t * p3[0],
    u * u * u * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t * t * t * p3[1],
  ];
}
function cubicTan(p0, p1, p2, p3, t) {
  const u = 1 - t;
  return Math.atan2(
    3 * u * u * (p1[1] - p0[1]) + 6 * u * t * (p2[1] - p1[1]) + 3 * t * t * (p3[1] - p2[1]),
    3 * u * u * (p1[0] - p0[0]) + 6 * u * t * (p2[0] - p1[0]) + 3 * t * t * (p3[0] - p2[0]),
  );
}

// Blatt in lokalen Koordinaten (Basis 0,0 → Spitze L,0), dann gedreht/verschoben.
// Rückgabe: { outline, rib } als Pfaddaten.
export function leaf({ x, y, angle, L, W, bend = 0, asym = 1, rib = 0.84, veins = 0, r = Math.random, petiole = 0 }) {
  const j = (v, a = 0.06) => v * (1 + (r() - 0.5) * 2 * a);
  const bendY = (px) => bend * L * (px / L) ** 2;
  const c = Math.cos(angle), s = Math.sin(angle);
  const P = (px, py) => {
    const yy = py + bendY(px);
    return `${n(x + (px + petiole) * c - yy * s)} ${n(y + (px + petiole) * s + yy * c)}`;
  };
  const up = [[j(0.16) * L, j(1.25) * W], [j(0.66) * L, j(0.95) * W]];
  const lo = [[j(0.68) * L, -j(0.9) * W * asym], [j(0.18) * L, -j(1.2) * W * asym]];
  let outline = `M${P(0, 0)}C${P(...up[0])} ${P(...up[1])} ${P(L, 0)}C${P(...lo[0])} ${P(...lo[1])} ${P(0, 0)}`;
  if (petiole) outline = `M${P(-petiole, 0)}L${P(0, 0)}` + outline.slice(outline.indexOf('C') - 0).replace(/^/, '');
  let ribD = `M${P(0, 0)}Q${P(0.45 * L, 0.04 * W)} ${P(rib * L, 0)}`;
  for (let i = 0; i < veins; i++) {
    const t = 0.28 + i * (0.42 / Math.max(1, veins - 1));
    const side = i % 2 ? 1 : -1;
    ribD += `M${P(t * L, 0)}Q${P((t + 0.08) * L, side * 0.35 * W)} ${P((t + 0.17) * L, side * 0.62 * W)}`;
  }
  if (petiole) outline = `M${P(-petiole, 0)}L${P(0, 0)}M${P(0, 0)}` + outline.slice(outline.indexOf('C'));
  return { outline, rib: ribD };
}

function svgDoc(w, h, body, { title = '', stroke = '#1E3A2B', sw = 1.25, bg = null, preserve = null } = {}) {
  const pa = preserve ? ` preserveAspectRatio="${preserve}"` : '';
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}"${pa} fill="none" stroke="${stroke}" stroke-width="${sw}" stroke-linecap="round" stroke-linejoin="round"${title ? ` role="img" aria-label="${title}"` : ' aria-hidden="true"'}>${bg ? `<rect width="${w}" height="${h}" fill="${bg}" stroke="none"/>` : ''}${body}</svg>\n`;
}
const path = (d, extra = '') => `<path d="${d}"${extra}/>`;

// Zweig entlang einer Kubik mit wechselständigen Blättern
function branch({ p0, p1, p2, p3, nodes = 8, seed = 1, Lmax = 90, Lmin = 40, spread = 46, widthRatio = 0.22, opposite = false, bend = 0.06, veins = 0, terminal = true, startT = 0.14 }) {
  const r = rng(seed);
  let d = `M${n(p0[0])} ${n(p0[1])}C${n(p1[0])} ${n(p1[1])} ${n(p2[0])} ${n(p2[1])} ${n(p3[0])} ${n(p3[1])}`;
  const leaves = [];
  for (let i = 0; i < nodes; i++) {
    const t = lerp(startT, 0.93, i / Math.max(1, nodes - 1));
    const [x, y] = cubic(p0, p1, p2, p3, t);
    const tan = cubicTan(p0, p1, p2, p3, t);
    const sides = opposite ? [-1, 1] : [i % 2 ? 1 : -1];
    for (const side of sides) {
      const L = lerp(Lmax, Lmin, t) * (0.85 + r() * 0.3);
      const a = tan + side * rad(spread + (r() - 0.5) * 16);
      leaves.push(leaf({ x, y, angle: a, L, W: L * widthRatio, bend: -side * bend * (0.6 + r() * 0.8), r, petiole: 4 + r() * 5, veins }));
    }
  }
  if (terminal) {
    const tan = cubicTan(p0, p1, p2, p3, 1);
    leaves.push(leaf({ x: p3[0], y: p3[1], angle: tan, L: Lmin * 1.05, W: Lmin * widthRatio, bend: 0.04, r }));
  }
  return { stem: d, leaves };
}
const drawBranch = (b, sw = 1.25) =>
  path(b.stem, ` stroke-width="${sw * 1.25}"`) + b.leaves.map((l) => path(l.outline) + path(l.rib, ' stroke-width="0.9" opacity=".75"')).join('');

// Grashalme – schmale, sich verjüngende Halme mit leichtem Schwung
function grass({ x, y, count = 9, h = [80, 170], spread = 28, seed = 2, lean = 0, w = 4 }) {
  const r = rng(seed);
  let d = '';
  for (let i = 0; i < count; i++) {
    const bx = x + (r() - 0.5) * spread;
    const hh = lerp(h[0], h[1], r());
    const ln = lean + (r() - 0.5) * 0.9;
    const bw = w * (0.7 + r() * 0.6);
    const tip = [bx + ln * hh * 0.55, y - hh];
    const c1 = [bx + ln * hh * 0.04, y - hh * 0.5];
    const c2 = [bx + ln * hh * 0.3, y - hh * 0.86];
    d += `M${n(bx - bw / 2)} ${n(y)}C${n(c1[0] - bw * 0.4)} ${n(c1[1])} ${n(c2[0] - bw * 0.15)} ${n(c2[1])} ${n(tip[0])} ${n(tip[1])}`;
    d += `C${n(c2[0] + bw * 0.25)} ${n(c2[1] + 4)} ${n(c1[0] + bw * 0.5)} ${n(c1[1])} ${n(bx + bw / 2)} ${n(y)}`;
  }
  return d;
}

// Gezähntes Blatt (Löwenzahn-artig, rückwärts gerichtete Zähne)
function toothedLeaf({ x, y, angle, L, W, teeth = 5, r = Math.random }) {
  const c = Math.cos(angle), s = Math.sin(angle);
  const P = (px, py) => `${n(x + px * c - py * s)} ${n(y + px * s + py * c)}`;
  const width = (t) => W * Math.sin(Math.PI * Math.pow(t, 0.8)) * (0.35 + 0.65 * t);
  let up = `M${P(0, 0)}`, lo = '';
  const pts = [];
  for (let i = 1; i <= teeth; i++) {
    const t0 = (i - 1) / teeth, t1 = i / teeth;
    const tm = t0 + (t1 - t0) * 0.75;
    pts.push([t0 + (t1 - t0) * 0.2, 0.45], [tm, 1.0 + r() * 0.15]);
  }
  for (const [t, f] of pts) up += `L${P(t * L, width(t) * f)}`;
  up += `L${P(L, 0)}`;
  for (const [t, f] of [...pts].reverse()) lo += `L${P(t * L, -width(t) * f * 0.92)}`;
  return { outline: up + lo + `L${P(0, 0)}`, rib: `M${P(0, 0)}L${P(L * 0.9, 0)}` };
}

// Kleine Blattmarken als Heckentextur
function leafTexture({ x0, y0, x1, y1, step = 26, seed = 4, chaos = 0, clip = null, len = 10 }) {
  const r = rng(seed);
  let d = '';
  for (let yy = y0 + step / 2; yy < y1; yy += step * 0.8) {
    for (let xx = x0 + step / 2 + ((yy / step) % 2) * step * 0.5; xx < x1; xx += step) {
      const px = xx + (r() - 0.5) * step * (0.35 + chaos);
      const py = yy + (r() - 0.5) * step * (0.35 + chaos);
      if (clip && !clip(px, py)) continue;
      const a = rad(-90 + (r() - 0.5) * (50 + chaos * 160));
      const L = len * (0.8 + r() * 0.5 + chaos * 0.6);
      const ex = px + Math.cos(a) * L, ey = py + Math.sin(a) * L;
      const nx = -Math.sin(a) * L * 0.32, ny = Math.cos(a) * L * 0.32;
      d += `M${n(px)} ${n(py)}Q${n((px + ex) / 2 + nx)} ${n((py + ey) / 2 + ny)} ${n(ex)} ${n(ey)}`;
    }
  }
  return d;
}

const files = {};

// ---------------------------------------------------------------- 1 Zweig (allgemein)
{
  const b = branch({ p0: [210, 595], p1: [150, 430], p2: [285, 230], p3: [228, 40], nodes: 9, seed: 11, Lmax: 96, Lmin: 44 });
  files['zweig.svg'] = svgDoc(400, 600, drawBranch(b));
  files['zweig-hell.svg'] = svgDoc(400, 600, drawBranch(b), { stroke: '#B9CF9F' });
}
// ---------------------------------------------------------------- 2 Olivenzweig (Grabpflege)
{
  const b = branch({ p0: [60, 520], p1: [180, 420], p2: [300, 250], p3: [450, 70], nodes: 7, seed: 23, Lmax: 92, Lmin: 54, spread: 30, widthRatio: 0.12, opposite: true, bend: 0.1, startT: 0.12 });
  files['olivenzweig.svg'] = svgDoc(520, 560, drawBranch(b, 1.1), { sw: 1.1 });
}
// ---------------------------------------------------------------- 3 Gräser
{
  const d = grass({ x: 120, y: 236, count: 11, h: [90, 210], spread: 46, seed: 5, lean: 0.25 }) + grass({ x: 190, y: 236, count: 6, h: [60, 130], spread: 30, seed: 9, lean: -0.3 });
  files['graeser.svg'] = svgDoc(300, 240, path(d));
}
// ---------------------------------------------------------------- 4 Hecke vorher / nachher (Slider-Platzhalter)
{
  const W = 1200, H = 800, ground = 650;
  // nachher: klare Kubatur, gerade Kante, kurzer Rasen
  const hx0 = 190, hx1 = 1010, hy0 = 300;
  let after = path(`M${hx0} ${ground}V${hy0 + 18}Q${hx0} ${hy0} ${hx0 + 18} ${hy0}H${hx1 - 18}Q${hx1} ${hy0} ${hx1} ${hy0 + 18}V${ground}`, ' stroke-width="1.6"');
  after += path(leafTexture({ x0: hx0 + 8, y0: hy0 + 10, x1: hx1 - 8, y1: ground - 8, step: 30, seed: 7, len: 11 }), ' opacity=".7"');
  after += path(`M40 ${ground}H${W - 40}`, ' stroke-width="1.4"');
  let shortGrass = '';
  for (let x = 50; x < W - 40; x += 14) shortGrass += `M${x} ${ground + 4}l${(x % 3) - 1} 9`;
  after += path(shortGrass, ' opacity=".55"');
  after += path(`M${hx0 - 150} ${ground + 70}H${hx1 + 150}`, ' opacity=".35" stroke-dasharray="2 10"');
  files['hecke-nachher.svg'] = svgDoc(W, H, after, { bg: '#E3EAD8', title: 'Illustration: gepflegte, gerade geschnittene Hecke' });

  // vorher: wuchernde Kontur, abstehende Triebe, hohes Gras
  const r = rng(31);
  let contour = `M${hx0 - 30} ${ground}`;
  const pts = [];
  const steps = 19;
  for (let i = 0; i <= steps; i++) {
    const t = i / steps;
    const x = lerp(hx0 - 40, hx1 + 50, t);
    const top = 200 + Math.sin(t * Math.PI * 3.2) * 26 + (r() - 0.5) * 48 + (t < 0.08 || t > 0.92 ? 140 * (1 - Math.min(t, 1 - t) / 0.08) : 0);
    pts.push([x, Math.min(top, ground - 40)]);
  }
  contour += `L${n(pts[0][0])} ${n(pts[0][1] + 60)}`;
  for (let i = 1; i < pts.length; i++) {
    const [x0, y0] = pts[i - 1], [x1, y1] = pts[i];
    contour += `Q${n(lerp(x0, x1, 0.3 + r() * 0.4))} ${n(Math.min(y0, y1) - 10 - r() * 46)} ${n(x1)} ${n(y1)}`;
  }
  contour += `L${hx1 + 60} ${ground}`;
  let before = path(contour, ' stroke-width="1.5"');
  const inside = (px, py) => {
    const i = Math.max(0, Math.min(pts.length - 1, Math.round(((px - (hx0 - 40)) / (hx1 + 90 - hx0)) * steps)));
    return py > pts[i][1] + 22 && py < ground - 6;
  };
  before += path(leafTexture({ x0: hx0 - 30, y0: 170, x1: hx1 + 60, y1: ground, step: 24, seed: 13, chaos: 0.9, clip: inside, len: 12 }), ' opacity=".7"');
  // abstehende Triebe
  const shoots = [[300, 210, -100], [520, 180, -80], [700, 205, -60], [880, 190, -110], [980, 260, -30], [220, 300, -150]];
  shoots.forEach(([sx, sy, deg], i) => {
    const a = rad(deg);
    const L = 90 + (i % 3) * 30;
    const p3 = [sx + Math.cos(a) * L, sy + Math.sin(a) * L];
    const b = branch({ p0: [sx, sy + 30], p1: [sx + Math.cos(a) * L * 0.3, sy + Math.sin(a) * L * 0.3 + 10], p2: [sx + Math.cos(a) * L * 0.7, sy + Math.sin(a) * L * 0.7], p3, nodes: 4, seed: 40 + i, Lmax: 30, Lmin: 18, startT: 0.35 });
    before += drawBranch(b, 1.1);
  });
  before += path(`M40 ${ground}H${W - 40}`, ' stroke-width="1.4"');
  let tall = '';
  for (let x = 60; x < W - 40; x += 52) tall += grass({ x, y: ground + 2, count: 4, h: [30, 95], spread: 30, seed: x, lean: (x % 5) / 10 - 0.2 });
  before += path(tall, ' opacity=".8"');
  files['hecke-vorher.svg'] = svgDoc(W, H, before, { bg: '#E6DDCB', title: 'Illustration: zugewachsene, ungeschnittene Hecke' });
}

// ---------------------------------------------------------------- 5 Motive für Fotoplatzhalter (4:5, zentriert, beschneidbar)
const MW = 800, MH = 1000;
const motif = (name, body, bg) => {
  files[`motiv-${name}.svg`] = svgDoc(MW, MH, body, { bg, preserve: 'xMidYMid slice', sw: 1.3 });
};
// Hecke: geschnittener Block, Schnittlinie, fallende Blättchen
{
  let b = path(`M170 860V430Q170 410 190 410H610Q630 410 630 430V860`, ' stroke-width="1.6"');
  b += path(leafTexture({ x0: 180, y0: 420, x1: 620, y1: 850, step: 28, seed: 3, len: 11 }), ' opacity=".65"');
  b += path('M120 860H680', ' stroke-width="1.4"');
  b += path('M150 372H650', ' stroke-dasharray="3 9" opacity=".6"');
  const r = rng(77);
  for (let i = 0; i < 7; i++) {
    const l = leaf({ x: 230 + i * 60 + (r() - 0.5) * 30, y: 300 - r() * 160, angle: rad(r() * 360), L: 16 + r() * 10, W: 4.5, r });
    b += path(l.outline, ' opacity=".7"');
  }
  motif('hecke', b, '#DCE4D1');
}
// Rasen: Mähstreifen + Halme
{
  let b = '';
  for (let i = 0; i < 9; i++) {
    const y = 470 + i * i * 6 + i * 22;
    b += path(`M-20 ${y}Q400 ${y - 30 - i * 2} 820 ${y}`, ` opacity="${0.25 + i * 0.05}"`);
  }
  b += path(grass({ x: 210, y: 1000, count: 14, h: [120, 300], spread: 120, seed: 21, lean: 0.2 }));
  b += path(grass({ x: 600, y: 1000, count: 10, h: [100, 240], spread: 90, seed: 22, lean: -0.25 }));
  motif('rasen', b, '#E1E7D5');
}
// Unkraut: Rosette über Bodenlinie, Pfahlwurzel darunter
{
  const r = rng(51);
  let b = path('M60 600H740', ' stroke-width="1.4"');
  for (let i = 0; i < 8; i++) {
    const a = rad(-176 + i * (172 / 7) + (r() - 0.5) * 10);
    const L = 190 + r() * 90 - Math.abs(i - 3.5) * 8;
    const l = toothedLeaf({ x: 400, y: 597, angle: a, L, W: 26 + r() * 8, teeth: 5, r });
    b += path(l.outline, ' stroke-linejoin="miter"') + path(l.rib, ' stroke-width="0.9" opacity=".7"');
  }
  let root = 'M400 600C404 680 392 760 401 900';
  for (let i = 0; i < 9; i++) {
    const y = 640 + i * 28, side = i % 2 ? 1 : -1;
    root += `M${n(400 + (r() - 0.5) * 6)} ${y}q${side * 18} ${10 + r() * 10} ${side * (34 + r() * 30)} ${24 + r() * 18}`;
  }
  b += path(root, ' opacity=".75"');
  motif('unkraut', b, '#E6DFCF');
}
// Sträucher: Verzweigung, kuppelförmige Silhouette
{
  let b = path('M90 900H710', ' stroke-width="1.4"');
  const arms = [
    { p0: [400, 900], p1: [390, 760], p2: [300, 620], p3: [210, 470], seed: 61 },
    { p0: [400, 900], p1: [410, 720], p2: [420, 560], p3: [400, 330], seed: 62 },
    { p0: [400, 900], p1: [420, 760], p2: [520, 620], p3: [600, 460], seed: 63 },
    { p0: [400, 880], p1: [360, 800], p2: [230, 760], p3: [140, 680], seed: 64 },
    { p0: [400, 880], p1: [450, 800], p2: [570, 760], p3: [670, 690], seed: 65 },
  ];
  for (const a of arms) b += drawBranch(branch({ ...a, nodes: 7, Lmax: 58, Lmin: 34, startT: 0.25, widthRatio: 0.26 }), 1.2);
  b += path('M150 640Q170 330 400 300Q630 330 650 640', ' stroke-dasharray="2 12" opacity=".45"');
  motif('straeucher', b, '#DDE3D3');
}
// Allgemeine Gartenpflege: gefegte Blätter + Halme
{
  const r = rng(91);
  let b = path('M80 820H720', ' stroke-width="1.4"');
  for (let i = 0; i < 13; i++) {
    const cx = 260 + r() * 300, cy = 770 - r() * 120 + Math.abs(cx - 410) * 0.35;
    const L = 40 + r() * 46;
    const l = leaf({ x: cx, y: cy, angle: rad(-180 + r() * 360), L, W: L * 0.3, bend: (r() - 0.5) * 0.25, r, veins: 2 });
    b += path(l.outline) + path(l.rib, ' stroke-width="0.9" opacity=".7"');
  }
  b += path(grass({ x: 140, y: 820, count: 7, h: [60, 160], spread: 50, seed: 93, lean: 0.3 }));
  b += path(grass({ x: 660, y: 820, count: 6, h: [50, 140], spread: 40, seed: 94, lean: -0.3 }));
  b += drawBranch(branch({ p0: [600, 300], p1: [520, 260], p2: [430, 250], p3: [330, 190], nodes: 6, seed: 95, Lmax: 60, Lmin: 34, startT: 0.2 }), 1.2);
  motif('garten', b, '#E8E1D2');
}
// Grabpflege: ruhiger Olivenzweig
{
  const b = drawBranch(branch({ p0: [180, 860], p1: [290, 700], p2: [420, 480], p3: [560, 200], nodes: 8, seed: 23, Lmax: 120, Lmin: 64, spread: 30, widthRatio: 0.12, opposite: true, bend: 0.1, startT: 0.12 }), 1.15);
  motif('grab', b, '#E7E4DD');
}
// Detail: geschnittener Zweig (Schnittmotiv für Hero)
{
  let b = drawBranch(branch({ p0: [250, 760], p1: [330, 620], p2: [430, 470], p3: [560, 260], nodes: 6, seed: 101, Lmax: 110, Lmin: 60, startT: 0.25, veins: 3 }), 1.3);
  b += path('M226 790L276 736', ' stroke-width="1.6"');
  b += path('M205 812L190 828M246 838L230 852', ' opacity=".5"');
  motif('detail', b, '#DCE4D1');
}

for (const [name, svg] of Object.entries(files)) writeFileSync(join(OUT, name), svg);
console.log('ok', Object.keys(files).join(', '));
