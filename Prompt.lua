-- TalentKeeper prompt: on arriving in a dungeon, a delve or the open world, offer the build
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
    if InCombatLockdown() then return TK.chat("|cffff8888Can't change talents in combat.|r") end
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

TK.on("ACTIVE_PLAYER_SPECIALIZATION_CHANGED", function()
    local p = pendingSwitch
    if not p or B.specID() ~= p.specID then return end
    pendingSwitch = nil
    C_Timer.After(1, TK.safe(function() B.apply(p.b) end)) -- let the new spec's tree settle
end)

local function chooseFor(here, owner)
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
                end }
            end
        end
        if #items == 0 then items[1] = { label = "No builds saved for this spec yet.", disabled = true } end
        return items
    end)
end

function P.check()
    local here = B.here()
    local kind = select(2, GetInstanceInfo())
    if not here or kind == "raid" or kind == "pvp" or kind == "arena" then return P.hide() end
    if here.key == shownFor then return end -- same place: don't ask again
    shownFor = here.key
    local hits = B.forHere(here)
    local hit = hits[1]
    if hit then
        if onBuild(hit.b, hit.specID) then
            TK.log("prompt: %s, already on '%s'", here.name, hit.b.name)
            return P.hide()
        end
        local spec = hit.specID ~= B.specID() and (" (" .. B.specName(hit.specID) .. ")") or ""
        TK.log("prompt: %s, offering '%s'%s", here.name, hit.b.name, spec)
        return show(("%s: |cff98ff98%s|r%s"):format(here.name, hit.b.name, spec),
            { "Switch", function() switch(hit.b, hit.specID) end })
    end
    -- an untagged delve takes the shared Delves / open world tag
    if here.content == "delve" then here = { key = "delve", name = "Delves / open world" } end
    local specID = B.specID()
    local active = specID and TK.db.active[specID]
    local cur
    for _, b in ipairs(specID and B.list(specID) or {}) do if b.name == active and onBuild(b, specID) then cur = b end end
    TK.log("prompt: %s, nothing set (current: %s)", here.name, cur and cur.name or "unsaved")
    show(("Nothing set for %s."):format(here.name),
        cur and { "Use " .. cur.name, function()
            B.toggleTag(cur, here.key, here.name)
            TK.log("prompt: used '%s' for %s", cur.name, here.name)
            P.hide()
        end } or nil,
        { "Choose...", function(bt) chooseFor(here, bt) end })
end

local function soon() C_Timer.After(2, TK.safe(P.check)) end -- instance info settles after loading
TK.on("PLAYER_ENTERING_WORLD", soon)
TK.on("ZONE_CHANGED_NEW_AREA", soon)
TK.on("CHALLENGE_MODE_START", function() P.hide() end) -- the key started: talents are locked
