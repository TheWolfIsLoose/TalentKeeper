# TalentKeeper — Roadmap

Forward plan, one section per release. Dev-only (`Dev/` never ships).
Shipped work moves to `Dev/HISTORY.md`; the player-facing summary goes in
`CHANGELOG.md` when a release is cut (see `Dev/RELEASING.md`).

Status key: **Decided**, **Default** (recommended; change it if you
disagree), **Open** (needs an answer before build).

---

## Product model (player, 2026-10-17)

How players label builds: a few per spec, named for what they're for, not
for their talent details. Most players settle on a handful (one raid build
for a spec; single target and AoE per hero tree; a couple for M+), then move
a class talent or two for a fight's or dungeon's utility. Others keep a
build per boss and per dungeon; that stays possible, but the addon points
out the overlap.

- **Scope: the class you're logged in as.** Its specs only; builds for
  other classes stay saved and show when you log into that class. The pane
  shows the current spec; other specs of the class come in through offers
  and history.
- **Builds are few, situations are many.** A situation is a dungeon, raid,
  boss or delve (content type too). A build is tagged with the situations
  it's for; one situation can point at builds in more than one spec.
- **Swaps instead of separate builds.** The small per-fight / per-dungeon
  changes hang off a build as its swaps for that situation ("SH AoE, Murder
  Row: + Curse of Exhaustion"). Same data as today's variants (changes from
  a main build, carried through when the main build changes), shown as the
  swaps rather than as a second build.
- **Keep the set small.** Saving or importing a build with the same talents
  as one you have: offer to tag that build for this situation instead.
  Within a couple of talents: offer to save it as a swap. For a collection
  brought over from another tool: propose the clusters ("these 9 are SH AoE
  with small swaps; these 6 are identical") and merge only on confirm.
- **What you said and what you played.** Log the spec and build active at
  each key start and boss pull (passive). On zone-in / before a boss, offer
  the tagged builds and what you played there last, across the class's
  specs.
- **Blizzard limits (what shapes this):** no talent changes in combat, in a
  boss encounter or in a running key; each change is a 5 s cast; in
  instances unit names / IDs are secret, while the instance, encounter
  start / end and your own spec / build are readable; builds only arrive as
  pasted strings. Storing, comparing, drawing on or beside the talent
  window and applying out of combat are all open.

## Next session: start here

**Revisit (player, 2026-10-18), before more features:**
1. **Import flow.** One import step that sets the build's name, its tags,
   and the main build it belongs to (if any), instead of import, then
   rename, then tag, then Variant of.
2. **Build actions without nested right-click menus.** Menus inside menus
   feel dated. Rethink how actions on a build are reached (in the pane
   itself, on the selected build) rather than a context menu tree.
3. **Click to preview.** Clicking a build previews it on the tree (hover is
   hard to read); applying becomes an explicit action. Keep the green glow
   for talents the build takes; find an equally clear look for talents it
   drops.
4. **Tidy up as the addon's job.** *(First version in testing, 2026-10-18:
   Tidy up in the pane's header plans the whole spec on one screen; the
   plan and its input are kept in saved data for tuning; /tk undo. Fill up:
   build sources register with the addon and fill a spec with builds tagged
   for their dungeons and bosses; your ungrouped builds move to "Migrated".
   Where sustainable source data comes from is open (player, 2026-10-18).)* One clearly explained pass that a new
   player can press and trust: group a spec's builds into a few core builds
   (hero tree as a hard split, then talent distance), keep the closest real
   build of each group as its core, turn the rest into swaps or merge
   near-copies, read the original names for intent (raid, M+, AoE / ST,
   dungeon and boss names, hero tree) to propose names and tags, show the
   whole plan on one screen before changing anything, and keep an undo.


**Parked 2026-10-16, ~23:40 ET (not released; last release
v0.2.0-alpha1).** Applying is solid (in place, confirmed across three specs).
The GUI moved to a side pane on the talent window (no separate management
window) with a size grip for the window. Untested when parked: the hero
emblem mark, right-click / drag in the pane, Save current / Import buttons
and the suite styling pass (the DevChecklist round is still set). Then:
search / compare / other specs if missed, free editing, a release.
**Tags (in testing, 2026-10-17):** right-click a build > Tags: the instance
you're in, Raid / Mythic+ / Delves, this season's M+ dungeons, and each of
this season's raids (whole raid or a boss, from the dungeon journal).
Saving or importing talents you already have opens that tag menu for the
existing build instead. The pane shows a build's tags on its row (first tag
+N) and in full on hover. **Variants and tidy up (in testing, 2026-10-17):** any saved build can be
made a variant of a main build (Variant of). Tidy up on a main build: the
build closest to all the others becomes the main build (the rest become its
swaps), builds more than a few talents from it become main builds of their
own, and builds a talent apart can merge (tags combine). Nothing is
synthesized: every build stays one that was saved, so none can break the
tree's rules. Main builds push their changes down to variants as before.
Next: the played-here history and zone-in offers. Change marks on the tree
were redrawn in the talent window's own art (in testing).

Earlier threads (history):
1. **Apply speed.** Switching feels slower than other loadout tools. Our
   path deletes and re-creates the TalentKeeper loadout each time (import ->
   wait for it to fill -> 0.3 s -> load, plus a 1 s retry when the first
   load errors). Spike S6: apply in place into the existing TalentKeeper
   loadout (reset the tree, buy nodes, commit once) and time click -> talents
   committed for both paths, with and without a hero tree change (the hero
   tree animation may set a floor of ~1-1.5 s either way).
   **Reworked and confirmed 2026-10-16** (16 switches across three specs,
   all in place, 0 differences, no import fallback; about half needed the
   rebuild step): in place now changes only the
   talents that differ on the live tree (refunds bottom row first, buys top
   row first, both in passes), adds up a multi-rank apex talent that comes as
   several entries (the cause of "apex stuck at 2"), leaves the hero tree
   alone unless the build picks another one, and commits only when something
   changed. Anything it can't take: roll back and import. First apply (or
   when another loadout is selected) still imports.
   **Floor (player, 2026-10-16):** changing talents is a 5 s cast, so 5 s
   from click to applied is the fastest possible. Import measures ~5.7-7 s,
   i.e. ~1 s of our own overhead (0.3 s wait before loading, the 1.5 s check
   after a load error). Only that second is left to win; low priority.
2. **GUI: build it and see (player, 2026-10-16).** Four directions were mocked
   (manager with a drawn tree, preview on the talent window, free editing,
   quick menu with icons); the player wants to build and find what doesn't
   work rather than settle the look on paper. Step 1: a strip of builds under the window lost the main / variant
   shape and crowded the window; now a side pane docked to the window's right
   edge (groups, main builds with variants indented, the one on now in mint),
   hover marks what a build changes on the tree, click applies. The talent
   window is too big by default: a corner grip scales it (saved).
   Step 2 (in testing): another hero tree shows as one mark on the hero
   emblem (with the new tree's name) instead of marks on every hero talent;
   the pane manages builds: right-click for the build's actions (incl. a
   Group submenu), drag onto a group / "+ New group", Save current, All
   builds (the management window, for other specs).
   **No separate management window (player, 2026-10-16):** everything lives
   in the side pane; the window was a lot of extra for no function. Builds
   for other specs show when you're on that spec. (Lost with it: search,
   compare-with, browsing other specs; bring back into the pane if missed.)
   Next candidates: the same marks from the manager and menu, then free
   editing on the talent window.
   Earlier notes: **The GUI doesn't feel designed yet.** Style-consistent but all text;
   players read talents visually. Directions to explore (mock up first,
   then pick): icons for builds (hero tree / spec) and for talent changes
   (spell icons, added / removed marks) instead of +/- text; a small drawn
   tree per build from the library's node positions with changes
   highlighted; previewing a build on Blizzard's own talent window (mark
   the nodes that would change on hover) so the window itself is the
   canvas. Decide the look before v0.4 adds zone offers.
   **Free editing (player, 2026-10-16):** shape a build however you like
   (talents in any order, prerequisites removed and re-added) and have it
   apply as long as the final build follows the tree's rules (gates,
   connections, point totals). Blizzard's window checks every click, so
   this needs our own editing surface: the drawn tree from direction 2
   doubles as an editor that only changes picks, checks the result with the
   talent library's gates / edges / currencies, then writes a string
   (`C.write`) and applies it through the import path, which already
   applies a whole build at once. Built clean-room from Blizzard's API.

**Parked 2026-10-16, ~14:55 ET: v0.1.0-alpha1 released** (CurseForge
Alpha). Spikes S1-S5 done; raid / dungeon / delve design written below as
Defaults awaiting the player's sign-off. Passive confirmations pending on
his next delve (difficulty 208) and heroic raid (every boss level -1? x,y
blocked in instances?): read the spike log when he says he's run them.
Next: v0.2 (duplicates by talents, near matches, compare view with talent
names via LibTalentTree, management window).

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

**Built 2026-10-16, in testing (not released).**
- Saved data: builds per spec (`TalentKeeperDB.builds[specID]`), one level
  of groups, PvP talents; names unique per spec; the same string is never
  saved twice for a spec.
- Save current talents (named in a small window); apply into
  TalentKeeper's own loadout with one automatic retry on a load error,
  then a check that warns when talents no longer fit the tree; rename;
  copy the string; delete (two clicks, "Sure?").
- Button beside Blizzard's loadout dropdown + grouped menu (Blizzard's menu
  system); `/tk` and a key binding open it anywhere.
- Import a talent string (goes to the string's own spec); one-time import
  of builds saved by another talent addon on first login.
- Log (`/tk log`, `/tk debug`), load line, smoke test (`Dev/smoke.lua`,
  Lua 5.1).
- Moved to v0.2: embedding LibTalentTree (first needed for talent names).
- Clearing a pending spec swap on cancel goes with the cross-spec feature.

## v0.2: no duplicates

**Part 1 built 2026-10-16, in testing:** `Compare.lua`. A build's picks =
node -> rank / choice from the string (free nodes ignored), read with
Blizzard's own reader + `C_Traits.GetTreeNodes`. Same talents as a saved
build (any string) = not saved again, on save, import and the first-login
import. Near match (6 talents or fewer) named on save / import with the
differences. Each build's submenu starts with how it differs from your
current talents, by talent name; menu marks "same as X" and Outdated
(set by the check after applying).
- LibTalentTree deferred again: Blizzard's API gives names for the
  player's own class; add the lib when we need another class's tree or
  class vs spec nodes.
- Not done: "Save anyway" for an identical build (nothing to gain);
  class vs spec tree split in diffs; hero tree shown.

Fixes in testing: talents a patch made free (old string: bought; today's
export: free) don't count as differences (that was the false Outdated);
the after-apply check names talents; a refused commit is reported as
such; the first load waits 0.3 s (the instant load errored nearly every
time, then the retry worked).

v0.2.0-alpha1 released 2026-10-16 (part 1).

**Part 2a, in testing:** LibTalentTree-1.0 (unmodified) + LibStub committed
under `libs/` (no `.pkgmeta` externals, so `update.bat` checkouts work
too). Used for: another class's tree and names, nodes free for a spec,
diffs ordered spec / hero / class with "(hero)" / "(class)" tags, and the
build's hero tree named at the top of its submenu.

**Part 2b, first cut in testing (`Manager.lua`, `/tk manage`, "Manage
builds" in the menu):** specs by class on the left (current class first,
counts), builds by group on the right with hero tree / Active / same as /
Outdated, search by build or talent name, drag a build onto a group or
"New group", Apply (current spec only) / Rename / Copy / Compare with /
Delete (Sure?). Compare opens the differences in the text window.
Mouse-wheel scrolling, no "more below" chevron yet. Tested 2026-10-16: all items work.
**Open (player, 2026-10-16):** unsure about showing other classes' builds
in the window; GUI polish later, after the functional pieces. Player: "we'll play
with it to see how we like it".

**Part 2b (original note):** management window: spec -> group, search, badges, drag to
regroup, compare any two builds by name.

## v0.3: main builds and variants

**Built 2026-10-16, in testing.** A variant keeps a full string (apply,
copy, compare work unchanged) plus `main` (its main build's name) and
`changes` ({node, from, to} from the main build). "Save current talents
as a variant" (menu / window) records the changes; "Update to current
talents" replaces a build's talents, and each variant of it is rebuilt
from the new main + its changes with our own string writer
(`C.write`, checked offline: all 45 saved builds round-trip). Where the
main build changed a talent the variant also changes: "Needs review".
Variants sit under their main build (menu and window), move with it,
follow renames, and become main builds if it's deleted. Gear set per
build: pick a Blizzard equipment set; equipped after a successful apply.
- Not yet: showing near matches as variants automatically (the "same hero
  tree + few changes" display rule); clearing Needs review other than by
  updating the variant.

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
