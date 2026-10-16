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

**2026-10-16, 09:30 ET: scope review done.** Feedback round 1 confirmed
as written (all six items, now Decided). Numy's Talent Tree Tweaks and
LibTalentTree reviewed: see "Numy's addons" below (lean on LTT; coexist
with TTT, don't rebuild it). Next: the player runs `update.bat dev` and
round 1 of the S2–S4 spike (`/tk spike`), still untested in game.

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
4. ~~S1~~ done offline (see Phase 0). S2–S4: `Dev/Spike.lua` (`/tk spike`,
   `#@debug@` in the TOC), round 1 out 2026-10-16; log in
   `TalentKeeperDB.spike`, taint in `_retail_\Logs\taint.log`.
   Give the player a grouped in-game test list per round (suite habit).
5. Write each spike's result into Phase 0 below, then plan v0.1.

CurseForge: project 1746823 (`talentkeeper`), GitHub webhook on this repo
(set up 2026-10-16). Nothing pending on the player's side.

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

## Feedback round 1 (2026-10-16, guild Discord): Decided

Confirmed by the player 2026-10-16 as written; the phases below carry them.

- **Boss memory from kills (MORG)**, reconciled with zone and boss
  awareness (player, 2026-10-16): both, per content type.
  - **Memory:** on a kill (`ENCOUNTER_END` success) record the talents for
    that encounter + difficulty; if they match a saved build, tag it (no
    new entry); if not, offer "Save as variant: Boss (Heroic)" (prompt on by
    default; silent auto-save opt-in). Next visit offers it ("Last time
    here you played X").
  - **M+:** one dungeon, so the target is the dungeon. Entering a
    Mythic dungeon = assume the player is about to run a key (the higher
    order activity; in plain Mythic talents stay changeable out of combat
    anyway), so **zone-in is the main offer**. Re-offer on ready check
    (everyone sees it; groups usually check before the key goes in). The
    keystone slot opening only reaches the keyholder, so it's a bonus
    re-offer for them, not something to rely on. Never offer after
    `CHALLENGE_MODE_START` (talents lock). Memory for M+ is per dungeon,
    recorded at key start. (player, 2026-10-16)
  - **Raid:** any boss could be next, so stack signals to name the likely
    next boss, between pulls: (1) journal bosses minus the ones this
    lockout already killed (`C_RaidLocks.IsEncounterComplete`); (2) where
    the player stands (map + subzone), learned from where past pulls of
    each boss started, so it improves with use; (3) seeing the boss
    (target / mouseover / nameplate), if Midnight allows; (4) for a linear
    raid, journal order. Offer the best guess with the other living
    bosses one click away.
  - **Decided: in 1.0 (v0.4).** S4 now logs all four raid signals.
- **Wrong-build reminder (whade).** In a zone tagged to a build, warn when
  the *active talents* don't match it (by talents, not loadout name). Same
  offer as zone-in, also on ready check. **Decided: in 1.0 (v0.4).**
- **Gear set per build (jix-aries).** Optional Blizzard equipment set
  linked to a build, equipped on apply. Small. **Decided: in 1.0 (v0.3).**
- **What counts as a different build (Jake / MORG).** Storage keeps every
  build complete; only the *display* collapses near matches. Proposed
  rule: same hero tree and a few spec-tree changes = shown as a variant of
  its main build; a different hero tree = its own main build. Diffs list
  class-tree changes (usually utility / survivability) apart from
  spec-tree changes. The switch menu still reads M+ > Murder Row > ...
  so "one build per dungeon, click it" (MORG's habit) keeps working.
  **Decided; tune the threshold with more examples** (S1 found 14 pairs
  within 6 nodes across 45 builds; more strings from other players
  welcome).
- **Raider.IO (Slonedog).** Don't rebuild what Raider.IO's talent-window
  button already does (pull builds from its database). Play nice: keep our
  button clear of theirs, and anything imported through it is recognized
  (duplicate check, boss memory) once it's active. **Decided: compatibility
  test with Raider.IO installed in S3; no import of our own.**
- **Out of scope:** Warcraft Logs import, a desktop companion app (no web
  access from addons; Raider.IO covers it).

## Numy's addons: Talent Tree Tweaks and LibTalentTree (2026-10-16)

Reviewed NumyAddon/TalentTreeTweaks and NumyAddon/LibTalentTree-1.0. The
player runs TTT with every module on except Import Into Current Loadout.

**LibTalentTree-1.0 (LTT): embed it, let it do the tree lifting.** Licence
allows shipping it unmodified in our addon (`.pkgmeta` externals, curse
slug `libtalenttree`, plus LibStub). It has data for every class, not just
the one you're logged in on, so builds from alts (TLE import spans 5
classes) get names and checks without logging over. What we use it for:
- `isClassNode`: diffs list class-tree changes apart from spec-tree
  changes (feedback rule above).
- `subTreeID`, `isSubTreeSelection`, `GetSubTreeInfo`: read the hero tree
  of a build (different hero tree = its own main build) and name it.
- `visibleForSpecs` / `grantedForSpecs` (`IsNodeVisibleForSpec`,
  `IsNodeGrantedForSpec`): compare only nodes the spec can see; free nodes
  never count as a difference.
- `GetNodeInfo` / `GetEntryInfo` (definition → spell name): talent names in
  diffs and variant change lists, any class (v0.2).
- Outdated badge: a saved pick whose node or entry no longer exists after a
  patch. Gates (`GetGates`), edges and `isApexTalent` /
  `requiredPlayerLevel` available if we need a stricter "still legal" check.
- Decode stays ours: `C_Traits.GetTreeNodes(treeID)` order + string bits
  (S1); `LTT:GetClassTreeID(classID)` gives the treeID. TTT's own parser
  does the same; we don't depend on TTT for it.

**Talent Tree Tweaks (TTT): coexist, don't rebuild.** No licence file, so
all rights reserved: ideas only, no code. It already covers inspect diff,
export / link / inspect from the loadout dropdown, clickable loadout
links, import into current loadout, mini tree in tooltips, taint
workarounds, muting chat spam on switching, hero-tree quick switch, respec
buttons, scaling. TalentKeeper builds none of these.
- **Mini tree for free:** TTT exposes a public global,
  `TalentTreeTweaks_EmbedMiniTreeIntoTooltip(tooltip, exportString)`. When
  TTT is loaded, hovering a build in our menu or window calls it, and the
  player gets TTT's mini tree with its diff colours against current
  talents. Without TTT: our text diff only. (v0.2)
- **Dropdown coexistence (S3):** TTT's mini tree and export modules hook
  Blizzard's loadout dropdown (`MENU_CLASS_TALENT_PROFILE`). Its mini-tree
  hook stops at the first entry without a configID, so if we add entries
  to that menu they go after Blizzard's, or TTT's hovers break below ours.
  Our own button + menu (the plan already) avoids this entirely.
- **Chat spam on apply:** TTT's Reduce Spam already mutes learn / unlearn
  lines on switching; ours applies through the same API, so no filter of
  our own (check in S2 with TTT on).
- After 1.0 idea: "Save to TalentKeeper" from a chat loadout link (TTT
  owns the link click; we'd need a light hook or just paste).

**Replacing TTT (player, 2026-10-16: wants to drop TTT from daily use and
build its talent features into TalentKeeper, our own way).** Clean-room:
features aren't owned, code is; build from Blizzard's API and
wow-ui-source, not TTT's source, and design each to fit TalentKeeper's
model (by-talents compare, saved builds) rather than copy TTT's behaviour.
Credit Numy as inspiration in the README. LTT stays (that's what it's for).
Inventory of what TTT does today (the player's settings: all on except
Import Into Current Loadout), **all Default until the player sorts them:**
- *Build features, fit TalentKeeper (proposed in 1.0):* mini tree on hover
  (our own drawing from LTT positions); inspect diff (compare an inspected
  player against your talents or any saved build, by name, and save it);
  improved chat loadout links (click: save to TalentKeeper with the
  duplicate check, copy, apply); export / link a build; mute learn /
  unlearn chat lines during our own apply; hero-tree quick switch and spec
  buttons in our menu.
- *Talent window tweaks (proposed after 1.0, pick the ones you'd miss):*
  always show gates (+ "points past the gate are free to move"); window
  scale; background transparency; stronger highlight for shift-click
  relearn; search by ID, IDs in talent tooltips, Ctrl-C spell ID, Ctrl-D
  node dump (dev tools; idTip already covers some IDs).
- *Fixes and unlocks (check need with TTT off):* loadout dropdown order /
  refresh after macro or addon switches / overlay blocking clicks; share
  without spending every point; spend points in combat; taint workarounds
  (share-button copy popup, cast bar errors on talent switch,
  MultiActionBar grid). Some of the taint may come from addons hooking the
  talent window in the first place; measure with TTT off.
- *Not talents, out of scope:* Skyriding / Horrific Visions / DRIVE auto
  purchase, bulk profession knowledge spending. Dropping TTT loses these.
- Next: one play session with TTT disabled; the player notes what he
  misses; that sorts the lists above.

**Other importers:** TLE on first run (v0.1). Talent Loadout Manager
import as a set-up helper for new users (the player doesn't need it;
**Default: before 1.0**).

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

- Embed LibTalentTree-1.0 + LibStub (`.pkgmeta` externals; `libs\` in the
  TOC). For `update.bat dev`, copy the lib into `libs\` locally (gitignored).
- Saved data: builds per class / spec, groups, PvP talents.
- Save current talents; apply; rename; delete (two-click "Sure?").
- Button + grouped menu by the talent window; `/tk` and a keybind open it
  anywhere.
- Import / export strings; import from TLE on first run.
- Log + debug, load line, smoke test (`Dev/smoke.lua`).

## v0.2: no duplicates

- Duplicate warning on save / import (Jump to it, Rename it, Save anyway).
- Near matches and the compare view (talent names via LTT; class vs spec
  tree split; hero tree shown).
- Hover a build: TTT's mini tree when TTT is loaded, text diff otherwise.
- Management window: spec → group, search, badges, drag to regroup.

## v0.3: main builds and variants

- Save as variant; variant changes listed by talent name; main-build edits
  carry through; "Needs review" on collisions; export a variant as a full
  string.
- Gear set per build: optional equipment set, equipped on apply.

## v0.4: zone awareness

- Tag builds / variants with dungeons and raids; offer the switch on
  zone-in (M+ at the entrance); single-boss raids included.
- Boss awareness in whatever form S4 allows (at least "next up" after a
  kill).
- Boss memory from kills (raid per boss + difficulty; M+ per dungeon at key
  start); M+ offer on Mythic zone-in + ready check; raid next-boss guess.
- Wrong-build reminder in tagged zones (by talents), also on ready check.

## 1.0

- Accessibility and style pass against the suite guide; Ponytail pass.
- README / CurseForge copy and screenshots; first stable release on the
  release cadence (see `Dev/RELEASING.md`).

## After 1.0 (ideas, not committed)

- Boss recognition before the pull, if S4 found it unreliable for 1.0.
- Anything from TLE / TLM the player misses after switching over.
