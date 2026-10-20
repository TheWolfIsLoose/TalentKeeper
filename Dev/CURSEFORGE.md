<!-- Paste below this line into the CurseForge description (Markdown). Dev-only.
     Mirrors README.md without the HTML. -->

**Keep your talent builds tidy, and the right one wherever you go.**

TalentKeeper keeps a few talent builds per spec and knows which one goes where. Tag a build with the dungeons, delves and raid bosses it's for, and TalentKeeper offers the right spec and build when you get there, so the talent window becomes something you rarely need to open.

### Features

- **Right beside your talents.** A side pane on the talent window lists your builds, in groups. Click one to preview it on the tree; double-click to apply. Apply, Tags, Group, Rename, Copy, Resave and Delete sit under the list, and spec buttons change spec without leaving the window.
- **Tag builds for where you use them.** This season's Mythic+ dungeons, delves (one shared Delves tag) and each raid boss. One build per spec for each place, so TalentKeeper always knows what to offer.
- **The right build when you arrive.** Entering one of this season's dungeons or a delve offers the build tagged for it, changing spec first if needed. A place with nothing tagged asks once what to use there. Nothing changes your talents without a click.
- **Ready check reminder.** On a ready check, a small strip says whether you're on the build tagged for what's next, with Switch or Choose. In raids it names the boss it expects, learned from where you've pulled before, and you can correct it. Shift-drag to move it.
- **No duplicates.** Builds are compared by their talents, not their import strings. Saving or importing one you already have points you at it, and gives it any tags you picked.
- **PvP talents too.** Saved and applied with the build.
- **Bring your builds over.** On first run, imports the builds you saved in Talent Loadout Ex.

### Commands

- `/tk`: your builds for this spec; click one to apply it (also on a key binding)
- `/tk save [name]`: save your current talents as a build
- `/tk import`: paste a talent string to save it
- `/tk log [clear]`: open the log to copy into a bug report, or clear it
- `/tk debug`: record detailed steps into the log until /reload

Retail only, no dependencies. Source and bug reports (please include `/tk log`): https://github.com/TheWolfIsLoose/TalentKeeper
