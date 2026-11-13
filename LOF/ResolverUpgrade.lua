-- =============================================================
-- LOF (LootOptimizer Forever) -- ResolverUpgrade.lua
-- Resolver layer, Upgrade domain: is a looted weapon/armor piece
-- usable, how does it compare to what is equipped, and why.
-- Returns a structured verdict with reason CODES; the UI turns those
-- into text. Class knowledge comes from Data/StatProfiles.lua.
-- =============================================================
--
-- Changelog
-- ---------
-- v0.13.20: audit 1.6.8 (final): no own Ignored list is stored while the
--   name is not known yet ("Unknown" at early login): a temporary list is
--   used, so no shared "Unknown-Realm" list can appear. Alts that still
--   have to train a weapon type sort after alts that can use it now (alt
--   list and Send to alts), as "at level" does.
-- v0.13.19: E28 (Tim's mail, 11 Nov): a weapon type the class can learn
--   but the character has not trained still counts, with needTraining =
--   the skill name ("Staves"): alts by the stored weaponSkills (Holdings;
--   not stored yet = class rule as before), you when the only red line in
--   the tooltip is the weapon type and IsPlayerSpell says untrained. For
--   you it works like "at level": tooltip line and swap protection, no
--   popup. RedLineInfo also returns the number of other red lines.
-- v0.13.18: E26 (Peter, 11 Nov): advice for an alt also respects that
--   alt's OWN Ignored list (what Huntrix ignored is never offered for
--   Huntrix while you play Priestly): EvaluateForAlts checks it next to
--   the per-alt ignores. A list not yet moved to the full name (E25) is
--   read under the first name.
-- v0.13.17: E25 (found 11 Nov with Tim's mail): the own Ignored list is
--   kept per full name ("First Last-Realm"); it was the first name only,
--   so alts with the same first name shared one list. Migration: a
--   character without a list under its full name gets a COPY of the old
--   first-name list (two alts with that first name both keep it; nothing
--   lost). Remove from LOF clears the full-name list only (the old one may
--   still be needed by another character with that first name).
-- v0.13.16: audit 1.6.8: fail safe while fishing - when the real weapon is
--   unknown or no longer in the bags, every weapon in the bags is
--   protected from Swap and Make room (agreement 5).
-- v0.13.15: E24 (Peter, 10 Nov: a level 1 mail bracer "+66.7% at level
--   40" for a level 5 Hunter alt): an upgrade for later (alt: armor or
--   weapon rule by level; you: "Requires Level") only counts within
--   StatProfiles.futureUpgradeLevels (5) levels. Closer to that level LOF
--   compares with what is worn then, so outgrown items drop out by
--   themselves. Tooltip, popups, Send to alts and swap protection alike.
-- v0.13.14: F17 (Peter's test, 9 Nov: two identical upgrades, > stuck):
--   every waiting entry gets its own bag slot (entry.bag / entry.slot):
--   exact link first, otherwise a slot with that item that no other entry
--   uses. Two identical items stay two upgrades, and the popup opens the
--   copy the player selected.
-- v0.13.13: F17 (Peter, 9 Nov): Upgrade.GetWaitingList replaces
--   PickFirstWaiting: all waiting upgrades for the button, in its order
--   (same rule), each with icon, quality, kind (SELF / ALT) and bag slot,
--   so the button can show the item and browse with < and >.
-- v0.13.12: F17 (Peter, 9 Nov): Upgrade.PickFirstWaiting: the button
--   shows your own upgrades before an alt's, and the largest gain first
--   (an empty slot counts as largest). Two upgrades for one slot: you see
--   the better one first; after Equip the other is no longer an upgrade
--   and drops off the button by itself.
-- v0.13.11: F17 (Peter, 9 Nov; CurseForge request): setting "Show an
--   'Upgrade available' button instead of the popup" (account wide,
--   LOF.db.upgradeButtonMode, default off; in GetAdvisorSettings as
--   buttonMode). Upgrade.GetPromptVerdict(entry): the one "is this queued
--   item still worth a popup" check, used by Capture for the popup and for
--   the count on the button.
-- v0.13.10: E23 (Peter, 9 Nov; idea and first patch by Silentspy): a
--   fishing pole in the main hand is never the weapon to compare with.
--   While fishing, the weapon slots compare with the weapons last held
--   without a pole (Holdings realWeapons), for you and for alts, but
--   only while that weapon is still in the bags. Unknown or gone: no
--   advice for the weapon slots (NOT_BETTER), a tooltip notice, and one
--   chat line per weapon and session when it is gone. While fishing the
--   real weapon in the bags is protected from Swap and Make room.
--   IsFishingPoleLink is the one pole check (also Upgrade.IsFishing).
-- v0.13.9: E21 (Peter, 8 Nov): default Ignored list. Default tools from
--   Resolver.lua that are weapons (Skinning Knife, Mining Pick, fishing
--   poles, Blacksmith Hammer ...) get no upgrade advice for any character
--   or alt, and show in the Ignored list as "default". Removing one is
--   remembered account wide (LOF_DB.removedDefaultIgnores), like the
--   whitelist defaults. Replaces the hidden fishing pole rule
--   (StatProfiles excludedSubclasses): IsExcludedWeapon is now
--   IsExcludedFromAdvice, at the same five places.
-- v0.13.8: E17 hardened (audit 1.6.6, Peter 4 Nov). AltClassAllowed
--   matches the "Classes:" names on the class token through the game's
--   own male and female class names, so gendered or other-language names
--   match too, and colour codes around a name are dropped. A name LOF
--   cannot map to a class, or an alt whose class is unknown, means no
--   restriction: the item stays protected (agreement 5).
-- v0.13.7: E18 (Peter, 23 Oct; branch, after launch). Upgrade.IsUniqueOwned:
--   a Unique item ("Unique" / "Unique (N)") you already have (bags, bank,
--   equipped) cannot be looted again ("You can't carry any more of those
--   items"). The swap deleted a bag item for nothing (Seal of the
--   Archmagus). Unreadable tooltip: false (as before, normal swap).
-- v0.13.6: E17 (Peter, 23 Oct; branch, after launch). Alt upgrades
--   ignored a class restriction on the item ("Classes: Druid"): Cenarion
--   Vestments were an upgrade for a Hunter and a Paladin. AltCanUse now
--   reads the "Classes:" line (ITEM_CLASSES_ALLOWED) from the tooltip
--   data and compares it with the alt's className. Unknown (no tooltip
--   data, item not loaded, no className): no restriction, so the item
--   stays protected (fail safe). FormatPattern is shared with the level
--   pattern (GetLevelPattern).
-- v0.13.5: E4 follow-up (release audit G1): the epoch only rises when an
--   item LOF itself requested arrives (itemData.waiting, by itemID), not on
--   every GET_ITEM_INFO_RECEIVED. An item the server reports as not
--   existing (success == false) is struck off, never requested again and
--   causes no recompute; it stays "not loaded" -> no upgrade, protected.
--   OnItemDataReceived(itemID, success); pendingSeen is gone.
--   IsLoaded added to the DEBT(dup) marker (audit D1).
-- v0.13.4: E4 fix (Peter: a grey Patchwork Gloves was an ALT UPGRADE over
--   the alt's green Heavy Linen Gloves; since 1.3.0). What an alt wears is
--   only a link from Holdings; when the client has not loaded that item
--   yet, GetItemStats returned nothing and the comparison ran against an
--   empty item. Now:
--   - CompareToSlot: equipped / off-hand / main-hand data not loaded ->
--     NOT_BETTER with result.pending (fail safe: never an upgrade on
--     data LOF does not have) and the item is requested.
--   - Evaluate / EvaluateForAlt(s) pass "pending" on; IsProtectedBagItem
--     keeps such a bag item protected (fail safe the other way round).
--   - An item-data epoch (Upgrade.OnItemDataReceived, called by Capture
--     on GET_ITEM_INFO_RECEIVED) is part of every cache key here and of
--     Holdings' gear-for-alts cache, so pending answers are recomputed.
--   - Upgrade.PreloadAltGear(): Capture calls it after login, so the
--     alts' worn gear is loaded before the first loot.
-- v0.13.3: Send to alts items carry statRows (the comparison with what the
--   alt wears), for the compact stat line in the list (UIAltMail 0.1.4).
-- v0.13.2: Effects that are already a stat are left out (Peter: "Equip:
--   Increases damage and healing ... by up to 1" stood under the table
--   while Spell Power -1 was in it, and read as a gain).
--   FilterStatEffects on newEffects and the equipped items' effects:
--   an Equip: line whose number equals one of the item's non-primary
--   stats is dropped. Use: / Chance on hit: and other Equip: effects
--   stay; "Effects not counted" only appears when one is left.
-- v0.13.1: Upgrade.GetAltComparison(alt, link): the full comparison for
--   an alt entry (EvaluateForAlts / EvaluateLootSlotForAlts) in the shape
--   of Upgrade.Evaluate, with compareName = the alt (Peter: the swap popup
--   for an alt upgrade shows the same table as for you).
-- v0.13.0: Upgrade.GetLootSlotComparison(lootSlot, link) (Peter: the swap
--   popup showed "+40%" but not where it came from). The same comparison
--   as the Upgrade popup for an item still in the loot window: verdict,
--   percent, statRows, newEffects, equippedItems and reasons (basis,
--   empty slot, effects not counted). nil when there is no comparison.
-- v0.12.2: Upgrade.ForgetCharacter(name) (Holdings 0.11.0): drops that
--   character's advisor settings, its "advise for this alt" entries in
--   the other characters' settings, its per-item alt ignores and its
--   ignored-upgrades list.
-- v0.12.1: Protection for future upgrades for you (Peter: Heavy Copper
--   Maul, upgrade at level 11, was offered in Make room now; alt
--   upgrades "at level X" were already protected). IsProtectedBagItem
--   also counts verdict.futureSelf (enabled, not ignored). Popups are
--   unchanged: IsAdviceWorthy / ShouldPrompt still ignore futureSelf.
-- v0.12.0: Advice once, not while fishing (Peter):
--   - An Upgrade popup is shown once per item (itemID) per session
--     (until logout / reload), whatever the player clicks: crafting or
--     looting a second copy gives no new popup. Upgrade.MarkAdvised /
--     WasAdvised. Forced prompts (Scan button, level-up scan, a popup
--     parked for combat) ignore this.
--   - Upgrade.IsFishing(): a fishing pole in the main hand means no
--     Upgrade popups at all (ShouldPrompt false). Tooltips unchanged.
--   - ShouldPrompt(verdict, force). Upgrade.IsAdviceWorthy keeps the old
--     rule; the swap protection uses it, so an upgrade stays protected
--     after its popup or while fishing.
-- v0.11.2: EvaluateLootSlot also returns the percentage and whether the
--   slot is empty (verdict, percent, emptySlot), for the swap popup.
-- v0.11.1: Send to alts with the mailbox open on the Inbox tab (Peter,
--   recording): GetSendMailState knows mailbox (MailFrame shown) and
--   open (Send Mail tab shown). A click is allowed as soon as the
--   mailbox is open; on the Inbox tab the action carries switchTab =
--   true (Capture switches to Send Mail first). NO_MAILBOX only when
--   the mailbox is closed. snap.mailOpen = mailbox open.
-- v0.11.0: Send to alts (Peter: "at the mailbox I search my bags for
--   the upgrades for my Priest"). Upgrade.GetAltMailSnapshot(): every
--   bag item that is an upgrade for an alt (same evaluation as the
--   tooltip and Gear for alts: GetBagItemAltUpgrades), grouped per alt,
--   usable first, then the largest gain. Per item the mail action,
--   decided here: ATTACH (fill in the recipient when it is not this
--   alt yet), IN_MAIL (already attached), NO_MAILBOX (Send Mail tab not
--   open), MAIL_FULL (no free attachment slot), OTHER_RECIPIENT (the
--   mail already holds items for someone else: send that first),
--   COMBAT. Upgrade.GetMailAction(bag, slot, link, altName) re-checks
--   right before Capture acts (the bag slot must still hold the same
--   link). Upgrade.GetSendMailState() reads the Send Mail form.
--   Setting "open at the mailbox": Upgrade.IsAltMailAutoOpen /
--   SetAltMailAutoOpen (LOF.db.altMailAutoOpen, default on), in
--   GetAdvisorSettings as mailAutoOpen; Upgrade.ShouldAutoOpenAltMail()
--   = setting on and at least one item to send.
-- v0.10.2: Evaluate: an item you cannot wear yet ONLY because of its
--   level (the one red line is the level requirement) gets
--   verdict.futureSelf = { percent, emptySlot, needLevel } when it is
--   an upgrade for you at that level. The popup verdict is unchanged
--   (no popup of its own); the orange alt popup shows it as "For you:
--   +x% (at level 11)", consistent with the tooltip.
-- v0.10.1: Tooltip: when the ONLY red line is the level requirement
--   (Blizzard's ITEM_MIN_LEVEL text, any language), the item is still
--   compared for you and marked self.tooLow / self.needLevel ("at level
--   14"), as for alts. Any other red line (armor type, weapon skill,
--   class) still means: nothing for you. The popup is unchanged.
-- v0.10.0: Upgrade.GetTooltipInfo(link, bag, slot) for EVERY item
--   tooltip (AH, vendor, loot, chat links, LOF windows, bags; Peter:
--   Blizzard's compare line on Forever only shows Armor). Returns
--   { self = { percent, emptySlot, rows }, alts = {...}, altRows }:
--   self = upgrade for the character you play (same weighted compare as
--   the popup; usable = no red line in the tooltip data), alts = as the
--   popup (only when the item can still be given away), rows = stat
--   changes (statRows of the comparison; altRows = best alt's when it
--   is no upgrade for you). Cached per link + bound state until data,
--   settings or level change. Nil when the Advisor is off / not gear.
-- v0.9.0: Upgrade Advisor per character (idea Nick, Peter): LOF_DB
--   .advisorChars["First Last"] = { enabled, altsOff = { [alt] = true } }.
--   - IsEnabled()/SetEnabled() now belong to the character you play.
--     Not set yet -> the old account-wide setting (no change on update).
--   - IsAltEnabled(name)/SetAltEnabled(name, on): which alts this
--     character gives advice for (default on). A switched-off alt is
--     left out of every alt result (popup, tooltip, swap, protection,
--     Gear for alts). The character you play is never "switched off" as
--     an alt (the main switch decides).
--   - GetAdvisorSettings(): snapshot for the Settings page (this
--     character + the other characters of the scope with their switch).
--   - Changes bump the same version as ignores (protection, caches).
-- v0.8.0: Gear for alts (B, Holdings window).
--   - Ignore per character: Upgrade.IgnoreFor(itemID, itemName, char)
--     / UnignoreFor / IsIgnoredFor (LOF_DB.altIgnores). An ignored
--     character is left out of every alt result (popup, tooltip, swap,
--     protection, Holdings list). GetIgnoredRows also lists these rows
--     (forName set); the ignore version covers both kinds.
--   - EvaluateForAlts(link, profiles): optional profile list (Holdings
--     passes all characters, the current one included).
--   - Alt entries carry replacesLink / replacesOffLink (what the alt
--     wears there) and gearUpdated (when that gear was read).
--   - Upgrade.IsTradableLink(link): bind type allows giving it away.
--   - The tooltip cache also resets on ignore changes.
-- v0.7.4: Swap protection (Peter: a grey mace that was an upgrade for
--   the Priest was almost thrown away). Upgrade.IsProtectedBagItem(bag,
--   slot): gear in the bags that the Upgrade Advisor would suggest (for
--   you or an alt, not ignored) must never be destroyed by a swap.
--   Upgrade.GetProtectionKey() changes when the answer can change
--   (Advisor on/off, gear/talents/level via Holdings.GetGearVersion,
--   ignore list), so Resolver can keep its per-slot cache.
-- v0.7.3: Duplicate stat keys are merged when the stats are read
--   (Data/StatProfiles statAliases): Frost Resistance came in as both
--   ITEM_MOD_FROST_RESISTANCE_SHORT and RESISTANCE4_NAME and showed
--   twice in the table. Same value under two names -> one key (the
--   higher value when they differ, never the sum).
-- v0.7.2: Equal weighted score (Peter, Priest: boots with only 7 Armor
--   vs boots without stats, Armor weight 0 for casters -> 0 vs 0): the
--   unweighted rule decides. Nothing goes down and something goes up ->
--   UPGRADE_CLEAR without percent, reason TIE_BETTER_STATS. Otherwise
--   NOT_BETTER as before. Applies to the player and to alts.
-- v0.7.1: Upgrade.GetBagItemAltUpgrades(bag, slot) for the bag tooltip
--   line "LOF: upgrade for ...": the same alt rules as the popup (not
--   bound, class can use it, higher score). Result cached per item link
--   until Holdings has new data (GetDataVersion), because tooltips ask
--   on every hover. Empty while the Upgrade Advisor is off. Ignored
--   items still get the line (ignore only stops the popups).
-- v0.7.0: Alt upgrades (LOF 1.3.0). Gear that is not soulbound is also
--   compared with the equipped gear of the other known characters
--   (Resolver.Holdings.GetAltGearProfiles), each with their own class
--   weights and stored talent points (class default tree when unknown).
--   - An alt counts when: the item is not bound (bag: IsBagItemBound;
--     loot window: bind type not Bind on Pickup / quest), the class can
--     use the armor / weapon type (Data/StatProfiles usability) and the
--     weighted score is higher. A level that is still too low does not
--     exclude the alt: entry.minLevel / entry.tooLow ("at level X").
--   - Old Holdings data without slots: the stored equipped items are
--     placed by item type (rings / trinkets fill both slots, a one-hand
--     weapon goes to the main hand first).
--   - verdict.alts: list per alt (best first); verdict.popupKind
--     "SELF" (upgrade for you, alts as extra lines) or "ALT" (only an
--     upgrade for alts: the stat table compares with the best alt's
--     gear, verdict.compareName). ShouldPrompt follows popupKind.
--   - Upgrade.EvaluateLootSlotForAlts(lootSlot, link): best alt entry
--     for an item still in the loot window (swap reason GEAR_ALT).
--   - CompareToSlot takes a slot reader, so the same comparison serves
--     the player and alts. GetWeightMixFor(classFile, trees) mixes
--     weights for any character.
-- v0.6.0: Stat weights (LOF 1.3.0, Data/StatWeights.lua).
--   - The character's spec comes from Forever's talent trees:
--     C_Traits.GetGroupDisplayInfoByTreeID (the three trees with their
--     names, left to right) + C_Traits.GetGroupCurrencyInfo (points per
--     tree). The weights of the trees are mixed by points (11 Ret ->
--     100% Ret; 6 Holy / 5 Ret -> 55% / 45%). No points (below level
--     10) -> the class's default tree from the data layer.
--   - Score of an item = sum of stat x weight. Weapon DPS uses the
--     Wand / RangedDPS / DPS weight by weapon type; the off-hand counts
--     at offHandDamageFactor. Related stats (AP vs Beast) count as a
--     share of another column; everything else counts 0.
--   - Verdict: score higher -> UPGRADE_CLEAR with percent = (new -
--     old) / old; otherwise NOT_BETTER. No more TRADE_OFF while weights
--     exist for the class (the unweighted rule stays as fallback).
--     Rings / trinkets / dual wield: the slot with the largest gain.
--   - Extra reasons for the popup: WEIGHT_BASIS (which trees, how much)
--     and EFFECTS_NOT_COUNTED (an item has Equip/Use/proc effects).
-- v0.5.0: Loot slots (LOF 1.1.2, "gear upgrade" swap): new
--   Upgrade.EvaluateLootSlot(lootSlot, link) returns the verdict code
--   for an item still in the loot window, with the same rules as a bag
--   item (slots, red tooltip lines, stat comparison). Red lines come
--   from C_TooltipInfo.GetLootItem, falling back to GetHyperlink
--   (both measured on Forever with a probe, 30-09-2026). No tooltip
--   data at all -> NOT_USABLE (safe: no swap for gear LOF cannot check).
--   Returns nil while the Upgrade Advisor is off or the item is ignored.
-- v0.4.0: Item effects (LOF 1.1.2): the "Equip:", "Use:" and "Chance on
--   hit:" lines from Blizzard's own tooltip are collected for the new
--   item (verdict.newEffects) and for each equipped item
--   (equippedItems[i].effects), exact text in the player's language.
--   Procs are not stats, so the stat table cannot show them.
-- v0.3.0: A two-hander is compared with main hand + off-hand combined
--   (all stats summed, off-hand DPS x offHandDamageFactor from the data
--   layer); reason REPLACES_BOTH, verdict.equippedItems lists both.
--   New verdict EXCLUDED for weapon types excluded in the data layer
--   (fishing poles).
-- v0.2.0: Verdict also carries statRows (every stat of both items with
--   old / new / change, for the comparison table) plus subType and
--   equipLoc of both items for the item cards.
-- v0.1.1: GetBagGearSnapshot + FindNewGear: detect new gear in the
--   bags regardless of source (loot, quest reward, vendor, mail).
-- v0.1.0: Initial version (Upgrade Advisor).
--   Verdicts:
--     UPGRADE_CLEAR : nothing goes down, something goes up (or the
--                     slot is empty)
--     TRADE_OFF     : ups and downs; LOF explains, the player decides
--     NOT_BETTER    : no popup
--     NOT_USABLE    : no popup (red text in the item tooltip: level,
--                     armor type, weapon skill, class restriction)
--   Stats are compared with C_Item.GetItemStats on both links
--   (new - equipped), so the direction is never ambiguous.
--   Ignored upgrades are stored per character.
-- =============================================================

local LOF = LOF
LOF.VERSION_RESOLVER_UPGRADE = "0.13.20"

local Upgrade = {}
LOF.Resolver.Upgrade = Upgrade

Upgrade.UPGRADE_CLEAR = "UPGRADE_CLEAR"
Upgrade.TRADE_OFF     = "TRADE_OFF"
Upgrade.NOT_BETTER    = "NOT_BETTER"
Upgrade.NOT_USABLE    = "NOT_USABLE"
Upgrade.EXCLUDED      = "EXCLUDED"

local VERDICT_RANK = { UPGRADE_CLEAR = 3, TRADE_OFF = 2, NOT_BETTER = 1, NOT_USABLE = 0, EXCLUDED = 0 }

-- -------------------------------------------------------------
-- v0.13.4 (E4): item data that is not loaded yet
-- -------------------------------------------------------------
-- epoch: part of every cache key below; raised when an item that a
-- comparison had to wait for arrives (v0.13.5: waiting, by itemID).
-- failed: items the server reported as not existing (never re-requested).
local itemData = { epoch = 0, waiting = {}, failed = {} }

-- DEBT(dup): IsLoaded and RequestLoad overlap with the other "is the item
-- loaded / request it" code (Resolver.lua RequestItemData, ResolverHoldings
-- RequestItem + BuildGearRows, ResolverReagents inline). RequestLoad uses
-- ResolverHoldings' RequestItem. Consolidate after 1.6.3 (audit D1).
local function IsLoaded(link)
    return link == nil or LOF.GetItemInfo(link) ~= nil
end

local function RequestLoad(link)
    local itemID = link and LOF.GetItemInfoInstant(link)
    if not itemID or itemData.failed[itemID] then return end
    itemData.waiting[itemID] = true
    local H = LOF.Resolver.Holdings
    if H and H.RequestItem then H.RequestItem(link) end
end

-- GET_ITEM_INFO_RECEIVED (via Capture): recompute only for an item LOF
-- asked for; success == false -> struck off for good (stays protected).
function Upgrade.OnItemDataReceived(itemID, success)
    itemID = tonumber(itemID)
    if not itemID or not itemData.waiting[itemID] then return end
    itemData.waiting[itemID] = nil
    if success == false then
        itemData.failed[itemID] = true
        return
    end
    itemData.epoch = itemData.epoch + 1
end

function Upgrade.GetDataEpoch()
    return itemData.epoch
end

-- -------------------------------------------------------------
-- Settings + ignored upgrades (per character)
-- -------------------------------------------------------------
-- v0.9.0: settings per character, keyed by the full name (Forever:
-- "First Last"; elsewhere the plain name).
local settingsVersion = 0   -- bumped with the ignore version (below)

local function CurrentFullName()
    local name, last = UnitName("player")
    -- v0.13.20: "Unknown" at early login is not a name
    if not name or name == "" or name == _G.UNKNOWNOBJECT then return nil end
    if type(last) == "string" and last ~= "" then return name .. " " .. last end
    return name
end

local function GetCharSettings(create)
    local name = CurrentFullName()
    if not name then return nil end
    LOF.db.advisorChars = LOF.db.advisorChars or {}
    local t = LOF.db.advisorChars[name]
    if not t and create then
        t = { altsOff = {} }
        LOF.db.advisorChars[name] = t
    end
    return t
end

function Upgrade.IsEnabled()
    local t = GetCharSettings(false)
    if t and t.enabled ~= nil then return t.enabled == true end
    return LOF.db.upgradeEnabled ~= false   -- before v0.9.0: one switch for all
end

function Upgrade.SetEnabled(enabled)
    local t = GetCharSettings(true)
    if not t then return end
    t.enabled = enabled and true or false
    settingsVersion = settingsVersion + 1
end

function Upgrade.IsAltEnabled(altName)
    if not altName or altName == CurrentFullName() then return true end
    local t = GetCharSettings(false)
    return not (t and t.altsOff and t.altsOff[altName])
end

function Upgrade.SetAltEnabled(altName, enabled)
    local t = GetCharSettings(true)
    if not t or not altName then return end
    t.altsOff = t.altsOff or {}
    t.altsOff[altName] = (not enabled) and true or nil
    settingsVersion = settingsVersion + 1
end

-- v0.11.0: open "Send to alts" when the mailbox opens (default on).
function Upgrade.IsAltMailAutoOpen()
    return LOF.db.altMailAutoOpen ~= false
end

function Upgrade.SetAltMailAutoOpen(enabled)
    LOF.db.altMailAutoOpen = enabled and true or false
    settingsVersion = settingsVersion + 1
end

-- v0.13.11 (F17): "Upgrade available" button instead of the popup
-- (account wide, default off).
function Upgrade.IsButtonMode()
    return LOF.db.upgradeButtonMode == true
end

function Upgrade.SetButtonMode(enabled)
    LOF.db.upgradeButtonMode = enabled and true or nil
    settingsVersion = settingsVersion + 1
end

-- Snapshot for the Settings page.
function Upgrade.GetAdvisorSettings()
    local snap = { name = CurrentFullName(), enabled = Upgrade.IsEnabled(), alts = {},
        mailAutoOpen = Upgrade.IsAltMailAutoOpen(),
        buttonMode = Upgrade.IsButtonMode() }   -- v0.13.11 (F17)
    local H = LOF.Resolver.Holdings
    for _, c in ipairs((H and H.GetCharacters and H.GetCharacters()) or {}) do
        if not c.isCurrent then
            snap.alts[#snap.alts + 1] = {
                name = c.name, class = c.class, className = c.className, level = c.level,
                enabled = Upgrade.IsAltEnabled(c.name),
            }
        end
    end
    return snap
end

local WEAPON_CLASS_ID = (_G.Enum and _G.Enum.ItemClass and _G.Enum.ItemClass.Weapon) or 2
-- v0.12.0: fishing pole = weapon class 2, subclass 20 (moved up, v0.13.10)
local FISHING_POLE_SUBCLASS = (_G.Enum and _G.Enum.ItemWeaponSubclass
    and _G.Enum.ItemWeaponSubclass.Fishingpole) or 20

-- v0.13.10 (E23): the one fishing pole check (link or itemID; any pole,
-- also one removed from the Ignored list: holding a pole means fishing).
local function IsFishingPoleLink(item)
    if not item then return false end
    local _, _, _, _, _, classID, subclassID = LOF.GetItemInfoInstant(item)
    return classID == WEAPON_CLASS_ID and subclassID == FISHING_POLE_SUBCLASS
end

function Upgrade.IsFishingPoleLink(item)   -- for Holdings
    return IsFishingPoleLink(item)
end

-- v0.13.17 (E25): full name ("First Last") + realm
local function GetCharKey()
    return tostring(CurrentFullName() or "?") .. "-" .. tostring(GetRealmName() or "?")
end

-- Before v0.13.17: first name only (shared by alts with the same first name)
local function GetOldCharKey()
    return tostring(UnitName("player") or "?") .. "-" .. tostring(GetRealmName() or "?")
end

local ignoreVersion = 0   -- v0.7.4: bumped on every ignore / unignore

local function GetIgnoredTable()
    LOF.db.ignoredUpgrades = LOF.db.ignoredUpgrades or {}
    local all = LOF.db.ignoredUpgrades
    -- v0.13.20: no name yet: a temporary list, nothing stored
    if not CurrentFullName() then return {} end
    local key = GetCharKey()
    if not all[key] then
        all[key] = {}
        -- v0.13.17 (E25): a copy of the old first-name list, once
        local old = GetOldCharKey()
        if old ~= key and type(all[old]) == "table" then
            for itemID, e in pairs(all[old]) do
                all[key][itemID] = (type(e) == "table") and { name = e.name, time = e.time } or e
            end
        end
    end
    return all[key]
end

-- v0.13.18 (E26): is this item on that character's OWN Ignored list?
-- name = full name; a list not yet moved (E25) sits under the first name.
local function IsOnOwnListOf(itemID, name)
    local all = LOF.db.ignoredUpgrades
    if not itemID or not name or type(all) ~= "table" then return false end
    local realm = tostring(GetRealmName() or "?")
    local list = all[tostring(name) .. "-" .. realm]
    if list == nil then
        local first = tostring(name):match("^(%S+)")
        list = first and all[first .. "-" .. realm]
    end
    return type(list) == "table" and list[itemID] ~= nil
end

-- v0.13.9 (E21): default Ignored list, account wide: the default tools
-- (Resolver.lua) that are weapons, unless the player removed one.
-- No answer from the resolver: not ignored (advice as before).
local function GetRemovedDefaultIgnores()
    LOF.db.removedDefaultIgnores = LOF.db.removedDefaultIgnores or {}
    return LOF.db.removedDefaultIgnores
end

local function IsDefaultIgnored(itemID)
    if not itemID then return false end
    local R = LOF.Resolver
    if not (R and R.IsDefaultToolID and R.IsDefaultToolID(itemID)) then return false end
    local classID = select(6, LOF.GetItemInfoInstant(itemID))
    return classID == WEAPON_CLASS_ID and not GetRemovedDefaultIgnores()[itemID]
end

function Upgrade.IsIgnored(itemID)
    return itemID ~= nil and GetIgnoredTable()[itemID] ~= nil
end

function Upgrade.Ignore(itemID, name)
    if not itemID then return end
    GetIgnoredTable()[itemID] = { name = name, time = time() }
    ignoreVersion = ignoreVersion + 1
    LOF.Print(tostring(name) .. " will not be suggested again. (/lof ignored)")
end

function Upgrade.Unignore(itemID)
    local t = GetIgnoredTable()
    if itemID and t[itemID] then
        LOF.Print(tostring(t[itemID].name) .. " removed from ignored upgrades.")
        t[itemID] = nil
        ignoreVersion = ignoreVersion + 1
    elseif IsDefaultIgnored(itemID) then   -- v0.13.9 (E21)
        GetRemovedDefaultIgnores()[itemID] = true
        ignoreVersion = ignoreVersion + 1
        local name = LOF.GetItemInfo(itemID)
        LOF.Print(tostring(name or ("item " .. itemID)) .. " removed from ignored upgrades (all characters).")
    end
end

-- v0.8.0: ignore per character (alt upgrades), account wide
local function GetAltIgnores()
    LOF.db.altIgnores = LOF.db.altIgnores or {}
    return LOF.db.altIgnores
end

function Upgrade.IsIgnoredFor(itemID, charName)
    local e = itemID and GetAltIgnores()[itemID]
    return e ~= nil and e.chars ~= nil and e.chars[charName] ~= nil
end

function Upgrade.IgnoreFor(itemID, itemName, charName)
    if not itemID or not charName then return end
    local t = GetAltIgnores()
    t[itemID] = t[itemID] or { name = itemName, chars = {} }
    t[itemID].chars[charName] = time()
    ignoreVersion = ignoreVersion + 1
    LOF.Print(tostring(itemName) .. " will not be suggested for " .. tostring(charName) .. " again. (/lof ignored)")
end

function Upgrade.UnignoreFor(itemID, charName)
    local t = GetAltIgnores()
    local e = itemID and t[itemID]
    if not (e and e.chars and e.chars[charName]) then return end
    e.chars[charName] = nil
    if next(e.chars) == nil then t[itemID] = nil end
    ignoreVersion = ignoreVersion + 1
    LOF.Print(tostring(e.name) .. " removed from ignored upgrades for " .. tostring(charName) .. ".")
end

-- v0.12.2: forget a character (full name, "First Last" on Forever)
function Upgrade.ForgetCharacter(name)
    if not name then return end
    local chars = LOF.db.advisorChars
    if type(chars) == "table" then
        chars[name] = nil
        for _, t in pairs(chars) do
            if type(t) == "table" and type(t.altsOff) == "table" then t.altsOff[name] = nil end
        end
    end
    for itemID, e in pairs(GetAltIgnores()) do
        if type(e) == "table" and type(e.chars) == "table" then
            e.chars[name] = nil
            if next(e.chars) == nil then GetAltIgnores()[itemID] = nil end
        end
    end
    -- v0.13.17 (E25): ignored upgrades are keyed "First Last-Realm" (GetCharKey)
    if type(LOF.db.ignoredUpgrades) == "table" then
        LOF.db.ignoredUpgrades[tostring(name) .. "-" .. tostring(GetRealmName() or "?")] = nil
    end
    settingsVersion = settingsVersion + 1
    ignoreVersion = ignoreVersion + 1
end

function Upgrade.GetIgnoreVersion()
    return ignoreVersion + settingsVersion * 100000   -- v0.9.0: settings count too
end

function Upgrade.GetIgnoredRows()
    local rows = {}
    for itemID, entry in pairs(GetIgnoredTable()) do
        local name, _, quality, _, _, _, _, _, _, icon = LOF.GetItemInfo(itemID)
        rows[#rows + 1] = {
            itemID = itemID, name = name or entry.name or ("item " .. itemID),
            quality = quality, icon = icon,
        }
    end
    -- v0.8.0: per character
    for itemID, entry in pairs(GetAltIgnores()) do
        local name, _, quality, _, _, _, _, _, _, icon = LOF.GetItemInfo(itemID)
        for charName in pairs(entry.chars or {}) do
            rows[#rows + 1] = {
                itemID = itemID, name = name or entry.name or ("item " .. itemID),
                quality = quality, icon = icon, forName = charName,
            }
        end
    end
    -- v0.13.9 (E21): default entries after the player's own
    local R = LOF.Resolver
    local own = GetIgnoredTable()
    for _, itemID in ipairs(R and R.GetDefaultToolIDs and R.GetDefaultToolIDs() or {}) do
        if not own[itemID] and IsDefaultIgnored(itemID) then
            local name, _, quality, _, _, _, _, _, _, icon = LOF.GetItemInfo(itemID)
            if name then   -- not loaded yet: shown after GET_ITEM_INFO_RECEIVED
                rows[#rows + 1] = {
                    itemID = itemID, name = name, quality = quality, icon = icon, isDefault = true,
                }
            end
        end
    end
    table.sort(rows, function(a, b)
        if (a.isDefault == true) ~= (b.isDefault == true) then return not a.isDefault end
        if a.name ~= b.name then return a.name < b.name end
        return tostring(a.forName or "") < tostring(b.forName or "")
    end)
    return rows
end

-- -------------------------------------------------------------
-- Slot mapping
-- -------------------------------------------------------------
local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 },
    INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 },
    INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16 },            -- 17 added when dual wield is possible
    INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 },
    INVTYPE_RELIC = { 18 },
}

local function GetTargetSlots(equipLoc)
    local slots = SLOTS[equipLoc]
    if not slots then return nil end
    if equipLoc == "INVTYPE_WEAPON" and CanDualWield and CanDualWield() then
        return { 16, 17 }
    end
    return slots
end

-- -------------------------------------------------------------
-- Item effects (v0.4.0): Equip / Use / Chance on hit lines from the
-- game's own tooltip data. Returns a list of strings (may be empty).
-- -------------------------------------------------------------
local EFFECT_PREFIXES = nil

local function GetEffectPrefixes()
    if EFFECT_PREFIXES then return EFFECT_PREFIXES end
    EFFECT_PREFIXES = {}
    for _, key in ipairs({ "ITEM_SPELL_TRIGGER_ONEQUIP", "ITEM_SPELL_TRIGGER_ONUSE",
                           "ITEM_SPELL_TRIGGER_ONPROC" }) do
        local text = _G[key]
        if type(text) == "string" and text ~= "" then
            EFFECT_PREFIXES[#EFFECT_PREFIXES + 1] = text
        end
    end
    return EFFECT_PREFIXES
end

local function IsEffectLine(text)
    if type(text) ~= "string" then return false end
    for _, prefix in ipairs(GetEffectPrefixes()) do
        if text:sub(1, #prefix) == prefix then return true end
    end
    return false
end

-- data: C_TooltipInfo result. Falls back to nothing on older clients.
local function EffectsFromTooltipData(data)
    local effects = {}
    if data and data.lines then
        for _, line in ipairs(data.lines) do
            local text = line.leftText
            if IsEffectLine(text) then
                effects[#effects + 1] = text
            end
        end
    end
    return effects
end

local function GetBagItemEffects(bag, slot)
    local C_TooltipInfo = _G.C_TooltipInfo
    if not (C_TooltipInfo and C_TooltipInfo.GetBagItem) then return {} end
    local ok, data = pcall(C_TooltipInfo.GetBagItem, bag, slot)
    return ok and EffectsFromTooltipData(data) or {}
end

local function GetLinkEffects(link)
    local C_TooltipInfo = _G.C_TooltipInfo
    if not (link and C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return {} end
    local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
    return ok and EffectsFromTooltipData(data) or {}
end

-- -------------------------------------------------------------
-- Usability: red text in the tooltip means "you cannot use this"
-- (level, armor type, weapon skill, class). One check covers all.
-- -------------------------------------------------------------
local function IsRed(r, g, b)
    return r and g and b and r > 0.9 and g < 0.2 and b < 0.2
end

-- data: C_TooltipInfo result. true / false, or nil without line data.
local function DataHasRedLine(data)
    if type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
    for _, line in ipairs(data.lines) do
        local l, r = line.leftColor, line.rightColor
        if (l and IsRed(l.r, l.g, l.b)) or (r and IsRed(r.r, r.g, r.b)) then
            return true
        end
    end
    return false
end

local function TooltipHasRedLine(bag, slot)
    local C_TooltipInfo = _G.C_TooltipInfo
    if C_TooltipInfo and C_TooltipInfo.GetBagItem then
        local red = DataHasRedLine(C_TooltipInfo.GetBagItem(bag, slot))
        if red ~= nil then return red end
    end

    -- Fallback: hidden scan tooltip (older clients)
    local tip = _G.LOF_ScanTooltip
    if not tip then
        tip = CreateFrame("GameTooltip", "LOF_ScanTooltip", UIParent, "GameTooltipTemplate")
    end
    tip:SetOwner(UIParent, "ANCHOR_NONE")
    tip:ClearLines()
    tip:SetBagItem(bag, slot)
    for i = 1, tip:NumLines() do
        for _, side in ipairs({ "Left", "Right" }) do
            local fs = _G["LOF_ScanTooltipText" .. side .. i]
            if fs and fs:GetText() and IsRed(fs:GetTextColor()) then
                tip:Hide()
                return true
            end
        end
    end
    tip:Hide()
    return false
end

-- -------------------------------------------------------------
-- Stats
-- -------------------------------------------------------------
local DPS_KEY = "ITEM_MOD_DAMAGE_PER_SECOND_SHORT"

local function GetStats(link)
    if not link then return {} end
    local C_Item = _G.C_Item
    local stats
    if C_Item and C_Item.GetItemStats then
        stats = C_Item.GetItemStats(link)
    elseif _G.GetItemStats then
        stats = _G.GetItemStats(link)
    end
    -- v0.7.3: one key per stat (aliases from the data layer)
    local profiles = LOF.Data and LOF.Data.StatProfiles
    local aliases = profiles and profiles.statAliases or {}
    local merged = {}
    for key, value in pairs(stats or {}) do
        local target = aliases[key] or key
        local v = tonumber(value) or 0
        if merged[target] == nil or v > merged[target] then merged[target] = v end
    end
    return merged
end

-- v0.13.2: an "Equip:" line that is already a stat in the table (spell
-- power, healing, hit, crit, attack power, mana per 5 ...) is not an
-- effect: the game reports it as a stat too, and the table shows its
-- gain or loss. Recognised by a number in the line equal to one of the
-- item's non-primary stats. Use: / Chance on hit: lines always stay.
local function IsPrimaryStatKey(key)
    key = tostring(key)
    return key:find("STRENGTH", 1, true) or key:find("AGILITY", 1, true)
        or key:find("STAMINA", 1, true) or key:find("INTELLECT", 1, true)
        or key:find("SPIRIT", 1, true) or key:find("RESISTANCE", 1, true)
        or key:find("DAMAGE_PER_SECOND", 1, true)
end

local function FilterStatEffects(effects, link)
    if not effects or #effects == 0 or not link then return effects or {} end
    local equipPrefix = _G.ITEM_SPELL_TRIGGER_ONEQUIP
    local values = {}
    for key, value in pairs(GetStats(link)) do
        if not IsPrimaryStatKey(key) then
            local v = tonumber(value)
            if v and v ~= 0 then values[math.abs(v)] = true end
        end
    end
    local out = {}
    for _, text in ipairs(effects) do
        local isStat = false
        if type(equipPrefix) == "string" and equipPrefix ~= ""
            and text:sub(1, #equipPrefix) == equipPrefix then
            for n in text:gmatch("%d+") do
                if values[tonumber(n)] then isStat = true; break end
            end
        end
        if not isStat then out[#out + 1] = text end
    end
    return out
end

local function GetWeaponData()
    local data = LOF.Data and LOF.Data.StatProfiles
    return (data and data.weapons) or {}
end

-- Stats of what is equipped in the compared slot(s). For a two-hander
-- this is main hand + off-hand combined; the off-hand's DPS counts for
-- offHandDamageFactor (data layer), all other stats count in full.
local function GetEquippedStats(mainLink, offLink)
    local total = {}
    for key, value in pairs(GetStats(mainLink)) do
        total[key] = tonumber(value) or 0
    end
    if offLink then
        local factor = tonumber(GetWeaponData().offHandDamageFactor) or 0.5
        for key, value in pairs(GetStats(offLink)) do
            local v = tonumber(value) or 0
            if key == DPS_KEY then v = v * factor end
            total[key] = (total[key] or 0) + v
        end
    end
    return total
end

-- new - equipped, only non-zero differences
local function StatDelta(newStats, oldStats)
    local delta = {}
    for key, value in pairs(newStats) do
        local d = (tonumber(value) or 0) - (tonumber(oldStats[key]) or 0)
        if math.abs(d) > 0.001 then delta[key] = d end
    end
    for key, value in pairs(oldStats) do
        if newStats[key] == nil then
            local d = -(tonumber(value) or 0)
            if math.abs(d) > 0.001 then delta[key] = d end
        end
    end
    return delta
end

local function BuildOrderIndex()
    local order = {}
    local data = LOF.Data and LOF.Data.StatProfiles
    for i, key in ipairs((data and data.displayOrder) or {}) do
        order[key] = i
    end
    return order
end

-- Full comparison table for display: every stat present on either
-- side, with both values and the change, in display order.
local function BuildStatRows(newStats, oldStats)
    local keys = {}
    for key in pairs(newStats) do keys[key] = true end
    for key in pairs(oldStats) do keys[key] = true end
    local order = BuildOrderIndex()

    local rows = {}
    for key in pairs(keys) do
        local new = tonumber(newStats[key]) or 0
        local old = tonumber(oldStats[key]) or 0
        rows[#rows + 1] = {
            key = key, new = new, old = old, delta = new - old,
            hasOld = oldStats[key] ~= nil, hasNew = newStats[key] ~= nil,
        }
    end
    table.sort(rows, function(x, y)
        local ox, oy = order[x.key] or 99, order[y.key] or 99
        if ox ~= oy then return ox < oy end
        return x.key < y.key
    end)
    return rows
end

local function GetClassProfile()
    local _, classFile = UnitClass("player")
    local data = LOF.Data and LOF.Data.StatProfiles
    local profile = data and data.classes and data.classes[classFile or ""]
    return profile, classFile, data and data.meta
end

-- -------------------------------------------------------------
-- v0.6.0: spec mix + weights
-- -------------------------------------------------------------
local function Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a = pcall(fn, ...)
    if ok then return a end
    return nil
end

-- Points per talent tree of the current character, in the order of
-- the talent window. Returns { {name, points}, ... } or nil.
function Upgrade.GetTalentTrees()
    local CT, T = _G.C_ClassTalents, _G.C_Traits
    if not (CT and T) then return nil end
    local configID = Try(CT.GetActiveConfigID)
    if type(configID) ~= "number" then return nil end
    local info = Try(T.GetConfigInfo, configID)
    local treeID = type(info) == "table" and type(info.treeIDs) == "table" and info.treeIDs[1]
    if type(treeID) ~= "number" then return nil end
    local displays = Try(T.GetGroupDisplayInfoByTreeID, treeID)
    if type(displays) ~= "table" or #displays == 0 then return nil end
    local ids = {}
    for _, d in ipairs(displays) do
        if type(d) == "table" and type(d.groupID) == "number" then ids[#ids + 1] = d.groupID end
    end
    local spent = {}
    local currencies = (#ids > 0) and Try(T.GetGroupCurrencyInfo, configID, ids)
    for _, g in ipairs(type(currencies) == "table" and currencies or {}) do
        local first = type(g) == "table" and type(g.currencyInfos) == "table" and g.currencyInfos[1]
        if type(g.traitNodeGroupID) == "number" and type(first) == "table" then
            spent[g.traitNodeGroupID] = tonumber(first.spent) or 0
        end
    end
    local trees = {}
    for _, d in ipairs(displays) do
        if type(d) == "table" and type(d.groupID) == "number" then
            trees[#trees + 1] = { name = d.displayName, points = spent[d.groupID] or 0 }
        end
    end
    return trees
end

local function GetClassWeights(classFile)
    local data = LOF.Data and LOF.Data.StatWeights
    return data and data.classes and data.classes[classFile or ""], data
end

-- The mixed weights for a class and its talent points (any character):
-- returns weights { column = value }, basis { {name, share, points} }, source
function Upgrade.GetWeightMixFor(classFile, trees)
    local cw, data = GetClassWeights(classFile)
    if not cw or not cw.trees then return nil end

    trees = trees or {}
    local total = 0
    for i = 1, #cw.trees do
        total = total + (tonumber(trees[i] and trees[i].points) or 0)
    end

    local mixed, basis, source = {}, {}, "talents"
    local function add(index, share, points)
        local t = cw.trees[index]
        if not t then return end
        for column, value in pairs(t) do
            if type(value) == "number" then
                mixed[column] = (mixed[column] or 0) + value * share
            end
        end
        basis[#basis + 1] = {
            name = (trees[index] and trees[index].name) or t.name,
            share = share, points = points,
        }
    end

    if total > 0 then
        for i = 1, #cw.trees do
            local pts = tonumber(trees[i] and trees[i].points) or 0
            if pts > 0 then add(i, pts / total, pts) end
        end
        table.sort(basis, function(a, b) return a.share > b.share end)
    else
        source = "default"
        add(cw.default or 1, 1, 0)
    end
    return mixed, basis, source, data
end

-- The mixed weights for the current character.
function Upgrade.GetWeightMix()
    local _, classFile = UnitClass("player")
    return Upgrade.GetWeightMixFor(classFile, Upgrade.GetTalentTrees())
end

local RANGED_LOCS = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true }
local WAND_SUBCLASS = 19

-- Score of one item under mixed weights. dpsFactor scales weapon DPS
-- (off-hand). Unknown stats count 0.
local function ScoreItem(link, mix, data, dpsFactor)
    if not link or not mix then return 0 end
    local stats = GetStats(link)
    local _, _, _, equipLoc, _, classID, subclassID = LOF.GetItemInfoInstant(link)

    -- stat key -> weight, built from the data layer's columns
    local weightOf = {}
    for column, keyList in pairs((data and data.keys) or {}) do
        for _, key in ipairs(keyList) do weightOf[key] = mix[column] or 0 end
    end
    for key, rel in pairs((data and data.related) or {}) do
        weightOf[key] = (mix[rel.of] or 0) * (tonumber(rel.factor) or 0)
    end

    local dpsWeight
    if classID == WEAPON_CLASS_ID and subclassID == WAND_SUBCLASS then
        dpsWeight = mix.Wand or 0
    elseif RANGED_LOCS[equipLoc or ""] then
        dpsWeight = mix.RangedDPS or mix.DPS or 0
    else
        dpsWeight = mix.DPS or 0
    end

    local score = 0
    for key, value in pairs(stats) do
        local v = tonumber(value) or 0
        if key == DPS_KEY then
            score = score + v * dpsWeight * (dpsFactor or 1)
        else
            score = score + v * (weightOf[key] or 0)
        end
    end
    return score
end

-- Excluded weapon types (e.g. fishing poles), from the data layer.

-- v0.13.9 (E21): no upgrade advice for an item on the default Ignored
-- list (was: weapon subclasses from StatProfiles, the fishing pole).
local function IsExcludedFromAdvice(link)
    if not link then return false end
    return IsDefaultIgnored((LOF.GetItemInfoInstant(link)))
end

-- -------------------------------------------------------------
-- Comparison against one equipped slot
-- -------------------------------------------------------------
-- v0.13.10 (E23): the weapon slots to compare with while a fishing pole
-- is in the main hand. main / off = held now; real = { [16], [17] } last
-- held without a pole (nil: never seen); inBags(link) -> the link as it
-- lies in the bags now, or nil. Returns the links to compare with for
-- 16 and 17 and a status: nil (not fishing), "ok", "unknown" or
-- "missing" (+ the missing link). A slot that cannot be resolved gets
-- the pole itself: CompareToSlot never compares with a pole.
local function ResolveWeaponBase(main, off, real, inBags)
    if not IsFishingPoleLink(main) then return main, off, nil end
    if type(real) ~= "table" then return main, main, "unknown" end
    local out, status, missing = {}, "ok", nil
    for _, slot in ipairs({ 16, 17 }) do
        local link = real[slot]
        if link ~= nil then
            local found = inBags(link)
            if found then
                out[slot] = found
            else
                out[slot] = main
                status = "missing"
                missing = missing or link
            end
        end
    end
    return out[16], out[17], status, missing
end

local weaponBaseCache = { t = nil }
local warnedMissing = {}   -- one chat line per weapon per session

local function PlayerWeaponBase()
    local now = GetTime()
    if weaponBaseCache.t == now then return weaponBaseCache.v end
    local base = nil
    local main = GetInventoryItemLink("player", 16)
    if IsFishingPoleLink(main) then
        local H = LOF.Resolver.Holdings
        local real = H and H.GetRealWeapons and H.GetRealWeapons()
        local m, o, status, missing = ResolveWeaponBase(main, GetInventoryItemLink("player", 17), real,
            function(link)
                local bag, slot = Upgrade.FindInBags(link, (LOF.GetItemInfoInstant(link)))
                local c = bag and LOF.GetContainerItemInfo(bag, slot)
                return c and c.hyperlink or nil
            end)
        base = { [16] = m, [17] = o, status = status }
        if status == "missing" and missing and not warnedMissing[missing] then
            warnedMissing[missing] = true
            LOF.Print(missing .. " is no longer in your bags: no weapon advice while fishing."
                .. " It returns when you equip a weapon.")
        end
    end
    weaponBaseCache.t, weaponBaseCache.v = now, base
    return base
end

-- v0.13.10 (E23): part of the protection and tooltip cache keys
function Upgrade.GetWeaponBaseKey()
    local base = PlayerWeaponBase()
    if not base then return "-" end
    return tostring(base[16]) .. "/" .. tostring(base[17]) .. "/" .. tostring(base.status)
end

local function PlayerSlotLink(slot)
    if slot == 16 or slot == 17 then   -- v0.13.10 (E23)
        local base = PlayerWeaponBase()
        if base then return base[slot] end
    end
    return GetInventoryItemLink("player", slot)
end

-- slotLink(slot) -> link of what is equipped there (player or alt).
local function CompareToSlot(newLink, equipLoc, targetSlot, mix, data, slotLink)
    slotLink = slotLink or PlayerSlotLink
    local equippedLink = slotLink(targetSlot)
    local result = { targetSlot = targetSlot, equippedLink = equippedLink, reasons = {} }

    -- An off-hand item cannot be used next to an equipped two-hander
    -- (checked first: an "empty" off-hand slot is not a real option).
    if targetSlot == 17 then
        local mh = slotLink(16)
        local mhLoc
        if mh then
            if not IsLoaded(mh) then            -- v0.13.4 (E4) fail safe
                RequestLoad(mh)
                result.verdict = Upgrade.NOT_BETTER
                result.pending = true
                return result
            end
            mhLoc = select(9, LOF.GetItemInfo(mh))
        end
        if mhLoc == "INVTYPE_2HWEAPON" then
            result.verdict = Upgrade.NOT_BETTER
            return result
        end
    end

    -- A two-hander replaces main hand AND off-hand: compare with both.
    local offLink
    if equipLoc == "INVTYPE_2HWEAPON" and targetSlot == 16 then
        offLink = slotLink(17)
        result.offHandLink = offLink
    end

    -- v0.13.10 (E23): a fishing pole is never what you compare with
    -- (real weapon unknown or gone): no advice for this slot.
    if IsFishingPoleLink(equippedLink) or IsFishingPoleLink(offLink) then
        result.verdict = Upgrade.NOT_BETTER
        return result
    end

    -- v0.13.4 (E4) fail safe: what is worn is not loaded -> never an upgrade
    if not IsLoaded(equippedLink) or not IsLoaded(offLink) then
        if not IsLoaded(equippedLink) then RequestLoad(equippedLink) end
        if not IsLoaded(offLink) then RequestLoad(offLink) end
        result.verdict = Upgrade.NOT_BETTER
        result.pending = true
        return result
    end

    local newStats = GetStats(newLink)

    if not equippedLink and not offLink then
        result.verdict = Upgrade.UPGRADE_CLEAR
        result.reasons[1] = { code = "EMPTY_SLOT" }
        result.statRows = BuildStatRows(newStats, {})
        if mix then
            result.scoreNew = ScoreItem(newLink, mix, data)
            result.scoreOld = 0
            result.gain = math.huge
        end
        return result
    end

    local oldStats = GetEquippedStats(equippedLink, offLink)
    local delta = StatDelta(newStats, oldStats)
    local anyUp, anyDown = false, false
    local order = BuildOrderIndex()
    local statReasons = {}
    for key, value in pairs(delta) do
        if value > 0 then anyUp = true else anyDown = true end
        statReasons[#statReasons + 1] = { code = "STAT", key = key, value = value }
    end
    table.sort(statReasons, function(x, y)
        local ox, oy = order[x.key] or 99, order[y.key] or 99
        if ox ~= oy then return ox < oy end
        return x.key < y.key
    end)
    for _, r in ipairs(statReasons) do result.reasons[#result.reasons + 1] = r end

    if offLink then
        result.reasons[#result.reasons + 1] = {
            code = "REPLACES_BOTH",
            factor = tonumber(GetWeaponData().offHandDamageFactor) or 0.5,
        }
    end

    if mix then
        -- v0.6.0: weighted score decides
        local factor = tonumber(GetWeaponData().offHandDamageFactor) or 0.5
        local newScore = ScoreItem(newLink, mix, data)
        local oldScore = ScoreItem(equippedLink, mix, data) + ScoreItem(offLink, mix, data, factor)
        result.scoreNew, result.scoreOld = newScore, oldScore
        result.gain = newScore - oldScore
        if newScore > oldScore + 0.0001 then
            result.verdict = Upgrade.UPGRADE_CLEAR
            if oldScore > 0 then
                result.percent = (newScore - oldScore) / oldScore * 100
            end
        elseif math.abs(newScore - oldScore) <= 0.0001 and anyUp and not anyDown then
            -- v0.7.2: same score, but better on stats the weights ignore
            result.verdict = Upgrade.UPGRADE_CLEAR
            result.reasons[#result.reasons + 1] = { code = "TIE_BETTER_STATS" }
        else
            result.verdict = Upgrade.NOT_BETTER
        end
    elseif anyUp and not anyDown then
        result.verdict = Upgrade.UPGRADE_CLEAR
    elseif anyUp and anyDown then
        result.verdict = Upgrade.TRADE_OFF
    else
        result.verdict = Upgrade.NOT_BETTER
    end
    result.delta = delta
    result.statRows = BuildStatRows(newStats, oldStats)
    return result
end

-- Better of two comparisons: higher verdict, then the larger gain.
local function IsBetter(r, best)
    if not best then return true end
    local a, b = VERDICT_RANK[r.verdict], VERDICT_RANK[best.verdict]
    if a ~= b then return a > b end
    return (r.gain or 0) > (best.gain or 0)
end

-- -------------------------------------------------------------
-- v0.7.0: alt upgrades
-- -------------------------------------------------------------
local ARMOR_CLASS_ID = (_G.Enum and _G.Enum.ItemClass and _G.Enum.ItemClass.Armor) or 4
local BIND_ON_PICKUP, BIND_QUEST = 1, 4

local function GetUsability(classFile)
    local data = LOF.Data and LOF.Data.StatProfiles
    local u = data and data.usability
    return u and u.classes and u.classes[classFile or ""]
end

-- v0.13.19 (E28): the skill name to train for this weapon subclass, or nil
-- (no skill needed, already known, or not known whether it is known).
local function TrainingNeeded(subclassID, known)
    local data = LOF.Data and LOF.Data.StatProfiles
    local s = data and data.weaponSkills and data.weaponSkills[subclassID or -1]
    if not s or type(known) ~= "table" or known[subclassID] then return nil end
    return s.name
end

-- v0.13.19 (E28): you: a weapon your class can learn but you have not
-- trained -> skill name, else nil.
local function SelfTrainingNeeded(link)
    local _, _, _, _, _, classID, subclassID = LOF.GetItemInfoInstant(link)
    if classID ~= WEAPON_CLASS_ID or not _G.IsPlayerSpell then return nil end
    local _, classFile = UnitClass("player")
    local u = GetUsability(classFile)
    if not (u and u.weapons and u.weapons[subclassID or -1]) then return nil end
    local data = LOF.Data and LOF.Data.StatProfiles
    local s = data and data.weaponSkills and data.weaponSkills[subclassID]
    if not s or _G.IsPlayerSpell(s.spell) then return nil end
    return s.name
end

-- v0.13.6 (E17): set further down, after GetTooltipData.
local AltClassAllowed

-- Can this class use the item type? Returns usable, level needed
-- (item level requirement or the armor type's level, the higher).
local function AltCanUse(profile, link)
    local u = GetUsability(profile.class)
    if not u then return false end
    local _, _, _, _, _, classID, subclassID = LOF.GetItemInfoInstant(link)
    local need = 1
    if classID == ARMOR_CLASS_ID then
        local lvl = u.armor and u.armor[subclassID or -1]
        if not lvl then return false end
        need = tonumber(lvl) or 1
    elseif classID == WEAPON_CLASS_ID then
        if not (u.weapons and u.weapons[subclassID or -1]) then return false end
    else
        return false
    end
    if AltClassAllowed and not AltClassAllowed(profile, link) then return false end   -- v0.13.6 (E17)
    local minLevel = tonumber(select(5, LOF.GetItemInfo(link)) or 1) or 1
    local train = classID == WEAPON_CLASS_ID and TrainingNeeded(subclassID, profile.weaponSkills) or nil   -- v0.13.19
    return true, math.max(need, minLevel), train
end

local function AltCanDualWield(profile)
    if profile.dualWield ~= nil then return profile.dualWield == true end
    local u = GetUsability(profile.class)
    local lvl = u and tonumber(u.dualWieldLevel)
    return lvl ~= nil and (tonumber(profile.level) or 1) >= lvl
end

local function AltTargets(equipLoc, canDualWield)
    if equipLoc == "INVTYPE_WEAPON" then
        return canDualWield and { 16, 17 } or { 16 }
    end
    if equipLoc == "INVTYPE_WEAPONOFFHAND" and not canDualWield then return nil end
    return SLOTS[equipLoc]
end

local PAIRS = {
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_WEAPON = { 16, 17 },
}

-- Slot -> link for an alt. Stored per slot since Holdings 0.7.0; older
-- data is placed by item type (pairs fill the first free slot).
local function BuildAltSlots(profile)
    if type(profile.equipSlots) == "table" then return profile.equipSlots end
    local slots, pending = {}, {}
    for _, e in pairs(profile.equipped or {}) do
        local link = e.l
        local equipLoc = link and select(4, LOF.GetItemInfoInstant(link))
        if equipLoc and PAIRS[equipLoc] then
            for _ = 1, math.min(tonumber(e.n) or 1, 2) do
                pending[#pending + 1] = { link = link, pair = PAIRS[equipLoc] }
            end
        elseif equipLoc and SLOTS[equipLoc] then
            slots[SLOTS[equipLoc][1]] = link
        end
    end
    for _, p in ipairs(pending) do
        if not slots[p.pair[1]] then
            slots[p.pair[1]] = p.link
        elseif not slots[p.pair[2]] then
            slots[p.pair[2]] = p.link
        end
    end
    return slots
end

-- v0.13.15 (E24): an upgrade for later only counts within this many
-- levels (data layer); further away it is no advice and no protection.
local function TooFarAhead(level, needLevel)
    if not needLevel then return false end
    local data = LOF.Data and LOF.Data.StatProfiles
    local lead = tonumber(data and data.futureUpgradeLevels) or 5
    return (tonumber(level) or 0) < (tonumber(needLevel) or 0) - lead
end

local function EvaluateForAlt(profile, link, equipLoc)
    local usable, needLevel, needTraining = AltCanUse(profile, link)   -- v0.13.19
    if not usable then return nil end
    if TooFarAhead(profile.level, needLevel) then return nil end   -- v0.13.15 (E24)
    local mix, basis, source, data = Upgrade.GetWeightMixFor(profile.class, profile.talents)
    if not mix then return nil end
    local targets = AltTargets(equipLoc, AltCanDualWield(profile))
    if not targets then return nil end

    local slots = BuildAltSlots(profile)
    -- v0.13.10 (E23): an alt saved holding a fishing pole compares with
    -- its real weapons (a copy; the stored profile is not changed).
    if IsFishingPoleLink(slots[16]) then
        local H = LOF.Resolver.Holdings
        local m, o = ResolveWeaponBase(slots[16], slots[17], profile.realWeapons, function(link)
            return H and H.CharHasInBags and H.CharHasInBags(profile.name, link) or nil
        end)
        local copy = {}
        for k, v in pairs(slots) do copy[k] = v end
        copy[16], copy[17] = m, o
        slots = copy
    end
    local function slotLink(slot) return slots[slot] end
    local best, pending
    for _, targetSlot in ipairs(targets) do
        local r = CompareToSlot(link, equipLoc, targetSlot, mix, data, slotLink)
        if r.pending then pending = true end   -- v0.13.4 (E4)
        if IsBetter(r, best) then best = r end
    end
    if not best or best.verdict ~= Upgrade.UPGRADE_CLEAR then return nil, pending end

    local level = tonumber(profile.level) or 1
    return {
        name = profile.name, class = profile.class, className = profile.className,
        level = level, needLevel = needLevel, tooLow = level < needLevel,
        needTraining = needTraining,   -- v0.13.19 (E28)
        percent = best.percent,
        emptySlot = best.equippedLink == nil and best.offHandLink == nil,
        basis = basis, source = source,
        comparison = best,
        replacesLink = best.equippedLink, replacesOffLink = best.offHandLink,
        gearUpdated = profile.updated,
    }, pending
end

-- Usable now first, then empty slots, then the largest percentage.
local function SortAlts(a, b)
    if a.tooLow ~= b.tooLow then return not a.tooLow end
    if (a.needTraining ~= nil) ~= (b.needTraining ~= nil) then return a.needTraining == nil end   -- v0.13.20
    if a.emptySlot ~= b.emptySlot then return a.emptySlot end
    local pa, pb = a.percent or 0, b.percent or 0
    if pa ~= pb then return pa > pb end
    return a.name < b.name
end

-- Every known alt for whom the item is an upgrade (caller checks that
-- the item is not bound). Returns a list, best first (may be empty).
function Upgrade.EvaluateForAlts(link, profiles)
    local list = {}
    local H = LOF.Resolver.Holdings
    if not link then return list end
    if not profiles then
        if not (H and H.GetAltGearProfiles) then return list end
        profiles = H.GetAltGearProfiles()
    end
    local itemID, _, _, equipLoc = LOF.GetItemInfoInstant(link)
    if not (equipLoc and SLOTS[equipLoc]) or IsExcludedFromAdvice(link) then return list end
    for _, profile in ipairs(profiles) do
        if Upgrade.IsAltEnabled(profile.name)                     -- v0.9.0
            and not Upgrade.IsIgnoredFor(itemID, profile.name)   -- v0.8.0
            and not IsOnOwnListOf(itemID, profile.name) then   -- v0.13.18 (E26)
            local entry, pending = EvaluateForAlt(profile, link, equipLoc)
            if entry then list[#list + 1] = entry end
            if pending then list.pending = true end   -- v0.13.4 (E4)
        end
    end
    table.sort(list, SortAlts)
    return list
end

-- v0.13.4 (E4): ask for the data of every item the alts wear, so the
-- first comparison after login already has it. Returns how many items
-- were not loaded yet (0 = everything is there).
function Upgrade.PreloadAltGear()
    if not Upgrade.IsEnabled() then return 0 end
    local H = LOF.Resolver.Holdings
    if not (H and H.GetAltGearProfiles and H.RequestItem) then return 0 end
    local missing = 0
    for _, profile in ipairs(H.GetAltGearProfiles()) do
        for _, link in pairs(BuildAltSlots(profile)) do
            if not IsLoaded(link) then
                H.RequestItem(link)
                missing = missing + 1
            end
        end
    end
    return missing
end

-- Bind type from the item data: Bind on Pickup and quest items can
-- never go to another character. Unknown (data not loaded) -> false.
local function IsTradableBindType(link)
    local bindType = select(14, LOF.GetItemInfo(link))
    if bindType == nil then return false end
    return bindType ~= BIND_ON_PICKUP and bindType ~= BIND_QUEST
end

function Upgrade.IsTradableLink(link)   -- v0.8.0
    return link ~= nil and IsTradableBindType(link)
end

-- v0.7.1: alts for a bag item, for the tooltip (cached per link).
local altTooltipCache = { version = nil, links = {} }

function Upgrade.GetBagItemAltUpgrades(bag, slot)
    if not Upgrade.IsEnabled() then return {} end
    local c = LOF.GetContainerItemInfo(bag, slot)
    local link = c and c.hyperlink
    if not link or not Upgrade.IsGearLink(link) then return {} end
    if LOF.IsBagItemBound(bag, slot) then return {} end
    if not LOF.GetItemInfo(link) then return {} end      -- data not loaded yet
    if not IsTradableBindType(link) then return {} end

    local H = LOF.Resolver.Holdings
    local version = tostring(H and H.GetDataVersion and H.GetDataVersion()) .. ":" .. Upgrade.GetIgnoreVersion()
        .. ":" .. itemData.epoch   -- v0.13.4 (E4)
    if altTooltipCache.version ~= version then
        altTooltipCache.version = version
        altTooltipCache.links = {}
    end
    local cached = altTooltipCache.links[link]
    if cached then return cached end
    local alts = Upgrade.EvaluateForAlts(link)
    altTooltipCache.links[link] = alts
    return alts
end

-- -------------------------------------------------------------
-- v0.11.0: Send to alts (mail helper)
-- -------------------------------------------------------------
local function NormName(name)
    if type(name) ~= "string" then return "" end
    name = name:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%-.*$", "")
    return name:lower()
end

-- The Send Mail form as it is now (Blizzard state, read only).
function Upgrade.GetSendMailState()
    local maxSend = tonumber(_G.ATTACHMENTS_MAX_SEND or 12) or 12
    local frame = _G.SendMailFrame
    local mailFrame = _G.MailFrame
    local state = { mailbox = false, open = false, recipient = "", attached = {}, count = 0,
                    free = nil, max = maxSend }
    state.open = (frame and frame:IsShown()) and true or false
    state.mailbox = state.open or ((mailFrame and mailFrame:IsShown()) and true or false)
    if not state.mailbox then return state end
    local box = _G.SendMailNameEditBox
    state.recipient = (box and box:GetText()) or ""
    for i = 1, maxSend do
        local name = _G.GetSendMailItem and GetSendMailItem(i)
        if name then
            state.count = state.count + 1
            local link = _G.GetSendMailItemLink and GetSendMailItemLink(i)
            if link then state.attached[link] = (state.attached[link] or 0) + 1 end
        elseif not state.free then
            state.free = i
        end
    end
    return state
end

-- What a click on this item (for altName) may do right now.
local function DecideMailAction(state, altName)
    if _G.InCombatLockdown and InCombatLockdown() then return { code = "COMBAT" } end
    if not state.mailbox then return { code = "NO_MAILBOX" } end
    if not state.free then return { code = "MAIL_FULL" } end
    local current = NormName(state.recipient)
    local target = NormName(altName)
    if current ~= "" and current ~= target and state.count > 0 then
        return { code = "OTHER_RECIPIENT", recipient = state.recipient }
    end
    return { code = "ATTACH", setRecipient = current ~= target, index = state.free,
             switchTab = not state.open }   -- v0.11.1
end

-- Re-check right before Capture acts: same item in that slot, still an
-- upgrade for this alt, and the mail form allows it.
function Upgrade.GetMailAction(bag, slot, link, altName)
    local c = LOF.GetContainerItemInfo(bag, slot)
    if not c or c.hyperlink ~= link then return { code = "MOVED" } end
    if c.isLocked then return { code = "IN_MAIL" } end
    local forAlt = false
    for _, a in ipairs(Upgrade.GetBagItemAltUpgrades(bag, slot)) do
        if a.name == altName then forAlt = true break end
    end
    if not forAlt then return { code = "MOVED" } end
    return DecideMailAction(Upgrade.GetSendMailState(), altName)
end

local function SortMailItems(a, b)
    if a.tooLow ~= b.tooLow then return not a.tooLow end
    if (a.needTraining ~= nil) ~= (b.needTraining ~= nil) then return a.needTraining == nil end   -- v0.13.20
    if a.emptySlot ~= b.emptySlot then return a.emptySlot end
    local pa, pb = a.percent or 0, b.percent or 0
    if pa ~= pb then return pa > pb end
    return tostring(a.name) < tostring(b.name)
end

-- Every bag item that is an upgrade for an alt, grouped per alt.
function Upgrade.GetAltMailSnapshot()
    local state = Upgrade.GetSendMailState()
    local snap = {
        enabled = Upgrade.IsEnabled(), groups = {}, total = 0,
        mailOpen = state.mailbox, recipient = state.recipient, attachedCount = state.count,
    }
    if not snap.enabled then return snap end
    local attachedLeft = {}
    for link, n in pairs(state.attached) do attachedLeft[link] = n end
    local byAlt = {}
    for bag = 0, LOF.GetLastBagIndex() do
        for slot = 1, LOF.GetContainerNumSlots(bag) do
            local c = LOF.GetContainerItemInfo(bag, slot)
            local alts = (c and c.hyperlink) and Upgrade.GetBagItemAltUpgrades(bag, slot) or nil
            if alts and #alts > 0 then
                local link = c.hyperlink
                local inMail = false
                if c.isLocked and (attachedLeft[link] or 0) > 0 then
                    inMail = true
                    attachedLeft[link] = attachedLeft[link] - 1
                end
                local itemName, _, quality = LOF.GetItemInfo(link)
                for _, a in ipairs(alts) do
                    local g = byAlt[a.name]
                    if not g then
                        g = { name = a.name, class = a.class, className = a.className,
                              level = a.level, items = {} }
                        byAlt[a.name] = g
                        snap.groups[#snap.groups + 1] = g
                    end
                    local action
                    if inMail then
                        action = { code = "IN_MAIL" }
                    elseif c.isLocked then
                        action = { code = "LOCKED" }
                    else
                        action = DecideMailAction(state, a.name)
                    end
                    g.items[#g.items + 1] = {
                        key = bag .. ":" .. slot .. ":" .. a.name,
                        bag = bag, slot = slot, link = link,
                        name = itemName or link, quality = quality,
                        icon = c.iconFileID, count = c.stackCount,
                        percent = a.percent, emptySlot = a.emptySlot,
                        tooLow = a.tooLow, needLevel = a.needLevel,
                        needTraining = a.needTraining,   -- v0.13.19 (E28)
                        replacesLink = a.replacesLink, replacesOffLink = a.replacesOffLink,
                        statRows = a.comparison and a.comparison.statRows or {},   -- v0.13.3
                        altName = a.name, action = action,
                    }
                    snap.total = snap.total + 1
                end
            end
        end
    end
    table.sort(snap.groups, function(a, b) return a.name < b.name end)
    for _, g in ipairs(snap.groups) do table.sort(g.items, SortMailItems) end
    return snap
end

function Upgrade.ShouldAutoOpenAltMail()
    if not Upgrade.IsAltMailAutoOpen() then return false end
    return Upgrade.GetAltMailSnapshot().total > 0
end

-- v0.10.0: upgrade info for any item tooltip (cached)
local tooltipCache = { version = nil, entries = {} }

-- v0.10.1: red lines in tooltip data: anyRed, levelOnly, needLevel.
-- v0.13.6: Lua pattern for a Blizzard format string (%d and %s captured).
local function FormatPattern(fmt)
    if type(fmt) ~= "string" or fmt == "" then return false end
    local pat = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    pat = pat:gsub("%%d", "(%%d+)")
    pat = pat:gsub("%%s", "(.+)")
    return "^" .. pat .. "$"
end

local LEVEL_PATTERN
local function GetLevelPattern()
    if LEVEL_PATTERN ~= nil then return LEVEL_PATTERN end
    LEVEL_PATTERN = FormatPattern(_G.ITEM_MIN_LEVEL)
    return LEVEL_PATTERN
end

local function RedLineInfo(data)
    if type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
    local anyRed, levelOnly, needLevel, otherRed = false, true, nil, 0
    local pattern = GetLevelPattern()
    for _, line in ipairs(data.lines) do
        for _, side in ipairs({ { line.leftText, line.leftColor }, { line.rightText, line.rightColor } }) do
            local text, c = side[1], side[2]
            if c and IsRed(c.r, c.g, c.b) then
                anyRed = true
                local lvl = pattern and type(text) == "string" and text:match(pattern)
                if lvl then
                    needLevel = tonumber(lvl)
                else
                    levelOnly = false
                    otherRed = otherRed + 1   -- v0.13.19 (E28)
                end
            end
        end
    end
    return anyRed, anyRed and levelOnly or false, needLevel, otherRed
end

local function GetTooltipData(link, bag, slot)
    local C_TooltipInfo = _G.C_TooltipInfo
    if not C_TooltipInfo then return nil end
    local ok, data
    if bag and slot and C_TooltipInfo.GetBagItem then
        ok, data = pcall(C_TooltipInfo.GetBagItem, bag, slot)
    elseif C_TooltipInfo.GetHyperlink then
        ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
    end
    return ok and data or nil
end

-- v0.13.6 (E17): classes an item is restricted to ("Classes: Druid"),
-- as a set of localized class names; false = no restriction. Only a
-- loaded item's answer is cached.
local classesCache = {}
local CLASSES_PATTERN
local function ItemAllowedClasses(link)
    if not link then return false end
    if classesCache[link] ~= nil then return classesCache[link] end
    if CLASSES_PATTERN == nil then CLASSES_PATTERN = FormatPattern(_G.ITEM_CLASSES_ALLOWED) end
    local data = CLASSES_PATTERN and GetTooltipData(link)
    if type(data) ~= "table" or type(data.lines) ~= "table" then return false end
    local allowed = false
    for _, line in ipairs(data.lines) do
        local list = type(line.leftText) == "string" and line.leftText:match(CLASSES_PATTERN)
        if list then
            allowed = {}
            for name in list:gmatch("[^,]+") do
                -- v0.13.8: drop colour codes around a class name
                name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                allowed[name:match("^%s*(.-)%s*$")] = true
            end
            break
        end
    end
    if allowed or LOF.GetItemInfo(link) then classesCache[link] = allowed end
    return allowed
end

-- v0.13.7 (E18): true when the item is Unique and you already have the
-- maximum (bags + bank via GetItemCount, or equipped).
local UNIQUE_N_PATTERN
function Upgrade.IsUniqueOwned(link)
    if not link then return false end
    local itemID = LOF.GetItemInfoInstant(link)
    if not itemID then return false end
    local CI = _G.C_Item
    local count = tonumber(CI and CI.GetItemCount and CI.GetItemCount(itemID, true)) or 0
    local equipped = CI and CI.IsEquippedItem and CI.IsEquippedItem(itemID)
    if equipped and count < 1 then count = 1 end
    if count < 1 then return false end
    local data = GetTooltipData(link)
    if type(data) ~= "table" or type(data.lines) ~= "table" then return false end
    if UNIQUE_N_PATTERN == nil then UNIQUE_N_PATTERN = FormatPattern(_G.ITEM_UNIQUE_MULTIPLE) end
    local uniqueText = _G.ITEM_UNIQUE or "Unique"
    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if text == uniqueText then return true end
        local n = UNIQUE_N_PATTERN and type(text) == "string" and tonumber(text:match(UNIQUE_N_PATTERN))
        if n then return count >= n end
    end
    return false
end

-- v0.13.8: match on the class token via the game's own male and female
-- class names (any language, gendered names such as "Druidin"). A name
-- LOF cannot map to a class means: no restriction (item stays protected).
local function ClassNameToken(name)
    for _, tbl in ipairs({ _G.LOCALIZED_CLASS_NAMES_MALE, _G.LOCALIZED_CLASS_NAMES_FEMALE }) do
        if type(tbl) == "table" then
            for token, localized in pairs(tbl) do
                if localized == name then return token end
            end
        end
    end
    return nil
end

AltClassAllowed = function(profile, link)
    local allowed = ItemAllowedClasses(link)
    if not allowed then return true end
    if profile.className and allowed[profile.className] then return true end
    for name in pairs(allowed) do
        local token = ClassNameToken(name)
        if not token then return true end          -- unknown name: fail safe
        if profile.class and token == profile.class then return true end
    end
    if not profile.class then return true end      -- alt's class unknown: fail safe
    return false
end

function Upgrade.GetTooltipInfo(link, bag, slot)
    if not link or not Upgrade.IsEnabled() or not Upgrade.IsGearLink(link) then return nil end
    if IsExcludedFromAdvice(link) then return nil end
    if not LOF.GetItemInfo(link) then return nil end   -- item data not loaded yet

    local bound = false
    if bag and slot then bound = LOF.IsBagItemBound(bag, slot) end
    local H = LOF.Resolver.Holdings
    local version = tostring(H and H.GetDataVersion and H.GetDataVersion()) .. ":"
        .. Upgrade.GetIgnoreVersion() .. ":" .. tostring(UnitLevel("player"))
        .. ":" .. itemData.epoch   -- v0.13.4 (E4)
        .. ":" .. Upgrade.GetWeaponBaseKey()   -- v0.13.10 (E23)
    if tooltipCache.version ~= version then
        tooltipCache.version = version
        tooltipCache.entries = {}
    end
    local cacheKey = link .. (bound and "|b" or "")
    local cached = tooltipCache.entries[cacheKey]
    if cached then return cached end

    local info = { alts = {} }
    local _, _, _, equipLoc = LOF.GetItemInfoInstant(link)

    -- for you (v0.10.1: a level requirement alone does not stop it)
    local anyRed, levelOnly, needLevel, otherRed = RedLineInfo(GetTooltipData(link, bag, slot))
    local targets = GetTargetSlots(equipLoc)
    -- v0.13.19 (E28): the only other red line is an untrained weapon type
    local train = anyRed and otherRed == 1 and SelfTrainingNeeded(link) or nil
    if anyRed ~= nil and (not anyRed or levelOnly or train) and targets
        and not (anyRed and TooFarAhead(UnitLevel("player"), needLevel)) then   -- v0.13.15 (E24)
        local mix, _, _, data = Upgrade.GetWeightMix()
        local best
        for _, targetSlot in ipairs(targets) do
            local r = CompareToSlot(link, equipLoc, targetSlot, mix, data)
            if IsBetter(r, best) then best = r end
        end
        -- v0.13.10 (E23): fishing without a known real weapon: say why
        local base = PlayerWeaponBase()
        local weaponSlot = false
        for _, t in ipairs(targets) do if t == 16 or t == 17 then weaponSlot = true end end
        if base and weaponSlot and base.status == "missing" then
            info.notice = "LOF: no weapon advice while fishing - a weapon you held is not in your bags."
        elseif base and weaponSlot and base.status == "unknown" then
            info.notice = "LOF: no weapon advice while fishing - equip your weapon once."
        end
        if best and best.verdict == Upgrade.UPGRADE_CLEAR then
            info.self = {
                percent = best.percent,
                emptySlot = best.equippedLink == nil and best.offHandLink == nil,
                rows = best.statRows or {},
                tooLow = needLevel ~= nil and anyRed and true or false, needLevel = needLevel,
                needTraining = train,   -- v0.13.19 (E28)
            }
        end
    end

    -- for alts (only what can still be given away)
    if not bound and IsTradableBindType(link) then
        info.alts = Upgrade.EvaluateForAlts(link)
        if not info.self and info.alts[1] then
            info.altRows = info.alts[1].comparison and info.alts[1].comparison.statRows or {}
        end
    end

    tooltipCache.entries[cacheKey] = info
    return info
end

-- -------------------------------------------------------------
-- Fill the verdict with one comparison (player or alt).
-- -------------------------------------------------------------
local function ApplyComparison(verdict, best, basis, source)
    verdict.targetSlot = best.targetSlot
    verdict.reasons = {}
    for _, r in ipairs(best.reasons or {}) do verdict.reasons[#verdict.reasons + 1] = r end
    verdict.statRows = best.statRows or {}
    verdict.percent = best.percent
    verdict.scoreNew, verdict.scoreOld = best.scoreNew, best.scoreOld

    -- What would be taken off: one item, or main hand + off-hand.
    verdict.equippedItems = {}
    for _, eLink in ipairs({ best.equippedLink, best.offHandLink }) do
        if eLink then
            local eName, _, eQuality, _, _, _, eSubType, _, eEquipLoc, eIcon = LOF.GetItemInfo(eLink)
            verdict.equippedItems[#verdict.equippedItems + 1] = {
                link = eLink, name = eName, quality = eQuality, icon = eIcon,
                subType = eSubType, equipLoc = eEquipLoc,
                effects = FilterStatEffects(GetLinkEffects(eLink), eLink),   -- v0.13.2
            }
        end
    end
    verdict.equippedLink = best.equippedLink

    -- v0.6.0: what the weighted verdict is based on
    if basis then
        verdict.reasons[#verdict.reasons + 1] = { code = "WEIGHT_BASIS", basis = basis, source = source }
        local hasEffects = #(verdict.newEffects or {}) > 0
        for _, e in ipairs(verdict.equippedItems) do
            if #(e.effects or {}) > 0 then hasEffects = true end
        end
        if hasEffects then
            verdict.reasons[#verdict.reasons + 1] = { code = "EFFECTS_NOT_COUNTED" }
        end
    end
end

-- -------------------------------------------------------------
-- Public: evaluate a bag item
-- -------------------------------------------------------------
function Upgrade.Evaluate(bag, slot)
    local c = LOF.GetContainerItemInfo(bag, slot)
    if not c or not c.hyperlink then return nil end
    local link = c.hyperlink

    local name, _, quality, _, _, _, subType, _, equipLoc, icon = LOF.GetItemInfo(link)
    if not name then return nil end   -- item data not loaded yet
    local itemID = LOF.GetItemInfoInstant(link)

    local verdict = {
        itemID = itemID, link = link, name = name, quality = quality,
        icon = icon or c.iconFileID, bag = bag, slot = slot, equipLoc = equipLoc,
        reasons = {}, alts = {},
    }

    local targets = GetTargetSlots(equipLoc)
    if not targets then
        verdict.verdict = Upgrade.NOT_USABLE   -- not a gear slot we handle
        return verdict
    end
    if IsExcludedFromAdvice(link) then
        verdict.verdict = Upgrade.EXCLUDED     -- e.g. fishing pole (data layer)
        return verdict
    end

    verdict.subType = subType
    verdict.newEffects = FilterStatEffects(GetBagItemEffects(bag, slot), link)   -- v0.13.2

    -- v0.7.0: alts, only for items that can still be given away
    if not LOF.IsBagItemBound(bag, slot) and IsTradableBindType(link) then
        verdict.alts = Upgrade.EvaluateForAlts(link)
        if verdict.alts.pending then verdict.pending = true end   -- v0.13.4 (E4)
    end

    if TooltipHasRedLine(bag, slot) then
        verdict.verdict = Upgrade.NOT_USABLE
        -- v0.10.2: only the level stops you -> remember it for later
        local anyRed, levelOnly, needLevel, otherRed = RedLineInfo(GetTooltipData(link, bag, slot))
        -- v0.13.19 (E28): or the only other red line is an untrained weapon type
        local train = anyRed and otherRed == 1 and SelfTrainingNeeded(link) or nil
        if anyRed and ((levelOnly and needLevel) or train)
            and not TooFarAhead(UnitLevel("player"), needLevel) then   -- v0.13.15 (E24)
            local mix, _, _, data = Upgrade.GetWeightMix()
            local best
            for _, targetSlot in ipairs(targets) do
                local r = CompareToSlot(link, equipLoc, targetSlot, mix, data)
                if r.pending then verdict.pending = true end   -- v0.13.4 (E4)
                if IsBetter(r, best) then best = r end
            end
            if best and best.verdict == Upgrade.UPGRADE_CLEAR then
                verdict.futureSelf = {
                    percent = best.percent, needLevel = needLevel,
                    needTraining = train,   -- v0.13.19 (E28)
                    emptySlot = best.equippedLink == nil and best.offHandLink == nil,
                }
            end
        end
    else
        -- Several possible slots (rings, trinkets, dual wield): take the
        -- most favourable comparison; empty slot wins automatically.
        local mix, basis, source, data = Upgrade.GetWeightMix()
        local best
        for _, targetSlot in ipairs(targets) do
            local r = CompareToSlot(link, equipLoc, targetSlot, mix, data)
            if r.pending then verdict.pending = true end   -- v0.13.4 (E4)
            if IsBetter(r, best) then best = r end
        end
        verdict.verdict = best.verdict
        ApplyComparison(verdict, best, mix and basis, source)

        -- Class hint from the data layer (explanation only, no decision).
        local profile, classFile, meta = GetClassProfile()
        if profile and profile.mainStat and best.delta and best.delta[profile.mainStat] then
            verdict.hint = {
                code = "MAIN_STAT", key = profile.mainStat,
                value = best.delta[profile.mainStat], class = classFile,
                confidence = meta and meta.confidence,
            }
        end
    end

    -- v0.7.0: which popup
    if verdict.verdict == Upgrade.UPGRADE_CLEAR or verdict.verdict == Upgrade.TRADE_OFF then
        verdict.popupKind = "SELF"
    elseif #verdict.alts > 0 then
        -- Only an upgrade for alts: the table compares with the best alt.
        verdict.popupKind = "ALT"
        local top = verdict.alts[1]
        ApplyComparison(verdict, top.comparison, top.basis, top.source)
        verdict.compareName = top.name
        verdict.hint = nil
    end

    return verdict
end

-- -------------------------------------------------------------
-- Public (v0.5.0): evaluate an item that is still in the loot window.
-- Returns the verdict code (UPGRADE_CLEAR / TRADE_OFF / NOT_BETTER /
-- NOT_USABLE / EXCLUDED), or nil when the Upgrade Advisor is off, the
-- item is ignored, or it is not gear.
-- -------------------------------------------------------------
local function LootSlotHasRedLine(lootSlot, link)
    local C_TooltipInfo = _G.C_TooltipInfo
    if not C_TooltipInfo then return nil end
    if C_TooltipInfo.GetLootItem then
        local ok, data = pcall(C_TooltipInfo.GetLootItem, lootSlot)
        if ok then
            local red = DataHasRedLine(data)
            if red ~= nil then return red end
        end
    end
    if C_TooltipInfo.GetHyperlink then
        local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
        if ok then return DataHasRedLine(data) end
    end
    return nil
end

function Upgrade.EvaluateLootSlot(lootSlot, link)
    if not Upgrade.IsEnabled() or not link then return nil end
    local itemID, _, _, equipLoc = LOF.GetItemInfoInstant(link)
    local targets = GetTargetSlots(equipLoc)
    if not targets then return nil end                -- not gear
    if Upgrade.IsIgnored(itemID) then return nil end
    if IsExcludedFromAdvice(link) then return Upgrade.EXCLUDED end

    local red = LootSlotHasRedLine(lootSlot, link)
    if red ~= false then return Upgrade.NOT_USABLE end  -- red, or unknown

    local mix, _, _, data = Upgrade.GetWeightMix()
    local best
    for _, targetSlot in ipairs(targets) do
        local r = CompareToSlot(link, equipLoc, targetSlot, mix, data)
        if IsBetter(r, best) then best = r end
    end
    if not best then return Upgrade.NOT_BETTER end
    return best.verdict, best.percent,                      -- v0.11.2
        best.equippedLink == nil and best.offHandLink == nil
end

-- v0.13.0: the full comparison for an item still in the loot window, in
-- the shape of Upgrade.Evaluate (for the swap popup's stat table).
function Upgrade.GetLootSlotComparison(lootSlot, link)
    if not Upgrade.IsEnabled() or not link then return nil end
    local itemID, _, _, equipLoc = LOF.GetItemInfoInstant(link)
    local targets = GetTargetSlots(equipLoc)
    if not targets or IsExcludedFromAdvice(link) then return nil end
    if LootSlotHasRedLine(lootSlot, link) ~= false then return nil end
    local mix, basis, source, data = Upgrade.GetWeightMix()
    local best
    for _, targetSlot in ipairs(targets) do
        local r = CompareToSlot(link, equipLoc, targetSlot, mix, data)
        if IsBetter(r, best) then best = r end
    end
    if not best then return nil end
    local verdict = {
        itemID = itemID, link = link, equipLoc = equipLoc,
        verdict = best.verdict, reasons = {},
        newEffects = FilterStatEffects(GetLinkEffects(link), link),   -- v0.13.2
    }
    ApplyComparison(verdict, best, mix and basis, source)
    return verdict
end

-- v0.13.1: the full comparison for an alt entry (comparison with what
-- that alt wears), for the swap popup's stat table.
function Upgrade.GetAltComparison(alt, link)
    if not alt or not alt.comparison or not link then return nil end
    local itemID, _, _, equipLoc = LOF.GetItemInfoInstant(link)
    local verdict = {
        itemID = itemID, link = link, equipLoc = equipLoc,
        verdict = alt.comparison.verdict, reasons = {},
        newEffects = FilterStatEffects(GetLinkEffects(link), link),   -- v0.13.2
        compareName = alt.name,
    }
    ApplyComparison(verdict, alt.comparison, alt.basis, alt.source)
    return verdict
end

-- v0.7.0: best alt entry for an item still in the loot window, or nil
-- (Upgrade Advisor off, ignored, not gear, Bind on Pickup, no alt).
function Upgrade.EvaluateLootSlotForAlts(lootSlot, link)
    if not Upgrade.IsEnabled() or not link then return nil end
    local itemID, _, _, equipLoc = LOF.GetItemInfoInstant(link)
    if not (equipLoc and SLOTS[equipLoc]) then return nil end
    if Upgrade.IsIgnored(itemID) then return nil end
    if not IsTradableBindType(link) then return nil end
    local alts = Upgrade.EvaluateForAlts(link)
    return alts[1]
end

-- v0.7.4: swap protection for upgrades in the bags.
function Upgrade.GetProtectionKey()
    if not Upgrade.IsEnabled() then return "off" end
    local H = LOF.Resolver.Holdings
    local gear = H and H.GetGearVersion and H.GetGearVersion() or 0
    return tostring(gear) .. ":" .. Upgrade.GetIgnoreVersion() .. ":" .. tostring(UnitLevel("player"))
        .. ":" .. itemData.epoch   -- v0.13.4 (E4)
        .. ":" .. Upgrade.GetWeaponBaseKey()   -- v0.13.10 (E23)
end

function Upgrade.IsProtectedBagItem(bag, slot)
    if not Upgrade.IsEnabled() then return false end
    local c = LOF.GetContainerItemInfo(bag, slot)
    if not c or not c.hyperlink or not Upgrade.IsGearLink(c.hyperlink) then return false end
    -- v0.13.10 (E23): while fishing, your real weapon in the bags is kept
    local base = PlayerWeaponBase()
    if base and (c.hyperlink == base[16] or c.hyperlink == base[17]) then return true end
    -- v0.13.16: real weapon unknown or gone: keep every weapon (fail safe)
    if base and base.status ~= "ok" then
        local targets = GetTargetSlots(select(4, LOF.GetItemInfoInstant(c.hyperlink)))
        for _, t in ipairs(targets or {}) do
            if t == 16 or t == 17 then return true end
        end
    end
    -- v0.12.0: protection does not depend on session / fishing
    local verdict = Upgrade.Evaluate(bag, slot)
    -- v0.13.4 (E4) fail safe: a comparison stopped on missing data -> protected
    if verdict ~= nil and verdict.pending then return true end
    if Upgrade.IsAdviceWorthy(verdict) then return true end
    -- v0.12.1: an upgrade for you once you reach its level
    return verdict ~= nil and verdict.futureSelf ~= nil and not Upgrade.IsIgnored(verdict.itemID)
end

-- Locate a (just looted) item in the bags.
function Upgrade.FindInBags(link, itemID)
    local fallbackBag, fallbackSlot
    for bag = 0, LOF.GetLastBagIndex() do
        for slot = 1, LOF.GetContainerNumSlots(bag) do
            local c = LOF.GetContainerItemInfo(bag, slot)
            if c and c.hyperlink == link then
                return bag, slot
            end
            if c and itemID and c.itemID == itemID and not fallbackBag then
                fallbackBag, fallbackSlot = bag, slot
            end
        end
    end
    return fallbackBag, fallbackSlot
end

-- Should LOF show a popup for this verdict?
-- v0.12.0: advice once per item per session (not saved)
local advisedThisSession = {}

function Upgrade.MarkAdvised(itemID)
    if itemID then advisedThisSession[itemID] = true end
end

function Upgrade.WasAdvised(itemID)
    return itemID ~= nil and advisedThisSession[itemID] == true
end

-- v0.12.0: fishing pole in the main hand (v0.13.10: IsFishingPoleLink)
function Upgrade.IsFishing()
    return IsFishingPoleLink(GetInventoryItemID("player", 16))
end

-- v0.13.11 (F17): a queued item { link, itemID, force } that is still in
-- the bags and still worth a popup -> its verdict, else nil.
function Upgrade.GetPromptVerdict(entry)
    if not entry then return nil end
    local bag, slot
    -- v0.13.14: the slot assigned by GetWaitingList, while it still holds it
    if entry.bag and entry.slot then
        local c = LOF.GetContainerItemInfo(entry.bag, entry.slot)
        if c and c.itemID == entry.itemID then bag, slot = entry.bag, entry.slot end
    end
    if not bag then bag, slot = Upgrade.FindInBags(entry.link, entry.itemID) end
    if not bag then return nil end
    local verdict = Upgrade.Evaluate(bag, slot)
    if Upgrade.ShouldPrompt(verdict, entry.force) then return verdict end
    return nil
end

-- v0.13.13 (F17): the waiting (not yet asked) queue entries for the
-- button, in the order it shows them: your own before an alt's, then the
-- largest gain (an empty slot counts as largest). Each item: { entry,
-- link, itemID, icon, quality, kind = "SELF" | "ALT", bag, slot }.
-- DEBT(dup): own bag scan next to Upgrade.FindInBags (O42)
function Upgrade.GetWaitingList(entries)
    -- v0.13.14: one bag slot per entry (exact link first, then a free
    -- slot with the same item), so identical items stay apart.
    local byLink, byID, used = {}, {}, {}
    for bag = 0, LOF.GetLastBagIndex() do
        for slot = 1, LOF.GetContainerNumSlots(bag) do
            local c = LOF.GetContainerItemInfo(bag, slot)
            if c and c.hyperlink and c.itemID then
                local key = bag .. ":" .. slot
                byLink[c.hyperlink] = byLink[c.hyperlink] or {}
                table.insert(byLink[c.hyperlink], { bag, slot, key })
                byID[c.itemID] = byID[c.itemID] or {}
                table.insert(byID[c.itemID], { bag, slot, key })
            end
        end
    end
    local function take(candidates)
        for _, s in ipairs(candidates or {}) do
            if not used[s[3]] then used[s[3]] = true return s[1], s[2] end
        end
    end
    for _, e in ipairs(entries or {}) do
        local bag, slot = take(byLink[e.link])
        if not bag then bag, slot = take(byID[e.itemID]) end
        e.bag, e.slot = bag, slot
    end

    local list = {}
    for _, e in ipairs(entries or {}) do
        if not e.asked and e.bag then
            local v = Upgrade.GetPromptVerdict(e)
            if v then
                list[#list + 1] = {
                    entry = e, link = v.link, itemID = v.itemID, icon = v.icon, quality = v.quality,
                    kind = (v.popupKind == "ALT") and "ALT" or "SELF", bag = v.bag, slot = v.slot,
                    gain = tonumber(v.percent) or math.huge,   -- empty slot
                }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.kind ~= b.kind then return a.kind == "SELF" end
        if a.gain ~= b.gain then return a.gain > b.gain end
        return tostring(a.link) < tostring(b.link)
    end)
    return list
end

-- The item is worth advice at all (also the swap protection rule).
function Upgrade.IsAdviceWorthy(verdict)
    if not verdict or not Upgrade.IsEnabled() then return false end
    if Upgrade.IsIgnored(verdict.itemID) then return false end
    return verdict.popupKind ~= nil   -- v0.7.0: SELF or ALT
end

-- A popup now? force: Scan button / level-up scan / popup parked for
-- combat (ignores "already advised this session").
function Upgrade.ShouldPrompt(verdict, force)
    if not Upgrade.IsAdviceWorthy(verdict) then return false end
    if Upgrade.IsFishing() then return false end          -- v0.12.0
    if not force and Upgrade.WasAdvised(verdict.itemID) then return false end
    return true
end

-- Gear in the bags as { [hyperlink] = count } (v0.1.1).
function Upgrade.GetBagGearSnapshot()
    local snap = {}
    for bag = 0, LOF.GetLastBagIndex() do
        for slot = 1, LOF.GetContainerNumSlots(bag) do
            local c = LOF.GetContainerItemInfo(bag, slot)
            if c and c.hyperlink and Upgrade.IsGearLink(c.hyperlink) then
                snap[c.hyperlink] = (snap[c.hyperlink] or 0) + 1
            end
        end
    end
    return snap
end

-- Links that appear more often in `after` than in `before`: new gear.
-- excludeIDs: { [itemID] = true } for items that just came from the
-- player's own equipment (unequipped / swapped out).
function Upgrade.FindNewGear(before, after, excludeIDs)
    local new = {}
    for link, count in pairs(after or {}) do
        local gained = count - ((before and before[link]) or 0)
        if gained > 0 then
            local itemID = LOF.GetItemInfoInstant(link)
            if not (excludeIDs and itemID and excludeIDs[itemID]) then
                new[#new + 1] = { link = link, itemID = itemID }
            end
        end
    end
    return new
end

-- Quick check used by Capture before queueing.
function Upgrade.IsGearLink(link)
    if not link then return false end
    local _, _, _, equipLoc = LOF.GetItemInfoInstant(link)
    return equipLoc ~= nil and SLOTS[equipLoc] ~= nil
end
