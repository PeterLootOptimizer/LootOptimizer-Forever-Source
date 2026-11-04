-- =============================================================
-- LOF (LootOptimizer Forever) -- UIReagents.lua
-- Pure consumer: the Reagents list (Settings window). Renders
-- LOF.Resolver.Reagents.GetWindowSnapshot() (the current character's
-- professions with their lootable materials, the useful skill range
-- and whether LOF keeps each one) and forwards a click to
-- LOF.Resolver.Reagents.SetChoice. No calculations or decisions here.
-- =============================================================
--
-- Changelog
-- ---------
-- v0.2.5: WHITE comes from the Kit (one constant).
-- v0.2.4: List pooling via Kit.GetPooled / HidePool (UI 1.17.0).
-- v0.2.3: Range legend in skill terms (Peter): "Green: skill points
--   possible. White: needs more skill. Grey: no more skill points."
-- v0.2.2: Range in three colours (ResolverReagents 0.1.2): green = now,
--   white = later, grey = no more skill. Hint line says so.
-- v0.2.1: Empty text no longer says "lootable" (crafted intermediates
--   are in the list too, Data/ProfessionReagents 0.2.0).
-- v0.2.0: No window of its own any more (Settings window, LOF 1.6.0):
--   UI.BuildReagentsPanel(parent, width, top) builds the list inside
--   the Settings window, topic "Reagents"; UI.RenderReagentsPanel(rp)
--   renders it. UI.ToggleReagentsWindow / RefreshReagentsWindow and
--   the "Choose reagents..." button are gone. Rows, texts and clicks
--   unchanged.
-- v0.1.1: Clearer texts (Peter): "Checked: always keep ... Unchecked:
--   normal rules (by value)"; row tooltips "Click: normal rules" /
--   "Click: always keep". Hint has three to four lines: list starts lower.
-- v0.1.0: Initial version (LOF 1.6.0, reagents in the swap).
--   - Opened from Settings > Reagents > "Choose reagents...".
--   - Per profession a header ("Blacksmithing  skill 45"), under it the
--     materials: check box (kept or not), icon, name, the skill range
--     in which it is useful ("1 - 50", green while useful now, grey
--     otherwise, "any" when the range is unknown). Useful now first.
--   - Click a row: keep / stop keeping it. A choice that differs from
--     LOF's default is marked "your choice" (gold); choosing the
--     default again makes it automatic.
--   - Item tooltip on hover. Same screen-relative scale as Holdings.
-- =============================================================

local LOF = LOF
LOF.VERSION_UI_REAGENTS = "0.2.5"

local UI = LOF.UI
local Resolver = LOF.Resolver
local Kit = UI.Kit

local GOLD, GREEN, GREY, TEAL = Kit.GOLD, Kit.GREEN, Kit.GREY, Kit.TEAL
local WHITE = Kit.WHITE   -- v0.2.5: from the Kit

local HINT_H = 58   -- three or four hint lines above the list
local HEAD_H = 22
local ROW_H  = 20
local SEP_H  = 10
local ICON   = 16

-- -------------------------------------------------------------
-- Rows (pooled)
-- -------------------------------------------------------------
local function CreateHeader(parent, width)
    local h = CreateFrame("Frame", nil, parent)
    h:SetSize(width, HEAD_H)
    h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h.text:SetPoint("LEFT", h, "LEFT", 2, 0)
    h.text:SetJustifyH("LEFT")
    return h
end

local function CreateRow(parent, width)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(width, ROW_H)
    row:RegisterForClicks("LeftButtonUp")

    row.hl = row:CreateTexture(nil, "HIGHLIGHT")
    row.hl:SetAllPoints(row)
    row.hl:SetColorTexture(1, 1, 1, 0.08)

    row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.check:SetSize(20, 20)
    row.check:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.check:EnableMouse(false)   -- the row takes the click

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON, ICON)
    row.icon:SetPoint("LEFT", row.check, "RIGHT", 2, 0)

    row.range = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.range:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.range:SetJustifyH("RIGHT")

    row.mark = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.mark:SetPoint("RIGHT", row, "RIGHT", -56, 0)
    row.mark:SetJustifyH("RIGHT")

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetPoint("RIGHT", row.mark, "LEFT", -6, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row:SetScript("OnEnter", function(self)
        local item = self.item
        if not item then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if item.link then
            GameTooltip:SetHyperlink(item.link)
        else
            GameTooltip:SetHyperlink("item:" .. item.itemID)
        end
        GameTooltip:AddLine(" ")
        if item.on then
            GameTooltip:AddLine("Kept: never deleted, offered for a swap. Click: normal rules.", 0.2, 0.84, 0.76, true)
        else
            GameTooltip:AddLine("Normal rules (by value). Click: always keep.", 0.7, 0.7, 0.7, true)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", Kit.HideTooltip)
    row:SetScript("OnClick", function(self)
        local item = self.item
        if not item then return end
        Resolver.Reagents.SetChoice(item.itemID, not item.on)
        LOF.RequestRefresh()
    end)
    return row
end

local GetPooled, HidePool = Kit.GetPooled, Kit.HidePool   -- v0.2.4: Kit helpers

local function RangeText(item)
    local color = (item.rangeState == "now" and GREEN) or (item.rangeState == "later" and WHITE) or GREY
    if not item.usefulTo then
        return color .. "any|r"
    end
    return color .. item.lowest .. " - " .. item.usefulTo .. "|r"
end

-- -------------------------------------------------------------
-- Panel (v0.2.0): built inside the Settings window (UISettings.lua),
-- topic "Reagents". parent = the page frame, width = its width.
-- -------------------------------------------------------------
function UI.BuildReagentsPanel(parent, width, top)
    local rp = CreateFrame("Frame", nil, parent)
    rp:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, top or 0)
    rp:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    rp.hint = rp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rp.hint:SetPoint("TOPLEFT", rp, "TOPLEFT", 4, 0)
    rp.hint:SetWidth(width - 8)
    rp.hint:SetJustifyH("LEFT")
    rp.hint:SetSpacing(2)

    rp.box = Kit.CreateInset(rp)
    rp.box:SetPoint("TOPLEFT", rp, "TOPLEFT", 0, -HINT_H)
    rp.box:SetPoint("BOTTOMRIGHT", rp, "BOTTOMRIGHT", 0, 0)

    rp.scroll = CreateFrame("ScrollFrame", nil, rp.box, "UIPanelScrollFrameTemplate")
    rp.scroll:SetPoint("TOPLEFT", rp.box, "TOPLEFT", 6, -8)
    rp.scroll:SetPoint("BOTTOMRIGHT", rp.box, "BOTTOMRIGHT", -28, 8)
    rp.listW = width - 6 - 28
    rp.content = CreateFrame("Frame", nil, rp.scroll)
    rp.content:SetSize(rp.listW, 10)
    rp.scroll:SetScrollChild(rp.content)

    rp.empty = rp.content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    rp.empty:SetPoint("TOPLEFT", rp.content, "TOPLEFT", 4, -4)
    rp.empty:SetWidth(rp.listW - 8)
    rp.empty:SetJustifyH("LEFT")

    rp.headers = { used = 0 }
    rp.rows = { used = 0 }
    return rp
end

local function HintText(snap)
    if not snap.enabled then
        return GREY .. "Off: every item is handled by value. Switch on above.|r"
    end
    return WHITE .. "Checked: always keep. Never deleted; offered for a swap when bags are full.|r\n"
        .. WHITE .. "Unchecked: normal rules (by value).|r" .. GREY .. " This character only.|r\n"
        .. GREEN .. "Green|r" .. GREY .. ": skill points possible. |r" .. WHITE .. "White|r"
        .. GREY .. ": needs more skill. Grey: no more skill points.|r"
end

function UI.RenderReagentsPanel(rp)
    if not rp or not rp:IsVisible() then return end
    local snap = Resolver.Reagents.GetWindowSnapshot()
    rp.hint:SetText(HintText(snap))
    local alpha = snap.enabled and 1 or 0.5

    rp.headers.used, rp.rows.used = 0, 0
    local y = 0
    for gi, g in ipairs(snap.professions) do
        if gi > 1 then y = y - SEP_H end
        local h = GetPooled(rp.headers, CreateHeader, rp.content, rp.listW)
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", rp.content, "TOPLEFT", 0, y)
        h.text:SetText(TEAL .. tostring(g.name) .. "|r" .. GREY .. "  skill " .. tostring(g.level) .. "|r")
        h:SetAlpha(alpha)
        h:Show()
        y = y - HEAD_H
        for _, item in ipairs(g.rows) do
            local row = GetPooled(rp.rows, CreateRow, rp.content, rp.listW)
            row.item = item
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", rp.content, "TOPLEFT", 0, y)
            row.check:SetChecked(item.on)
            row.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.name:SetText(LOF.ColorizeName(item.name, item.quality))
            row.mark:SetText(item.userSet and (GOLD .. "your choice|r") or "")
            row.range:SetText(RangeText(item))
            row:SetAlpha(alpha)
            row:Show()
            y = y - ROW_H
        end
    end
    HidePool(rp.headers)
    HidePool(rp.rows)

    if #snap.professions == 0 then
        rp.empty:SetText("This character has no profession that uses reagents "
            .. "(Alchemy, Blacksmithing, Cooking, Enchanting, Engineering, First Aid, Leatherworking, Tailoring).")
        rp.empty:Show()
        y = -40
    else
        rp.empty:Hide()
    end
    rp.content:SetHeight(math.max(10, -y))
end
