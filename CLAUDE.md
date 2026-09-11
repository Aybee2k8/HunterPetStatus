# CLAUDE.md

Guidance for Claude Code / AI agents working in this repository.

## What this is

A WoW Retail addon for Midnight (12.x), called **PetWatch**.

The addon lives in `PetWatch/`, not at the repository root, so that a clone or
ZIP download already contains a correctly named folder to drop into
`Interface/AddOns`. **The folder name and the `.toc` name must match** — the
client silently skips a folder whose `.toc` does not share its name, and the
addon then never appears in the list at all, not even as out of date. CI asserts
`PetWatch/PetWatch.toc` exists for exactly this reason; do not flatten the
layout.

The repository may still be named after its predecessor. That is cosmetic:
`package-as: PetWatch` in `.pkgmeta` decides the packaged folder name. Nothing
in the code should refer to the old name.

## Before pushing

```sh
lua5.4 tests/state_spec.lua
lua5.4 tests/options_spec.lua
luacheck .
```

All three run in CI. `luacheck` is configured to fail on warnings, so add new
WoW globals to `read_globals` in `.luacheckrc` (or `globals`, if the addon
writes to them) rather than leaving them undeclared.

## What a live client has actually confirmed

Measured on 12.1.0 (interface 120100), Beast Mastery, solo, **living pet**:

| | |
| --- | --- |
| `UnitIsDeadOrGhost("pet")` | readable, not a secret value |
| `HasPetUI` | present |
| `GetSpecialization` (global) | still present, alongside `C_SpecializationInfo` |
| Every registered event | accepted |

Two corrections to earlier assumptions, recorded so they are not repeated:
`GetSpecialization` was **not** removed in 12.0, and the predecessor addon's
`## Interface: 120000, 120100` was **not** out of date — 120100 is live. Both
claims came from search summaries rather than a primary source.

What is still unmeasured: the dead-pet path (does `UnitExists("pet")` stay true
once the pet dies?), and whether any of these stay readable in combat, raids or
Mythic+. Secret values are context-dependent, so a solo reading proves very
little. This is why `compat.SafeFlag` stays on every unit query regardless of
the table above.

## Rules specific to this addon

- **Never call a unit API directly.** Everything goes through `compat.SafeFlag`
  in `Compat.lua`. Since 12.0 the client can return secret values that raise on
  comparison, and a direct call is a latent error. `SafeFlag` returns
  `true` / `false` / `nil`, and `nil` means "unreadable" — never treat it as
  `false`.

- **Keep `State.lua` free of frames and globals.** It is the only logic file the
  test harness can load, and that is only true while it depends on nothing but
  `Compat.lua`. Logic added elsewhere is logic that cannot be tested.

- **Bound any new state memory.** `sawPetDie` exists because a dead pet can stop
  answering to the `pet` token. It is cleared on every roster event. An
  unbounded latch is what broke the addon this replaces — see the "death memory"
  tests.

- **Register events through `compat.RegisterEvent`.** `RegisterEvent` throws on
  unknown event names at load time; one renamed event would otherwise stop the
  whole addon from loading.

- **Route every setting change through the `settings` table in `Core.lua`.** The
  panel and the slash commands share it. A change written directly to the saved
  variables from one of them will silently drift from the other.

- **Do not introduce named Blizzard templates into `Options.lua`** beyond the
  few already there (`UICheckButtonTemplate`, `UIPanelButtonTemplate`,
  `UIPanelCloseButton`, `BackdropTemplate`). Template names and their child
  layouts churn between expansions, and a missing one is a hard error at
  construction time. Build from primitives and own the widget's parts —
  especially label FontStrings, which the templates expose differently across
  versions.

- **Add new API dependencies to `compat.ProbeOptional`** so `/pw diag` reports
  them. That command is the first thing to run after a patch.

## Bumping for a new patch

Update `## Interface:` in `PetWatch/PetWatch.toc`. **Take the number from a live
client** — `/dump select(4, GetBuildInfo())` — or from the Mainline row of the
wiki's build table.

Do not take it from a search result or from the newest-looking patch number. The
highest 12.x version is usually the PTR, not live: at the time of writing,
Mainline is 12.1.0 / `120100` while Mainline **Test** is 12.1.5 / `120105`. An
addon declaring only the PTR number is marked incompatible on live and, unless
the player ticks "Load out of date AddOns", does not load at all. That mistake
has already cost one round here.

The TOC lists both, comma-delimited, so the addon loads on either. Keep the live
number first.

Run `/pw diag` before assuming anything else needs changing; it prints the
client's interface version next to the one the addon declares.

## Branch workflow

One task, one branch off `main`, one topic per PR. Never reuse a merged branch —
after a squash merge the branch diverges and stops being mergeable. Branch fresh
from `main` instead.
