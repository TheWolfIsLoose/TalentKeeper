<p align="center">
  <img src=".assets/logo-256.png" alt="TalentKeeper" width="128" height="128">
</p>

<h1 align="center">TalentKeeper</h1>

<p align="center">
  Keep your talent builds tidy.<br>
  <a href="https://www.curseforge.com/wow/addons/talentkeeper">CurseForge</a>
  ·
  <a href="https://github.com/TheWolfIsLoose/TalentKeeper/releases">Releases</a>
</p>

> **In development.** Nothing to install yet; the plan is in
> [Dev/ROADMAP.md](Dev/ROADMAP.md).

TalentKeeper keeps a few talent builds per spec and knows which one goes
where. Tag a build with the dungeons, delves and raid bosses it's for, and
TalentKeeper puts the right spec and build in front of you wherever you go,
so the talent window becomes something you rarely need to open.

## Features (planned for 1.0)

- **The right build wherever you go.** Tag a build with a dungeon, delve,
  raid or boss; when you arrive TalentKeeper offers to switch spec and build
  (before the key starts in Mythic+). Places without a build ask once.
- **Right beside your talents.** A side pane on the talent window lists your
  builds. Click one to preview it on the tree; apply, tag, group, rename,
  copy or delete it from the panel below the list. Double-click applies.
- **No duplicates.** Builds are compared by their talents, not their import
  strings, so saving one you already have points you at it instead.
- **Groups.** Save or import straight into a group; rename or delete a
  group from its heading.
- **PvP talents too.** Saved with the build.
- **Bring your builds over.** Imports your Talent Loadout Ex builds on
  first run.

## Commands

| Command | What it does |
|---|---|
| `/tk` | Quick menu: click a build to apply it |
| `/tk save`, `/tk import` | Save your current talents, or import a string |

## Install

Retail (12.1.5). No dependencies. Report bugs on
[GitHub Issues](https://github.com/TheWolfIsLoose/TalentKeeper/issues) with
the output of `/tk log`.

## Credits

By Jakerator. Inspired by Talent Loadout Ex (Morizo) and Talent Loadout
Manager (Numy).

## License

[MIT](LICENSE)
