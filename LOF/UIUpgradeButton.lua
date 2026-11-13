-- =============================================================
-- LOF (LootOptimizer Forever) -- UIUpgradeButton.lua
-- Pure consumer: the small "Upgrade available" window (F17). Capture
-- hands it the state (UI.SetUpgradeButton: count, position, the selected
-- item from the resolver's waiting list); clicks go to LOF.Capture
-- (OpenNextUpgrade, StepUpgradeButton). No calculations or decisions here.
-- =============================================================
--
-- Changelog
-- ---------
-- v0.2.2: audit 1.6.8: DEBT(dup) marker (drag + position, O43).
-- v0.2.1: Peter's test, 9 Nov: < and > are the same red buttons as
--   "Upgrade available" (the spellbook arrows had no background); the
--   button shows the position, "Upgrade available (2/3)".
-- v0.2.0: Peter, 9 Nov: under the button the selected item's icon, framed
--   in the popup colour (own upgrade: the item's quality colour, as GEAR
--   UPGRADE; alt: ALT UPGRADE orange, Kit.POPUP_STYLES), with < and > to
--   browse when more wait. Hovering the icon shows the item tooltip (with
--   LOF's upgrade line). Clicking the button or the icon opens the popup
--   for that item. The whole window is dragged as one.
-- v0.1.0: Initial version (LOF 1.6.8, Peter 9 Nov; CurseForge request:
--   "the window often pops up while I am standing between angry mobs").
--   - One button: "Upgrade available", with "(2)" when more wait.
--   - Default spot: just below the minimap. Drag to move; the spot is
--     remembered (Kit.SavePosition, key "upgradebutton").
--   - Shown only while the count is above 0 (Capture hides it in combat
--     and while an upgrade popup is open).
-- =============================================================

local LOF = LOF
LOF.VERSION_UI_UPGRADEBUTTON = "0.2.2"

local UI = LOF.UI
local Kit = UI.Kit

local POS_KEY = "upgradebutton"
local WIN_W, BTN_H = 150, 22
local ICON = 28
local ARROW = 22

local win

local function StartDrag() win:StartMoving() end
local function StopDrag()
    win:StopMovingOrSizing()
    Kit.SavePosition(win, POS_KEY)
end

-- DEBT(dup): drag + SavePosition also in UI.lua CreatePanel (O43)
local function Draggable(f)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", StartDrag)
    f:SetScript("OnDragStop", StopDrag)
end

local function Arrow(parent, dir)
    local b = Kit.CreateButton(parent, dir < 0 and "<" or ">", ARROW)   -- v0.2.1
    b:SetHeight(ARROW)
    b:SetScript("OnClick", function() LOF.Capture.StepUpgradeButton(dir) end)
    Draggable(b)
    return b
end

local function Create()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(WIN_W, BTN_H + 4 + ICON)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    Draggable(f)

    f.button = Kit.CreateButton(f, "Upgrade available", WIN_W)
    f.button:SetHeight(BTN_H)
    f.button:SetPoint("TOP", f, "TOP", 0, 0)
    f.button:SetScript("OnClick", function() LOF.Capture.OpenNextUpgrade() end)
    f.button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Upgrade available")
        GameTooltip:AddLine("Click to see the comparison. < and > show the other upgrades.", 1, 1, 1, true)
        GameTooltip:AddLine("Drag to move. Settings > Upgrade Advisor to switch it off.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    f.button:SetScript("OnLeave", Kit.HideTooltip)
    Draggable(f.button)

    f.item = CreateFrame("Button", nil, f)
    f.item:SetSize(ICON, ICON)
    f.item:SetPoint("TOP", f.button, "BOTTOM", 0, -4)
    f.item.icon = f.item:CreateTexture(nil, "ARTWORK")
    f.item.icon:SetAllPoints(f.item)
    f.item.border = f.item:CreateTexture(nil, "OVERLAY")
    f.item.border:SetTexture("Interface\\Common\\WhiteIconFrame")
    f.item.border:SetAllPoints(f.item)
    f.item:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    f.item:SetScript("OnClick", function() LOF.Capture.OpenNextUpgrade() end)
    f.item:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        if self.bag and self.slot then
            GameTooltip:SetBagItem(self.bag, self.slot)
        elseif self.link then
            GameTooltip:SetHyperlink(self.link)
        end
        GameTooltip:Show()
    end)
    f.item:SetScript("OnLeave", Kit.HideTooltip)
    Draggable(f.item)

    f.prev = Arrow(f, -1)
    f.prev:SetPoint("RIGHT", f.item, "LEFT", -8, 0)
    f.next = Arrow(f, 1)
    f.next:SetPoint("LEFT", f.item, "RIGHT", 8, 0)

    if LOF.db.frames[POS_KEY] then
        Kit.RestorePosition(f, POS_KEY, "CENTER", 0, 0)
    else
        f:ClearAllPoints()
        if Minimap then
            f:SetPoint("TOP", Minimap, "BOTTOM", 0, -24)
        else
            f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -200)
        end
    end
    f:Hide()
    return f
end

-- state = { count, index, item = { icon, quality, kind, link, bag, slot } }
-- from Capture (resolver data); nil hides the window.
function UI.SetUpgradeButton(state)
    if type(state) ~= "table" or (tonumber(state.count) or 0) <= 0 or not state.item then
        if win then win:Hide() end
        return
    end
    win = win or Create()
    local n, it = state.count, state.item
    win.button:SetText(n > 1 and ("Upgrade available (" .. tostring(state.index) .. "/" .. n .. ")")
        or "Upgrade available")   -- v0.2.1
    win.item.icon:SetTexture(it.icon)
    if it.kind == "ALT" then
        local c = Kit.POPUP_STYLES.alt.border
        win.item.border:SetVertexColor(c[1], c[2], c[3])
    else
        win.item.border:SetVertexColor(Kit.GetQualityRGB(it.quality))
    end
    win.item.link, win.item.bag, win.item.slot = it.link, it.bag, it.slot
    win.prev:SetShown(n > 1)
    win.next:SetShown(n > 1)
    win:Show()
    if GameTooltip:GetOwner() == win.item then win.item:GetScript("OnEnter")(win.item) end
end
