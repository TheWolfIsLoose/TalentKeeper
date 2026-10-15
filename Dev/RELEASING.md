# TalentKeeper — Releasing

Dev-only (`Dev/` never ships). Same process as StockClerk, PickupGroup and
SharedMedia: Tones.

Releases are cut by CI from the `## vX.Y.Z` heading in
[CHANGELOG.md](../CHANGELOG.md), which holds only the release being cut
(short, player-facing bullets). Detailed notes for every version go in
[HISTORY.md](HISTORY.md). Planned work lives in [ROADMAP.md](ROADMAP.md).

- Work lands on `dev` and is tested internally (player syncs
  `Dev\update.bat dev`, plays, `/reload`; Claude reads the log).
- Push to `dev` with a new `-alphaN` / `-betaN` version heading to publish a
  prerelease (CurseForge Alpha/Beta). Before 1.0 the versions are
  `v0.x.y-alphaN`.
- Merge to `main` with a new stable `vX.Y.Z` heading to publish a release.

The workflow tags the commit, packages it (BigWigsMods packager) and creates
the GitHub release; CurseForge picks it up through its GitHub webhook. Don't
create releases by hand. Wait for a release push's tag
(`git ls-remote --tags origin`) before pushing again.

**Cadence (all of the player's addons, 2026-10-13):** feature releases go
out every other Tuesday around 9 AM ET, bundling whatever is tested on
`dev`; hotfixes ship as needed. On a Retail patch day the release moves to
~5 PM ET and carries the TOC bump.

## Patch day: Retail TOC bump

Check the live interface number and bump `## Interface` in the TOC if it
changed. Cross-reference at least two of:
- Warcraft Wiki, Public client builds (Interface column):
  https://warcraft.wiki.gg/wiki/Public_client_builds
- Blizzard's UI source mirror, `live` branch (latest commit names the patch):
  https://github.com/Gethe/wow-ui-source/tree/live
- In game: `/dump select(4, GetBuildInfo())`

Last checked: 2026-10-15, 12.1.5 = 120105.
