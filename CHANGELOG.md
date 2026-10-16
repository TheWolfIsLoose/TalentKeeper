<!-- Holds only the release being cut, as short player-facing bullets under a
     `## vX.Y.Z` heading. Detailed notes go in Dev/HISTORY.md. -->

## v0.2.0-alpha1

Builds are now compared by their talents, not their strings.

- New: saving or importing a build with the same talents as one you have says so instead of saving a copy.
- New: saving or importing a build close to one you have names it and the talents that differ.
- New: each build's menu entry shows how it differs from your current talents, by talent name; copies read "same as ...".
- Fixed: builds were marked Outdated when a patch had made one of their talents free.
- Fixed: when the game refuses a talent change, TalentKeeper says so instead of calling the build outdated.
- Fixed: applying a build no longer needs a retry most of the time, and hides the "You have learned / unlearned" chat lines.
