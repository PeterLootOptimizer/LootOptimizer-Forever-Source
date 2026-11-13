-- =============================================================
-- LOF (LootOptimizer Forever) -- ResolverValue.lua
-- Value intelligence (LOF.Resolver.Value): what is an item worth,
-- vendor or auction house (Auctionator), and why.
-- The UI never decides a value; it renders the fields and codes
-- set here. Rules/numbers come from Data/PriceRules.lua.
-- =============================================================
--
-- Changelog
-- ---------
-- v0.2.1: Yivry (CurseForge, 13 Nov): setting "Show disenchant details
--   in tooltips" (showDisenchantDetails, default on). Off: info.de.details
--   is false; the tooltip shows only the value LOF uses. Values, Swap,
--   Make room and protection are not affected.
-- v0.2.0: Disenchant value (LOF 1.5.0, Peter). Value = the highest of
--   vendor (V), AH and the expected disenchant yield (DE). DE counts
--   only when ALL of these hold:
--     A. Auctionator integration active (on + loaded)
--     B. at least one character has Enchanting (Holdings.GetEnchanters;
--        skill level ignored)
--     C. setting useDisenchant on (default off)
--     D. soulbound item: the character you play has Enchanting itself
--     E. the item can be disenchanted: quality green/blue/purple, armor
--        or weapon, not a shirt/tabard, not in excludedItems, item level
--        inside the table (Data/DisenchantTable.lua)
--     F. at least one material has a usable AH price (> 0, not STALE)
--   DE value = sum of chance x average count x AH price per material; a
--   material without a usable price counts as 0 (never too high). No AH
--   cut, same as the AH value. DE wins only when higher than V and AH.
--   info.de = { each, stack, outcomes = { id, name, chance, min, max,
--   priceEach, priced }, by = enchanter name, byCurrent } whenever A-F
--   hold, also when DE does not win (tooltip line). When DE wins:
--   valueSource "DE", valueReason "DE_USED", info.de.baseSource /
--   baseReason = what it would have been. The cache key includes the
--   enchanter state, so learning Enchanting (or an alt) re-values bags.
-- v0.1.1: "Last AH visit" replaced by "AH prices updated": LOF stores
--   the date/time whenever Auctionator reports new prices (official
--   API v1 RegisterForDBUpdate: after a full scan or a search that
--   stored prices). Value.RecordPriceUpdate replaces RecordAHVisit;
--   the snapshot gives the calendar-day age + freshness code of it.
-- v0.1.0: Initial version (Auctionator integration, LOF 1.1.0).
--   - Auctionator is optional. Only the official API v1 is used
--     (GetAuctionPriceBy* / GetAuctionAgeBy*), always via pcall.
--   - Rules, in order:
--       integration off / Auctionator missing -> vendor
--       soulbound / bind-on-pickup            -> vendor
--       quality set to Vendor in Settings     -> vendor
--       no AH price                            -> vendor
--       AH price older than maxUsable days     -> vendor (STALE)
--       AH price below vendor price            -> vendor
--       otherwise                              -> AH price
--     So the value is never lower than the vendor price.
--   - Freshness codes FRESH / AGING / OLD / STALE from the age bands.
--   - Settings (LOF_DB.settings): useAuctionator, qualityModes,
--     lastAHVisit (replaced by lastPriceUpdate in v0.1.1). Setters invalidate the value data version, which
--     the bag slot cache in Resolver.lua checks.
-- =============================================================

local LOF = LOF
LOF.VERSION_RESOLVER_VALUE = "0.2.1"

local Value = {}
LOF.Resolver.Value = Value

Value.SOURCE_AH     = "AH"
Value.SOURCE_VENDOR = "V"
Value.SOURCE_DE     = "DE"   -- v0.2.0

Value.MODE_VENDOR = "VENDOR"
Value.MODE_AH     = "AH"

-- Freshness codes
Value.FRESH = "FRESH"
Value.AGING = "AGING"
Value.OLD   = "OLD"
Value.STALE = "STALE"

-- Reason codes (why this source was used)
Value.REASON_AH_USED         = "AH_USED"
Value.REASON_AH_OFF          = "AH_OFF"
Value.REASON_AH_UNAVAILABLE  = "AH_UNAVAILABLE"
Value.REASON_SOULBOUND       = "SOULBOUND"
Value.REASON_QUALITY_VENDOR  = "QUALITY_VENDOR"
Value.REASON_NO_AH_DATA      = "NO_AH_DATA"
Value.REASON_AH_STALE        = "AH_STALE"
Value.REASON_AH_BELOW_VENDOR = "AH_BELOW_VENDOR"
Value.REASON_DE_USED         = "DE_USED"   -- v0.2.0

local function Rules()
    return LOF.Data.PriceRules
end

-- -------------------------------------------------------------
-- Settings
-- -------------------------------------------------------------
local function Settings()
    LOF.db.settings = LOF.db.settings or {}
    local s = LOF.db.settings
    s.qualityModes = s.qualityModes or {}
    if s.useAuctionator == nil then s.useAuctionator = false end
    if s.useDisenchant == nil then s.useDisenchant = false end
    return s
end

-- Bumped on every change that alters values (settings, new AH data).
local dataVersion = 0

function Value.Invalidate()
    dataVersion = dataVersion + 1
end

-- v0.2.0: enchanter state (condition B / D), from Holdings. Re-read
-- only when the Holdings data changed. Returns state table:
--   { any = bool, current = bool, first = name of the first enchanter,
--     names = { ... }, key = "" / "A" / "C" }
local enchMemo, enchMemoVersion = nil, nil

local function GetEnchanterState()
    local H = LOF.Resolver.Holdings
    local v = H and H.GetDataVersion and H.GetDataVersion() or 0
    if enchMemo and enchMemoVersion == v then return enchMemo end
    local list = (H and H.GetEnchanters) and H.GetEnchanters() or {}
    local st = { any = #list > 0, current = false, names = {} }
    for _, e in ipairs(list) do
        st.names[#st.names + 1] = e.name
        if e.isCurrent then st.current = true end
    end
    st.first = list[1] and list[1].name
    st.key = st.current and "C" or (st.any and "A" or "")
    enchMemo, enchMemoVersion = st, v
    return st
end

-- Part of the slot cache key. The day number is included so ages move
-- on by themselves after midnight. v0.2.0: + enchanter state.
function Value.GetCacheKey()
    return tostring(dataVersion) .. ":" .. tostring(math.floor((time() or 0) / 86400))
        .. ":" .. GetEnchanterState().key
end

function Value.IsAuctionatorLoaded()
    local A = _G.Auctionator
    local api = A and A.API and A.API.v1
    return api ~= nil
        and (type(api.GetAuctionPriceByItemLink) == "function"
             or type(api.GetAuctionPriceByItemID) == "function")
end

function Value.IsEnabled()
    return Settings().useAuctionator == true
end

-- Integration switched on AND Auctionator present.
function Value.IsActive()
    return Value.IsEnabled() and Value.IsAuctionatorLoaded()
end

function Value.SetEnabled(enabled)
    Settings().useAuctionator = enabled and true or false
    Value.Invalidate()
end

function Value.GetQualityMode(quality)
    local q = tonumber(quality)
    if q == nil then return Value.MODE_VENDOR end
    local mode = Settings().qualityModes[q]
    if mode ~= Value.MODE_VENDOR and mode ~= Value.MODE_AH then
        mode = Rules().qualityDefaults[q]
    end
    if mode ~= Value.MODE_AH then
        mode = Value.MODE_VENDOR
    end
    -- Qualities above the table (legendary, artifact, heirloom) follow Epic.
    if Rules().qualityDefaults[q] == nil and q > 4 then
        mode = Value.GetQualityMode(4)
    end
    return mode
end

function Value.SetQualityMode(quality, mode)
    local q = tonumber(quality)
    if q == nil then return false end
    if mode ~= Value.MODE_VENDOR and mode ~= Value.MODE_AH then return false end
    Settings().qualityModes[q] = mode
    Value.Invalidate()
    return true
end

-- v0.2.0: disenchant value switch (condition C)
function Value.IsDisenchantEnabled()
    return Settings().useDisenchant == true
end

function Value.SetDisenchantEnabled(enabled)
    Settings().useDisenchant = enabled and true or false
    Value.Invalidate()
end

-- v0.2.1: disenchant details (materials, "Disenchant on") in tooltips.
-- Default on; nil counts as on.
function Value.IsDisenchantDetailsShown()
    return Settings().showDisenchantDetails ~= false
end

function Value.SetDisenchantDetailsShown(shown)
    Settings().showDisenchantDetails = shown and true or false
    Value.Invalidate()
end

-- Conditions A + B + C: disenchant value can be used at all.
function Value.IsDisenchantActive()
    return Value.IsActive() and Value.IsDisenchantEnabled() and GetEnchanterState().any
end

-- Called when Auctionator reports new prices (RegisterForDBUpdate).
function Value.RecordPriceUpdate()
    local s = Settings()
    s.lastPriceUpdate = time()
    s.lastAHVisit = nil   -- v0.1.0 field, no longer used
    Value.Invalidate()
end

-- Calendar days between a timestamp and now (0 = today, 1 = yesterday).
local function CalendarDaysAgo(t)
    local function DayNumber(ts)
        local d = date("*t", ts)
        return math.floor(time({ year = d.year, month = d.month, day = d.day, hour = 12 }) / 86400)
    end
    return math.max(0, DayNumber(time()) - DayNumber(t))
end

-- -------------------------------------------------------------
-- Freshness
-- -------------------------------------------------------------
function Value.GetFreshness(ageDays)
    local f = Rules().freshness
    local age = tonumber(ageDays)
    if age == nil then return Value.STALE end
    if age <= f.fresh then return Value.FRESH end
    if age <= f.aging then return Value.AGING end
    if age <= f.maxUsable then return Value.OLD end
    return Value.STALE
end

function Value.GetMaxUsableDays()
    return Rules().freshness.maxUsable
end

-- -------------------------------------------------------------
-- Auctionator lookup (official API v1 only)
-- -------------------------------------------------------------
local function CallAPI(fnName, arg)
    local api = _G.Auctionator and _G.Auctionator.API and _G.Auctionator.API.v1
    local fn = api and api[fnName]
    if type(fn) ~= "function" or arg == nil then return nil end
    local ok, result = pcall(fn, Rules().auctionatorCallerID, arg)
    if ok then return result end
    return nil
end

-- Returns priceEach (copper, or nil) and ageDays (or nil).
local ahMemo = {}
local ahMemoKey = nil

function Value.GetAHInfo(link, itemID)
    if not Value.IsAuctionatorLoaded() then return nil, nil end
    local key = Value.GetCacheKey()
    if key ~= ahMemoKey then
        ahMemo = {}
        ahMemoKey = key
    end
    local memoKey = link or ("id:" .. tostring(itemID))
    local m = ahMemo[memoKey]
    if m then return m.price, m.age end

    local price, age
    if type(link) == "string" then
        price = CallAPI("GetAuctionPriceByItemLink", link)
        age = CallAPI("GetAuctionAgeByItemLink", link)
    end
    if (price == nil or price <= 0) and type(itemID) == "number" then
        price = CallAPI("GetAuctionPriceByItemID", itemID)
        age = CallAPI("GetAuctionAgeByItemID", itemID)
    end
    price = tonumber(price)
    if price and price <= 0 then price = nil end
    age = tonumber(age)

    ahMemo[memoKey] = { price = price, age = age }
    return price, age
end

-- -------------------------------------------------------------
-- v0.2.0: disenchant value
-- -------------------------------------------------------------
local function DETable()
    return LOF.Data.DisenchantTable
end

-- Condition E: the band of outcomes for this item, or nil.
local function GetDisenchantOutcomes(info)
    local d = DETable()
    if not d then return nil end
    local q = tonumber(info.quality)
    local bands = q and d.bands[q]
    if not bands then return nil end
    local isWeapon = info.classID == d.weaponClass
    if not isWeapon and info.classID ~= d.armorClass then return nil end
    if info.itemID and d.excludedItems[info.itemID] then return nil end
    local loc = info.equipLoc
    if loc == nil or loc == "" or d.excludedEquipLocs[loc] then return nil end
    local level = tonumber(info.itemLevel)
    if not level or level <= 0 then return nil end
    for _, band in ipairs(bands) do
        if level <= band.maxLevel then
            return (isWeapon and band.weapon) or band.armor
        end
    end
    return nil
end

-- AH price of a material when usable (condition F), else nil.
local function UsableMaterialPrice(materialID)
    local price, age = Value.GetAHInfo(nil, materialID)
    if not price or price <= 0 then return nil end
    if Value.GetFreshness(age) == Value.STALE then return nil end
    return price
end

-- info.de for an item, or nil when one of A-F does not hold.
local function BuildDisenchant(info)
    if not Value.IsDisenchantActive() then return nil end            -- A B C
    local ench = GetEnchanterState()
    if info.isBound and not ench.current then return nil end         -- D
    local outcomes = GetDisenchantOutcomes(info)                     -- E
    if not outcomes then return nil end

    local d = DETable()
    local each, anyPriced = 0, false
    local list = {}
    for _, o in ipairs(outcomes) do
        local price = UsableMaterialPrice(o.id)
        local avg = ((tonumber(o.min) or 1) + (tonumber(o.max) or o.min or 1)) / 2
        if price then
            anyPriced = true
            each = each + o.chance * avg * price
        end
        local name = LOF.GetItemInfo(o.id)
        list[#list + 1] = {
            id = o.id, name = name or d.materialNames[o.id] or ("item " .. o.id),
            chance = o.chance, min = o.min, max = o.max,
            priceEach = price, priced = price ~= nil,
        }
    end
    if not anyPriced then return nil end                             -- F

    each = math.floor(each + 0.5)
    local count = math.max(1, tonumber(info.count or 1) or 1)
    local by = (not ench.current) and ench.first or nil
    return {
        each = each, stack = each * count, outcomes = list,
        by = by, byCurrent = ench.current,
        details = Value.IsDisenchantDetailsShown(),   -- v0.2.1
    }
end

-- -------------------------------------------------------------
-- The value rule
-- -------------------------------------------------------------
-- Adds value fields to an item info table (from Resolver.BuildItemInfo):
--   valueEach, value (stack), valueSource ("AH" / "V"), valueReason,
--   ahEach, ahStack, ahAgeDays, freshness.
-- isBound: soulbound / bind-on-pickup (never sellable on the AH).
function Value.Apply(info, isBound)
    local vendorEach = tonumber(info.vendorEach or 0) or 0
    local count = math.max(1, tonumber(info.count or 1) or 1)

    info.isBound     = isBound == true
    info.ahEach      = nil
    info.ahStack     = nil
    info.ahAgeDays   = nil
    info.freshness   = nil
    info.valueSource = Value.SOURCE_VENDOR
    info.valueEach   = vendorEach

    local reason
    if not Value.IsEnabled() then
        reason = Value.REASON_AH_OFF
    elseif not Value.IsAuctionatorLoaded() then
        reason = Value.REASON_AH_UNAVAILABLE
    elseif info.isBound then
        reason = Value.REASON_SOULBOUND
    else
        -- AH data is looked up for every tradable item, so the tooltip
        -- can show it even when the quality setting says Vendor.
        local price, age = Value.GetAHInfo(info.link, info.itemID)
        if price then
            info.ahEach    = price
            info.ahStack   = price * count
            info.ahAgeDays = age
            info.freshness = Value.GetFreshness(age)
        end

        if Value.GetQualityMode(info.quality) == Value.MODE_VENDOR then
            reason = Value.REASON_QUALITY_VENDOR
        elseif not price then
            reason = Value.REASON_NO_AH_DATA
        elseif info.freshness == Value.STALE then
            reason = Value.REASON_AH_STALE
        elseif price < vendorEach then
            reason = Value.REASON_AH_BELOW_VENDOR
        else
            reason = Value.REASON_AH_USED
            info.valueSource = Value.SOURCE_AH
            info.valueEach = price
        end
    end

    -- v0.2.0: disenchant value (highest wins)
    info.de = BuildDisenchant(info)
    if info.de and info.de.each > info.valueEach then
        info.de.baseSource = info.valueSource
        info.de.baseReason = reason
        info.valueSource = Value.SOURCE_DE
        info.valueEach = info.de.each
        reason = Value.REASON_DE_USED
    end

    info.valueReason = reason
    info.value = info.valueEach * count
    return info
end

-- -------------------------------------------------------------
-- Settings snapshot for the Settings tab (render only)
-- -------------------------------------------------------------
function Value.GetSettingsSnapshot()
    local s = Settings()
    local rows = {}
    for _, q in ipairs(Rules().qualityOrder) do
        rows[#rows + 1] = {
            quality = q,
            label = Rules().qualityLabels[q] or ("Quality " .. q),
            mode = Value.GetQualityMode(q),
        }
    end

    local updateDays, updateFreshness
    if s.lastPriceUpdate then
        updateDays = CalendarDaysAgo(s.lastPriceUpdate)
        updateFreshness = Value.GetFreshness(updateDays)
    end

    return {
        auctionatorLoaded = Value.IsAuctionatorLoaded(),
        enabled           = Value.IsEnabled(),
        active            = Value.IsActive(),
        lastPriceUpdate      = s.lastPriceUpdate,
        lastPriceUpdateDays  = updateDays,
        lastPriceUpdateFresh = updateFreshness,
        maxUsableDays     = Rules().freshness.maxUsable,
        freshDays         = Rules().freshness.fresh,
        agingDays         = Rules().freshness.aging,
        qualityRows       = rows,
        -- v0.2.0: disenchant value
        deAvailable       = GetEnchanterState().any,
        deEnabled         = Value.IsDisenchantEnabled(),
        deDetails         = Value.IsDisenchantDetailsShown(),   -- v0.2.1
        deActive          = Value.IsDisenchantActive(),
        deCurrent         = GetEnchanterState().current,
        deEnchanters      = GetEnchanterState().names,
    }
end
