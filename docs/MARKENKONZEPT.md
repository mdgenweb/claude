# [FIRMENNAME] – Markenkonzept & Designsystem

Gartenservice · Gartenpflege · Grabpflege · [ORT + EINSATZGEBIET]

---

## 1. Kurzfassung

**Positionierung:** Der Gartenservice, bei dem man sofort weiß, was er macht, wer kommt und wie man ihn erreicht. Er arbeitet ordentlich, kommuniziert klar und tritt modern auf, ohne abgehoben zu wirken.

**Leitidee: „Ordnung, die natürlich wirkt.“**
Jedes Gestaltungselement verbindet etwas Gewachsenes mit einer klaren, präzisen Kante. Das organische Blatt und der saubere Schnitt sind dasselbe, was der Kunde vom Service erwartet: Natur, die gepflegt aussieht.

**Gewünschte Wahrnehmung:**
„Das wirkt wie ein seriöser, moderner Gartenservice. Die kümmern sich ordentlich darum, ich weiß sofort, was sie anbieten, und ich kann unkompliziert jemanden erreichen.“

| Wir sind | Wir sind nicht |
|---|---|
| zuverlässig, ordentlich, sauber | Baumarkt-Werbung |
| nahbar, persönlich, unkompliziert | aggressiver Handwerker-Funnel |
| naturverbunden, ruhig | verspielter Blumenladen |
| professionell, modern | übertrieben luxuriöser Landschaftsarchitekt |

**Tonalität:** kurze Sätze, Kundennutzen zuerst, konkrete Verben (schneiden, mähen, jäten, aufräumen). Keine Superlative, keine Floskeln („Ihr kompetenter Partner“, „Alles aus einer Hand“). Grabpflege: leiser, zurückhaltend, ohne jede Werbesprache.

---

## 2. Logo-System – „Das Schnittblatt“

![Logo](../assets/brand/logo-primaer.svg)

**Idee:** Ein Blatt, dessen Spitze gerade geschnitten ist. Das Blatt steht für Natur und Wachstum, der präzise Schnitt für Formschnitt, Sorgfalt und Ordnung. Die negative Mittelrippe macht das Blatt auch in kleinen Größen eindeutig lesbar. Es ist keine Clipart, kein Haus und kein Rasenmäher, sondern eine eigenständige, langlebige Form.

**Konstruktion (64er-Raster):**
- Linsenblatt aus zwei Viertelkreisen mit r = 48, Blattachse 45° (Basis unten links, Spitze oben rechts)
- Schnitt rechtwinklig zur Blattachse bei 82 % der Achslänge
- Mittelrippe als sich verjüngende Aussparung (1,45 → 0,6 Einheiten), von 15 % bis 70 % der Achse
- Favicon-Variante mit kräftigerer Rippe (2,6 → 1,3) für 16–32 px

**Varianten** (alle in `assets/brand/`, reine Vektorpfade, Schrift in Kurven):

| Datei | Einsatz |
|---|---|
| `logo-primaer.svg` | Website-Header, Briefbogen, Rechnung, Angebote |
| `logo-kompakt.svg` (gestapelt) | Fahrzeugheck, Schilder, quadratische Flächen |
| `symbol.svg` | Stick auf Arbeitskleidung (Ärmel/Kappe), Stempel, Werkzeugmarkierung |
| `favicon.svg`, `assets/brand/apple-touch-icon.png` | Browser, Homescreen |
| `social-avatar.svg` | Profilbild Google Unternehmensprofil, Instagram, WhatsApp Business (kreisrund beschnitten) |
| `*-invers.svg` / `*-schwarz.svg` / `*-weiss.svg` | dunkle Flächen, Einfarbdruck, Folie, Gravur |

**Schutzraum:** rundum mindestens ½ Symbolhöhe.
**Mindestgrößen:** Primärlogo 120 px / 30 mm breit · Symbol 16 px / 6 mm.

**Anwendungen:**
- **Arbeitskleidung:** Symbol + Name einfarbig gestickt, Brust links, 7–9 cm breit. Rücken: kompaktes Logo, darunter die Telefonnummer.
- **Fahrzeug:** Seite mit Primärlogo invers auf Waldgrün oder Waldgrün auf Weiß, darunter in großer Schrift *Gartenpflege · [TELEFON]*. Heck: kompaktes Logo + Website.
- **Rechnung/Angebot:** Primärlogo oben links mit 25 mm Breite, Fließtext in Instrument Sans, Akzentlinie Blattgrün.
- **Visitenkarte:** Vorderseite Symbol groß auf Waldgrün, Rückseite Name, Telefon, WhatsApp, Website auf Leinen.

**Nicht erlaubt:** verzerren, Farben außerhalb der Palette, Schatten/Verläufe, Symbol drehen, Wortmarke in anderer Schrift setzen.

> Der Firmenname ist Platzhalter. Mit `python3 tools/build_brand.py "Echter Name"` werden alle Lockups neu gesetzt.

---

## 3. Farbsystem

| Name | Hex | Rolle |
|---|---|---|
| **Waldgrün** | `#1E3A2B` | Markenfarbe, dunkle Flächen, Akzent-Headlines, Symbol |
| Waldgrün tief | `#142A1E` | Footer |
| **Blattgrün** | `#7FA35E` | Ranke, Illustrationen, Aufzählungsblätter – nie für Fließtext |
| Blattgrün hell | `#B9CF9F` | Akzente auf Waldgrün |
| Salbei | `#DFE6D4` | Bildflächen, Hinweise |
| **Leinen** | `#F6F2EA` | Seitenhintergrund (warmes Off-White statt Reinweiß) |
| Leinen dunkel | `#EEE7DA` | Wechselflächen |
| Kalkstein | `#E9E6DF` | ausschließlich Grabpflege – kühler, ruhiger |
| **Anthrazit** | `#1B201D` | Text |
| Anthrazit 2 / 3 | `#3A433D` / `#56605A` | Fließtext (9,2 : 1) / Meta (5,8 : 1) |
| **Lehm** | `#A5502D` | ausschließlich primäre Anfrage-Aktionen (5,5 : 1 mit Weiß) |

**Regel:** Lehm ist die einzige warme Farbe und erscheint nur auf Schaltflächen, die zur Anfrage führen. Dadurch erkennt das Auge die Handlungsaufforderung sofort, ohne dass die Seite laut wird. Die Grabpflege bekommt bewusst keinen Lehm-Akzent.

---

## 4. Typografie

| Rolle | Schrift | Schnitt | Warum |
|---|---|---|---|
| Headlines | **Bricolage Grotesque** (variabel, optische Größen) | 560–600, −2,5 bis −3,5 % Laufweite | Charakterstarke Grotesk mit leicht handwerklichen Details. Hat Persönlichkeit, wirkt aber nicht verspielt. |
| Fließtext, UI | **Instrument Sans** (variabel) | 400–600 | Ruhig, offen, sehr gut lesbar auf Smartphones |

- Beide unter SIL Open Font License, **lokal gehostet** (`assets/fonts/`, zusammen ca. 107 KB)
- Skala (fluid): H1 42–84 px · H2 33–58 px · H3 24–33 px · Lead 18–21 px · Text 17 px · Label 13 px Versalien +14 %
- Kurze Absätze, maximal ca. 60 Zeichen pro Zeile, `text-wrap: balance` für Headlines
- Keine Texte unter 13 px, kein Hellgrau für Inhalte

---

## 5. UI-Designsystem

- **Raster:** 12 Spalten, maximal 1280 px Inhaltsbreite, Seitenrand 20–64 px (fluid)
- **Abstände:** Sektionen 88–160 px vertikal, Basis 8 px
- **Formen:** kleine Radien (4 / 8 px) für UI-Elemente. Für Bilder gibt es zwei Formen aus der Marke:
  - **Blattmaske:** zwei gerundete Ecken und eine schräg geschnittene Spitze, also das Logo als Bildform (`.mask-leaf`, `.mask-leaf--flip`)
  - **Bogen** für Personen und die Grabpflege (`.portrait__arch`, `.media--arch`)
- **Buttons:** Primär in Lehm mit weißer Schrift, sekundär als Outline in Waldgrün, auf dunklen Flächen hell. Mindesthöhe 44–58 px, keine Pillenform.
- **Links:** Waldgrün, die Unterstreichung wächst beim Hover von links, der Pfeil gleitet 4 px.
- **Formular:** 52 px Feldhöhe, sichtbare Labels, Pflichtfelder mit *, Fehlermeldungen in Klartext unter dem Feld, Arbeiten als Auswahl-Chips, Foto-Upload mit Vorschau.
- **Icons:** Linienstil, 24er-Raster, 1,6 px Strich, runde Enden, keine Flächen
- **Platzhalter:** getönte Fläche mit Papierkorn, Linienmotiv und dem Etikett „Foto folgt · Motiv“. Sie sind eindeutig als Platzhalter erkennbar und dienen gleichzeitig als Bildbriefing.

---

## 6. Bildsprache & Fotografie

Langfristig trägt **echte Fotografie des Unternehmens** die Seite. Bis dahin zeigen die Platzhalter, welches Motiv an welche Stelle gehört.

**Shotlist (Priorität):**
1. Inhaber-Porträt: freigestellt für den Hero (ragt aus dem Bogen) oder klassisch im Bogen. Natürliches Licht, Arbeitskleidung, Blick in die Kamera, kein Studio-Look.
2. Inhaber bei der Arbeit (Über uns): z. B. an einer Hecke, Hände und Werkzeug im Bild
3. Detail: Schere bzw. Heckenschere an einer Kante, frischer Schnitt
4. Vorher/Nachher: **gleicher Standpunkt, gleicher Ausschnitt, gleiche Brennweite.** Stativ oder Markierung am Boden.
5. Je Leistung ein Motiv: gerade geschnittene Hecke, gemähter Rasen mit Streifen, sauberes Beet, Strauch nach Rückschnitt, aufgeräumte Fläche
6. Grabpflege: ruhig, ohne Personen, ohne lesbare Inschriften, weiches Licht

**Vermeiden:** amerikanische Villengärten, offensichtliche Stockfotos, KI-generierte Menschen, Großbaustellen und Landschaftsbau, der nicht angeboten wird.
**Technik:** AVIF und WebP in 800/1200/1600 px, `width`/`height` setzen, `loading="lazy"` außer im Hero.

---

## 7. Botanische Illustrationen

Feine Linienzeichnungen (1,1–1,4 px) in Waldgrün oder Blattgrün: Zweige, Olivenzweig, Gräser, Rosette mit Wurzel, Hecke. Erzeugt mit `tools/botanics.mjs` aus wenigen Grundformen und festen Zufallswerten. Dadurch wirken sie gezeichnet und bleiben trotzdem einheitlich.

**Einsatz sparsam:** im Hero hinter dem Bogen, in den Bildplatzhaltern, im Ablauf (mobil) und als Ranke. Nie hinter Fließtext, nie dekorativ gestreut.

---

## 8. Bewegung

**Signature: „Der Garten wächst durch die Website.“**
Im Hero sitzt ein kleines gezeichnetes Blatt, die Linienform des Logos. Beim Scrollen wächst daraus eine feine Ranke:
- verläuft im Seitenrand und durch bewusste Lücken im Layout, **kreuzt nie Text**
- verschwindet hinter einigen Bildern (Hecke, Strauch, Porträt, Vorher/Nachher) und läuft vor anderen her (Detailbild, Rasen). So entsteht räumliche Tiefe.
- verzweigt sich bei den Leistungen und verbindet die vier Ablauf-Schritte
- bleibt im Grabpflege-Bereich ruhig, ohne Blätter
- endet über dem Anfrageformular mit wenigen kleinen Blättern
- **Stop-Motion-Charakter:** wächst in 9-px-Stufen mit ca. 14 Bildern pro Sekunde, Blätter erscheinen in drei Stufen. Einzelne Blätter wiegen sich danach sehr langsam (±3°, 7 s).
- **Technik:** SVG-Pfade, Route relativ zu Layout-Elementen (passt sich jeder Breite an), Teilpfade zur Entlastung des Renderings, kein Framework
- **Mobil/Tablet unter 1024 px:** keine Seitenranke. Im Ablauf zeichnet sich stattdessen beim Eintritt eine Linie, die die Schritte verbindet.
- **prefers-reduced-motion:** Die Ranke steht fertig gezeichnet da, es gibt keine Bewegung und keine Einblendungen.

**Microinteractions:** Buttons heben sich um 1 px mit weichem Schatten, Pfeile gleiten 3–4 px, Bilder zoomen beim Hover um 2,5 % über 1,4 s, Inhalte blenden einmalig mit 18 px Versatz ein, die Unterstreichung im Hero zeichnet sich nach dem Laden, FAQ-Antworten öffnen weich, und der Vorher/Nachher-Regler zeigt beim ersten Sichtkontakt einmal kurz seine Funktion.

---

## 9. Seitenarchitektur & Conversion

| # | Sektion | Beantwortete Kundenfrage |
|---|---|---|
| 1 | Hero: „Hecke, Rasen, Beete. Wir kümmern uns darum.“ | Was macht das Unternehmen? Wo? Was muss ich tun? |
| 2 | Vertrauenszone (6 überprüfbare Zusagen) | Kann ich denen vertrauen? Was kostet eine Anfrage? |
| 3 | Leistungen (Editorial-Blöcke 01–05) | Was genau übernehmen sie? |
| 4 | Über uns (fester Ansprechpartner) | Wer kommt zu mir? |
| 5 | Vorher/Nachher | Wie sehen deren Arbeiten aus? |
| 6 | Ablauf (4 Schritte) | Wie läuft die Anfrage ab? |
| 7 | Grabpflege (eigener, ruhiger Bereich) | Pflegen sie auch Gräber, und wie? |
| 8 | Kundenstimmen (vorbereitet, nur echte) | Was sagen andere? |
| 9 | Einsatzgebiet | Arbeiten die in meiner Gegend? |
| 10 | FAQ | Restliche Einwände |
| 11 | Abschluss + Formular | Kann ich unkompliziert Kontakt aufnehmen? |

**CTA-Strategie:** eine Hauptaktion, „Kostenlos anfragen“, in Lehm, an fünf Stellen (Header, Hero, Ablauf, Formular, mobile Leiste). Daneben immer Telefon und WhatsApp als gleichwertige direkte Wege. Bei jeder Leistung führt ein Link zur Anfrage und wählt die Leistung im Formular vor.

**Formular:** sechs Felder, davon vier Pflicht. Die Arbeiten werden als Chips gewählt statt getippt. Der Foto-Upload wird aktiv empfohlen. Fehler werden freundlich und erst beim Absenden angezeigt. Nach dem Absenden erscheint eine persönliche Bestätigung.

**Mobil:** Headline, Text, Hauptbutton und Telefon/WhatsApp liegen auf dem ersten Bildschirm. Eine dezente Kontaktleiste (Anrufen · WhatsApp · Anfrage) erscheint erst nach dem Hero und verschwindet am Formular und im Footer.

---

## 10. SEO-Struktur

- genau eine H1 je Seite, H2 pro Sektion, H3 für Leistungen, Schritte und FAQ
- individueller Title und Description mit Ort, Leistung und Nutzen
- JSON-LD: `LocalBusiness` mit Leistungskatalog und Einsatzgebiet, `FAQPage`. Auf Unterseiten zusätzlich `Service` und `BreadcrumbList`.
- Muster-Unterseite: `/heckenschnitt/`. Nach demselben Schema entstehen `/rasenpflege/`, `/unkraut-entfernen/`, `/gartenpflege/`, `/grabpflege/`, und erst bei echten Einsatzorten `/[ort]-gartenservice/`.
- interne Verlinkung: Leistung → Anfrage (mit Vorauswahl), Footer → alle Leistungen und Orte, Unterseite → Startseite/Einsatzgebiet
- Empfehlung: **Google Unternehmensprofil** mit identischem Namen, identischer Adresse und Telefonnummer (NAP) sowie echten Fotos. Bewertungen dort sammeln und später auf der Seite einbinden.
- `sitemap.xml`, `robots.txt`, Canonical, Open-Graph-Bild (`tools/og-card.html`)

---

## 11. Responsive

- **Desktop (ab 1240 px):** großzügig, asymmetrisch, editorial; volle Navigation, Ranke aktiv
- **Laptop/Tablet quer (1024–1239 px):** Navigation im Drawer, Raster bleibt, Ranke aktiv
- **Tablet (768–1023 px):** Hero-Text vor dem Bild, Leistungen zweispaltig, Formular einspaltig, keine Ranke
- **Smartphone (unter 768 px):** eigene Komposition: Text und Hauptbutton zuerst, Bilder teils randlos, Nummer und Titel bei Leistungen nebeneinander, Ablauf als vertikale Linie, Formularfelder untereinander, Kontaktleiste unten

---

## 12. Barrierefreiheit, Datenschutz, Performance

- **Barrierefreiheit:** Kontraste ≥ 4,5 : 1 für Text, sichtbarer Fokus (Lehm-Kontur), Skip-Link, vollständige Tastaturbedienung (Drawer mit Fokusfalle und Esc, Vorher/Nachher als echter Regler, FAQ mit nativem `details`), beschriftete Formularfelder mit verknüpften Fehlermeldungen, Bedienelemente ≥ 44 px, Information nie nur über Farbe. Automatisierter Test mit axe-core (WCAG 2.1 AA + Best Practices): **0 Verstöße** auf Desktop und Mobil.
- **DSGVO:** keine externen Anfragen beim Laden, keine Cookies, keine Tracker, Schriften lokal, abstrakte Einsatzkarte statt Google Maps. WhatsApp öffnet sich erst nach einem Klick. Ein Cookie-Banner ist deshalb nicht nötig. Impressum und Datenschutz liegen als Vorlage bei.
- **Performance:** kein Framework, ca. 32 KB JavaScript unkomprimiert (ca. 11 KB gzip), ein Stylesheet, Schriften vorgeladen, Bilder lazy, keine Videos. Die Animation läuft über SVG-Strich-Offsets in Teilpfaden mit gedrosselter Bildrate.

---

## 13. Freigabe-Liste – bitte vom Unternehmen bestätigen

Diese Formulierungen sind aus dem Briefing abgeleitet. Sie dürfen nur online gehen, wenn sie zutreffen:

- [ ] Persönlicher, fester Ansprechpartner „von der Anfrage bis zur fertigen Arbeit“
- [ ] „Keine Warteschleife, keine wechselnden Zuständigkeiten“
- [ ] Saubere Arbeitsweise („Nach der Arbeit sieht es ordentlich aus – auch drumherum“)
- [ ] Flexible Terminabsprache
- [ ] Einmalige **und** regelmäßige Pflege (auch Grabpflege: „Umfang und Häufigkeit besprechen wir“)
- [ ] Transparente Kommunikation und Angebot vor Beginn der Arbeit
- [ ] Besichtigung vor Ort „bei Bedarf“
- [ ] Kleinere Aufträge werden angenommen (FAQ)
- [ ] Rückschnitt zu breit gewordener Hecken
- [ ] Zitat des Inhabers (Textvorschlag) freigeben oder ersetzen
- [ ] „[NAME] meldet sich persönlich“
- [ ] Umgang mit Schnittgut (Unterseite Heckenschnitt, Platzhalter)

**Bewusst nicht behauptet:** Zahlen, Jahre Erfahrung, Bewertungen, Sterne, Referenzprojekte, Entsorgung, chemische Steinreinigung, Restaurierung, Reaktionszeiten.

---

## 14. Qualitätskontrolle

| Frage | Antwort |
|---|---|
| Individuelles Markenprojekt oder Template? | Eigene Logoform, aus der sich Bildmasken, Aufzählungszeichen, Favicon und Ranke ableiten. Eine eigene Illustrationssprache. Eine reservierte Akzentfarbe mit klarer Funktion. |
| In fünf Sekunden klar, was angeboten wird? | Die H1 nennt drei konkrete Arbeiten, die Unterzeile Ort und Art der Pflege. |
| Nächster Schritt sofort klar? | Ein einziger Lehm-Button mit „Kostenlos anfragen“, daneben Telefon und WhatsApp |
| Seriös genug für Zugang zum Grundstück? | Person sichtbar, Name, ruhige Gestaltung, keine Werbesprache, klare Abläufe, Impressum |
| Grabpflege respektvoll? | Eigener kühler Farbraum, leisere Typografie, kein Lehm, keine Ranke mit Blättern, sachliche Liste, ehrliche Abgrenzung im FAQ |
| Animationen elegant? | Eine einzige Signature-Bewegung, sonst nur einmalige, kurze Übergänge. Bei reduzierter Bewegung vollständig statisch. |
| Überladen? | Pro Sektion eine Idee, viel Leinen-Fläche, Illustrationen nur dort, wo Bilder hingehören |
| Konkrete Texte? | Verben und Gegenstände statt Adjektive. Keine Floskel aus der Verbotsliste. |
| Mobil gleichwertig? | Eigene Reihenfolge und Komposition, Kontaktleiste, Linie im Ablauf, große Touch-Ziele |
| Erfundene Behauptungen? | Keine. Zu bestätigende Aussagen stehen in Abschnitt 13, alle Fakten sind Platzhalter. |
| Erweiterbar mit echten Fotos und Bewertungen? | Platzhalter mit festen Seitenverhältnissen. Bewertungs-Komponente ist fertig vorbereitet. Projekte lassen sich als weitere Vergleiche ergänzen. |
