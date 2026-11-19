# Damage Numbers (DaylightUI Plugin)

Daylight UI's combat text shows the hits you take and the heals you get, but not the damage you
deal. This plugin adds it: every hit on your target lands in a stream (the Right one by default),
in your number style, with crits bigger.

Needs [Daylight UI](https://www.curseforge.com/wow/addons/daylightui). Made for WoW: Forever.

## Setup

Install it next to Daylight UI and log in. That's it. `/dui dmg` shows a few sample hits.

## Settings

`/dui` > Combat text > Messages, in the **Damage you deal** card at the bottom:

| Message | What it is |
|---|---|
| Your melee and ranged hits | Weapon hits on your target, and your pet's. |
| Your spell hits | Spell hits on your target, and your pet's. Colored by school when Daylight UI's "Color spell hits by school" is on. |
| Your crits in their own color | Crits take this color. Off: a crit keeps its hit's color. It always lands bigger. |
| Your misses | Dodge, Parry, Miss, Resist, Absorb and the rest, as a word. |

Each has a switch, a stream and a color, like Daylight UI's own messages. Below them:

- **Only when solo**: the game reports every hit your target takes, so in a group other players'
  hits show too. This hides your messages while you're grouped.
- **Hide the game's damage numbers**: the numbers that pop off your target would only double up,
  so they go, but only once your first real hit of the session has shown in a stream. Turning
  this off puts back what you had.

## Good to know

- WoW: Forever gives addons no combat log, so hits come from the game's UNIT_COMBAT event on your
  target. Damage on anything other than your target doesn't show.
- If the game stops reporting your hits while its own numbers are hidden, the plugin puts them
  back for the rest of the session and says so in chat.
- `/dui dmgdebug` says what the plugin has seen this session, for bug reports.
