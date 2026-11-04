-- =============================================================
-- LOF (LootOptimizer Forever) -- Core.lua
-- Namespace, SavedVariables, API shims, formatting, event hub.
-- Contains NO decision logic: that lives in Resolver.lua.
-- =============================================================
--
-- Changelog
-- ---------
-- v0.3.1: LOF.IsFreshInstall(): true when LOF_DB did not exist at
--   login (first install on this account). The Guide shows How to use
--   then instead of What's new (Resolver.GetGuideTrigger).
-- v0.3.0: One money format everywhere (Peter): LOF.FormatMoney gives
--   the WoW standard "6 [s] 94 [c]" with coin icons at the height of
--   the surrounding text, no leading zeros, empty units left out
--   (like Blizzard's own money text). LOF.FormatMoneyShort (text
--   "6s 94c") is removed; all callers use LOF.FormatMoney.
-- v0.2.0: LOF 1.1.0 (Auctionator integration).
--   - DB default `settings` (useAuctionator = false, qualityModes,
--     lastAHVisit). Defaults are now also applied inside existing
--     tables, so new keys reach old SavedVariables.
--   - Shim LOF.IsBagItemBound(bag, slot): soulbound check for a bag
--     item (container info isBound, fallback C_Item.IsBound).
--   - LOF.On registers events via pcall; an unknown event is skipped
--     instead of breaking the calling file.
-- v0.1.1: GetContainerItemInfo fallback (old Classic API) now also
--   returns isLocked, like the C_Container table does.
-- v0.1.0: Initial version (LOF Lite).
--   - Single namespace table LOF; the only other global is LOF_DB.
--   - API shims pick the Mainline (C_Item / C_Container) variant when
--     present and fall back to the Classic globals otherwise.
-- =============================================================

local ADDON_NAME, ns = ...

LOF = ns
_G.LOF = ns

LOF.ADDON_NAME   = ADDON_NAME
LOF.VERSION      = "0.1.0"
LOF.VERSION_CORE = "0.3.1"

LOF.SWAP_DELAY = 0.15

-- -------------------------------------------------------------
-- SavedVariables
-- -------------------------------------------------------------
local DB_DEFAULTS = {
    whitelist  = {},   -- [itemName] = true (persistent entries only)
    collapsed  = {},   -- [sectionKey] = true
    frames     = {},   -- [frameKey] = { point, x, y }
    recentLoot = {},   -- newest first
    shown      = true,
    settings   = {     -- read and written by Resolver.Value only
        useAuctionator = false,
        qualityModes   = {},   -- [quality] = "VENDOR" | "AH" (empty = defaults)
    },
}

local function ApplyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            if type(value) == "table" then
                target[key] = {}
                ApplyDefaults(target[key], value)
            else
                target[key] = value
            end
        elseif type(value) == "table" and type(target[key]) == "table" then
            ApplyDefaults(target[key], value)
        end
    end
end

local freshInstall = false   -- v0.3.1

function LOF.InitDB()
    if type(LOF_DB) ~= "table" then
        LOF_DB = {}
        freshInstall = true
    end
    ApplyDefaults(LOF_DB, DB_DEFAULTS)
    LOF.db = LOF_DB
    return LOF.db
end

function LOF.IsFreshInstall()
    return freshInstall
end

-- -------------------------------------------------------------
-- API shims (Mainline first, Classic fallback)
-- -------------------------------------------------------------
local C_Item = _G.C_Item
local C_Container = _G.C_Container

function LOF.GetItemInfo(item)
    if not item then return nil end
    if C_Item and C_Item.GetItemInfo then
        return C_Item.GetItemInfo(item)
    end
    return _G.GetItemInfo(item)
end

function LOF.GetItemInfoInstant(item)
    if not item then return nil end
    if C_Item and C_Item.GetItemInfoInstant then
        return C_Item.GetItemInfoInstant(item)
    end
    return _G.GetItemInfoInstant(item)
end

function LOF.GetContainerNumSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag) or 0
    end
    return (_G.GetContainerNumSlots and _G.GetContainerNumSlots(bag)) or 0
end

function LOF.GetContainerNumFreeSlots(bag)
    if C_Container and C_Container.GetContainerNumFreeSlots then
        return C_Container.GetContainerNumFreeSlots(bag)
    end
    if _G.GetContainerNumFreeSlots then
        return _G.GetContainerNumFreeSlots(bag)
    end
    return 0, 0
end

-- Always returns a table { itemID, hyperlink, stackCount, iconFileID } or nil.
function LOF.GetContainerItemInfo(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        return C_Container.GetContainerItemInfo(bag, slot)
    end
    if _G.GetContainerItemInfo then
        local icon, count, locked, _, _, _, link, _, _, itemID = _G.GetContainerItemInfo(bag, slot)
        if not link then return nil end
        return { iconFileID = icon, stackCount = count, hyperlink = link, itemID = itemID, isLocked = locked }
    end
    return nil
end

-- Soulbound check for a bag item. Mainline container info has
-- isBound; otherwise ask C_Item.IsBound with an ItemLocation.
function LOF.IsBagItemBound(bag, slot)
    local c = LOF.GetContainerItemInfo(bag, slot)
    if c and c.isBound ~= nil then
        return c.isBound == true
    end
    local C_Item = _G.C_Item
    local IL = _G.ItemLocation
    if C_Item and C_Item.IsBound and IL and IL.CreateFromBagAndSlot then
        local ok, loc = pcall(IL.CreateFromBagAndSlot, IL, bag, slot)
        if ok and loc then
            local ok2, bound = pcall(C_Item.IsBound, loc)
            if ok2 then return bound == true end
        end
    end
    return false
end

-- Returns isQuestItem (boolean) for a bag slot, tolerant of both
-- the table-return (modern) and multi-return (old) variants.
function LOF.GetContainerItemQuestFlag(bag, slot)
    local fn = (C_Container and C_Container.GetContainerItemQuestInfo) or _G.GetContainerItemQuestInfo
    if not fn then return false end
    local q1, q2 = fn(bag, slot)
    if type(q1) == "table" then
        return q1.isQuestItem == true or (tonumber(q1.questID or q1.questId or 0) or 0) > 0
    end
    return q1 == true or (tonumber(q2 or 0) or 0) > 0
end

function LOF.PickupContainerItem(bag, slot)
    if C_Container and C_Container.PickupContainerItem then
        return C_Container.PickupContainerItem(bag, slot)
    end
    return _G.PickupContainerItem(bag, slot)
end

-- Highest equipped bag index (0 = backpack).
function LOF.GetLastBagIndex()
    return tonumber(_G.NUM_TOTAL_EQUIPPED_BAG_SLOTS or _G.NUM_BAG_SLOTS or 4) or 4
end

LOF.QUEST_CLASS_ID = (_G.Enum and _G.Enum.ItemClass and _G.Enum.ItemClass.Questitem)
    or _G.LE_ITEM_CLASS_QUESTITEM or 12

-- -------------------------------------------------------------
-- Formatting (pure presentation helpers, no decisions)
-- -------------------------------------------------------------
-- Size 0 = the height of the font the text is shown in, so the icons
-- fit small and large text alike (as in Blizzard's money strings).
local ICON_GOLD   = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
local ICON_SILVER = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
local ICON_COPPER = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"

-- v0.3.0: the one money format: "2 [g] 5 [c]", "6 [s] 94 [c]", "0 [c]".
-- Always the absolute amount; callers add a sign or colour themselves.
function LOF.FormatMoney(copper)
    copper = math.floor(math.abs(tonumber(copper or 0) or 0))
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. ICON_GOLD end
    if s > 0 then parts[#parts + 1] = s .. ICON_SILVER end
    if c > 0 or #parts == 0 then parts[#parts + 1] = c .. ICON_COPPER end
    return table.concat(parts, " ")
end

function LOF.GetQualityHex(quality)
    local q = tonumber(quality)
    local colors = _G.ITEM_QUALITY_COLORS
    if q and colors and colors[q] and colors[q].hex then
        return colors[q].hex
    end
    return "|cffffffff"
end

function LOF.ColorizeName(name, quality)
    return LOF.GetQualityHex(quality) .. tostring(name or "Unknown") .. "|r"
end

function LOF.Print(msg)
    print("|cff33ff99LOF:|r " .. tostring(msg))
end

-- -------------------------------------------------------------
-- Event hub: one frame, many listeners
-- -------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local listeners = {}

-- RegisterEvent is wrapped in pcall: an event this client does not
-- know must never stop the file that registers it from loading.
function LOF.On(event, fn)
    if not listeners[event] then
        local ok = pcall(eventFrame.RegisterEvent, eventFrame, event)
        if not ok then return false end
        listeners[event] = {}
    end
    table.insert(listeners[event], fn)
    return true
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = listeners[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], event, ...)
        if not ok then
            LOF.Print("|cffff5555error in " .. event .. ":|r " .. tostring(err))
        end
    end
end)

-- Modules register init callbacks; they run after SavedVariables load.
local initCallbacks = {}

function LOF.OnInit(fn)
    table.insert(initCallbacks, fn)
end

LOF.On("ADDON_LOADED", function(_, loadedName)
    if loadedName ~= ADDON_NAME then return end
    LOF.InitDB()
    for i = 1, #initCallbacks do
        local ok, err = pcall(initCallbacks[i])
        if not ok then
            LOF.Print("|cffff5555init error:|r " .. tostring(err))
        end
    end
end)
