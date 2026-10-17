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

TalentKeeper saves your talent builds without a sidepane bolted onto the
talent window. It knows when two builds are really the same, lets you keep
small per-dungeon variants of one main build, and offers the right build
when you zone in.

## Features (planned for 1.0)

- **No duplicates.** TalentKeeper compares builds by their talents, not
  their import strings, so it tells you when you already have a build, or
  how one differs from another ("2 talents: X → Y").
- **Main builds and variants.** Keep one main build and attach small
  variants for the dungeons or bosses that need different picks. Change the
  main build and every variant follows.
- **The right build when you zone in.** Tag a build with a dungeon or raid
  and TalentKeeper offers to switch when you arrive, before the key starts.
- **Right beside your talents.** A side pane on the talent window lists your
  builds: hover one to see on the tree what it would change, click to apply,
  right-click or drag to organize. A small menu and a keybind work too, and
  the talent window can be scaled down.
- **PvP talents too.** Saved with the build.
- **Bring your builds over.** Imports your Talent Loadout Ex builds on
  first run.

## Commands

| Command | What it does |
|---|---|
| `/tk` | Open the build menu |

## Install

Retail (12.1.5). No dependencies. Report bugs on
[GitHub Issues](https://github.com/TheWolfIsLoose/TalentKeeper/issues) with
the output of `/tk log`.

## Credits

By Jakerator. Inspired by Talent Loadout Ex (Morizo) and Talent Loadout
Manager (Numy).

## License

[MIT](LICENSE)
