# Kings-n-Things

*A buff bar for the raid buffs and consumables you should have*

![WoW WotLK 3.3.5a](https://img.shields.io/badge/WoW-Wrath%20of%20the%20Lich%20King%203.3.5a-9b1c1c?style=flat-square)
![Version](https://img.shields.io/badge/version-1.0-blue?style=flat-square)

A column of buff icons for World of Warcraft: Wrath of the Lich King (3.3.5a). Grayed out while a buff is missing, in colour with a cooldown sweep and the time left while it's active (red under a minute). Split out of [Rally](../Rally).

## Features

- 🍖 **Consumables first** — Well Fed, then a flask or up to three elixirs, then the pet's Well Fed (hunters and warlocks)
- 👑 **Only what can be cast** — a raid buff is shown when its caster class is in the group; Thorns only in groups of 10 or fewer; a buff you already have is always shown
- 🤝 **Rally-aware** — with Rally loaded, the blessings and shouts follow Rally's assignments for your class; without it, paladin #1 (by name) gives the top blessing for your class, #2 the next, and so on, and warriors show both shouts
- ⏳ **Time left at a glance** — an active buff's icon carries Blizzard's cooldown sweep along with the remaining time, red under a minute
- 🖱️ **Hover** an icon for the buff tooltip; **shift-drag** to move (snaps to the screen centre lines); **right-click** for horizontal layout, text side, icon size and text size
- 🎨 **ElvUI compatible** — the background picks up the ElvUI template when ElvUI is loaded

## Usage

| Command | Action |
|---|---|
| `/knt` | Toggle the bar |
| `/knt on\|off` | Show or hide the bar |

`/kingsnthings` works too. Settings are stored in `KingsNThingsDB`; on first run they are copied over from Rally's old bar settings.
