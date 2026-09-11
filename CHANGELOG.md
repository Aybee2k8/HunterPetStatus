# Changelog

Addon sites require a changelog entry with every file upload, and refuse
re-uploads without functional changes. Paste the relevant section into the
upload's changelog field.

Versions match the `## Version` line in `PetWatch/PetWatch.toc`; the release
workflow refuses a tag that disagrees with it.

## 0.2.0 — first release

0.1.0 was developed but never published, so this first release covers the whole
addon rather than a difference from something nobody has.

**What it does**

- Shows an indicator when your hunter pet is dead or missing, and nothing at all
  while the pet is alive.
- Flashes a large **Pet Missing!** / **Pet Dead!** above the middle of the
  screen, so a pet lost mid-fight is not something you discover two minutes
  later. On by default.
- Hides itself while mounted (optional), in vehicles, and on specialisations
  that do not use a pet.

**Settings**

- A panel in the client's own options UI, reachable with `/pw`, from the
  minimap's addon compartment, or via Game Menu → Options → AddOns.
- Indicator: position, size, and a choice of icon, text or both.
- Alert: font, size, colour and position, all adjustable. Fonts are the
  client's own — nothing is bundled — and "Default" follows your locale.
- **Preview** shows the indicator and the alert on demand, so both can be seen
  and placed without waiting for something to go wrong.

**Behaviour worth knowing**

- The alert fires only on a change into that state, never repeatedly for as
  long as it lasts.
- Alerts are held back for five seconds after a loading screen: while the world
  loads, the pet unit can read as absent even when your pet is right there.
- `/pw diag` reports what your client's API supports. If something looks wrong,
  that output is what to put in a bug report.

**Compatibility**

Built for Midnight; declares interface 120100 (live) and 120105 (PTR). No
dependencies and no libraries.

Verified on a live client (12.1.0, Beast Mastery, solo) with a pet that actually
died. Not yet exercised in a group — Midnight's secret values are
context-dependent, so raid and Mythic+ behaviour is untested.
