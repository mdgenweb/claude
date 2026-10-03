# [FIRMENNAME] – Markenkonzept & Designsystem

Gartenservice · Gartenpflege · Grabpflege · [ORT + EINSATZGEBIET]

> **Version 2 – „Kraft & Ordnung“** (aktuell): Nike-inspiriert, kräftige Versalien, Nachtgrün, generativer Rasen-Hero, viel Bewegung.
> Version 1 – „ruhig & editorial“ mit der Scroll-Ranke liegt im Git-Verlauf (Commit `cbaf5ca`).

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
| **Nachtgrün** | `#0E1D15` | das „Schwarz“ der Marke: Hero, Leistungen, Ablauf, Einsatzgebiet, Footer |
| **Waldgrün** | `#1E3A2B` | Logo, Anfrage-Bereich |
| Karte | `#15281C` | Leistungskarten auf Nachtgrün |
| **Blattgrün** | `#8DB86A` | Akzent auf Dunkel (7,6 : 1), Marquee-Band, Ziffern, Linien |
| Blattgrün hell | `#B9CF9F` | Linienzeichnungen auf Dunkel |
| Blattgrün Text | `#426A2F` | Labels auf hellem Grund (≥ 5 : 1) |
| **Leinen** | `#F4F0E6` | heller Grund, Text auf Dunkel (15 : 1) |
| Leinen dunkel / Kalkstein | `#ECE6D8` / `#E7E3DA` | Wechselflächen / ausschließlich Grabpflege |
| **Anthrazit** | `#121814` | Text auf Hell |
| **Lehm** | `#AE542D` | ausschließlich primäre Anfrage-Aktionen (5,1 : 1 mit Weiß) |

**Regel:** Dunkle und helle Sektionen wechseln sich ab, damit die Seite Rhythmus bekommt. Lehm ist die einzige warme Farbe und erscheint nur auf Schaltflächen, die zur Anfrage führen. Die Grabpflege bleibt hell, kühl und ohne Lehm.

---

## 4. Typografie

| Rolle | Schrift | Schnitt | Einsatz |
|---|---|---|---|
| Display | **Bricolage Grotesque Condensed** | 800, Versalien, Breite 75 %, Zeilenabstand 0,8–0,86 | Hero „HECKE. RASEN. BEETE.“, Sektionstitel, Ziffern, Marquee, Footer-Wortmarke |
| Satz-Headlines | **Bricolage Grotesque** | 600, normale Breite | Claims, H2-Sätze, Kartentitel, FAQ |
| Fließtext, UI | **Instrument Sans** | 400–600 | Text, Buttons, Formular |

- beide SIL OFL, **lokal gehostet**: Bricolage mit Breiten-Achse (78 KB) + Instrument Sans (30 KB)
- die Riesentypo im Hero und die Footer-Wortmarke werden per Skript exakt auf die verfügbare Breite gesetzt
- kurze Versalien-Titel (2–4 Wörter) für Energie, ganze Sätze immer in normaler Breite für Lesbarkeit

---

## 5. UI-Designsystem

- **Raster:** maximal 1360 px Inhaltsbreite, Seitenrand 16–64 px (fluid)
- **Buttons:** Pill-Form. Beim Hover wischt eine zweite Farbe von unten herein, der Pfeil gleitet 4 px, und auf dem Desktop folgt der Button leicht dem Zeiger (magnetisch). Primär ist Lehm; sekundär Outline-Pills, auf Dunkel hell.
- **Karten:** Leistungen als dunkle Karten (10 px Radius) mit heller Linienzeichnung, großer Ziffer und „Anfragen →“
- **Bogen:** Personen- und Grabpflege-Bilder im Rundbogen
- **Formular:** 54 px Felder mit 14 px Radius, Auswahl-Chips als Pills (das Blatt aus dem Logo als Häkchen), Foto-Upload mit Vorschau
- **Icons:** Linienstil, 24er-Raster, 1,7 px Strich
- **Platzhalter:** gestrichelte Etiketten „Foto folgt“ – eindeutig, aber unaufdringlich

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

**Einsatz:** in hellen Linien auf den dunklen Leistungskarten, im Porträt-Bogen, in der Grabpflege und als Vorher/Nachher-Illustration. Nie hinter Fließtext, nie dekorativ gestreut.

---

## 8. Bewegung

**Signature: „Scrollen = Mähen.“**
Der Hero zeigt ein generatives Rasenfeld (Canvas 2D):
- beim Laden wachsen die Halme hoch, und die Wörter „HECKE. RASEN. BEETE.“ steigen aus dem Gras
- die Halme wiegen sich im Wind und weichen dem Mauszeiger aus
- beim Scrollen fährt eine unsichtbare Mählinie von links nach rechts: Die Halme werden gekürzt, Mähstreifen entstehen, Schnittgut fliegt, und die Headline steht vollständig frei
- zwei Ebenen: dichtes Gras hinter der Schrift, einzelne Halme davor (Tiefe)
- läuft nur, solange der Hero sichtbar ist; Pixeldichte auf 2 begrenzt; auf dem Smartphone etwa halb so viele Halme

**Weitere Effekte:**
| Effekt | Wo |
|---|---|
| Marquee-Band, dessen Tempo und Richtung dem Scrollen folgen | unter dem Hero |
| Text-Scrub: Wörter werden beim Lesen kräftig | Statement |
| rollende Ziffern wie ein Zählwerk (6 · 1 · 0 €) | Fakten |
| fixierte Galerie: vertikales Scrollen bewegt die Leistungskarten seitwärts (Desktop), Wischen mit Einrasten (Mobil) | Leistungen |
| Wort-für-Wort-Reveal aus einer Maske | alle Display-Titel |
| Bild-Reveal von unten | Über uns |
| wachsende Linie, Ziffern füllen sich, Blätter springen an | Ablauf |
| Karte zeichnet sich, Puls um den Ort | Einsatzgebiet |
| rotierendes Badge „Kostenlos · unverbindlich“ | Hero |
| Header blendet beim Runterscrollen aus und passt sich hell/dunkel an | überall |
| Vollbild-Menü mit gestaffelten Versalien | Mobil/Tablet |

**Grenzen:** Die Grabpflege bekommt nur ein ruhiges Einblenden. Alle Effekte nutzen transform/opacity und einen gemeinsamen Takt. Bei **prefers-reduced-motion** gibt es keine dieser Bewegungen: Der Rasen steht als ruhiges Standbild (halb gemäht), alle Inhalte sind sofort sichtbar.

---

## 9. Seitenarchitektur & Conversion

| # | Sektion | Beantwortete Kundenfrage |
|---|---|---|
| 1 | Hero: „HECKE. RASEN. BEETE.“ + „Wir kümmern uns darum.“ | Was macht das Unternehmen? Wo? Was muss ich tun? |
| 2 | Marquee mit allen Leistungen | Was gibt es alles? |
| 3 | Statement, Fakten (6 Leistungen · 1 Ansprechpartner · 0 € Anfrage), Zusagen | Kann ich vertrauen? Was kostet eine Anfrage? |
| 4 | Leistungen als Galerie (01–06) | Was genau übernehmen sie? |
| 5 | Vorher/Nachher | Wie sehen deren Arbeiten aus? |
| 6 | Über uns | Wer kommt zu mir? |
| 7 | Ablauf (4 Schritte) | Wie läuft die Anfrage ab? |
| 8 | Grabpflege (ruhig) | Pflegen sie auch Gräber, und wie? |
| 9 | Kundenstimmen (vorbereitet, nur echte) | Was sagen andere? |
| 10 | Einsatzgebiet | Arbeiten die in meiner Gegend? |
| 11 | FAQ | Restliche Einwände |
| 12 | „IHR GARTEN KÖNNTE WIEDER ETWAS PFLEGE GEBRAUCHEN?“ + Formular | Kann ich unkompliziert Kontakt aufnehmen? |

Die Fakten sind keine erfundenen Kennzahlen, sondern überprüfbare Aussagen aus dem Briefing.

**CTA-Strategie:** eine Hauptaktion, „Kostenlos anfragen“, als Lehm-Pill im Header, im Hero, im Ablauf, im Formular und in der mobilen Leiste. Dazu das rotierende Badge im Hero. Telefon und WhatsApp sind immer gleichwertig erreichbar. Jede Leistungskarte führt zur Anfrage und wählt die Leistung im Formular vor.

**Mobil:** Claim, Text, Hauptbutton und Telefon/WhatsApp auf dem ersten Bildschirm, darunter die gestapelte Riesentypo im Gras. Die dunkle Kontaktleiste (Anrufen · WhatsApp · Anfrage) erscheint erst nach dem Hero.

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

- **Desktop (ab 1240 px):** volle Navigation, Riesentypo einzeilig, fixierte Leistungs-Galerie
- **Laptop (1024–1239 px):** Navigation im Vollbild-Menü, Galerie weiterhin fixiert (ab 620 px Fensterhöhe)
- **Tablet (768–1023 px):** einspaltige Sektionen, Galerie zum Wischen mit Einrasten
- **Smartphone (unter 768 px):** Riesentypo dreizeilig gestapelt, weniger Halme, Fakten als Zeilen, randloses Vorher/Nachher, Kontaktleiste unten

---

## 12. Barrierefreiheit, Datenschutz, Performance

- **Barrierefreiheit:** Kontraste ≥ 4,5 : 1 für Text, sichtbarer Fokus (Lehm-Kontur), Skip-Link, vollständige Tastaturbedienung (Drawer mit Fokusfalle und Esc, Vorher/Nachher als echter Regler, FAQ mit nativem `details`), beschriftete Formularfelder mit verknüpften Fehlermeldungen, Bedienelemente ≥ 44 px, Information nie nur über Farbe. Automatisierter Test mit axe-core (WCAG 2.1 AA + Best Practices): **0 Verstöße** auf Desktop und Mobil.
- **DSGVO:** keine externen Anfragen beim Laden, keine Cookies, keine Tracker, Schriften lokal, abstrakte Einsatzkarte statt Google Maps. WhatsApp öffnet sich erst nach einem Klick. Ein Cookie-Banner ist deshalb nicht nötig. Impressum und Datenschutz liegen als Vorlage bei.
- **Performance:** kein Framework, ca. 32 KB JavaScript unkomprimiert (ca. 11 KB gzip), ein Stylesheet, zwei Schriftdateien (zusammen ca. 108 KB), Bilder lazy, keine Videos. Der Rasen läuft auf Canvas 2D mit gebündelten Zeichenaufrufen und pausiert außerhalb des Sichtbereichs.

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
| Individuelles Markenprojekt oder Template? | Eigene Logoform (Badge, Chips, Erfolgsmeldung, Favicon), ein generativer Rasen-Hero, der nur zu diesem Thema passt, eigene Illustrationssprache, eine reservierte Akzentfarbe. |
| In fünf Sekunden klar, was angeboten wird? | Die H1 nennt drei konkrete Arbeiten, die Unterzeile Ort und Art der Pflege. |
| Nächster Schritt sofort klar? | Ein einziger Lehm-Button mit „Kostenlos anfragen“, daneben Telefon und WhatsApp |
| Seriös genug für Zugang zum Grundstück? | Person sichtbar, Name, ruhige Gestaltung, keine Werbesprache, klare Abläufe, Impressum |
| Grabpflege respektvoll? | Eigener heller, kühler Farbraum, leise Satz-Typografie statt Versalien, kein Lehm, nur ruhiges Einblenden, sachliche Liste, ehrliche Abgrenzung im FAQ |
| Animationen sinnvoll? | Jede Bewegung erzählt etwas über Gartenarbeit (wachsen, mähen, zählen, verbinden). Die Grabpflege bleibt ruhig. Bei reduzierter Bewegung vollständig statisch. |
| Überladen? | Pro Sektion eine Idee, viel Leinen-Fläche, Illustrationen nur dort, wo Bilder hingehören |
| Konkrete Texte? | Verben und Gegenstände statt Adjektive. Keine Floskel aus der Verbotsliste. |
| Mobil gleichwertig? | Eigene Reihenfolge und Komposition, Kontaktleiste, Linie im Ablauf, große Touch-Ziele |
| Erfundene Behauptungen? | Keine. Zu bestätigende Aussagen stehen in Abschnitt 13, alle Fakten sind Platzhalter. |
| Erweiterbar mit echten Fotos und Bewertungen? | Platzhalter mit festen Seitenverhältnissen. Bewertungs-Komponente ist fertig vorbereitet. Projekte lassen sich als weitere Vergleiche ergänzen. |
