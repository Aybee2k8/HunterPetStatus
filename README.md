# HunterPetStatus

A World of Warcraft Retail addon that shows an indicator when your hunter pet is
missing or dead.

Built for Midnight (12.x). This is a ground-up rewrite of an abandoned addon of
the same name — none of the original code is reused.

## Status

The logic is written and unit-tested, but **it has not yet run in the game.**
Two things still need confirming on a live client, and `/hps diag` reports both:

1. Whether `UnitIsDeadOrGhost("pet")` returns a [secret value][secrets] in 12.x.
   If it does, the pet's condition cannot be read directly and death detection
   has to be driven purely by events instead.
2. Whether `HasPetUI` is still present, and whether it still lingers after a pet
   dies. It is used here only as a tiebreaker, never as proof the pet is alive.

## Install

Copy the repository into a folder named `HunterPetStatus` under
`World of Warcraft/_retail_/Interface/AddOns/`, or install a packaged release.

## Commands

| Command | Effect |
| --- | --- |
| `/hps unlock` / `/hps lock` | Reposition the indicator by dragging |
| `/hps scale 1.0` | Resize it (0.3 – 4.0) |
| `/hps display icon\|text\|both` | Choose what is shown |
| `/hps mounted show\|hide` | Behaviour while mounted |
| `/hps on` / `/hps off` | Enable or disable |
| `/hps reset` | Restore defaults |
| `/hps diag` | Report what this client's API supports |

`/hps diag` is the thing to run after a patch — and the thing to paste into a
bug report. It prints the build, the resolved spec, and every API and event the
addon probed, so a breakage is visible without guessing.

## Layout

| File | Contains |
| --- | --- |
| `Compat.lua` | Every client-API difference, in one place |
| `State.lua` | Pet state resolution — the only real logic |
| `Display.lua` | Frame, icon, caption, dragging |
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
zoning, spec change). The original addon latched on this and never cleared it,
so once a pet had died the indicator stayed stuck on "Pet dead" for the rest of
the session; `tests/state_spec.lua` covers that case directly.

**Isolated event registration.** `RegisterEvent` throws on an unknown event name,
and those calls happen at load time — one renamed event would stop the whole
addon from loading. Each registration is wrapped, and failures are reported via
`/hps diag` rather than being fatal.

**Unit-filtered events.** `UNIT_HEALTH`, `UNIT_FLAGS` and `UNIT_CONNECTION` fire
for every unit in the group, so they are registered against `pet` only.

**No bundled font.** The original shipped `Expressway.ttf` with no accompanying
licence. This uses the game's own fonts instead.

## Development

```sh
lua5.4 tests/state_spec.lua   # state logic, stubbed client API
luacheck .                    # lint
```

Both run in CI on every push. Tagging `v*` builds a package via the
[BigWigs packager][packager]; CurseForge and Wago uploads happen only when
`CF_API_KEY` / `WAGO_API_TOKEN` are configured.

The test harness stubs the client API, so it can prove the state machine but not
the client's behaviour. A genuine secret value is a client-side type that plain
Lua cannot reproduce — the "unreadable" tests stub the API to raise, which
exercises the same branch. Only the game confirms which queries actually return
secrets.

## Licence

MIT — see [LICENSE](LICENSE).

[secrets]: https://warcraft.wiki.gg/wiki/Secret_Values
[packager]: https://github.com/BigWigsMods/packager
