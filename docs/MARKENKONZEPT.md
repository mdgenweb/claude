# [FIRMENNAME] – Markenkonzept & Designsystem

Gartenservice · Gartenpflege · Grabpflege · [ORT + EINSATZGEBIET]

> **Version 3 – „Direkt & übersichtlich“** (aktuell): direkte Ansprache („Ihr Garten? Erledigen wir.“), Schnellanfrage im Hero, Leistungen als klares Raster mit farbigen Illustrationen, kompakter Ablauf. Die Bildwelt von V2 bleibt: kräftige Versalien, Nachtgrün, generativer Rasen-Hero.
> Version 2 (fixierte Leistungs-Galerie, Text-Scrub) und Version 1 („ruhig & editorial“ mit Scroll-Ranke, Commit `cbaf5ca`) liegen im Git-Verlauf.

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
- **Buttons:** Pill-Form, ruhig: Der Button bleibt an seinem Platz. Beim Hover blendet die Farbe weich eine Stufe dunkler (Lehm → dunkles Lehm, Outline → gefülltes Waldgrün), dazu ein weicher Schatten in der Button-Farbe; ein Pfeil rückt nur 3 px nach. Beim Klicken gibt der Button minimal nach (98 %). Tastatur-Fokus zeigt denselben Zustand plus Lehm-Kontur. Primär ist Lehm; sekundär Outline-Pills, auf Dunkel hell.
- **Schnellanfrage:** helle Karte im Hero (22 px Radius). Sechs Bild-Kacheln zum Ankreuzen (mehrere möglich), ein Feld für Ort/PLZ und „Anfrage starten“. Die Auswahl landet im Anfrageformular, der Cursor steht im Namensfeld.
- **Karten:** Leistungen als helle Karten (20 px Radius) im 3er-Raster: farbige Spot-Illustration oben, Titel mit kleiner Ziffer, ein Satz, runder Pfeil-Button „Jetzt anfragen“. Die ganze Karte ist klickbar und wählt die Leistung im Formular vor. Auf dem Smartphone liegen Bild und Text nebeneinander.
- **Fakten-Band:** nachtgrüne Fläche mit drei großen Ziffern (6 · 1 · 0 €) und dem Hauptbutton
- **Bogen:** Personen- und Grabpflege-Bilder im Rundbogen (bis zu echten Fotos: Siebdruck-Platzhalter `portrait-platzhalter.svg` und `grabpflege-hoch.svg`)
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

## 7. Illustrationen

**Spot-Illustrationen im Siebdruck-Stil (Leistungen, Vorher/Nachher)** – bewusst gestaltet, nicht generiert:
- **Wenige Druckfarben:** Waldgrün, Moos, Blattgrün, dazu Papiertöne; Lehm nur für die Aktion (Schnittlinie, Pfeil, Zielform). Keine Verläufe.
- **Gestaltete Raster statt Zufall:** Laub als Schuppenmuster, Erde als Punktraster, Kies als Körnung, Rasen als Mähstreifen in Perspektive.
- **Passerversatz:** große Formen haben eine hellere Kante oben links, wie beim Druck mit zwei Sieben. Das ist die eigene Handschrift.
- **Papierkörnung:** eine kleine Kachel (`assets/img/grain.png`) liegt per „multiply“ über allen Illustrationen. Im Hero ist die Körnung dagegen direkt eingemalt (`grain-soft.png`, „soft-light“ im Hintergrund und in den stillen Ebenen der Szene): Eine Mischebene über dem ganzen Hero müsste der Browser in jedem Frame neu verrechnen, sobald darunter etwas wiegt, und das verlangsamte Klicks.
- **Organische Konturen** werden geglättet (Löwenzahnblätter mit gerundeten Lappen statt Zickzack), Grundlinien bleiben gerade.
- **Jedes Motiv erzählt den Vorher-nachher-Moment:** Hecke links zottig, rechts geschnitten; Rasen halb gemäht; Löwenzahn samt Wurzel gezogen; Strauch halb in Form; Hochbeet mit Rechen im Laub; Grabstätte ruhig, ohne Lehm und ohne Bewegung.
- **Leichte Bewegung:** einzelne Triebe, Halme und ein Blatt wiegen sich in den Leistungskarten. Technisch liegt ein stilles Bild unten (`name-base.svg`) und eine dünne, transparente Bewegungsebene darüber (`name-motion.svg`, eigene Compositor-Ebene), damit nicht das ganze Muster in jedem Frame neu gezeichnet wird. Kacheln und Unterseite nutzen die komplette, stille Fassung (`name.svg`). Bei „reduzierter Bewegung“ steht alles still.

Erzeugt mit `tools/spots.mjs` (feste Zufallswerte, reproduzierbar). Echte Fotos können jede Illustration 1 : 1 ersetzen.

**Botanische Linien:** Feine Linienzeichnungen (1,1–1,4 px) in Waldgrün oder Blattgrün: Zweige, Olivenzweig, Gräser, Rosette mit Wurzel, Hecke. Erzeugt mit `tools/botanics.mjs` aus wenigen Grundformen und festen Zufallswerten. Dadurch wirken sie gezeichnet und bleiben trotzdem einheitlich.

**Einsatz:** derzeit nicht auf der Website (dort tragen die Siebdruck-Illustrationen); als Markenmaterial für Drucksachen wie Visitenkarte, Flyer oder Fahrzeug. Nie hinter Fließtext, nie dekorativ gestreut.

---

## 8. Bewegung

**Signature: „Scrollen = Mähen.“**
Unter Headline und Schnellanfrage liegt eine Szene im Siebdruck-Stil (inline SVG, erzeugt mit `tools/scene.mjs`):
- die Riesentypo „HECKE. RASEN. BEETE.“ steht hinter einer gerade geschnittenen Hecke (Schuppenmuster, helle Schnittkante), deren Oberkante das untere Fünftel der Buchstaben verdeckt
- davor ein Rasen in Perspektive: links gemäht (Mähstreifen, unten breiter als oben), rechts hohes Gras mit Halmbüscheln, getrennt durch eine helle Mähkante parallel zu den Streifen
- beim Laden gleitet die Mählinie von links in die Szene; beim Scrollen fährt sie weiter nach rechts, bis fast der ganze Rasen gemäht ist (CSS-Variable `--mow`, weich nachgeführt)
- Triebe auf der Hecke und Halmbüschel wiegen sich leicht. Je Reihe und Takt ist es eine Gruppe, die um ihre Fußlinie geschert wird: wenige Compositor-Ebenen, kein Neuzeichnen der Muster; außerhalb des Sichtbereichs pausiert die Bewegung
- Tiefe durch Luftperspektive: hintere Büschel klein und blasser, vordere groß und dunkel, unregelmäßig verteilt, teils als Paar
- die Headline „Ihr Garten? Erledigen wir.“ bekommt einen gezeichneten Lehm-Unterstrich mit leichtem Druckversatz, der sich nach dem Wort-Reveal einmal von links zeichnet

**Weitere Effekte:**
| Effekt | Wo |
|---|---|
| Marquee-Band, dessen Tempo und Richtung dem Scrollen folgen | unter dem Hero |
| Kacheln mit Häkchen, Bild zoomt beim Hover; Absenden springt sanft zum Formular | Schnellanfrage |
| Kartenschatten blendet ein, Illustration zoomt leicht (3 %), Pfeil-Button wird Lehm – ohne Anheben oder Drehen | Leistungen |
| rollende Ziffern wie ein Zählwerk (6 · 1 · 0 €) | Fakten-Band |
| Wort-für-Wort-Reveal aus einer Maske | alle Display-Titel |
| Bild-Reveal von unten | Über uns |
| Linie wächst seitwärts (mobil nach unten), Ziffern füllen sich, Blätter springen an | Ablauf |
| Karte zeichnet sich, Puls um den Ort | Einsatzgebiet |
| Header blendet beim Runterscrollen aus, passt sich hell/dunkel an, Milchglas über dem Inhalt (ebenso die mobile Kontaktleiste) | überall |
| Parallaxe im Hero, Ablauf-Linie und Marquee-Tempo gleiten weich zum Ziel statt mit dem Mausrad zu springen; das Marquee läuft als Web Animation auf dem Compositor | Hero, Ablauf, Marquee |
| Druck-Feedback beim Klicken/Tippen (Buttons, Karten, Kacheln, Chips, FAQ, Kontaktleiste); Hover-Effekte nur mit Maus, Tastatur bekommt denselben Zustand per Fokus | überall |
| Menü-Overlay: Vorhang in zwei Ebenen (Blattgrün, dann Nachtgrün), nummerierte Links gleiten nacheinander hoch, Trennlinien zeichnen sich, Gras-Silhouette am unteren Rand; aktueller Abschnitt in Blattgrün; ab Tablet Kontaktspalte daneben | Mobil/Tablet/Laptop |

**Grenzen:** Die Grabpflege bekommt nur ein ruhiges Einblenden. Alle Effekte nutzen transform/opacity und einen gemeinsamen Takt. Das Einblenden läuft als CSS-Animation, damit Hover-Übergänge der Karten danach sofort und unverzögert reagieren. Bei **prefers-reduced-motion** gibt es keine dieser Bewegungen: Die Szene steht als ruhiges Standbild (gut zur Hälfte gemäht), alle Inhalte sind sofort sichtbar.

---

## 9. Seitenarchitektur & Conversion

| # | Sektion | Beantwortete Kundenfrage |
|---|---|---|
| 1 | Hero: „IHR GARTEN? ERLEDIGEN WIR.“ + drei Zusagen + Schnellanfrage, darunter „HECKE. RASEN. BEETE.“ im Gras | Was macht das Unternehmen? Wo? Was muss ich tun? |
| 2 | Marquee mit allen Leistungen | Was gibt es alles? |
| 3 | „WAS DÜRFEN WIR FÜR SIE TUN?“ – Leistungen als Raster (01–06), Fakten-Band (6 Leistungen · 1 Ansprechpartner · 0 € Anfrage) | Was genau übernehmen sie? Was kostet eine Anfrage? |
| 4 | „SO EINFACH GEHT'S.“ – Ablauf in 4 Schritten | Wie läuft die Anfrage ab? |
| 5 | Vorher/Nachher | Wie sehen deren Arbeiten aus? |
| 6 | Über uns | Wer kommt zu mir? |
| 7 | Grabpflege (ruhig) | Pflegen sie auch Gräber, und wie? |
| 8 | Kundenstimmen (vorbereitet, ausgeblendet bis echte Bewertungen vorliegen) | Was sagen andere? |
| 9 | Einsatzgebiet | Arbeiten die in meiner Gegend? |
| 10 | FAQ | Restliche Einwände |
| 11 | „IHR GARTEN KÖNNTE WIEDER ETWAS PFLEGE GEBRAUCHEN?“ + Formular | Kann ich unkompliziert Kontakt aufnehmen? |

Die Fakten sind keine erfundenen Kennzahlen, sondern überprüfbare Aussagen aus dem Briefing.

**Direkte Ansprache:** Überschriften sprechen den Besucher an und stellen seine Frage („Ihr Garten?“, „Was dürfen wir für Sie tun?“). Pro Sektion eine Aussage, kurze Sätze, keine Füllabschnitte.

**CTA-Strategie:** eine Hauptaktion, „Kostenlos anfragen“, als Lehm-Pill im Header, im Fakten-Band, im Ablauf, im Formular und in der mobilen Leiste. Im Hero ersetzt die Schnellanfrage den Button: Wer dort Arbeiten ankreuzt, findet sie im Formular wieder. Telefon und WhatsApp sind immer gleichwertig erreichbar. Jede Leistungskarte führt zur Anfrage und wählt die Leistung vor. Unterseiten verlinken mit Vorauswahl (`/?arbeit=Heckenschnitt#kontakt`).

**Mobil:** Headline, Text und die drei Zusagen auf dem ersten Bildschirm, die Schnellanfrage beginnt direkt darunter. Danach die gestapelte Riesentypo im Gras. Die dunkle Kontaktleiste (Anrufen · WhatsApp · Anfrage) erscheint erst, wenn die Schnellanfrage aus dem Bild ist.

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

- **Desktop (ab 1240 px):** volle Navigation, Headline und Schnellanfrage nebeneinander, Leistungen 3 × 2, Ablauf in einer Reihe
- **Laptops mit wenig Höhe (ab 1100 px Breite, bis 1000 px Höhe):** Hero etwas dichter (flachere Kachelbilder, knappere Abstände, niedrigere Hecke), damit Riesentypo, Hecke und der Anfang des Rasens schon im ersten Bild stehen
- **Laptop (1100–1239 px):** Navigation im Vollbild-Menü, sonst wie Desktop
- **Tablet (768–1099 px):** Schnellanfrage unter der Headline, Leistungen 2 × 3, Ablauf untereinander (ab 1024 px wieder in einer Reihe)
- **Smartphone (unter 768 px):** Riesentypo dreizeilig gestapelt, niedrigere Hecke und Rasenfläche, Leistungskarten mit Bild links, Fakten als Zeilen, randloses Vorher/Nachher, Kontaktleiste unten

---

## 12. Barrierefreiheit, Datenschutz, Performance

- **Barrierefreiheit:** Kontraste ≥ 4,5 : 1 für Text, sichtbarer Fokus (Lehm-Kontur), Skip-Link, vollständige Tastaturbedienung (Drawer mit Fokusfalle und Esc, Vorher/Nachher als echter Regler, FAQ mit nativem `details`), beschriftete Formularfelder mit verknüpften Fehlermeldungen, Bedienelemente ≥ 44 px, Information nie nur über Farbe. Automatisierter Test mit axe-core (WCAG 2.1 AA + Best Practices): **0 Verstöße** auf Desktop und Mobil.
- **DSGVO:** keine externen Anfragen beim Laden, keine Cookies, keine Tracker, Schriften lokal, abstrakte Einsatzkarte statt Google Maps. WhatsApp öffnet sich erst nach einem Klick. Ein Cookie-Banner ist deshalb nicht nötig. Impressum und Datenschutz liegen als Vorlage bei.
- **Performance:** kein Framework, ca. 35 KB JavaScript unkomprimiert (ca. 12 KB gzip), ein Stylesheet, zwei Schriftdateien (zusammen ca. 108 KB), Illustrationen als schlanke SVG (gleichfarbige Formen in einem Pfad), Bilder lazy und asynchron dekodiert, keine Videos. Gemessen (Chromium, lokal): Layout-Verschiebung (CLS) 0; Haupt-Thread bei laufender Hero-Szene ca. 0–2 ms pro Sekunde; Scrollen konstant 60 fps, auch bei 4-fach gedrosselter CPU; Reaktionszeit auf Klicks in der Schnellanfrage (INP) im Median ca. 32 ms am Desktop und ca. 64 ms bei 4-fach gedrosselter CPU auf dem Smartphone. Kartenschatten werden nur über die Deckkraft einer eigenen Ebene eingeblendet, das Menü bleibt im Layout und öffnet per Klassenwechsel. Die große Hero-Schrift startet per CSS bereits in ihrer eingepassten Größe.
- **Ausrichtung:** Riesentypo im Hero und Wortmarke im Footer liegen auch auf sehr breiten Bildschirmen exakt im Inhaltsraster. Die Leistungskarten nutzen CSS-Subgrid, damit Titel, Text und Button in jeder Reihe auf einer Linie stehen.

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
| Individuelles Markenprojekt oder Template? | Eigene Logoform (Chips, Erfolgsmeldung, Favicon), ein generativer Rasen-Hero, der nur zu diesem Thema passt, eigene Illustrationen für jede Leistung, eine reservierte Akzentfarbe. |
| In fünf Sekunden klar, was angeboten wird? | Die H1 spricht den Besucher direkt an, der Text darunter nennt die Arbeiten, die Schnellanfrage zeigt alle sechs Leistungen als Bild. |
| Nächster Schritt sofort klar? | Im Hero ankreuzen und „Anfrage starten“, sonst überall derselbe Lehm-Button „Kostenlos anfragen“, daneben Telefon und WhatsApp |
| Seriös genug für Zugang zum Grundstück? | Person sichtbar, Name, ruhige Gestaltung, keine Werbesprache, klare Abläufe, Impressum |
| Grabpflege respektvoll? | Eigener heller, kühler Farbraum, leise Satz-Typografie statt Versalien, kein Lehm, nur ruhiges Einblenden, sachliche Liste, ehrliche Abgrenzung im FAQ |
| Animationen sinnvoll? | Jede Bewegung erzählt etwas über Gartenarbeit (wachsen, mähen, zählen, verbinden). Die Grabpflege bleibt ruhig. Bei reduzierter Bewegung vollständig statisch. |
| Überladen? | Pro Sektion eine Idee, keine leeren Platzhalter-Sektionen, Leistungen auf einen Blick im Raster statt in einer Galerie |
| Konkrete Texte? | Verben und Gegenstände statt Adjektive. Keine Floskel aus der Verbotsliste. |
| Mobil gleichwertig? | Eigene Reihenfolge und Komposition, Kontaktleiste, Linie im Ablauf, große Touch-Ziele |
| Erfundene Behauptungen? | Keine. Zu bestätigende Aussagen stehen in Abschnitt 13, alle Fakten sind Platzhalter. |
| Erweiterbar mit echten Fotos und Bewertungen? | Platzhalter mit festen Seitenverhältnissen. Bewertungs-Komponente ist fertig vorbereitet. Projekte lassen sich als weitere Vergleiche ergänzen. |
