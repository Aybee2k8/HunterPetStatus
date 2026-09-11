# PetWatch

A World of Warcraft Retail addon that shows an indicator when your hunter pet is
missing or dead.

Built for Midnight (12.x). Written from scratch — it replaces an abandoned addon
that stopped working in 12.0, and shares no code with it.

## Troubleshooting

Lua errors are hidden by default in Retail. Turn them on before reporting
anything — `/console scriptErrors 1`, then restart the game.

| Symptom | Cause |
| --- | --- |
| Not in the addon list at all | Folder name does not match the `.toc` inside it. It must be `Interface/AddOns/PetWatch/PetWatch.toc`. Restart the game; `/reload` does not pick up a newly added addon |
| Listed as incompatible / out of date | The client's interface version is not one the TOC declares. `/dump select(4, GetBuildInfo())` gives the real number; ticking "Load out of date AddOns" loads it meanwhile, unchanged |
| Loaded, but `/pw` does nothing | Should not happen — the slash command is registered at load. If it does, the addon did not load: check `/dump C_AddOns.IsAddOnLoaded("PetWatch")` |
| Panel missing, indicator working | The panel failed to build. It says so in chat at login and in `/pw diag`; the slash commands cover everything it does |

## Status

Runs on live (12.1.0, interface 120100), on a Beast Mastery hunter, with the
settings panel registering into the client's own options UI.

Confirmed there, with a **living** pet, solo:

- `UnitIsDeadOrGhost("pet")` is readable — it does not come back as a
  [secret value][secrets]. Reading the pet's condition directly is viable, so
  death detection does not have to become purely event-driven.
- `HasPetUI` still exists.
- `GetSpecialization` still exists as a global, alongside
  `C_SpecializationInfo.GetSpecialization`.
- Every event the addon registers is accepted.

Still unconfirmed, and the reason this is not called finished:

1. **The dead-pet path has never run.** Whether `UnitExists("pet")` stays true
   once the pet is dead is the question the whole death-memory design exists to
   answer, and a living pet cannot answer it. `/pw diag` prints
   `pet: exists=… dead=… hunterPetUI=…` for exactly this.
2. **Secret values are context-dependent.** A quiet solo test is the weakest
   possible probe. Whether these queries stay readable in combat, in a raid, or
   in a Mythic+ is untested — which is why every one of them still goes through
   `compat.SafeFlag`.

## Install

Copy the **`PetWatch`** folder from this repository into
`World of Warcraft/_retail_/Interface/AddOns/`, so that
`Interface/AddOns/PetWatch/PetWatch.toc` exists. Then restart the game — the
addon list is only read at startup, so a `/reload` will not pick up a newly
added addon.

Copy the inner `PetWatch` folder, not the repository folder. The client matches
a folder against the `.toc` inside it by name: a folder called anything else
(`HunterPetStatus`, or the `-main` suffix a ZIP download adds) is skipped
silently and the addon never appears in the list at all — not even as out of
date.

## Layout

| Path | Contains |
| --- | --- |
| `PetWatch/` | The addon itself — this is what gets installed |
| `tests/` | Test harnesses, run outside the game |
| `.github/` | CI and release packaging |

## Settings

Type `/pw` to open the settings panel, click **PetWatch** in the minimap's addon
compartment, or find it under Game Menu → Options → AddOns. Everything is there: enable, behaviour while
mounted, what the indicator shows, its size, where it sits, and a button that
reports what the client API supports.

The slash commands remain as shortcuts:

| Command | Effect |
| --- | --- |
| `/pw` | Open the settings panel |
| `/pw preview dead\|missing\|off` | Show the indicator without waiting for a dead pet (`/pw test` also works) |
| `/pw unlock` / `/pw lock` | Reposition the indicator by dragging |
| `/pw scale 1.0` | Resize it (0.3 – 4.0) |
| `/pw display icon\|text\|both` | Choose what is shown |
| `/pw mounted show\|hide` | Behaviour while mounted |
| `/pw on` / `/pw off` | Enable or disable |
| `/pw reset` | Restore defaults |
| `/pw diag` | Report what this client's API supports |

`/pw diag` — the panel's **Report API support** button — is the thing to run
after a patch, and the thing to paste into a bug report. It prints the build,
the resolved spec, and every API and event the addon probed, so a breakage is
visible without guessing.

## Source files

Everything below lives in `PetWatch/`.

| File | Contains |
| --- | --- |
| `Compat.lua` | Every client-API difference, in one place |
| `State.lua` | Pet state resolution — the only real logic |
| `Display.lua` | Frame, icon, caption, dragging |
| `Options.lua` | Settings panel |
| `Core.lua` | Saved variables, event wiring, slash commands |

`State.lua` deliberately touches no frames and no globals it does not go through
`Compat.lua` for, which is what lets it be tested outside the game.

## Design notes

**Secret values.** Since 12.0 the client may return values that tainted code —
any addon — can store and pass on but not compare or branch on; doing so raises
a Lua error. Every unit query therefore goes through `compat.SafeFlag`, which
returns `true`, `false`, or `nil` for "the client would not tell us". `nil` is
never treated as `false`: the difference between "no pet" and "cannot tell" is
the whole point, and an unreadable query holds the previous state rather than
collapsing to a wrong one.

**Bounded death memory.** A dead pet can stop answering to the `pet` unit token,
which makes it indistinguishable from having no pet — but the two need different
advice, revive vs. call. So the addon remembers having seen the pet die. That
memory is cleared by every event meaning the pet roster changed (`UNIT_PET`,
zoning, spec change). The addon this replaces latched on it and never cleared
it, so once a pet had died the indicator stayed stuck on "Pet dead" for the rest
of the session; `tests/state_spec.lua` covers that case directly.

**Isolated event registration.** `RegisterEvent` throws on an unknown event name,
and those calls happen at load time — one renamed event would stop the whole
addon from loading. Each registration is wrapped, and failures are reported via
`/pw diag` rather than being fatal.

**Unit-filtered events.** `UNIT_HEALTH`, `UNIT_FLAGS` and `UNIT_CONNECTION` fire
for every unit in the group, so they are registered against `pet` only.

**One path for every setting change.** The panel and the slash commands both go
through the same `settings` table in `Core.lua`, so the two cannot disagree
about what a change means, and the panel re-reads saved state on every show.

**Panel widgets are built from primitives.** Named Blizzard templates and their
child-widget layouts churn between expansions, and a missing template is a hard
error at construction — which for a settings panel would take the addon down
with it. The panel registers with the client's settings UI when that API is
available and falls back to its own window when it is not; both hosts show the
same content frame.

**Preview, because working looks like broken.** A healthy pet means the
indicator is hidden — which is indistinguishable from an addon that does not
work, and leaves no way to position it. Preview forces a state, and closes the
panel when it does, since the panel covers the thing you asked to look at.
Unlocking turns it on for the same reason: there would otherwise be nothing to
drag. It is never saved, and ends on zone or reload.

**No bundled font.** The addon this replaces shipped `Expressway.ttf` with no
accompanying licence. This uses the game's own fonts.

## Development

```sh
lua5.4 tests/state_spec.lua     # state logic, stubbed client API
lua5.4 tests/options_spec.lua   # panel construction and wiring, stubbed frames
luacheck .                      # lint
```

All three run in CI on every push, along with a check that
`PetWatch/PetWatch.toc` still matches its folder name.

Tagging `v*` builds a package via the [BigWigs packager][packager] — as
`PetWatch`, whatever the repository is called; CurseForge and Wago uploads
happen only when `CF_API_KEY` / `WAGO_API_TOKEN` are configured. No release has
been built yet, so the `move-folders` mapping in `.pkgmeta` that flattens the
subfolder layout is untested; check the first release's zip has
`PetWatch/PetWatch.toc` at its root and not `PetWatch/PetWatch/PetWatch.toc`.

The harnesses stub the client, so they can prove the state machine and the
panel's wiring but not the client's behaviour. A genuine secret value is a
client-side type that plain Lua cannot reproduce — the "unreadable" tests stub
the API to raise, which exercises the same branch. Only the game confirms which
queries actually return secrets, and only the game shows whether the panel
looks right.

## Licence

MIT — see [LICENSE](LICENSE).

[secrets]: https://warcraft.wiki.gg/wiki/Secret_Values
[packager]: https://github.com/BigWigsMods/packager
