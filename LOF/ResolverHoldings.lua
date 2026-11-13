-- =============================================================
-- LOF (LootOptimizer Forever) -- ResolverHoldings.lua
-- Resolver layer, Holdings domain (LOF.Resolver.Holdings): what does
-- each character own, where does it lie (bag / bank / mail / AH) and
-- what is it worth. All intelligence for the Holdings window lives
-- here; UIHoldings.lua only renders GetWindowSnapshot().
-- =============================================================
--
-- Changelog
-- ---------
-- v0.11.6: audit 1.6.8 (final): weaponSkills is only stored when the scan
--   found at least one trained weapon type (an early scan that sees none
--   would mark every weapon "train"); the trained types are part of the
--   gear signature (swap protection refreshes after training); in Gear for
--   alts an alt that still has to train sorts after one that can use it.
-- v0.11.5: E28 (Tim, 11 Nov): ScanCharacter stores weaponSkills, the
--   weapon types the character has trained ({ [subclass] = true },
--   IsPlayerSpell with StatProfiles.weaponSkills); GetGearProfiles passes
--   it on. Without IsPlayerSpell nothing is stored (old class rule).
-- v0.11.4: audit 1.6.8: realWeapons only stores a real weapon in the main
--   hand (not empty, not a pole). Unarmed and then the pole used to store
--   "no weapon", so every weapon looked like an upgrade again.
-- v0.11.3: E23 (Peter, 9 Nov): ScanCharacter also stores realWeapons,
--   the main hand / off-hand held without a fishing pole (kept while a
--   pole is held; equipSlots still shows what is really held).
--   GetGearProfiles passes realWeapons on; Holdings.GetRealWeapons() for
--   the current character and Holdings.CharHasInBags(name, link) for the
--   "is it still in the bags" check (stored bag of that character).
-- v0.11.2: E4 fix (ResolverUpgrade 0.13.4): RequestItem is exported as
--   Holdings.RequestItem for ResolverUpgrade (alt gear not loaded yet),
--   and the gear-for-alts cache key includes Upgrade.GetDataEpoch(), so a
--   comparison that waited for item data is recomputed.
-- v0.11.1: Gear for alts: the selected row carries comparison (Resolver
--   .Upgrade.GetAltComparison for its top character), so Holdings shows
--   the same comparison table as the popups (UIHoldings 0.9.4).
-- v0.11.0: Forget a character (CurseForge request: a deleted character
--   stays in LOF - the game never tells an addon a character is gone).
--   Holdings.ForgetCharacter(name): not the current character; removes
--   the character from the scope and asks Upgrade / Reagents to drop
--   its settings too. Holdings.GetCharacters rows carry lastSeen (the
--   latest read time of that character).
-- v0.10.2: Reagents in the swap (LOF 1.6.0, ResolverReagents):
--   Holdings.GetCurrentProfessions() returns the current character's
--   professions ({ name, level, max, skillLine }), stored by the last
--   scan, read live when nothing is stored yet.
--   Holdings.GetCurrentCharKey() = scope key + full name: the key for
--   per-character reagent choices.
-- v0.10.1: Holdings.GetEnchanters() (LOF 1.5.0, disenchant value): the
--   characters in the current scope whose stored professions include
--   Enchanting (skill line / name from Data/DisenchantTable.lua). The
--   skill level is NOT used: what can not be disenchanted now can be
--   later. A character counts once LOF has seen it log in. VendorOnly
--   (Vendor Value mode) also drops the disenchant value.
-- v0.10.0: Who sent the items in the mail (Peter). ScanMail keeps per
--   mail item the senders with their count (entry.f = { [sender] = n },
--   sender as GetInboxHeaderInfo gives it: an alt, a player, "Auction
--   House", a quest giver). RecordSentMail books the sending character
--   as sender. Snapshot: holder.mailFrom = { { name, count } }, most
--   first, then by name. Entries stored before v0.10.0 have no senders
--   until that character opens the mailbox again.
-- v0.9.0: GetProfessionStatus rows carry materials (coin icon tooltip,
--   Peter): Trade Goods of the subclasses linked to that profession
--   (Data/ProfessionRanks materials), counted in the stored bags of the
--   current character (reagent bag included) plus the bank when known.
--   Biggest bag count first, at most maxMaterials (moreMaterials = the
--   rest). hasMaterials = false for Cooking / First Aid / Fishing.
-- v0.8.2: "AH incoming" no longer drops to 0 when the mailbox opens
--   (Peter: the sale mail arrives about an hour later, so the money was
--   nowhere for a while). Incoming = sum of the sold auctions whose sale
--   mail has not arrived yet (node.ahSoldPending). A pending sale stays
--   until its invoice is booked; a later AH visit keeps it (the sold
--   auction may no longer be listed there) and adds new ones without
--   doubles. Pending sales older than 2 days are dropped (safety).
-- v0.8.1: Sold auctions leave the AH list without an AH visit (Peter:
--   sold Light Leather stayed under AH after the money was in the mail).
--   ScanMail books every AH sale invoice once against node.loc.ah (same
--   item name, minus the sold count). Booked invoices are remembered in
--   node.ahSoldSeen (item, count, gross, mail expiry +-5 min), because
--   the mailbox is scanned several times and the money can stay in the
--   mail. Auctions that were already "sold" (status 1) at the last AH
--   visit were never in the list: ScanAuctions keeps them in
--   node.ahSoldPending, and their invoice is matched there instead.
--   Opening the AH replaces the list; booked invoices stay remembered
--   (until their mail expires), so they are never booked twice.
--   Not covered: cancelled auctions (back in the mail early) stay in the
--   AH list until the next AH visit.
-- v0.8.0: Gear for alts (B). GetWindowSnapshot(opts) with
--   opts.gearMode fills snap.gear: every BoE gear item in bags, bank or
--   mail of any character in the scope (not soulbound, not equipped,
--   not on the AH, bind type tradable) that is an upgrade for at least
--   one character (the current one included; Resolver.Upgrade rules,
--   per-character ignores respected).
--   - Character filter = "for whom"; Location filter = where it lies
--     (bag / bank / mail; other locations give an empty list).
--   - Row: item, holders (character + location + count), targets (all
--     characters it is an upgrade for, best first) and shown (the
--     target for the filter, or the best). Sorted by shown target.
--   - Cached until the data, the ignores or the Advisor setting change.
--     Items whose data is not loaded yet are requested and counted in
--     snap.gear.pending (the list completes on GET_ITEM_INFO_RECEIVED).
--   - Holdings.GetGearProfiles(includeCurrent): profiles for the
--     comparison; GetAltGearProfiles() = without the current character.
-- v0.7.2: Profile spec (D2, Peter): snap.profile.spec = { source,
--   basis, trees }. source "talents" (points spent), "default" (no
--   points yet: class default tree) or "unknown" (talents never read:
--   character not logged in since LOF 1.3.0). basis comes from
--   Resolver.Upgrade.GetWeightMixFor, so the profile shows exactly what
--   the Upgrade Advisor uses. trees = stored points per tree.
-- v0.7.1: Holdings.GetGearVersion(): bumped only when the current
--   character's equipped gear, talent points or level change (not on
--   every bag scan). Resolver uses it to know when the swap protection
--   of upgrades in the bags must be checked again.
-- v0.7.0: Gear for alt upgrades (LOF 1.3.0).
--   - ScanCharacter also stores node.equipSlots ({ [slot] = link },
--     which item sits in which slot: two equal rings, main hand vs
--     off-hand), node.talents (points per talent tree, from
--     Resolver.Upgrade.GetTalentTrees; kept when not readable yet) and
--     node.dualWield (CanDualWield, when the client has it).
--   - Holdings.GetAltGearProfiles(): the other characters in the scope
--     with known equipped gear, for Resolver.Upgrade. Characters not
--     logged in since this version have no equipSlots; ResolverUpgrade
--     then places the stored equipped items by their item type.
-- v0.6.0: Gold in the mail per mail (Peter). ScanMail stores every mail
--   with money in node.mailMoney: AH sale (GetInboxInvoiceInfo
--   "seller": item, count, sold for, AH fee, deposit back, net) or
--   player money (sender, amount). Mail sent with money to an own alt
--   is booked there as player money (sent). Snapshot: snap.mailMoney
--   (rows, key "money:<character>:<n>"), snap.mailMoneyTotal and
--   snap.selectedMoney when such a row is selected. These rows are not
--   items: they never add to the item value (mailGold already counts).
-- v0.5.0: AH (Holdings step 4).
--   - Location "ah": Holdings.ScanAuctions() reads the own auctions
--     (C_AuctionHouse, Modern AH). Active auctions (status 0) are
--     stored with count, buyout (p, total) and expiry (x). Commodities
--     have no item link (measured): "item:<itemID>" is used instead.
--   - Sold auctions (status 1) are no items any more: their amount is
--     ahIncoming (money on its way by mail).
--   - Reading the mailbox removes expired AH entries (they are in the
--     mail now) and clears ahIncoming (the money is mail gold now), so
--     nothing counts twice.
--   - Snapshot: row.ahListed / ahBuyout / ahExpiresIn / ahExpired,
--     holder.ahExpiresIn / ahExpired; profile/summary.ahIncoming (also
--     in the total).
-- v0.4.1: Forever names are "First Last" (measured: UnitName returns
--   "Julian", "Brandt"; the surname sits where retail has the realm).
--   Only the combination is unique, so characters are stored under the
--   full name ("Julian Brandt"), plus node.guid. Data stored under the
--   first name only (v0.1.0 - v0.4.0) moves to the full name at the
--   next login of that character. Mail recipients match on the full
--   name ("Soumix Beta", "Soumix-Beta"); a first name alone only when
--   exactly one own character has it (never book on a guess).
-- v0.4.0: Mailbox (Holdings step 3).
--   - Location "mail": Holdings.ScanMail() reads the open inbox; per
--     item the count and the earliest expiry (x = timestamp), plus the
--     gold in the mail (mailGold; COD amounts are not yours).
--   - Holdings.RecordSentMail(recipient, items, money): mail sent to an
--     own character of the same scope is booked in that character's
--     mail at once, marked sent (s = 1), expiry 30 days. The next real
--     read of that mailbox replaces it.
--   - Snapshot: row.mailExpiresDays / row.mailExpiringSoon (<= 3 days),
--     holder.mailExpiresDays, holder.mailSent; profile.mailGold,
--     summary.mailGold (also in the total).
-- v0.3.0: Holdings.GetProfessionStatus(): the current character's
--   professions with a training status from Data/ProfessionRanks.lua:
--   NORMAL, TRAIN (next rank can be learned now) or TRAIN_LEVEL (skill
--   is high enough, the character level is not yet). anyTrain = true
--   when at least one profession can be trained now.
-- v0.2.1: Scans only store data while the game is ready: the backpack
--   (bag 0) always has slots, so 0 slots means logout / loading screen
--   and the stored data is kept (it was overwritten with "nothing").
-- v0.2.0: Character profile (LOF 1.1.2, Holdings step 2).
--   - Per character also: gold, className, free slots (bags always,
--     bank while open), professions (GetProfessions/GetProfessionInfo,
--     measured on Forever: the old GetSkillLineInfo does not exist) and
--     equipped gear as location "equipped".
--   - Holdings.ScanCharacter() reads bags + equipped + gold +
--     professions in one go (Capture calls it); ScanBank as before.
--   - Bank containers never include the player's own bag indexes
--     (0 .. last bag, incl. the reagent bag), so nothing is counted
--     twice whatever the client reports.
--   - Snapshot: `profile` (one character) or `summary` (All
--     Characters: count, gold, item value, total).
-- v0.1.0: Initial version (LOF 1.1.2, Holdings phase 1).
--   - Scope = realm + faction ("ClassicBetaPvE|Alliance"). On Forever a
--     ruleset shows up as its own realm name, and Horde and Alliance
--     cannot trade, so a scope is one group of characters that can
--     share items. One function (GetScopeKey) decides this.
--   - Storage LOF_DB.holdings (version 1):
--       scopes[scopeKey].chars[charName] = {
--         class, level,
--         updated = { bag = time, bank = time },
--         loc = { bag = { [groupKey] = { n = count, l = link, b = 1 } },
--                 bank = { ... } },
--       }
--     Per character and location one list; a new scan replaces that
--     list as a whole (no running totals to keep in sync).
--   - groupKey = itemID, plus the random suffix ("of the Monkey") when
--     present. The link level differs per character, so the full item
--     string would split the same item into several rows.
--   - Phase 1 collects bag (incl. reagent bag) and bank. Mail and AH
--     are known location codes but not collected yet.
--   - Everything is included: soulbound gear, quest items, whitelisted
--     items. The question is "where is my stuff", not "what can I sell".
--   - Value mode SWAP uses the normal value rules (Resolver.Value, the
--     Auctionator settings); VENDOR uses the vendor price only. Bound
--     items are always valued at vendor price (as everywhere in LOF).
-- =============================================================

local LOF = LOF
LOF.VERSION_RESOLVER_HOLDINGS = "0.11.6"

local Resolver = LOF.Resolver
local Holdings = {}
Resolver.Holdings = Holdings

Holdings.STORAGE_VERSION = 1

Holdings.ALL = "ALL"

Holdings.LOC_BAG  = "bag"
Holdings.LOC_BANK = "bank"
Holdings.LOC_MAIL = "mail"
Holdings.LOC_AH   = "ah"
Holdings.LOC_EQUIPPED = "equipped"
Holdings.LOC_MULTI = "MULTI"   -- row lies in more than one location

-- Display order of the locations.
Holdings.LOCATIONS = { "bag", "bank", "equipped", "mail", "ah" }

-- Locations LOF collects in this version.
local COLLECTED = { bag = true, bank = true, equipped = true, mail = true, ah = true }

-- Mail expiring within this many days is flagged (lost when it expires).
local MAIL_SOON_DAYS = 3
local MAIL_SENT_DAYS = 30   -- expiry assumed for mail LOF booked as sent

Holdings.MODE_SWAP   = "SWAP"
Holdings.MODE_VENDOR = "VENDOR"

-- Bumped after every scan, so the UI knows when to re-render.
local dataVersion = 0

function Holdings.GetDataVersion()
    return dataVersion
end

-- v0.7.1: changes only with the current character's gear / talents / level
local gearVersion = 0
local gearSignature = nil

function Holdings.GetGearVersion()
    return gearVersion
end

local function GearSignature(node)
    local parts = { tostring(node.level) }
    for slot = 0, 19 do
        parts[#parts + 1] = tostring(node.equipSlots and node.equipSlots[slot] or "")
    end
    for _, t in ipairs(node.talents or {}) do
        parts[#parts + 1] = tostring(t.points)
    end
    -- v0.11.6: trained weapon types (E28)
    local skills = {}
    for subclass in pairs(node.weaponSkills or {}) do skills[#skills + 1] = subclass end
    table.sort(skills)
    parts[#parts + 1] = table.concat(skills, ",")
    return table.concat(parts, "|")
end

function Holdings.IsLocationCollected(code)
    return COLLECTED[code] == true
end

-- -------------------------------------------------------------
-- Scope + storage
-- -------------------------------------------------------------
function Holdings.GetScopeKey()
    local realm = _G.GetNormalizedRealmName and _G.GetNormalizedRealmName()
    if not realm or realm == "" then
        realm = string.gsub(_G.GetRealmName and _G.GetRealmName() or "", "%s+", "")
    end
    local faction = UnitFactionGroup("player")
    if not realm or realm == "" or not faction then return nil end
    return realm .. "|" .. faction
end

local function GetDB()
    local db = LOF.db
    db.holdings = db.holdings or {}
    local h = db.holdings
    h.version = h.version or Holdings.STORAGE_VERSION
    h.scopes = h.scopes or {}
    return h
end

local function GetScope(scopeKey)
    if not scopeKey then return nil end
    local h = GetDB()
    h.scopes[scopeKey] = h.scopes[scopeKey] or { chars = {} }
    h.scopes[scopeKey].chars = h.scopes[scopeKey].chars or {}
    return h.scopes[scopeKey]
end

-- Full character name: "First Last" on Forever, plain name elsewhere.
-- Also returns the first name alone.
local function GetPlayerName()
    local name, last = UnitName("player")
    if not name or name == "" or name == _G.UNKNOWNOBJECT then return nil end
    if type(last) == "string" and last ~= "" then
        return name .. " " .. last, name
    end
    return name, name
end

-- The current character's node (created when missing).
local function GetCurrentNode()
    local scope = GetScope(Holdings.GetScopeKey())
    local name, first = GetPlayerName()
    if not scope or not name then return nil end
    -- v0.4.1: data stored under the first name only moves to the full name
    if first ~= name and scope.chars[first] and not scope.chars[name] then
        scope.chars[name] = scope.chars[first]
        scope.chars[first] = nil
    end
    local node = scope.chars[name] or {}
    scope.chars[name] = node
    node.guid = UnitGUID("player") or node.guid
    node.loc = node.loc or {}
    node.updated = node.updated or {}
    local className, classFile = UnitClass("player")
    node.class = classFile or node.class
    node.className = className or node.className
    node.level = UnitLevel("player") or node.level
    return node, name
end

-- -------------------------------------------------------------
-- Item keys
-- -------------------------------------------------------------
local function ItemFields(link)
    local itemString = type(link) == "string" and string.match(link, "item:[%-%d:]*")
    if not itemString then return nil end
    local fields = {}
    for part in string.gmatch(itemString .. ":", "([^:]*):") do
        fields[#fields + 1] = part
    end
    return fields
end

-- itemID, or itemID:suffixID for random-suffix items.
local function GroupKey(link)
    local f = ItemFields(link)
    if not f or not f[2] or f[2] == "" then return nil end
    local suffix = f[8]
    if suffix and suffix ~= "" and suffix ~= "0" then
        return f[2] .. ":" .. suffix
    end
    return f[2]
end

-- -------------------------------------------------------------
-- Containers
-- -------------------------------------------------------------
local function GetBagContainers()
    local list = {}
    for bag = 0, LOF.GetLastBagIndex() do
        list[#list + 1] = bag
    end
    return list
end

-- Character bank: main bank, reagent bank and bank bags / character
-- bank tabs, whichever this client knows. Account (warband) tabs are
-- left out: they are not one character's holdings.
local function GetBankContainers()
    local list, seen = {}, {}
    local lastBag = LOF.GetLastBagIndex()
    local function add(b)
        -- never one of the player's own bags (0 .. last, reagent bag)
        if type(b) == "number" and not seen[b] and not (b >= 0 and b <= lastBag) then
            seen[b] = true
            list[#list + 1] = b
        end
    end
    local E = _G.Enum and _G.Enum.BagIndex
    if E and E.Bank then
        add(E.Bank)
        add(E.Reagentbank)
        for i = 1, 7 do add(E["BankBag_" .. i]) end
        for i = 1, 6 do add(E["CharacterBankTab_" .. i]) end
    else
        add(_G.BANK_CONTAINER or -1)
        local first = (tonumber(_G.NUM_TOTAL_EQUIPPED_BAG_SLOTS or _G.NUM_BAG_SLOTS or 4) or 4) + 1
        local count = tonumber(_G.NUM_BANKBAGSLOTS or 7) or 7
        for b = first, first + count - 1 do add(b) end
    end
    return list
end

Holdings.GetBankContainers = GetBankContainers

-- Reads containers into { [groupKey] = { n, l, b } }.
local function ReadContainers(containers)
    local entries, slots = {}, 0
    for _, bag in ipairs(containers) do
        local numSlots = LOF.GetContainerNumSlots(bag)
        slots = slots + numSlots
        for slot = 1, numSlots do
            local c = LOF.GetContainerItemInfo(bag, slot)
            local link = c and c.hyperlink
            local key = GroupKey(link)
            if key then
                local count = tonumber(c.stackCount or 1) or 1
                local e = entries[key]
                if e then
                    e.n = e.n + count
                else
                    entries[key] = {
                        n = count,
                        l = link,
                        b = LOF.IsBagItemBound(bag, slot) and 1 or nil,
                    }
                end
            end
        end
    end
    return entries, slots
end

-- -------------------------------------------------------------
-- Scans (called by Capture at the right moments)
-- -------------------------------------------------------------
local function CountFree(containers, generalOnly)
    local free = 0
    local reagent = _G.Enum and _G.Enum.BagIndex and _G.Enum.BagIndex.ReagentBag
    for _, bag in ipairs(containers) do
        local n, family = LOF.GetContainerNumFreeSlots(bag)
        n = tonumber(n or 0) or 0
        family = tonumber(family or 0) or 0
        if not generalOnly or (family == 0 and bag ~= reagent) then
            free = free + n
        end
    end
    return free
end

-- Returns the grouped entries (location "equipped") and, per slot,
-- the link of the item in that slot (v0.7.0).
local function ReadEquipped()
    local entries = {}
    local slotLinks = {}
    local IL = _G.ItemLocation
    local C_Item = _G.C_Item
    for slot = 0, 19 do
        local link = GetInventoryItemLink("player", slot)
        local key = GroupKey(link)
        if link then slotLinks[slot] = link end
        if key then
            local count = 1
            if slot == 0 then count = GetInventoryItemCount("player", slot) or 1 end
            local bound
            if IL and IL.CreateFromEquipmentSlot and C_Item and C_Item.IsBound then
                local ok, loc = pcall(IL.CreateFromEquipmentSlot, IL, slot)
                if ok and loc then
                    local ok2, b = pcall(C_Item.IsBound, loc)
                    bound = ok2 and b == true
                end
            end
            local e = entries[key]
            if e then
                e.n = e.n + count
            else
                entries[key] = { n = count, l = link, b = bound and 1 or nil }
            end
        end
    end
    return entries, slotLinks
end

local function ReadProfessions()
    local list = {}
    if not _G.GetProfessions or not _G.GetProfessionInfo then return list end
    local indexes = { _G.GetProfessions() }
    for i = 1, 6 do
        local index = indexes[i]
        if index then
            local name, _, level, maxLevel, _, _, skillLine = _G.GetProfessionInfo(index)
            if name then
                list[#list + 1] = { name = name, level = level, max = maxLevel, skillLine = skillLine }
            end
        end
    end
    return list
end

-- The backpack always has slots; none means the character is not
-- (or no longer) loaded, and nothing read now can be trusted.
local function IsReady()
    return LOF.GetContainerNumSlots(0) > 0
end

function Holdings.ScanBags()
    if not IsReady() then return false end
    local node = GetCurrentNode()
    if not node then return false end
    local bags = GetBagContainers()
    node.loc.bag = ReadContainers(bags)
    node.updated.bag = time()
    node.free = node.free or {}
    node.free.bag = CountFree(bags, true)
    dataVersion = dataVersion + 1
    return true
end

-- v0.2.0: everything that can be read anywhere, in one go.
function Holdings.ScanCharacter()
    if not IsReady() then return false end
    local node = GetCurrentNode()
    if not node then return false end
    Holdings.ScanBags()
    local equipped, slotLinks = ReadEquipped()
    node.loc.equipped = equipped
    node.equipSlots = slotLinks
    -- v0.11.3 (E23): the weapons held without a fishing pole
    local Up = Resolver.Upgrade
    local main = slotLinks and slotLinks[16]
    if main and not (Up and Up.IsFishingPoleLink and Up.IsFishingPoleLink(main)) then   -- v0.11.4
        node.realWeapons = { [16] = main, [17] = slotLinks and slotLinks[17] }
    end
    -- v0.11.5 (E28): trained weapon types
    local skills = LOF.Data and LOF.Data.StatProfiles and LOF.Data.StatProfiles.weaponSkills
    if type(skills) == "table" and _G.IsPlayerSpell then
        local known = {}
        for subclass, s in pairs(skills) do
            if _G.IsPlayerSpell(s.spell) then known[subclass] = true end
        end
        if next(known) ~= nil then node.weaponSkills = known end   -- v0.11.6
    end
    node.updated.equipped = time()
    -- v0.7.0: talents + dual wield, for alt upgrades
    local Upgrade = Resolver.Upgrade
    local trees = Upgrade and Upgrade.GetTalentTrees and Upgrade.GetTalentTrees()
    if type(trees) == "table" and #trees > 0 then
        node.talents = trees
        node.updated.talents = time()
    end
    if type(_G.CanDualWield) == "function" then
        local ok, dw = pcall(_G.CanDualWield)
        if ok then node.dualWield = dw and true or false end
    end
    local signature = GearSignature(node)
    if signature ~= gearSignature then
        gearSignature = signature
        gearVersion = gearVersion + 1
    end
    node.gold = GetMoney and GetMoney() or node.gold
    node.professions = ReadProfessions()
    dataVersion = dataVersion + 1
    return true
end

function Holdings.ScanMoney()
    if not IsReady() then return false end
    local node = GetCurrentNode()
    if not node or not GetMoney then return false end
    node.gold = GetMoney()
    dataVersion = dataVersion + 1
    return true
end

-- Only call while the bank is open: a closed bank reads as empty.
function Holdings.ScanBank()
    local node = GetCurrentNode()
    if not node then return false end
    local containers = GetBankContainers()
    local entries, slots = ReadContainers(containers)
    if slots <= 0 then return false end   -- bank not readable (closed)
    node.loc.bank = entries
    node.updated.bank = time()
    node.free = node.free or {}
    node.free.bank = CountFree(containers, false)
    dataVersion = dataVersion + 1
    return true
end

-- -------------------------------------------------------------
-- Characters in the current scope
-- -------------------------------------------------------------
-- Sorted: current character first, then alphabetical.
function Holdings.GetCharacters()
    local scope = GetScope(Holdings.GetScopeKey())
    local current = GetPlayerName()
    local list = {}
    if not scope then return list end
    for name, node in pairs(scope.chars) do
        local lastSeen   -- v0.11.0
        for _, t in pairs(type(node.updated) == "table" and node.updated or {}) do
            if type(t) == "number" and (not lastSeen or t > lastSeen) then lastSeen = t end
        end
        list[#list + 1] = {
            name = name, class = node.class, className = node.className,
            level = node.level, isCurrent = name == current, lastSeen = lastSeen,
        }
    end
    table.sort(list, function(a, b)
        if a.isCurrent ~= b.isCurrent then return a.isCurrent end
        return a.name < b.name
    end)
    return list
end

-- v0.11.0: forget a character of this scope (not the one you play).
-- Returns true, or false + "current" / "unknown".
function Holdings.ForgetCharacter(name)
    local scopeKey = Holdings.GetScopeKey()
    local scope = GetScope(scopeKey)
    if not scope or not name or not scope.chars[name] then return false, "unknown" end
    if name == GetPlayerName() then return false, "current" end
    scope.chars[name] = nil
    dataVersion = dataVersion + 1
    gearVersion = gearVersion + 1
    local R = LOF.Resolver
    if R.Upgrade and R.Upgrade.ForgetCharacter then R.Upgrade.ForgetCharacter(name) end
    if R.Reagents and R.Reagents.ForgetCharacter then R.Reagents.ForgetCharacter(scopeKey .. "|" .. name) end
    if R.InvalidateCache then R.InvalidateCache() end
    return true
end

-- v0.10.1: characters with Enchanting, current character first.
-- Returns list of { name, isCurrent }.
local function HasEnchanting(node)
    local d = LOF.Data.DisenchantTable
    for _, p in ipairs(node.professions or {}) do
        if (d.skillLine and p.skillLine == d.skillLine) or p.name == d.professionName then
            return true
        end
    end
    return false
end

function Holdings.GetEnchanters()
    local list = {}
    local scope = GetScope(Holdings.GetScopeKey())
    if not scope then return list end
    local current = GetPlayerName()
    for name, node in pairs(scope.chars) do
        if type(node) == "table" and HasEnchanting(node) then
            list[#list + 1] = { name = name, isCurrent = name == current }
        end
    end
    table.sort(list, function(a, b)
        if a.isCurrent ~= b.isCurrent then return a.isCurrent end
        return a.name < b.name
    end)
    return list
end

-- v0.10.2: the current character's professions, for ResolverReagents.
function Holdings.GetCurrentProfessions()
    local scope = GetScope(Holdings.GetScopeKey())
    local name = GetPlayerName()
    local node = scope and name and scope.chars[name]
    if type(node) == "table" and type(node.professions) == "table" then
        return node.professions
    end
    return ReadProfessions()
end

-- v0.10.2: scope + full name, nil while the character is not loaded.
function Holdings.GetCurrentCharKey()
    local scopeKey = Holdings.GetScopeKey()
    local name = GetPlayerName()
    if not scopeKey or not name then return nil end
    return scopeKey .. "|" .. name
end

-- v0.7.2: spec of a stored character, as the Upgrade Advisor sees it.
local function BuildSpec(node)
    local Upgrade = Resolver.Upgrade
    if not (Upgrade and Upgrade.GetWeightMixFor) or not node.class then return nil end
    local mix, basis, source = Upgrade.GetWeightMixFor(node.class, node.talents)
    if not mix then return nil end
    if type(node.talents) ~= "table" or #node.talents == 0 then source = "unknown" end
    local trees = {}
    for _, t in ipairs(node.talents or {}) do
        trees[#trees + 1] = { name = t.name, points = tonumber(t.points) or 0 }
    end
    return { source = source, basis = basis, trees = trees }
end

-- v0.7.0: the other characters in the scope whose equipped gear is
-- known, for alt upgrades (Resolver.Upgrade). Read-only copies of the
-- stored data; nothing is calculated here.
-- v0.11.3 (E23): weapons last held without a fishing pole (current
-- character), or nil when never seen.
function Holdings.GetRealWeapons()
    local node = GetCurrentNode()
    return node and node.realWeapons or nil
end

-- v0.11.3 (E23): the stored bag link of this item for a character, or
-- nil when it is not in that character's stored bags.
function Holdings.CharHasInBags(name, link)
    local scope = GetScope(Holdings.GetScopeKey())
    local node = scope and name and scope.chars[name]
    local bag = node and node.loc and node.loc.bag
    local e = bag and GroupKey(link) and bag[GroupKey(link)]
    return e and (e.l or link) or nil
end

function Holdings.GetGearProfiles(includeCurrent)
    local scope = GetScope(Holdings.GetScopeKey())
    local current = GetPlayerName()
    local list = {}
    if not scope or not current then return list end
    for name, node in pairs(scope.chars) do
        if (includeCurrent or name ~= current) and node.class and node.loc and node.loc.equipped then
            list[#list + 1] = {
                name = name, class = node.class, className = node.className,
                level = tonumber(node.level) or 1,
                equipSlots = node.equipSlots,      -- nil before v0.7.0
                realWeapons = node.realWeapons,    -- v0.11.3 (E23), nil before
                weaponSkills = node.weaponSkills,  -- v0.11.5 (E28), nil before
                equipped = node.loc.equipped,
                talents = node.talents,
                dualWield = node.dualWield,
                updated = node.updated and node.updated.equipped,
            }
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

function Holdings.GetAltGearProfiles()
    return Holdings.GetGearProfiles(false)
end

-- Ask the server for item data (moved up in v0.8.0: used by the gear
-- view as well; a local must be declared before the code that uses it).
local function RequestItem(link)
    local itemID = LOF.GetItemInfoInstant(link)
    local C_Item = _G.C_Item
    if itemID and C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    end
end
-- DEBT(dup): v0.11.2 exported for ResolverUpgrade (E4 fix). One of three
-- request-item helpers (Resolver.lua RequestItemData, this one,
-- ResolverReagents inline). Consolidate after 1.6.3 (audit C).
Holdings.RequestItem = RequestItem

-- -------------------------------------------------------------
-- v0.8.0: Gear for alts (B)
-- -------------------------------------------------------------
local GEAR_LOCATIONS = { "bag", "bank", "mail" }
local gearCache = { key = nil, rows = nil, pending = 0 }

-- All gear rows for the scope (unfiltered), cached.
local function BuildGearRows(scope, current)
    local Upgrade = Resolver.Upgrade
    if not (Upgrade and Upgrade.IsEnabled and Upgrade.IsEnabled()) then return {}, 0 end
    local cacheKey = tostring(Holdings.GetScopeKey()) .. ":" .. dataVersion .. ":"
        .. tostring(Upgrade.GetIgnoreVersion and Upgrade.GetIgnoreVersion())
        .. ":" .. tostring(Upgrade.GetDataEpoch and Upgrade.GetDataEpoch())   -- v0.11.2 (E4)
    if gearCache.key == cacheKey and gearCache.rows then
        return gearCache.rows, gearCache.pending
    end

    -- Collect: group key -> item + holders
    local byKey, order = {}, {}
    for name, node in pairs(scope.chars) do
        for _, code in ipairs(GEAR_LOCATIONS) do
            for key, e in pairs((node.loc and node.loc[code]) or {}) do
                local n = tonumber(e.n or 0) or 0
                if n > 0 and not e.b and e.l and Upgrade.IsGearLink(e.l) then
                    local r = byKey[key]
                    if not r then
                        r = { key = "gear:" .. key, link = e.l, holders = {} }
                        byKey[key] = r
                        order[#order + 1] = key
                    end
                    r.holders[#r.holders + 1] = {
                        name = name, class = node.class, isCurrent = name == current,
                        location = code, count = n,
                        updated = node.updated and node.updated[code],
                    }
                end
            end
        end
    end

    local profiles = Holdings.GetGearProfiles(true)
    local rows, pending = {}, 0
    for _, key in ipairs(order) do
        local r = byKey[key]
        local name, _, quality, _, _, _, _, _, _, icon = LOF.GetItemInfo(r.link)
        if not name then
            pending = pending + 1
            RequestItem(r.link)
        elseif Upgrade.IsTradableLink(r.link) then
            local targets = Upgrade.EvaluateForAlts(r.link, profiles)
            if #targets > 0 then
                r.name, r.quality, r.icon = name, quality, icon
                r.itemID = LOF.GetItemInfoInstant(r.link)
                r.targets = targets
                table.sort(r.holders, function(a, b)
                    if a.name ~= b.name then return a.name < b.name end
                    return a.location < b.location
                end)
                rows[#rows + 1] = r
            end
        end
    end
    -- only cache a complete result
    if pending == 0 then
        gearCache.key, gearCache.rows, gearCache.pending = cacheKey, rows, 0
    end
    return rows, pending
end

local function TargetBefore(a, b)
    if a.tooLow ~= b.tooLow then return not a.tooLow end
    if (a.needTraining ~= nil) ~= (b.needTraining ~= nil) then return a.needTraining == nil end   -- v0.11.6
    if a.emptySlot ~= b.emptySlot then return a.emptySlot end
    local pa, pb = a.percent or 0, b.percent or 0
    if pa ~= pb then return pa > pb end
    return a.name < b.name
end

-- Filtered view for the window.
local function BuildGearView(scope, current, character, location, selectedKey)
    local gear = { rows = {}, pending = 0, locations = GEAR_LOCATIONS }
    local Upgrade = Resolver.Upgrade
    gear.advisorOff = not (Upgrade and Upgrade.IsEnabled and Upgrade.IsEnabled())
    if not scope then return gear end
    local all, pending = BuildGearRows(scope, current)
    gear.pending = pending
    local now = time()
    for _, r in ipairs(all) do
        local shown
        if character == Holdings.ALL then
            shown = r.targets[1]
        else
            for _, t in ipairs(r.targets) do
                if t.name == character then shown = t break end
            end
        end
        local holders = {}
        for _, h in ipairs(r.holders) do
            if location == Holdings.ALL or location == h.location then holders[#holders + 1] = h end
        end
        if shown and #holders > 0 then
            local targets = {}
            for _, t in ipairs(r.targets) do
                local copy = {}
                for k, v in pairs(t) do copy[k] = v end
                if t.gearUpdated then copy.gearAgeDays = math.floor((now - t.gearUpdated) / 86400) end
                copy.isHolder = false
                for _, h in ipairs(r.holders) do
                    if h.name == t.name then copy.isHolder = true end
                end
                targets[#targets + 1] = copy
            end
            gear.rows[#gear.rows + 1] = {
                key = r.key, link = r.link, itemID = r.itemID, name = r.name,
                quality = r.quality, icon = r.icon,
                holders = holders, targets = targets, shown = shown,
            }
        end
    end
    table.sort(gear.rows, function(a, b)
        if a.shown ~= b.shown then
            local x, y = a.shown, b.shown
            if x.tooLow ~= y.tooLow or x.emptySlot ~= y.emptySlot
                or (x.needTraining ~= nil) ~= (y.needTraining ~= nil)   -- v0.11.6
                or (x.percent or 0) ~= (y.percent or 0) then
                return TargetBefore(x, y)
            end
        end
        if a.name ~= b.name then return a.name < b.name end
        return a.key < b.key
    end)
    for _, row in ipairs(gear.rows) do
        if row.key == selectedKey then gear.selected = row break end
    end
    gear.selected = gear.selected or gear.rows[1]
    -- v0.11.1: the full comparison for the top character of the selected
    -- item (the same table as the Upgrade and swap popups)
    local sel = gear.selected
    if sel and sel.targets and sel.targets[1] and Upgrade and Upgrade.GetAltComparison then
        sel.comparison = Upgrade.GetAltComparison(sel.targets[1], sel.link)
    end
    return gear
end

-- -------------------------------------------------------------
-- Value of one stored entry group
-- -------------------------------------------------------------
local function VendorOnly(info)
    info.valueSource = "V"
    info.valueEach   = tonumber(info.vendorEach or 0) or 0
    info.value       = info.valueEach * (tonumber(info.count or 1) or 1)
    info.valueReason = "AH_OFF"   -- no AH block in tooltips
    info.ahEach, info.ahStack, info.ahAgeDays, info.freshness = nil, nil, nil, nil
    info.de = nil   -- v0.10.1
    return info
end

-- Row info for count items of which boundCount are soulbound.
local function ResolveRowValue(link, count, boundCount, mode)
    local free = count - boundCount
    local info
    if free > 0 then
        info = Resolver.BuildItemInfo(link, free, false)
        if mode == Holdings.MODE_VENDOR then VendorOnly(info) end
        if boundCount > 0 then
            local boundInfo = Resolver.BuildItemInfo(link, boundCount, true)
            info.value = (info.value or 0) + (boundInfo.value or 0)
        end
    else
        info = Resolver.BuildItemInfo(link, count, true)
        if mode == Holdings.MODE_VENDOR then VendorOnly(info) end
    end
    info.count = count
    info.boundCount = boundCount
    if not info.infoReady then RequestItem(link) end
    return info
end

-- -------------------------------------------------------------
-- Window snapshot
-- -------------------------------------------------------------
-- opts:
--   character : nil / "current" (logged-in), Holdings.ALL, or a name
--   location  : Holdings.ALL or a location code
--   valueMode : Holdings.MODE_SWAP (default) or MODE_VENDOR
--   selectedKey : groupKey of the selected row (optional)
function Holdings.GetWindowSnapshot(opts)
    opts = opts or {}
    local scopeKey = Holdings.GetScopeKey()
    local scope = GetScope(scopeKey)
    local current = GetPlayerName()
    local mode = opts.valueMode == Holdings.MODE_VENDOR and Holdings.MODE_VENDOR or Holdings.MODE_SWAP
    local location = opts.location or Holdings.ALL
    if location ~= Holdings.ALL and not COLLECTED[location] then location = Holdings.ALL end

    local character = opts.character
    if character == nil or character == "current" then character = current end
    if character ~= Holdings.ALL and not (scope and scope.chars[character]) then
        character = current
    end

    local snap = {
        scopeKey = scopeKey,
        character = character,
        isAll = character == Holdings.ALL,
        currentName = current,
        location = location,
        valueMode = mode,
        characters = Holdings.GetCharacters(),
        rows = {},
        totals = { items = 0, units = 0, value = 0 },
        updated = {},     -- [loc] = { oldest = t, newest = t, missing = n }
        locations = {},
    }
    for _, code in ipairs(Holdings.LOCATIONS) do
        if COLLECTED[code] then snap.locations[#snap.locations + 1] = code end
    end
    if not scope then return snap end

    -- Characters in the selection
    local selected = {}
    if snap.isAll then
        for name in pairs(scope.chars) do selected[#selected + 1] = name end
    elseif character and scope.chars[character] then
        selected[1] = character
    end

    -- When was each location last read (for the footer)
    for _, code in ipairs(snap.locations) do
        local u = { missing = 0 }
        for _, name in ipairs(selected) do
            local t = scope.chars[name].updated and scope.chars[name].updated[code]
            if t then
                if not u.oldest or t < u.oldest then u.oldest = t end
                if not u.newest or t > u.newest then u.newest = t end
            else
                u.missing = u.missing + 1
            end
        end
        snap.updated[code] = u
    end

    -- Aggregate per group key
    local byKey = {}
    for _, name in ipairs(selected) do
        local node = scope.chars[name]
        for _, code in ipairs(snap.locations) do
            if location == Holdings.ALL or location == code then
                for key, e in pairs((node.loc and node.loc[code]) or {}) do
                    local n = tonumber(e.n or 0) or 0
                    if n > 0 then
                        local r = byKey[key]
                        if not r then
                            r = { key = key, link = e.l, count = 0, bound = 0, parts = {}, holders = {} }
                            byKey[key] = r
                        end
                        r.count = r.count + n
                        if e.b then r.bound = r.bound + n end
                        r.parts[code] = (r.parts[code] or 0) + n
                        local h = r.holders[name]
                        if not h then
                            h = { name = name, class = node.class, level = node.level,
                                  isCurrent = name == current, parts = {},
                                  updated = node.updated }
                            r.holders[name] = h
                        end
                        h.parts[code] = (h.parts[code] or 0) + n
                        if code == "mail" then
                            local x = tonumber(e.x)
                            if x and (not h.mailExpires or x < h.mailExpires) then h.mailExpires = x end
                            if x and (not r.mailExpires or x < r.mailExpires) then r.mailExpires = x end
                            if e.s then h.mailSent = (h.mailSent or 0) + n end
                            if type(e.f) == "table" then   -- v0.10.0
                                h.mailFromMap = h.mailFromMap or {}
                                for sender, c in pairs(e.f) do
                                    h.mailFromMap[sender] = (h.mailFromMap[sender] or 0) + (tonumber(c) or 0)
                                end
                            end
                        end
                        if code == "ah" then
                            local x = tonumber(e.x)
                            if x and (not h.ahExpires or x < h.ahExpires) then h.ahExpires = x end
                            if x and (not r.ahExpires or x < r.ahExpires) then r.ahExpires = x end
                            r.ahBuyout = (r.ahBuyout or 0) + (tonumber(e.p or 0) or 0)
                        end
                    end
                end
            end
        end
    end

    -- Value per row
    for _, r in pairs(byKey) do
        local row = ResolveRowValue(r.link, r.count, r.bound, mode)
        row.key = r.key
        row.parts = r.parts
        local codes = 0
        for code in pairs(r.parts) do
            codes = codes + 1
            row.location = code
        end
        if codes > 1 then row.location = Holdings.LOC_MULTI end
        local holders = {}
        for _, h in pairs(r.holders) do holders[#holders + 1] = h end
        table.sort(holders, function(a, b)
            if a.isCurrent ~= b.isCurrent then return a.isCurrent end
            return a.name < b.name
        end)
        row.holders = holders
        local now = time()
        if r.mailExpires then
            row.mailExpiresDays = math.max(0, math.floor((r.mailExpires - now) / 86400))
            row.mailExpiringSoon = row.mailExpiresDays <= MAIL_SOON_DAYS
        end
        if r.parts.ah then
            row.ahListed = r.parts.ah
            row.ahBuyout = r.ahBuyout
            if r.ahExpires then
                row.ahExpiresIn = r.ahExpires - now
                row.ahExpired = row.ahExpiresIn <= 0
            end
        end
        for _, h in ipairs(holders) do
            if h.ahExpires then
                h.ahExpiresIn = h.ahExpires - now
                h.ahExpired = h.ahExpiresIn <= 0
            end
            if h.mailExpires then
                h.mailExpiresDays = math.max(0, math.floor((h.mailExpires - now) / 86400))
                h.mailExpiringSoon = h.mailExpiresDays <= MAIL_SOON_DAYS
            end
            if h.mailFromMap then   -- v0.10.0
                local list = {}
                for sender, c in pairs(h.mailFromMap) do
                    if c > 0 then list[#list + 1] = { name = sender, count = c } end
                end
                table.sort(list, function(a, b)
                    if a.count ~= b.count then return a.count > b.count end
                    return a.name < b.name
                end)
                h.mailFrom = list
                h.mailFromMap = nil
            end
        end
        snap.rows[#snap.rows + 1] = row
        snap.totals.units = snap.totals.units + r.count
        snap.totals.value = snap.totals.value + (row.value or 0)
    end
    snap.totals.items = #snap.rows

    table.sort(snap.rows, function(a, b)
        local va, vb = a.value or 0, b.value or 0
        if va ~= vb then return va > vb end
        return tostring(a.name) < tostring(b.name)
    end)

    -- v0.2.0: profile of one character, or summary of all
    if snap.isAll then
        local gold, mailGold, ahIncoming = 0, 0, 0
        for _, name in ipairs(selected) do
            gold = gold + (tonumber(scope.chars[name].gold or 0) or 0)
            mailGold = mailGold + (tonumber(scope.chars[name].mailGold or 0) or 0)
            ahIncoming = ahIncoming + (tonumber(scope.chars[name].ahIncoming or 0) or 0)
        end
        snap.summary = {
            characters = #selected, gold = gold, mailGold = mailGold, ahIncoming = ahIncoming,
            itemValue = snap.totals.value,
            total = gold + mailGold + ahIncoming + snap.totals.value,
        }
    elseif selected[1] then
        local node = scope.chars[selected[1]]
        snap.profile = {
            name = selected[1], class = node.class, className = node.className,
            level = node.level, gold = node.gold, mailGold = node.mailGold,
            ahIncoming = node.ahIncoming,
            freeBag = node.free and node.free.bag,
            freeBank = node.free and node.free.bank,
            professions = node.professions or {},
            itemValue = snap.totals.value,
            spec = BuildSpec(node),   -- v0.7.2
        }
    end

    -- v0.6.0: gold in the mail, per mail (only in the Mail view)
    snap.mailMoney, snap.mailMoneyTotal = {}, 0
    if location == "mail" then
        local now = time()
        for _, name in ipairs(selected) do
            local node = scope.chars[name]
            for i, m in ipairs(node.mailMoney or {}) do
                local row = {
                    key = "money:" .. name .. ":" .. i, isMoney = true,
                    character = name, class = node.class, isCurrent = name == current,
                    kind = m.kind, item = m.item, count = m.count, from = m.from,
                    gross = m.gross, fee = m.fee, deposit = m.deposit, net = m.net or 0,
                    sent = m.s ~= nil,
                }
                if m.item then
                    local _, link, quality, _, _, _, _, _, _, icon = LOF.GetItemInfo(m.item)
                    row.icon, row.quality, row.link = icon, quality, link
                end
                if m.x then
                    row.expiresDays = math.max(0, math.floor((m.x - now) / 86400))
                    row.expiringSoon = row.expiresDays <= MAIL_SOON_DAYS
                end
                snap.mailMoney[#snap.mailMoney + 1] = row
                snap.mailMoneyTotal = snap.mailMoneyTotal + row.net
            end
        end
        table.sort(snap.mailMoney, function(a, b)
            if a.net ~= b.net then return a.net > b.net end
            return a.key < b.key
        end)
    end

    for _, row in ipairs(snap.rows) do
        if row.key == opts.selectedKey then snap.selected = row break end
    end
    for _, row in ipairs(snap.mailMoney) do
        if row.key == opts.selectedKey then snap.selectedMoney = row break end
    end
    if not snap.selectedMoney then
        snap.selected = snap.selected or snap.rows[1] or nil
        if not snap.selected then snap.selectedMoney = snap.mailMoney[1] end
    end

    -- v0.8.0: Gear for alts
    if opts.gearMode then
        snap.gearMode = true
        snap.gear = BuildGearView(scope, current, character, location, opts.selectedKey)
    end
    return snap
end

-- -------------------------------------------------------------
-- Small snapshot for the Holdings tab on the dashboard
-- -------------------------------------------------------------
function Holdings.GetTabSnapshot()
    local scope = GetScope(Holdings.GetScopeKey())
    local current = GetPlayerName()
    local node = scope and current and scope.chars[current]
    local count = 0
    if scope then
        for _ in pairs(scope.chars) do count = count + 1 end
    end
    return {
        characterCount = count,
        bagUpdated  = node and node.updated and node.updated.bag,
        bankUpdated = node and node.updated and node.updated.bank,
    }
end

-- -------------------------------------------------------------
-- v0.3.0: profession training status (current character)
-- -------------------------------------------------------------
Holdings.PROF_NORMAL      = "NORMAL"
Holdings.PROF_TRAIN       = "TRAIN"
Holdings.PROF_TRAIN_LEVEL = "TRAIN_LEVEL"

-- v0.9.0: materials of one profession in the current character's
-- stored bags (+ bank). Returns list or nil (no materials for it).
local function ProfessionMaterials(p, data)
    local subs = data and data.materials and data.materials[p.skillLine or -1]
    if not subs and data and data.materialsByName then subs = data.materialsByName[p.name or ""] end
    if not subs then return nil end
    local wanted = {}
    for _, sc in ipairs(subs) do wanted[sc] = true end
    local classID = tonumber(data.materialClass or 7) or 7
    local node = GetCurrentNode()
    local byKey, list = {}, {}
    local function add(loc, field)
        for key, e in pairs((node and node.loc and node.loc[loc]) or {}) do
            local link = e.l
            local _, _, _, _, _, c, sc = LOF.GetItemInfoInstant(link)
            if c == classID and sc and wanted[sc] then
                local m = byKey[key]
                if not m then
                    local name, _, quality = LOF.GetItemInfo(link)
                    m = { name = name, quality = quality, link = link, bag = 0, bank = 0 }
                    byKey[key] = m
                    list[#list + 1] = m
                end
                m[field] = m[field] + (tonumber(e.n or 0) or 0)
            end
        end
    end
    add("bag", "bag")
    add("bank", "bank")
    table.sort(list, function(a, b)
        if a.bag ~= b.bag then return a.bag > b.bag end
        if a.bank ~= b.bank then return a.bank > b.bank end
        return tostring(a.name) < tostring(b.name)
    end)
    return list
end

function Holdings.GetProfessionStatus()
    local data = LOF.Data.ProfessionRanks
    local window = tonumber(data and data.trainWindow or 25) or 25
    local charLevel = UnitLevel("player") or 0
    local rows, anyTrain = {}, false
    for _, p in ipairs(ReadProfessions()) do
        local level = tonumber(p.level or 0) or 0
        local max = tonumber(p.max or 0) or 0
        local rank = data and data.ranks and data.ranks[max]
        local status = Holdings.PROF_NORMAL
        local requiredLevel
        if rank and rank.nextMinLevel and max > 0 and level >= max - window then
            if charLevel >= rank.nextMinLevel then
                status = Holdings.PROF_TRAIN
                anyTrain = true
            else
                status = Holdings.PROF_TRAIN_LEVEL
                requiredLevel = rank.nextMinLevel
            end
        end
        local row = {
            name = p.name, level = level, max = max,
            status = status, requiredLevel = requiredLevel,
        }
        -- v0.9.0: materials
        local mats = ProfessionMaterials(p, data)
        row.hasMaterials = mats ~= nil
        if mats then
            local maxN = tonumber(data.maxMaterials or 4) or 4
            row.materials = {}
            for i = 1, math.min(#mats, maxN) do row.materials[i] = mats[i] end
            row.moreMaterials = math.max(0, #mats - maxN)
        end
        rows[#rows + 1] = row
    end
    return { rows = rows, anyTrain = anyTrain }
end

-- -------------------------------------------------------------
-- v0.4.0: mailbox
-- -------------------------------------------------------------
-- v0.6.0: what a mail with money is. GetInboxInvoiceInfo (measured on
-- Forever): type, item, player, sold for, ?, deposit, AH fee, ...,
-- count. The mail's own money is the net amount (authoritative).
local function ReadMoneyMail(i, sender, money, expires)
    local m = { net = money, x = expires }
    local r = { pcall(_G.GetInboxInvoiceInfo or function() end, i) }
    if r[1] and r[2] == "seller" then
        m.kind = "ah"
        m.item = r[3]
        m.gross = tonumber(r[5])
        m.deposit = tonumber(r[7])
        m.fee = tonumber(r[8])
        m.count = tonumber(r[12]) or tonumber(r[6])
    else
        m.kind = "player"
        m.from = sender
    end
    return m
end
-- v0.8.1: book AH sale invoices against the stored auctions (once each).
local SOLD_MATCH_SECONDS = 300

local function ItemNameOf(link)
    return link and LOF.GetItemInfo(link) or nil
end

local function ApplyAhSales(node, moneyList, now)
    node.ahSoldSeen = node.ahSoldSeen or {}
    -- forget invoices whose mail is gone for sure (expired)
    for i = #node.ahSoldSeen, 1, -1 do
        if (tonumber(node.ahSoldSeen[i].x) or 0) < now - 86400 then table.remove(node.ahSoldSeen, i) end
    end
    for _, m in ipairs(moneyList) do
        if m.kind == "ah" and m.item then
            local seen = false
            for _, s in ipairs(node.ahSoldSeen) do
                if s.item == m.item and s.count == m.count and s.gross == m.gross
                    and math.abs((s.x or 0) - (m.x or 0)) <= SOLD_MATCH_SECONDS then
                    seen = true
                    break
                end
            end
            if not seen then
                node.ahSoldSeen[#node.ahSoldSeen + 1] = { item = m.item, count = m.count, gross = m.gross, x = m.x }
                -- already sold at the last AH visit -> never in the list
                local pending = false
                for i, p in ipairs(node.ahSoldPending or {}) do
                    if ItemNameOf(p.l) == m.item and (p.amount == nil or m.gross == nil or p.amount == m.gross) then
                        table.remove(node.ahSoldPending, i)
                        pending = true
                        break
                    end
                end
                if not pending then
                    local sold = tonumber(m.count or 0) or 0
                    for key, e in pairs(node.loc.ah or {}) do
                        if ItemNameOf(e.l) == m.item then
                            local n = tonumber(e.n or 0) or 0
                            local take = (sold > 0) and math.min(sold, n) or n
                            e.n = n - take
                            sold = sold - take
                            if e.n <= 0 then node.loc.ah[key] = nil end
                            if sold <= 0 then break end
                        end
                    end
                end
            end
        end
    end
end

-- Only call while the mailbox is open.
function Holdings.ScanMail()
    if not IsReady() then return false end
    if not _G.GetInboxNumItems or not _G.GetInboxItemLink then return false end
    local node = GetCurrentNode()
    if not node then return false end
    local now = time()
    local entries, gold, moneyList = {}, 0, {}
    local maxAttach = tonumber(_G.ATTACHMENTS_MAX_RECEIVE or 12) or 12
    for i = 1, (GetInboxNumItems() or 0) do
        local _, _, sender, _, money, cod, daysLeft, itemCount = GetInboxHeaderInfo(i)
        local expires = now + math.floor((tonumber(daysLeft or 0) or 0) * 86400)
        money = tonumber(money or 0) or 0
        if (tonumber(cod or 0) or 0) <= 0 then
            gold = gold + money
            if money > 0 then
                moneyList[#moneyList + 1] = ReadMoneyMail(i, sender, money, expires)
            end
        end
        if (tonumber(itemCount or 0) or 0) > 0 then
            for a = 1, maxAttach do
                local link = GetInboxItemLink(i, a)
                local key = GroupKey(link)
                if key then
                    local _, _, _, count = GetInboxItem(i, a)
                    count = tonumber(count or 1) or 1
                    local e = entries[key]
                    if e then
                        e.n = e.n + count
                        if expires < e.x then e.x = expires end
                    else
                        e = { n = count, l = link, x = expires }
                        entries[key] = e
                    end
                    if type(sender) == "string" and sender ~= "" then   -- v0.10.0
                        e.f = e.f or {}
                        e.f[sender] = (e.f[sender] or 0) + count
                    end
                end
            end
        end
    end
    node.loc.mail = entries
    node.mailGold = gold
    node.mailMoney = moneyList
    node.updated.mail = now
    -- v0.5.0: expired auctions are in the mail now; sold money too
    for key, e in pairs(node.loc.ah or {}) do
        if tonumber(e.x) and e.x <= now then node.loc.ah[key] = nil end
    end
    ApplyAhSales(node, moneyList, now)   -- v0.8.1
    -- v0.8.2: money still on its way = sold auctions without sale mail
    local incoming = 0
    for _, p in ipairs(node.ahSoldPending or {}) do incoming = incoming + (tonumber(p.amount) or 0) end
    node.ahIncoming = incoming
    dataVersion = dataVersion + 1
    return true
end

-- Recipient as typed ("Soumix Beta", "Soumix-Beta", "soumix") -> the
-- stored character name in this scope, or nil when not (surely) own.
local function FindOwnCharacter(scope, recipient)
    if type(recipient) ~= "string" then return nil end
    local wanted = string.lower(recipient)
    wanted = string.gsub(wanted, "%-", " ")
    wanted = string.gsub(wanted, "%s+", " ")
    wanted = string.gsub(wanted, "^ ", "")
    wanted = string.gsub(wanted, " $", "")
    if wanted == "" then return nil end
    -- 1. full name
    for stored in pairs(scope.chars) do
        if string.lower(stored) == wanted then return stored end
    end
    -- 1b. "Soumix Beta" -> data still stored under "Soumix" (before
    --     v0.4.1, until that character logs in once)
    local firstWanted = string.match(wanted, "^(%S+)")
    for stored in pairs(scope.chars) do
        if not string.find(stored, " ", 1, true) and string.lower(stored) == firstWanted then
            return stored
        end
    end
    -- 2. first name only, when exactly one own character has it
    if not string.find(wanted, " ", 1, true) then
        local found, count = nil, 0
        for stored in pairs(scope.chars) do
            local first = string.lower(string.match(stored, "^(%S+)") or stored)
            if first == wanted then
                found = stored
                count = count + 1
            end
        end
        if count == 1 then return found end
    end
    return nil
end

-- items: { { link = l, count = n }, ... }. Books mail to an own alt.
function Holdings.RecordSentMail(recipient, items, money)
    local scope = GetScope(Holdings.GetScopeKey())
    if not scope then return false end
    local target = FindOwnCharacter(scope, recipient)
    if not target or target == GetPlayerName() then return false end
    local node = scope.chars[target]
    node.loc = node.loc or {}
    node.loc.mail = node.loc.mail or {}
    local expires = time() + MAIL_SENT_DAYS * 86400
    for _, it in ipairs(items or {}) do
        local key = GroupKey(it.link)
        if key then
            local e = node.loc.mail[key]
            local n = tonumber(it.count or 1) or 1
            if e then
                e.n = e.n + n
                e.s = 1
                if not e.x or expires < e.x then e.x = expires end
            else
                e = { n = n, l = it.link, x = expires, s = 1 }
                node.loc.mail[key] = e
            end
            local sender = GetPlayerName()   -- v0.10.0
            if sender then
                e.f = e.f or {}
                e.f[sender] = (e.f[sender] or 0) + n
            end
        end
    end
    if (tonumber(money or 0) or 0) > 0 then
        node.mailGold = (tonumber(node.mailGold or 0) or 0) + money
        node.mailMoney = node.mailMoney or {}
        node.mailMoney[#node.mailMoney + 1] = {
            kind = "player", from = GetPlayerName(), net = money, x = expires, s = 1,
        }
    end
    dataVersion = dataVersion + 1
    return true
end

-- -------------------------------------------------------------
-- v0.5.0: own auctions (Modern AH). Only call after the server sent
-- the owned auctions (OWNED_AUCTIONS_UPDATED) while the AH is open.
-- -------------------------------------------------------------
function Holdings.ScanAuctions()
    if not IsReady() then return false end
    local AH = _G.C_AuctionHouse
    if not AH or not AH.GetNumOwnedAuctions or not AH.GetOwnedAuctionInfo then return false end
    local node = GetCurrentNode()
    if not node then return false end
    local now = time()
    local entries, incoming, soldPending = {}, 0, {}
    for i = 1, (AH.GetNumOwnedAuctions() or 0) do
        local a = AH.GetOwnedAuctionInfo(i)
        if a then
            local amount = tonumber(a.buyoutAmount or a.bidAmount or 0) or 0
            if a.status == 1 then
                incoming = incoming + amount
                -- v0.8.1: sold, invoice still to come
                local soldLink = a.itemLink
                if not soldLink and a.itemKey and a.itemKey.itemID then
                    soldLink = "item:" .. a.itemKey.itemID
                end
                soldPending[#soldPending + 1] = { l = soldLink, amount = amount, t = now }
            else
                local link = a.itemLink
                if not link and a.itemKey and a.itemKey.itemID then
                    link = "item:" .. a.itemKey.itemID
                end
                local key = GroupKey(link)
                if key then
                    local n = tonumber(a.quantity or 1) or 1
                    local x = now + (tonumber(a.timeLeftSeconds or 0) or 0)
                    local e = entries[key]
                    if e then
                        e.n = e.n + n
                        e.p = (e.p or 0) + amount
                        if x < e.x then e.x = x end
                    else
                        entries[key] = { n = n, l = link, x = x, p = amount }
                    end
                end
            end
        end
    end
    node.loc.ah = entries
    -- v0.8.2: keep earlier pending sales (no mail yet); add the new ones
    -- without doubles (same item + amount = the same sale seen again)
    local merged = {}
    local used = {}
    for _, old in ipairs(node.ahSoldPending or {}) do
        if (tonumber(old.t) or now) > now - 2 * 86400 then
            merged[#merged + 1] = old
        end
    end
    for _, p in ipairs(soldPending) do
        local found = false
        for i, old in ipairs(merged) do
            if not used[i] and old.l == p.l and old.amount == p.amount then
                used[i] = true
                found = true
                break
            end
        end
        if not found then merged[#merged + 1] = p end
    end
    node.ahSoldPending = merged
    incoming = 0
    for _, p in ipairs(merged) do incoming = incoming + (tonumber(p.amount) or 0) end
    -- ahSoldSeen stays: an invoice still in the mail must not be booked
    -- again against the fresh list.
    node.ahIncoming = incoming
    node.updated.ah = now
    dataVersion = dataVersion + 1
    return true
end
