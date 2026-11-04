-- =============================================================
-- LOF (LootOptimizer Forever) -- Data/DisenchantTable.lua
-- Reference data ONLY (no logic). Read by ResolverValue.lua.
-- What disenchanting an item gives, by quality, item level band and
-- armor / weapon.
-- =============================================================
--
-- Changelog
-- ---------
-- v0.1.0: Initial version (LOF 1.5.0, disenchant value).
--   - Numbers are the vanilla (1.12) disenchant table, written from
--     knowledge, NOT yet measured on Forever. If Forever differs,
--     change the numbers here only.
--   - bands[quality] is a list ordered by maxLevel. An item uses the
--     first band whose maxLevel >= its item level. Above the last band
--     the item is unknown (no disenchant value).
--   - Each outcome: { id = material itemID, chance = 0..1, min, max }.
--     The resolver uses the average count (min + max) / 2.
--   - weapon = nil means: same as armor.
--   - excludedEquipLocs / excludedItems: armor or weapons that can
--     not be disenchanted. Add itemIDs here when found in game.
-- =============================================================

local LOF = LOF
LOF.VERSION_DATA_DISENCHANTTABLE = "0.1.0"

LOF.Data = LOF.Data or {}

-- Material itemIDs (names are a fallback for the tooltip until the
-- client has the item cached).
local STRANGE_DUST   = 10940
local SOUL_DUST      = 11083
local VISION_DUST    = 11137
local DREAM_DUST     = 11176
local ILLUSION_DUST  = 16204

local LESSER_MAGIC   = 10938
local GREATER_MAGIC  = 10939
local LESSER_ASTRAL  = 10998
local GREATER_ASTRAL = 11082
local LESSER_MYSTIC  = 11134
local GREATER_MYSTIC = 11135
local LESSER_NETHER  = 11174
local GREATER_NETHER = 11175
local LESSER_ETERNAL = 16202
local GREATER_ETERNAL= 16203

local SMALL_GLIMMERING = 10978
local LARGE_GLIMMERING = 11084
local SMALL_GLOWING    = 11138
local LARGE_GLOWING    = 11139
local SMALL_RADIANT    = 11177
local LARGE_RADIANT    = 11178
local SMALL_BRILLIANT  = 14343
local LARGE_BRILLIANT  = 14344
local NEXUS_CRYSTAL    = 20725

-- Green bands: armor gives mostly dust, weapons mostly essence.
local function Green(maxLevel, dust, dMin, dMax, essence, eMin, eMax, shard, shardChance)
    local dustChance = 1 - 0.20 - (shardChance or 0)
    local armor = {
        { id = dust,    chance = dustChance, min = dMin, max = dMax },
        { id = essence, chance = 0.20,       min = eMin, max = eMax },
    }
    local weapon = {
        { id = dust,    chance = 0.20,       min = dMin, max = dMax },
        { id = essence, chance = dustChance, min = eMin, max = eMax },
    }
    if shard then
        armor[#armor + 1]   = { id = shard, chance = shardChance, min = 1, max = 1 }
        weapon[#weapon + 1] = { id = shard, chance = shardChance, min = 1, max = 1 }
    end
    return { maxLevel = maxLevel, armor = armor, weapon = weapon }
end

local function One(maxLevel, id, min, max)
    return { maxLevel = maxLevel, armor = { { id = id, chance = 1, min = min or 1, max = max or min or 1 } } }
end

LOF.Data.DisenchantTable = {
    -- Profession that can disenchant (skill line, English name fallback).
    skillLine = 333,
    professionName = "Enchanting",

    -- Item classes that can be disenchanted.
    weaponClass = 2,
    armorClass  = 4,

    -- Equip locations that can never be disenchanted.
    excludedEquipLocs = {
        INVTYPE_BODY   = true,   -- shirt
        INVTYPE_TABARD = true,
    },

    -- Known items that can not be disenchanted (itemID = true).
    excludedItems = {
    },

    materialNames = {
        [STRANGE_DUST] = "Strange Dust", [SOUL_DUST] = "Soul Dust",
        [VISION_DUST] = "Vision Dust", [DREAM_DUST] = "Dream Dust",
        [ILLUSION_DUST] = "Illusion Dust",
        [LESSER_MAGIC] = "Lesser Magic Essence", [GREATER_MAGIC] = "Greater Magic Essence",
        [LESSER_ASTRAL] = "Lesser Astral Essence", [GREATER_ASTRAL] = "Greater Astral Essence",
        [LESSER_MYSTIC] = "Lesser Mystic Essence", [GREATER_MYSTIC] = "Greater Mystic Essence",
        [LESSER_NETHER] = "Lesser Nether Essence", [GREATER_NETHER] = "Greater Nether Essence",
        [LESSER_ETERNAL] = "Lesser Eternal Essence", [GREATER_ETERNAL] = "Greater Eternal Essence",
        [SMALL_GLIMMERING] = "Small Glimmering Shard", [LARGE_GLIMMERING] = "Large Glimmering Shard",
        [SMALL_GLOWING] = "Small Glowing Shard", [LARGE_GLOWING] = "Large Glowing Shard",
        [SMALL_RADIANT] = "Small Radiant Shard", [LARGE_RADIANT] = "Large Radiant Shard",
        [SMALL_BRILLIANT] = "Small Brilliant Shard", [LARGE_BRILLIANT] = "Large Brilliant Shard",
        [NEXUS_CRYSTAL] = "Nexus Crystal",
    },

    bands = {
        -- Uncommon (green)
        [2] = {
            Green(15, STRANGE_DUST, 1, 2, LESSER_MAGIC,    1, 2),
            Green(20, STRANGE_DUST, 2, 3, GREATER_MAGIC,   1, 2, SMALL_GLIMMERING, 0.05),
            Green(25, STRANGE_DUST, 4, 6, LESSER_ASTRAL,   1, 2, SMALL_GLIMMERING, 0.05),
            Green(30, SOUL_DUST,    1, 2, GREATER_ASTRAL,  1, 2, LARGE_GLIMMERING, 0.05),
            Green(35, SOUL_DUST,    2, 5, LESSER_MYSTIC,   1, 2, SMALL_GLOWING,    0.05),
            Green(40, VISION_DUST,  1, 2, GREATER_MYSTIC,  1, 2, LARGE_GLOWING,    0.05),
            Green(45, VISION_DUST,  2, 5, LESSER_NETHER,   1, 2, SMALL_RADIANT,    0.05),
            Green(50, DREAM_DUST,   1, 2, GREATER_NETHER,  1, 2, LARGE_RADIANT,    0.05),
            Green(55, DREAM_DUST,   2, 5, LESSER_ETERNAL,  1, 2, SMALL_BRILLIANT,  0.05),
            Green(60, ILLUSION_DUST,1, 2, GREATER_ETERNAL, 1, 2, LARGE_BRILLIANT,  0.05),
            Green(65, ILLUSION_DUST,2, 5, GREATER_ETERNAL, 2, 3, LARGE_BRILLIANT,  0.05),
        },
        -- Rare (blue)
        [3] = {
            One(25, SMALL_GLIMMERING),
            One(30, LARGE_GLIMMERING),
            One(35, SMALL_GLOWING),
            One(40, LARGE_GLOWING),
            One(45, SMALL_RADIANT),
            One(50, LARGE_RADIANT),
            One(55, SMALL_BRILLIANT),
            { maxLevel = 65, armor = {
                { id = LARGE_BRILLIANT, chance = 0.995, min = 1, max = 1 },
                { id = NEXUS_CRYSTAL,   chance = 0.005, min = 1, max = 1 },
            } },
        },
        -- Epic (purple)
        [4] = {
            One(45, SMALL_RADIANT, 2, 4),
            One(50, LARGE_RADIANT, 2, 4),
            One(55, SMALL_BRILLIANT, 2, 4),
            One(60, NEXUS_CRYSTAL, 1),
            One(80, NEXUS_CRYSTAL, 1, 2),
        },
    },
}
