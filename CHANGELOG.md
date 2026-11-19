# Damage Numbers 1.5.0

- Named "Damage Numbers (DaylightUI Plugin)", following Daylight UI's plugin naming.
- New icon, on the Plugins page and in the AddOns list.
- Chat lines are signed "Damage Numbers".

# Damage Numbers 1.4.0

- Its messages moved to `/dui` > Combat text > Messages, in a "Damage you deal" card. Melee hits,
  spell hits, crits and misses each get a switch, a stream and a color, like Daylight UI's own
  messages. Your old stream and colors carry over.

# Damage Numbers 1.2.0

- Hits are read from every UNIT_COMBAT event and filtered to your target. The target-only
  version never fired on WoW: Forever.
- The game's own damage numbers are hidden only after your first real hit of the session has
  shown in a stream, and come back if the game stops reporting hits.
- `/dui dmgdebug` says what the plugin has seen this session.

# Damage Numbers 1.0.0

- The damage you deal to your target, in Daylight UI's Right stream.
