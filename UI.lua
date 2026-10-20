-- TalentKeeper UI: fonts, buttons, the save / import dialog, the picker (tags, groups, the
-- quick build list for the key binding and /tk), and one small text window (copy, log).
local addonName, TK = ...
local B = TK.builds
local UI = {}
TK.ui = UI

-- Fonts and colors (suite style guide) ---------------------------------------------
local FONT = "Interface\\AddOns\\" .. addonName .. "\\Media\\BarlowSemiCondensed-Medium.ttf"
local SIZES = { TalentKeeperFontSmall = 10, TalentKeeperFont = 12, TalentKeeperFontLarge = 16, TalentKeeperFontDisabled = 12 }
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

-- Flat button: face at rest, gray ring, hover wash.
local function button(parent, label, width, onClick)
    local bt = CreateFrame("Button", nil, parent)
    bt:SetSize(width, 24)
    fill(bt, "BACKGROUND", 1, 1, 1, 0.07)
    local setRing = ring(bt, 0.4)
    local hover = fill(bt, "HIGHLIGHT", 0.851, 0.851, 0.851, 0.15)
    hover:SetBlendMode("BLEND")
    bt:SetNormalFontObject(TalentKeeperFont)
    bt:SetDisabledFontObject(disabledFont)
    bt:SetText(label)
    bt:SetScript("OnEnter", function() setRing(0.7) end)
    bt:SetScript("OnLeave", function() setRing(0.4) end)
    bt:SetScript("OnClick", TK.safe(onClick))
    return bt
end

UI.fill, UI.ring, UI.button = fill, ring, button

-- Text window --------------------------------------------------------------------
-- UI.textWindow{ title, text, okText?, onOK?(text), readOnly?, singleLine? }
local win
local function makeWindow()
    win = CreateFrame("Frame", "TalentKeeperTextWindow", UIParent)
    win:SetSize(460, 260)
    win:SetPoint("CENTER")
    win:SetFrameStrata("DIALOG")
    win:SetMovable(true); win:EnableMouse(true); win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    win:SetClampedToScreen(true)
    fill(win, "BACKGROUND", 0.031, 0.031, 0.031, 0.97)
    ring(win, 0)
    tinsert(UISpecialFrames, win:GetName()) -- Escape closes it

    win.title = win:CreateFontString(nil, "OVERLAY", "TalentKeeperFontLarge")
    win.title:SetPoint("TOPLEFT", 12, -10)

    win.box = CreateFrame("Frame", nil, win)
    win.box:SetPoint("TOPLEFT", 12, -36)
    win.box:SetPoint("BOTTOMRIGHT", -12, 44)
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
    win.edit:SetScript("OnEditFocusGained", function() win.setRing(0.596) end)
    win.edit:SetScript("OnEditFocusLost", function() win.setRing(0.4) end)
    win.edit:SetScript("OnEnterPressed", function(self)
        if win.single and win.ok:IsShown() then win.ok:Click() end
    end)
    win.edit:SetScript("OnTextChanged", function(self, user)
        if user and win.readOnly then self:SetText(win.fixedText) self:HighlightText() end
    end)
    win.box:SetScript("OnMouseDown", function() win.edit:SetFocus() end)

    win.close = button(win, "Close", 80, function() win:Hide() end)
    win.close:SetPoint("BOTTOMRIGHT", -12, 12)
    win.ok = button(win, "Save", 80, function()
        local text = win.edit:GetText()
        win:Hide()
        if win.onOK then win.onOK(text) end
    end)
    win.ok:SetPoint("RIGHT", win.close, "LEFT", -8, 0)
    win:SetScript("OnHide", function() win.edit:ClearFocus() end)
end

function UI.textWindow(opts)
    if not win then makeWindow() end
    win.title:SetText(opts.title)
    win.onOK, win.readOnly, win.single, win.fixedText = opts.onOK, opts.readOnly, opts.singleLine, opts.text or ""
    win.edit:SetMultiLine(not opts.singleLine)
    win:SetHeight(opts.singleLine and 120 or 260)
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
    e:SetScript("OnEditFocusGained", function() setRing(0.596) end)
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
    dlg:SetPoint("CENTER")
    dlg:SetFrameStrata("DIALOG")
    dlg:SetMovable(true); dlg:EnableMouse(true); dlg:RegisterForDrag("LeftButton")
    dlg:SetScript("OnDragStart", dlg.StartMoving)
    dlg:SetScript("OnDragStop", dlg.StopMovingOrSizing)
    dlg:SetClampedToScreen(true)
    fill(dlg, "BACKGROUND", 0.031, 0.031, 0.031, 0.97)
    ring(dlg, 0)
    tinsert(UISpecialFrames, dlg:GetName())
    dlg.title = dlg:CreateFontString(nil, "OVERLAY", "TalentKeeperFontLarge")
    dlg.title:SetPoint("TOPLEFT", 12, -10)
    dlg.text = editBox(dlg, true)
    dlg.text:SetHeight(64)
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
    caption(dlg, "For (blank for nothing yet)", dlg.forBox)
    local function showFor() dlg.forText:SetText(UI.tagSummary(dlg.draft) or "") end
    dlg.showFor = showFor
    local function draftToggle(_, key, name)
        local t = dlg.draft.tags or {}
        t[key] = not t[key] and name or nil
        dlg.draft.tags = next(t) and t or nil
        showFor()
    end
    dlg.forPick = button(dlg, "...", 24, function(self)
        UI.picker(self, "For", function() return UI.tagItems(dlg.draft, draftToggle) end)
    end)
    dlg.forPick:SetPoint("LEFT", dlg.forBox, "RIGHT", 6, 0)
    dlg.text.edit.next, dlg.name.edit.next, dlg.group.edit.next = dlg.name.edit, dlg.group.edit, nil
    dlg.cancel = button(dlg, "Cancel", 80, function() dlg:Hide() end)
    dlg.cancel:SetPoint("BOTTOMRIGHT", -12, 12)
    dlg.ok = button(dlg, "Save", 80, function()
        local text, name, group = dlg.text.edit:GetText(), strtrim(dlg.name.edit:GetText()), strtrim(dlg.group.edit:GetText())
        group = group ~= "" and group or nil
        local tags = dlg.draft.tags
        dlg:Hide()
        TK.lastGroup = group
        if dlg.import then B.importString(text, name, group, tags) else B.saveCurrent(name, group, tags) end
    end)
    dlg.ok:SetPoint("RIGHT", dlg.cancel, "LEFT", -8, 0)
    for _, box in ipairs({ dlg.name, dlg.group }) do
        box.edit:SetScript("OnEnterPressed", function() dlg.ok:Click() end)
    end
    dlg:SetScript("OnHide", function() dlg.text.edit:ClearFocus() dlg.name.edit:ClearFocus() dlg.group.edit:ClearFocus() end)
end

-- import = true: paste a string; otherwise save your current talents.
function UI.buildDialog(import)
    local specID = B.specID()
    if not specID then return TK.chat("Pick a specialization first.") end
    if not dlg then makeDialog() end
    dlg.import = import
    dlg.title:SetText(import and "Import a build" or "Save your current talents")
    dlg.text:SetShown(import)
    dlg.textCap:SetShown(import)
    dlg.name:ClearAllPoints()
    local top = import and -148 or -54
    dlg.name:SetPoint("TOPLEFT", 12, top); dlg.name:SetPoint("TOPRIGHT", -12, top)
    dlg:SetHeight(-top + 24 + 22 + 24 + 22 + 24 + 56)
    dlg.draft = {}
    dlg.showFor()
    dlg.text.edit:SetText("")
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

local CONTENT = { { key = "delve", name = "Delves" } }

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
    r.mark:SetColorTexture(0.596, 1, 0.596, 1)
    r.text = r:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    r.text:SetPoint("RIGHT", -8, 0)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)
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
    pick:SetFrameStrata("DIALOG")
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
    pick.more:SetTextColor(0.596, 1, 0.596)
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

-- Two columns: Delves and this season's dungeons; then each raid's bosses.
-- toggle(b, key, name) defaults to B.toggleTag (the import dialog passes its own for a draft).
function UI.tagItems(b, toggle)
    toggle = toggle or B.toggleTag
    local items = {}
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
    UI.picker(owner, b.name .. " is for", function() return UI.tagItems(b) end)
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
    UI.picker(owner, "Move " .. b.name .. " to", function() return UI.groupItems(specID, b) end)
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
