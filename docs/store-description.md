# Addon page descriptions

Copy-and-paste text for CurseForge, Wago, WoWInterface and anywhere else the
addon is listed. Kept in the repository so the description cannot drift away
from what the addon actually does.

Most addon sites accept Markdown or have a rich-text editor that takes pasted
formatting. CurseForge's editor does; if a site wants BBCode instead, the
headings and bullet lists are the only things that need converting.

**Before publishing anywhere, read [Accuracy](#accuracy) at the bottom.**

---

## English

### Summary (short field, one line)

> Shows an icon when your hunter pet is missing or dead — so you notice before the pull, not after it.

### Description

**PetWatch** puts a small indicator on your screen when your hunter pet is not
where it should be.

Pets die quietly. You hear the sound, you miss it in a busy fight, and the next
two minutes are spent wondering why your damage feels wrong. PetWatch makes that
state visible: a clear icon, a short caption, and nothing at all when your pet is
fine.

#### What it does

- **Pet dead** — your pet is down and needs reviving.
- **Pet missing** — you have no pet out and need to call one.
- **Nothing** — your pet is alive. No icon, no clutter.

The indicator hides itself automatically while you are mounted or in a vehicle,
and on specialisations that do not use a pet.

#### Setting it up

Type `/pw` to open the settings, click **PetWatch** in the minimap's addon
compartment, or find it under Game Menu → Options → AddOns.

- Drag the indicator anywhere on screen
- Scale it from 0.3× to 4×
- Show the icon, the text, or both
- Choose whether it hides while mounted
- **Preview** — see the indicator without waiting for your pet to die, which is
  also how you position it

#### Commands

| Command | Effect |
| --- | --- |
| `/pw` | Open the settings panel |
| `/pw preview dead\|missing\|off` | Show the indicator on demand |
| `/pw unlock` / `/pw lock` | Move the indicator |
| `/pw scale 1.0` | Resize it |
| `/pw display icon\|text\|both` | Choose what is shown |
| `/pw mounted show\|hide` | Behaviour while mounted |
| `/pw on` / `/pw off` | Enable or disable |
| `/pw reset` | Restore defaults |
| `/pw diag` | Report what your client's API supports |

`/pw diag` is the one to run if something looks wrong — paste its output into a
bug report and it will usually say what broke.

#### Notes

- Built for Midnight (12.x). Beast Mastery and Survival only; Marksmanship is
  petless, so the indicator would be noise there.
- No dependencies, no libraries, no bundled fonts.

---

## Deutsch

### Kurzbeschreibung (einzeiliges Feld)

> Zeigt ein Symbol, wenn dein Jägerbegleiter fehlt oder tot ist — damit du es vor dem Pull merkst und nicht danach.

### Beschreibung

**PetWatch** blendet eine kleine Anzeige ein, wenn dein Jägerbegleiter nicht da
ist, wo er sein sollte.

Begleiter sterben leise. Man hört das Geräusch, überhört es im Getümmel, und
wundert sich die nächsten zwei Minuten, warum der Schaden sich falsch anfühlt.
PetWatch macht diesen Zustand sichtbar: ein deutliches Symbol, ein kurzer Text —
und gar nichts, solange alles in Ordnung ist.

#### Was es anzeigt

- **Pet dead** — dein Begleiter ist tot und muss wiederbelebt werden.
- **Pet missing** — du hast keinen Begleiter draußen und musst einen rufen.
- **Nichts** — dein Begleiter lebt. Kein Symbol, kein zugestellter Bildschirm.

Beim Reiten, in Fahrzeugen und in Spezialisierungen ohne Begleiter blendet sich
die Anzeige von selbst aus.

#### Einrichten

`/pw` öffnet die Einstellungen. Alternativ **PetWatch** im Addon-Fach an der
Minimap anklicken oder unter Spielmenü → Optionen → AddOns aufrufen.

- Anzeige frei auf dem Bildschirm platzieren
- Größe zwischen 0,3× und 4× einstellen
- Symbol, Text oder beides anzeigen
- Verhalten beim Reiten festlegen
- **Vorschau** — die Anzeige einblenden, ohne auf den Tod des Begleiters zu
  warten; so positionierst du sie auch

#### Befehle

| Befehl | Wirkung |
| --- | --- |
| `/pw` | Einstellungsfenster öffnen |
| `/pw preview dead\|missing\|off` | Anzeige zum Testen einblenden |
| `/pw unlock` / `/pw lock` | Anzeige verschieben |
| `/pw scale 1.0` | Größe ändern |
| `/pw display icon\|text\|both` | Was angezeigt wird |
| `/pw mounted show\|hide` | Verhalten beim Reiten |
| `/pw on` / `/pw off` | Ein- oder ausschalten |
| `/pw reset` | Standardwerte wiederherstellen |
| `/pw diag` | Meldet, was die API deines Clients unterstützt |

`/pw diag` ist der Befehl für den Fehlerfall — die Ausgabe in einen Bugreport
kopieren, dann steht dort meist direkt, was kaputt ist.

#### Hinweise

- Für Midnight (12.x). Nur Tierherrschaft und Überleben; Treffsicherheit spielt
  ohne Begleiter, dort wäre die Anzeige nur Störung.
- Keine Abhängigkeiten, keine Bibliotheken, keine mitgelieferten Schriftarten.

---

## Footer (goes last on the page, after both languages)

CurseForge requires anything pointing off-platform — source links, issue
trackers, personal sites — to sit at the *bottom* of the description, below the
functional content. This is the only block that links out, so keep it last.

> Open source under the MIT licence. Bug reports and feature requests are
> welcome on the issue tracker.
>
> Quelloffen unter der MIT-Lizenz. Fehlerberichte und Feature-Wünsche sind im
> Issue-Tracker willkommen.

---

## Accuracy

Everything above describes behaviour the addon implements, and the central claim
is now backed by observation.

**Pet-death detection has been seen working on a live client** (12.1.0, Beast
Mastery, solo), with a pet that actually died:

```
resolved state: dead
pet: exists=true dead=true hunterPetUI=true
```

The text above can be published as it stands. No beta note is needed for that
claim.

One softer caveat remains, and it is worth knowing even though it does not
belong in the store text: every reading so far has been solo and out of combat.
Midnight's secret values are context-dependent, so a raid or Mythic+ may behave
differently. If they do, the addon degrades rather than breaks — it holds the
last known state instead of showing something wrong — but "degrades" is not
"tested". Worth a line in the changelog once someone has run it in a group.

---

## CurseForge submission checklist

Points from CurseForge's moderation policy that this project actually touches.

**Settled by the text above**

- *English first.* Other languages are allowed, but the English version has to
  appear before them. The order in this file is the order to paste.
- *Summary is one sentence and not copied from the description.* Both are
  written to that rule.
- *Description carries functional information*, not just flavour — states,
  settings and commands are all listed.
- *Off-platform links sit at the bottom.* That is the Footer block.

**Needs a decision from you**

- **Avatar: do not use the in-game spell icon.** The addon uses
  `Ability_Hunter_BeastTaming` as its in-game list icon, which is fine — it is
  Blizzard's art used inside Blizzard's client. Uploading that same art as a
  400×400 CurseForge avatar is not the same thing: the policy forbids
  copyrighted imagery in avatars. Draw or generate something original.
  (400×400, no solid colours, avoid WebP — their uploader has a known bug
  with it.)

- **Issue tracker means a public repository.** The policy recommends a
  communication channel for bug reports, and `/pw diag` output is the whole
  point of having one. The repository is currently private, so there is nowhere
  for a player to file anything. Either make it public or set up another
  channel before pointing at one.

- **Every file upload needs a changelog entry.** `CHANGELOG.md` is in the
  repository for this; keep it current, and paste the relevant section into the
  file's changelog field on upload. Re-uploads without functional changes are
  explicitly against the Fair Play rule.

**Worth knowing, no action needed**

- *Names must not contain a game or class name.* "PetWatch" is clean. The
  earlier working name — Hunter Pet Status — would have run straight into this,
  which is a second reason the rename was worth doing.

- *Forks must credit the original and be licence-permitted.* This is not a
  fork: no code, text or assets were carried over, and the name is distinct. The
  description deliberately does not frame the addon as a successor to anything,
  because implying a lineage that does not exist would invite a copyright review
  over nothing. If a moderator ever asks, the answer is that it was written from
  scratch — and the git history shows it.
