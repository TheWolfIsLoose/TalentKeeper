# TalentKeeper — version history

Full notes for every release, newest first. Dev-only (the `Dev/` folder
never ships); the player-facing summary for the release being cut lives in
CHANGELOG.md. Add each release's detailed notes here when you cut it.

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
