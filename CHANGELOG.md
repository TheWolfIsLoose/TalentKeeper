<!-- Holds only the release being cut, as short player-facing bullets under a
     `## vX.Y.Z` heading. Detailed notes go in Dev/HISTORY.md. -->

## v0.5.2

- New: link a gear set to a build (More... > Gear set...); it goes on once the build's talents are in. A spec with its own gear set in the Equipment Manager keeps it.
- Fixed: pasting a talent string into Import threw an error; it shows the build on the tree again before you save it.
- Fixed: a talent change cancelled partway (moving, combat) could count as applied and swap your gear.
- The side pane sits in the same layer as the talent window, so other windows overlap both alike.
