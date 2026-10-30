-- TalentKeeper UI: fonts, buttons, the save / import dialog, the picker (tags, groups, the
-- quick build list for the key binding and /tk), and one small text window (copy, log).
local addonName, TK = ...
local B = TK.builds
local UI = {}
TK.ui = UI

-- Fonts and colors (suite style guide) ---------------------------------------------
local FONT = "Interface\\AddOns\\" .. addonName .. "\\Media\\BarlowSemiCondensed-Medium.ttf"
local SIZES = { TalentKeeperFontSmall = 10, TalentKeeperFont = 12, TalentKeeperFontLarge = 16, TalentKeeperFontDisabled = 10 }
local fonts = {}
for name, size in pairs(SIZES) do fonts[name] = CreateFont(name) fonts[name]:SetFont(FONT, size, "") end
local disabledFont = fonts.TalentKeeperFontDisabled
disabledFont:SetTextColor(0.55, 0.55, 0.55)
-- Expressway when another addon has registered it with LibSharedMedia (it can't ship here).
TK.on("PLAYER_LOGIN", function()
    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    local face = lsm and lsm:Fetch("font", "Expressway", true)
    if face then for name, size in pairs(SIZES) do fonts[name]:SetFont(face, size, "") end end
end)

local function fill(frame, layer, r, g, b, a)
    local t = frame:CreateTexture(nil, layer)
    t:SetAllPoints()
    t:SetColorTexture(r, g, b, a)
    return t
end

-- 1px ring around a frame.
local function ring(frame, gray)
    local edges = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(gray, gray, gray, 1)
        t:SetTexelSnappingBias(0); t:SetSnapToPixelGrid(false)
        if side == "TOP" or side == "BOTTOM" then
            t:SetPoint(side .. "LEFT"); t:SetPoint(side .. "RIGHT"); t:SetHeight(1)
        else
            t:SetPoint("TOP" .. side); t:SetPoint("BOTTOM" .. side); t:SetWidth(1)
        end
        edges[#edges + 1] = t
    end
    return function(g) for _, t in ipairs(edges) do t:SetColorTexture(g, g, g, 1) end end
end

-- Flat button: face at rest, gray ring, hover wash; 20px with the Small font, like PickupGroup's.
local function button(parent, label, width, onClick)
    local bt = CreateFrame("Button", nil, parent)
    bt:SetSize(width, 20)
    fill(bt, "BACKGROUND", 1, 1, 1, 0.07)
    local setRing = ring(bt, 0.4)
    local hover = fill(bt, "HIGHLIGHT", 0.851, 0.851, 0.851, 0.15)
    hover:SetBlendMode("BLEND")
    bt:SetNormalFontObject(TalentKeeperFontSmall)
    bt:SetMotionScriptsWhileDisabled(true) -- a grayed button still says why
    bt:SetDisabledFontObject(disabledFont)
    bt:SetText(label)
    bt:SetScript("OnEnter", function() setRing(0.7) end)
    bt:SetScript("OnLeave", function() setRing(0.4) end)
    bt:SetScript("OnClick", TK.safe(onClick))
    return bt
end

UI.fill, UI.ring, UI.button = fill, ring, button

-- One footprint: a form opens as a view over the side pane (Window.lua sets UI.pane) while the
-- talent window is open, else on its own mid-screen (/tk import, the log). f.bg and f.setEdge are
-- its fill and edge. Returns true when it's in the pane.
function UI.dock(f, alone)
    local pane = UI.pane
    local inPane = not alone and pane and pane:IsShown() or false
    f.inPane = inPane
    f:ClearAllPoints()
    if inPane then
        f:SetParent(pane)
        f:SetFrameStrata(pane:GetFrameStrata())
        f:SetFrameLevel(pane:GetFrameLevel() + 30)
        f:SetPoint("TOPLEFT", pane, "TOPLEFT", 1, -27); f:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -1, 1)
        if not f.paneHooked then -- closes with the talent window
            f.paneHooked = true
            pane:HookScript("OnHide", function() if f.inPane then f:Hide() end end)
        end
    else
        f:SetParent(UIParent)
        f:SetFrameStrata("DIALOG")
        f:SetPoint("CENTER")
    end
    local g = inPane and 0.06 or 0.031
    f.bg:SetColorTexture(g, g, g, inPane and 1 or 0.97)
    f.setEdge(inPane and 0.06 or 0)
    -- in the pane its buttons sit in the footer band, the same as the build list's
    if f.lastButton then
        if not rawget(f, "band") then f.band = UI.footBand(f) end
        f.band:SetShown(inPane)
        f.lastButton:ClearAllPoints()
        if inPane then f.lastButton:SetPoint("BOTTOMRIGHT", -8, 8) else f.lastButton:SetPoint(unpack(f.alonePoint)) end
    end
    return inPane
end

-- The footer band: 36px (or h), a black rule over a faint band (the suite's footer).
function UI.footBand(f, h)
    local band = CreateFrame("Frame", nil, f)
    band:SetPoint("BOTTOMLEFT"); band:SetPoint("BOTTOMRIGHT")
    band:SetHeight(h or 36)
    fill(band, "BACKGROUND", 1, 1, 1, 0.035)
    local rule = band:CreateTexture(nil, "OVERLAY")
    rule:SetColorTexture(0, 0, 0, 1)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT"); rule:SetPoint("TOPRIGHT")
    return band
end

-- The hero tree's emblem for a build's talent string, trimmed a little like the spec tiles.
local HERO_ZOOM = 0.05 -- share of the emblem trimmed off each side
function UI.setHero(tex, text)
    local hero = TK.compare.hero(text)
    local a = hero and hero.atlas and C_Texture.GetAtlasInfo(hero.atlas) -- the atlas's own coords: a texture's may be cropped already
    if not a then tex:SetTexture(nil) return end
    tex:SetTexture(a.file or a.filename)
    local l, r, t, bt = a.leftTexCoord, a.rightTexCoord, a.topTexCoord, a.bottomTexCoord
    local w, h = (r - l) * HERO_ZOOM, (bt - t) * HERO_ZOOM
    tex:SetTexCoord(l + w, r - w, t + h, bt - h)
end

-- The suite's dropdown mark: a small drawn chevron (two 45° strokes) on anything that opens a menu,
-- so it reads as a dropdown without a tooltip.
function UI.chevron(parent, gray)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(9, 6)
    local g = gray or 0.74
    for side = -1, 1, 2 do
        local t = f:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(g, g, g, 1)
        t:SetSize(6, 1.5)
        t:SetPoint("CENTER", side * 2, 0)
        t:SetRotation(side * math.pi / 4) -- left \ and right /: points down
    end
    return f
end

-- A build card: the spec's tile and the build's hero emblem, the build name, a line under it saying
-- where and how it stands, and up to two buttons (plus x when it can be closed). The ready check
-- and the delve prompt both use it, so a glance says which spec and build without reading.
-- card:Set({ specID, text, title, sub, one = { label, fn }, two = ..., minWidth })
local TILE = 34
function UI.card(name, onClose)
    local c = CreateFrame("Frame", name, UIParent)
    c:SetHeight(TILE + 12)
    c:SetFrameStrata("DIALOG")
    c:SetClampedToScreen(true)
    c:EnableMouse(true)
    fill(c, "BACKGROUND", 0.06, 0.06, 0.06, 0.98)
    ring(c, 0)
    local function tile(x, kind)
        local f = CreateFrame(kind, nil, c)
        f:SetSize(TILE, TILE)
        f:SetPoint("LEFT", x, 0)
        ring(f, 0.3)
        f.icon = f:CreateTexture(nil, "ARTWORK")
        f.icon:SetPoint("TOPLEFT", 1, -1); f.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        return f
    end
    -- the spec tile is a dropdown (spec and loot spec): a chevron badge in its corner says so, and a
    -- small loot badge at the top shows a loot spec that isn't the current one
    c.spec, c.hero = tile(6, "Button"), tile(6 + TILE + 4, "Frame")
    c.spec.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    fill(c.spec, "HIGHLIGHT", 1, 1, 1, 0.15)
    local badge = CreateFrame("Frame", nil, c.spec)
    badge:SetSize(12, 10)
    badge:SetPoint("BOTTOMRIGHT", -1, 1)
    fill(badge, "ARTWORK", 0, 0, 0, 0.8)
    UI.chevron(badge, 0.9):SetPoint("CENTER", 0, 0)
    c.loot = CreateFrame("Frame", nil, c.spec)
    c.loot:SetSize(14, 14)
    c.loot:SetPoint("TOPRIGHT", 3, 3)
    ring(c.loot, 0)
    c.loot.icon = c.loot:CreateTexture(nil, "OVERLAY")
    c.loot.icon:SetPoint("TOPLEFT", 1, -1); c.loot.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    c.loot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    c.spec:SetScript("OnClick", TK.safe(function(self) UI.specMenu(self) end))
    c.spec:SetScript("OnEnter", function(self) -- what it is: the spec and where loot goes
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(c.specName or "")
        local loot = GetLootSpecialization and GetLootSpecialization() or 0
        GameTooltip:AddLine("Loot: " .. (loot == 0 and "current spec" or select(2, GetSpecializationInfoByID(loot)) or "?"), 0.74, 0.74, 0.74)
        GameTooltip:Show()
    end)
    c.spec:SetScript("OnLeave", GameTooltip_Hide)
    -- the build name is a dropdown when the card can offer another build (c:Set's onTitle)
    c.name = CreateFrame("Button", nil, c)
    c.name:SetPoint("TOPLEFT", c.hero, "TOPRIGHT", 4, 2)
    c.name:SetHeight(20)
    c.nameHover = fill(c.name, "HIGHLIGHT", 1, 1, 1, 0.08)
    c.title = c.name:CreateFontString(nil, "OVERLAY", "TalentKeeperFontLarge")
    c.title:SetPoint("LEFT", 4, 0)
    c.title:SetWordWrap(false)
    c.caret = UI.chevron(c.name)
    c.caret:SetPoint("LEFT", c.title, "RIGHT", 6, -1)
    -- the second line is a button so the ready check can make it clickable (correct the boss)
    c.where = CreateFrame("Button", nil, c)
    c.where:SetHeight(14)
    c.where:SetPoint("BOTTOMLEFT", c.hero, "BOTTOMRIGHT", 8, 0)
    c.sub = c.where:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    c.sub:SetPoint("LEFT")
    c.sub:SetTextColor(0.74, 0.74, 0.74)
    if onClose then
        c.close = button(c, "x", 24, onClose)
        c.close:SetPoint("RIGHT", -6, 0)
    end
    c.btn1 = button(c, "", 70, function() end)
    c.btn1.pulse = UI.pulse(c.btn1)
    c.btn2 = button(c, "", 70, function() end)
    function c:Set(o)
        local _, specName, _, icon = GetSpecializationInfoByID(o.specID or 0)
        self.spec.icon:SetTexture(icon)
        self.specName = specName
        local loot = GetLootSpecialization and GetLootSpecialization() or 0
        local lootIcon = loot ~= 0 and loot ~= o.specID and select(4, GetSpecializationInfoByID(loot))
        self.loot:SetShown(lootIcon and true or false)
        if lootIcon then self.loot.icon:SetTexture(lootIcon) end
        UI.setHero(self.hero.icon, o.text)
        self.title:SetText(o.title or "")
        self.caret:SetShown(o.onTitle ~= nil)
        self.nameHover:SetShown(o.onTitle ~= nil)
        self.name:SetWidth(self.title:GetStringWidth() + 8 + (o.onTitle and 15 or 0))
        self.name:SetScript("OnClick", o.onTitle and TK.safe(o.onTitle) or nil)
        self.sub:SetText(o.sub or "")
        self.where:SetWidth(math.max(1, self.sub:GetStringWidth()))
        local right, bw = self.close or nil, 0
        for _, pair in ipairs({ { self.btn2, o.two }, { self.btn1, o.one } }) do -- laid out right to left
            local bt, spec = pair[1], pair[2]
            bt:SetShown(spec ~= nil)
            if spec then
                bt:SetText(spec[1])
                bt:SetWidth(math.max(64, bt:GetTextWidth() + 20))
                bt:SetScript("OnClick", TK.safe(function() spec[2](bt) end))
                bt:ClearAllPoints()
                if right then bt:SetPoint("RIGHT", right, "LEFT", -4, 0) else bt:SetPoint("RIGHT", -6, 0) end
                right, bw = bt, bw + bt:GetWidth() + 4
            end
        end
        local text = math.max(self.title:GetStringWidth() + (o.onTitle and 15 or 0), self.sub:GetStringWidth())
        local w = 6 + 2 * TILE + 4 + 8 + text + 16 + bw + (self.close and 30 or 2)
        self:SetWidth(math.ceil(math.max(o.minWidth or 0, w)))
        self:Show()
    end
    c:Hide()
    return c
end

-- Spec and loot spec in one picker (the cards' spec tile).
function UI.specMenu(owner)
    UI.picker(owner, "Spec", function()
        local items = { { heading = "Specialization" } }
        for i = 1, GetNumSpecializations() or 0 do
            local id, name = GetSpecializationInfo(i)
            items[#items + 1] = { label = name, checked = function() return GetSpecialization() == i end, onClick = function()
                if i == GetSpecialization() then return end
                if InCombatLockdown() then return TK.chat("|cffff6666Can't change spec in combat.|r") end
                TK.log("spec change to %s (card)", name)
                C_SpecializationInfo.SetSpecialization(i)
            end }
        end
        items[#items + 1] = { heading = "Loot" }
        items[#items + 1] = { label = "Current spec", checked = function() return GetLootSpecialization() == 0 end,
            onClick = function() SetLootSpecialization(0) UI.refreshCards() return "keep" end }
        for i = 1, GetNumSpecializations() or 0 do
            local id, name = GetSpecializationInfo(i)
            items[#items + 1] = { label = name, checked = function() return GetLootSpecialization() == id end,
                onClick = function() SetLootSpecialization(id) UI.refreshCards() return "keep" end }
        end
        return items
    end)
end

-- Cards redraw when the loot spec changes (its badge); set by whoever shows cards.
function UI.refreshCards() if TK.readycheck and TK.readycheck.refresh then TK.readycheck.refresh() end end

-- This spec's builds, by group, in a picker; onPick(b).
function UI.buildMenu(owner, specID, onPick)
    UI.picker(owner, "Builds", function()
        local items = {}
        for _, line in ipairs(TK.builds.ordered(specID)) do
            if line.header then items[#items + 1] = { heading = line.header }
            elseif line.build then
                local b = line.build
                items[#items + 1] = { label = b.name, onClick = function() onPick(b) end }
            end
        end
        if #items == 0 then items[1] = { label = "No builds saved for this spec yet.", disabled = true } end
        return items
    end)
end

-- The suite's pulse ("this wants a click"): three 1 s fades, then it stops. UI.pulse(region)
-- returns a function that plays it, unless motion is turned off.
function UI.pulse(region)
    local g = region:CreateAnimationGroup()
    local a = g:CreateAnimation("Alpha")
    a:SetFromAlpha(1); a:SetToAlpha(0.35); a:SetDuration(0.5); a:SetSmoothing("IN_OUT")
    local b = g:CreateAnimation("Alpha")
    b:SetFromAlpha(0.35); b:SetToAlpha(1); b:SetDuration(0.5); b:SetStartDelay(0.5); b:SetSmoothing("IN_OUT")
    g:SetLooping("REPEAT")
    g:SetScript("OnPlay", function(self) self.n = 0 end)
    g:SetScript("OnLoop", function(self) self.n = self.n + 1 if self.n >= 3 then self:Stop() end end)
    return function() if not TK.db.noMotion then g:Stop() g:Play() end end
end

-- The version as the suite shows it: yellow while it's a dev, alpha or beta build, else muted.
function UI.versionText()
    local v = TK.version or ""
    return ((v:find("^dev") or v:find("%-alpha") or v:find("%-beta")) and "|cffffd84a" or "|cff8c8c8c") .. v .. "|r"
end

-- The header: a 26px faint band over a black rule, with the icon, the two-tone name and the
-- version (head.version) on the left, as the suite's other headers.
function UI.header(f)
    local head = CreateFrame("Frame", nil, f)
    head:SetPoint("TOPLEFT"); head:SetPoint("TOPRIGHT")
    head:SetHeight(26)
    fill(head, "BACKGROUND", 1, 1, 1, 0.035)
    local rule = head:CreateTexture(nil, "OVERLAY")
    rule:SetColorTexture(0, 0, 0, 1)
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT"); rule:SetPoint("BOTTOMRIGHT")
    local mark = head:CreateTexture(nil, "ARTWORK")
    mark:SetSize(16, 16)
    mark:SetPoint("LEFT", 8, 0)
    mark:SetTexture("Interface\\AddOns\\TalentKeeper\\icon.png")
    local name = head:CreateFontString(nil, "OVERLAY", "TalentKeeperFont")
    name:SetPoint("LEFT", mark, "RIGHT", 6, 0)
    name:SetText("|cffffffffTalent|r|cffb3b3b3Keeper|r")
    head.version = head:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    head.version:SetPoint("BOTTOMLEFT", name, "BOTTOMRIGHT", 6, 1)
    head.version:SetText(UI.versionText())
    return head
end

-- Drag to move, only when it's on its own.
local function movable(f)
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) if not self.inPane then self:StartMoving() end end)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
end

-- Text window --------------------------------------------------------------------
-- UI.textWindow{ title, text, okText?, onOK?(text), readOnly?, singleLine?, alone? }
-- In the side pane while the talent window is open; alone = always its own window (the log).
local win
local function makeWindow()
    win = CreateFrame("Frame", "TalentKeeperTextWindow", UIParent)
    win:SetSize(460, 260)
    movable(win)
    win.bg = fill(win, "BACKGROUND", 0.031, 0.031, 0.031, 0.97)
    win.setEdge = ring(win, 0)
    tinsert(UISpecialFrames, win:GetName()) -- Escape closes it

    win.title = win:CreateFontString(nil, "OVERLAY", "TalentKeeperFontLarge")
    win.title:SetPoint("TOPLEFT", 12, -10)
    win.title:SetPoint("RIGHT", -12, 0)
    win.title:SetJustifyH("LEFT")
    win.title:SetWordWrap(false) -- a long build name ends in "..." in the pane

    win.box = CreateFrame("Frame", nil, win)
    win.box:SetPoint("TOPLEFT", 12, -36)
    win.box:SetPoint("TOPRIGHT", -12, -36)
    fill(win.box, "BACKGROUND", 1, 1, 1, 0.08)
    win.setRing = ring(win.box, 0.4)

    win.scroll = CreateFrame("ScrollFrame", nil, win.box, "ScrollFrameTemplate")
    win.scroll:SetPoint("TOPLEFT", 6, -6)
    win.scroll:SetPoint("BOTTOMRIGHT", -24, 6)
    win.edit = CreateFrame("EditBox", nil, win.scroll)
    win.edit:SetFontObject(ChatFontNormal)
    win.edit:SetAutoFocus(false)
    win.edit:SetSize(400, 20)
    win.scroll:SetScrollChild(win.edit)
    -- An edit box inside a scroll frame draws nothing until it has a size: track the scroll area.
    win.scroll:SetScript("OnSizeChanged", function(_, w, h) win.edit:SetWidth(w) win.edit:SetHeight(h) end)
    win.edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); win:Hide() end)
    win.edit:SetScript("OnEditFocusGained", function() win.setRing(1) end)
    win.edit:SetScript("OnEditFocusLost", function() win.setRing(0.4) end)
    win.edit:SetScript("OnEnterPressed", function(self)
        if win.single and win.ok:IsShown() then win.ok:Click() end
    end)
    win.edit:SetScript("OnTextChanged", function(self, user)
        if user and win.readOnly then self:SetText(win.fixedText) self:HighlightText() end
    end)
    win.box:SetScript("OnMouseDown", function() win.edit:SetFocus() end)

    win.close = button(win, "Close", 80, function() win:Hide() end)
    win.lastButton, win.alonePoint = win.close, { "TOPRIGHT", win.box, "BOTTOMRIGHT", 0, -10 }
    win.ok = button(win, "Save", 80, function()
        local text = win.edit:GetText()
        win:Hide()
        if win.onOK then win.onOK(text) end
    end)
    win.ok:SetPoint("RIGHT", win.close, "LEFT", -4, 0)
    win:SetScript("OnHide", function() win.edit:ClearFocus() end)
end

function UI.textWindow(opts)
    if not win then makeWindow() end
    win.title:SetText(opts.title)
    win.onOK, win.readOnly, win.single, win.fixedText = opts.onOK, opts.readOnly, opts.singleLine, opts.text or ""
    win.edit:SetMultiLine(not opts.singleLine)
    local inPane = UI.dock(win, opts.alone)
    local boxH = opts.singleLine and 24 or inPane and 140 or 180
    win.box:SetHeight(boxH)
    win:SetWidth(460)
    win:SetHeight(36 + boxH + 10 + 20 + 12)
    win.close:SetText(inPane and "Cancel" or "Close")
    win.ok:SetText(opts.okText or "Save")
    win.ok:SetShown(opts.onOK ~= nil)
    win.edit:SetText(opts.text or "")
    win:Show()
    win.edit:SetFocus()
    win.edit:HighlightText()
    if opts.readOnly then win.edit:SetCursorPosition(#win.fixedText) win.edit:HighlightText() end
end

-- Save / import dialog -----------------------------------------------------------------
-- One step: the talent string (import only), the build's name, its group and what it's for.
-- If the talents are already saved, that build gets the "for" tags instead (B.add).
local dlg
local function editBox(parent, multi)
    local box = CreateFrame("Frame", nil, parent)
    box:SetHeight(24)
    fill(box, "BACKGROUND", 1, 1, 1, 0.08)
    local setRing = ring(box, 0.4)
    local e = CreateFrame("EditBox", nil, box)
    e:SetFontObject(ChatFontNormal)
    e:SetAutoFocus(false)
    e:SetMultiLine(multi or false)
    e:SetPoint("TOPLEFT", 6, -4); e:SetPoint("BOTTOMRIGHT", -6, 4)
    e:SetScript("OnEditFocusGained", function() setRing(1) end)
    e:SetScript("OnEditFocusLost", function() setRing(0.4) end)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() dlg:Hide() end)
    e:SetScript("OnTabPressed", function(self) if self.next then self.next:SetFocus() end end)
    box:SetScript("OnMouseDown", function() e:SetFocus() end)
    box.edit = e
    return box
end

local function caption(parent, text, anchor)
    local fs = parent:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    fs:SetTextColor(0.55, 0.55, 0.55)
    fs:SetText(text)
    fs:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 3)
    return fs
end

local function makeDialog()
    dlg = CreateFrame("Frame", "TalentKeeperBuildDialog", UIParent)
    dlg:SetWidth(380)
    movable(dlg)
    dlg.bg = fill(dlg, "BACKGROUND", 0.031, 0.031, 0.031, 0.97)
    dlg.setEdge = ring(dlg, 0)
    tinsert(UISpecialFrames, dlg:GetName())
    dlg.title = dlg:CreateFontString(nil, "OVERLAY", "TalentKeeperFontLarge")
    dlg.title:SetPoint("TOPLEFT", 12, -10)
    dlg.text = editBox(dlg) -- one line, like the string: it scrolls inside the box
    dlg.text:SetPoint("TOPLEFT", 12, -54); dlg.text:SetPoint("TOPRIGHT", -12, -54)
    dlg.textCap = caption(dlg, "Talent string", dlg.text)
    dlg.name = editBox(dlg)
    dlg.nameCap = caption(dlg, "Name", dlg.name)
    dlg.group = editBox(dlg)
    dlg.group:SetPoint("TOPLEFT", dlg.name, "BOTTOMLEFT", 0, -22)
    dlg.group:SetPoint("TOPRIGHT", dlg.name, "BOTTOMRIGHT", -30, -22)
    caption(dlg, "Group (blank for none)", dlg.group)
    dlg.pick = button(dlg, "...", 24, function(self)
        UI.picker(self, "Group", function()
            local cur = strtrim(dlg.group.edit:GetText())
            local items = { { label = "No group", checked = function() return cur == "" end, onClick = function() dlg.group.edit:SetText("") end } }
            for _, g in ipairs(B.groups(B.specID())) do
                items[#items + 1] = { label = g, checked = function() return cur == g end, onClick = function() dlg.group.edit:SetText(g) end }
            end
            return items
        end)
    end)
    dlg.pick:SetPoint("LEFT", dlg.group, "RIGHT", 6, 0)
    -- what it's for: a draft of tags, set on the build only when you press Import / Save
    dlg.forBox = CreateFrame("Frame", nil, dlg)
    dlg.forBox:SetHeight(24)
    fill(dlg.forBox, "BACKGROUND", 1, 1, 1, 0.08)
    ring(dlg.forBox, 0.4)
    dlg.forBox:SetPoint("TOPLEFT", dlg.group, "BOTTOMLEFT", 0, -22)
    dlg.forBox:SetPoint("TOPRIGHT", dlg.group, "BOTTOMRIGHT", 0, -22)
    dlg.forText = dlg.forBox:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    dlg.forText:SetPoint("LEFT", 6, 0); dlg.forText:SetPoint("RIGHT", -6, 0)
    dlg.forText:SetJustifyH("LEFT"); dlg.forText:SetWordWrap(false)
    caption(dlg, "Tags (blank for none yet)", dlg.forBox)
    local function showFor() dlg.forText:SetText(UI.tagSummary(dlg.draft) or "") end
    dlg.showFor = showFor
    local function draftToggle(_, key, name)
        local t = dlg.draft.tags or {}
        t[key] = not t[key] and name or nil
        dlg.draft.tags = next(t) and t or nil
        showFor()
    end
    dlg.forPick = button(dlg, "...", 24, function(self)
        UI.picker(self, "Tags", function() return UI.tagItems(dlg.draft, draftToggle) end)
    end)
    dlg.forPick:SetPoint("LEFT", dlg.forBox, "RIGHT", 6, 0)
    dlg.text.edit.next, dlg.name.edit.next, dlg.group.edit.next = dlg.name.edit, dlg.group.edit, nil
    dlg.cancel = button(dlg, "Cancel", 80, function() dlg:Hide() end)
    dlg.lastButton, dlg.alonePoint = dlg.cancel, { "TOPRIGHT", dlg.forPick, "BOTTOMRIGHT", 0, -16 }
    dlg.ok = button(dlg, "Save", 80, function()
        local text, name, group = dlg.text.edit:GetText(), strtrim(dlg.name.edit:GetText()), strtrim(dlg.group.edit:GetText())
        group = group ~= "" and group or nil
        local tags = dlg.draft.tags
        dlg:Hide()
        TK.lastGroup = group
        if dlg.import then B.importString(text, name, group, tags) else B.saveCurrent(name, group, tags) end
    end)
    dlg.ok:SetPoint("RIGHT", dlg.cancel, "LEFT", -4, 0)
    for _, box in ipairs({ dlg.name, dlg.group }) do
        box.edit:SetScript("OnEnterPressed", function() dlg.ok:Click() end)
    end
    dlg:SetScript("OnHide", function()
        dlg.text.edit:ClearFocus() dlg.name.edit:ClearFocus() dlg.group.edit:ClearFocus()
        if dlg.import and TK.window then TK.safe(TK.window.preview)(nil) end -- drop the pasted build's marks
    end)
    -- Import: the pasted string shows on the tree before it's saved; the note says what you see
    dlg.note = dlg:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    dlg.note:SetPoint("TOPLEFT", dlg.text, "BOTTOMLEFT", 0, -3)
    dlg.note:SetPoint("RIGHT", dlg.text, "RIGHT")
    dlg.note:SetJustifyH("LEFT")
    dlg.note:SetTextColor(0.55, 0.55, 0.55)
    dlg.text.edit:SetScript("OnTextChanged", TK.safe(function(self)
        if not dlg.import then return end
        local text = strtrim(self:GetText())
        local spec = text ~= "" and B.stringSpec(text)
        local preview, note = nil, ""
        if spec and spec ~= B.specID() then
            note = ("For %s: change to it to see this build on the tree."):format(B.specName(spec))
        elseif spec then
            local d = TK.compare.diff(B.currentString(), text)
            if d then
                preview = text
                note = #d == 0 and "Same as your talents now." or "Shown on the tree."
            end
        elseif text ~= "" then
            note = "|cffff6666That isn't a talent string.|r"
        end
        dlg.note:SetText(note)
        if TK.window then TK.window.preview(preview) end
    end))
end

-- import = true: paste a string; otherwise save your current talents.
function UI.buildDialog(import)
    local specID = B.specID()
    if not specID then return TK.chat("Pick a specialization first.") end
    if not dlg then makeDialog() end
    dlg.import = import
    UI.dock(dlg)
    dlg.title:SetText(import and "Import a build" or "Save your current talents")
    dlg.text:SetShown(import)
    dlg.textCap:SetShown(import)
    dlg.name:ClearAllPoints()
    local top = import and -114 or -54 -- room for the preview note under the string
    dlg.name:SetPoint("TOPLEFT", 12, top); dlg.name:SetPoint("TOPRIGHT", -12, top)
    dlg:SetHeight(-top + 24 + 22 + 24 + 22 + 24 + 16 + 20 + 12)
    dlg.draft = {}
    dlg.showFor()
    dlg.text.edit:SetText("")
    dlg.note:SetText("")
    dlg.name.edit:SetText(import and "" or ("%s %d"):format(B.specName(specID), #B.list(specID) + 1))
    local sel = TK.selected
    dlg.group.edit:SetText((sel and sel.group) or TK.lastGroup or "")
    dlg.ok:SetText(import and "Import" or "Save")
    dlg:Show()
    local first = import and dlg.text.edit or dlg.name.edit
    first:SetFocus()
    first:HighlightText()
end

-- Tags: the situations a build is for ----------------------------------------------------
-- This season's raids and their bosses, from the dungeon journal (read once it has them).
local raids
local function seasonRaids()
    if raids or not EJ_GetNumTiers then return raids or {} end
    local out, prev = {}, EJ_GetCurrentTier()
    EJ_SelectTier(EJ_GetNumTiers())
    for i = 1, 20 do
        local journalID, name = EJ_GetInstanceByIndex(i, true)
        if not journalID then break end
        local _, _, _, _, _, _, _, _, hasDifficulty, mapID = EJ_GetInstanceInfo(journalID)
        local raid = { name = name, key = mapID and ("zone:" .. mapID), bosses = {}, world = hasDifficulty == false }
        EJ_SelectInstance(journalID) -- the journal lists a raid's bosses only once it's selected
        for j = 1, 20 do
            local boss, _, _, _, _, _, encounterID = EJ_GetEncounterInfoByIndex(j, journalID)
            if not boss then break end
            if encounterID then raid.bosses[#raid.bosses + 1] = { key = "boss:" .. encounterID, name = boss } end
        end
        if not raid.world then out[#out + 1] = raid end -- world bosses aren't a place to tag
    end
    if prev then EJ_SelectTier(prev) end
    local bosses, names = 0, {}
    for _, r in ipairs(out) do bosses = bosses + #r.bosses names[#names + 1] = ("%s (%d)"):format(r.name, #r.bosses) end
    TK.log("journal: raids %s", #names > 0 and table.concat(names, ", ") or "none")
    if #out > 0 and bosses > 0 then raids = out end -- keep asking until the journal has the bosses
    return out
end

local function seasonDungeons()
    local out = {}
    for _, id in ipairs(C_ChallengeMode and C_ChallengeMode.GetMapTable() or {}) do
        local name, _, _, _, _, mapID = C_ChallengeMode.GetMapUIInfo(id)
        if name and mapID then out[#out + 1] = { key = "zone:" .. mapID, name = name } end
    end
    table.sort(out, function(a, c) return a.name < c.name end)
    return out
end

UI.seasonRaids, UI.seasonDungeons = seasonRaids, seasonDungeons

-- Miscellaneous: places that aren't a dungeon or a raid boss. (PvP comes later.)
local CONTENT = { { key = "delve", name = "Delves" } }
UI.CONTENT = CONTENT

-- Picker: the suite's flat list in a small panel (headings, 24px check rows, plain rows) ------
-- UI.picker(owner, title, items) where items() returns, each time it draws:
--   { heading = "Text" } | { label = "Text" or fn, checked = fn?, onClick = fn, keep = true? }
-- A row with checked toggles and stays open; other rows close it unless keep is set.
local pick
local PROW, PHEAD, PTITLE, PPAD = 18, 18, 20, 6 -- dense rows (the guide allows 18px in dense lists)
local function pickRow(i)
    if pick.rows[i] then return pick.rows[i] end
    local r = CreateFrame("Button", nil, pick.list)
    r:SetHeight(PROW)
    UI.fill(r, "HIGHLIGHT", 0.851, 0.851, 0.851, 0.15)
    r.box = CreateFrame("Frame", nil, r)
    r.box:SetSize(12, 12)
    r.box:SetPoint("LEFT", PPAD, 0)
    fill(r.box, "BACKGROUND", 1, 1, 1, 0.08)
    r.ring = ring(r.box, 0.4)
    r.mark = r.box:CreateTexture(nil, "ARTWORK")
    r.mark:SetPoint("TOPLEFT", 3, -3); r.mark:SetPoint("BOTTOMRIGHT", -3, 3)
    r.mark:SetColorTexture(1, 1, 1, 1)
    r.text = r:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    r.text:SetPoint("RIGHT", -8, 0)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)
    -- an armed "Sure?" flashes: the suite's pulse, three 1 s pulses
    r.flash = r.text:CreateAnimationGroup()
    local fa = r.flash:CreateAnimation("Alpha")
    fa:SetFromAlpha(1); fa:SetToAlpha(0.35); fa:SetDuration(0.5); fa:SetSmoothing("IN_OUT")
    local fb = r.flash:CreateAnimation("Alpha")
    fb:SetFromAlpha(0.35); fb:SetToAlpha(1); fb:SetDuration(0.5); fb:SetStartDelay(0.5); fb:SetSmoothing("IN_OUT")
    r.flash:SetLooping("REPEAT")
    r.flash:SetScript("OnPlay", function(self) self.n = 0 end)
    r.flash:SetScript("OnLoop", function(self) self.n = self.n + 1 if self.n >= 3 then self:Stop() end end)
    r:SetScript("OnEnter", function(self) self.ring(0.7) end)
    r:SetScript("OnLeave", function(self) self.ring(0.4) end)
    r:SetScript("OnClick", TK.safe(function(self)
        local it = self.item
        if not it or not it.onClick then return end
        local keep = it.onClick() == "keep" or it.keep or it.checked ~= nil and it.multi
        if keep then UI.refreshPicker() else pick:Hide() end
    end))
    pick.rows[i] = r
    return r
end

local function pickHead(i)
    if pick.heads[i] then return pick.heads[i] end
    local h = pick.list:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    h:SetTextColor(0.55, 0.55, 0.55)
    pick.heads[i] = h
    return h
end

local function makePicker()
    pick = CreateFrame("Frame", "TalentKeeperPicker", UIParent)
    pick.rows, pick.heads, pick.bars, pick.offset = {}, {}, {}, 0
    pick:SetFrameStrata("FULLSCREEN_DIALOG") -- above whatever opened it (the save / import dialog sits in DIALOG)
    pick:SetClampedToScreen(true)
    pick:EnableMouse(true)
    fill(pick, "BACKGROUND", 0.06, 0.06, 0.06, 0.98)
    ring(pick, 0)
    tinsert(UISpecialFrames, pick:GetName())
    pick.title = pick:CreateFontString(nil, "OVERLAY", "TalentKeeperFont")
    pick.title:SetPoint("TOPLEFT", PPAD, -5); pick.title:SetPoint("TOPRIGHT", -PPAD, -5)
    pick.title:SetJustifyH("LEFT")
    pick.measure = pick:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    pick.measure:Hide()
    pick.title:SetWordWrap(false)
    local rule = pick:CreateTexture(nil, "OVERLAY")
    rule:SetColorTexture(0, 0, 0, 1)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", 0, -PTITLE); rule:SetPoint("TOPRIGHT", 0, -PTITLE)
    pick.list = CreateFrame("Frame", nil, pick)
    pick.list:SetPoint("TOPLEFT", 0, -(PTITLE + 3)); pick.list:SetPoint("BOTTOMRIGHT", 0, 3)
    pick.list:SetClipsChildren(true)
    pick.list:EnableMouseWheel(true)
    pick.list:SetScript("OnMouseWheel", function(_, delta) pick.offset = pick.offset - delta * PROW * 3 UI.refreshPicker() end)
    -- "more below": pulses 3 times, then holds
    pick.more = pick:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    pick.more:SetPoint("BOTTOM", 0, 3)
    pick.more:SetText("v  more below  v")
    pick.more:SetTextColor(1, 1, 1)
    pick.pulse = pick.more:CreateAnimationGroup()
    local a = pick.pulse:CreateAnimation("Alpha")
    a:SetFromAlpha(1); a:SetToAlpha(0.3); a:SetDuration(0.5)
    pick.pulse:SetLooping("BOUNCE")
    pick.pulse:SetScript("OnLoop", function(self)
        self.n = (self.n or 0) + 1
        if self.n >= 6 then self:Stop() pick.more:SetAlpha(1) end
    end)
    -- a click anywhere else closes it
    pick:RegisterEvent("GLOBAL_MOUSE_DOWN")
    pick:SetScript("OnEvent", function(self)
        if self:IsShown() and not self:IsMouseOver() and not (self.owner and self.owner:IsMouseOver()) then self:Hide() end
    end)
end

-- Items split into columns at { column = true }; { bar = true } is a short divider.
local PBAR = 7
local function itemHeight(it) return it.heading and PHEAD or it.bar and PBAR or it.column and 0 or PROW end

function UI.refreshPicker()
    if not pick or not pick:IsShown() then return end
    for _, r in ipairs(pick.rows) do r:Hide() end
    for _, h in ipairs(pick.heads) do h:Hide() end
    for _, t in ipairs(pick.bars) do t:Hide() end
    local cols = { {} }
    for _, it in ipairs(pick.items()) do
        if it.column then cols[#cols + 1] = {} else table.insert(cols[#cols], it) end
    end
    local total = 0
    for _, col in ipairs(cols) do
        local h = 0
        for _, it in ipairs(col) do h = h + itemHeight(it) end
        total = math.max(total, h)
    end
    -- each column as wide as its longest line (the title sets the minimum)
    local widths, x0 = {}, {}
    for c, col in ipairs(cols) do
        local w = 0
        for _, it in ipairs(col) do
            local text = it.heading or (type(it.label) == "function" and it.label() or it.label)
            if text then
                pick.measure:SetText(text)
                w = math.max(w, pick.measure:GetStringWidth() + PPAD * 2 + ((it.checked ~= nil and not it.heading) and 18 or 0))
            end
        end
        widths[c] = math.ceil(w)
    end
    pick.measure:SetFontObject("TalentKeeperFont")
    pick.measure:SetText(pick.title:GetText() or "")
    local titleW = pick.measure:GetStringWidth() + PPAD * 2
    pick.measure:SetFontObject("TalentKeeperFontSmall")
    local sum = 0
    for c = 1, #cols do x0[c] = sum sum = sum + widths[c] end
    if sum < titleW then widths[#cols] = widths[#cols] + math.ceil(titleW - sum) sum = math.ceil(titleW) end
    pick:SetWidth(sum)
    local height = math.min(total, math.floor(UIParent:GetHeight() * 0.6))
    pick:SetHeight(PTITLE + 3 + height + 3)
    pick.offset = math.max(0, math.min(pick.offset, total - height))
    local nr, nh, nb, below = 0, 0, 0, false
    for c, col in ipairs(cols) do
        local x, y, cw = x0[c], 0, widths[c]
        for _, it in ipairs(col) do
            local h = itemHeight(it)
            local top = y - pick.offset
            if top + h > height then below = true end
            if top >= 0 and top + h <= height then
                if it.heading then
                    nh = nh + 1
                    local fs = pickHead(nh)
                    fs:SetText(it.heading)
                    fs:ClearAllPoints()
                    fs:SetPoint("BOTTOMLEFT", pick.list, "TOPLEFT", x + PPAD, -(top + h - 3))
                    fs:Show()
                elseif it.bar then
                    nb = nb + 1
                    local t = pick.bars[nb]
                    if not t then
                        t = pick.list:CreateTexture(nil, "ARTWORK")
                        t:SetColorTexture(1, 1, 1, 0.12)
                        t:SetTexelSnappingBias(0); t:SetSnapToPixelGrid(false)
                        pick.bars[nb] = t
                    end
                    t:ClearAllPoints()
                    t:SetSize(cw - PPAD * 2, 1)
                    t:SetPoint("TOPLEFT", x + PPAD, -(top + 3))
                    t:Show()
                else
                    nr = nr + 1
                    local r = pickRow(nr)
                    r.item = it
                    local check = it.checked ~= nil
                    r.box:SetShown(check)
                    if check then r.mark:SetShown(it.checked() and true or false) end
                    r.text:ClearAllPoints()
                    r.text:SetPoint("LEFT", check and (PPAD + 18) or PPAD, 0); r.text:SetPoint("RIGHT", -PPAD, 0)
                    local label = type(it.label) == "function" and it.label() or it.label
                    r.text:SetText(label)
                    local armed = it.armed and it.armed()
                    if armed and not r.wasArmed then r.flash:Play() elseif not armed then r.flash:Stop() r.text:SetAlpha(1) end
                    r.wasArmed = armed
                    if it.disabled then r.text:SetTextColor(0.55, 0.55, 0.55) else r.text:SetTextColor(1, 1, 1) end
                    r:EnableMouse(not it.disabled)
                    r:ClearAllPoints()
                    r:SetWidth(cw)
                    r:SetPoint("TOPLEFT", x, -top)
                    r:Show()
                end
            end
            y = y + h
        end
    end
    if below and not pick.more:IsShown() then pick.pulse.n = 0 pick.pulse:Play() end
    pick.more:SetShown(below)
end

function UI.hidePicker() if pick then pick:Hide() end end

function UI.picker(owner, title, items)
    if not pick then makePicker() end
    if pick:IsShown() and pick.owner == owner then return pick:Hide() end -- the same button closes it
    pick.owner, pick.items, pick.offset = owner, items, 0
    pick.title:SetText(title)
    pick:ClearAllPoints()
    if owner and owner ~= UIParent then
        pick:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    else
        local x, y = GetCursorPosition()
        local s = UIParent:GetEffectiveScale()
        pick:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s, y / s)
    end
    pick:Show()
    UI.refreshPicker()
end

-- Tags ----------------------------------------------------------------------------------
local function tagItem(b, s, toggle)
    return { label = s.name, multi = true, checked = function() return b.tags and b.tags[s.key] ~= nil end,
        onClick = function() toggle(b, s.key, s.name) end }
end

-- Two columns: Miscellaneous (Delves) and this season's dungeons; then each raid's bosses.
-- toggle(b, key, name) defaults to B.toggleTag (the import dialog passes its own for a draft).
function UI.tagItems(b, toggle)
    toggle = toggle or B.toggleTag
    local items = {}
    items[#items + 1] = { heading = "Miscellaneous" }
    for _, s in ipairs(CONTENT) do items[#items + 1] = tagItem(b, s, toggle) end
    local dungeons = seasonDungeons()
    if #dungeons > 0 then
        items[#items + 1] = { bar = true }
        items[#items + 1] = { heading = "Mythic+ dungeons" }
        for _, s in ipairs(dungeons) do items[#items + 1] = tagItem(b, s, toggle) end
    end
    items[#items + 1] = { column = true }
    for _, raid in ipairs(seasonRaids()) do
        items[#items + 1] = { heading = raid.name }
        for _, s in ipairs(raid.bosses) do items[#items + 1] = tagItem(b, s, toggle) end
    end
    return items
end

function UI.tagMenu(owner, b)
    UI.picker(owner, "Tags: " .. b.name, function() return UI.tagItems(b) end)
end

-- "Raid +2"
function UI.tagSummary(b)
    local names = B.tagNames(b)
    if #names == 0 then return nil end
    return names[1] .. (#names > 1 and (" +" .. (#names - 1)) or "")
end

function UI.groupItems(specID, b)
    local items = { { label = "No group", checked = function() return not b.group end, onClick = function() B.setGroup(b, nil) end } }
    for _, g in ipairs(B.groups(specID)) do
        items[#items + 1] = { label = g, checked = function() return b.group == g end, onClick = function() B.setGroup(b, g) end }
    end
    items[#items + 1] = { label = "New group...", onClick = function()
        UI.textWindow({ title = "New group for " .. b.name, singleLine = true, okText = "Move",
            onOK = function(name) if strtrim(name) ~= "" then B.setGroup(b, name) end end })
    end }
    return items
end

function UI.groupMenu(owner, specID, b)
    -- From More...: swap the open picker's list instead of the same-owner toggle closing it.
    if pick then pick.owner = nil end
    UI.picker(owner, "Move " .. b.name .. " to", function() return UI.groupItems(specID, b) end)
end

-- Gear set: none, or one of the game's equipment sets (Blizzard's Equipment Manager makes them).
function UI.gearItems(b)
    local items = {}
    local specID = B.findSpec(b)
    local own = specID and B.specGearSet(specID)
    if own then
        -- two short lines: the picker grows to its widest row
        items[1] = { label = ("|cffffd84a%s uses %s (Equipment Manager)|r"):format(B.specName(specID), own), disabled = true }
        items[2] = { label = "so TalentKeeper won't swap its gear.", disabled = true }
    end
    items[#items + 1] = { label = "None", checked = function() return not b.gear end, onClick = function() B.setGear(b, nil) end }
    for _, id in ipairs(C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs() or {}) do
        local name, icon = C_EquipmentSet.GetEquipmentSetInfo(id)
        if name then
            items[#items + 1] = { label = (icon and ("|T%s:14:14:0:0:64:64:5:59:5:59|t "):format(icon) or "") .. name,
                checked = function() return b.gear == name end, onClick = function() B.setGear(b, name) end }
        end
    end
    if not C_EquipmentSet or #C_EquipmentSet.GetEquipmentSetIDs() == 0 then items[#items + 1] = { label = "No gear sets yet: make one in the character window's Equipment Manager.", disabled = true } end
    return items
end

function UI.gearMenu(owner, b)
    if pick then pick.owner = nil end -- from More...: swap the open list
    UI.picker(owner, "Gear set for " .. b.name, function() return UI.gearItems(b) end)
end

-- Quick menu (key binding, /tk): this spec's builds; click one to apply it -------------------
function UI.quickItems(specID)
    local items = {}
    for _, line in ipairs(B.ordered(specID)) do
        if line.header then
            items[#items + 1] = { heading = line.header }
        elseif line.build then
            local b = line.build
            local tags = UI.tagSummary(b)
            items[#items + 1] = { label = b.name .. (tags and ("  |cff8c8c8c" .. tags .. "|r") or ""),
                checked = function() return TK.db.active[specID] == b.name end, onClick = function() B.apply(b) end }
        end
    end
    if #items == 0 then items[1] = { label = "No builds saved for this spec yet.", disabled = true } end
    return items
end

function UI.openMenu(owner)
    local specID = B.specID()
    if not specID then return TK.chat("Pick a specialization first.") end
    UI.picker(owner or UIParent, B.specName(specID) .. " builds", function() return UI.quickItems(specID) end)
end

-- Key binding (Bindings.xml)
BINDING_HEADER_TALENTKEEPER = "TalentKeeper"
BINDING_NAME_TALENTKEEPER_MENU = "Open your builds"
function TalentKeeper_OpenMenu() TK.safe(UI.openMenu)() end
