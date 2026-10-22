<!-- Holds only the release being cut, as short player-facing bullets under a
     `## vX.Y.Z` heading. Detailed notes go in Dev/HISTORY.md. -->

## v0.4.0

Builds now go in through the game's own loadout system: they land whole, every time, without a hitch.

- New: Apply loads the build into the talent window as pending changes, so you see exactly what changes; Apply changes (ours or the game's) finishes it. Double-click a build, the quick list and the prompts apply straight away, the same way.
- New: This season tab: every Mythic+ dungeon, delve and raid boss this season, which of your specs has a build there, and the gaps. Click a place to pick a build for any of your specs, without changing spec.
- New: Bring your builds in: the first time you open talents, TalentKeeper offers to copy the builds you have in Talent Loadout Ex, Talent Loadout Manager and your game loadouts (any you already have are skipped; nothing is removed anywhere). Also in Options.
- New: your builds go into the SimulationCraft addon's /simc text as saved loadouts, so sim sites can pick them (Options: Add to /simc).
- New: drag builds to reorder them.
- New: Import shows the pasted build on the tree before you save it.
- New: Options (the gear in the pane's header): talent window size, and whether to ask in delves.
- Changed: the ready check strip confirms you're on your build, offers Switch when you're on another one, and asks to tag a build only once per play session (with your other spec's build one click away). The dungeon and delve prompt follows the same rules.
- Changed: talents a build drops glow red on the preview, like the ones it takes glow green; bigger spec buttons.
- Changed: the raid's rooms are known out of the box for this season's raids, so the strip names the right boss from the first pull.
- Fixed: the talent window kept its size but drifted off to one side; it now shrinks toward its middle and stays centered.
- Fixed: a talent change the game cancelled (moving, combat) could still say it was applied; it now says why it wasn't.
- Fixed: the version showed as "vv0.3.0"; the ready check strip now closes as soon as you answer.
