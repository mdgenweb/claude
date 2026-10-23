# Juvens Fahrschule website

One-page site for Juvens Fahrschule, Borghagener Str. 1, 44581 Castrop-Rauxel (Habinghorst).

- `site/` is the deployable version. Upload `index.html`, `fonts.css` and `fonts/` to any static host. Fonts are self-hosted, so the site makes no Google requests.
- `juvens.html` is the source for the claude.ai artifact preview. It loads Google Fonts, because the artifact sandbox only allows those.

## Design

A calm, airy layout on light concrete tones with generous spacing. German road signage appears only at a few signature moments, drawn in CSS and SVG, so the page uses no stock photos.

The page has seven sections: hero, classes, route, reviews, costs, FAQ, and pre-registration with contact. A sign-off section and the footer follow.

- **Hero intro (about 2.5 s, plays once):**
  - The headline lines slide up.
  - The posts grow and the Autobahn direction sign (Wegweiser) drops in with a slight spring. Its arrows slide in.
  - The office-hours plate (Zusatzzeichen) swings into place.
  - The driving-school car rolls in with turning wheels and parks between the posts. The body dips forward as it brakes, rebounds, and the mirror indicator blinks twice.
  - A light glint sweeps across the sign.
- **Vehicles:** detailed SVG illustrations defined once in a hidden `<svg class="svg-defs">` and reused with `<use>`:
  - The car is a compact hatchback in side view, with shaded paint, tinted glass with reflections, door seams and handles, an LED headlight, five twin-spoke alloys with red calipers, the roof sign and the Juvens livery.
  - The motorbike and the scooter are drawn the same way.
  - The road car is a matching top view.
- **Buttons:** arrow shapes with a gradient, inner highlight and soft shadow. On hover they lift, the tip extends and a glint passes across. On click a ripple spreads from the press point.
- **Classes:** three clear cards (Auto, Motorrad, Roller & Mofa), each listing its classes with age. On hover the vehicle rolls forward and its wheels turn. The card link preselects the class in the form.
- **Route ("Ablauf"):** a grey road with nine real traffic signs, one per step. The driving-school car eases after the scroll position, and the stop markers turn from grey to yellow to green.
- **Reviews (Google look):** set in Roboto with Google colours and Material buttons.
  - A rating panel shows the Google logo, "5,0" and stars. When it scrolls into view the logo pops in, the stars fill one by one and the numbers count up.
  - Below it, a carousel of review cards in Google style: a large card in the centre, smaller cards left and right. It advances to the right every 6 s, pauses on hover or focus, and supports swipe, arrow buttons and the keyboard.
- **Pre-registration and contact:** the contact details sit beside the form. The licence plate above the form updates live with the visitor's initials.
- **Sign-off:** a town-exit sign. "Beifahrersitz" is crossed out and the next place is "Fahrersitz, 0 km". The footer ends on a road strip with "JUVENS" painted on it.

Text blocks keep their resting position readable and only settle into place on scroll. All motion is switched off under `prefers-reduced-motion`.

**Fonts:** Barlow for headlines and Barlow Semi Condensed for sign lettering. Both are open alternatives to DIN 1451, the typeface on German road signs. Body text is Atkinson Hyperlegible Next with a 1.7 line height.

**Colours:** approximations of Verkehrsblau, Verkehrsgelb and Verkehrsrot on light concrete neutrals, with a full dark mode.

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
