-- TalentKeeper management window: every spec you have builds for (left), that spec's
-- builds by group (right), search by build or talent name, drag a build onto a group,
-- and Apply / Rename / Copy / Compare / Delete for the selected build.
local _, TK = ...
local B, C, UI = TK.builds, TK.compare, TK.ui
local M = {}
TK.manager = M

local ROW, W, H, LEFT_W = 24, 660, 440, 190
local ROWS = math.floor((H - 44 - 70 - 4) / ROW) -- rows that fit in each pane
local frame, specRows, buildRows = nil, {}, {}
local state = { spec = nil, selected = nil, search = "", specScroll = 0, buildScroll = 0, compareFrom = nil, armed = nil }

local function classOf(specID)
    local _, _, _, _, _, classFile = GetSpecializationInfoByID(specID)
    return classFile
end

local function className(classFile)
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile]) or classFile or "?"
end

local function classColor(classFile)
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    return c and c.colorStr or "ffffffff"
end

-- Rows --------------------------------------------------------------------------------
local function makeRow(parent, onClick)
    local r = CreateFrame("Button", nil, parent)
    r:SetHeight(ROW)
    r.stripe = UI.fill(r, "BACKGROUND", 1, 1, 1, 0.05)
    r.sel = UI.fill(r, "BORDER", 0.596, 1, 0.596, 0.15)
    local hover = UI.fill(r, "HIGHLIGHT", 0.851, 0.851, 0.851, 0.15)
    hover:SetBlendMode("BLEND")
    r.left = r:CreateFontString(nil, "OVERLAY", "TalentKeeperFont")
    r.left:SetPoint("LEFT", 8, 0)
    r.left:SetJustifyH("LEFT")
    r.right = r:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    r.right:SetPoint("RIGHT", -8, 0)
    r.right:SetJustifyH("RIGHT")
    r.left:SetPoint("RIGHT", r.right, "LEFT", -8, 0)
    r.left:SetWordWrap(false)
    r:SetScript("OnClick", TK.safe(function(self) onClick(self) end))
    return r
end

-- What the right side lists: group headings and builds, filtered by search.
local function buildLines()
    local list = state.spec and B.list(state.spec) or {}
    local q = state.search:lower()
    local groups, order, loose = {}, {}, {}
    for _, b in ipairs(list) do
        local hit = q == "" or b.name:lower():find(q, 1, true) or C.searchText(b.text):find(q, 1, true)
        if hit then
            if b.group then
                if not groups[b.group] then groups[b.group] = {}; order[#order + 1] = b.group end
                table.insert(groups[b.group], b)
            else
                loose[#loose + 1] = b
            end
        end
    end
    local lines = {}
    for _, g in ipairs(order) do
        lines[#lines + 1] = { header = g }
        for _, b in ipairs(groups[g]) do lines[#lines + 1] = { build = b } end
    end
    lines[#lines + 1] = { header = false } -- "No group"
    for _, b in ipairs(loose) do lines[#lines + 1] = { build = b } end
    lines[#lines + 1] = { newGroup = true }
    return lines, list
end

local function specLines()
    local specs = {}
    for specID, list in pairs(TK.db.builds) do if #list > 0 then specs[#specs + 1] = specID end end
    local current = B.specID()
    if current and not tContains(specs, current) then specs[#specs + 1] = current end
    table.sort(specs, function(a, b)
        local ca, cb = classOf(a) or "", classOf(b) or ""
        if ca ~= cb then
            if ca == classOf(current) then return true elseif cb == classOf(current) then return false end
            return ca < cb
        end
        return a < b
    end)
    local lines, lastClass = {}, nil
    for _, specID in ipairs(specs) do
        local cls = classOf(specID)
        if cls ~= lastClass then lines[#lines + 1] = { class = cls }; lastClass = cls end
        lines[#lines + 1] = { spec = specID }
    end
    return lines
end

-- Drawing ------------------------------------------------------------------------------

local function drawSpecs()
    local lines = specLines()
    local n = ROWS
    state.specScroll = math.max(0, math.min(state.specScroll, #lines - n))
    for i = 1, n do
        local r = specRows[i] or makeRow(frame.specPane, function(self)
            if self.specID then
                state.spec, state.selected, state.buildScroll, state.compareFrom = self.specID, nil, 0, nil
                M.refresh()
            end
        end)
        specRows[i] = r
        r:SetPoint("TOPLEFT", 2, -2 - (i - 1) * ROW)
        r:SetPoint("TOPRIGHT", -2, -2 - (i - 1) * ROW)
        local line = lines[i + state.specScroll]
        r.specID = line and line.spec
        r:SetShown(line ~= nil)
        r.stripe:SetShown(i % 2 == 0)
        r.sel:SetShown(line and line.spec == state.spec or false)
        if line and line.class then
            r.left:SetText(("|c%s%s|r"):format(classColor(line.class), className(line.class)))
            r.right:SetText("")
            r:EnableMouse(false)
        elseif line then
            r.left:SetText("   " .. B.specName(line.spec) .. (line.spec == B.specID() and "  |cff98ff98(you)|r" or ""))
            r.right:SetText(("|cff8c8c8c%d|r"):format(#B.list(line.spec)))
            r:EnableMouse(true)
        end
    end
    for i = n + 1, #specRows do specRows[i]:Hide() end
end

local function badges(list, b)
    local out = {}
    local hero = C.heroName(b.text)
    if hero then out[#out + 1] = "|cffbdbdbd" .. hero .. "|r" end
    if state.spec == B.specID() and TK.db.active[state.spec] == b.name then out[#out + 1] = "|cff98ff98Active|r" end
    local same = C.sameAsEarlier(list, b)
    if same then out[#out + 1] = "|cff8c8c8csame as " .. same.name .. "|r" end
    if b.outdated then out[#out + 1] = "|cffffb84dOutdated|r" end
    return table.concat(out, "   ")
end

local function drawBuilds()
    local lines, list = buildLines()
    local n = ROWS
    state.buildScroll = math.max(0, math.min(state.buildScroll, #lines - n))
    for i = 1, n do
        local r = buildRows[i] or makeRow(frame.buildPane, function(self) M.click(self.line) end)
        if not buildRows[i] then
            r:RegisterForDrag("LeftButton")
            r:SetScript("OnDragStart", function(self) if self.line and self.line.build then M.dragging = self.line.build; SetCursor("Interface\\Cursor\\UI-Cursor-Move") end end)
            r:SetScript("OnDragStop", TK.safe(function() M.drop() end))
        end
        buildRows[i] = r
        r:SetPoint("TOPLEFT", 2, -2 - (i - 1) * ROW)
        r:SetPoint("TOPRIGHT", -2, -2 - (i - 1) * ROW)
        local line = lines[i + state.buildScroll]
        r.line = line
        r:SetShown(line ~= nil)
        r.stripe:SetShown(i % 2 == 0)
        r.sel:SetShown(line and line.build and line.build == state.selected or false)
        if line and line.header ~= nil then
            r.left:SetText(line.header and ("|cff8c8c8c%s|r"):format(line.header) or "|cff8c8c8cNo group|r")
            r.right:SetText("")
        elseif line and line.newGroup then
            r.left:SetText("|cff8c8c8c+ New group (drop a build here)|r")
            r.right:SetText("")
        elseif line then
            r.left:SetText("   " .. line.build.name)
            r.right:SetText(badges(list, line.build))
        end
    end
    for i = n + 1, #buildRows do buildRows[i]:Hide() end
    if #lines == 2 and state.search == "" then frame.empty:Show() else frame.empty:Hide() end
end

local function drawActions()
    local b = state.selected
    local onSpec = state.spec == B.specID()
    for _, bt in ipairs(frame.actions) do bt:SetEnabled(b ~= nil) end
    frame.apply:SetEnabled(b ~= nil and onSpec)
    frame.delete:SetText(state.armed and state.armed == b and "|cffff8888Sure?|r" or "Delete")
    if state.compareFrom then
        frame.status:SetText(("Pick a build to compare with |cffffffff%s|r"):format(state.compareFrom.name))
    elseif b then
        frame.status:SetText("Selected: |cffffffff" .. b.name .. "|r")
    else
        frame.status:SetText("|cff8c8c8cClick a build to select it; drag it onto a group to move it.|r")
    end
end

function M.refresh()
    if not frame or not frame:IsShown() then return end
    if state.selected and not tContains(B.list(state.spec), state.selected) then state.selected = nil end
    frame.title:SetText("TalentKeeper: " .. (state.spec and B.specName(state.spec) or "builds"))
    drawSpecs(); drawBuilds(); drawActions()
end
TK.onChange = M.refresh

-- Clicks, drag and drop, actions -------------------------------------------------------------
local function compare(a, b)
    local d = C.diff(a.text, b.text)
    local lines
    if not d then lines = { "Couldn't read one of these builds." }
    elseif #d == 0 then lines = { "Same talents." }
    else
        lines = { ("%d talent%s apart. From %s to %s:"):format(#d, #d == 1 and "" or "s", a.name, b.name), "" }
        for _, l in ipairs(C.describe(d)) do lines[#lines + 1] = l end
    end
    UI.textWindow({ title = ("Compare: %s / %s"):format(a.name, b.name), text = table.concat(lines, "\n"), readOnly = true })
end

function M.click(line)
    if not line then return end
    if line.newGroup then return end
    if line.build then
        if state.compareFrom and state.compareFrom ~= line.build then
            local a = state.compareFrom
            state.compareFrom = nil
            compare(a, line.build)
        else
            state.selected, state.compareFrom = line.build, nil
        end
        M.refresh()
    end
end

function M.drop()
    local b = M.dragging
    M.dragging = nil
    ResetCursor()
    if not b then return end
    for _, r in ipairs(buildRows) do
        if r:IsShown() and r:IsMouseOver() and r.line then
            local line = r.line
            local target
            if line.header ~= nil then target = line.header or false
            elseif line.build then target = line.build.group or false
            elseif line.newGroup then
                return UI.textWindow({ title = "New group", text = "", singleLine = true, okText = "Create",
                    onOK = function(name) if strtrim(name) ~= "" then B.setGroup(b, name) end end })
            end
            if target ~= nil and (target or nil) ~= b.group then B.setGroup(b, target or nil) end
            return
        end
    end
end

local function makeFrame()
    frame = CreateFrame("Frame", "TalentKeeperManager", UIParent)
    frame:SetSize(W, H)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    UI.fill(frame, "BACKGROUND", 0.031, 0.031, 0.031, 0.97)
    UI.ring(frame, 0)
    tinsert(UISpecialFrames, frame:GetName())

    local band = CreateFrame("Frame", nil, frame)
    band:SetPoint("TOPLEFT"); band:SetPoint("TOPRIGHT"); band:SetHeight(36)
    UI.fill(band, "BACKGROUND", 1, 1, 1, 0.035)
    frame.title = band:CreateFontString(nil, "OVERLAY", "TalentKeeperFontLarge")
    frame.title:SetPoint("LEFT", 12, 0)

    local close = UI.button(band, "x", 24, function() frame:Hide() end)
    close:SetPoint("RIGHT", -6, 0)

    local search = CreateFrame("EditBox", nil, band)
    search:SetSize(200, 24)
    search:SetPoint("RIGHT", close, "LEFT", -8, 0)
    search:SetFontObject(TalentKeeperFont)
    search:SetAutoFocus(false)
    search:SetTextInsets(6, 6, 0, 0)
    UI.fill(search, "BACKGROUND", 1, 1, 1, 0.08)
    local setRing = UI.ring(search, 0.4)
    local hint = search:CreateFontString(nil, "OVERLAY", "TalentKeeperFont")
    hint:SetPoint("LEFT", 6, 0)
    hint:SetText("|cff8c8c8cSearch builds or talents|r")
    search:SetScript("OnEditFocusGained", function() setRing(0.596) end)
    search:SetScript("OnEditFocusLost", function() setRing(0.4) end)
    search:SetScript("OnEscapePressed", search.ClearFocus)
    search:SetScript("OnTextChanged", TK.safe(function(self)
        state.search = self:GetText() or ""
        hint:SetShown(state.search == "")
        state.buildScroll = 0
        M.refresh()
    end))
    frame:SetScript("OnHide", function() search:ClearFocus() end)

    frame.specPane = CreateFrame("Frame", nil, frame)
    frame.specPane:SetPoint("TOPLEFT", 8, -44)
    frame.specPane:SetPoint("BOTTOMLEFT", 8, 70)
    frame.specPane:SetWidth(LEFT_W)
    UI.fill(frame.specPane, "BACKGROUND", 0.06, 0.06, 0.06, 0.98)

    frame.buildPane = CreateFrame("Frame", nil, frame)
    frame.buildPane:SetPoint("TOPLEFT", frame.specPane, "TOPRIGHT", 8, 0)
    frame.buildPane:SetPoint("BOTTOMRIGHT", -8, 70)
    UI.fill(frame.buildPane, "BACKGROUND", 0.06, 0.06, 0.06, 0.98)
    frame.empty = frame.buildPane:CreateFontString(nil, "OVERLAY", "TalentKeeperFont")
    frame.empty:SetPoint("CENTER")
    frame.empty:SetText("|cff8c8c8cNo builds for this spec yet.|r")

    for _, pane in ipairs({ frame.specPane, frame.buildPane }) do
        pane:EnableMouseWheel(true)
        pane:SetScript("OnMouseWheel", function(self, delta)
            if self == frame.specPane then state.specScroll = state.specScroll - delta * 3
            else state.buildScroll = state.buildScroll - delta * 3 end
            M.refresh()
        end)
    end

    frame.status = frame:CreateFontString(nil, "OVERLAY", "TalentKeeperFont")
    frame.status:SetPoint("BOTTOMLEFT", 12, 46)

    local function sel() return state.selected end
    frame.apply = UI.button(frame, "Apply", 80, function() local b = sel() if b then B.apply(b) end end)
    local rename = UI.button(frame, "Rename", 80, function()
        local b = sel()
        if b then UI.textWindow({ title = "Rename build", text = b.name, singleLine = true, okText = "Rename",
            onOK = function(name) B.rename(state.spec, b, name) end }) end
    end)
    local copy = UI.button(frame, "Copy", 80, function()
        local b = sel()
        if b then UI.textWindow({ title = "Talent string: " .. b.name, text = b.text, readOnly = true }) end
    end)
    local cmp = UI.button(frame, "Compare with…", 120, function()
        state.compareFrom = sel()
        M.refresh()
    end)
    frame.delete = UI.button(frame, "Delete", 80, function()
        local b = sel()
        if not b then return end
        if state.armed == b then
            state.armed, state.selected = nil, nil
            B.delete(state.spec, b)
        else
            state.armed = b
            C_Timer.After(3, function() if state.armed == b then state.armed = nil; M.refresh() end end)
            M.refresh()
        end
    end)
    frame.actions = { frame.apply, rename, copy, cmp, frame.delete }
    frame.apply:SetPoint("BOTTOMLEFT", 12, 12)
    rename:SetPoint("LEFT", frame.apply, "RIGHT", 8, 0)
    copy:SetPoint("LEFT", rename, "RIGHT", 8, 0)
    cmp:SetPoint("LEFT", copy, "RIGHT", 8, 0)
    frame.delete:SetPoint("BOTTOMRIGHT", -12, 12)
    frame.apply:HookScript("OnEnter", function(self)
        if state.selected and state.spec ~= B.specID() then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Apply")
            GameTooltip:AddLine(("Switch to %s to apply this build."):format(B.specName(state.spec)), 0.74, 0.74, 0.74, true)
            GameTooltip:Show()
        end
    end)
    frame.apply:HookScript("OnLeave", GameTooltip_Hide)
end

function M.open()
    if not frame then makeFrame() end
    state.spec = state.spec or B.specID()
    frame:Show()
    M.refresh()
end

TK.commands.manage = function() if frame and frame:IsShown() then frame:Hide() else M.open() end end
