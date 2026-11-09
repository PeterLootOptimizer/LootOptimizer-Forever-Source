# LootOptimizer Forever (LOF)

Source of **LootOptimizer Forever**, a free addon for **WoW: Forever**.

Bags full while looting? LOF compares the loot with the cheapest item in your bags and swaps them with one click. It also gives gear advice with stat weights per class and talent tree (for your alts too), keeps profession materials you still need, makes room before you turn in a quest, and shows what all your characters own.

- **Download:** https://www.curseforge.com/wow/addons/lootoptimizer-forever
- **Website and guide:** https://lootoptimizer.digitalfame.nl
- **Discord** (bugs, ideas, questions): https://discord.gg/zUJRbeEFaF

## What is in this repository

The folder `LOF/` is exactly what is in the release ZIP on CurseForge. This repository holds **released versions only**; development happens elsewhere. The current version is **1.6.7**.

Inside `LOF/`, `README.md` describes every file and its role. The code is plain Lua 5.1, split into layers: `Resolver*.lua` (all decisions), `UI*.lua` (display only), `Capture.lua` (game events) and `Data/` (reference data such as the stat weights).

## License

All Rights Reserved. You are welcome to read the code and learn from it. Please do not copy it, redistribute it or publish modified versions. Embedded libraries in `LOF/Libs/` keep their own licenses (see `LOF/Libs/LICENSE-Ace3.txt`).
