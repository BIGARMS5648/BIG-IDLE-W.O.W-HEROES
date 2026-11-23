# CurseForge page — BIG IDLE HEROES

Copy each block into the matching field of the CurseForge project form.

---

## Project name

```
BIG IDLE HEROES
```

## Summary (short description, one line)

```
An idle party RPG in a small battle window: five heroes fight their way from Elwynn Forest to Naxxramas on their own while you gear them up.
```

(124 characters.)

## Categories (suggested)

- Primary: **Mini Games**
- Secondary: **Miscellaneous**

## Game version / flavor

World of Warcraft: Forever (TOC `## Interface: 16001`).

## Release title (for this file)

```
BIG IDLE HEROES v3.20.0
```

---

## Description

Paste everything between the lines below into the description editor (Markdown).

---

# BIG IDLE HEROES

**An idle party RPG that lives in a small battle window on your screen.**
Build a party of five heroes, send them along a route through the original game's zones, dungeons and raids, and let them fight on their own while you quest, raid, or sit in a queue. Drop in now and then to equip loot, spend talent and skill points, and push into the next stage.

> **Language:** the in-game interface is **Korean only** for now. The add-on runs on any client language and uses the Korean font that every WoW client includes, so the text always displays, but there is no English translation yet.

## Features

### Your party
- Up to **5 heroes in a fight: 1 tank, 3 damage dealers, 1 healer** (up to 12 heroes on your roster).
- Pick **Alliance or Horde** at the start. Each class takes its classic race for your faction. Heroes share the gender of the character you are logged in with.
- **All 9 original classes and 28 specializations**: Arms, Fury and Protection Warrior; Holy, Protection and Retribution Paladin; Guardian, Feral, Balance and Restoration Druid; and so on.
- Every hero gets a random "first name + family name" that fits its race and gender.
- **Talents** (stat points, one per level) and **skills** are separate. Skills unlock in the order the original game teaches them, and you equip up to three of them (more with runes).

### The world: 120 stages
- A route through **the original game's zones, dungeons and raids in recommended-level order**: Elwynn Forest, Dun Morogh, the Deadmines, Scarlet Monastery, Uldaman, Blackrock Depths, Scholomance, Stratholme, Zul'Gurub, Ahn'Qiraj, and on to Molten Core, Onyxia's Lair, Blackwing Lair, the Temple of Ahn'Qiraj and **Naxxramas**.
- **Four difficulty tiers** (Normal, Heroic, Mythic, Mythic+), each with 30 stages in three acts.
- Every stage is a run of monster waves ending in a boss. Raid bosses have their own abilities.

### A living battle window
- Heroes, monsters, bosses, summons and companions are **the game's own 3D models**, animated: they stand, walk, attack, cast, get hit and die.
- Heroes wear their **class's dungeon set** and carry **their spec's best-in-slot weapons from level-60 dungeons**.
- Druids fight in **bear, cat or moonkin form**. You can turn forms off.
- Skills and boss abilities play **the original spells' visual effects**: casts, missiles and impacts.
- **Moving scenery:**
  - Each place has its own backdrop picture that scrolls by while the party walks between waves.
  - The ground is the zone's real terrain texture (Elwynn grass, Durotar red dirt, Dun Morogh snow, or a dungeon's own floor) and rolls by under the heroes' feet.
  - Outdoors, the zone's own trees, bushes and rocks pass in three parallax rows. Inside dungeons you see the dungeon's own props instead: Scholomance bookshelves and cauldrons, Blackrock Depths statues and anvils, Blackwing Lair dragon eggs.
- Melee summons walk beside their summoner and charge in with the melee heroes when a fight starts. Ranged summons stay beside their summoner. Your companion follows at the back.
- **Drag** the window anywhere, **resize** it from its corner, or switch to a compact view.

### Loot and progression
- **Gear in 8 quality tiers** from monsters and chests.
- **The Forge**, all in the equipment screen: fuse, craft, add gems, enchant, engrave runes, salvage, extract and use lucky seals. Bags fill up, so auto-salvage helps keep them clear.
- **Rune tree**: account-wide bonuses that open more party slots, skill slots and more.
- **Companions** that join the party.
- **Offline rewards** for the time you were away.
- A **"Recommended" hint** always points at the next useful thing to do, and red dots show where something is waiting.

### Stage screen
- World and stage pictures are **the game's own loading screens**: Forever's continent screens for outdoor zones, and the original dungeon and raid screens.

## Getting started

1. Install the add-on and enable **BIG IDLE HEROES** in the AddOns list at character select.
2. Log in. Choose **Alliance or Horde**, then create your first hero (class, specialization, name). Your first hero is free.
3. The fight starts on its own in the battle window. Open the menu at any time with **/bih**.

## Commands

| Command | What it does |
| --- | --- |
| `/bih` | Open or close the menu |
| `/bih bar` | Show or hide the battle window |
| `/bih reset` | Put the battle window back in its default place and size |
| `/bih model` | Open the 3D model check window (for testing how models look on your client) |

Right-click the battle window to open the menu. Chat messages from the add-on start with **[B.I.H]**.

## Settings

Open the menu, then **Settings**, to:

- change window sizes and lock the battle window;
- turn 3D models, druid forms and the moving scenery on or off;
- set auto-salvage, sound and your faction.

## Updating from an older version (BIG W.O.W IDLE)

The add-on was renamed, and its folder is now `BigIdleHeroes`. To keep your progress:

1. Exit the game completely.
2. Delete the old `Interface/AddOns/BigWowIdle` folder.
3. In `WTF/Account/<your account>/SavedVariables/`, copy `BigWowIdle.lua` to a new file named `BigIdleHeroes.lua`.
4. Start the game. Your heroes, gear and progress load as before.

**After installing or updating, always restart the game fully.** `/reload` does not pick up new image files.

## Notes

- Made for **World of Warcraft: Forever**. If the AddOns list marks it as out of date, tick "Load out of date AddOns".
- The battle runs while you play. It costs little, and you can hide the battle window at any time with `/bih bar`.

## Credits

- 3D models, spell effects, terrain textures and loading screens are the game's own files, loaded from your client. Nothing of Blizzard's is copied into the add-on except the battle backdrop pictures.
- The battle backdrop pictures are strips cut from in-game screenshots published on [Warcraft Wiki](https://warcraft.wiki.gg/). World of Warcraft and its imagery are © Blizzard Entertainment. The list of source images is in `docs/BACKDROP_SOURCES.md` in the project repository.

---

## Changelog for this release (v3.20.0)

```
- Heroes now share the gender of the character you are logged in with: a male character shows male heroes, a female character female heroes, all in their class's dungeon set. The gender choice in hero creation is gone.
- Your companion walks back to its place smoothly after a fight.
- Far scenery rows are faded and softened so they look further away.
- The battle scenery stands completely still while the party fights.
- On a fresh start the battle window waits until your first hero is made.
- The druid cat's health bar sits under its body.
- Forge tab locks match the other tabs.
```
