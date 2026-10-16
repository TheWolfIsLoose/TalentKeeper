# TalentKeeper — Roadmap

Forward plan, one section per release. Dev-only (`Dev/` never ships).
Shipped work moves to `Dev/HISTORY.md`; the player-facing summary goes in
`CHANGELOG.md` when a release is cut (see `Dev/RELEASING.md`).

Status key: **Decided**, **Default** (recommended; change it if you
disagree), **Open** (needs an answer before build).

---

## Next session: start here

**2026-10-15: repo set up before any code.** In place: TOC (12.1.5), icon
set, release workflow, `.pkgmeta`, README, CurseForge copy draft, style
notes, this roadmap. `main` = `dev` = scaffolding only; `CHANGELOG.md` has
no version heading, so pushes publish nothing.

**2026-10-16: scope review done.** Feedback round 1 decided (below). Next:
round 1 of the S2–S4 spike (`/tk spike`), still untested in game, run with
other talent-window addons disabled.

Kickoff checklist:
1. Work on `dev`.
2. ~~Open questions~~ settled 2026-10-16. CurseForge project 1746823,
   slug `talentkeeper` (in the TOC and README).
3. Reference: Blizzard's import/export code, Gethe/wow-ui-source `live`
   (`Blizzard_PlayerSpells`, `ClassTalentImportExportMixin`). Apply = reset
   the tree, then `C_Traits.PurchaseRank` / `SetSelection` / `CommitConfig`.
4. ~~S1~~ done offline (see Phase 0). S2–S4: `Dev/Spike.lua` (`/tk spike`,
   `#@debug@` in the TOC), round 1 out 2026-10-16; log in
   `TalentKeeperDB.spike`, taint in the game's `Logs\taint.log`.
   Each round: rewrite the DevChecklist (`/dc`), grouped by area.
5. Write each spike's result into Phase 0 below, then plan v0.1.

CurseForge: project 1746823 (`talentkeeper`), GitHub webhook on this repo.

Dev loop: GitHub is the record, not the install path. Commit and push to
`dev`, then write the changed files straight into the installed addon
folder (stamp `Build.lua` with the commit). `Dev/update.bat` is only a
fallback full resync.

---

## The idea

Talent loadout addons fall short on **management**: some group builds well
but bolt a big sidepane onto an already big talent window; others keep a
small footprint but organize weakly. None know when two builds are the
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
- **PvP talents** are saved as part of a build.
- **Main builds and variants:** a variant is stored as a list of changes
  from its main build (A → B, +C, −D), not a second full string. Editing
  the main build carries through; a variant whose changes collide with a
  main-build edit or a patch gets a "Needs review" badge. Make one by
  applying the main build, adjusting talents in Blizzard's window, then
  "Save as variant of …". Applying builds the full loadout on the spot;
  exporting gives a normal import string. A variant with no changes left
  counts as a duplicate.
- **What counts as a different build:** storage keeps every build
  complete; only the *display* collapses near matches. Same hero tree and a
  few spec-tree changes = shown as a variant of its main build; a different
  hero tree = its own main build. Diffs list class-tree changes (usually
  utility / survivability) apart from spec-tree changes. The switch menu
  still reads M+ > dungeon > ... so "one build per dungeon, click it"
  works. Tune the threshold with more example strings.
- **Zone awareness is in 1.0:** tag a build or variant with dungeons /
  raids (picked from a list). Entering one **offers** the switch (never
  automatic). Single-boss raids are covered as zones.
- **Boss awareness and boss memory (1.0, v0.4):** both, per content type.
  - **Memory:** on a kill (`ENCOUNTER_END` success) record the talents for
    that encounter + difficulty; if they match a saved build, tag it (no
    new entry); if not, offer "Save as variant: Boss (Heroic)" (prompt on by
    default; silent auto-save opt-in). Next visit offers it ("Last time
    here you played X").
  - **M+:** the target is the dungeon. Entering a Mythic dungeon = assume a
    key is next (in plain Mythic talents stay changeable out of combat
    anyway), so **zone-in is the main offer**. Re-offer on ready check
    (everyone sees it; groups usually check before the key goes in). The
    keystone slot opening only reaches the keyholder: a bonus re-offer, not
    something to rely on. Never offer after `CHALLENGE_MODE_START` (talents
    lock). M+ memory is per dungeon, recorded at key start.
  - **Dungeons (any difficulty): the build is chosen on entry, and that's
    it** (2026-10-16). Nobody swaps talents between dungeon bosses, and M+
    locks them at key start, so no per-boss offers or boss sighting in
    dungeons; memory and tags are per dungeon.
  - **Delves (Default, 2026-10-16):** treated like dungeons, build chosen
    on entry. Often a delve gets the same build as other content, so it's
    opt-in: one "Delves" tag covering every delve (per-delve tags only if
    asked for). Entering a delve with no build tagged for Delves gives one
    gentle nudge ("Want a build for Delves? Tag one", with "Don't ask
    again"); after that it's quiet. Detection: `GetInstanceInfo` type
    `scenario`, difficulty 208 (Delves); the spike logs it on its own, so
    confirm on the next delve.
  - **Raid:** any boss could be next, so stack signals to name the likely
    next boss, between pulls: (1) journal bosses minus the ones this
    lockout already killed (`C_RaidLocks.IsEncounterComplete`); (2) where
    the player stands (map + subzone), learned from where past pulls of
    each boss started; (3) seeing the boss (target / mouseover /
    nameplate), if Midnight allows; (4) for a linear raid, journal order.
    Offer the best guess with the other living bosses one click away.
- **Wrong-build reminder (1.0, v0.4):** in a zone tagged to a build, warn
  when the *active talents* don't match it (by talents, not loadout name).
  Same offer as zone-in, also on ready check.
- **Gear set per build (1.0, v0.3):** optional Blizzard equipment set
  linked to a build, equipped on apply.
- **Layout:** switching = a small button by Blizzard's loadout dropdown
  that opens a grouped menu (Blizzard's menu system), plus a keybind /
  `/tk` to open it anywhere; managing = a separate window opened on demand
  (spec → group, search, badges, drag to regroup, compare). No sidepane.
  Our own button and menu, not entries added to Blizzard's dropdown.
- **Play nice:** standalone, but don't crowd other addons' talent-window
  buttons, and builds applied by anything else are still recognized
  (duplicate check, boss memory) once active.
- **Bring builds over:** first run imports saved builds from other talent
  addons (names, groups, strings) and flags duplicates right away.
- **Suite rules apply:** style guide (WCAG 2.2, tokens, controls, words),
  saved log with `/tk log`, `/tk debug`.
- **Apply target:** TalentKeeper keeps one Blizzard loadout of its own
  ("TalentKeeper") and leaves the player's other Blizzard loadouts alone.
- **Storage:** account-wide, keyed by class and spec.
- **Groups:** one level (spec → group → builds → variants).
- **Library:** LibTalentTree-1.0 (embedded unmodified via `.pkgmeta`) for
  tree data of every class: class vs spec nodes, hero trees
  (`subTreeID`), nodes visible / granted per spec (free nodes never count
  as a difference), talent names, Outdated checks. Decoding strings stays
  ours (`C_Traits.GetTreeNodes` order + string bits).
- **Not in 1.0:** custom icons, presets, sim / aura export, log import,
  desktop companion app, mini tree previews.

## Open

None.

## Talent window features (2026-10-16)

TalentKeeper also takes over the talent-window extras, built from
Blizzard's API in our own way.
- **In 1.0 (Default, cheap on top of compare / apply):** inspect compare
  (an inspected player against your talents or any saved build, by name,
  and save it); clickable loadout links in chat (save to TalentKeeper with
  the duplicate check, copy, apply); export / link a build; mute learn /
  unlearn chat lines during our own apply; hero-tree quick switch and spec
  buttons in our menu.
- **After 1.0 (Default, nice-to-have):** always show gates (+ "points past
  the gate are free to move"); window scale; background transparency;
  stronger highlight for shift-click relearn; search by ID, IDs in talent
  tooltips, copy spell ID, node dump (dev tools).
- **Fixes and unlocks (after 1.0, only what testing shows is needed):**
  loadout dropdown order / refresh after macro switches / overlay blocking
  clicks; share without spending every point; spend points in combat;
  taint workarounds (share-button copy popup, cast bar errors on talent
  switch, action bar grid). The S2–S4 spike shows whether these errors are
  Blizzard's own or come from hooks.
- **Out of scope:** auto-purchase for non-class trees (Skyriding and
  similar), profession knowledge spending.

## Phase 0: spikes (on `dev`, dev-only, nothing ships)

Each answers a question before we design around it. Throwaway code in
`Dev/`, run in game, results written back here.

- **S1 Decode and compare.** Decode an import string into its picks for
  the player's spec, and diff two builds. Run it over a real set of saved
  builds: how many are duplicates or near matches? This proves the core
  idea.
  **Done 2026-10-16, offline** (`Dev/spikes/s1_compare.py`, no game needed):
  the string body is one record per tree node in `C_Traits.GetTreeNodes`
  order, so builds of one spec compare node by node without tree data.
  Ignore the 128-bit tree hash (it changes with patches, not picks).
  Over 45 builds (11 specs, serialization v2): **0 exact duplicates, 14
  near pairs within 6 nodes** (closest pairs 2 nodes apart). Those near
  pairs are the natural main-build + variant candidates.
- **S2 Apply.** Apply a decoded build (reset tree, buy nodes, commit),
  including hero talents and PvP talents; confirm where it lands and what
  happens in a rested area vs a dungeon entrance; check learn / unlearn
  chat spam.
  **Round 1 (2026-10-16): works.** `C_ClassTalents.ImportLoadout` into one
  "TalentKeeper" slot (old slot deleted first; the player's other loadouts
  untouched), then `LoadConfig`; talents and PvP verified after each apply,
  rested or not, talent window open or closed, inside a dungeon (no key).
  No chat flood. One `LoadConfig` returned Error (window open, right after a
  menu hook); a retry worked, so v0.1 retries once. One build verified with
  1 difference every time: a stale node in that string (the Outdated badge
  case). Key-start talent lock now logged passively.
- **S3 Taint.** Hook Blizzard's loadout dropdown menu; check for taint
  errors in the talent window. If it taints, our own button opens our own
  menu (same feature, no hook). **Round 1: no errors either way**, action
  buttons fine after switches (other talent-window addons off). Own button
  stays the plan.
  Caution: `taintLog` is a saved CVar and, while on, set off a flood of
  Blizzard nameplate driver errors. Any round that turns it on ends with
  `/console taintLog 0` as its last checklist item.
- **S4 Zone and boss signals.** Log instance IDs on zone-in, encounter
  start/end, ready check, keystone slot, killed bosses, and whether a boss
  can be recognized from target / mouseover out of combat. Decides how far
  boss awareness goes. **Passive** (logs on its own during normal play; a
  raid-warning reminder on zone-in says what to do by hand, raids only).
  Round 1: zone-in logged; the journal lookup by map failed for one
  dungeon (name fallback added); **mouseover inside an instance returns
  name and NPC ID as secret** (level and classification readable), so boss
  sighting by identity is likely out; confirm on a real boss.
  **Raid run (LFR, single-boss raid, 2026-10-16): done.** Zone-in gives
  instance type, ID and difficulty; the journal resolves from the boss
  room's map (the entrance map isn't linked). `ENCOUNTER_START` / `END` /
  `BOSS_KILL` give the boss name, encounter ID, difficulty and wipe / kill
  in readable form, so **boss memory from kills works**. Target / mouseover
  keep name and NPC ID secret even on the boss; the boss shows as **elite,
  level -1** (trash: 90-91), so "a boss is in front of you" is readable but
  not which one. **Default: no boss recognition by sight.** Next-boss guess
  = lockout kills + where the player stands (learned from past pulls) +
  journal order, and a level -1 target only confirms "at a boss". Same
  secrecy in Normal dungeons, out of combat.
  **Raid flow (Default, 2026-10-16).** Two ways in, same result:
  - *Learn as you go:* zone in with whatever talents you have; on each kill
    TalentKeeper offers "Save as build for Boss (Heroic)" (or tags the
    matching saved build silently). Next lockout, it offers those builds.
  - *Set up ahead:* tag saved builds to a raid or to bosses before the
    raid (management window).
  When it asks, never in combat or during an encounter:
  1. **Zone-in:** the build tagged for the raid (or the likely first boss).
  2. **After a kill:** the build for the likely next boss. That's when
     people swap talents anyway, and the save offer for the boss just
     killed rides along.
  3. **Ready check:** if your talents don't match the likely next boss's
     build, a reminder (the wrong-build reminder). Leaders ready-check
     before pulls, so it lands right before it matters.
  4. **Map / subzone change** into the area where a boss was pulled before:
     updates the guess quietly; only asks if nothing was offered since the
     last kill.
  Location = map ID + subzone name at `ENCOUNTER_START`, learned from
  your own pulls; x,y is expected to be unavailable inside instances (the
  spike now logs it to confirm).
  **Content awareness is a pillar, so both (Default, 2026-10-16):**
  - *Telegraph learning, always.* Every offer says why: "Next: Boss X
    (after your kills)" vs "Next: Boss X (you're where it's pulled)". The
    menu shows the raid's state: "Learning this raid: 3 of 8 boss spots
    known". First visit says so plainly: "TalentKeeper learns where each
    boss is pulled as you raid." Learning is the fallback for any raid with
    no shipped data and fixes shipped data that's wrong.
  - *Pre-load what we can.* Ship a small seed file of boss pull spots (map
    ID + subzone per encounter ID) for current raids, captured from our own
    live runs with a dev-only export (`/tk dev spots`). New raid: seed from
    live week 1 in a quick follow-up release; PTR runs feed it too when they
    happen (spike / export are passive), but nothing depends on PTR.
  **Mark a spot by hand (Default, 2026-10-16):** for players who want to
  tune it, the menu gets "Prepare for <boss> here": it records the current
  map + subzone as that boss's trigger (overrides learned and shipped
  spots). Granularity is subzone, since x,y is likely unavailable in
  instances. Advanced, tucked in the menu, never a pop-up.
  **Guardrails on hand-marked spots (Default, 2026-10-16), in code, not
  just words:**
  - Only in a raid, out of combat, not during an encounter, for a boss
    picked from this raid's journal list (no free text).
  - A spot is map ID + subzone only (repeatable); no x,y. Refused where
    there's no subzone name, and where the subzone is the whole raid's
    name (too broad).
  - One spot per boss; one boss per spot. A spot already tied to another
    boss is refused with "That's Boss Y's spot" (Replace / Cancel).
  - The confirm names the area: "Prepare for Boss X when you enter
    'Kith'ix's Prison'?" and says what's good: "the room or doorway right
    before the pull, not a hallway you pass through".
  - Fires only on entering the spot, at most once per boss between kills,
    never in combat; the next-boss logic still has to agree the boss is
    alive this lockout.
  - Self-correcting: a hand spot whose offer is declined, or followed by a
    different boss's pull, 3 times in a row is retired with a notice.
    "Reset to learned" is always one click in the management window.
  **Boss sighting as a guided mark (Default, 2026-10-16):** a level -1
  unit (skull) moused over or targeted out of combat = "you're at a boss".
  Identity stays secret, so TalentKeeper pairs it with its next-boss guess:
  "Looks like you're at a boss. Prepare for Boss X here?" (other living
  bosses one click away). Confirming makes the hand-marked spot, under the
  same guardrails. Hand marks then also require a skull seen in that
  subzone this visit, which ties every spot to a real boss.
  `ENCOUNTER_START` still confirms which boss it was and corrects the spot.
  To verify: -1 seen once (single-boss raid). The next heroic run logs
  every unit's level (passive), to check that every boss is -1 and how
  often trash or minibosses are too.
  **Across specs (Default, 2026-10-16):** a boss can be tagged with builds
  from any of the class's specs. The offer names spec and build
  ("Next: Boss X, Destruction 'Raid HC Cleave'"); one click, after the
  player confirms, switches spec, waits for it, then applies the build.
  Memory keeps the last kill per spec; the offer leads with the most recent
  and lists the other specs' builds one click away. Gear sets per build
  cover the gear side. Spike S5 checks the switch-then-apply chain.
  **Everything else is read live** (Default): zone, boss list (journal),
  lockout kills and encounters are all read from the game at runtime, so a
  new raid works on patch day. Only boss-pull positions are learned, per
  player, from their own pulls; until then the guess uses lockout + journal
  order. PTR is only for a smoke test that these APIs still behave.

- **S5 Spec swap.** From one click: switch spec, wait for it, apply a
  build of that spec into that spec's TalentKeeper slot (`/tk spike swap
  <spec> <n>`). Check timing, interruption by moving, and that each spec
  keeps its own slot.
  **Round 2 (2026-10-16): works.** `SetSpecialization` from our own call
  (no hardware event needed), spec active after ~5 s, then the build
  applies into that spec's own TalentKeeper slot; the other spec's slot is
  left alone. Moving during the cast cancels it and nothing applies, but
  the pending swap stayed armed: v0.1+ clears it on cast interrupt / fail
  or after 15 s, so a later manual spec change can't apply a stale build.
  A second build ('Raid || HC ST', Destruction) also verifies 1 node off:
  stale strings are common, so the Outdated badge matters.

## v0.1: keep and switch (first alpha)

- Embed LibTalentTree-1.0 + LibStub (`.pkgmeta` externals; `libs\` in the
  TOC). For local dev, copy the lib into `libs\` (gitignored).
- Saved data: builds per class / spec, groups, PvP talents.
- Save current talents; apply; rename; delete (two-click "Sure?").
- Button + grouped menu by the talent window; `/tk` and a keybind open it
  anywhere.
- Import / export strings; import from other talent addons on first run.
- Log + debug, load line, smoke test (`Dev/smoke.lua`).

## v0.2: no duplicates

- Duplicate warning on save / import (Jump to it, Rename it, Save anyway).
- Near matches and the compare view (talent names; class vs spec tree
  split; hero tree shown).
- Hover a build: text diff against current talents.
- Management window: spec → group, search, badges, drag to regroup.

## v0.3: main builds and variants

- Save as variant; variant changes listed by talent name; main-build edits
  carry through; "Needs review" on collisions; export a variant as a full
  string.
- Gear set per build: optional equipment set, equipped on apply.

## v0.4: zone awareness

- Tag builds / variants with dungeons and raids; offer the switch on
  zone-in; single-boss raids included.
- Boss memory from kills (raid per boss + difficulty; M+ per dungeon at key
  start); M+ offer on Mythic zone-in + ready check; raid next-boss guess.
- Wrong-build reminder in tagged zones (by talents), also on ready check.

## 1.0

- Accessibility and style pass against the suite guide; Ponytail pass.
- README / CurseForge copy and screenshots; first stable release on the
  release cadence (see `Dev/RELEASING.md`).

## After 1.0 (ideas, not committed)

- Boss recognition before the pull, if S4 found it unreliable for 1.0.
- The talent window extras listed above.
