-- =============================================================
-- LOF (LootOptimizer Forever) -- ResolverReagents.lua
-- Resolver layer, Reagents domain (LOF.Resolver.Reagents): is an item
-- a profession material the current character still needs? Decides
-- which reagents are "kept" (offered in the swap, never offered for
-- deletion) and builds the snapshot for the Reagents window.
-- Reference data: Data/ProfessionReagents.lua. UI only renders.
-- =============================================================
--
-- Changelog
-- ---------
-- v0.1.3: Reagents.ForgetCharacter(charKey) (Holdings 0.11.0): drops
--   that character's reagent choices.
-- v0.1.2: Window rows carry rangeState (Peter: on skill 77 every range
--   was green): "now" (skill within lowest .. useful-to), "later"
--   (skill below the lowest recipe) or "past" (no more skill). Sorted
--   now -> later -> past. What is kept does not change.
-- v0.1.1: Reagents.IsKnown(itemID): the item is in the reagent data
--   (Make room now: a "Crafting Reagent" that is not, gets a grey line).
-- v0.1.0: Initial version (LOF 1.6.0, Peter: Rough Stone was "Not
--   worth a swap" while he levels Blacksmithing).
--   - Kept ("on") per item, current character only:
--       1. the player's own choice always wins (Reagents window, or
--          All Items: click a kept reagent to stop keeping it);
--       2. otherwise: one of the character's professions uses the item
--          and its skill is below the recipe range's highest + margin
--          (unknown highest: always). Several professions: one is
--          enough.
--     Items that are not in the data have no reagent rule.
--   - Setting "Offer reagents for a swap" (LOF.db.reagentsEnabled,
--     default on). Off: no reagent rule at all (no teal popup, no
--     protection).
--   - Choices: LOF.db.reagentChoices[charKey][itemID] = true / false;
--     a choice equal to the default is not stored (back to automatic).
--   - GetCacheKey() for the per-slot cache in Resolver.lua: changes
--     with the setting, a choice, or the character's professions and
--     skill levels.
-- =============================================================

local LOF = LOF
LOF.VERSION_RESOLVER_REAGENTS = "0.1.3"

local Resolver = LOF.Resolver
local Reagents = {}
Resolver.Reagents = Reagents

local choiceVersion = 0

local function Data()
    return LOF.Data.ProfessionReagents
end

local function Holdings()
    return Resolver.Holdings
end

-- -------------------------------------------------------------
-- Setting
-- -------------------------------------------------------------
function Reagents.IsEnabled()
    return LOF.db.reagentsEnabled ~= false
end

function Reagents.SetEnabled(enabled)
    LOF.db.reagentsEnabled = enabled and true or false
    choiceVersion = choiceVersion + 1
end

-- -------------------------------------------------------------
-- Current character: professions known to the data (memo by the
-- Holdings data version, which changes after every scan).
-- -------------------------------------------------------------
local stateMemo, stateVersion

local function GetState()
    local H = Holdings()
    local v = H and H.GetDataVersion and H.GetDataVersion() or 0
    if stateMemo and stateVersion == v then return stateMemo end

    local profs, sig = {}, {}
    local list = (H and H.GetCurrentProfessions) and H.GetCurrentProfessions() or {}
    for _, def in ipairs(Data().professions) do
        for _, p in ipairs(list) do
            if (p.skillLine and p.skillLine == def.skillLine) or p.name == def.name then
                local level = tonumber(p.level) or 0
                profs[#profs + 1] = {
                    key = def.key, skillLine = def.skillLine,
                    name = p.name or def.name, level = level, max = tonumber(p.max),
                }
                sig[#sig + 1] = def.key .. level
                break
            end
        end
    end
    stateMemo = { profs = profs, sig = table.concat(sig, ",") }
    stateVersion = v
    return stateMemo
end

local function GetChoices(create)
    local H = Holdings()
    local key = H and H.GetCurrentCharKey and H.GetCurrentCharKey()
    if not key then return nil end
    LOF.db.reagentChoices = LOF.db.reagentChoices or {}
    local t = LOF.db.reagentChoices[key]
    if not t and create then
        t = {}
        LOF.db.reagentChoices[key] = t
    end
    return t
end

function Reagents.GetCacheKey()
    if not Reagents.IsEnabled() then return "off" end
    return tostring(choiceVersion) .. ":" .. GetState().sig
end

-- -------------------------------------------------------------
-- Evaluation
-- -------------------------------------------------------------
-- One profession's use of an item: range and whether it is useful now.
local function BuildMatch(p, range, margin)
    local lowest = tonumber(range[1]) or 1
    local highest = tonumber(range[2])
    local usefulTo = highest and (highest + margin) or nil
    return {
        key = p.key, name = p.name, level = p.level,
        lowest = lowest, highest = highest, usefulTo = usefulTo,
        useful = usefulTo == nil or p.level < usefulTo,
    }
end

local function Matches(entry, state)
    local margin = tonumber(Data().margin) or 0
    local list, anyUseful = {}, false
    for _, p in ipairs(state.profs) do
        local range = entry[p.key]
        if type(range) == "table" then
            local m = BuildMatch(p, range, margin)
            list[#list + 1] = m
            if m.useful then anyUseful = true end
        end
    end
    return list, anyUseful
end

-- nil = no reagent rule for this item (feature off, not in the data,
-- or no profession of this character uses it and no own choice).
-- Otherwise { on, auto, userSet, best = match, matches }.
function Reagents.Evaluate(itemID)
    itemID = tonumber(itemID)
    if not itemID or not Reagents.IsEnabled() then return nil end
    local entry = Data().items[itemID]
    if not entry then return nil end
    local matches, auto = Matches(entry, GetState())
    local choices = GetChoices(false)
    local choice = choices and choices[itemID]
    if #matches == 0 and choice == nil then return nil end

    local best
    for _, m in ipairs(matches) do
        if m.useful then best = m; break end
    end
    best = best or matches[1]

    local on = auto
    if choice ~= nil then on = choice == true end
    return {
        itemID = itemID,
        on = on,
        auto = auto,
        userSet = choice ~= nil,
        best = best,
        matches = matches,
    }
end

-- v0.1.3: forget a character (scope key .. "|" .. full name)
function Reagents.ForgetCharacter(charKey)
    if charKey and type(LOF.db.reagentChoices) == "table" then
        LOF.db.reagentChoices[charKey] = nil
        choiceVersion = choiceVersion + 1
    end
end

-- v0.1.1: the item is in Data/ProfessionReagents.lua.
function Reagents.IsKnown(itemID)
    itemID = tonumber(itemID)
    return itemID ~= nil and Data().items[itemID] ~= nil
end

-- True when the item is a kept reagent for the current character.
function Reagents.IsKept(itemID)
    local r = Reagents.Evaluate(itemID)
    return r ~= nil and r.on == true
end

-- value: true (keep) / false (do not keep). A value equal to the
-- automatic default removes the choice (automatic again).
function Reagents.SetChoice(itemID, value)
    itemID = tonumber(itemID)
    if not itemID then return end
    local choices = GetChoices(true)
    if not choices then return end
    local entry = Data().items[itemID]
    local auto = false
    if entry then
        local _, a = Matches(entry, GetState())
        auto = a
    end
    if (value and true or false) == auto then
        choices[itemID] = nil
    else
        choices[itemID] = value and true or false
    end
    choiceVersion = choiceVersion + 1
    if Resolver.InvalidateCache then Resolver.InvalidateCache() end
end

-- -------------------------------------------------------------
-- Snapshot for the Reagents window (UIReagents.lua)
-- -------------------------------------------------------------
local function ItemDisplay(itemID, fallbackName)
    local name, link, quality, _, _, _, _, _, _, texture = LOF.GetItemInfo(itemID)
    if not texture and LOF.GetItemInfoInstant then
        texture = select(5, LOF.GetItemInfoInstant(itemID))
    end
    if not name and _G.C_Item and _G.C_Item.RequestLoadItemDataByID then
        pcall(_G.C_Item.RequestLoadItemDataByID, itemID)
    end
    return name or fallbackName or ("item " .. itemID), link, quality, texture
end

local STATE_ORDER = { now = 1, later = 2, past = 3 }

local function SortRows(a, b)
    local sa, sb = STATE_ORDER[a.rangeState] or 9, STATE_ORDER[b.rangeState] or 9
    if sa ~= sb then return sa < sb end
    if a.lowest ~= b.lowest then return a.lowest < b.lowest end
    return a.name < b.name
end

-- Returns { enabled, margin, professions = { { name, level, rows } } }.
-- Row: itemID, name, link, quality, icon, lowest, usefulTo,
-- usefulNow (default for this profession), rangeState (v0.1.2: now /
-- later / past), on, userSet.
function Reagents.GetWindowSnapshot()
    local snap = { enabled = Reagents.IsEnabled(), margin = Data().margin, professions = {} }
    local state = GetState()
    local choices = GetChoices(false) or {}
    local margin = tonumber(Data().margin) or 0
    local itemsByProf = {}
    for itemID, entry in pairs(Data().items) do
        for _, p in ipairs(state.profs) do
            local range = entry[p.key]
            if type(range) == "table" then
                itemsByProf[p.key] = itemsByProf[p.key] or {}
                local list = itemsByProf[p.key]
                list[#list + 1] = { itemID = itemID, entry = entry, range = range }
            end
        end
    end

    for _, p in ipairs(state.profs) do
        local group = { name = p.name, level = p.level, max = p.max, rows = {} }
        for _, it in ipairs(itemsByProf[p.key] or {}) do
            local m = BuildMatch(p, it.range, margin)
            local _, auto = Matches(it.entry, state)
            local choice = choices[it.itemID]
            local on = auto
            if choice ~= nil then on = choice == true end
            local name, link, quality, icon = ItemDisplay(it.itemID, it.entry[1])
            local rangeState = "now"   -- v0.1.2
            if not m.useful then
                rangeState = "past"
            elseif p.level < m.lowest then
                rangeState = "later"
            end
            group.rows[#group.rows + 1] = {
                itemID = it.itemID, name = name, link = link, quality = quality, icon = icon,
                lowest = m.lowest, usefulTo = m.usefulTo, usefulNow = m.useful, rangeState = rangeState,
                on = on, userSet = choice ~= nil,
            }
        end
        table.sort(group.rows, SortRows)
        snap.professions[#snap.professions + 1] = group
    end
    return snap
end
