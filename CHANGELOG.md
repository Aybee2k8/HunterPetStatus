# Changelog

Addon sites require a changelog entry with every file upload, and refuse
re-uploads without functional changes. Paste the relevant section into the
upload's changelog field.

Versions match the `## Version` line in `PetWatch/PetWatch.toc`; the release
workflow refuses a tag that disagrees with it.

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
