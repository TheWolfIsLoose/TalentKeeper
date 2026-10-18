-- TalentKeeper on the talent window: your builds in a side pane beside it. Hover one to see on
-- the tree what it would change; click to apply; right-click or drag to organize.
local _, TK = ...
local B, C, UI = TK.builds, TK.compare, TK.ui
local W = {}
TK.window = W

local tf, marks = nil, {}

-- Marks on the tree ----------------------------------------------------------------------
-- Drawn in the talent window's own language, from each button's own art set: a talent the
-- build adds glows green like one you can take; one it drops gets the red border and a dim
-- veil, like a talent you'd lose; another choice shows the build's pick on the node. Plus
-- and minus signs only in colorblind mode.
local function mark(i)
    if marks[i] then return marks[i] end
    local m = CreateFrame("Frame", nil, tf)
    m.mask = m:CreateMaskTexture()
    m.mask:SetPoint("CENTER")
    m.veil = m:CreateTexture(nil, "ARTWORK", nil, 1)
    m.veil:SetPoint("CENTER")
    m.veil:SetColorTexture(0, 0, 0, 0.55)
    m.veil:AddMaskTexture(m.mask)
    m.icon = m:CreateTexture(nil, "ARTWORK", nil, 2)
    m.icon:SetPoint("CENTER")
    m.icon:AddMaskTexture(m.mask)
    m.border = m:CreateTexture(nil, "OVERLAY", nil, 1)
    m.border:SetPoint("CENTER")
    m.glow = m:CreateTexture(nil, "OVERLAY", nil, 2)
    m.glow:SetPoint("CENTER")
    m.glow:SetBlendMode("ADD")
    m.text = m:CreateFontString(nil, "OVERLAY", "SystemFont16_Shadow_ThickOutline")
    m.text:SetPoint("BOTTOMRIGHT", 4, -4)
    m.label = m:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    m.label:SetPoint("TOP", m, "BOTTOM", 0, -6)
    marks[i] = m
    return m
end

function W.hide()
    for _, m in ipairs(marks) do m:Hide() end
end

-- How a node changes from your talents to the build's.
local function kind(c) return not c.from and "add" or not c.to and "rem" or "swap" end

local LTT = LibStub and LibStub("LibTalentTree-1.0", true)
local function lib(node) return LTT and LTT:GetLibNodeInfo(node) end

-- The icon of the build's pick on a choice node ("rank:choice").
local function choiceIcon(node, pick)
    local choice = tonumber((pick or ""):match(":(%d+)$")) or 0
    local cfg = C_ClassTalents.GetActiveConfigID()
    local info = choice > 0 and cfg and C_Traits.GetNodeInfo(cfg, node)
    local entry = info and info.entryIDs and C_Traits.GetEntryInfo(cfg, info.entryIDs[choice])
    local def = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
    if not def then return end
    return def.overrideIcon or (def.spellID and C_Spell.GetSpellTexture(def.spellID))
end

local function sizeOf(region, w, h)
    if region and region.GetSize then local rw, rh = region:GetSize() if rw and rw > 0 then return rw, rh end end
    return w, h
end

local function place(m, button, c)
    local k = c and kind(c) or "swap"
    local art = button.artSet or { glow = "talents-node-circle-greenglow" }
    local w, h = button:GetSize()
    m:SetFrameStrata(button:GetFrameStrata())
    m:SetFrameLevel(button:GetFrameLevel() + 10)
    m:ClearAllPoints()
    m:SetPoint("CENTER", button)
    m:SetSize(w, h)
    local iw, ih = sizeOf(button.Icon, w, h)
    m.mask:SetSize(iw, ih)
    if art.iconMask then m.mask:SetAtlas(art.iconMask, TextureKitConstants.IgnoreAtlasSize) else m.mask:SetTexture("Interface\\Buttons\\WHITE8X8") end
    m.veil:SetSize(iw, ih)
    m.icon:SetSize(iw, ih)
    m.border:SetSize(sizeOf(button.StateBorder, w, h))
    m.glow:SetSize(sizeOf(button.Glow, w * 1.6, h * 1.6))
    m.glow:SetAtlas(art.glow)
    m.veil:SetShown(k == "rem")
    m.border:SetShown(k == "rem" and art.displayError ~= nil)
    if art.displayError then m.border:SetAtlas(art.displayError) end
    m.glow:SetShown(k ~= "rem")
    local icon = k == "swap" and c and choiceIcon(c.node, c.to)
    m.icon:SetShown(icon and true or false) -- icon is false, not nil, off a choice node
    if icon then m.icon:SetTexture(icon) end
    -- a rank change shows the build's rank; colorblind mode adds a sign
    local rank = k == "swap" and c and not icon and tonumber((c.to or ""):match("^(%d+)"))
    local sign = GetCVarBool("colorblindMode") and ((k == "add" and "+") or (k == "rem" and "-")) or nil
    m.text:SetText(rank and rank > 0 and tostring(rank) or sign or "")
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
                place(mark(n), button, c)
            else
                hidden = hidden + 1
            end
        end
    end
    local emblem = tf.HeroTalentsContainer and tf.HeroTalentsContainer.HeroSpecButton
    if heroSwap and emblem and emblem:IsVisible() then
        n = n + 1
        local m = mark(n)
        place(m, emblem, nil)
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
    r.stripe = UI.fill(r, "BACKGROUND", 1, 1, 1, 0.05)
    UI.fill(r, "HIGHLIGHT", 0.851, 0.851, 0.851, 0.15)
    r.status = r:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    r.status:SetPoint("RIGHT", -8, 0)
    r.status:SetTextColor(1, 0.722, 0.302)
    r.bar = r:CreateTexture(nil, "OVERLAY")
    r.bar:SetColorTexture(0.596, 1, 0.596, 1)
    r.bar:SetPoint("TOPLEFT"); r.bar:SetPoint("BOTTOMLEFT"); r.bar:SetWidth(2)
    r.text = r:CreateFontString(nil, "OVERLAY", "TalentKeeperFont")
    r.text:SetPoint("RIGHT", r.status, "LEFT", -6, 0)
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
        local tags = B.tagNames(self.b)
        if #tags > 0 then GameTooltip:AddLine("For: " .. table.concat(tags, ", "), 0.596, 1, 0.596, true) end
        if self.b.main and self.b.changes then
            GameTooltip:AddLine(("Swaps from %s: %s"):format(self.b.main, #self.b.changes == 0 and "none"
                or table.concat(C.describe(self.b.changes, 6), ", ")), 1, 1, 1, true)
        end
        if not d then
            GameTooltip:AddLine("Couldn't read this build.", 1, 0.533, 0.533)
        elseif #d == 0 then
            GameTooltip:AddLine("Same as your talents.", 0.74, 0.74, 0.74)
        else
            GameTooltip:AddLine(("%d change%s, marked on the tree: %s"):format(#d, #d == 1 and "" or "s", table.concat(C.describe(d, 6), ", ")), 0.74, 0.74, 0.74, true)
            if hidden > 0 then GameTooltip:AddLine(("%d not on show (another hero tree)."):format(hidden), 0.55, 0.55, 0.55, true) end
            GameTooltip:AddLine("Click to apply. Right-click to tag it and more; drag onto a group to move it.", 0.55, 0.55, 0.55, true)
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
    pane.title:SetText(specID and (B.specName(specID) .. " builds") or "TalentKeeper")
    local y, nr, nh = -30, 0, 0
    for _, line in ipairs(B.ordered(specID)) do
        if line.header ~= nil then
            if line.header or nr > 0 then -- "No group" only when something came before it
                nh = nh + 1
                local h = head(nh)
                h:SetText(line.header or "No group")
                h.group = line.header
                h:ClearAllPoints()
                h:SetPoint("TOPLEFT", 8, y - 8)
                h:Show()
                y = y - 22
            end
        elseif line.build then
            nr = nr + 1
            local b, r = line.build, row(nr)
            r.b = b
            r.text:SetText((b.main and "· " or "") .. b.name)
            r.text:SetPoint("LEFT", b.main and 20 or 8, 0)
            local warn = b.outdated and "Outdated" or b.needsReview and "Needs review"
            r.status:SetText(warn or UI.tagSummary(b) or "")
            if warn then r.status:SetTextColor(1, 0.722, 0.302) else r.status:SetTextColor(0.55, 0.55, 0.55) end
            r.stripe:SetShown(nr % 2 == 0)
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
    pane.newGroup:SetPoint("TOPLEFT", 8, y - 8)
    pane.newGroup:SetShown(nr > 0)
    if nr == 0 then
        nh = nh + 1
        local h = head(nh)
        h:SetText("No builds for this spec yet.")
        h.group = nil
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", 8, y - 8)
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
    -- the suite's side panel: opaque panel fill, black edge, a 26px header over a black rule
    pane:SetWidth(220)
    pane:SetPoint("TOPLEFT", PlayerSpellsFrame, "TOPRIGHT", 1, 0)
    pane:SetPoint("BOTTOMLEFT", PlayerSpellsFrame, "BOTTOMRIGHT", 1, 0)
    pane:SetFrameStrata(PlayerSpellsFrame:GetFrameStrata())
    pane:EnableMouse(true)
    UI.fill(pane, "BACKGROUND", 0.06, 0.06, 0.06, 1)
    UI.ring(pane, 0)
    local mark = pane:CreateTexture(nil, "ARTWORK")
    mark:SetSize(16, 16)
    mark:SetPoint("LEFT", pane, "TOPLEFT", 8, -13)
    mark:SetTexture("Interface\\AddOns\\TalentKeeper\\icon.png")
    pane.title = pane:CreateFontString(nil, "OVERLAY", "TalentKeeperFont")
    pane.title:SetPoint("LEFT", mark, "RIGHT", 6, 0)
    local rule = pane:CreateTexture(nil, "OVERLAY")
    rule:SetColorTexture(0, 0, 0, 1)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", 0, -26); rule:SetPoint("TOPRIGHT", 0, -26)
    pane.newGroup = CreateFrame("Frame", nil, pane)
    pane.newGroup:SetSize(180, 20)
    local ng = pane.newGroup:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    ng:SetPoint("LEFT")
    ng:SetText("+ New group (drop a build here)")
    ng:SetTextColor(0.55, 0.55, 0.55)
    local save = UI.button(pane, "Save current", 98, function()
        local specID = B.specID()
        if not specID then return end
        UI.textWindow({ title = "Save current talents", singleLine = true, okText = "Save",
            text = ("%s %d"):format(B.specName(specID), #B.list(specID) + 1),
            onOK = function(name) B.saveCurrent(name) end })
    end)
    save:SetPoint("BOTTOMLEFT", 8, 8)
    local import = UI.button(pane, "Import", 98, function() TK.commands.import() end)
    import:SetPoint("BOTTOMRIGHT", -8, 8)
    pane:Hide()
    tf:HookScript("OnShow", function() pane:Show() TK.safe(W.refresh)() end)
    tf:HookScript("OnHide", function() W.hide() pane:Hide() end)
    PlayerSpellsFrame:HookScript("OnShow", applyScale)
    grip()
    applyScale()
end))
