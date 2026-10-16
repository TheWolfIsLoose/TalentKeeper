# TalentKeeper — Roadmap

Forward plan, one section per release. Dev-only (`Dev/` never ships).
Shipped work moves to `Dev/HISTORY.md`; the player-facing summary goes in
`CHANGELOG.md` when a release is cut (see `Dev/RELEASING.md`).

Status key: **Decided**, **Default** (recommended; change it if you
disagree), **Open** (needs an answer before build).

---

## Next session: start here

**2026-10-15: repo set up before any code** (a first for the suite: SC, PUG
and Tones started as code). In place: TOC (12.1.5), icon set, release
workflow, `.pkgmeta`, README, CurseForge copy draft, style notes, this
roadmap. `main` = `dev` = scaffolding only; `CHANGELOG.md` has no version
heading, so pushes publish nothing.

Next: answer the **Open** items below, then build **Phase 0 (spikes)** on
`dev`. No player-facing code before the spikes report back.

**Kickoff checklist for the first code session** (parked 2026-10-15, 14:17 ET):
1. Attach the repo with push access (add_repo `TheWolfIsLoose/TalentKeeper`),
   clone, work on `dev`.
2. ~~Open questions~~ settled 2026-10-16. CurseForge project 1746823,
   slug `talentkeeper` (in the TOC and README).
3. Read the reference: TLE's apply code (`TalentLoadoutsEx\modules\import.lua`,
   resets the tree then `C_Traits.PurchaseRank` / `SetSelection` /
   `CommitConfig`) and its saved builds
   (`WTF\Account\SAVAGEFEARLESS\SavedVariables\TalentLoadoutsEx.lua`:
   per class → spec → list of `{name, text, icon, isInGroup, pvp1..}` with
   group header rows `{name, isExpanded}`), both in the player's `_retail_`
   folder. Blizzard's import/export code: Gethe/wow-ui-source `live`
   (`Blizzard_PlayerSpells`, `ClassTalentImportExportMixin`).
4. ~~S1~~ done offline (see Phase 0). Next: S2–S4 as a dev-only in-game
   `/tk spike`.
   Give the player a grouped in-game test list per round (suite habit).
5. Write each spike's result into Phase 0 below, then plan v0.1.

Pending on the player's side: point CurseForge's GitHub webhook at this
repo, as for SC / PUG / Tones.

Session setup (same as the other addons): player syncs with
`Dev\update.bat dev` and `/reload`; Claude reads
`WTF\Account\SAVAGEFEARLESS\SavedVariables\TalentKeeper.lua` via the
connected `_retail_` folder. Pushing needs the repo attached with push
access (add_repo).

---

## The idea

Both talent addons Jake has used fall short on **management**: Talent
Loadout Ex (TLE) groups builds well but bolts a big sidepane onto an
already big talent window; Talent Loadout Manager (TLM) has a smaller
footprint but weaker organizing. Neither knows when two builds are the
same, so duplicates and re-imports pile up.

TalentKeeper's core: **a build is its talent picks, not its import
string.** Decode every string into what it actually picks for its spec
(plus PvP talents) and compare those. Everything else follows from that.

## Decided

- **Name:** TalentKeeper. Folder / TOC `TalentKeeper`, slash `/tk`
  (`/talentkeeper` long form), saved data `TalentKeeperDB`.
- **Icon:** suite frame, gold `FFD84A` talent tree, nodes 1-2-3 in a
  triangle, bottom-center node joined to both middle nodes. Gold is the
  icon only (it sits near the suite's warning amber).
- **Compare by talents:** duplicate warning on save and import, near
  matches ("differs by 2 talents: X → Y"), compare any two builds by name.
  Badges: Active, Duplicate, Outdated (no longer fits the tree after a
  patch).
- **PvP talents** are saved as part of a build (for PvP players; Jake is
  PvE).
- **Main builds and variants:** a variant is stored as a list of changes
  from its main build (A → B, +C, −D), not a second full string. Editing
  the main build carries through; a variant whose changes collide with a
  main-build edit or a patch gets a "Needs review" badge. Make one by
  applying the main build, adjusting talents in Blizzard's window, then
  "Save as variant of …". Applying builds the full loadout on the spot;
  exporting gives a normal import string. A variant with no changes left
  counts as a duplicate.
- **Zone awareness is in 1.0:** tag a build or variant with dungeons /
  raids (picked from a list). Entering one **offers** the switch (never
  automatic). M+: offer at the entrance, because talents lock once the key
  starts. Single-boss raids (e.g. The Unbinding of Kith'ix) are covered as
  zones.
- **Boss awareness: try it.** Tag a build with a boss. Signals in order:
  single-boss raid = zone; "next up" after a kill; seeing the boss before
  the pull (target, mouseover, nameplate). The last one depends on a spike
  (Midnight hides some enemy identity from addons).
- **Layout:** switching = a small button by Blizzard's loadout dropdown
  that opens a grouped menu (Blizzard's menu system), plus a keybind /
  `/tk` to open it anywhere; managing = a separate window opened on demand
  (spec → group, search, badges, drag to regroup, compare). No sidepane.
- **Bring builds over:** first run imports TLE's saved builds (names,
  groups, strings) and flags duplicates right away. Jake has 31 TLE builds
  across 5 classes (19 warlock).
- **Suite rules apply:** style guide (WCAG 2.2, tokens, controls, words),
  saved log with `/tk log`, `/tk debug`, standalone.
- **Apply target:** TalentKeeper keeps one Blizzard loadout of its own
  ("TalentKeeper") and leaves the player's other Blizzard loadouts alone.
- **Storage:** account-wide, keyed by class and spec.
- **Groups:** one level (spec → group → builds → variants).
- **Not in 1.0:** custom icons, presets, SimC / WeakAuras export.

## Open

None. The four kickoff questions were settled 2026-10-16 (all defaults):
applied builds land in TalentKeeper's own Blizzard loadout slot; storage is
account-wide by class and spec; accent mint; one level of groups.

## Phase 0: spikes (on `dev`, dev-only, nothing ships)

Each answers a question before we design around it. Throwaway code in
`Dev/`, run in game, results written back here.

- **S1 Decode and compare.** Decode an import string into its picks
  (Blizzard's own import code path) for the player's spec, and diff two
  builds. Run it over the player's TLE builds: how many are duplicates or
  near matches? This proves the core idea.
  **Done 2026-10-16, offline** (`Dev/spikes/s1_compare.py`, no game needed):
  the string body is one record per tree node in `C_Traits.GetTreeNodes`
  order, so builds of one spec compare node by node without tree data.
  Ignore the 128-bit tree hash (it changes with patches, not picks).
  Over the player's 45 TLE builds (11 specs, serialization v2): **0 exact
  duplicates, 14 near pairs within 6 nodes** (closest: Assassination
  'Ula' vs 'Coiled' and Subtlety 'M' vs 'Raid', 2 nodes each; Destruction
  'Raid || HC Ula' vs 'Raid || HC Cleave', 3). Those near pairs are the
  natural main-build + variant candidates. In game, the same compare runs on
  the decoded records; talent names come from `C_Traits.GetNodeInfo` /
  `GetEntryInfo` / `GetDefinitionInfo` (v0.2).
- **S2 Apply.** Apply a decoded build the way TLE does (reset tree,
  buy nodes, commit), including hero talents and PvP talents; confirm
  where it lands (Open 1) and what happens in a rested area vs a dungeon
  entrance.
- **S3 Taint.** Hook Blizzard's loadout dropdown menu; check for taint
  errors in the talent window. If it taints, our own button opens our own
  menu (same feature, no hook).
- **S4 Zone and boss signals.** Log instance IDs on zone-in, encounter
  start/end, and whether a boss can be recognized from target / mouseover /
  nameplate out of combat. Decides how far boss awareness goes.

## v0.1: keep and switch (first alpha)

- Saved data: builds per class / spec, groups, PvP talents.
- Save current talents; apply; rename; delete (two-click "Sure?").
- Button + grouped menu by the talent window; `/tk` and a keybind open it
  anywhere.
- Import / export strings; import from TLE on first run.
- Log + debug, load line, smoke test (`Dev/smoke.lua`).

## v0.2: no duplicates

- Duplicate warning on save / import (Jump to it, Rename it, Save anyway).
- Near matches and the compare view (talent names).
- Management window: spec → group, search, badges, drag to regroup.

## v0.3: main builds and variants

- Save as variant; variant changes listed by talent name; main-build edits
  carry through; "Needs review" on collisions; export a variant as a full
  string.

## v0.4: zone awareness

- Tag builds / variants with dungeons and raids; offer the switch on
  zone-in (M+ at the entrance); single-boss raids included.
- Boss awareness in whatever form S4 allows (at least "next up" after a
  kill).

## 1.0

- Accessibility and style pass against the suite guide; Ponytail pass.
- README / CurseForge copy and screenshots; first stable release on the
  release cadence (see `Dev/RELEASING.md`).

## After 1.0 (ideas, not committed)

- Boss recognition before the pull, if S4 found it unreliable for 1.0.
- Anything from TLE / TLM the player misses after switching over.
