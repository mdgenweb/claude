# Juvens Fahrschule website

One-page site for Juvens Fahrschule, Borghagener Str. 1, 44581 Castrop-Rauxel (Habinghorst).

- `site/` is the deployable version. Upload `index.html`, `fonts.css` and `fonts/` to any static host. Fonts are self-hosted, so the site makes no Google requests.
- `juvens.html` is the source for the claude.ai artifact preview. It loads Google Fonts, because the artifact sandbox only allows those.

## Design

Every visual element is a German traffic sign drawn in CSS and SVG, so the page uses no stock photos:

- The hero is an Autobahn direction sign (Wegweiser) that doubles as navigation, with an hours plate (Zusatzzeichen) underneath.
- The class cards (B, A, A2, A1, AM, Mofa) carry a guilloche pattern like the EU licence card.
- "Ablauf" is a dark asphalt band with a zebra crossing. A driving-school car drives down a winding road as you scroll, and the stop markers switch from grey to yellow to green like a traffic light.
- The contact section uses a town sign (Ortstafel). The closing call to action is a town-exit sign: "Beifahrersitz" is crossed out and the next place is "Fahrersitz, 0 km".
- Motion is subtle: one load sequence in the hero, the scroll-linked car, an indicator that blinks on button hover, and a slow marquee. Everything is switched off under `prefers-reduced-motion`.

Fonts are Archivo (variable width, wide for headlines and condensed for sign lettering) and Instrument Sans for body text. The colours approximate Verkehrsblau, Verkehrsgelb and Verkehrsrot on concrete and asphalt neutrals, and there is a full dark mode.

## Confirm with the owner before launch

These facts come from directory listings, not from the school itself.

| Item | Current value on the page | Note |
|---|---|---|
| Office hours | Mon–Fri 16.30–18.30 | Older listings say Tue and Thu only |
| Postcode | 44581 | Some listings say 44579 |
| Email | info@juvens-fahrschule.de | Taken from one directory |
| Instructors | Pira (owner), Holger | Holger comes from review summaries only |
| Rating | 5.0, over 150 Google reviews | Check the live count |
| Intensive courses | mentioned | Listed by topfahrschulen.com |
| Classes | B, A, A2, A1, AM, Mofa | Add BE, B196 or B197 if offered |

## Still needed

- **Voranmeldung form:** connect it to a backend or form service. For now it only shows a preview message and sends nothing.
- **Impressum:** add the details for § 5 DDG (Fahrschulerlaubnis, Aufsichtsbehörde).
- **Datenschutzerklärung:** write the full privacy policy.
- **Photos:** add real ones (team, cars, office) if wanted. The design works without them.
- **2027 reform:** update the Ablauf text when the planned driving-licence reform takes effect.
