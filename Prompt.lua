-- TalentKeeper prompt: on arriving in a dungeon or a delve, offer the build
-- tagged for it (changing spec first if it's another spec's build). Nothing set: offer to use
-- your current build there, or choose one. Raids wait for boss awareness.
local _, TK = ...
local B, C, UI = TK.builds, TK.compare, TK.ui
local P = {}
TK.prompt = P

local bar, shownFor, pendingSwitch

local function specIndex(specID)
    for i = 1, GetNumSpecializations() or 0 do
        if GetSpecializationInfo(i) == specID then return i end
    end
end

-- True when b's talents are the ones you have now.
local function onBuild(b, specID)
    if specID ~= B.specID() then return false end
    local d = C.diff(B.currentString(), b.text)
    return d ~= nil and #d == 0
end

local function makeBar()
    bar = CreateFrame("Frame", "TalentKeeperPrompt", UIParent)
    bar:SetHeight(32)
    bar:SetPoint("TOP", 0, -120)
    bar:SetFrameStrata("HIGH")
    bar:EnableMouse(true)
    UI.fill(bar, "BACKGROUND", 0.06, 0.06, 0.06, 0.98)
    UI.ring(bar, 0)
    local mark = bar:CreateTexture(nil, "ARTWORK")
    mark:SetSize(16, 16)
    mark:SetPoint("LEFT", 8, 0)
    mark:SetTexture("Interface\\AddOns\\TalentKeeper\\icon.png")
    bar.text = bar:CreateFontString(nil, "OVERLAY", "TalentKeeperFont")
    bar.text:SetPoint("LEFT", mark, "RIGHT", 6, 0)
    bar.close = UI.button(bar, "x", 24, function()
        TK.log("prompt: dismissed (%s)", shownFor or "?")
        bar:Hide()
    end)
    bar.close:SetPoint("RIGHT", -4, 0)
    bar.b2 = UI.button(bar, "", 70, function() end)
    bar.b2:SetPoint("RIGHT", bar.close, "LEFT", -4, 0)
    bar.b1 = UI.button(bar, "", 70, function() end)
    bar.b1:SetPoint("RIGHT", bar.b2, "LEFT", -4, 0)
end

-- show(text, { label, fn }, { label, fn }?)
local function show(text, one, two)
    if not one then one, two = two, nil end
    if not bar then makeBar() end
    bar.text:SetText(text)
    for _, pair in ipairs({ { bar.b1, one }, { bar.b2, two } }) do
        local bt, spec = pair[1], pair[2]
        bt:SetShown(spec ~= nil)
        if spec then
            bt:SetText(spec[1])
            bt:SetWidth(math.max(56, bt:GetTextWidth() + 20))
            bt:SetScript("OnClick", TK.safe(function() spec[2](bt) end))
        end
    end
    if not two then bar.b1:ClearAllPoints() bar.b1:SetPoint("RIGHT", bar.close, "LEFT", -4, 0)
    else bar.b1:ClearAllPoints() bar.b1:SetPoint("RIGHT", bar.b2, "LEFT", -4, 0) end
    local w = 8 + 16 + 6 + bar.text:GetStringWidth() + 12 + bar.b1:GetWidth() + (two and bar.b2:GetWidth() + 4 or 0) + 4 + 24 + 4
    bar:SetWidth(math.ceil(w))
    bar:Show()
end

function P.hide() if bar then bar:Hide() end end

-- Switch to b: change spec first if needed, then apply once the spec change lands.
local function switch(b, specID)
    if InCombatLockdown() then return TK.chat("|cffff6666Can't change talents in combat.|r") end
    P.hide()
    if specID == B.specID() then
        TK.log("prompt: switch to '%s'", b.name)
        return B.apply(b)
    end
    local i = specIndex(specID)
    if not i then return end
    TK.log("prompt: switch to %s, then '%s'", B.specName(specID), b.name)
    pendingSwitch = { b = b, specID = specID }
    C_SpecializationInfo.SetSpecialization(i)
end
P.switch, P.onBuild = switch, onBuild

TK.on("ACTIVE_PLAYER_SPECIALIZATION_CHANGED", function()
    local p = pendingSwitch
    if not p or B.specID() ~= p.specID then return end
    pendingSwitch = nil
    C_Timer.After(1, TK.safe(function() B.apply(p.b) end)) -- let the new spec's tree settle
end)

-- Pick one of this spec's builds for a situation: tags it there and switches to it.
local function chooseFor(here, owner, after)
    local specID = B.specID()
    UI.picker(owner, "Use for " .. here.name, function()
        local items = {}
        for _, line in ipairs(B.ordered(specID)) do
            if line.header then items[#items + 1] = { heading = line.header }
            elseif line.build then
                local b = line.build
                items[#items + 1] = { label = b.name, onClick = function()
                    B.toggleTag(b, here.key, here.name)
                    TK.log("prompt: chose '%s' for %s", b.name, here.name)
                    P.hide()
                    if not onBuild(b, specID) then switch(b, specID) end
                    if after then after() end
                end }
            end
        end
        if #items == 0 then items[1] = { label = "No builds saved for this spec yet.", disabled = true } end
        return items
    end)
end

-- Only places the tag list offers: delves and this season's dungeons (old and timewalking
-- dungeons, follower dungeons of past content and the like get nothing).
function P.taggable(here)
    if not here then return false end
    if here.content == "delve" or here.key == "delve" then return true end
    for _, d in ipairs(UI.seasonDungeons()) do if d.key == here.key then return true end end
    return false
end

-- What to offer for a place: mine (this spec's build tagged there), other ({ b, specID }: another
-- spec's), cur (a saved build of this spec your talents match now).
function P.plan(here)
    local spec = B.specID()
    local mine, other
    for _, h in ipairs(B.forHere(here)) do
        if h.specID == spec then mine = mine or h.b else other = other or h end
    end
    local cur
    for _, b in ipairs(spec and B.list(spec) or {}) do if onBuild(b, spec) then cur = b break end end
    return mine, other, cur
end

-- Asking to tag a place happens once per play session (see TalentKeeper.lua); being on the wrong
-- tagged build is said every time.
local function id(here) return (select(8, GetInstanceInfo()) or 0) .. ":" .. here.key end
function P.asked(here) return TK.db.asked[id(here)] ~= nil end
function P.markAsked(here) TK.db.asked[id(here)] = time() end

-- The two buttons when this spec has nothing tagged here: tag what you're on (or choose a build),
-- and the other spec's tagged build if there is one (else Choose... beside Use).
function P.tagButtons(here, cur, other, after)
    local tag = cur and { "Use " .. cur.name, function()
        B.setTag(cur, here.key, here.name, true)
        TK.log("tagged '%s' for %s", cur.name, here.name)
        if after then after() end
    end } or { "Choose...", function(bt) chooseFor(here, bt, after) end }
    if other then
        return tag, { B.specName(other.specID), function() switch(other.b, other.specID) if after then after() end end }
    end
    return tag, cur and { "Choose...", function(bt) chooseFor(here, bt, after) end } or nil
end

function P.check()
    local here = B.here()
    local kind = select(2, GetInstanceInfo())
    -- open world: no prompt (delves still offer the Delves build)
    if not here or kind == "none" or kind == nil or kind == "raid" or kind == "pvp" or kind == "arena" then
        shownFor = nil
        return P.hide()
    end
    if not P.taggable(here) then return P.hide() end
    if here.key == shownFor then return end -- same place: don't ask again
    shownFor = here.key
    local delve = here.content == "delve"
    if delve and TK.db.noDelvePrompt then return P.hide() end
    if delve then
        here = { key = "delve", name = "Delves", content = "delve" } -- delves share one tag
        -- the build you last applied counting as your Delves build is enough
        for _, b in ipairs(B.list(B.specID())) do
            if b.name == TK.db.active[B.specID()] and b.tags and b.tags.delve then
                TK.log("prompt: %s, on your Delves build '%s'", here.name, b.name)
                return P.hide()
            end
        end
    end
    local mine, other, cur = P.plan(here)
    local name = delve and select(1, GetInstanceInfo()) or here.name
    if mine then
        if onBuild(mine, B.specID()) then
            TK.log("prompt: %s, already on '%s'", name, mine.name)
            return P.hide()
        end
        TK.log("prompt: %s, offering '%s'", name, mine.name)
        return show(("%s: |cffffffff%s|r"):format(name, mine.name), { "Switch", function() switch(mine, B.specID()) end })
    end
    if P.asked(here) then return TK.log("prompt: %s, already asked this session", name) end
    P.markAsked(here)
    local text = other
        and ("Nothing for %s here. %s: |cffffffff%s|r"):format(B.specName(B.specID()), B.specName(other.specID), other.b.name)
        or ("Nothing set for %s."):format(here.name)
    TK.log("prompt: %s, nothing for this spec (current: %s%s)", name, cur and cur.name or "unsaved",
        other and (", " .. B.specName(other.specID) .. " has '" .. other.b.name .. "'") or "")
    show(text, P.tagButtons(here, cur, other, P.hide))
end

local function soon() C_Timer.After(2, TK.safe(P.check)) end -- instance info settles after loading
TK.on("PLAYER_ENTERING_WORLD", soon)
TK.on("ZONE_CHANGED_NEW_AREA", soon)
TK.on("CHALLENGE_MODE_START", function() P.hide() end) -- the key started: talents are locked
