-- TalentKeeper on the talent window: your builds in a strip under it. Hover one to see on the
-- tree what it would change (marks on the talents themselves); click it to apply.
local _, TK = ...
local B, C, UI = TK.builds, TK.compare, TK.ui
local W = {}
TK.window = W

local COLOR = { add = { 0.596, 1, 0.596 }, rem = { 1, 0.533, 0.533 }, swap = { 1, 0.722, 0.302 } }
local SIGN = { add = "+", rem = "-", swap = "~" }

local tf, marks = nil, {}

-- Marks on the tree --------------------------------------------------------------------
local function colorRing(frame)
    local edges = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = frame:CreateTexture(nil, "OVERLAY")
        t:SetTexelSnappingBias(0); t:SetSnapToPixelGrid(false)
        if side == "TOP" or side == "BOTTOM" then
            t:SetPoint(side .. "LEFT"); t:SetPoint(side .. "RIGHT"); t:SetHeight(2)
        else
            t:SetPoint("TOP" .. side); t:SetPoint("BOTTOM" .. side); t:SetWidth(2)
        end
        edges[#edges + 1] = t
    end
    return function(r, g, b) for _, t in ipairs(edges) do t:SetColorTexture(r, g, b, 1) end end
end

local function mark(i)
    if marks[i] then return marks[i] end
    local m = CreateFrame("Frame", nil, tf)
    m.setRing = colorRing(m)
    m.badge = CreateFrame("Frame", nil, m)
    m.badge:SetSize(14, 14)
    m.badge:SetPoint("CENTER", m, "TOPRIGHT", -2, -2)
    m.badge.bg = m.badge:CreateTexture(nil, "OVERLAY")
    m.badge.bg:SetAllPoints()
    m.badge.text = m.badge:CreateFontString(nil, "OVERLAY", "TalentKeeperFont")
    m.badge.text:SetPoint("CENTER", 0, 1)
    m.badge.text:SetTextColor(0.031, 0.031, 0.031)
    m.label = m:CreateFontString(nil, "OVERLAY", "TalentKeeperFontLarge")
    m.label:SetPoint("TOP", m, "BOTTOM", 0, -4)
    m.label:SetTextColor(1, 0.722, 0.302)
    marks[i] = m
    return m
end

function W.hide()
    for _, m in ipairs(marks) do m:Hide() end
end

-- How a node changes from your talents to the build's.
local function kind(c) return not c.from and "add" or not c.to and "rem" or "swap" end

-- Mark what applying b would change; returns the changes and how many have no button on show.
local LTT = LibStub and LibStub("LibTalentTree-1.0", true)
local function lib(node) return LTT and LTT:GetLibNodeInfo(node) end

local function place(m, target, k)
    local col = COLOR[k]
    m:SetFrameStrata(target:GetFrameStrata())
    m:SetFrameLevel(target:GetFrameLevel() + 10)
    m:ClearAllPoints()
    m:SetPoint("TOPLEFT", target, "TOPLEFT", -3, 3)
    m:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 3, -3)
    m.setRing(col[1], col[2], col[3])
    m.badge.bg:SetColorTexture(col[1], col[2], col[3], 1)
    m.badge.text:SetText(SIGN[k])
    m.label:SetText("")
    m:Show()
end

-- Mark what applying b would change; returns the changes and how many have no button on show.
-- Another hero tree is one mark on the hero tree's emblem, not a mark on every hero talent.
function W.show(b)
    W.hide()
    if not tf or not tf:IsVisible() then return end
    local d = C.diff(B.currentString(), b.text)
    if not d then return end
    local heroSwap = false
    for _, c in ipairs(d) do local n = lib(c.node) if n and n.isSubTreeSelection then heroSwap = true end end
    local hidden, n = 0, 0
    for _, c in ipairs(d) do
        local info = lib(c.node)
        if not (heroSwap and info and (info.subTreeID or info.isSubTreeSelection)) then
            local button = tf:GetTalentButtonByNodeID(c.node)
            if button and button:IsVisible() then
                n = n + 1
                place(mark(n), button, kind(c))
            else
                hidden = hidden + 1
            end
        end
    end
    local emblem = tf.HeroTalentsContainer and tf.HeroTalentsContainer.HeroSpecButton
    if heroSwap and emblem and emblem:IsVisible() then
        n = n + 1
        local m = mark(n)
        place(m, emblem, "swap")
        m.label:SetText(C.heroName(b.text) or "")
    end
    return d, hidden
end

-- The side pane of builds -----------------------------------------------------------------
-- Docked to the window's right edge, at our own scale (parented to UIParent, shown with the
-- talent window). Groups as headings, each main build with its variants indented under it.
local pane, rows, heads = nil, {}, {}
local ROW = 24

local function row(i)
    if rows[i] then return rows[i] end
    local r = CreateFrame("Button", nil, pane)
    r:SetHeight(ROW)
    r:SetPoint("LEFT", 0, 0); r:SetPoint("RIGHT", 0, 0)
    UI.fill(r, "HIGHLIGHT", 0.851, 0.851, 0.851, 0.15)
    r.bar = r:CreateTexture(nil, "OVERLAY")
    r.bar:SetColorTexture(0.596, 1, 0.596, 1)
    r.bar:SetPoint("TOPLEFT"); r.bar:SetPoint("BOTTOMLEFT"); r.bar:SetWidth(2)
    r.text = r:CreateFontString(nil, "OVERLAY", "TalentKeeperFont")
    r.text:SetPoint("RIGHT", -8, 0)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:RegisterForDrag("LeftButton")
    r:SetScript("OnClick", TK.safe(function(self, button)
        if self.dragged then self.dragged = nil return end
        W.hide()
        if button == "RightButton" then
            local b, specID = self.b, B.specID()
            return MenuUtil.CreateContextMenu(self, function(_, root)
                root:CreateTitle(b.name)
                UI.buildActions(root, specID, b)
            end)
        end
        B.apply(self.b)
    end))
    r:SetScript("OnDragStart", function(self)
        self.dragged, W.dragging = true, self.b
        W.hide() GameTooltip:Hide()
        SetCursor("Interface\\Cursor\\UI-Cursor-Move")
    end)
    r:SetScript("OnDragStop", TK.safe(function() W.drop() end))
    r:SetScript("OnEnter", TK.safe(function(self)
        local d, hidden = W.show(self.b)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.b.name)
        if not d then
            GameTooltip:AddLine("Couldn't read this build.", 1, 0.533, 0.533)
        elseif #d == 0 then
            GameTooltip:AddLine("Same as your talents.", 0.74, 0.74, 0.74)
        else
            GameTooltip:AddLine(("%d change%s, marked on the tree: %s"):format(#d, #d == 1 and "" or "s", table.concat(C.describe(d, 6), ", ")), 0.74, 0.74, 0.74, true)
            if hidden > 0 then GameTooltip:AddLine(("%d not on show (another hero tree)."):format(hidden), 0.55, 0.55, 0.55, true) end
            GameTooltip:AddLine("Click to apply. Right-click for more; drag onto a group to move it.", 0.55, 0.55, 0.55, true)
        end
        GameTooltip:Show()
    end))
    r:SetScript("OnLeave", function() W.hide() GameTooltip:Hide() end)
    rows[i] = r
    return r
end

local function head(i)
    if heads[i] then return heads[i] end
    local h = pane:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    h:SetTextColor(0.55, 0.55, 0.55)
    heads[i] = h
    return h
end

-- Drop a dragged build onto a group heading, a build (its group) or "+ New group".
function W.drop()
    local b = W.dragging
    W.dragging = nil
    ResetCursor()
    if not b then return end
    local target -- nil: no drop target; false: no group
    for _, h in ipairs(heads) do if h:IsShown() and h.group ~= nil and h:IsMouseOver() then target = h.group end end
    for _, r in ipairs(rows) do if r:IsShown() and r:IsMouseOver() then target = r.b.group or false end end
    if pane.newGroup:IsMouseOver() then
        return UI.textWindow({ title = "New group for " .. b.name, singleLine = true, okText = "Move",
            onOK = function(name) if strtrim(name) ~= "" then B.setGroup(b, name) end end })
    end
    if target ~= nil and (target or nil) ~= b.group then B.setGroup(b, target or nil) end
end

function W.refresh()
    if not pane or not pane:IsShown() then return end
    W.hide()
    for _, r in ipairs(rows) do r:Hide() end
    for _, h in ipairs(heads) do h:Hide() end
    local specID = B.specID()
    local active = specID and TK.db.active[specID]
    pane.title:SetText(specID and B.specName(specID) or "TalentKeeper")
    local y, nr, nh = -36, 0, 0
    for _, line in ipairs(B.ordered(specID)) do
        if line.header ~= nil then
            if line.header or nr > 0 then -- "No group" only when something came before it
                nh = nh + 1
                local h = head(nh)
                h:SetText(line.header or "No group")
                h.group = line.header
                h:ClearAllPoints()
                h:SetPoint("TOPLEFT", 10, y - 8)
                h:Show()
                y = y - 22
            end
        elseif line.build then
            nr = nr + 1
            local b, r = line.build, row(nr)
            r.b = b
            r.text:SetText((b.main and "· " or "") .. b.name)
            r.text:SetPoint("LEFT", b.main and 24 or 10, 0)
            local on = b.name == active
            r.text:SetTextColor(on and 0.596 or 1, 1, on and 0.596 or 1)
            r.bar:SetShown(on)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, y); r:SetPoint("TOPRIGHT", 0, y)
            r:Show()
            y = y - ROW
        end
    end
    pane.newGroup:ClearAllPoints()
    pane.newGroup:SetPoint("TOPLEFT", 10, y - 8)
    pane.newGroup:SetShown(nr > 0)
    if nr == 0 then
        nh = nh + 1
        local h = head(nh)
        h:SetText("No builds for this spec yet.")
        h.group = nil
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", 10, y - 8)
        h:Show()
    end
end

local prev = TK.onChange
TK.onChange = function()
    if prev then prev() end
    TK.safe(W.refresh)()
end
TK.on("ACTIVE_PLAYER_SPECIALIZATION_CHANGED", function() TK.safe(W.refresh)() end)

-- Window size: drag the corner grip to scale the talent window (kept between sessions).
local function applyScale()
    if PlayerSpellsFrame and not InCombatLockdown() then PlayerSpellsFrame:SetScale(TK.db.windowScale or 1) end
end

local function grip()
    local g = CreateFrame("Button", nil, PlayerSpellsFrame)
    g:SetSize(16, 16)
    g:SetPoint("BOTTOMRIGHT", -2, 2)
    g:SetFrameLevel(PlayerSpellsFrame:GetFrameLevel() + 50)
    g:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    g:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    g:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    g:RegisterForClicks("RightButtonUp")
    g:SetScript("OnClick", function() if InCombatLockdown() then return end TK.db.windowScale = nil applyScale() end)
    g:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or InCombatLockdown() then return end
        self:SetScript("OnUpdate", function()
            local f = PlayerSpellsFrame
            local x = GetCursorPosition()
            local px = UIParent:GetEffectiveScale()
            local width = x - f:GetLeft() * f:GetEffectiveScale()
            local s = math.max(0.5, math.min(1.2, width / (f:GetWidth() * px)))
            TK.db.windowScale = math.floor(s * 100 + 0.5) / 100
            applyScale()
        end)
    end)
    g:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
    g:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Talent window size")
        GameTooltip:AddLine("Drag to make the window smaller or bigger. Right-click for the normal size.", 0.74, 0.74, 0.74, true)
        GameTooltip:Show()
    end)
    g:SetScript("OnLeave", GameTooltip_Hide)
end

EventUtil.ContinueOnAddOnLoaded("Blizzard_PlayerSpells", TK.safe(function()
    tf = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    if not tf or not tf.GetTalentButtonByNodeID then return TK.log("talent window: no talent buttons found") end
    pane = CreateFrame("Frame", nil, UIParent)
    pane:SetWidth(200)
    pane:SetPoint("TOPLEFT", PlayerSpellsFrame, "TOPRIGHT", 2, 0)
    pane:SetPoint("BOTTOMLEFT", PlayerSpellsFrame, "BOTTOMRIGHT", 2, 0)
    pane:SetFrameStrata(PlayerSpellsFrame:GetFrameStrata())
    UI.fill(pane, "BACKGROUND", 0.06, 0.06, 0.06, 0.98)
    pane.title = pane:CreateFontString(nil, "OVERLAY", "TalentKeeperFontLarge")
    pane.title:SetPoint("TOPLEFT", 10, -10)
    pane.newGroup = CreateFrame("Frame", nil, pane)
    pane.newGroup:SetSize(180, 20)
    local ng = pane.newGroup:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    ng:SetPoint("LEFT")
    ng:SetText("+ New group (drop a build here)")
    ng:SetTextColor(0.55, 0.55, 0.55)
    local save = UI.button(pane, "Save current", 88, function()
        local specID = B.specID()
        if not specID then return end
        UI.textWindow({ title = "Save current talents", singleLine = true, okText = "Save",
            text = ("%s %d"):format(B.specName(specID), #B.list(specID) + 1),
            onOK = function(name) B.saveCurrent(name) end })
    end)
    save:SetPoint("BOTTOMLEFT", 8, 8)
    local all = UI.button(pane, "All builds", 88, function() TK.manager.open() end)
    all:SetPoint("BOTTOMRIGHT", -8, 8)
    pane:Hide()
    tf:HookScript("OnShow", function() pane:Show() TK.safe(W.refresh)() end)
    tf:HookScript("OnHide", function() W.hide() pane:Hide() end)
    PlayerSpellsFrame:HookScript("OnShow", applyScale)
    grip()
    applyScale()
end))
