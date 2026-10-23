# Juvens Fahrschule website

One-page site for Juvens Fahrschule, Borghagener Str. 1, 44581 Castrop-Rauxel (Habinghorst).

- `site/` is the deployable version. Upload `index.html`, `fonts.css` and `fonts/` to any static host. Fonts are self-hosted, so the site makes no Google requests.
- `juvens.html` is the source for the claude.ai artifact preview. It loads Google Fonts, because the artifact sandbox only allows those.

## Design

Every visual element is German road signage drawn in CSS and SVG, so the page uses no stock photos:

- **Hero:** an Autobahn direction sign (Wegweiser) that doubles as navigation. An hours plate (Zusatzzeichen) hangs underneath, and a round inspection sticker (HU-Plakette) shows the 5.0 rating.
- **Buttons:** arrow direction signs (Pfeilwegweiser), yellow for main actions and white for secondary ones. On hover they catch a light glint, like a reflective sign in headlights.
- **Section labels:** small Zusatzzeichen plates.
- **Classes:** laid out as the back of the EU driving licence card. "Wählen" preselects the class in the form.
- **"Ablauf":** a grey road on a light background. Each of the nine stops has its own real traffic sign:
  - Info sign, first-aid sign, a document sign and a § sign
  - Priority road and Autobahn
  - STOP and Tempo 50
  - End of all restrictions

  A driving-school car follows the scroll. The stop markers turn from grey to yellow to green.
- **Reviews:** a carousel with a large card in the centre and smaller cards left and right. It advances to the right on its own, pauses on hover or focus, and supports swipe, arrow buttons and the keyboard.
- **Contact and close:** the contact section uses a town sign (Ortstafel). The closing call to action is a town-exit sign: "Beifahrersitz" is crossed out and the next place is "Fahrersitz, 0 km". The footer ends on a road strip with "JUVENS" painted on it.

All motion is switched off under `prefers-reduced-motion`.

**Fonts:** Barlow Condensed for headlines and Barlow Semi Condensed for sign lettering. Both are open alternatives to DIN 1451, the typeface on German road signs. Body text is Atkinson Hyperlegible Next.

**Colours:** approximations of Verkehrsblau, Verkehrsgelb and Verkehrsrot on light concrete neutrals, with a full dark mode.

## Reviews

No individual Google review texts could be retrieved, so the carousel shows verbatim quotes from review portals, each linked to its source (deutschefahrschulen.com and topfahrschulen.com). To swap in real Google reviews, replace the `<figure class="rv">` blocks in `#reviews`; the carousel adapts to any number of slides. The dot buttons and the "1 / 5" labels need updating by hand.

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
