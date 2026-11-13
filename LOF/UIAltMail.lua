-- =============================================================
-- LOF (LootOptimizer Forever) -- UIAltMail.lua
-- Pure consumer: the "Send to alts" window. Renders
-- LOF.Resolver.Upgrade.GetAltMailSnapshot() (bag items that are an
-- upgrade for an alt, grouped per alt, with the mail action the
-- resolver decided) and forwards a click to
-- LOF.Capture.AttachUpgradeToMail. No calculations or decisions here.
-- =============================================================
--
-- Changelog
-- ---------
-- v0.1.5: E28: "(train Staves)" when the alt has not trained the weapon
--   type (resolver field needTraining).
-- v0.1.4: Under each item the compact stat line ("+6.2 damage per
--   second   +1 Spell Power"; Kit.StatChangeLines, the same as in item
--   tooltips; ResolverUpgrade 0.13.3 hands the rows over). Rows grow per
--   stat line. ORANGE / WHITE from the Kit.
-- v0.1.3: Kit helpers instead of own copies (UI 1.17.0): ClassColored,
--   GainText, GetPooled / HidePool.
-- v0.1.2: Combat (Capture 1.7.1): UI.HideAltMailForCombat() hides the
--   window and reports whether it was open; UI.RestoreAltMailAfterCombat()
--   shows it again (not when it opened by itself and the mailbox has
--   closed meanwhile).
-- v0.1.1: With the mailbox open (also on the Inbox tab) the hint reads
--   "Click an item to put it in the mail": LOF opens the Send Mail tab
--   itself (Capture 1.6.1). New text for NO_SEND_TAB.
-- v0.1.0: Initial version (LOF 1.4.0, Peter: "at the mailbox I have to
--   search my bags for the upgrades for my Priest").
--   - Opened from Recent Loot > Upgrade, or by itself next to the mail
--     when the mailbox opens and there is something to send (setting
--     in the Upgrade Advisor box). Closes with the mailbox when it
--     opened by itself.
--   - Per alt a header (class colour, class and level), under it the
--     items: icon, name, gain ("+6.2%" / "empty slot"), what it
--     replaces, "(at level X)"; a white dotted line between the alts.
--     An item that is an upgrade for two alts is listed under both:
--     the header you click under decides who gets it.
--   - Click with the Send Mail tab open: the item goes into the mail
--     and the recipient is filled in. LOF never presses Send.
--   - Same screen-relative scale as Holdings (Kit.ApplyAutoScale).
-- =============================================================

local LOF = LOF
LOF.VERSION_UI_ALTMAIL = "0.1.5"

local UI = LOF.UI
local Resolver = LOF.Resolver
local Kit = UI.Kit

local GOLD, GREEN, GREY = Kit.GOLD, Kit.GREEN, Kit.GREY
local ORANGE, WHITE = Kit.ORANGE, Kit.WHITE   -- v0.1.4: from the Kit

local WIN_W, WIN_H = 380, 420
local HEAD_H  = 22
local ITEM_H  = 34
local STAT_LINE_H = 13   -- v0.1.4: one compact stat line
local SEP_H   = 14
local ICON    = 26

local win

-- -------------------------------------------------------------
-- Text for the resolver's action codes
-- -------------------------------------------------------------
local ClassColored = Kit.ClassColored   -- v0.1.3: the Kit helper

local function ResultText(action, item)
    local code = action and action.code
    local name = item and (LOF.ColorizeName(item.name, item.quality)) or "Item"
    if code == "ATTACH" then
        return GREEN .. "In the mail:|r " .. name .. " for " .. tostring(item.altName)
            .. GREY .. " - press Send when ready.|r"
    elseif code == "NO_MAILBOX" then
        return ORANGE .. "Open a mailbox first.|r"
    elseif code == "NO_SEND_TAB" then
        return ORANGE .. "Could not open the Send Mail tab: click it yourself and try again.|r"
    elseif code == "MAIL_FULL" then
        return ORANGE .. "This mail is full: send it first.|r"
    elseif code == "OTHER_RECIPIENT" then
        return ORANGE .. "This mail is for " .. tostring(action.recipient) .. ": send it first.|r"
    elseif code == "IN_MAIL" then
        return GREY .. "Already in the mail.|r"
    elseif code == "COMBAT" then
        return ORANGE .. "Not during combat.|r"
    elseif code == "MOVED" or code == "LOCKED" then
        return ORANGE .. "The item moved or changed: try again.|r"
    elseif code == "FAILED" then
        return ORANGE .. "Could not put the item in the mail.|r"
    end
    return ""
end

local function ClickHint(action)
    local code = action and action.code
    if code == "ATTACH" then return "Click: put it in the mail.", 0.4, 1, 0.4 end
    if code == "IN_MAIL" then return "In the mail.", 0.7, 0.7, 0.7 end
    if code == "NO_MAILBOX" then return "Open a mailbox to send it.", 0.7, 0.7, 0.7 end
    if code == "OTHER_RECIPIENT" then
        return "This mail is for " .. tostring(action.recipient) .. ": send it first.", 1, 0.6, 0.2
    end
    if code == "MAIL_FULL" then return "This mail is full: send it first.", 1, 0.6, 0.2 end
    return nil
end

local function GainText(item)   -- v0.1.3: Kit.GainText
    return Kit.GainText(item, GREEN, "")
end

local function SubText(item)
    local parts = {}
    local function nameOf(link)
        local n = link and LOF.GetItemInfo(link)
        return n or nil
    end
    local r1, r2 = nameOf(item.replacesLink), nameOf(item.replacesOffLink)
    if r1 and r2 then
        parts[#parts + 1] = "replaces " .. r1 .. " + " .. r2
    elseif r1 or r2 then
        parts[#parts + 1] = "replaces " .. (r1 or r2)
    end
    if item.tooLow and item.needLevel then
        parts[#parts + 1] = ORANGE .. "(at level " .. item.needLevel .. ")|r"
    end
    if item.needTraining then   -- v0.1.5 (E28)
        parts[#parts + 1] = ORANGE .. "(train " .. item.needTraining .. ")|r"
    end
    return GREY .. table.concat(parts, "  ") .. "|r"
end

-- -------------------------------------------------------------
-- Rows (pooled)
-- -------------------------------------------------------------
local function CreateHeader(parent, width)
    local h = CreateFrame("Frame", nil, parent)
    h:SetSize(width, HEAD_H)
    h.sep = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    h.sep:SetPoint("BOTTOMLEFT", h, "TOPLEFT", 0, 2)
    h.sep:SetWidth(width)
    h.sep:SetJustifyH("LEFT")
    h.sep:SetWordWrap(false)
    h.sep:SetText(WHITE .. string.rep(". ", 90) .. "|r")
    h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h.text:SetPoint("LEFT", h, "LEFT", 2, 0)
    h.text:SetJustifyH("LEFT")
    return h
end

local function CreateItemRow(parent, width)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(width, ITEM_H)
    row:RegisterForClicks("LeftButtonUp")

    row.hl = row:CreateTexture(nil, "HIGHLIGHT")
    row.hl:SetAllPoints(row)
    row.hl:SetColorTexture(1, 1, 1, 0.08)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON, ICON)
    row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -4)   -- v0.1.4: rows can be taller
    row.border = row:CreateTexture(nil, "OVERLAY")
    row.border:SetTexture("Interface\\Common\\WhiteIconFrame")
    row.border:SetAllPoints(row.icon)

    row.gain = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.gain:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -4)
    row.gain:SetJustifyH("RIGHT")

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.status:SetPoint("TOPRIGHT", row.gain, "BOTTOMRIGHT", 0, -4)
    row.status:SetJustifyH("RIGHT")

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, 0)
    row.name:SetPoint("RIGHT", row.gain, "LEFT", -6, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.sub = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
    row.sub:SetPoint("RIGHT", row.status, "LEFT", -6, 0)
    row.sub:SetJustifyH("LEFT")
    row.sub:SetWordWrap(false)

    -- v0.1.4: the compact stat line(s) (Kit.StatChangeLines, as in tooltips)
    row.stats = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.stats:SetPoint("TOPLEFT", row.sub, "BOTTOMLEFT", 0, -3)
    row.stats:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.stats:SetJustifyH("LEFT")
    row.stats:SetSpacing(2)

    row:SetScript("OnEnter", function(self)
        local item = self.item
        if not item then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetBagItem(item.bag, item.slot)
        local hint, r, g, b = ClickHint(item.action)
        if hint then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("For " .. tostring(item.altName) .. ": " .. hint, r, g, b, true)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", Kit.HideTooltip)
    row:SetScript("OnClick", function(self)
        local item = self.item
        if not item then return end
        local result = LOF.Capture.AttachUpgradeToMail(item.bag, item.slot, item.link, item.altName)
        win.status:SetText(ResultText(result, item))
        LOF.RequestRefresh()
    end)
    return row
end

local GetPooled, HidePool = Kit.GetPooled, Kit.HidePool   -- v0.1.3: Kit helpers

-- -------------------------------------------------------------
-- Window
-- -------------------------------------------------------------
local function BuildWindow()
    win = Kit.CreateStyledPanel("LOF_AltMailFrame", "altmail", WIN_W, WIN_H, "HIGH")
    win:SetFrameStrata("HIGH")
    if win.Inset then win.Inset:Hide() end
    if not win.CloseButton then
        win.close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
        win.close:SetPoint("TOPRIGHT", win, "TOPRIGHT", 0, 0)
    end
    if _G.UISpecialFrames then tinsert(_G.UISpecialFrames, "LOF_AltMailFrame") end
    win:SetScript("OnHide", function(self) self.autoOpened = nil end)
    Kit.SetPanelTitle(win, "LootOptimizer Forever - Send to alts")

    local top = win.styled and -30 or -10

    win.hint = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    win.hint:SetPoint("TOPLEFT", win, "TOPLEFT", 14, top - 4)
    win.hint:SetPoint("RIGHT", win, "RIGHT", -14, 0)
    win.hint:SetJustifyH("LEFT")

    win.box = Kit.CreateInset(win)
    win.box:SetPoint("TOPLEFT", win, "TOPLEFT", 10, top - 22)
    win.box:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -10, 30)

    win.scroll = CreateFrame("ScrollFrame", nil, win.box, "UIPanelScrollFrameTemplate")
    win.scroll:SetPoint("TOPLEFT", win.box, "TOPLEFT", 6, -8)
    win.scroll:SetPoint("BOTTOMRIGHT", win.box, "BOTTOMRIGHT", -28, 8)
    win.listW = WIN_W - 20 - 6 - 28
    win.content = CreateFrame("Frame", nil, win.scroll)
    win.content:SetSize(win.listW, 10)
    win.scroll:SetScrollChild(win.content)

    win.empty = win.content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    win.empty:SetPoint("TOPLEFT", win.content, "TOPLEFT", 4, -4)
    win.empty:SetWidth(win.listW - 8)
    win.empty:SetJustifyH("LEFT")

    win.status = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    win.status:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 14, 10)
    win.status:SetPoint("RIGHT", win, "RIGHT", -14, 0)
    win.status:SetJustifyH("LEFT")
    win.status:SetWordWrap(false)

    win.headers = { used = 0 }
    win.items = { used = 0 }
    win:Hide()
end

local function HintText(snap)
    if not snap.enabled then
        return GREY .. "The Upgrade Advisor is off for this character (Settings).|r"
    end
    if not snap.mailOpen then
        return GREY .. "At a mailbox: click an item to put it in the mail.|r"
    end
    if snap.recipient and snap.recipient ~= "" and (snap.attachedCount or 0) > 0 then
        return GOLD .. "Mail to " .. snap.recipient .. ":|r " .. snap.attachedCount
            .. " item(s). " .. GREY .. "Press Send when ready.|r"
    end
    return GOLD .. "Click an item to put it in the mail.|r"
end

function UI.RefreshAltMailWindow()
    if not win or not win:IsShown() then return end
    local snap = Resolver.Upgrade.GetAltMailSnapshot()
    win.hint:SetText(HintText(snap))

    win.headers.used, win.items.used = 0, 0
    local y = 0
    for gi, g in ipairs(snap.groups) do
        if gi > 1 then y = y - SEP_H end
        local h = GetPooled(win.headers, CreateHeader, win.content, win.listW)
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", win.content, "TOPLEFT", 0, y)
        h.sep:SetShown(gi > 1)
        h.text:SetText(ClassColored(g.name, g.class) .. GREY .. "  "
            .. tostring(g.className or "") .. " " .. tostring(g.level or "") .. "|r")
        h:Show()
        y = y - HEAD_H
        for _, item in ipairs(g.items) do
            local row = GetPooled(win.items, CreateItemRow, win.content, win.listW)
            row.item = item
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", win.content, "TOPLEFT", 0, y)
            row.icon:SetTexture(item.icon)
            local r, gg, b = Kit.GetQualityRGB(item.quality)
            row.border:SetVertexColor(r, gg, b)
            local label = LOF.ColorizeName(item.name, item.quality)
            if (tonumber(item.count or 1) or 1) > 1 then label = label .. GREY .. " x" .. item.count .. "|r" end
            row.name:SetText(label)
            row.gain:SetText(GainText(item))
            row.sub:SetText(SubText(item))
            local statLines = Kit.StatChangeLines(item.statRows, "") or {}   -- v0.1.4
            row.stats:SetText(table.concat(statLines, "\n"))
            row.stats:SetShown(#statLines > 0)
            local rowH = ITEM_H + #statLines * STAT_LINE_H
            row:SetHeight(rowH)
            local code = item.action and item.action.code
            if code == "IN_MAIL" then
                row.status:SetText(GREY .. "in mail|r")
                row:SetAlpha(0.55)
            else
                row.status:SetText("")
                row:SetAlpha(1)
            end
            row:Show()
            y = y - rowH
        end
    end
    HidePool(win.headers)
    HidePool(win.items)

    if #snap.groups == 0 then
        win.empty:SetText(snap.enabled and "No upgrades for your alts in your bags." or "")
        win.empty:Show()
        y = -20
    else
        win.empty:Hide()
    end
    win.content:SetHeight(math.max(10, -y))
end

-- auto = true: opened by the mailbox (next to the mail, closes with it)
function UI.ShowAltMailWindow(auto)
    if not win then BuildWindow() end
    if win:IsShown() then
        UI.RefreshAltMailWindow()
        return
    end
    Kit.ApplyAutoScale(win, "altmail", "CENTER", 0, 0)
    if auto and _G.MailFrame and MailFrame:IsShown() then
        win:ClearAllPoints()
        win:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 12, 0)
    end
    win.status:SetText("")
    win:Show()
    win.autoOpened = auto and true or nil
    UI.RefreshAltMailWindow()
end

function UI.ToggleAltMailWindow()
    if win and win:IsShown() then
        win:Hide()
        return
    end
    UI.ShowAltMailWindow(false)
end

-- v0.1.2: combat hide / restore (Capture decides when)
local combatAuto = nil

function UI.HideAltMailForCombat()
    if not (win and win:IsShown()) then return false end
    combatAuto = win.autoOpened
    win:Hide()
    return true
end

function UI.RestoreAltMailAfterCombat()
    if not win or win:IsShown() then return end
    local auto = combatAuto
    combatAuto = nil
    if auto and not (_G.MailFrame and MailFrame:IsShown()) then return end
    win:Show()
    win.autoOpened = auto
    UI.RefreshAltMailWindow()
end

function UI.OnMailClosed()
    if win and win:IsShown() then
        if win.autoOpened then
            win:Hide()
        else
            UI.RefreshAltMailWindow()
        end
    end
end
