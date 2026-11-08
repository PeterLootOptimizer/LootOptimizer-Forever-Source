-- =============================================================
-- LOF (LootOptimizer Forever) -- Resolver.lua
-- ALL intelligence lives here: item value (via Resolver.Value), swap
-- policy (quest / whitelist / no value / special bags), candidate
-- ranking, the swap decision and the dashboard snapshot.
-- UI and Capture only read from this module; they never calculate.
-- =============================================================
--
-- Changelog
-- ---------
-- v0.10.16: E15b (Peter, 5 Nov test): Recent Loot keeps 25 rows PER
--   character (max 250 for all together). The old shared limit of 25
--   let one character's loot push out another's (audit O33).
-- v0.10.15: merge for 1.6.6 (Peter, 4 Nov): Recent Loot per character
--   (0.10.13, E15) and the Unique fix (0.10.14, E18) together.
-- v0.10.14: E18 (Peter, 23 Oct; branch, after launch). GetBlockedLoot
--   leaves out a Unique item you already have (Upgrade.IsUniqueOwned):
--   the game refuses it, so a swap would delete a bag item for nothing.
--   It returns that item as a second value; BuildSwapDecision tells the
--   player once when it was the only blocked loot. (0.10.13 is the
--   Recent Loot branch; merge both after launch.)
-- v0.10.13: Recent Loot per character (Peter, 22 Oct; branch, after
--   launch). LOF_DB is account-wide, so a new alt showed the loot of
--   another character. RecordLoot stores the character key
--   (Holdings.GetCurrentCharKey, the same key as reagent choices);
--   GetRecentLootRows shows only the current character's rows. Older
--   rows without a key are no longer shown. Unknown key (character not
--   loaded yet): no rows.
-- v0.10.12: E12 fix. The client sends QUEST_FINISHED between QUEST_PROGRESS
--   and QUEST_COMPLETE, which wiped the turn-in list: slots freed by a
--   handed-in stack were never counted. ForgetQuestTurnIn now drops the
--   list only when the reward window closes, and the list counts only
--   for the same quest (GetTitleText).
-- v0.10.11: E10 fix. GetQuestRewardRoom only answers while the reward
--   window is open (QuestRewardShown at QUEST_COMPLETE, cleared by
--   ForgetQuestTurnIn at QUEST_FINISHED): the client keeps returning the
--   old reward count after the window closed (Peter, 19 Oct).
-- v0.10.10: E9 ammo protection. Ammo (item class Projectile: arrows,
--   bullets, every kind incl. Forever's own) is on the default whitelist
--   like the profession tools: never offered by Swap or Make room, also in
--   a general bag. Removing it from the whitelist is remembered per item
--   (LOF_DB.removedDefaults). The whitelist list shows the ammo the player
--   carries. Whitelisted ammo leaves the bag value / vendor total.
-- v0.10.9: E7 (Peter, 17 Oct: Westfall Stew gives 4 items, 2 slots free,
--   "Inventory is full" and Make room stayed silent because LOF saw free
--   slots). Quest reward room:
--   - Resolver.RememberQuestTurnIn() (QUEST_PROGRESS): items handed in.
--   - Resolver.GetQuestRewardRoom() (reward window open): need = fixed
--     rewards that do not fit on an existing stack + 1 for a choice;
--     free = free general slots + stacks that disappear for sure (only
--     when the bags hold exactly the handed-in amount; otherwise 0, fail
--     safe: at worst one slot too many). Returns need, free, short, text,
--     doneText. Resolver.ForgetQuestTurnIn() on QUEST_FINISHED.
--   - NewMakeRoomRound(bagsFull, forQuest): forQuest skips the "a slot is
--     free after all" check; BuildMakeRoomNowDecision adds questNote.
-- v0.10.8: Make room: cheaperItem = the cheapest item LOF may delete in a
--   HIGHER quality than the current round, when it is worth less than the
--   offered item (Peter: a grey item worth 1s 96c went first while a white
--   one worth 1s waited). Order and behaviour of Make room are unchanged;
--   the UI explains the choice.
-- v0.10.7: Setting "Not worth a swap" popup (Peter, 17 Oct; default on,
--   account-wide like Make room): Resolver.IsNotWorthPopupEnabled / Set.
--   Off: the low_value decision carries notice = one player line
--   ("LOF: not worth a swap - loot X, cheapest bag item Y") instead of the
--   popup. Nothing to swap is not affected.
-- v0.10.6: navNote for a value swap reads neutral (Peter: the old text
--   sounded like a warning while the swap was a profit; "Need more room?
--   Use Room in the Swap section first." was jargon). Same condition as
--   before: no Next because no other bag item is worth less than the loot.
--   "The only item in your bags worth less than this loot." /
--   "The last item in your bags worth less than this loot."
-- v0.10.5: ValidateSwap always returns a player text (fallback for a
--   code without its own text; release audit).
-- v0.10.4: The swap decision carries loss (bag value - loot value, never
--   below 0) for "Not worth a swap" (audit A6: the UI computed it).
-- v0.10.3: ValidateSwap also returns a player text (audit A3: Capture
--   printed the raw code, e.g. "Swap skipped (bag_item_changed)"). The
--   texts live here only (SWAP_CHECK_TEXTS); the codes stay internal.
-- v0.10.2: Fail safe (audit A1). The upgrade check on a bag item ran in
--   a pcall that swallowed errors and then treated the item as NOT
--   protected, so gear could be offered for deletion without a word.
--   Now an error keeps the item protected (EXCLUDE_UPGRADE) and prints
--   one chat line per session with the error text, for a bug report.
-- v0.10.1: Quest loot per state (Peter: Hops showed QUEST ITEM while no
--   quest of his needs it). Resolver.ResolveLootSlot reads the loot
--   window's own isQuestItem / questID / isActive (GetLootSlotInfo) next
--   to the item class: questState ACTIVE (a quest you have), STARTS
--   (the item starts a quest), NONE (quest class only; no quest of yours
--   needs it now). Fields missing (nil) -> ACTIVE (old behaviour). Still
--   a QUEST swap with the gold popup in every state; only the texts
--   differ. The texts are decided here (QUEST_TEXTS): lootItem.questTag
--   / questSub (card) and decision.questSummary { label, before, money,
--   after } (summary line); the UI only renders them.
-- v0.10.0: One Make room flow (Peter: the automatic popup could not
--   browse). Resolver.NewMakeRoomRound(bagsFull) starts every round; with
--   bagsFull (game said "Inventory is full") it returns nil when a slot
--   is free and starts at the lowest quality present. Decisions carry
--   bagsFull; nothing safe at all -> done + nothing + the old message.
--   Resolver.BuildMakeRoomDecision (the separate automatic popup) is gone.
-- v0.9.2: For swapReason GEAR_ALT the decision carries gearCompare too
--   (ResolverUpgrade 0.13.1: comparison with what the alt wears, with
--   compareName), so the swap popup shows the same table for an alt.
-- v0.9.1: Exactly one bag item qualifies (Peter: no Next, but no reason
--   either): navNote says so too. Value swap with more items in the bag
--   that hold the loot: "Only bag item worth less than the loot. Need
--   more room? Use Room in the Swap section first." Quest / gear / alt /
--   reagent: "Only item that can make room." (isOnly = true)
-- v0.9.0: Gear upgrade in the swap popup (Peter: make it stand out and
--   show where the gain comes from). For swapReason GEAR the decision
--   carries gearCompare (ResolverUpgrade 0.13.0: stat rows, effects,
--   equipped item, basis) and lootQuality (for the colours in the UI).
-- v0.8.1: Bug (Peter, found with Next): Copper Ore you need for
--   Blacksmithing showed the neutral popup with "Profit +1" while the
--   bag item was cheaper, and only the teal reagent popup after Next.
--   The swap reason checked the money before what the loot is. Order is
--   now QUEST, GEAR, GEAR_ALT, REAGENT, VALUE. Whether a swap is offered
--   does not change (same reasons), only which one the popup shows.
--   Existed since v0.6.6.
-- v0.8.0: Previous / Next in the Swap popup (Peter: skipping a bag item
--   was only possible through the whitelist). BuildSwapDecision(skip)
--   takes skip = { keys = { [slotKey] = true }, order = { slotKey, ... } }
--   (Capture keeps it per loot window). Only bag items that qualify for
--   the swap can be browsed: worth less than the loot, or any item that
--   can hold the loot when it is a quest item, a gear upgrade (you or
--   an alt) or a kept reagent. Cheapest first, skipped ones left out.
--   The decision carries total (qualifying items), canPrevious,
--   canNext, isLast and navNote ("Last item worth less than the loot..."
--   or "Last item that can make room."). Every qualifying item skipped
--   (e.g. after WL on the last one): the skips are dropped
--   (skipReset = true) so the cheapest qualifying item shows again.
--   Nothing qualifies: unchanged ("Not worth a swap" on the cheapest).
-- v0.7.0: Guide (LOF 1.6.0). Resolver.GetGuideTrigger(): which tab
--   the Guide opens by itself at login - "howto" on a first install,
--   "whatsnew" when the LOF version differs from the last one seen
--   (LOF.db.guideSeenVersion; per account) and the setting allows it,
--   otherwise nil. Resolver.MarkGuideSeen() stores the version.
--   Setting Is/SetWhatsNewEnabled (LOF.db.whatsNewOff, default on).
-- v0.6.9: Markers for items the player released from protection (Peter:
--   "say so when LOF offers it"): bag items get info.ignoredUpgrade
--   (on the Ignored upgrades list) and info.reagentOff (a profession
--   reagent on normal rules). Reagents.Evaluate runs once per slot.
--   Future upgrades for you are protected too (ResolverUpgrade 0.12.1).
-- v0.6.8: Make room now in rounds per quality (Peter): grey first, then
--   white, green, blue after a question; never epic or higher. The
--   decision is an item (with quality, position / total within the
--   quality, reagent on normal rules, or craftingReagent: the game's
--   "Crafting Reagent" flag on an item that is not in LOF's list), a
--   question (ask, nextQuality) or done. Round state stays in Capture.
-- v0.6.7: Make room now (LOF 1.6.0, Reddit request: empty your bags
--   now, one item at a time). Resolver.BuildMakeRoomNowDecision(skipped)
--   walks the same safe candidates as the Swap section (cheapest
--   first, protected items never) without needing full bags; skipped
--   = slots the player passed with Next (Resolver.GetSlotKey). The
--   decision carries position / total / isLast for "1 of 12", and
--   reagent when the item is a profession reagent on normal rules.
-- v0.6.6: Reagents in the swap (LOF 1.6.0, ResolverReagents 0.1.0).
--   - Bag items that are a kept reagent for the current character are
--     never offered for deletion: new exclusion EXCLUDE_REAGENT, label
--     "reagent" (after quest, whitelist and upgrade). The per-slot
--     cache also keys on Reagents.GetCacheKey().
--   - Blocked loot that is a kept reagent gets info.reagent and
--     isReagent; sorted after alt upgrades. Loot worth less than the
--     cheapest bag item is then still offered: swapReason REAGENT, the
--     decision carries reagent (profession, skill, useful up to).
-- v0.6.5: Disenchant value (LOF 1.5.0). BuildItemInfo carries itemLevel
--   and equipLoc (disenchant band, ResolverValue 0.2.0). Bag totals
--   count DE-valued items apart (deValue / deCount; dashboard snapshot
--   bagValueDE / bagValueDECount). Recent loot rows carry info.de.
-- v0.6.4: Make room (Peter: conjuring food / water or a quest reward
--   fails with "Inventory is full" and Swap only helps with loot).
--   Resolver.BuildMakeRoomDecision(): outside the loot window, the
--   cheapest swap candidate (same policy as the Swap section: quest
--   items, whitelist, tools, special bags and upgrades never) as
--   { kind = "ROOM", bagItem, bagValue }; hasSpace when a general slot
--   is free; message when nothing may go. ValidateMakeRoom re-checks
--   the bag slot right before the delete. Setting IsMakeRoomEnabled /
--   SetMakeRoomEnabled (LOF.db.makeRoomEnabled, default on).
-- v0.6.3: Loot that is gear for you carries gearPercent / gearEmptySlot
--   (ResolverUpgrade 0.11.2) for the swap popup label.
-- v0.6.2: Whitelist rows with the real icon, quality colour and item
--   tooltip (Peter: permanent / session entries showed a note icon).
--   Entries now keep their itemID: LOF.db.whitelist[name] = itemID
--   (was true; every check only tests that the entry exists), same for
--   the session list. AddToWhitelist looks the ID up by name; older
--   entries that still say true learn their ID the next time a scan
--   checks that item (GetWhitelistStatus with an itemID).
--   GetWhitelistRows fills itemID / quality / icon for every row; when
--   the client does not know the ID (yet) the row keeps the note icon.
-- v0.6.1: Upgrades in the bags are protected from the swap (new
--   exclusion EXCLUDE_UPGRADE, label "upgrade"): gear the Upgrade
--   Advisor would suggest for you or an alt is never offered for
--   destruction (Resolver.Upgrade.IsProtectedBagItem). Checked after
--   quest and whitelist. The per-slot cache also keys on
--   Upgrade.GetProtectionKey(), so a new piece of gear, a level-up or
--   an ignore re-checks it.
-- v0.6.0: Gear upgrade for an alt in the swap (LOF 1.3.0). Blocked
--   loot that is no upgrade for the player but is one for a known alt
--   (Resolver.Upgrade.EvaluateLootSlotForAlts: not Bind on Pickup,
--   class can use it, higher weighted score) gets info.altUpgrade and
--   isAltUpgrade. Sorted quest -> gear upgrade -> alt upgrade -> value.
--   The decision offers the swap with swapReason GEAR_ALT and carries
--   altUpgrade (name, percent, ...) for the text.
-- v0.5.0: Resolver.BuildItemInfo(link, count, isBound) is public, so
--   ResolverHoldings values stored items with exactly the same rules.
-- v0.4.9: Loot that fits on an existing, not yet full stack in the
--   bags is never "blocked": a full bag does not stop it, it is only
--   still on its way (server delay). Resolver.GetStackRoom(itemID) adds
--   up the free room on those stacks; GetBlockedLoot shares that room
--   between loot slots of the same item. Fixes the swap popup offering
--   Linen Cloth that arrived a moment later ("loot_item_changed").
--   Unknown max stack size (item data not loaded) -> no room assumed.
-- v0.4.8: Gear upgrade in the swap (LOF 1.1.2): every blocked loot
--   item gets gearVerdict from Resolver.Upgrade.EvaluateLootSlot.
--   UPGRADE_CLEAR / TRADE_OFF loot is offered like quest loot, even
--   when it is worth less than the cheapest bag item. Blocked loot is
--   sorted quest -> gear upgrade -> value. The decision carries
--   swapReason QUEST / VALUE / GEAR (UI shows text per code) and
--   isGearUpgrade.
-- v0.4.7: possibleTotal = gold + bag value (per Settings), shown as
--   "Possible total" next to the guaranteed Total (gold + vendor).
-- v0.4.6: Loot sources (LOF 1.1.1, "loot left behind" safety net):
--   Resolver.GetLootSourceGUID(lootSlot) and
--   Resolver.FindLootSlot(link, sourceGUID): find the same item from the
--   same corpse/object again after the loot window was reopened.
-- v0.4.5: GetDestroyState also returns WHY a destroy is pending:
--   "cursor" (item on the cursor, delete blocked), "dialog" (Blizzard's
--   Destroy? dialog is open) or "locked" (slot locked while the server
--   processes a delete that already happened). Capture shows the
--   destroy instructions only for cursor / dialog.
-- v0.4.4: Total is always gold + vendor (guaranteed money); the bag
--   value is a separate "possible" figure (agreed with Peter).
--   Snapshot adds bagValueGain = bag value - vendor total.
-- v0.4.3: Bag value (LOF 1.1.0): per item the value LOF uses (per the
--   Settings: AH where allowed, otherwise vendor), summed over the same
--   items as the vendor total (quest and whitelisted items excluded).
--   Snapshot: bagValue, bagValueAH/Count, bagValueVendor/Count,
--   bagValueTop (10 most valuable), bagValueMore. Total = gold + bag
--   value while the Auctionator integration is active, else gold +
--   vendor (as before).
-- v0.4.2: Recent Loot rows also carry valueEach (tooltip value line
--   shows "count x each = total").
-- v0.4.1: Resolver.GetBagSlotInfo(bag, slot): the resolved item info
--   (incl. value fields) of one slot in the player's bags, from the
--   same per-slot cache. Used by the bag tooltip line in UI.lua.
-- v0.4.0: LOF 1.1.0, Auctionator integration.
--   - Item value comes from Resolver.Value.Apply (ResolverValue.lua):
--     vendor or Auctionator price, never below vendor. info.value is
--     that effective stack value; vendorEach/vendorStack stay as-is.
--   - Soulbound: bag items via LOF.IsBagItemBound, loot / recent loot
--     via bind type (bind on pickup / quest item) -> vendor value.
--   - Policy "no vendor value" became "no value": an item without a
--     vendor price but with a usable AH price is now a swap candidate.
--   - Slot cache key includes Resolver.Value.GetCacheKey() (settings,
--     new AH data, day change).
--   - Recent Loot rows carry the value fields for the tooltip.
-- v0.3.1: Reagent bag rule corrected: it holds ANY crafting reagent
--   (verified in game with Chunk of Boar Meat + Warcraft Wiki); the
--   same-class/subclass requirement is dropped.
-- v0.3.0: Bug: the reagent bag (slot 5, reports family 0 on Forever)
--   was treated as a general bag, so LOF destroyed a reagent-bag item
--   for loot that cannot go there. Bag kinds general / reagent /
--   special; Resolver.CanHoldLoot: a reagent-bag slot only takes a
--   crafting reagent of the same class+subclass. The swap decision
--   picks the cheapest candidate whose slot can hold the loot. Free
--   slots and "bag has space" count general bags only; panel top 3
--   shows general-bag candidates.
-- v0.2.5: DoesItemExistByID is not enough on Forever (the Mainline
--   client knows TBC items the server never serves). A default tool is
--   now only listed once the client has its name; otherwise its data is
--   requested once and the list refreshes on GET_ITEM_INFO_RECEIVED.
--   Protection itself is unchanged.
-- v0.2.4: Default tools the client does not know (TBC items on Forever:
--   Jeweler's Kit, Fel Iron/Adamantite/Eternium rods) are hidden from
--   the whitelist list via C_Item.DoesItemExistByID.
-- v0.2.3: Default whitelist of profession/class tools by itemID
--   (Skinning Knife, Mining Pick, fishing poles, enchanting rods, ...).
--   Removable; removal remembered in LOF_DB.removedDefaults.
--   Whitelist API takes an optional itemID.
-- v0.2.2: BuildSwapDecision sets infoKind ("low_value" /
--   "nothing_swappable") instead of a chat message, so Capture can
--   show the info popup. nothing_swappable now includes lootItem.
-- v0.2.1: Bug: destroy was seen as "returned" while Blizzard's delete
--   dialog was open (item leaves the cursor and sits locked in its
--   slot). GetDestroyState now also returns "pending" when a DELETE_*
--   StaticPopup is visible or the bag slot item is locked.
-- v0.2.0: Two-phase swap (Mainline blocks DeleteCursorItem for addons).
--   - New Resolver.GetDestroyState(bagItem, countBefore): pending /
--     destroyed / returned, count based (an item on the cursor is not
--     counted in its bag slot on Forever).
--   - BuildSwapDecision: no swap offered while a general bag slot is
--     free (bag not full anymore, e.g. after a destroy).
-- v0.1.0: Initial version (LOF Lite).
--   - Value = vendor sell price x stack count. No auction house.
--   - Swap algorithm ported from LootOptimizer-Classic 1.8.1:
--       baseline at LOOT_OPENED, blocked loot = not yet gained,
--       quest loot first then highest value, cheapest bag
--       candidate, swap when loot is quest or loot > cheapest.
--   - New policy: items without a vendor price are never offered
--     (value unknown without AH). Items in special bags (quiver,
--     ammo, soul, profession bags) are never offered either:
--     deleting them does not free a general slot.
--   - Per-slot cache keyed on hyperlink + count + whitelist version.
-- =============================================================

local LOF = LOF
LOF.VERSION_RESOLVER = "0.10.16"

local Resolver = {}
LOF.Resolver = Resolver

-- Exclusion reasons (nil = valid swap candidate)
Resolver.EXCLUDE_QUEST       = "quest"
Resolver.EXCLUDE_WHITELIST   = "whitelist"
Resolver.EXCLUDE_NO_VENDOR   = "no_vendor_value"
Resolver.EXCLUDE_SPECIAL_BAG = "special_bag"
Resolver.EXCLUDE_LOADING     = "loading"
Resolver.EXCLUDE_UPGRADE     = "upgrade"   -- v0.6.1
Resolver.EXCLUDE_REAGENT     = "reagent"   -- v0.6.6

local EXCLUDE_ORDER = {
    whitelist = 2, quest = 3, upgrade = 4, reagent = 5, no_vendor_value = 6, special_bag = 7, loading = 8,
}

local EXCLUDE_LABEL = {
    whitelist       = "WL",
    upgrade         = "upgrade",
    reagent         = "reagent",
    quest           = "Quest",
    no_vendor_value = "no value",
    special_bag     = "special bag",
    loading         = "loading...",
}

function Resolver.GetExclusionLabel(reason)
    return EXCLUDE_LABEL[reason] or ""
end

-- -------------------------------------------------------------
-- Whitelist
--   temp       : name based, runtime only, gone after /reload
--   persistent : name based, stored in LOF_DB.whitelist
--   default    : itemID based profession/class tools (v0.2.3), on by
--                default; removing one is remembered in
--                LOF_DB.removedDefaults. ItemIDs work in every locale.
-- -------------------------------------------------------------
local tempWhitelist = {}
local whitelistVersion = 0

local DEFAULT_TOOLS = {
    -- Gathering
    [7005]  = true, -- Skinning Knife
    [2901]  = true, -- Mining Pick
    [6256]  = true, -- Fishing Pole
    [6365]  = true, -- Strong Fishing Pole
    [6366]  = true, -- Darkwood Fishing Pole
    [6367]  = true, -- Big Iron Fishing Pole
    [12225] = true, -- Blump Family Fishing Pole
    [19022] = true, -- Nat Pagle's Extreme Angler FC-5000
    [19970] = true, -- Arcanite Fishing Pole
    -- Crafting
    [5956]  = true, -- Blacksmith Hammer
    [6219]  = true, -- Arclight Spanner
    [10498] = true, -- Gyromatic Micro-Adjustor
    [6218]  = true, -- Runed Copper Rod
    [6339]  = true, -- Runed Silver Rod
    [11130] = true, -- Runed Golden Rod
    [11145] = true, -- Runed Truesilver Rod
    [16207] = true, -- Runed Arcanite Rod
    [22461] = true, -- Runed Fel Iron Rod
    [22462] = true, -- Runed Adamantite Rod
    [22463] = true, -- Runed Eternium Rod
    [20815] = true, -- Jeweler's Kit
    [4471]  = true, -- Flint and Tinder
    -- Class
    [5060]  = true, -- Thieves' Tools
}

local function GetRemovedDefaults()
    LOF.db.removedDefaults = LOF.db.removedDefaults or {}
    return LOF.db.removedDefaults
end

-- The tool list spans several game versions (e.g. TBC rods). Items the
-- running client does not know are hidden from the whitelist list.
-- Without the API (older clients) every item counts as existing.
local function ItemExistsInClient(itemID)
    local C_Item = _G.C_Item
    if C_Item and C_Item.DoesItemExistByID then
        return C_Item.DoesItemExistByID(itemID) == true
    end
    return true
end

local requestedItemData = {}

local function RequestItemData(itemID)
    if requestedItemData[itemID] then return end
    requestedItemData[itemID] = true
    local C_Item = _G.C_Item
    if C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    end
end

-- v0.10.10 (E9): ammo (arrows, bullets) is on the default whitelist
-- too, recognised by item class so every kind counts, also Forever's
-- own. GetItemInfoInstant needs no loaded item data.
local PROJECTILE_CLASS_ID = (_G.Enum and _G.Enum.ItemClass and _G.Enum.ItemClass.Projectile) or 6

local function IsAmmo(itemID)
    if not itemID then return false end
    local classID = select(6, LOF.GetItemInfoInstant(itemID))
    return classID == PROJECTILE_CLASS_ID
end

local function IsDefaultTool(itemID)
    return itemID ~= nil and (DEFAULT_TOOLS[itemID] == true or IsAmmo(itemID))
        and not GetRemovedDefaults()[itemID]
end

-- v0.6.2: itemID for a whitelist entry stored by name (nil if the
-- client does not know the name right now).
local function LookupItemID(itemName)
    if not itemName or itemName == "" then return nil end
    local itemID = LOF.GetItemInfoInstant(itemName)
    if itemID then return tonumber(itemID) end
    local _, link = LOF.GetItemInfo(itemName)
    if link then return tonumber(link:match("item:(%d+)")) end
    return nil
end

-- itemID is optional; without it default tools are not recognised.
-- v0.6.2: with an itemID, an entry that still says true learns its ID.
function Resolver.GetWhitelistStatus(itemName, itemID)
    if itemName and itemName ~= "" then
        if LOF.db and LOF.db.whitelist[itemName] then
            if itemID and LOF.db.whitelist[itemName] == true then
                LOF.db.whitelist[itemName] = tonumber(itemID) or true
            end
            return "persistent"
        end
        if tempWhitelist[itemName] then
            if itemID and tempWhitelist[itemName] == true then
                tempWhitelist[itemName] = tonumber(itemID) or true
            end
            return "temp"
        end
    end
    if LOF.db and IsDefaultTool(itemID) then return "default" end
    return nil
end

function Resolver.IsWhitelisted(itemName, itemID)
    return Resolver.GetWhitelistStatus(itemName, itemID) ~= nil
end

function Resolver.AddToWhitelist(itemName, isPersistent)
    if not itemName or itemName == "" then return false end
    local current = Resolver.GetWhitelistStatus(itemName)
    if current == "persistent" then return false end
    if current == "temp" and not isPersistent then return false end

    local entry = LookupItemID(itemName) or true   -- v0.6.2
    if isPersistent then
        tempWhitelist[itemName] = nil
        LOF.db.whitelist[itemName] = entry
        LOF.Print(itemName .. " added to whitelist (permanent).")
    else
        tempWhitelist[itemName] = entry
        LOF.Print(itemName .. " added to whitelist (this session).")
    end
    whitelistVersion = whitelistVersion + 1
    return true
end

function Resolver.RemoveFromWhitelist(itemName, itemID)
    if not Resolver.IsWhitelisted(itemName, itemID) then return false end
    if itemName then
        tempWhitelist[itemName] = nil
        LOF.db.whitelist[itemName] = nil
    end
    if IsDefaultTool(itemID) then
        GetRemovedDefaults()[itemID] = true
    end
    whitelistVersion = whitelistVersion + 1
    LOF.Print(tostring(itemName or ("item " .. tostring(itemID))) .. " removed from whitelist.")
    return true
end

-- User entries first (alphabetical), then the default tools.
-- v0.6.2: user entries carry itemID / quality / icon when known.
local function UserWhitelistRow(name, entry, status)
    local row = { name = name, status = status, order = 1 }
    local itemID = (type(entry) == "number") and entry or LookupItemID(name)
    if itemID then
        row.itemID = itemID
        local itemName, _, quality, _, _, _, _, _, _, icon = LOF.GetItemInfo(itemID)
        if itemName then
            row.quality, row.icon = quality, icon
        else
            RequestItemData(itemID)   -- GET_ITEM_INFO_RECEIVED refreshes
        end
    end
    return row
end

function Resolver.GetWhitelistRows()
    local rows = {}
    for name, entry in pairs(LOF.db.whitelist) do
        rows[#rows + 1] = UserWhitelistRow(name, entry, "persistent")
    end
    for name, entry in pairs(tempWhitelist) do
        if not LOF.db.whitelist[name] then
            rows[#rows + 1] = UserWhitelistRow(name, entry, "temp")
        end
    end
    for itemID in pairs(DEFAULT_TOOLS) do
        if IsDefaultTool(itemID) and ItemExistsInClient(itemID) then
            local name, _, quality, _, _, _, _, _, _, icon = LOF.GetItemInfo(itemID)
            if name then
                rows[#rows + 1] = {
                    name = name, itemID = itemID,
                    quality = quality, icon = icon, status = "default", order = 2,
                }
            else
                -- Ask the server; GET_ITEM_INFO_RECEIVED refreshes the list.
                -- Items the server does not have never answer: stay hidden.
                RequestItemData(itemID)
            end
        end
    end
    -- v0.10.10 (E9): ammo the player carries (all kinds would be noise)
    local seen = {}
    for _, info in ipairs((Resolver.GetBagSnapshot())) do
        local itemID = info.itemID
        if itemID and not seen[itemID] and not DEFAULT_TOOLS[itemID] and IsDefaultTool(itemID) then
            seen[itemID] = true
            rows[#rows + 1] = {
                name = info.name, itemID = itemID,
                quality = info.quality, icon = info.icon, status = "default", order = 2,
            }
        end
    end
    table.sort(rows, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.name < b.name
    end)
    return rows
end

-- -------------------------------------------------------------
-- Item resolving
-- -------------------------------------------------------------
local upgradeCheckErrorShown = false   -- v0.10.2: one chat line per session

local function IsQuestClass(itemRef)
    local _, _, _, _, _, classID = LOF.GetItemInfoInstant(itemRef)
    return classID ~= nil and classID == LOF.QUEST_CLASS_ID
end

-- Bind types that make an item unsellable on the auction house:
-- 1 = bind on pickup, 4 = quest item.
local BOUND_BIND_TYPES = { [1] = true, [4] = true }

-- Item info + value. The value rule itself lives in Resolver.Value.
-- isBound: true/false for a bag item (real soulbound state); nil for
-- loot, then the bind type decides.
local function BuildItemInfo(link, count, isBound)
    local name, _, quality, itemLevel, _, _, _, _, equipLoc, texture, sellPrice, _, _, bindType, _, _, isCraftingReagent = LOF.GetItemInfo(link)
    local itemID, _, _, _, _, classID, subclassID = LOF.GetItemInfoInstant(link)
    local qty = math.max(1, tonumber(count or 1) or 1)
    local vendorEach = tonumber(sellPrice or 0) or 0
    if isBound == nil then
        isBound = BOUND_BIND_TYPES[tonumber(bindType or 0) or 0] == true
    end

    local info = {
        itemID      = itemID,
        link        = link,
        name        = name or (itemID and ("item " .. itemID)) or "Unknown",
        icon        = texture,
        quality     = quality,
        count       = qty,
        infoReady   = name ~= nil,
        vendorEach  = vendorEach,
        vendorStack = vendorEach * qty,
        value       = vendorEach * qty,
        classID     = classID,
        subclassID  = subclassID,
        isCraftingReagent = isCraftingReagent == true,
        itemLevel   = itemLevel,   -- v0.6.5: disenchant band
        equipLoc    = equipLoc,
    }
    return Resolver.Value.Apply(info, isBound)
end

-- v0.5.0: public for ResolverHoldings (same value rules everywhere).
Resolver.BuildItemInfo = BuildItemInfo

-- Bag kinds (v0.3.0): "general" holds anything, "reagent" is the
-- reagent bag slot (reports family 0 on Forever!), "special" is a
-- family bag (quiver, soul, profession bag in a normal slot).
local function GetReagentBagIndex()
    local e = _G.Enum and _G.Enum.BagIndex
    return e and e.ReagentBag
end

function Resolver.GetBagKind(bag, family)
    local reagentIndex = GetReagentBagIndex()
    if reagentIndex and bag == reagentIndex then return "reagent" end
    if (tonumber(family or 0) or 0) ~= 0 then return "special" end
    return "general"
end

-- Can the slot freed by destroying `candidate` hold `loot`?
-- General slot: always. Reagent bag: any item the game flags as a
-- crafting reagent (tooltip "Crafting Reagent"); the bag's name
-- (Light Leather / Linen / Woolen) is only what it is made of.
-- Spell reagents are left out until confirmed on Forever.
function Resolver.CanHoldLoot(candidate, loot)
    if not candidate or not loot then return false end
    if candidate.bagKind == "general" then return true end
    if candidate.bagKind == "reagent" then
        return loot.isCraftingReagent == true
    end
    return false
end

-- isUpgrade: v0.6.1, gear the Upgrade Advisor suggests (bag items only)
-- isReagent: v0.6.6, a kept reagent (bag items only)
local function ApplyPolicy(info, isQuest, bagKind, isUpgrade, isReagent)
    info.isQuest = isQuest == true
    info.whitelistStatus = Resolver.GetWhitelistStatus(info.name, info.itemID)

    local reason
    if not info.infoReady then
        reason = Resolver.EXCLUDE_LOADING
    elseif info.isQuest then
        reason = Resolver.EXCLUDE_QUEST
    elseif info.whitelistStatus then
        reason = Resolver.EXCLUDE_WHITELIST
    elseif isUpgrade then
        reason = Resolver.EXCLUDE_UPGRADE
    elseif isReagent then
        reason = Resolver.EXCLUDE_REAGENT
    elseif bagKind == "special" then
        reason = Resolver.EXCLUDE_SPECIAL_BAG
    elseif (tonumber(info.value or 0) or 0) <= 0 then
        reason = Resolver.EXCLUDE_NO_VENDOR
    end

    info.excludeReason = reason
    info.isSwapCandidate = reason == nil
    return info
end

-- Per-slot cache
local slotCache = {}

function Resolver.InvalidateCache()
    slotCache = {}
end

local function ResolveBagSlot(bag, slot, bagFamily)
    local c = LOF.GetContainerItemInfo(bag, slot)
    if not c or not c.hyperlink then
        if slotCache[bag] then slotCache[bag][slot] = nil end
        return nil
    end

    local count = tonumber(c.stackCount or 1) or 1
    local valueKey = Resolver.Value.GetCacheKey()
    local Upgrade = Resolver.Upgrade
    local upgradeKey = Upgrade and Upgrade.GetProtectionKey and Upgrade.GetProtectionKey() or ""
    local Reagents = Resolver.Reagents
    local reagentKey = Reagents and Reagents.GetCacheKey() or ""   -- v0.6.6
    local bagCache = slotCache[bag]
    local cached = bagCache and bagCache[slot]
    if cached and cached.link == c.hyperlink and cached.count == count
        and cached.wlVersion == whitelistVersion and cached.family == bagFamily
        and cached.valueKey == valueKey and cached.upgradeKey == upgradeKey
        and cached.reagentKey == reagentKey then
        return cached.info
    end

    local info = BuildItemInfo(c.hyperlink, count, LOF.IsBagItemBound(bag, slot))
    if not info.icon then info.icon = c.iconFileID end
    info.bag = bag
    info.slot = slot
    info.bagKind = Resolver.GetBagKind(bag, bagFamily)

    local isQuest = LOF.GetContainerItemQuestFlag(bag, slot) or IsQuestClass(c.hyperlink)
    local isUpgrade = false
    if info.infoReady and Upgrade and Upgrade.IsProtectedBagItem then
        local ok, protected = pcall(Upgrade.IsProtectedBagItem, bag, slot)
        if ok then
            isUpgrade = protected == true
        else
            -- v0.10.2: fail safe - an error keeps the item protected
            isUpgrade = true
            if not upgradeCheckErrorShown then
                upgradeCheckErrorShown = true
                LOF.Print("upgrade check failed - gear kept safe. Please report: " .. tostring(protected))
            end
        end
    end
    -- v0.6.9: one reagent evaluation: kept -> protected, off -> marker
    local reagent = info.infoReady and Reagents ~= nil and Reagents.Evaluate(info.itemID) or nil
    local isReagent = reagent ~= nil and reagent.on == true
    info.reagentOff = reagent ~= nil and not reagent.on and reagent.best ~= nil
    info.ignoredUpgrade = info.infoReady and Upgrade ~= nil and Upgrade.IsIgnored ~= nil
        and Upgrade.IsIgnored(info.itemID) == true
    ApplyPolicy(info, isQuest, info.bagKind, isUpgrade, isReagent)

    if info.infoReady then
        slotCache[bag] = slotCache[bag] or {}
        slotCache[bag][slot] = {
            link = c.hyperlink, count = count, family = bagFamily,
            wlVersion = whitelistVersion, valueKey = valueKey, info = info,
            upgradeKey = upgradeKey, reagentKey = reagentKey,
        }
    end
    return info
end

-- Item info of one slot in the player's bags (0 .. last bag index);
-- nil for empty slots and for bank / other containers.
function Resolver.GetBagSlotInfo(bag, slot)
    bag, slot = tonumber(bag), tonumber(slot)
    if not bag or not slot or bag < 0 or bag > LOF.GetLastBagIndex() then return nil end
    if slot < 1 or slot > LOF.GetContainerNumSlots(bag) then return nil end
    local _, family = LOF.GetContainerNumFreeSlots(bag)
    return ResolveBagSlot(bag, slot, tonumber(family or 0) or 0)
end

local function SortRows(a, b)
    local ga = a.isSwapCandidate and 1 or (EXCLUDE_ORDER[a.excludeReason] or 9)
    local gb = b.isSwapCandidate and 1 or (EXCLUDE_ORDER[b.excludeReason] or 9)
    if ga ~= gb then return ga < gb end
    if a.value ~= b.value then return a.value < b.value end
    if a.bag ~= b.bag then return a.bag < b.bag end
    return a.slot < b.slot
end

-- Full bag scan. Returns rows (sorted: candidates cheapest first,
-- then excluded items grouped by reason) and totals.
function Resolver.GetBagSnapshot()
    local rows = {}
    local candidates = {}
    local totals = {
        vendorTotal = 0, freeSlots = 0, totalSlots = 0,
        bagValue = 0, ahValue = 0, ahCount = 0, vendorValue = 0, vendorCount = 0,
        deValue = 0, deCount = 0,
        valued = {},   -- items counted in the bag value
    }

    for bag = 0, LOF.GetLastBagIndex() do
        local numSlots = LOF.GetContainerNumSlots(bag)
        if numSlots > 0 then
            local free, family = LOF.GetContainerNumFreeSlots(bag)
            family = tonumber(family or 0) or 0
            if Resolver.GetBagKind(bag, family) == "general" then
                totals.freeSlots = totals.freeSlots + (tonumber(free or 0) or 0)
                totals.totalSlots = totals.totalSlots + numSlots
            end
            for slot = 1, numSlots do
                local info = ResolveBagSlot(bag, slot, family)
                if info then
                    rows[#rows + 1] = info
                    if info.excludeReason ~= Resolver.EXCLUDE_QUEST
                        and info.excludeReason ~= Resolver.EXCLUDE_WHITELIST then
                        totals.vendorTotal = totals.vendorTotal + info.vendorStack
                        local v = tonumber(info.value or 0) or 0
                        if v > 0 then
                            totals.bagValue = totals.bagValue + v
                            totals.valued[#totals.valued + 1] = info
                            if info.valueSource == Resolver.Value.SOURCE_AH then
                                totals.ahValue = totals.ahValue + v
                                totals.ahCount = totals.ahCount + 1
                            elseif info.valueSource == Resolver.Value.SOURCE_DE then
                                totals.deValue = totals.deValue + v
                                totals.deCount = totals.deCount + 1
                            else
                                totals.vendorValue = totals.vendorValue + v
                                totals.vendorCount = totals.vendorCount + 1
                            end
                        end
                    end
                    if info.isSwapCandidate then
                        candidates[#candidates + 1] = info
                    end
                end
            end
        end
    end

    table.sort(rows, SortRows)
    table.sort(candidates, SortRows)
    return rows, candidates, totals
end

function Resolver.GetCheapestCandidate()
    local _, candidates = Resolver.GetBagSnapshot()
    return candidates[1]
end

-- v0.6.4: Make room (bags full outside the loot window)
function Resolver.IsMakeRoomEnabled()
    return LOF.db.makeRoomEnabled ~= false
end

function Resolver.SetMakeRoomEnabled(enabled)
    LOF.db.makeRoomEnabled = enabled and true or false
end

-- v0.10.7: "Not worth a swap" popup on (default) or a short notice
function Resolver.IsNotWorthPopupEnabled()
    return LOF.db.notWorthPopupOff ~= true
end

function Resolver.SetNotWorthPopupEnabled(enabled)
    LOF.db.notWorthPopupOff = (not enabled) or nil
end

-- v0.10.0: Resolver.BuildMakeRoomDecision is gone: bags full outside the
-- loot window uses Make room now (NewMakeRoomRound(true)).

-- v0.7.0: Guide (What's new / How to use)
function Resolver.IsWhatsNewEnabled()
    return LOF.db.whatsNewOff ~= true
end

function Resolver.SetWhatsNewEnabled(enabled)
    LOF.db.whatsNewOff = (not enabled) or nil
end

function Resolver.GetGuideTrigger()
    local version = tostring(LOF.VERSION or "")
    if LOF.db.guideSeenVersion == version then return nil end
    if LOF.IsFreshInstall and LOF.IsFreshInstall() then return "howto" end
    if not Resolver.IsWhatsNewEnabled() then return nil end
    return "whatsnew"
end

function Resolver.MarkGuideSeen()
    LOF.db.guideSeenVersion = tostring(LOF.VERSION or "")
end

-- v0.6.7: Make room now. Key of one bag slot holding one item.
function Resolver.GetSlotKey(item)
    if not item then return nil end
    return tostring(item.bag) .. ":" .. tostring(item.slot) .. ":" .. tostring(item.link)
end

-- v0.6.8: Make room now in rounds per quality (grey, white, green,
-- blue; never epic or higher). round = { quality, skipped = { [slotKey]
-- = true }, seen = { [quality] = true } } (Capture keeps it).
-- Returns one of:
--   { bagItem, quality, position, total, isLast, reagent, craftingReagent }
--   { ask = true, doneQuality, nextQuality, hadAny }   next round?
--   { done = true, message }                            nothing left
local MAX_ROOM_QUALITY = 3

local function RoomQuality(item)
    return tonumber(item.quality) or 1
end

function Resolver.BuildMakeRoomNowDecision(round)
    round = round or {}
    local bagsFull = round.bagsFull == true   -- v0.10.0
    if (GetNumLootItems() or 0) > 0 then
        return { kind = "ROOMNOW", done = true, bagsFull = bagsFull, message = "Close the loot window first." }
    end
    local quality = tonumber(round.quality) or 0
    local skipped = round.skipped or {}
    local _, candidates = Resolver.GetBagSnapshot()

    local all, open = {}, {}
    local nextQuality
    for _, c in ipairs(candidates) do
        local q = RoomQuality(c)
        if q == quality then
            all[#all + 1] = c
            if not skipped[Resolver.GetSlotKey(c)] then open[#open + 1] = c end
        elseif q > quality and q <= MAX_ROOM_QUALITY and not skipped[Resolver.GetSlotKey(c)] then
            if not nextQuality or q < nextQuality then nextQuality = q end
        end
    end

    local bagItem = open[1]
    if not bagItem then
        if nextQuality then
            return { kind = "ROOMNOW", ask = true, doneQuality = quality, nextQuality = nextQuality,
                     hadAny = (round.seen and round.seen[quality]) == true, bagsFull = bagsFull }
        end
        local seenAny = false
        for _ in pairs(round.seen or {}) do seenAny = true end
        if bagsFull and not seenAny then
            return { kind = "ROOMNOW", done = true, bagsFull = true, nothing = true,
                     message = "Bags full - nothing safe to delete (quest items, whitelist, tools and upgrades are kept)." }
        end
        return { kind = "ROOMNOW", done = true, bagsFull = bagsFull, message = "Nothing more LOF may delete." }
    end

    -- v0.10.8: a cheaper item waits in a higher quality round?
    local cheaperItem
    local offered = tonumber(bagItem.value) or 0
    for _, c in ipairs(candidates) do
        local q, v = RoomQuality(c), tonumber(c.value) or 0
        if q > quality and q <= MAX_ROOM_QUALITY and v < offered
            and (not cheaperItem or v < (tonumber(cheaperItem.value) or 0)) then
            cheaperItem = c
        end
    end

    local reagent, craftingReagent
    local Reagents = Resolver.Reagents
    if Reagents then
        local r = Reagents.Evaluate(bagItem.itemID)
        if r and not r.on and r.best then reagent = r end
        craftingReagent = bagItem.isCraftingReagent == true and not Reagents.IsKnown(bagItem.itemID)
    end
    return {
        kind = "ROOMNOW",
        bagsFull = bagsFull,   -- v0.10.0: opened because the bags are full
        bagItem = bagItem,
        bagValue = bagItem.value,
        quality = quality,
        cheaperItem = cheaperItem,   -- v0.10.8
        questNote = round.forQuest and Resolver.GetQuestRewardRoom
            and (Resolver.GetQuestRewardRoom() or {}).text or nil,   -- v0.10.9 (E7)
        reagent = reagent,
        craftingReagent = craftingReagent,
        position = #all - #open + 1,
        total = #all,
        isLast = #open == 1,
    }
end

-- v0.10.0: a new Make room round. bagsFull = opened because the game
-- said "Inventory is full": nil when a general slot is free after all,
-- and the round starts at the lowest quality LOF may offer (no question
-- for empty lower qualities). Otherwise (Room button) it starts at grey.
function Resolver.NewMakeRoomRound(bagsFull, forQuest)
    local round = { quality = 0, skipped = {}, seen = {}, order = {}, bagsFull = bagsFull and true or nil,
                    forQuest = forQuest and true or nil }   -- v0.10.9 (E7)
    if bagsFull then
        local _, candidates, totals = Resolver.GetBagSnapshot()
        if (tonumber(totals.freeSlots) or 0) > 0 and not forQuest then return nil end
        local lowest
        for _, c in ipairs(candidates) do
            local q = RoomQuality(c)
            if q <= MAX_ROOM_QUALITY and (not lowest or q < lowest) then lowest = q end
        end
        if lowest then round.quality = lowest end
    end
    return round
end

function Resolver.ValidateMakeRoom(decision)
    if not decision or not decision.bagItem then return false, "missing_decision" end
    local b = decision.bagItem
    local c = LOF.GetContainerItemInfo(b.bag, b.slot)
    if not c or c.hyperlink ~= b.link or (tonumber(c.stackCount or 1) or 1) ~= b.count then
        return false, "bag_item_changed"
    end
    return true
end

function Resolver.CountItemInBags(itemID)
    if not itemID then return 0 end
    local total = 0
    for bag = 0, LOF.GetLastBagIndex() do
        for slot = 1, LOF.GetContainerNumSlots(bag) do
            local c = LOF.GetContainerItemInfo(bag, slot)
            if c and c.itemID == itemID then
                total = total + (tonumber(c.stackCount or 1) or 1)
            end
        end
    end
    return total
end

-- Free room on existing stacks of an item (v0.4.9): how many more
-- would fit without a free bag slot. 0 when the max stack size is
-- unknown or the item does not stack.
-- -------------------------------------------------------------
-- v0.10.9 (E7): room for a quest reward
-- -------------------------------------------------------------
local questTurnIn = nil   -- { [itemID] = count handed in }
-- v0.10.11 (E10): the game keeps answering GetNumQuestRewards() after the
-- quest window closed, so LOF only trusts it while the reward window is open.
local questRewardOpen = false
-- v0.10.12 (E12): the quest the turn-in list belongs to. The client sends
-- QUEST_FINISHED between QUEST_PROGRESS and QUEST_COMPLETE (Peter's event
-- log, 19 Oct), so the list may only be dropped when the reward window
-- closes, and is only used for the same quest.
local questTurnInTitle = nil

local function QuestTitle()
    local t = _G.GetTitleText and _G.GetTitleText()
    return (type(t) == "string" and t ~= "") and t or nil
end

-- QUEST_COMPLETE: the reward window is on screen.
function Resolver.QuestRewardShown()
    questRewardOpen = true
end

-- QUEST_PROGRESS ("Required items"): remember what is handed in.
function Resolver.RememberQuestTurnIn()
    local list = {}
    local n = tonumber(_G.GetNumQuestItems and _G.GetNumQuestItems() or 0) or 0
    for i = 1, n do
        local link = _G.GetQuestItemLink and _G.GetQuestItemLink("required", i)
        local itemID = link and LOF.GetItemInfoInstant(link)
        local _, _, count = _G.GetQuestItemInfo("required", i)
        if itemID then list[itemID] = (list[itemID] or 0) + (tonumber(count) or 1) end
    end
    questTurnIn = list
    questTurnInTitle = QuestTitle()   -- v0.10.12 (E12)
end

-- QUEST_FINISHED (turned in or closed): forget the turn-in and the window.
-- v0.10.12 (E12): between "Required items" and "Rewards" the reward window
-- is not open yet; keep the list then.
function Resolver.ForgetQuestTurnIn()
    if questRewardOpen then
        questTurnIn = nil
        questTurnInTitle = nil
    end
    questRewardOpen = false   -- v0.10.11 (E10)
end

-- DEBT(dup): number of stacks of an item - the same bag loop as
-- Resolver.CountItemInBags and Resolver.GetStackRoom (audit D4). Kept
-- separate on purpose before the 1.6.4 release (Peter, 17 Oct: no change
-- to the tested functions); merge in the duplicate clean-up after it.
local function CountStacksInBags(itemID)
    local stacks = 0
    for bag = 0, LOF.GetLastBagIndex() do
        for slot = 1, LOF.GetContainerNumSlots(bag) do
            local c = LOF.GetContainerItemInfo(bag, slot)
            if c and c.itemID == itemID then stacks = stacks + 1 end
        end
    end
    return stacks
end

local function SlotsText(n)
    return tostring(n) .. (n == 1 and " free slot" or " free slots")
end

-- Reward window open: how many slots the reward needs and has. nil when
-- there is no item reward.
function Resolver.GetQuestRewardRoom()
    if not questRewardOpen then return nil end   -- v0.10.11 (E10)
    local rewards = tonumber(_G.GetNumQuestRewards and _G.GetNumQuestRewards() or 0) or 0
    local choices = tonumber(_G.GetNumQuestChoices and _G.GetNumQuestChoices() or 0) or 0
    if rewards + choices <= 0 then return nil end
    local need = 0
    for i = 1, rewards do
        local link = _G.GetQuestItemLink and _G.GetQuestItemLink("reward", i)
        local itemID = link and LOF.GetItemInfoInstant(link)
        local _, _, count = _G.GetQuestItemInfo("reward", i)
        count = tonumber(count) or 1
        if not (itemID and Resolver.GetStackRoom(itemID) >= count) then need = need + 1 end
    end
    if choices > 0 then need = need + 1 end
    local freed = 0
    -- v0.10.12 (E12): only the list of this quest counts
    local turnIn = questTurnIn
    if turnIn and questTurnInTitle and QuestTitle() ~= questTurnInTitle then turnIn = nil end
    for itemID, count in pairs(turnIn or {}) do
        if Resolver.CountItemInBags(itemID) == count then freed = freed + CountStacksInBags(itemID) end
    end
    local _, _, totals = Resolver.GetBagSnapshot()
    local free = (tonumber(totals.freeSlots) or 0) + freed
    return {
        need = need, free = free, short = math.max(0, need - free),
        text = "Quest reward needs " .. SlotsText(need) .. " \226\128\147 you have " .. tostring(free) .. ".",
        doneText = "Enough room for the quest reward.",
    }
end

function Resolver.GetStackRoom(itemID)
    if not itemID then return 0 end
    local maxStack = tonumber((select(8, LOF.GetItemInfo(itemID)))) or 0
    if maxStack <= 1 then return 0 end
    local room = 0
    for bag = 0, LOF.GetLastBagIndex() do
        for slot = 1, LOF.GetContainerNumSlots(bag) do
            local c = LOF.GetContainerItemInfo(bag, slot)
            if c and c.itemID == itemID then
                room = room + math.max(0, maxStack - (tonumber(c.stackCount or 1) or 1))
            end
        end
    end
    return room
end

-- -------------------------------------------------------------
-- Loot window
-- -------------------------------------------------------------
local function GetLootItemLink(lootSlot)
    if not LootSlotHasItem(lootSlot) then return nil end
    local link = GetLootSlotLink(lootSlot)
    if not link or not string.find(link, "item:", 1, true) then
        return nil  -- money or currency
    end
    return link
end

-- GUID of the corpse/object a loot slot comes from (first source).
function Resolver.GetLootSourceGUID(lootSlot)
    if not GetLootSourceInfo or not lootSlot then return nil end
    local ok, guid = pcall(GetLootSourceInfo, lootSlot)
    if ok then return guid end
    return nil
end

-- Loot slot holding `link` from the source `sourceGUID` (any source
-- when sourceGUID is nil). Same item = same link, or same itemID.
function Resolver.FindLootSlot(link, sourceGUID)
    if not link then return nil end
    local wantID = LOF.GetItemInfoInstant(link)
    for lootSlot = 1, (GetNumLootItems() or 0) do
        local l = GetLootItemLink(lootSlot)
        if l and (l == link or (wantID and LOF.GetItemInfoInstant(l) == wantID)) then
            if not sourceGUID then return lootSlot end
            local sources = { pcall(GetLootSourceInfo, lootSlot) }
            -- sources[1] is pcall's ok flag; then guid, quantity, guid, ...
            for i = 2, #sources, 2 do
                if sources[i] == sourceGUID then return lootSlot end
            end
        end
    end
    return nil
end

-- v0.10.1: quest loot texts per state - the only place they are decided.
local QUEST_TEXTS = {
    ACTIVE = { tag = "Quest", sub = "Quest item",
               label = "Quest item", before = " - worth more than ", after = " to you", money = true },
    STARTS = { tag = "Quest", sub = "Starts a quest",
               label = "Starts a quest", before = " - worth more than ", after = " to you", money = true },
    NONE   = { tag = "Quest", sub = "Quest item - no quest of yours",
               label = "Quest item", before = " - no quest of yours needs it now (maybe later)" },
}

-- v0.10.1: quest state of a loot slot (nil = not a quest item).
-- The loot window knows best: isQuestItem / questID / isActive. The item
-- class (12) alone only means "made for a quest".
local function ResolveLootQuestState(lootSlot, link)
    local _, _, _, _, _, _, isQuestItem, questID, isActive = GetLootSlotInfo(lootSlot)
    questID = tonumber(questID)
    if questID and questID > 0 and not isActive then
        return "STARTS"
    end
    if isQuestItem then
        return "ACTIVE"
    end
    if IsQuestClass(link) then
        -- fields missing on this client: keep the old behaviour
        if isQuestItem == nil and isActive == nil then return "ACTIVE" end
        return "NONE"
    end
    return nil
end

function Resolver.ResolveLootSlot(lootSlot)
    local link = GetLootSlotLink and GetLootItemLink(lootSlot)
    if not link then return nil end
    local _, _, quantity = GetLootSlotInfo(lootSlot)
    local info = BuildItemInfo(link, quantity)
    info.lootSlot = lootSlot
    info.questState = ResolveLootQuestState(lootSlot, link)   -- v0.10.1
    info.isQuest = info.questState ~= nil
    local qt = info.questState and QUEST_TEXTS[info.questState]
    info.questTag = qt and qt.tag or nil
    info.questSub = qt and qt.sub or nil
    return info
end

-- Baseline: how many of each loot item were already in the bags
-- when the loot window opened.
local lootBaseline = nil

function Resolver.CaptureLootBaseline()
    lootBaseline = {}
    for lootSlot = 1, (GetNumLootItems() or 0) do
        local link = GetLootItemLink(lootSlot)
        if link then
            local itemID = LOF.GetItemInfoInstant(link)
            if itemID and lootBaseline[itemID] == nil then
                lootBaseline[itemID] = Resolver.CountItemInBags(itemID)
            end
        end
    end
end

function Resolver.ClearLootBaseline()
    lootBaseline = nil
end

function Resolver.GetLootBaseline(itemID)
    return tonumber(lootBaseline and itemID and lootBaseline[itemID] or 0) or 0
end

-- Loot items that did not make it into the bags yet.
-- Sorted: quest items first, then highest value.
function Resolver.GetBlockedLoot()
    local blocked = {}
    local consumedByItem = {}
    local roomLeft = {}   -- v0.4.9: free stack room per itemID, shared

    local uniqueOwned   -- v0.10.14 (E18)
    local U = Resolver.Upgrade
    for lootSlot = 1, (GetNumLootItems() or 0) do
        local info = Resolver.ResolveLootSlot(lootSlot)
        if info and info.itemID and U and U.IsUniqueOwned and U.IsUniqueOwned(info.link) then
            uniqueOwned = uniqueOwned or info
        elseif info and info.itemID then
            local gained = math.max(0, Resolver.CountItemInBags(info.itemID) - Resolver.GetLootBaseline(info.itemID))
            local consumed = consumedByItem[info.itemID] or 0
            local resolved = math.min(info.count, math.max(0, gained - consumed))
            consumedByItem[info.itemID] = consumed + resolved

            -- v0.4.9: the rest fits on an existing stack -> not blocked,
            -- only still on its way.
            local remaining = info.count - resolved
            if remaining > 0 then
                if roomLeft[info.itemID] == nil then
                    roomLeft[info.itemID] = Resolver.GetStackRoom(info.itemID)
                end
                if remaining <= roomLeft[info.itemID] then
                    roomLeft[info.itemID] = roomLeft[info.itemID] - remaining
                    resolved = info.count
                end
            end

            if resolved < info.count then
                local verdict, pct, empty
                if Resolver.Upgrade then
                    verdict, pct, empty = Resolver.Upgrade.EvaluateLootSlot(lootSlot, info.link)
                end
                info.gearVerdict = verdict
                info.gearPercent, info.gearEmptySlot = pct, empty   -- v0.6.3
                info.isGearUpgrade = verdict == "UPGRADE_CLEAR" or verdict == "TRADE_OFF"
                -- v0.6.0: no upgrade for you, maybe for an alt
                if not info.isGearUpgrade and Resolver.Upgrade and Resolver.Upgrade.EvaluateLootSlotForAlts then
                    info.altUpgrade = Resolver.Upgrade.EvaluateLootSlotForAlts(lootSlot, info.link)
                end
                info.isAltUpgrade = info.altUpgrade ~= nil
                -- v0.6.6: a profession material this character keeps
                local Reagents = Resolver.Reagents
                local reagent = Reagents and Reagents.Evaluate(info.itemID)
                info.reagent = (reagent and reagent.on) and reagent or nil
                info.isReagent = info.reagent ~= nil
                blocked[#blocked + 1] = info
            end
        end
    end

    table.sort(blocked, function(a, b)
        if a.isQuest ~= b.isQuest then return a.isQuest end
        if a.isGearUpgrade ~= b.isGearUpgrade then return a.isGearUpgrade end
        if a.isAltUpgrade ~= b.isAltUpgrade then return a.isAltUpgrade end
        if a.isReagent ~= b.isReagent then return a.isReagent end
        if a.value ~= b.value then return a.value > b.value end
        return a.lootSlot < b.lootSlot
    end)
    return blocked, uniqueOwned
end

-- The swap decision. The only place that decides whether to offer a swap.
-- v0.8.0: does this bag item qualify for a swap with this loot? The
-- reasons that do not depend on the bag item's value (quest, gear for
-- you or an alt, kept reagent) make every holding item qualify.
local function QualifiesForSwap(candidate, lootItem)
    if lootItem.isQuest or lootItem.isGearUpgrade or lootItem.isAltUpgrade or lootItem.isReagent then
        return true
    end
    return (tonumber(lootItem.value) or 0) > (tonumber(candidate.value) or 0)
end

function Resolver.BuildSwapDecision(skip)
    if (GetNumLootItems() or 0) <= 0 then
        return { shouldShowPopup = false, stopReason = "lootwindow_closed" }
    end

    local blocked, uniqueOwned = Resolver.GetBlockedLoot()
    if #blocked == 0 then
        if uniqueOwned then   -- v0.10.14 (E18)
            return {
                shouldShowPopup = false, stopReason = "unique_owned",
                message = "You already have " .. tostring(uniqueOwned.name or "this item")
                    .. " (Unique): the game will not let you loot a second one.",
            }
        end
        return { shouldShowPopup = false, stopReason = "no_blocked_loot" }
    end

    -- A free general slot means the bag is not full (anymore): the
    -- player can simply loot. Never offer a destroy in that case.
    local _, candidates, totals = Resolver.GetBagSnapshot()
    if totals.freeSlots > 0 then
        return {
            shouldShowPopup = false, stopReason = "bag_has_space",
            message = "Bag has free space: click the loot to pick it up.",
        }
    end

    local lootItem = blocked[1]
    local bagItem
    -- v0.8.0: qualifying items (cheapest first) and those not skipped
    local skipKeys = (skip and skip.keys) or {}
    local qualifying, open = {}, {}
    local holdable = 0   -- v0.9.1
    for _, candidate in ipairs(candidates) do
        if Resolver.CanHoldLoot(candidate, lootItem) then
            holdable = holdable + 1
            bagItem = bagItem or candidate
            if QualifiesForSwap(candidate, lootItem) then
                qualifying[#qualifying + 1] = candidate
                if not skipKeys[Resolver.GetSlotKey(candidate)] then
                    open[#open + 1] = candidate
                end
            end
        end
    end
    local skipReset = false
    if #open == 0 and #qualifying > 0 then
        open, skipReset = qualifying, true
    end
    if open[1] then bagItem = open[1] end
    if not bagItem then
        return {
            shouldShowPopup = false, stopReason = "no_valid_bag_item",
            infoKind = "nothing_swappable",
            lootItem = lootItem,
        }
    end

    -- Why a swap is offered: quest item, better gear (you / an alt), a
    -- profession material you keep (v0.6.6), or more money. v0.8.1: what
    -- the loot IS goes before the money, so the popup does not depend on
    -- which bag item happens to be shown.
    local swapReason
    if lootItem.isQuest then
        swapReason = "QUEST"
    elseif lootItem.isGearUpgrade then
        swapReason = "GEAR"
    elseif lootItem.isAltUpgrade then
        swapReason = "GEAR_ALT"
    elseif lootItem.isReagent then
        swapReason = "REAGENT"
    elseif lootItem.value > bagItem.value then
        swapReason = "VALUE"
    end
    local shouldSwap = swapReason ~= nil

    -- v0.8.0: browsing (only with more than one qualifying item)
    local total = #qualifying
    local canPrevious = (not skipReset) and skip ~= nil and skip.order ~= nil and #skip.order > 0
    local canNext = #open > 1
    local isLast = shouldSwap and total > 1 and #open == 1
    local isOnly = shouldSwap and total == 1   -- v0.9.1
    local valueOnly = not (lootItem.isQuest or lootItem.isGearUpgrade
        or lootItem.isAltUpgrade or lootItem.isReagent)
    local navNote
    if isLast then
        if valueOnly then
            navNote = "The last item in your bags worth less than this loot."
        else
            navNote = "Last item that can make room."
        end
    elseif isOnly then
        if valueOnly then
            if holdable > 1 then
                navNote = "The only item in your bags worth less than this loot."
            end
        else
            navNote = "Only item that can make room."
        end
    end

    -- v0.9.0: the full comparison for a gear upgrade for you
    local gearCompare
    if swapReason == "GEAR" and Resolver.Upgrade and Resolver.Upgrade.GetLootSlotComparison then
        gearCompare = Resolver.Upgrade.GetLootSlotComparison(lootItem.lootSlot, lootItem.link)
    elseif swapReason == "GEAR_ALT" and Resolver.Upgrade and Resolver.Upgrade.GetAltComparison then
        gearCompare = Resolver.Upgrade.GetAltComparison(lootItem.altUpgrade, lootItem.link)   -- v0.9.2
    end

    -- v0.10.1: the quest summary line (texts per quest state)
    local questSummary
    local qt = lootItem.questState and QUEST_TEXTS[lootItem.questState]
    if qt then
        questSummary = { label = qt.label, before = qt.before,
            money = qt.money and bagItem.value or nil, after = qt.after }
    end

    return {
        questSummary    = questSummary,  -- v0.10.1
        gearCompare     = gearCompare,   -- v0.9.0
        lootQuality     = lootItem.quality,
        total           = total,         -- v0.8.0
        canPrevious     = canPrevious,
        canNext         = canNext,
        isLast          = isLast,
        isOnly          = isOnly,        -- v0.9.1
        navNote         = navNote,
        skipReset       = skipReset,
        shouldShowPopup = shouldSwap,
        stopReason      = (not shouldSwap) and "only_low_value_loot" or nil,
        infoKind        = (not shouldSwap) and "low_value" or nil,
        -- v0.10.7: popup switched off -> one line instead (Capture shows it)
        notice          = ((not shouldSwap) and not Resolver.IsNotWorthPopupEnabled())
            and ("LOF: not worth a swap - loot " .. LOF.FormatMoney(lootItem.value)
                .. ", cheapest bag item " .. LOF.FormatMoney(bagItem.value)) or nil,
        lootItem        = lootItem,
        bagItem         = bagItem,
        lootValue       = lootItem.value,
        bagValue        = bagItem.value,
        profit          = lootItem.value - bagItem.value,
        loss            = math.max(0, bagItem.value - lootItem.value),   -- v0.10.4
        isQuest         = lootItem.isQuest,
        isGearUpgrade   = lootItem.isGearUpgrade == true,
        gearVerdict     = lootItem.gearVerdict,
        swapReason      = swapReason,
        altUpgrade      = lootItem.altUpgrade,
        reagent         = lootItem.reagent,   -- v0.6.6
    }
end

-- Safety check right before deleting: the bag slot must still hold
-- exactly the item the user agreed to delete, and the loot slot
-- must still hold the loot item.
-- v0.10.3: player text per failed check (the codes stay internal)
local SWAP_CHECK_TEXTS = {
    missing_decision  = "Nothing to swap any more - checking again.",
    bag_item_changed  = "Your bags changed - checking again.",
    loot_item_changed = "The loot changed - checking again.",
}

-- Returns ok, reasonCode, playerText.
function Resolver.ValidateSwap(decision)
    local reason
    if not decision or not decision.bagItem or not decision.lootItem then
        reason = "missing_decision"
    else
        local b = decision.bagItem
        local c = LOF.GetContainerItemInfo(b.bag, b.slot)
        if not c or c.hyperlink ~= b.link or (tonumber(c.stackCount or 1) or 1) ~= b.count then
            reason = "bag_item_changed"
        elseif GetLootItemLink(decision.lootItem.lootSlot) ~= decision.lootItem.link then
            reason = "loot_item_changed"
        end
    end
    if reason then
        return false, reason, SWAP_CHECK_TEXTS[reason] or "Something changed - checking again."
    end
    return true
end

-- Destroy tracking (v0.2.0). Addons may not delete items on Mainline,
-- so the player destroys the item via Blizzard's own dialog. This
-- decides what happened to the item that LOF put on the cursor:
--   "pending"   : still on the cursor (dialog may be open)
--   "destroyed" : cursor empty and one fewer stack of it in the bags
--   "returned"  : cursor empty and the item is back in the bags
-- countBefore = Resolver.CountItemInBags(itemID) taken before pickup.
-- An item on the cursor does not count as "in the bags" on Forever,
-- so the check is count based rather than slot based.
local DELETE_POPUPS = { "DELETE_ITEM", "DELETE_GOOD_ITEM", "DELETE_QUEST_ITEM", "DELETE_GOOD_QUEST_ITEM" }

local function IsDeleteDialogOpen()
    if not StaticPopup_Visible then return false end
    for _, which in ipairs(DELETE_POPUPS) do
        if StaticPopup_Visible(which) then return true end
    end
    return false
end

function Resolver.GetDestroyState(bagItem, countBefore)
    if CursorHasItem() then
        return "pending", "cursor"
    end
    -- While Blizzard's "Destroy?" dialog is open the item leaves the
    -- cursor and sits locked in its bag slot until the player decides.
    if IsDeleteDialogOpen() then
        return "pending", "dialog"
    end
    -- Locked without cursor or dialog: the delete was sent and the
    -- server has not confirmed it yet.
    local c = LOF.GetContainerItemInfo(bagItem.bag, bagItem.slot)
    if c and c.isLocked and c.hyperlink == bagItem.link then
        return "pending", "locked"
    end
    local countNow = Resolver.CountItemInBags(bagItem.itemID)
    if countNow <= (tonumber(countBefore or 0) or 0) - bagItem.count then
        return "destroyed"
    end
    return "returned"
end

-- -------------------------------------------------------------
-- Session money + recent loot
-- -------------------------------------------------------------
local sessionStartMoney = nil

function Resolver.InitSessionMoney()
    if sessionStartMoney == nil then
        sessionStartMoney = GetMoney() or 0
    end
end

local RECENT_LOOT_KEEP = 25        -- per character (v0.10.16)
local RECENT_LOOT_MAX_ALL = 250    -- all characters together (v0.10.16)

function Resolver.RecordLoot(link, count)
    if not link then return end
    local info = BuildItemInfo(link, count)
    local H = Resolver.Holdings
    table.insert(LOF.db.recentLoot, 1, {
        itemID = info.itemID, link = link, name = info.name,
        icon = info.icon, quality = info.quality, count = info.count,
        time = time(),
        char = H and H.GetCurrentCharKey and H.GetCurrentCharKey() or nil,  -- v0.10.13
    })
    -- v0.10.16: trim per character (newest first), so one character's
    -- loot never pushes out another's; rows without a key count as one group.
    local list, perChar = LOF.db.recentLoot, {}
    for i = #list, 1, -1 do
        local k = tostring(list[i].char)
        perChar[k] = (perChar[k] or 0) + 1
    end
    for i = #list, 1, -1 do
        local k = tostring(list[i].char)
        if perChar[k] > RECENT_LOOT_KEEP or #list > RECENT_LOOT_MAX_ALL then
            perChar[k] = perChar[k] - 1
            table.remove(list, i)
        end
    end
end

function Resolver.GetRecentLootRows(limit)
    local rows = {}
    -- v0.10.13: only the current character's loot (no key yet: no rows).
    local H = Resolver.Holdings
    local charKey = H and H.GetCurrentCharKey and H.GetCurrentCharKey()
    if not charKey then return rows end
    for _, r in ipairs(LOF.db.recentLoot) do
        if #rows >= (limit or 3) then break end
        if r.char == charKey then
            -- Re-resolve value: item info may not have been cached at loot time.
            local info = BuildItemInfo(r.link, r.count)
            rows[#rows + 1] = {
                link = r.link, count = r.count,
                name = info.infoReady and info.name or r.name,
                icon = info.icon or r.icon,
                quality = info.quality or r.quality,
                value = info.value,
                hasValue = info.value > 0,
                -- value fields for the tooltip
                vendorEach = info.vendorEach, ahEach = info.ahEach, valueEach = info.valueEach,
                ahAgeDays = info.ahAgeDays, freshness = info.freshness,
                valueSource = info.valueSource, valueReason = info.valueReason,
                de = info.de,
            }
        end
    end
    return rows
end

-- -------------------------------------------------------------
-- Dashboard snapshot: the single dataset the UI renders from
-- -------------------------------------------------------------
function Resolver.GetDashboardSnapshot()
    local rows, candidates, totals = Resolver.GetBagSnapshot()
    local money = GetMoney() or 0

    -- Top 3 for the panel: general bags only (a reagent-bag item can
    -- only make room for a matching reagent, so it is not the default).
    local swapTop = {}
    for _, c in ipairs(candidates) do
        if c.bagKind == "general" then
            swapTop[#swapTop + 1] = c
            if #swapTop == 3 then break end
        end
    end

    -- Bag value breakdown: the 10 most valuable items.
    local BAG_VALUE_TOP = 10
    local valued = totals.valued
    table.sort(valued, function(a, b)
        if a.value ~= b.value then return a.value > b.value end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)
    local bagValueTop = {}
    for i = 1, math.min(BAG_VALUE_TOP, #valued) do
        bagValueTop[i] = valued[i]
    end

    local valueActive = Resolver.Value.IsActive()

    return {
        money          = money,
        vendorTotal    = totals.vendorTotal,
        bagValue       = totals.bagValue,
        bagValueAH     = totals.ahValue,
        bagValueAHCount     = totals.ahCount,
        bagValueVendor      = totals.vendorValue,
        bagValueVendorCount = totals.vendorCount,
        bagValueDE          = totals.deValue,
        bagValueDECount     = totals.deCount,
        bagValueTop    = bagValueTop,
        bagValueMore   = math.max(0, #valued - #bagValueTop),
        bagValueGain   = totals.bagValue - totals.vendorTotal,
        possibleTotal  = money + totals.bagValue,        -- gold + bag value
        total          = money + totals.vendorTotal,   -- guaranteed money
        sessionDelta   = money - (sessionStartMoney or money),
        freeSlots      = totals.freeSlots,
        totalSlots     = totals.totalSlots,
        swapTop        = swapTop,
        candidateCount = #candidates,
        allRows        = rows,
        recentLoot     = Resolver.GetRecentLootRows(3),
        valueActive    = valueActive,
    }
end
