// Flächige Leistungs-Illustrationen (Spot-Illustrationen) im Markenstil.
//   node tools/spots.mjs  →  assets/img/spots/*.svg
// Wenige Farben, klare Formen, je Leistung eine kleine Geschichte:
// geschnittene Hecke, halb gemähter Rasen, gezogenes Unkraut, rückgeschnittener
// Strauch, aufgeräumtes Beet, ruhige Grabpflege.

import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const OUT = join(ROOT, 'assets', 'img', 'spots');
mkdirSync(OUT, { recursive: true });

const C = {
  night: '#0E1D15', forest: '#1E3A2B', moss: '#2F5A3C', grass: '#4E7F45',
  leaf: '#8DB86A', leaf2: '#7AA65A', soft: '#B9CF9F', pale: '#DCE8CC',
  linen: '#F4F0E6', sand: '#E6DAC4', soil: '#9C7A57', soilDark: '#6E5238',
  clay: '#AE542D', stone: '#C9C4B8', stoneDark: '#A9A397',
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
const W = 480, H = 360;
const doc = (bg, body, label) =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" role="img" aria-label="${label}"><rect width="${W}" height="${H}" fill="${bg}"/>${body}</svg>\n`;

// kleine Blattform als Pfad (für Texturen)
const leafD = (x, y, len, ang) => {
  const c = Math.cos(ang), s = Math.sin(ang), w = len * 0.42;
  const P = (px, py) => `${n(x + px * c - py * s)} ${n(y + px * s + py * c)}`;
  return `M${P(0, 0)}Q${P(len * 0.5, w)} ${P(len, 0)}Q${P(len * 0.5, -w)} ${P(0, 0)}Z`;
};
const leafAt = (x, y, len, ang, fill) => `<path fill="${fill}" d="${leafD(x, y, len, ang)}"/>`;
// Laubtextur innerhalb eines Rechtecks – je Farbe ein einziger Pfad (klein, schnell)
const texture = (x0, y0, x1, y1, fills, seed, density = 0.012, size = [10, 16]) => {
  const r = rng(seed);
  const groups = fills.map(() => []);
  const count = Math.round((x1 - x0) * (y1 - y0) * density);
  for (let i = 0; i < count; i++) {
    const x = x0 + r() * (x1 - x0), y = y0 + r() * (y1 - y0);
    const len = size[0] + r() * (size[1] - size[0]), ang = -Math.PI / 2 + (r() - 0.5) * 1.6;
    groups[Math.floor(r() * fills.length)].push(leafD(x, y, len, ang));
  }
  return groups.map((g, i) => (g.length ? `<path fill="${fills[i]}" d="${g.join('')}"/>` : '')).join('');
};
// Grashalm-Dreiecke entlang einer Linie
const blades = (x0, x1, y, hMin, hMax, fill, seed, step = 7) => {
  const r = rng(seed);
  let d = '';
  for (let x = x0; x < x1; x += step * (0.6 + r() * 0.8)) {
    const h = hMin + r() * (hMax - hMin), lean = (r() - 0.5) * h * 0.5, w = 3 + r() * 3;
    d += `M${n(x - w)} ${y}L${n(x + lean)} ${n(y - h)}L${n(x + w)} ${y}Z`;
  }
  return `<path fill="${fill}" d="${d}"/>`;
};

const files = {};

// 1 Heckenschnitt – geschnittener Block, abgehobener Schnitt, fallende Blätter
{
  let b = '';
  b += `<rect y="276" width="${W}" height="84" fill="${C.leaf}"/>`;
  for (let i = 0; i < 6; i++) b += `<rect x="${i * 80}" y="276" width="40" height="84" fill="${C.leaf2}" opacity=".55"/>`;
  b += `<rect x="58" y="126" width="250" height="160" rx="16" fill="${C.forest}"/>`;
  b += texture(70, 136, 296, 278, [C.moss, '#25472F'], 3, 0.01, [9, 15]);
  b += `<rect x="318" y="168" width="112" height="118" rx="16" fill="${C.moss}"/>`;
  b += texture(326, 176, 422, 278, [C.grass, '#3B6A3F'], 4, 0.012, [8, 13]);
  // abgeschnittene Kappe, leicht angehoben
  b += `<path d="M58 104c0-8 6-14 14-14h222c8 0 14 6 14 14v8H58z" fill="${C.grass}" transform="translate(0 -14) rotate(-2 180 100)"/>`;
  b += `<path d="M40 118H446" stroke="${C.clay}" stroke-width="3" stroke-dasharray="10 8" stroke-linecap="round"/>`;
  const r = rng(9);
  for (let i = 0; i < 9; i++) b += leafAt(90 + r() * 300, 40 + r() * 40, 12 + r() * 6, r() * 6.28, i % 2 ? C.leaf : C.grass);
  files['heckenschnitt.svg'] = doc('#CFE0BC', b, 'Illustration: gerade geschnittene Hecke');
}

// 2 Rasenpflege – gemähte Streifen links, hohes Gras rechts
{
  let b = '';
  b += `<path d="M0 120H${W}V${H}H0z" fill="${C.leaf}"/>`;
  // Streifen in Perspektive
  for (let i = 0; i < 8; i++) {
    const xTop = i * 60, xBot = -120 + i * 90;
    if (i % 2 === 0) b += `<path d="M${xTop} 120H${xTop + 60}L${xBot + 90} ${H}H${xBot}Z" fill="${C.leaf2}"/>`;
  }
  // ungemähter Bereich rechts
  b += `<path d="M330 120H${W}V${H}H285Z" fill="${C.grass}"/>`;
  b += blades(300, 490, 360, 40, 110, C.moss, 21, 6);
  b += blades(330, 490, 250, 30, 70, C.moss, 22, 7);
  b += blades(345, 490, 170, 20, 46, C.moss, 23, 8);
  // Mähkante
  b += `<path d="M330 120L285 ${H}" stroke="${C.linen}" stroke-width="3" opacity=".7"/>`;
  // Schnittgut
  const r = rng(31);
  for (let i = 0; i < 16; i++) { const x = 250 + r() * 70, y = 130 + r() * 200; b += `<rect x="${n(x)}" y="${n(y)}" width="8" height="2.4" rx="1.2" fill="${C.pale}" transform="rotate(${n(r() * 180)} ${n(x)} ${n(y)})"/>`; }
  files['rasenpflege.svg'] = doc('#DCE8CC', b, 'Illustration: halb gemähter Rasen mit Streifen');
}

// 3 Unkraut entfernen – Rosette ist samt Pfahlwurzel herausgezogen
{
  let b = '';
  b += `<rect y="236" width="${W}" height="124" fill="${C.soil}"/>`;
  b += `<rect y="236" width="${W}" height="14" fill="${C.soilDark}" opacity=".35"/>`;
  const r = rng(41);
  for (let i = 0; i < 40; i++) b += `<circle cx="${n(r() * W)}" cy="${n(256 + r() * 100)}" r="${n(1.5 + r() * 2.5)}" fill="${C.soilDark}" opacity=".45"/>`;
  // Loch, aus dem die Pflanze kam
  b += `<ellipse cx="240" cy="244" rx="34" ry="9" fill="#4E3A28"/>`;
  // fallende Erdkrümel
  for (let i = 0; i < 7; i++) b += `<circle cx="${n(226 + r() * 28)}" cy="${n(196 + r() * 34)}" r="${n(2 + r() * 2)}" fill="${C.soilDark}"/>`;
  // Pfahlwurzel, hängt frei
  b += `<path d="M240 128C243 150 236 168 240 214" stroke="${C.soilDark}" stroke-width="6" stroke-linecap="round" fill="none"/>`;
  b += `<path d="M240 154l-18 12M240 168l20 10M239 184l-14 10M241 198l12 8" stroke="${C.soilDark}" stroke-width="2.5" stroke-linecap="round"/>`;
  // Rosette (gezähnte Blätter)
  const CX = 240, CY = 122;
  const k2 = (a) => (Math.round(a * 10) % 2 ? C.leaf : C.grass);
  const tooth = (ang, L) => {
    const c = Math.cos(ang), s = Math.sin(ang), w = L * 0.16;
    const P = (px, py) => `${n(CX + px * c - py * s)} ${n(CY + px * s + py * c)}`;
    let d = `M${P(0, 0)}`;
    for (let k = 1; k <= 5; k++) { const t = k / 5; d += `L${P(L * (t - 0.12), w * (1.1 - t * 0.5))}L${P(L * t, w * 0.35)}`; }
    d += `L${P(L, 0)}`;
    for (let k = 5; k >= 1; k--) { const t = k / 5; d += `L${P(L * t, -w * 0.35)}L${P(L * (t - 0.12), -w * (1.1 - t * 0.5))}`; }
    return `<path d="${d}Z" fill="${k2(ang)}"/>`;
  };
  for (let i = 0; i < 9; i++) b += tooth(-Math.PI + 0.2 + i * (Math.PI - 0.4) / 8, 78 + (i % 3) * 12);
  b += `<circle cx="${CX}" cy="${CY - 10}" r="12" fill="#E3B23C"/><circle cx="${CX}" cy="${CY - 10}" r="5" fill="#C9922A"/>`;
  // Pfeil nach oben
  b += `<path d="M352 196V96" stroke="${C.clay}" stroke-width="3" stroke-linecap="round"/><path d="M340 108l12-14 12 14" stroke="${C.clay}" stroke-width="3" fill="none" stroke-linecap="round" stroke-linejoin="round"/>`;
  files['unkraut.svg'] = doc('#EADFCB', b, 'Illustration: Unkraut samt Wurzel entfernt');
}

// 4 Sträucher – links wild, rechts in Form geschnitten
{
  let b = '';
  b += `<rect y="286" width="${W}" height="74" fill="${C.leaf}"/>`;
  const r = rng(51);
  // wilde Hälfte
  for (let i = 0; i < 26; i++) {
    const a = Math.PI + r() * Math.PI * 0.5, rad = 70 + r() * 70;
    const x = 240 + Math.cos(a) * rad * 0.9, y = 230 + Math.sin(a) * rad * 0.9;
    b += `<circle cx="${n(x)}" cy="${n(y)}" r="${n(22 + r() * 18)}" fill="${[C.forest, C.moss, C.grass][i % 3]}"/>`;
  }
  b += `<path d="M120 150l-26-40M150 120l-8-46M186 104l6-42M108 196l-44-16" stroke="${C.moss}" stroke-width="4" stroke-linecap="round"/>`;
  b += leafAt(94, 110, 18, -2.2, C.grass) + leafAt(142, 74, 18, -1.8, C.grass) + leafAt(192, 62, 18, -1.4, C.grass) + leafAt(64, 180, 18, -2.8, C.grass);
  // geschnittene Hälfte: glatte Kuppel
  b += `<path d="M240 100A150 150 0 0 1 390 250V290H240Z" fill="${C.forest}"/>`;
  b += texture(250, 120, 380, 284, [C.moss, '#25472F'], 52, 0.009, [10, 15]);
  b += `<path d="M240 286V98" stroke="${C.clay}" stroke-width="3" stroke-dasharray="9 7"/>`;
  b += `<path d="M90 250A150 150 0 0 1 240 100" stroke="${C.clay}" stroke-width="3" stroke-dasharray="9 7" fill="none"/>`;
  files['straeucher.svg'] = doc('#D6E3C6', b, 'Illustration: Strauch, zur Hälfte in Form geschnitten');
}

// 5 Allgemeine Gartenpflege – aufgeräumtes Beet, Weg, Rechen im Laubhaufen
{
  let b = '';
  b += `<rect y="140" width="${W}" height="220" fill="${C.leaf}"/>`;
  b += `<path d="M30 206h420l-18 108H48z" fill="${C.soilDark}"/>`;
  const r = rng(61);
  for (let row = 0; row < 3; row++) {
    for (let i = 0; i < 7; i++) {
      const x = 80 + i * 54 + row * 6, y = 232 + row * 30;
      b += `<circle cx="${x}" cy="${y}" r="${12 - row}" fill="${row === 1 ? C.grass : C.moss}"/>`;
      b += leafAt(x - 2, y - 6, 11, -2.2, C.leaf) + leafAt(x + 2, y - 6, 11, -0.9, C.leaf);
    }
  }
  for (let i = 0; i < 5; i++) b += `<ellipse cx="${60 + i * 90}" cy="${338 - (i % 2) * 4}" rx="30" ry="9" fill="${C.linen}" opacity=".9"/>`;
  // Rechen, Zinken im Laub
  const E = [334, 186], d = [0.406, 0.914], p = [0.914, -0.406];
  b += `<path d="M${n(E[0] - d[0] * 160)} ${n(E[1] - d[1] * 160)}L${E[0]} ${E[1]}" stroke="#8A6744" stroke-width="5" stroke-linecap="round"/>`;
  let head = `M${n(E[0] - p[0] * 26)} ${n(E[1] - p[1] * 26)}L${n(E[0] + p[0] * 26)} ${n(E[1] + p[1] * 26)}`;
  for (let k = -2; k <= 2; k++) { const q = [E[0] + p[0] * k * 12, E[1] + p[1] * k * 12]; head += `M${n(q[0])} ${n(q[1])}l${n(d[0] * 13)} ${n(d[1] * 13)}`; }
  b += `<path d="${head}" stroke="${C.forest}" stroke-width="4" stroke-linecap="round"/>`;
  // Laubhaufen
  for (let i = 0; i < 22; i++) b += leafAt(352 + r() * 88, 162 + r() * 28, 15 + r() * 6, r() * 6.28, [C.clay, '#C9763F', C.leaf2, '#D99A4E'][i % 4]);
  for (let i = 0; i < 4; i++) b += leafAt(300 + r() * 40, 178 + r() * 18, 13, r() * 6.28, ['#C9763F', C.clay][i % 2]);
  files['gartenpflege.svg'] = doc('#ECE6D8', b, 'Illustration: aufgeräumtes Beet mit Weg und Rechen');
}

// 6 Grabpflege – ruhig, gedämpft: Bogen in Stein, Olivenzweig
{
  let b = '';
  b += `<rect y="276" width="${W}" height="84" fill="#D6D1C6"/>`;
  b += `<path d="M168 286V150A72 72 0 0 1 312 150V286Z" fill="${C.stone}"/>`;
  b += `<path d="M180 286V152A60 60 0 0 1 300 152V286" fill="none" stroke="${C.stoneDark}" stroke-width="2"/>`;
  const r = rng(71);
  for (let i = 0; i < 60; i++) b += `<circle cx="${n(130 + r() * 220)}" cy="${n(292 + r() * 52)}" r="${n(2 + r() * 2.5)}" fill="${['#BEB8AC', '#CFC9BD', '#B1AB9F'][i % 3]}"/>`;
  // Olivenzweig
  let stem = 'M118 330C170 300 230 286 300 252';
  b += `<path d="${stem}" stroke="${C.forest}" stroke-width="3" fill="none" stroke-linecap="round"/>`;
  for (let i = 0; i < 7; i++) {
    const t = 0.15 + i * 0.12, x = 118 + t * 182, y = 330 - t * 78;
    b += leafAt(x, y, 30, -0.9 - (i % 2) * 0.8, i % 2 ? '#4F6E57' : '#3E5C47');
  }
  files['grabpflege.svg'] = doc('#E7E3DA', b, 'Illustration: ruhige Grabstätte mit Olivenzweig');
}

// 7 Vorher / Nachher – gleiche Szene, 1200 × 800 (wird je nach Format beschnitten)
{
  const BW = 1200, BH = 800;
  const wide = (bg, body, label) =>
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${BW} ${BH}" role="img" aria-label="${label}"><rect width="${BW}" height="${BH}" fill="${bg}"/>${body}</svg>\n`;
  // Hintergrund: weiche Baumkronen, Rasenfläche
  const backdrop = () => {
    let b = '';
    const r = rng(81);
    for (let i = 0; i < 9; i++) b += `<circle cx="${n(i * 150 + r() * 60)}" cy="${n(330 + r() * 60)}" r="${n(110 + r() * 50)}" fill="#D3E2C2"/>`;
    b += `<rect y="400" width="${BW}" height="${BH - 400}" fill="#D3E2C2"/>`;
    return b;
  };
  // Vorher
  {
    let b = backdrop();
    b += `<rect y="560" width="${BW}" height="240" fill="${C.leaf2}"/>`;
    const r = rng(82);
    // Hecke: ausgefranste Wolkenform
    b += `<path d="M120 590V330H1080V590Z" fill="${C.forest}"/>`;
    for (let i = 0; i < 18; i++) {
      const x = 120 + i * 57 + r() * 20, y = 300 + r() * 70;
      b += `<circle cx="${n(x)}" cy="${n(y)}" r="${n(48 + r() * 34)}" fill="${[C.forest, C.moss, '#25472F'][i % 3]}"/>`;
    }
    for (let i = 0; i < 6; i++) {
      const left = i < 3, x = left ? 120 - r() * 30 : 1080 + r() * 30, y = 360 + (i % 3) * 70 + r() * 20;
      b += `<circle cx="${n(x)}" cy="${n(y)}" r="${n(44 + r() * 20)}" fill="${[C.forest, C.moss][i % 2]}"/>`;
    }
    b += texture(110, 250, 1090, 580, [C.grass, '#3B6A3F', C.moss], 83, 0.0022, [16, 26]);
    // abstehende Triebe
    const shoot = (x, y, len, ang) => {
      const ex = x + Math.cos(ang) * len, ey = y + Math.sin(ang) * len;
      let o = `<path d="M${n(x)} ${n(y)}Q${n((x + ex) / 2 + 14)} ${n((y + ey) / 2)} ${n(ex)} ${n(ey)}" stroke="${C.moss}" stroke-width="5" fill="none" stroke-linecap="round"/>`;
      for (let k = 1; k <= 3; k++) { const t = k / 3.4; o += leafAt(x + (ex - x) * t, y + (ey - y) * t, 24, ang + (k % 2 ? -0.9 : 0.9), C.grass); }
      return o + leafAt(ex, ey, 26, ang, C.leaf2);
    };
    for (let i = 0; i < 12; i++) b += shoot(170 + i * 78 + r() * 30, 280 + r() * 30, 70 + r() * 90, -Math.PI / 2 + (r() - 0.5) * 1.2);
    b += shoot(110, 420, 110, Math.PI + 0.3) + shoot(1090, 400, 120, -0.25) + shoot(1085, 500, 90, 0.2);
    // hohes, ungleichmäßiges Gras und Löwenzahn
    b += blades(0, 1210, 800, 70, 150, C.grass, 84, 9);
    b += blades(0, 1210, 700, 50, 110, '#5E8E4E', 85, 11);
    b += blades(0, 1210, 620, 40, 80, C.grass, 86, 12);
    for (let i = 0; i < 7; i++) {
      const x = 80 + i * 170 + r() * 60, y = 640 + r() * 120;
      b += `<path d="M${n(x)} ${n(y)}V${n(y - 70)}" stroke="${C.moss}" stroke-width="3"/><circle cx="${n(x)}" cy="${n(y - 74)}" r="11" fill="#E3B23C"/>`;
    }
    files['vorher.svg'] = wide('#E9F0DE', b, 'Illustration: zugewachsene Hecke und hoher Rasen');
  }
  // Nachher
  {
    let b = backdrop();
    b += `<rect y="560" width="${BW}" height="240" fill="${C.leaf}"/>`;
    for (let i = 0; i < 10; i++) if (i % 2 === 0) b += `<path d="M${i * 120} 560H${i * 120 + 120}L${i * 140 - 60 + 140} 800H${i * 140 - 60}Z" fill="${C.leaf2}"/>`;
    // Pflanzstreifen vor der Hecke
    b += `<path d="M150 574H1050L1070 600H130Z" fill="${C.soilDark}"/>`;
    // Hecke: klare Form, Oberseite heller
    b += `<rect x="170" y="290" width="860" height="290" rx="14" fill="${C.forest}"/>`;
    b += `<path d="M184 290H1016Q1030 290 1030 304V318H170V304Q170 290 184 290Z" fill="${C.moss}"/>`;
    b += texture(184, 324, 1016, 570, [C.moss, '#25472F'], 87, 0.0024, [16, 24]);
    // feine Schnittkante
    b += `<path d="M170 318H1030" stroke="${C.grass}" stroke-width="3"/>`;
    files['nachher.svg'] = wide('#E9F0DE', b, 'Illustration: gerade geschnittene Hecke und gemähter Rasen');
  }
}

for (const [name, svg] of Object.entries(files)) writeFileSync(join(OUT, name), svg);
console.log('ok', Object.keys(files).join(', '));
