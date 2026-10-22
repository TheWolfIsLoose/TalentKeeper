# TalentKeeper — version history

Full notes for every release, newest first. Dev-only (the `Dev/` folder
never ships); the player-facing summary for the release being cut lives in
CHANGELOG.md. Add each release's detailed notes here when you cut it.

## v0.5.0 (2026-10-22)

Suite style pass (`Dev/SUITE-STYLE.md`): mint replaced by white everywhere (selection wash, live build text and edge bar, tabs, spec ring, checkbox squares, slider thumb, cast fill, shimmer at peak 0.15, focus rings); yellow `FFD84A` / red `FF6666`; two-tone name; the game-texture gear became the drawn three-bar Settings & Activity icon (a toggle, white while open); white icon. One `UI.header` for the pane and the bring-in window (`UI.versionText`), `UI.footBand` for its footer. Tags: Miscellaneous heading over Delves (an Open world place was tried and dropped: no reliable moment to check the spec there). Removed the unused import preview (`W.preview`) and `Compare.sameAsEarlier`. Roadmap: PvP under Miscellaneous, not scheduled.

## v0.4.0 (2026-10-22)

Applying moved to the game's own load (player, 2026-10-21): the in-place,
talent-by-talent apply froze the game 0.3-1.4 s with the talent window open
(every staged click redraws the tree) and had to resolve dependencies and
point limits itself (a refund took Blight of Tongues along; rebuilds when
changes deadlocked). Now TalentKeeper's loadout is replaced with the build
and loaded by the game: Apply (window open) uses the talent window's own
"pick this loadout without applying" so the build waits as pending changes
and Apply changes commits it into TalentKeeper's loadout; it only counts as
pending while the loadout menu is on TalentKeeper's loadout (picking Default
Loadout would otherwise have let our button commit that). Double-click,
quick list, prompts and the strip load and apply at once; a first load that
errors is retried after 1.5 s and a cancel before the load went through is
not reported as a failure. Cancelled changes (moving, combat, interrupted
cast 384255) are reported honestly with the cause.
- This season tab: every season dungeon, delve and raid boss, spec icons lit
  where that spec has a build, this spec's gaps gray, count at the bottom;
  click to pick this spec's build there.
- Ready check strip / zone-in prompt (player, 2026-10-21): confirm the
  tagged build; Switch when on another of this spec's builds (every check);
  nothing for this spec: ask once per play session (Use <build> /
  Choose...) with the other spec's tagged build as a button. Session = gaps
  under 2 h; nothing kept past 16 h. Strip closes on answer / end of check.
- Shipped rooms: Venomous Abyss (all 8; Pit of Fangs means the Twin Fangs
  only once Vashnik and Sszorak are down: it's the hub), Kith'ix.
- Options view in the pane (gear): talent window size slider (applied on
  release, shrinks toward the middle, leaves the game's own fit scaling alone
  at 100%), Ask in delves. No delve prompt when your last applied build is
  the Delves one.
- Import previews the string on the tree (note: changes, same, other spec,
  not a string); Save / Import have a For field; a duplicate takes the tags.
- Preview: dropped talents glow red; spec buttons fill the pane; pane header
  shows TalentKeeper and its version; pickers draw above the dialog; rows
  shimmer when a build is saved, tagged or moved.
- Version shows once (packager versions already start with v).
- Bring your builds in (pane view, first time talents open, and Options):
  Talent Loadout Ex (strings, headings kept, else "From TLE"), Talent
  Loadout Manager (talent lists written out as import strings in the game's
  format, zero tree hash; grouped under a linked game loadout's name, else
  "From TLM"), this character's game loadouts (every spec; spec patched in
  the string; "Blizzard loadouts"). Same talents: skipped; same name, other
  talents: "<name> (TLE)". Sources show only when that addon is loaded.
- SimulationCraft: this spec's builds go into /simc as "# Saved Loadout:
  TalentKeeper: <name>" / "# talents=" after the talents lines; the profile's
  adler32 checksum is worked out again. Option: Add to /simc.
- Drag builds to reorder (mint line where it lands, dragged row dims).
- Smoke test runs again (Lua 5.1 built from source in the dev session);
  covers bring-in, asking once per session, hub rooms, the /simc checksum.

Later on 2026-10-22, before the cut:
- Apply does one thing every time (player): it changes your talents like
  double-click. The staged "Apply, then Apply changes" path is gone; one
  button changing meaning with state read as inconsistent.
- Pane redone (player-led, several rounds): every control in one block at the
  top (spec tiles in one strip in class order with the width shared out;
  Apply / Tags... / More...; Save current / Import), then "Now:" (the saved
  build committed in the tree, worked out from the tree; "winging it" when
  unsaved; its row shimmers when it changes) and "Preview:" (the clicked
  build), then Builds / Tag Config tabs and the list. Forms open in the pane.
  Buttons 20px Small everywhere. Resave became More... > Update to my talents.
  No swap animation on spec change: the game hangs as the spec lands.
- /simc: TalentKeeper's builds in one block after SimulationCraft's own talent
  lines, under "### TalentKeeper: <spec>" headings; other specs only with
  SimulationCraft's Offspec Talent Loadouts box ticked; the game's
  TalentKeeper slot left out (it only repeats a build).

## v0.3.0 (2026-10-20)

First stable release (CurseForge lists a project only once it has one).
Everything in v0.3.0-beta1, plus:
- Save / Import: a For field (the tag list, kept as a draft until you
  press Save / Import). Same talents as a saved build: that build takes the
  tags, moved off the spec's other builds, and chat says what it was tagged
  for.
- Pane rows shimmer once (mint sweep, 2 s) when a build is saved, matched,
  tagged or moved to a group; the list scrolls to it.
- Pane header: TalentKeeper (mint "Talent") and the version, amber for
  dev / alpha / beta builds, instead of "<spec> builds".
- README, CurseForge copy and TOC notes rewritten to what the addon does
  now.

## v0.3.0-beta1 (2026-10-20)

First public beta. Reset to basics (2026-10-18): a plain build manager that
knows this season's dungeons, delves and raid bosses.
- Side pane on the talent window (no separate management window; size grip
  for the window). Click a build to preview it on the tree in the window's
  own art (green glow added, red border and dim dropped, choice-node pick,
  rank number; marks redraw when talents change), double-click to apply.
  Panel under the list: Apply, Tags, Group, Rename, Copy, Resave, Delete
  (click twice). The list scrolls.
- Save current / Import: one dialog for string, name and group. Same
  talents as a saved build offers to tag that build instead. Group headings:
  rename, ungroup, delete with its builds.
- Tags, groups and the quick build list (keybind, /tk) use the suite's own
  flat picker instead of Blizzard's menu. Tag list in two columns: Delves,
  this season's dungeons, then each raid's bosses (read from the journal,
  selecting each raid first). No world bosses, no Raid / Mythic+ or
  whole-raid tags. One build per spec per situation.
- Spec buttons under the pane's header change spec in place.
- Zone-in prompt (`Prompt.lua`): in this season's dungeons and delves only
  (no open world, no old or timewalking dungeons, no raids): on the tagged
  build, nothing; another, Switch (changes spec first if needed); nothing
  set, "Use current" or Choose. Asks once per place; hides when a key
  starts. Confirmed in game 2026-10-18.
- Ready-check strip (`ReadyCheck.lua`): under Blizzard's ready check popup
  (or a saved spot), in a dungeon, delve or raid: on the tagged build (mint),
  wrong build with Switch (amber), or nothing tagged with Choose. Raids name
  the expected boss: rooms learned at pulls (subzone at ENCOUNTER_START,
  raids only), then the lockout, then journal order; correctable by hand,
  which teaches the room. Shift-drag to move. Confirmed in Mythic+ only so
  far (DON, Kings' Rest); the raid side is untested.
- Spike unloaded; it no longer writes to the raid warning frame (tainted
  Blizzard's raid warnings).
- Cut: tidy up, fill up and build sources, main builds / variants / swaps,
  near-match planning, gear sets (old data cleared once).

## v0.2.0-alpha1 (2026-10-16)

v0.2 part 1, compare by talents (`Compare.lua`):
- Picks = node -> rank / choice read from the string with Blizzard's reader
  and `C_Traits.GetTreeNodes`; granted nodes ignored, and nodes free for the
  current spec today (from the game's own export) ignored too: old strings
  list as bought what a patch made free, which caused false Outdated marks
  in 2c48aa6 (cleared once on load).
- Same talents = not saved again (save, import, first-login import). Near
  match (6 or fewer) named with differences on save / import.
- Menu: each build's submenu starts with the differences from current
  talents by name; "same as X"; Outdated from the after-apply check, which
  now names talents. CONFIG_COMMIT_FAILED during an apply is reported as a
  refused change. First LoadConfig waits 0.3 s (instant load errored).
- Text boxes show typed text (edit box needed a size); learn / unlearn
  chat lines hidden for 10 s while applying; strings trimmed.

## v0.1.0-alpha1 (2026-10-16)

First alpha. Phase 0 spikes S1-S5 done (see the roadmap). Built on `dev`:
- Saved data per spec (`TalentKeeperDB.builds[specID]`), one level of
  groups, PvP talents; names unique per spec; the same string (trimmed) is
  never saved twice for a spec.
- Apply: import into the per-spec "TalentKeeper" loadout (old one deleted),
  load it; a load error right after import is retried once on the same
  loadout a second later; PvP talents set; a check 5 s later warns when
  talents no longer fit the tree. Learn / unlearn chat lines hidden for
  10 s while applying. Refused in combat and when the game blocks changes.
- Button beside the loadout dropdown + grouped menu (Blizzard menu
  system); `/tk`, key binding. Build submenu: rename, copy string, delete
  (two clicks). Save current talents / import a string via a small text
  window (suite style, Barlow font).
- One-time import of another talent addon's saved builds (45 for the
  player). Log + debug, load line, smoke test (Lua 5.1).
- Tested in game 2026-10-16 (two rounds): all items pass.

## Unreleased

- 2026-10-15: repo set up before any code: TOC (12.1.5), icon set (gold
  talent tree), release workflow and `.pkgmeta` copied from StockClerk,
  README, CurseForge draft, style notes, roadmap.
