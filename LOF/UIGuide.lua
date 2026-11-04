-- =============================================================
-- LOF (LootOptimizer Forever) -- UIGuide.lua
-- Pure consumer: the Guide window with two tabs, "What's new" and
-- "How to use". Renders LOF.Data.Guide (text only). When it opens by
-- itself is decided by Resolver.GetGuideTrigger (Capture asks).
-- =============================================================
--
-- Changelog
-- ---------
-- v0.3.0: How to use starts with a box linking to the website (Peter):
--   "For the full guide, information and more, visit our website" +
--   copy box. Address from LOF.Data.Guide.links.website; Kit.CreateInset
--   and Kit.CreateCopyBox (UI 1.17.13). Only on the How to use tab.
-- v0.2.3: White from the Kit (one constant).
-- v0.2.2: List pooling via Kit.GetPooled / HidePool (UI 1.17.0).
-- v0.2.1: The swatches read the popup styles of UI.lua
--   (Kit.GetPopupStyleColors / POPUP_STYLES): one place for every
--   colour, the legend always matches the popups. Own SWATCH table gone.
-- v0.2.0: Third tab "Colors" (Peter): per line a swatch in the popup's
--   real colours (border + background; the quality line shows the five
--   Blizzard quality colours), a title and the text from
--   LOF.Data.Guide.colors. Footer: "Settings > Guide". Tab keys:
--   whatsnew / howto / colors.
-- v0.1.1: Opened while Settings is open: next to it (right, or left
--   when there is no room) instead of on top of it (Peter). Clicking
--   the window brings it to the front (SetToplevel).
-- v0.1.0: Initial version (LOF 1.6.0, Peter: "a change log the first
--   time you log in with a new version"; later also the place for the
--   tutorial).
--   - Same look and fixed size as the Settings window. Tabs at the
--     top: What's new / How to use.
--   - What's new: per version a header (newest open, older closed;
--     click to open / close) with coloured bullets.
--   - How to use: the howTo lines with gold bullets.
--   - Footer: "Settings > General or /lof guide" and a "Got it" button.
--   - UI.ShowGuideWindow(tab, auto), UI.ToggleGuideWindow(tab),
--     UI.CloseGuideWindow() (moving: Capture; not when it opened by
--     itself), UI.HideGuideForCombat() / UI.RestoreGuideAfterCombat().
-- =============================================================

local LOF = LOF
LOF.VERSION_UI_GUIDE = "0.3.0"

local UI = LOF.UI
local Kit = UI.Kit

local GOLD, GREY = Kit.GOLD, Kit.GREY
local COLORS = UI.MARKUP_COLORS

local WIN_W, WIN_H = 560, 470
local TAB_W, TAB_H = 130, 24
local HEAD_H = 26
local BULLET_GAP = 6

local TABS = {
    { key = "whatsnew", label = "What's new" },
    { key = "howto",    label = "How to use" },
    { key = "colors",   label = "Colors" },   -- v0.2.0
}

-- v0.2.1: swatch colours come from UI.lua (Kit.GetPopupStyleColors).
local PLAIN_EDGE = { 0.45, 0.45, 0.45 }   -- a plain popup has no border: grey outline
local SWATCH_W, SWATCH_H, ROW_GAP = 70, 34, 8

local win

-- -------------------------------------------------------------
-- Pooled lines: a header (button) or a bullet (dot + text)
-- -------------------------------------------------------------
local GetPooled, HidePool = Kit.GetPooled, Kit.HidePool   -- v0.2.2: Kit helpers

local function CreateHeader()
    local h = CreateFrame("Button", nil, win.content)
    h:SetSize(win.listW, HEAD_H)
    h.hl = h:CreateTexture(nil, "HIGHLIGHT")
    h.hl:SetAllPoints(h)
    h.hl:SetColorTexture(1, 1, 1, 0.06)
    h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h.text:SetPoint("LEFT", h, "LEFT", 4, 0)
    h.text:SetJustifyH("LEFT")
    h.state = h:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    h.state:SetPoint("RIGHT", h, "RIGHT", -6, 0)
    h:SetScript("OnClick", function(self)
        win.open[self.version] = not win.open[self.version]
        UI.RefreshGuideWindow()
    end)
    return h
end

local function CreateBullet()
    local f = CreateFrame("Frame", nil, win.content)
    f:SetWidth(win.listW)
    f.dot = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.dot:SetPoint("TOPLEFT", f, "TOPLEFT", 14, 0)
    f.dot:SetText("•")
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.text:SetPoint("TOPLEFT", f, "TOPLEFT", 30, 0)
    f.text:SetWidth(win.listW - 36)
    f.text:SetJustifyH("LEFT")
    f.text:SetSpacing(2)
    return f
end

local function AddBullet(y, colorKey, text)
    local b = GetPooled(win.bullets, CreateBullet)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", win.content, "TOPLEFT", 0, y)
    b.dot:SetText((COLORS[colorKey] or GOLD) .. "•|r")
    b.text:SetText(Kit.FormatMarkup(text))
    local h = b.text:GetStringHeight()
    b:SetHeight(h)
    return y - h - BULLET_GAP
end

-- v0.2.0: one swatch box (dark like a popup, border + tint)
local function CreateBox(parent)
    local b = CreateFrame("Frame", nil, parent)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints(b)
    b.bg:SetColorTexture(0.08, 0.07, 0.06, 1)
    b.tint = b:CreateTexture(nil, "BORDER")
    b.tint:SetAllPoints(b)
    local function Edge() return b:CreateTexture(nil, "ARTWORK") end
    b.t, b.b, b.l, b.r = Edge(), Edge(), Edge(), Edge()
    b.t:SetPoint("TOPLEFT"); b.t:SetPoint("TOPRIGHT"); b.t:SetHeight(2)
    b.b:SetPoint("BOTTOMLEFT"); b.b:SetPoint("BOTTOMRIGHT"); b.b:SetHeight(2)
    b.l:SetPoint("TOPLEFT"); b.l:SetPoint("BOTTOMLEFT"); b.l:SetWidth(2)
    b.r:SetPoint("TOPRIGHT"); b.r:SetPoint("BOTTOMRIGHT"); b.r:SetWidth(2)
    return b
end

-- v0.2.1: paints a box in a popup style (key) and quality
local function PaintBox(b, key, quality)
    local _, border, tint = Kit.GetPopupStyleColors(key, quality)
    local e = border or PLAIN_EDGE
    for _, t in ipairs({ b.t, b.b, b.l, b.r }) do t:SetColorTexture(e[1], e[2], e[3], 1) end
    if tint then
        b.tint:SetColorTexture(tint[1], tint[2], tint[3], tint[4] or 0.3)
        b.tint:Show()
    else
        b.tint:Hide()
    end
end

local function CreateColorRow()
    local f = CreateFrame("Frame", nil, win.content)
    f:SetWidth(win.listW)
    f.box = CreateBox(f)
    f.box:SetPoint("TOPLEFT", f, "TOPLEFT", 4, 0)
    f.box:SetSize(SWATCH_W, SWATCH_H)
    f.minis = {}
    local w = math.floor((SWATCH_W - 4 * 3) / 5)
    for q = 0, 4 do
        local m = CreateBox(f)
        m:SetSize(w, SWATCH_H)
        m:SetPoint("TOPLEFT", f, "TOPLEFT", 4 + q * (w + 3), 0)
        f.minis[q] = m
    end
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", SWATCH_W + 16, 0)
    f.title:SetJustifyH("LEFT")
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.text:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
    f.text:SetWidth(win.listW - SWATCH_W - 24)
    f.text:SetJustifyH("LEFT")
    f.text:SetSpacing(2)
    return f
end

-- -------------------------------------------------------------
-- Pages
-- -------------------------------------------------------------
local function RenderWhatsNew()
    local data = LOF.Data.Guide.whatsNew or {}
    local y = 0
    for i, v in ipairs(data) do
        if win.open[v.version] == nil then win.open[v.version] = (i == 1) end
        local open = win.open[v.version]
        local h = GetPooled(win.headers, CreateHeader)
        h.version = v.version
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", win.content, "TOPLEFT", 0, y)
        h.text:SetText((open and "- " or "+ ") .. GOLD .. "Version " .. v.version .. "|r  "
            .. Kit.WHITE .. tostring(v.title or "") .. "|r")
        h.state:SetText(i == 1 and (GREY .. "latest|r") or "")
        y = y - HEAD_H - 2
        if open then
            for _, item in ipairs(v.items or {}) do
                y = AddBullet(y, item.color, item.text)
            end
            y = y - 6
        end
    end
    return y
end

local function RenderColors()   -- v0.2.0
    local y = -4
    for _, c in ipairs(LOF.Data.Guide.colors or {}) do
        local row = GetPooled(win.colorRows, CreateColorRow)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", win.content, "TOPLEFT", 0, y)
        local st = Kit.POPUP_STYLES[c.swatch]
        local quality = st and st.quality
        row.box:SetShown(not quality)
        for q = 0, 4 do
            local m = row.minis[q]
            m:SetShown(quality and true or false)
            if quality then PaintBox(m, c.swatch, q) end
        end
        if not quality then PaintBox(row.box, c.swatch) end
        row.title:SetText(tostring(c.title or ""))
        row.text:SetText(Kit.FormatMarkup(c.text))
        local h = math.max(SWATCH_H, row.title:GetStringHeight() + 3 + row.text:GetStringHeight())
        row:SetHeight(h)
        y = y - h - ROW_GAP
    end
    return y
end

-- v0.3.0: website box at the top of How to use (built once)
local SITE_BOX_H = 64
local function ShowSiteBox(y)
    if not win.siteBox then
        local b = Kit.CreateInset(win.content)
        b:SetSize(win.listW, SITE_BOX_H)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.text:SetPoint("TOPLEFT", b, "TOPLEFT", 10, -9)
        b.text:SetWidth(win.listW - 20)
        b.text:SetJustifyH("LEFT")
        b.text:SetText("For the full guide, information and more, visit our website (Ctrl+C to copy):")
        b.copy = Kit.CreateCopyBox(b, win.listW - 30)
        b.copy:SetPoint("TOPLEFT", b.text, "BOTTOMLEFT", 6, -5)
        win.siteBox = b
    end
    local links = LOF.Data.Guide.links or {}
    win.siteBox.copy:SetFixedText(tostring(links.website or ""))
    win.siteBox:ClearAllPoints()
    win.siteBox:SetPoint("TOPLEFT", win.content, "TOPLEFT", 0, y)
    win.siteBox:Show()
    return y - SITE_BOX_H - 10
end

local function RenderHowTo()
    local y = ShowSiteBox(-4)   -- v0.3.0
    for _, line in ipairs(LOF.Data.Guide.howTo or {}) do
        y = AddBullet(y, "gold", line)
    end
    return y
end

-- -------------------------------------------------------------
-- Window
-- -------------------------------------------------------------
local function SelectTab(key)
    win.tab = key
    win.scroll:SetVerticalScroll(0)
    UI.RefreshGuideWindow()
end

local function BuildWindow()
    win = Kit.CreateStyledPanel("LOF_GuideFrame", "guide", WIN_W, WIN_H, "HIGH")
    win:SetFrameStrata("HIGH")
    if win.SetToplevel then win:SetToplevel(true) end   -- v0.1.1
    if win.Inset then win.Inset:Hide() end
    if not win.CloseButton then
        win.close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
        win.close:SetPoint("TOPRIGHT", win, "TOPRIGHT", 0, 0)
    end
    if _G.UISpecialFrames then tinsert(_G.UISpecialFrames, "LOF_GuideFrame") end
    win:SetScript("OnHide", function(self) self.auto = nil end)
    Kit.SetPanelTitle(win, "LootOptimizer Forever - Guide")
    local top = win.styled and -30 or -10

    win.tabs = {}
    for i, t in ipairs(TABS) do
        local b = CreateFrame("Button", nil, win)
        b:SetSize(TAB_W, TAB_H)
        b:SetPoint("TOPLEFT", win, "TOPLEFT", 14 + (i - 1) * (TAB_W + 6), top - 4)
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints(b)
        b.bar = b:CreateTexture(nil, "ARTWORK")
        b.bar:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
        b.bar:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
        b.bar:SetHeight(2)
        b.bar:SetColorTexture(1, 0.82, 0, 0.9)
        b.hl = b:CreateTexture(nil, "HIGHLIGHT")
        b.hl:SetAllPoints(b)
        b.hl:SetColorTexture(1, 1, 1, 0.08)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        b.text:SetPoint("CENTER")
        b.text:SetText(t.label)
        b.key = t.key
        b:SetScript("OnClick", function(self) SelectTab(self.key) end)
        win.tabs[i] = b
    end

    win.box = Kit.CreateInset(win)
    win.box:SetPoint("TOPLEFT", win, "TOPLEFT", 10, top - 4 - TAB_H - 6)
    win.box:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -10, 44)

    win.scroll = CreateFrame("ScrollFrame", nil, win.box, "UIPanelScrollFrameTemplate")
    win.scroll:SetPoint("TOPLEFT", win.box, "TOPLEFT", 10, -10)
    win.scroll:SetPoint("BOTTOMRIGHT", win.box, "BOTTOMRIGHT", -30, 10)
    win.scroll.scrollBarHideable = true
    win.listW = WIN_W - 20 - 10 - 30
    win.content = CreateFrame("Frame", nil, win.scroll)
    win.content:SetSize(win.listW, 10)
    win.scroll:SetScrollChild(win.content)

    win.footer = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    win.footer:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 16, 18)
    win.footer:SetText("Open again: Settings > Guide, or /lof guide")   -- v0.2.0

    win.gotIt = Kit.CreateButton(win, "Got it", 110)
    win.gotIt:SetHeight(22)
    win.gotIt:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -14, 14)
    win.gotIt:SetScript("OnClick", function() win:Hide() end)

    win.headers = { used = 0 }
    win.bullets = { used = 0 }
    win.colorRows = { used = 0 }   -- v0.2.0
    win.open = {}
    win.tab = "whatsnew"
    win:Hide()
end

function UI.RefreshGuideWindow()
    if not win or not win:IsShown() then return end
    for _, b in ipairs(win.tabs) do
        local on = b.key == win.tab
        b.bg:SetColorTexture(1, 0.82, 0, on and 0.16 or 0.04)
        b.bar:SetShown(on)
        if on then b.text:SetTextColor(1, 1, 1) else b.text:SetTextColor(1, 0.82, 0) end
    end
    win.headers.used, win.bullets.used, win.colorRows.used = 0, 0, 0
    if win.siteBox then win.siteBox:Hide() end   -- v0.3.0: How to use shows it again
    local y
    if win.tab == "howto" then
        y = RenderHowTo()
    elseif win.tab == "colors" then   -- v0.2.0
        y = RenderColors()
    else
        y = RenderWhatsNew()
    end
    HidePool(win.headers)
    HidePool(win.bullets)
    HidePool(win.colorRows)
    win.content:SetHeight(math.max(10, -y))
end

-- v0.1.1: Settings open -> stand next to it, right if it fits, else left.
local function PlaceNextToSettings()
    local sf = UI.GetSettingsFrame and UI.GetSettingsFrame()
    if not (sf and sf:IsShown()) then return end
    local sScale = sf:GetEffectiveScale() or 1
    local right = (sf:GetRight() or 0) * sScale
    local left = (sf:GetLeft() or 0) * sScale
    local need = WIN_W * (win:GetEffectiveScale() or 1) + 8
    local screen = (UIParent:GetRight() or 0) * (UIParent:GetEffectiveScale() or 1)
    win:ClearAllPoints()
    if right + need <= screen or left < need then
        win:SetPoint("TOPLEFT", sf, "TOPRIGHT", 8, 0)
    else
        win:SetPoint("TOPRIGHT", sf, "TOPLEFT", -8, 0)
    end
end

-- tab: "whatsnew" | "howto" | "colors"; auto: opened by itself at login
function UI.ShowGuideWindow(tab, auto)
    if not win then BuildWindow() end
    win.tab = tab or win.tab or "whatsnew"
    if not win:IsShown() then
        Kit.ApplyAutoScale(win, "guide", "CENTER", 0, 40)
        PlaceNextToSettings()
        win:Show()
    end
    if win.Raise then win:Raise() end
    win.auto = auto and true or nil
    win.scroll:SetVerticalScroll(0)
    UI.RefreshGuideWindow()
end

function UI.ToggleGuideWindow(tab)
    if win and win:IsShown() then
        win:Hide()
        return
    end
    UI.ShowGuideWindow(tab, false)
end

-- Moving (Capture): only a Guide the player opened himself closes;
-- one that opened by itself at login stays until he closes it.
function UI.CloseGuideWindow()
    if win and win:IsShown() and not win.auto then win:Hide() end
end

-- Combat (Capture): hide; an automatic Guide comes back afterwards.
local combatTab = nil

function UI.HideGuideForCombat()
    if not (win and win:IsShown()) then return false end
    local wasAuto = win.auto
    combatTab = wasAuto and win.tab or nil
    win:Hide()
    return wasAuto == true
end

function UI.RestoreGuideAfterCombat()
    local tab = combatTab
    combatTab = nil
    if tab then UI.ShowGuideWindow(tab, true) end
end
