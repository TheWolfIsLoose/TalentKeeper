# TalentKeeper — UI style rules

Suite-wide rules (colour tokens, controls, accessibility, words, chat) live in
`Dev/SUITE-STYLE.md`; this file holds
TalentKeeper's specifics and wins only where it names an exception.

- **Beside the talent window.** One side pane docked to its right edge (the
  suite's sidecar): the build list, then the selected build's panel. No
  separate management window.
- **Pickers, not Blizzard menus.** Tags, groups and the quick build list open
  the suite's flat picker: a small panel with a 26px title, muted Small
  headings, 24px rows with the 16px check well (mint square when on), and a
  "more below" mark instead of a scroll bar. No nested menus.
- **Accent:** mint (suite default). The icon's gold `FFD84A` is never used
  in the UI, since it sits near the `warn` amber.
- **Badges** pair colour with a word: Active (mint), Duplicate (muted),
  Outdated (amber).
- **Talent names, not IDs,** everywhere a player reads a difference
  ("Talent A → Talent B").
- **Offers, not actions:** zone and boss awareness offer a switch; nothing
  changes talents without a click.
