<p align="center">
  <img src=".assets/logo-256.png" alt="TalentKeeper" width="128" height="128">
</p>

<h1 align="center">TalentKeeper</h1>

<p align="center">
  Keep your talent builds tidy, and the right one wherever you go.<br>
  <a href="https://www.curseforge.com/wow/addons/talentkeeper">CurseForge</a>
  ·
  <a href="https://github.com/TheWolfIsLoose/TalentKeeper/releases">Releases</a>
</p>

TalentKeeper keeps a few talent builds per spec and knows which one goes
where. Tag a build with the dungeons, delves and raid bosses it's for, and
TalentKeeper offers the right spec and build when you get there, so the
talent window becomes something you rarely need to open.

## Features

- **Right beside your talents.** A side pane on the talent window holds everything: your specs (click one to change spec), Apply, Tags, More, Save current and Import in one block at the top, then your builds in groups you can drag them between.
- **See it before you take it.** Click a build to preview it on the tree: talents it takes glow green, talents it drops glow red. The pane always shows which saved build is in your tree right now, or that you're winging it.
- **Lands whole, every time.** Apply (or double-click a build, or the quick list) changes your talents through the game's own loadout system, the same way every time.
- **Tag builds for where you use them.** This season's Mythic+ dungeons, delves (one shared Delves tag) and each raid boss. One build per spec for each place, so TalentKeeper always knows what to offer.
- **Every place at a glance.** The Tag Config tab lists every dungeon, delve and raid boss this season with which of your specs has a build there. Pick a build for any spec from there, without changing spec, and fill the gaps in one place.
- **The right build when you arrive.** Entering one of this season's dungeons or a delve offers the build tagged for it. Nothing tagged for your spec yet: it asks once what to use there, with your other spec's build one click away. Nothing changes your talents without a click.
- **Ready check reminder.** On a ready check, a small strip confirms you're on the build tagged for what's next, or offers Switch. In raids it names the boss it expects from the room you're in, and you can correct it. Shift-drag to move it.
- **No duplicates.** Builds are compared by their talents, not their import strings. Importing one you already have points you at it, and gives it any tags you picked. Import shows the build on the tree before you save it.
- **PvP talents too.** Saved and applied with the build.
- **Bring your builds over.** At your first login, TalentKeeper offers to copy your builds from Talent Loadout Ex, Talent Loadout Manager and your game loadouts, then to turn the other talent addon off. Ones it already has are skipped, and nothing is removed anywhere. Also in Options.
- **Sim them.** Your builds go into the SimulationCraft addon's `/simc` text as saved loadouts, ready to pick on sim sites. Your other specs' builds too when SimulationCraft's Offspec Talent Loadouts box is ticked.
- **Options.** Talent window size, whether to ask in delves, and whether to add builds to `/simc` (the three-bar icon in the pane's header).

## Commands

| Command | What it does |
|---|---|
| `/tk` | Your builds for this spec: click one to apply it (also on a key binding) |
| `/tk save [name]` | Save your current talents as a build |
| `/tk import` | Paste a talent string to save it |
| `/tk log [clear]` | Open the log to copy into a bug report, or clear it |
| `/tk debug` | Record detailed steps into the log until `/reload` |

## Install

Retail (12.1.5). No dependencies. Report bugs on
[GitHub Issues](https://github.com/TheWolfIsLoose/TalentKeeper/issues) with
the output of `/tk log`.

## Credits

By Jakerator. Uses LibStub and LibTalentTree-1.0. Font: Barlow Semi
Condensed (SIL Open Font License).

## License

[MIT](LICENSE)
