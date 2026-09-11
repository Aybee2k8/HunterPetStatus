# PetWatch

A World of Warcraft Retail addon that shows an indicator when your hunter pet is
missing or dead.

Built for Midnight (12.x). Written from scratch — it replaces an abandoned addon
that stopped working in 12.0, and shares no code with it.

## Status

The logic is written and unit-tested, but **it has not yet run in the game.**
Two things still need confirming on a live client, and `/pw diag` reports both:

1. Whether `UnitIsDeadOrGhost("pet")` returns a [secret value][secrets] in 12.x.
   If it does, the pet's condition cannot be read directly and death detection
   has to be driven purely by events instead.
2. Whether `HasPetUI` is still present, and whether it still lingers after a pet
   dies. It is used here only as a tiebreaker, never as proof the pet is alive.

## Install

Copy the repository into a folder named **`PetWatch`** under
`World of Warcraft/_retail_/Interface/AddOns/`, or install a packaged release.
The folder name has to match `PetWatch.toc`, so a plain `git clone` needs
renaming (packaged releases are already named correctly).

## Settings

Type `/pw` to open the settings panel, or find **PetWatch** under
Game Menu → Options → AddOns. Everything is there: enable, behaviour while
mounted, what the indicator shows, its size, where it sits, and a button that
reports what the client API supports.

The slash commands remain as shortcuts:

| Command | Effect |
| --- | --- |
| `/pw` | Open the settings panel |
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

## Layout

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

**No bundled font.** The addon this replaces shipped `Expressway.ttf` with no
accompanying licence. This uses the game's own fonts.

## Development

```sh
lua5.4 tests/state_spec.lua     # state logic, stubbed client API
lua5.4 tests/options_spec.lua   # panel construction and wiring, stubbed frames
luacheck .                      # lint
```

All three run in CI on every push. Tagging `v*` builds a package via the
[BigWigs packager][packager] (as `PetWatch`, whatever the repository is called);
CurseForge and Wago uploads happen only when `CF_API_KEY` / `WAGO_API_TOKEN`
are configured.

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
