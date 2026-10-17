-- TalentKeeper on the talent window: your builds in a strip under it. Hover one to see on the
-- tree what it would change (marks on the talents themselves); click it to apply.
local _, TK = ...
local B, C, UI = TK.builds, TK.compare, TK.ui
local W = {}
TK.window = W

local COLOR = { add = { 0.596, 1, 0.596 }, rem = { 1, 0.533, 0.533 }, swap = { 1, 0.722, 0.302 } }
local SIGN = { add = "+", rem = "-", swap = "~" }

local tf, strip, marks, pills, labels = nil, nil, {}, {}, {}

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
    marks[i] = m
    return m
end

function W.hide()
    for _, m in ipairs(marks) do m:Hide() end
end

-- How a node changes from your talents to the build's.
local function kind(c) return not c.from and "add" or not c.to and "rem" or "swap" end

-- Mark what applying b would change; returns the changes and how many have no button on show.
function W.show(b)
    W.hide()
    if not tf or not tf:IsVisible() then return end
    local d = C.diff(B.currentString(), b.text)
    if not d then return end
    local hidden = 0
    for i, c in ipairs(d) do
        local button = tf:GetTalentButtonByNodeID(c.node)
        if button and button:IsVisible() then
            local k, m = kind(c), mark(i)
            local col = COLOR[k]
            m:SetFrameStrata(button:GetFrameStrata())
            m:SetFrameLevel(button:GetFrameLevel() + 10)
            m:ClearAllPoints()
            m:SetPoint("TOPLEFT", button, "TOPLEFT", -3, 3)
            m:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 3, -3)
            m.setRing(col[1], col[2], col[3])
            m.badge.bg:SetColorTexture(col[1], col[2], col[3], 1)
            m.badge.text:SetText(SIGN[k])
            m:Show()
        else
            hidden = hidden + 1
        end
    end
    return d, hidden
end

-- The strip of builds -------------------------------------------------------------------
local function pill(i)
    if pills[i] then return pills[i] end
    local p = UI.button(strip, "", 60, function(self) W.hide() B.apply(self.b) end)
    p:SetHeight(22)
    p.bar = p:CreateTexture(nil, "OVERLAY")
    p.bar:SetColorTexture(0.596, 1, 0.596, 1)
    p.bar:SetPoint("BOTTOMLEFT"); p.bar:SetPoint("BOTTOMRIGHT"); p.bar:SetHeight(2)
    p:HookScript("OnEnter", TK.safe(function(self)
        local d, hidden = W.show(self.b)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(self.b.name)
        if not d then
            GameTooltip:AddLine("Couldn't read this build.", 1, 0.533, 0.533)
        elseif #d == 0 then
            GameTooltip:AddLine("Same as your talents.", 0.74, 0.74, 0.74)
        else
            GameTooltip:AddLine(("%d change%s: %s"):format(#d, #d == 1 and "" or "s", table.concat(C.describe(d, 6), ", ")), 0.74, 0.74, 0.74, true)
            if hidden > 0 then GameTooltip:AddLine(("%d not on show (another hero tree)."):format(hidden), 0.55, 0.55, 0.55, true) end
            GameTooltip:AddLine("Click to apply.", 0.55, 0.55, 0.55)
        end
        GameTooltip:Show()
    end))
    p:HookScript("OnLeave", function() W.hide() GameTooltip:Hide() end)
    pills[i] = p
    return p
end

local function label(i)
    if labels[i] then return labels[i] end
    local l = strip:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    l:SetTextColor(0.55, 0.55, 0.55)
    labels[i] = l
    return l
end

function W.refresh()
    if not strip or not strip:IsVisible() then return end
    W.hide()
    for _, p in ipairs(pills) do p:Hide() end
    for _, l in ipairs(labels) do l:Hide() end
    local specID = B.specID()
    local active = specID and TK.db.active[specID]
    local x, y, np, nl = 8, -6, 0, 0
    local width = strip:GetWidth() - 8
    local function place(w)
        if x + w > width and x > 8 then x, y = 8, y - 26 end
        local px, py = x, y
        x = x + w + 6
        return px, py
    end
    for _, line in ipairs(B.ordered(specID)) do
        if line.header then
            nl = nl + 1
            local l = label(nl)
            l:SetText(line.header)
            local px, py = place(l:GetStringWidth() + 2)
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", px, py - 6)
            l:Show()
        elseif line.build then
            np = np + 1
            local b, p = line.build, pill(np)
            p.b = b
            p:SetText((b.main and "· " or "") .. b.name)
            p:SetWidth(p:GetFontString():GetStringWidth() + 20)
            local on = b.name == active
            p:GetFontString():SetTextColor(on and 0.596 or 1, 1, on and 0.596 or 1)
            p.bar:SetShown(on)
            local px, py = place(p:GetWidth())
            p:ClearAllPoints()
            p:SetPoint("TOPLEFT", px, py)
            p:Show()
        end
    end
    if np == 0 then
        nl = nl + 1
        local l = label(nl)
        l:SetText("No builds saved for this spec yet. Save one from the TalentKeeper button.")
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", 8, -11)
        l:Show()
    end
    strip:SetHeight(-y + 28)
end

local prev = TK.onChange
TK.onChange = function()
    if prev then prev() end
    TK.safe(W.refresh)()
end
TK.on("ACTIVE_PLAYER_SPECIALIZATION_CHANGED", function() TK.safe(W.refresh)() end)

EventUtil.ContinueOnAddOnLoaded("Blizzard_PlayerSpells", TK.safe(function()
    tf = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    if not tf or not tf.GetTalentButtonByNodeID then return TK.log("talent window: no talent buttons found") end
    strip = CreateFrame("Frame", nil, tf)
    strip:SetPoint("TOPLEFT", PlayerSpellsFrame, "BOTTOMLEFT", 0, -2)
    strip:SetPoint("TOPRIGHT", PlayerSpellsFrame, "BOTTOMRIGHT", 0, -2)
    strip:SetHeight(34)
    UI.fill(strip, "BACKGROUND", 0.031, 0.031, 0.031, 0.97)
    strip:SetScript("OnShow", TK.safe(W.refresh))
    strip:SetScript("OnSizeChanged", TK.safe(W.refresh))
    tf:HookScript("OnHide", W.hide)
end))
