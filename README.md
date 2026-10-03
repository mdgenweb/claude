# [FIRMENNAME] – Gartenservice-Website

Statische, schnelle und DSGVO-freundliche Website für einen Gartenservice: Heckenschnitt, Rasenpflege, Unkraut, Sträucher, allgemeine Gartenpflege und Grabpflege.
Das Konzept, das Logo-System und alle Gestaltungsregeln stehen in **[docs/MARKENKONZEPT.md](docs/MARKENKONZEPT.md)**.

## Ansehen

```bash
python3 -m http.server 8000
# → http://localhost:8000
```

Die Seite benötigt keinen Build-Schritt und kein Framework. Zum Testen der fertig gezeichneten Ranke `?vine=full` an die URL hängen.

## Aufbau

```
index.html              Startseite (alle Sektionen)
heckenschnitt/          Muster für Leistungs-Unterseiten
impressum.html          Vorlage
datenschutz.html        Vorlage
assets/css/main.css     Designsystem (Tokens, Komponenten, Sektionen, Responsive)
assets/js/main.js       Navigation, Drawer, Vorher/Nachher, Formular, Kontaktleiste
assets/js/vine.js       Signature-Animation „Ranke“
assets/fonts/           Bricolage Grotesque + Instrument Sans (lokal, OFL)
assets/brand/           Logo-System als SVG, Icons als PNG
assets/img/             Illustrationen/Platzhalter, OG-Bild
tools/build_brand.py    setzt alle Logo-Lockups mit echtem Firmennamen neu
tools/botanics.mjs      erzeugt die botanischen Linienzeichnungen
tools/og-card.html      Vorlage für das Social-Media-Vorschaubild
```

## Vor dem Livegang

1. **Platzhalter ersetzen** (Suchen & Ersetzen in allen Dateien):
   `[FIRMENNAME]` `[ORT]` `[REGION]` `[TELEFON]` `[TELEFON_LINK]` (z. B. `+4930123456`) `[TELEFON_INTERNATIONAL]` `[WHATSAPP]` `[WHATSAPP_NUMMER]` (nur Ziffern, z. B. `4917612345678`) `[E-MAIL]` `[NAME]` `[VORNAME NACHNAME]` `[DOMAIN]` `[STRASSE NR]` `[PLZ]` `[XX]` `[ORT 1]`…`[ORT 6]` `[GOOGLE-BEWERTUNGEN-LINK]`
2. **Logo neu setzen:** `pip install fonttools brotli uharfbuzz && python3 tools/build_brand.py "Echter Name"`
3. **Aussagen freigeben:** Liste in `docs/MARKENKONZEPT.md`, Abschnitt 13
4. **Fotos einsetzen:** siehe unten
5. **Kundenstimmen:** nur echte, freigegebene Bewertungen eintragen. Bis dahin die Sektion mit `hidden` ausblenden (`<section class="section reviews" … hidden>`).
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

**Inhaberfoto im Hero:**
- Ist das Foto freigestellt (PNG/WebP mit transparentem Hintergrund), behält die Figur die Klasse `portrait--cutout`. Das Foto ragt dann oben aus dem grünen Bogen.
- Bei einem normalen Foto auf `portrait--framed` umstellen. Das Bild wird dann in den Bogen eingepasst.
- Danach das `<svg class="portrait__placeholder">` und das Etikett `ph-tag` entfernen.

**Vorher/Nachher:** Die beiden `<img>` in `.compare__pane--before` und `.compare__pane--after` tauschen. Beide Fotos brauchen denselben Ausschnitt, im Format 3 : 2.

## Formularversand

Ohne Konfiguration läuft das Formular im Demo-Modus und zeigt nur die Bestätigung an. Für den echten Versand die Adresse eines Formular-Endpunkts in `data-endpoint` eintragen:

```html
<form … data-endpoint="/anfrage.php">
```

Das Formular sendet dann alle Felder inklusive Fotos (`multipart/form-data`) per `fetch`. Geeignet sind ein PHP-Mailskript beim (deutschen) Hoster oder ein EU-gehosteter Formulardienst mit AV-Vertrag. Die Datenschutzerklärung muss dazu passend ergänzt werden.

## Qualität

- axe-core (WCAG 2.1 AA + Best Practices): 0 Verstöße auf Desktop und Mobil
- keine externen Requests beim Laden, keine Cookies
- `prefers-reduced-motion` wird vollständig berücksichtigt
