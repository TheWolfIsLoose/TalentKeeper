<!-- Holds only the release being cut, as short player-facing bullets under a
     `## vX.Y.Z` heading. Detailed notes go in Dev/HISTORY.md. -->

## v0.1.0-alpha1

First alpha: keep and switch talent builds.

- New: save your current talents as a named build; apply, rename, copy or delete builds (delete asks "Sure?").
- New: a TalentKeeper button beside the talent window's loadout dropdown opens your builds for the current spec, grouped; `/tk` or a key binding opens it anywhere.
- New: builds apply into one TalentKeeper loadout per spec, leaving your other loadouts alone, and warn when some talents no longer fit the tree.
- New: import a talent string (saved to the spec it's for); builds saved by another talent addon are brought over on first login.
- New: `/tk log` and `/tk debug` for bug reports.
