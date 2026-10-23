# Juvens Fahrschule website

One-page site for Juvens Fahrschule, Borghagener Str. 1, 44581 Castrop-Rauxel (Habinghorst).

- `site/` is the deployable version. Upload `index.html`, `fonts.css` and `fonts/` to any static host. Fonts are self-hosted, so the site makes no Google requests.
- `juvens.html` is the source for the claude.ai artifact preview. It loads Google Fonts, because the artifact sandbox only allows those.

## Design

The concept is a bright whiteboard, like the board in a theory lesson. The page is clean and white, with thick marker headlines and hand-drawn circles, underlines and highlighter strokes that draw themselves. Every block sits on its own standout colour area, and the page is light-only.

- **Hero intro (about 2.5 s, plays once):**
  - The marker headline appears line by line, then a red marker circle draws itself around "selbst."
  - The Autobahn direction sign (Wegweiser) drops onto its posts and the office-hours plate swings in.
  - The driving-school car rolls in, kicking up dust from its wheels. It dips as it brakes, blinks twice, and then keeps puffing exhaust while it waits.
- **Classes:** one large panel per vehicle class: Auto in blue, Motorrad in black, Roller & Mofa in red.
  - Each panel has a big marker headline, a giant class letter in the background, the age facts, a button and a detailed vehicle illustration.
  - The vehicle drives in with a dust cloud when its panel arrives, then idles with exhaust puffs.
  - On larger screens the panels stack on scroll: each new panel slides over the previous one, which scales back and dims.
- **Route ("Ablauf"):** a grey road with nine real traffic signs, inside a light panel.
  - The driving-school car glides smoothly after the scroll position and kicks up dust while it moves.
  - When the page stands still, the car idles with a slight engine shake and exhaust puffs. The particles are drawn on a canvas.
- **Reviews (Google look):** a Google rating panel with an animated logo, stars and count-up, and a carousel of review cards in Google style. The section sits on a Google-grey background.
- **Costs:** a yellow sticky note with tape, and hand-drawn check marks for each cost item.
- **Pre-registration and contact:** a blue board with the contact details, plus a white form card. The licence plate on the form updates live with the visitor's initials.
- **Sign-off:** a town-exit sign. "Beifahrersitz" is crossed out and the next place is "Fahrersitz, 0 km". The footer ends on a road strip with "JUVENS" painted in marker.
- **Buttons:** chunky marker stickers with a thick black border and a hard offset shadow. On hover they lift and tilt slightly and the arrow slides. On click they press flat and a ripple spreads.

Vehicles and signs are SVG illustrations, defined once in a hidden `<svg class="svg-defs">` and reused with `<use>`. Text stays readable at rest and only settles into place on scroll. All motion, including the particles, is switched off under `prefers-reduced-motion`.

**Fonts:**
- Permanent Marker (thick marker) for headlines.
- Shantell Sans (marker-style but easy to read) for buttons, labels and sub-headings.
- Atkinson Hyperlegible Next for body text.
- Barlow Semi Condensed for road-sign lettering.
- Roboto in the Google section.

**Colours:** white base with marker blue, red, black and Juvens yellow. Road signs keep their official colours.

## Reviews

No individual Google review texts could be retrieved, so the cards show verbatim quotes from review portals. Each card names its portal as the author and links to the source (deutschefahrschulen.com and topfahrschulen.com).

To show real Google reviews with names, either:
- replace the `<figure class="rv">` blocks in `#reviews` with reviews the school has approved, or
- load them live through the Google Places API.

The carousel adapts to any number of slides; only the dot buttons need updating by hand.

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
