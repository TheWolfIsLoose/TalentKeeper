# TalentKeeper — version history

Full notes for every release, newest first. Dev-only (the `Dev/` folder
never ships); the player-facing summary for the release being cut lives in
CHANGELOG.md. Add each release's detailed notes here when you cut it.

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
