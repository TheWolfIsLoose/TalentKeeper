-- TalentKeeper prompt: on arriving in a delve, offer the build tagged for delves (changing spec
-- first if it's another spec's build). Nothing set: offer to use your current build there, or
-- choose one. Dungeons and raids are covered by the ready check card (ReadyCheck.lua): every key
-- has a ready check before it starts.
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
    bar = UI.card("TalentKeeperPrompt", function()
        TK.log("prompt: dismissed (%s)", shownFor or "?")
        bar:Hide()
    end)
    bar:SetPoint("TOP", 0, -120)
    bar:SetFrameStrata("HIGH")
end

-- show(card): the build card at the top of the screen; its main button pulses as it appears
local function show(card)
    if not bar then makeBar() end
    bar:Set(card)
    if card.one then bar.btn1.pulse() end
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
    local delve = here.content == "delve"
    if not delve then shownFor = nil return P.hide() end -- dungeons: the ready check card
    if here.key == shownFor then return end -- same place: don't ask again
    shownFor = here.key
    if TK.db.noDelvePrompt then return P.hide() end
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
        return show({ specID = B.specID(), text = mine.text, title = mine.name, sub = name .. " · |cffffd84anot on it|r",
            one = { "Switch", function() switch(mine, B.specID()) end } })
    end
    if P.asked(here) then return TK.log("prompt: %s, already asked this session", name) end
    P.markAsked(here)
    TK.log("prompt: %s, nothing for this spec (current: %s%s)", name, cur and cur.name or "unsaved",
        other and (", " .. B.specName(other.specID) .. " has '" .. other.b.name .. "'") or "")
    local one, two = P.tagButtons(here, cur, other, P.hide)
    local shown = other and other.b or cur
    show({ specID = other and other.specID or B.specID(), text = shown and shown.text or B.currentString(),
        title = other and ("%s: %s"):format(B.specName(other.specID), other.b.name) or (cur and ("Use %s here?"):format(cur.name) or "Nothing tagged"),
        sub = name .. " · nothing for " .. B.specName(B.specID()), one = one, two = two })
end

local function check() -- after login, wait for the builds to be read (see Compare.lua)
    if TK.compare.warming then return C_Timer.After(0.5, TK.safe(check)) end
    P.check()
end
local function soon() C_Timer.After(2, TK.safe(check)) end -- instance info settles after loading
TK.on("PLAYER_ENTERING_WORLD", soon)
TK.on("ZONE_CHANGED_NEW_AREA", soon)
TK.on("CHALLENGE_MODE_START", function() P.hide() end) -- the key started: talents are locked
