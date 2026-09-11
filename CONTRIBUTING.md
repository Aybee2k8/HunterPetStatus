# Contributing

Notes for anyone working on this addon — what the code assumes, what a live
client has actually confirmed, and the mistakes already made so they are not
repeated.

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

Measured on 12.1.0 (interface 120100), Beast Mastery, solo, with a **living**
and then an actually **dead** pet:

| | |
| --- | --- |
| `UnitExists("pet")` with a dead pet | **true** — the token keeps answering |
| `UnitIsDeadOrGhost("pet")` | readable either way, not a secret value |
| `HasPetUI` | present, and **true for a dead pet** |
| `GetSpecialization` (global) | still present, alongside `C_SpecializationInfo` |
| Every registered event | accepted |
| Detection end to end | `resolved state: dead` — it works |

Three corrections to earlier assumptions, recorded so they are not repeated:

1. `GetSpecialization` was **not** removed in 12.0.
2. The predecessor addon's `## Interface: 120000, 120100` was **not** out of
   date — 120100 is live.
3. **A dead pet does not stop answering to the `pet` token.** The predecessor
   asserted it does and built its detection on that; the measurement above says
   otherwise. Do not restate it as fact.

The first two came from search summaries rather than a primary source. The third
came from trusting the predecessor's own comment.

Consequence for `State.lua`: the despawn fallback (`sawPetDie`, and the
`HasPetUI` tiebreaker under it) is not the load-bearing path — the plain
`exists → dead` branch is. Keep the fallback anyway; one reading on one build
with one pet does not prove the case never occurs. But do not describe the file
as being shaped by it.

## Pet health is secret: no "pet is hurt" indicator

Asked for, and investigated. A `/run` test of the comparison such a feature
needs returns, consistently:

```
attempt to perform arithmetic on a secret number value
```

So `UnitHealth("pet")` is a secret value and arithmetic on it is refused. A
threshold ("show when below 70%") cannot be computed, and the feature cannot be
built that way. **Do not re-attempt it** without new evidence.

Two caveats on that conclusion, both honest:

- The `/run` path carries `ForceTaint_Strong`, which may be stricter than an
  addon's own execution. `compat.HealthComparable()` runs the same comparison
  from inside the addon and reports the result in `/pw diag` — that line is the
  authoritative answer, and is also a regression detector if Blizzard ever
  relaxes this.
- Secrets may still be *passed* to certain native APIs, `StatusBar:SetValue()`
  among them. So displaying pet health as a bar is likely possible even though
  deciding anything about it is not. That is a different feature — showing,
  not alerting — and nobody has asked for it.

Still unmeasured: whether any of these stay readable in combat, raids or
Mythic+. Secret values are context-dependent, so a solo reading proves little.
This is why `compat.SafeFlag` stays on every unit query regardless of the table
above.

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

- **Keep the preview out of saved variables.** It forces the indicator to show a
  state the pet is not in. Persisting that would leave someone convinced their
  pet is dead after a relog. It is cleared on `PLAYER_ENTERING_WORLD` for the
  same reason.

- **The TOC carries a literal `## Version`, not `@project-version@`.** The
  placeholder is only substituted when a release is built, so a clone install
  would display the placeholder itself. Bump it together with the release tag;
  the release workflow refuses a tag that disagrees with it.

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

## Publishing to CurseForge

The release workflow uploads through CurseForge's upload API, via the BigWigs
packager, and runs **only on a `v*` tag** — never on a merge to `main`. Two
things beyond the tag are required, and without either the packager still builds
the zip and attaches it to the GitHub release but skips the upload *silently*:

- `## X-Curse-Project-ID` in `PetWatch/PetWatch.toc` (and `## X-Wago-ID` for
  Wago).
- A `CF_API_KEY` repository secret, from CurseForge's API Tokens page. The
  workflow sets both `CF_API_KEY` and `CF_API_TOKEN` from it: the packager's
  README names one, its GitHub Action wiki names the other, and the two
  disagree.

Bump `## Version` in the TOC before tagging. The workflow refuses a tag that
disagrees with it, so a version already published cannot be re-uploaded by
accident.

### Trying a packaging change safely

The `move-folders` mapping in `.pkgmeta` has never been exercised, and it is not
the shape CurseForge's own documentation shows: their example moves a nested
folder to a *different* top-level name, while this one moves `PetWatch/PetWatch`
onto its own parent. It may simply work; nobody has checked.

CurseForge reads the release type from the tag name — one containing `alpha` or
`beta` is filed in that channel instead of as a release. The version check
ignores a pre-release suffix for that reason, so `v0.2.0-alpha1` against a TOC of
`0.2.0` is a complete end-to-end run — same packager, same `.pkgmeta`, same
upload path — that lands in the alpha channel and leaves the release channel
alone. Check the resulting zip has `PetWatch/PetWatch.toc` at its root and not
`PetWatch/PetWatch/PetWatch.toc`, then delete the alpha file and the tag.

### Pick one automation, not two

CurseForge's project settings have their own **Automatic Packaging**, driven by a
repository webhook, which also builds from tags and reads the same `.pkgmeta`.
Enabling it alongside this workflow means two builds of the same tag and two
uploads. If CurseForge's own packaging is turned on, delete this workflow.

## Branch workflow

One task, one branch off `main`, one topic per PR. Never reuse a merged branch —
after a squash merge the branch diverges and stops being mergeable. Branch fresh
from `main` instead.
