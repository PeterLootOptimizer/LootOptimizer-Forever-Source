# LootOptimizer Forever (LOF) v1.6.6

Bag full while looting? LOF compares the loot with the cheapest item in your
bags (vendor value x stack, or the auction house value when Auctionator is
installed and switched on) and offers to swap them. The Upgrade Advisor judges
new gear with stat weights for your spec, also for your alts. Holdings shows what
all your characters own and where (bags, bank, equipped, mail, auction house).
Profession reagents you still need are kept, Make room now empties your bags
round by round, and the Guide explains what is new and what each popup colour
means. Characters you deleted can be removed from LOF.

## Files
| File | Version | Role |
|---|---|---|
| LOF.toc | 1.6.6 | Interface 16001 (WoW: Forever), SavedVariables `LOF_DB`, OptionalDeps Auctionator |
| Libs/ | - | Embedded libraries: LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0 (minimap button; Ace3 BSD license, see Libs/LICENSE-Ace3.txt) |
| Core.lua | 0.3.1 | Namespace, DB (first-install flag), API shims, money format (coin icons), event hub |
| Data/StatProfiles.lua | 0.3.2 | Reference data: main stat per class, usable armor/weapon types per class, duplicate stat keys, stat display order |
| Data/PriceRules.lua | 0.1.0 | Reference data: AH freshness bands, default value source per quality |
| Data/ProfessionRanks.lua | 0.2.0 | Reference data: profession ranks, when the next rank can be trained, materials per profession |
| Data/DisenchantTable.lua | 0.1.0 | Reference data: what disenchanting gives per quality, item level band, armor/weapon (classic table, checked on Forever) |
| Data/StatWeights.lua | 0.2.5 | Reference data: stat weights per class and talent tree (beta) |
| Data/ProfessionReagents.lua | 0.2.0 | Reference data: looted and crafted profession materials with the skill range per profession |
| Data/Guide.lua | 0.8.0 | Reference data: texts of the Guide (What's new, How to use, Colors) |
| Resolver.lua | 0.10.16 | ALL swap intelligence: policy (upgrade / reagent protection), decision (quest / value / gear / alt / reagent), Make room (now), Guide trigger, snapshot |
| ResolverValue.lua | 0.2.0 | Value intelligence: vendor, Auctionator or disenchant value, freshness, reason codes, settings |
| ResolverUpgrade.lua | 0.13.8 | Upgrade Advisor intelligence: spec, weighted score, verdict, alts, protection (also future upgrades), settings per character, Send to alts |
| ResolverHoldings.lua | 0.11.2 | Holdings intelligence: per character bags/bank/equipped/mail/AH, talents, gold, professions, Gear for alts, forget a character |
| ResolverReagents.lua | 0.1.3 | Reagent intelligence: which materials the current character keeps (own choice or skill range), Reagents list |
| Capture.lua | 1.9.13 | Events, loot baseline, swap session, Make room (now), upgrade flow, Guide timing, combat / moving, Holdings reads, mail |
| UI.lua | 1.17.26 | Panel, tabs, popup styles (one table), popups (swap, make room), comparison table, lists, tooltips, minimap icon (LibDBIcon), /lof |
| UIHoldings.lua | 0.9.5 | The Holdings window (incl. Gear for alts, Remove from LOF), scales with the screen |
| UIAltMail.lua | 0.1.4 | The Send to alts window |
| UIReagents.lua | 0.2.5 | The Reagents list (Settings window) |
| UISettings.lua | 0.3.2 | The Settings window: Values, Upgrade Advisor, General, Guide, Reagents, Characters |
| UIGuide.lua | 0.3.0 | The Guide window: What's new, How to use, Colors |

## Swap rules
- Profession/class tools (Skinning Knife, Mining Pick, fishing poles, enchanting
  rods, Thieves' Tools, ...) and ammo (arrows, bullets: item class Projectile,
  also in a general bag) are on the whitelist by default (removable).
- Never offered: quest items, whitelisted items, items without any value
  (no vendor price and no usable AH price), items in special bags (quiver,
  ammo, soul, profession bags).
- Reagent bag: an item there is only swapped for loot that is a crafting reagent;
  otherwise LOF picks the cheapest item from a general bag. Free slots count
  general bags only.
- Never offered either: gear that the Upgrade Advisor suggests for you or one of
  your alts, also when it is an upgrade only at a later level (label "upgrade" in
  All Items), and profession reagents you keep (label "reagent").
- All Items: click an "upgrade" or "reagent" row to release it (normal rules);
  a released item shows "· upg" / "· reag" after its value; click it again to
  protect it again, Shift-click to whitelist it permanently.
- Swap is offered when the loot is, in this order: a quest item (QUEST ITEM;
  the loot window tells whether you have the quest, the item starts one, or no
  quest of yours needs it now), a gear upgrade for you (GEAR UPGRADE, in the
  item's quality colour, with the full stat comparison), a gear upgrade for an
  alt (orange ALT UPGRADE), a profession reagent you keep (teal REAGENT), or
  simply worth more than the cheapest bag item (plain popup). Loot that fits on
  a stack you already have is never "blocked".
- Previous / Next browse the bag items that qualify (for a plain swap: worth
  less than the loot; otherwise any item that can hold the loot). Next keeps
  the item for now (not whitelisted); a note shows the last / only item.
- Otherwise a red NOT WORTH A SWAP popup (once per loot window) explains why
  ("you would lose X"), with OK / "Swap anyway"; it closes by itself after 10s
  (paused on hover). Settings > General can switch it off: then a short gold
  line under "Inventory is full" says the same.
- Before every swap the bag slot and loot slot are re-validated.
- The loot is requested in the same click as the delete. If the loot window
  still closes too early (e.g. you move right away), LOF shows "LOOT LEFT
  BEHIND" and loots the item automatically when you open that corpse again
  (within 3 minutes).
- Swap is one click: LOF destroys the bag item and loots (one item per click is
  allowed on WoW: Forever). If the game blocks it for an item, LOF falls back:
  the item hangs on your cursor and you confirm Blizzard's destroy dialog.

## Make room
- One flow, one bronze popup. "Inventory is full" outside the loot window
  (conjuring food or water, crafting, a quest reward, buying, taking mail):
  MAKE ROOM - bags full, at the lowest quality you carry. The "Room" button in
  the Swap section header (or `/lof room`): MAKE ROOM NOW, also with free slots.
- Delete / Previous / Next / Cancel, one item per click, cheapest first, round
  by round per quality: grey, then (after "Continue with white?") white, green
  and blue; epic items are never offered. Same rules as Swap. After Delete, try
  again yourself (addons may not cast or take quest rewards for you).
- Quest reward: on the reward screen LOF counts the slots the reward needs
  (each reward one slot, a choice one slot, none when it fits on a stack you
  have) against the free slots plus stacks you hand in completely. Too few:
  Make room opens before you click Complete Quest ("Quest reward needs N free
  slots - you have X"), counts again after each delete and closes with "Enough
  room for the quest reward." Only while the reward window is open.
- When a cheaper item waits in a higher quality round, Make room says so
  (order: Grey, White, Green, Blue, cheapest first within each).
- The automatic popup comes at most once per 10 seconds. Settings > General:
  on/off. A reagent on normal rules is marked in teal, an unknown "Crafting
  Reagent" gets a note.

## Profession reagents
- Materials your current character still needs for a profession (looted or
  crafted: ore, herbs, cloth, leather, grinding stones, bolts, cured hides,
  Engineering parts, ...) are kept: never offered for deletion, and offered for a
  swap (teal popup) even when the loot is worth less than your cheapest item.
- Kept = your own choice, or: a profession of this character uses it and your
  skill is below the highest recipe level + 25.
- Settings > Reagents: "Keep profession reagents" (on by default) and the list
  per profession: checked = always keep, unchecked = normal rules. Range colour:
  green = skill points possible, white = needs more skill, grey = no more skill
  points. A choice that differs from LOF's default shows "your choice".
- Data: classic database plus Forever materials (profession guessed, range
  unknown); First Aid uses the healing potion herbs (assumed).

## Auction house values (Auctionator, optional)
- Settings > Values: "Use Auctionator prices" (off by default). Without Auctionator
  LOF works on vendor values only.
- Only the official Auctionator API is used: last seen price + age in days.
- Value source per quality (default: Poor/Common = Vendor, Uncommon and up = AH).
- The value is never lower than the vendor price. Soulbound / bind-on-pickup
  items always use the vendor value.
- Freshness: green up to 3 days, orange up to 7, red up to 14. Older AH data is
  not used ("scan the auction house", vendor value is used).
- Values show their source: `(V)` or `(AH)` in the freshness colour.
- Item tooltips (bags and LOF windows) get a small LOF block: why
  ("LOF: White item", "LOF: Soulbound", ...) and which value is used
  ("Uses vendor value .... 17 x 1c = 17c", "Uses AH value .... 37c (today)").
- Inventory: Total = gold + vendor (guaranteed money). Below it, with the
  integration on, "Possible total" = gold + possible bag value (per item the
  value LOF uses). Hover it for the gain compared to Total, the AH / vendor
  split and the 10 most valuable items.
- Settings shows "AH prices updated": LOF records the time whenever Auctionator
  reports new prices (official API callback, full scan or search).

## Disenchant value
- Settings > Values: "Use disenchant value" (off by default). Shown
  only when one of your characters has Enchanting (LOF must have seen that
  character log in). The skill level is not checked.
- An item is then worth the highest of vendor, AH and the expected disenchant
  yield: chance x average count x AH price of each dust / essence / shard.
- It counts only when: Auctionator prices are on, the item is a green, blue or
  purple armor piece or weapon (no shirts / tabards), and at least one of its
  materials has a usable AH price (not older than 14 days). A material without
  a usable price counts as 0.
- Soulbound items: only when the character you play has Enchanting itself
  (soulbound items can not be mailed to an alt).
- Shows `(DE)` in light purple. The tooltip lists the outcomes ("80%  1-2 Strange
  Dust ... 1s each") and who can disenchant it, also when DE does not win.
- Other item tooltips (profession window, AH, vendor, loot, chat links) get the
  disenchant lines only: "LOF: Disenchant value ~x", the outcomes and who.
- DE-valued items move down in the swap / make room list, so LOF offers them later.
- The numbers come from the classic disenchant table (Data/DisenchantTable.lua);
  measured on Forever in October 2026: same materials and counts.

## Upgrade Advisor
- Every new weapon/armor piece in your bags is checked (loot, quest reward, vendor,
  mail), after the loot window closes and never in combat. Items you just took
  off, bank moves and the state at login are not "new".
- Score = sum of stat x weight (Data/StatWeights.lua, per class and talent tree).
  The spec comes from your talents (C_Traits); hybrid builds are mixed by points;
  no points yet -> the class default tree. Weapon DPS uses a melee, ranged or wand
  weight; a two-hander is compared with main hand + off-hand (off-hand DPS x 50%).
  Spell Damage counts for the damage trees (same weight as spell power), Spell
  Healing only for the healer trees (Holy Paladin, Discipline, Holy Priest,
  Restoration); one "damage and healing" effect is never counted twice.
- Higher score -> "Upgrade found: +x.x%". Equal score but better on stats the
  weights ignore -> upgrade without percentage. Otherwise no popup.
- Not usable (red tooltip text) or an excluded weapon type (fishing poles): no popup.
- One popup per item per session (until logout / reload), whatever you click:
  crafting or looting a second copy gives no new popup. The Scan button and a
  level-up show everything again. Tooltips, Send to alts and the swap
  protection are not affected.
- No popups at all while a fishing pole is in your main hand.
- Popup: item cards (the new item framed green for you / orange for an alt, the
  equipped one dimmed), stat table (Stat / Equipped / New / Change), effects (exact
  Equip / Use / Chance on hit text, not counted in the score), "Based on: ...".
- Equip (works like dragging, so Bind-on-Equip confirmation works), Cancel
  (decide later) or Ignore (never suggested again; `/lof ignored`).
- Alts: Bind-on-Equip gear that is not bound yet is also compared with the stored
  gear of your other characters (same realm and faction; class must be able to use
  it; level too low = "at level X"). Upgrade for you too -> "Also an upgrade for";
  only for alts -> orange popup "Gear upgrade for alt" (OK / Ignore).
- Every item tooltip (bags, AH, vendor, loot, chat links) shows "LOF: upgrade for
  you +x.x%" with the stat changes, and "LOF: also for ..." for alts.
- "Scan" button (Recent Loot header) checks all gear in your bags; LOF also
  does this silently after every level-up (only your own upgrades).
- Settings: on/off per character, and per alt which alts you get advice for.

## Send to alts
- "Upgrade" button (Recent Loot header, between Scan and Ignored) opens the Send
  to alts window: every bag item that is an upgrade for one of your alts,
  grouped per alt (class colour, dotted line between alts), with the gain, what
  it replaces and "at level X". An item for two alts is listed under both.
- At a mailbox the window opens by itself next to the mail when there is
  something to send (Settings > Upgrade Advisor: "Open Send to alts at the
  mailbox"), and closes with the mailbox.
- Send Mail tab open: click an item -> LOF fills in the recipient and puts the
  item in a free attachment slot. LOF never presses Send.
- When the mail already holds items for someone else, or is full, LOF does
  nothing and tells you why.

## Holdings
- Click the Holdings tab (or `/lof holdings`) to open the Holdings window; hover
  the tab for the explanation and when bags and bank were read.
- Per character LOF stores what lies where: bags (always), bank (while open),
  equipped gear (per slot), talents, mail (while the mailbox is open; items,
  expiry, who sent each item, gold per mail with the AH sale breakdown) and own auctions (when the AH
  opens; sold auctions leave the list when their sale mail arrives).
- Mail sent to an own character is booked in that character's mail at once.
- Character dropdown: logged-in character (default), any other, or All
  Characters. Only the same realm/ruleset and faction (characters that can
  share items). Location dropdown: All / Bag / Bank / Equipped / Mail / AH.
- The character dropdown shows when LOF last saw each other character. Remove
  from LOF (next to the dropdown, for another character; also Settings >
  Characters): after a confirmation LOF removes everything it stored for that
  character (holdings, gear, alt and reagent settings). The character in the
  game is not touched; logging in with it again reads it anew. The game never
  tells an addon that a character was deleted.
- Swap Value (as LOF values items) or Vendor Value.
- Profile line: class/level, spec, gold, gold in the mail, AH incoming, free bag
  and bank slots; professions on a second line.
- Gear for alts: all Bind-on-Equip gear in bags, bank and mail of all characters
  that is an upgrade for one of them. Character = for whom, Location = where.
  Per character gain, spec, what it replaces, gear age and an Ignore button.
- Data is read a second after every change and never at logout (the character
  is already gone then). The footer shows when each location was last read.

## Panel
- Forever look & feel: portrait frame with coin icon, inset sections for
  Inventory, Swap and Recent Loot (each collapsible with +/-).
- LOF icon (a coin with your free bag slots, red at 0): by default on the edge of
  the minimap and always shown. It is a LibDBIcon button, so minimap button
  collectors (Leatrix Plus and others) can gather it. Click: open / close the
  dashboard; right-click: Settings; drag: along the minimap; Shift-right-click:
  loose anywhere (it then shows only while the dashboard is closed, and Settings
  > General "Show the LOF icon at the minimap" goes off); Shift-right-click the
  loose coin: back to the minimap. Hover for gold / vendor / slots / professions.
- `<` closes the dashboard.
- "Professions" in the Inventory header: hover for skill per profession; green
  "Visit a trainer" when the next rank can be learned, grey "Trainer at level X"
  when only your character level is missing (also in the coin icon tooltip).
- Combat: the panel folds into the coin icon and Holdings / Send to alts close;
  after combat only what LOF closed comes back. Swap, "Not worth a swap" and
  Make room popups close when combat starts; an open Upgrade popup returns after
  the fight.
- Start moving while on the Info tab: back to the LOF tab.

## Settings window
- The Settings tab (or right-click on the LOF icon) opens the Settings window:
  topics on the left (Values, Upgrade Advisor, General, Reagents), the options on
  the right with one grey line each; longer help in the tooltips. Closes with X,
  Escape, moving or combat.

## Guide
- Opens by itself once per LOF version, a few seconds after login at a quiet
  moment (no combat, popup or loot window): "What's new" after an update, "How
  to use" on a first install. Stays until you close it (Got it / X / Escape);
  combat hides it and it returns after the fight.
- Settings > General: "Show What's new after an update" and "Open Guide";
  `/lof guide`.
- All money is shown with WoW's coin icons.

## Info tab
- Tabs under the panel: LOF (dashboard), Holdings (opens the Holdings window),
  Settings (opens the Settings window) and Info (about, how to use, support).
- Support: LOFCurseForge@DigitalFame.nl; the version info box can be copied (Ctrl+C).

## Commands
`/lof` toggle LOF - `/lof mini` close the dashboard - `/lof room` make room now -
`/lof all` all bag items - `/lof wl` whitelist - `/lof upgrade on|off|scan` -
`/lof ignored` - `/lof holdings` - `/lof settings` - `/lof guide` -
`/lof reset` window positions (icon back on the minimap) - `/lof version`

## Support
LOFCurseForge@DigitalFame.nl - please include the version info from the Info tab.

Copyright (c) 2026 Peter. All Rights Reserved.
