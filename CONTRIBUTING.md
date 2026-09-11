# Contributing

Notes for anyone working on this addon.

## What this is

A WoW Retail addon for Midnight (12.x). The repository root *is* the addon
folder — `HunterPetStatus.toc` sits at the top level and lists the Lua files in
load order.

## Before pushing

```sh
lua5.4 tests/state_spec.lua
luacheck .
```

Both run in CI. `luacheck` is configured to fail on warnings, so add new WoW
globals to `read_globals` in `.luacheckrc` rather than leaving them undeclared.

## Rules specific to this addon

- **Never call a unit API directly.** Everything goes through `compat.SafeFlag`
  in `Compat.lua`. Since 12.0 the client can return secret values that raise on
  comparison, and a direct call is a latent error. `SafeFlag` returns
  `true` / `false` / `nil`, and `nil` means "unreadable" — never treat it as
  `false`.

- **Keep `State.lua` free of frames and globals.** It is the only file the test
  harness can load, and that is only true while it depends on nothing but
  `Compat.lua`. Logic added elsewhere is logic that cannot be tested.

- **Bound any new state memory.** `sawPetDie` exists because a dead pet can stop
  answering to the `pet` token. It is cleared on every roster event. An
  unbounded latch is what broke the addon this replaces — see the "death memory"
  tests.

- **Register events through `compat.RegisterEvent`.** `RegisterEvent` throws on
  unknown event names at load time; one renamed event would otherwise stop the
  whole addon from loading.

- **Add new API dependencies to `compat.ProbeOptional`** so `/hps diag` reports
  them. That command is the first thing to run after a patch.

## Bumping for a new patch

Update `## Interface:` in `HunterPetStatus.toc` to the new build's interface
number (`/dump select(4, GetBuildInfo())` in game). Run `/hps diag` before
assuming anything else needs changing.

## Branch workflow

One task, one branch off `main`, one topic per PR. Never reuse a merged branch —
after a squash merge the branch diverges and stops being mergeable. Branch fresh
from `main` instead.
