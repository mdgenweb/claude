# [FIRMENNAME] – Gartenservice-Website

Statische, schnelle und DSGVO-freundliche Website für einen Gartenservice: Heckenschnitt, Rasenpflege, Unkraut, Sträucher, allgemeine Gartenpflege und Grabpflege.
Das Konzept, das Logo-System und alle Gestaltungsregeln stehen in **[docs/MARKENKONZEPT.md](docs/MARKENKONZEPT.md)**.

## Ansehen

```bash
python3 -m http.server 8000
# → http://localhost:8000
```

Die Seite benötigt keinen Build-Schritt und kein Framework. Den Rasen-Hero am besten am Desktop mit Maus ausprobieren: Halme weichen dem Zeiger aus, Scrollen mäht. Die Schnellanfrage im Hero übernimmt die angekreuzten Arbeiten und den Ort ins Anfrageformular.

## Aufbau

```
index.html              Startseite (alle Sektionen)
heckenschnitt/          Muster für Leistungs-Unterseiten
impressum.html          Vorlage
datenschutz.html        Vorlage
assets/css/main.css     Designsystem (Tokens, Komponenten, Sektionen, Responsive)
assets/js/main.js       Header, Menü, Schnellanfrage, Vorher/Nachher, Formular, Kontaktleiste
assets/js/motion.js     Reveals, Marquee, rollende Zahlen, Ablauf-Linie, magnetische Buttons
assets/js/grass.js      Signature: generatives Rasenfeld im Hero (Web Worker), wird beim Scrollen gemäht
assets/fonts/           Bricolage Grotesque (mit Breiten-Achse) + Instrument Sans (lokal, OFL)
assets/brand/           Logo-System als SVG, Icons als PNG
assets/img/spots/       farbige Leistungs-Illustrationen und Vorher/Nachher
assets/img/             weitere Illustrationen/Platzhalter, OG-Bild
tools/build_brand.py    setzt alle Logo-Lockups mit echtem Firmennamen neu
tools/spots.mjs         erzeugt die Leistungs-Illustrationen (node tools/spots.mjs)
tools/botanics.mjs      erzeugt die botanischen Linienzeichnungen
tools/og-card.html      Vorlage für das Social-Media-Vorschaubild
```

## Vor dem Livegang

1. **Platzhalter ersetzen** (Suchen & Ersetzen in allen Dateien):
   `[FIRMENNAME]` `[ORT]` `[REGION]` `[TELEFON]` `[TELEFON_LINK]` (z. B. `+4930123456`) `[TELEFON_INTERNATIONAL]` `[WHATSAPP]` `[WHATSAPP_NUMMER]` (nur Ziffern, z. B. `4917612345678`) `[E-MAIL]` `[NAME]` `[VORNAME NACHNAME]` `[DOMAIN]` `[STRASSE NR]` `[PLZ]` `[XX]` `[ORT 1]`…`[ORT 6]` `[GOOGLE-BEWERTUNGEN-LINK]`
2. **Logo neu setzen:** `pip install fonttools brotli uharfbuzz && python3 tools/build_brand.py "Echter Name"`
3. **Aussagen freigeben:** Liste in `docs/MARKENKONZEPT.md`, Abschnitt 13
4. **Fotos einsetzen:** siehe unten
5. **Kundenstimmen:** Die Sektion ist vorbereitet und mit `hidden` ausgeblendet. Erst mit echten, freigegebenen Bewertungen füllen und `hidden` entfernen.
6. **Formularversand einrichten:** siehe unten
7. **Impressum und Datenschutz** vervollständigen und rechtlich prüfen lassen
8. **Einsatzorte:** nur reale Orte in Einsatzgebiet, FAQ, Footer und JSON-LD (`areaServed`) eintragen

## Fotos austauschen

Platzhalter sind `<div class="ph …">…</div>`-Blöcke mit dem Etikett „Foto folgt · Motiv“. Ersetzen durch:

```html
<picture>
  <source srcset="assets/img/hecke-800.avif 800w, assets/img/hecke-1600.avif 1600w" type="image/avif">
  <img src="assets/img/hecke-1200.webp" alt="Frisch geschnittene Ligusterhecke in [ORT]" width="1200" height="1000" loading="lazy">
</picture>
```

**Inhaberfoto (Über uns):** In `.about__arch` das `<svg class="about__silhouette">` und den Zweig durch `<img class="about__img" src="…" alt="[NAME], Inhaber">` ersetzen und das Etikett `ph-tag` entfernen.

**Leistungskarten und Schnellanfrage:** Die farbigen Illustrationen in `.card__media` und `.qchip` können bleiben. Wer Fotos zeigen möchte, ersetzt sie im Format 4 : 3 (Motiv mittig, die Kacheln der Schnellanfrage schneiden auf 16 : 10 zu).

**Vorher/Nachher:** Die beiden `<img>` in `.compare__pane--before` und `.compare__pane--after` tauschen. Beide Fotos brauchen denselben Ausschnitt, im Breitformat (21 : 9 Desktop, mobil wird beschnitten). Danach das Etikett „Illustration · echte Projektfotos folgen“ entfernen.

## Formularversand

Ohne Konfiguration läuft das Formular im Demo-Modus und zeigt nur die Bestätigung an. Für den echten Versand die Adresse eines Formular-Endpunkts in `data-endpoint` eintragen:

```html
<form … data-endpoint="/anfrage.php">
```

Das Formular sendet dann alle Felder inklusive Fotos (`multipart/form-data`) per `fetch`. Geeignet sind ein PHP-Mailskript beim (deutschen) Hoster oder ein EU-gehosteter Formulardienst mit AV-Vertrag. Die Datenschutzerklärung muss dazu passend ergänzt werden.

Vorauswahl per Link ist möglich, z. B. von Unterseiten oder aus Anzeigen: `/?arbeit=Heckenschnitt&ort=12345#kontakt` (Werte wie in den Chips des Formulars).

## Qualität

- axe-core (WCAG 2.1 AA + Best Practices): 0 Verstöße auf Desktop und Mobil
- keine externen Requests beim Laden, keine Cookies
- Layout-Verschiebung (CLS) 0; der Rasen-Hero rendert sparsam, der Wind flaut nach 8 Sekunden ohne Interaktion sanft ab
- Rasen läuft in einem Web Worker (Fallback im Haupt-Thread): Klicks und Scrollen bleiben flüssig
- `prefers-reduced-motion` wird vollständig berücksichtigt (Rasen als Standbild, keine Effekte)
- Frühere Versionen liegen im Git-Verlauf: V1 ruhig/editorial mit Scroll-Ranke (Commit `cbaf5ca`), V2 mit fixierter Leistungs-Galerie
