# Changelog

Addon sites require a changelog entry with every file upload, and refuse
re-uploads without functional changes. Paste the relevant section into the
upload's changelog field.

Versions match the `## Version` line in `PetWatch/PetWatch.toc`; the release
workflow refuses a tag that disagrees with it.

## 0.2.0 — unreleased

- **The alert's appearance is configurable**: font, size, colour and position,
  all from the settings panel. "Move alert" shows it permanently so it can be
  dragged, and closes the panel so it is not hidden behind it.
- Fonts are the client's own (Default, Arial, Skurri, Morpheus) — no bundled
  typeface, and "Default" follows the client's locale. A font the client
  refuses falls back and says so.
- Colour is three sliders rather than the client's colour picker, whose API has
  been rewritten more than once.
- **Centre-screen alert.** A large "Pet Missing!" or "Pet Dead!" flashes above
  the middle of the screen and fades, so a pet lost mid-fight is not something
  you find out about two minutes later. On by default; turn it off in the
  settings panel or with `/pw alert off`.
- The alert fires only on a change into that state, never repeatedly while it
  lasts, and is held back for five seconds after a loading screen — during a
  zone the pet unit can briefly read as absent even when the pet is out.
- Previewing a state now shows the alert too, so it can be seen without waiting
  for something to go wrong.

## 0.1.0 — unreleased

First release.

- Shows an indicator when the hunter pet is dead or missing, and nothing at all
  while the pet is alive.
- Hides itself while mounted (optional), in vehicles, and on specialisations
  that do not use a pet.
- Settings panel in the client's own options UI, reachable via `/pw`, the
  minimap addon compartment, or Game Menu → Options → AddOns.
- Preview mode, so the indicator can be seen and positioned without waiting for
  the pet to die.
- Position, scale, and a choice of icon, text or both.
- `/pw diag` reports what the client's API supports — the output to attach to a
  bug report.
- Built for Midnight; declares interface 120100 (live) and 120105 (PTR).

Verified on a live client (12.1.0, Beast Mastery, solo) with a pet that actually
died. Not yet exercised in a group: Midnight's secret values are
context-dependent, so raid and Mythic+ behaviour is untested.
