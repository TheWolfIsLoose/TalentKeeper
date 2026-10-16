--[[
    TalentKeeper - Dev/Spike.lua   [DEV ONLY, never ships: #@debug@ in TOC]

    Phase 0 spikes S2-S4 (S1 ran offline: Dev/spikes/s1_compare.py).
        /tk spike              the test list
        /tk spike builds       TLE builds for this spec, numbered
        /tk spike apply <n>    S2: apply TLE build n into the "TalentKeeper" loadout
        /tk spike button       S3a: our own button by the loadout dropdown (no hook)
        /tk spike hook         S3b: add our builds to Blizzard's loadout dropdown
    S4 (zone / encounter / boss sighting) logs on its own.

    Every line goes to chat and TalentKeeperDB.spike (read from
    WTF\...\SavedVariables\TalentKeeper.lua after a /reload).
--]]

local addonName = ...
local TK = _G[addonName]
local SLOT = "TalentKeeper"

local log = {}
local function P(fmt, ...)
    local line = date("[%H:%M:%S] ") .. (select("#", ...) > 0 and fmt:format(...) or fmt)
    log[#log + 1] = line
    if #log > 600 then table.remove(log, 1) end
    print("|cffff9933[spike]|r " .. line)
end

local function sec(v) return issecretvalue and issecretvalue(v) end
local function show(v) if sec(v) then return "<secret>" end return tostring(v) end

-- Builds and decoding ---------------------------------------------------------
local function tleBuilds()
    local _, class = UnitClass("player")
    local list = TalentLoadoutEx and TalentLoadoutEx[class] and TalentLoadoutEx[class][GetSpecialization()]
    local r = {}
    for _, b in ipairs(list or {}) do if b.text then r[#r + 1] = b end end
    return r
end

-- Blizzard's own reader (ClassTalentImportExportMixin), called on the mixin itself.
local function entries(text)
    C_AddOns.LoadAddOn("Blizzard_PlayerSpells")
    local M = ClassTalentImportExportMixin
    local specID = PlayerUtil.GetCurrentSpecID()
    local treeID = C_ClassTalents.GetTraitTreeForSpec(specID)
    local stream = ExportUtil.MakeImportDataStream(text)
    local ok, ver, spec = M:ReadLoadoutHeader(stream)
    if not ok then return nil, "not a talent string" end
    if ver ~= C_Traits.GetLoadoutSerializationVersion() then return nil, "string version " .. ver end
    if spec ~= specID then return nil, "string is for spec " .. spec end
    return M:ConvertToImportLoadoutEntryInfo(C_ClassTalents.GetActiveConfigID(), treeID, M:ReadLoadoutContent(stream, treeID))
end

local function currentString()
    local M = ClassTalentImportExportMixin
    local specID = PlayerUtil.GetCurrentSpecID()
    local treeID = C_ClassTalents.GetTraitTreeForSpec(specID)
    local s = ExportUtil.MakeExportDataStream()
    M:WriteLoadoutHeader(s, C_Traits.GetLoadoutSerializationVersion(), specID, C_Traits.GetTreeHash(treeID))
    M:WriteLoadoutContent(s, C_ClassTalents.GetActiveConfigID(), treeID)
    return s:GetExportString()
end

local function keys(list)
    local k = {}
    for _, e in ipairs(list) do k[e.nodeID .. ":" .. e.ranksPurchased .. ":" .. tostring(e.selectionEntryID)] = true end
    return k
end

local function differences(a, b)
    local ka, kb, n = keys(a), keys(b), 0
    for k in pairs(ka) do if not kb[k] then n = n + 1 end end
    for k in pairs(kb) do if not ka[k] then n = n + 1 end end
    return n
end

-- S2 apply --------------------------------------------------------------------
local pending, waitID
local resultName = tInvert(Enum.LoadConfigResult)

local function findSlot(specID)
    for _, id in ipairs(C_ClassTalents.GetConfigIDsBySpecID(specID) or {}) do
        local info = C_Traits.GetConfigInfo(id)
        if info and info.name == SLOT then return id end
    end
end

local function pvp(b)
    for i = 1, 3 do
        local want, s = b["pvp" .. i], C_SpecializationInfo.GetPvpTalentSlotInfo(i)
        if want and s and s.enabled and s.selectedTalentID ~= want then
            local ok, err = pcall(LearnPvpTalent, want, i)
            P("PvP slot %d -> %d: %s", i, want, ok and "sent" or tostring(err))
        end
    end
    C_Timer.After(2, function()
        local got = {}
        for i = 1, 3 do local s = C_SpecializationInfo.GetPvpTalentSlotInfo(i); got[i] = s and tostring(s.selectedTalentID) or "-" end
        P("PvP now: %s (wanted %s, %s, %s)", table.concat(got, ", "), tostring(b.pvp1), tostring(b.pvp2), tostring(b.pvp3))
    end)
end

local function verify(b)
    local want = entries(b.text)
    local ok, have = pcall(entries, currentString())
    if not want or not ok or not have then return P("verify: could not read talents (%s)", tostring(have)) end
    local n = differences(want, have)
    if n == 0 then P("verify: talents match '%s'", b.name)
    else P("verify: |cffff8888%d differences|r from '%s'", n, b.name) end
end

local function load(id)
    local b = pending
    pending, waitID = nil, nil
    local specID = PlayerUtil.GetCurrentSpecID()
    local r, changeError = C_ClassTalents.LoadConfig(id, true)
    C_ClassTalents.UpdateLastSelectedSavedConfigID(specID, id)
    P("LoadConfig(%d): %s %s | talent window %s", id, resultName[r] or tostring(r), changeError or "",
        PlayerSpellsFrame and PlayerSpellsFrame:IsShown() and "open" or "closed")
    pvp(b)
    C_Timer.After(5, function() verify(b) end)
end

local function apply(b)
    if InCombatLockdown() then return P("in combat: not applying") end
    local e, err = entries(b.text)
    if not e then return P("'%s': %s", b.name, err) end
    local specID = PlayerUtil.GetCurrentSpecID()
    local inst, itype = GetInstanceInfo()
    P("apply '%s' (%d entries) in %s (%s), rested %s, key %s", b.name, #e, inst, itype, tostring(IsResting()),
        tostring(C_ChallengeMode.GetActiveChallengeMapID()))
    local old = findSlot(specID)
    if old then P("delete old slot %d: %s", old, tostring(C_ClassTalents.DeleteConfig(old))) end
    pending = b
    local ok, importErr = C_ClassTalents.ImportLoadout(C_ClassTalents.GetActiveConfigID(), e, SLOT, b.text)
    P("ImportLoadout: %s %s", tostring(ok), importErr or "")
    if not ok then pending = nil end
end

-- S3 hook vs own button ---------------------------------------------------------
local function buildMenu(root)
    root:CreateTitle("TalentKeeper (spike)")
    for _, b in ipairs(tleBuilds()) do root:CreateButton(b.name, function() apply(b) end) end
end

local function talentsFrame()
    C_AddOns.LoadAddOn("Blizzard_PlayerSpells")
    return PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
end

local button, hooked
local function addButton()
    if button then return P("button already there") end
    local tf = talentsFrame()
    button = CreateFrame("Button", nil, tf)
    button:SetSize(24, 24)
    button:SetPoint("RIGHT", tf.LoadSystem, "LEFT", -4, 0)
    local bg = button:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(1, 1, 1, 0.07)
    button:SetNormalFontObject(GameFontNormalSmall)
    button:SetText("TK")
    button:SetScript("OnClick", function(self) MenuUtil.CreateContextMenu(self, function(_, root) buildMenu(root) end) end)
    P("own button added (no hooks)")
end

local function addHook()
    if hooked then return P("hook already on") end
    hooked = true
    Menu.ModifyMenu("MENU_CLASS_TALENT_PROFILE", function(_, root) root:CreateDivider(); buildMenu(root) end)
    P("hooked Blizzard's loadout dropdown (MENU_CLASS_TALENT_PROFILE)")
end

-- S4 signals ------------------------------------------------------------------
local seen, inInstance = {}, false

local function bossList()
    local mapID = C_Map.GetBestMapForUnit("player")
    local jID = mapID and EJ_GetInstanceForMap(mapID)
    if not jID or jID == 0 then return P("journal: no instance for map %s", tostring(mapID)) end
    EJ_SelectInstance(jID)
    local names = {}
    for i = 1, 30 do
        local name, _, _, _, _, _, encID = EJ_GetEncounterInfoByIndex(i, jID)
        if not name then break end
        names[#names + 1] = ("%s (%s)"):format(name, tostring(encID))
    end
    P("journal %d bosses: %s", jID, table.concat(names, ", "))
end

local function zone()
    local name, itype, diffID, diffName, _, _, _, instID = GetInstanceInfo()
    inInstance = itype ~= "none"
    if not inInstance or seen["zone" .. instID .. diffID] then return end
    seen["zone" .. instID .. diffID] = true
    P("zone: %s | %s | instanceID %d | %s (%d) | key map %s", name, itype, instID, diffName, diffID,
        tostring(C_ChallengeMode.GetActiveChallengeMapID()))
    bossList()
end

local function probe(unit, how)
    if not inInstance or InCombatLockdown() then return end
    local ok, err = pcall(function()
        local guid, name, cls, lvl = UnitGUID(unit), UnitName(unit), UnitClassification(unit), UnitLevel(unit)
        if not sec(guid) and not guid then return end
        local anySecret = sec(guid) or sec(name) or sec(cls) or sec(lvl)
        if not anySecret and lvl ~= -1 and cls ~= "worldboss" then return end
        local npc = not sec(guid) and select(6, strsplit("-", guid)) or "<secret>"
        local key = how .. ":" .. (sec(name) and npc or name)
        if seen[key] then return end
        seen[key] = true
        P("seen via %s: %s | npc %s | %s | level %s", how, show(name), npc, show(cls), show(lvl))
    end)
    if not ok and not seen["err" .. how] then seen["err" .. how] = true; P("probe %s error: %s", how, tostring(err)) end
end

-- Events ------------------------------------------------------------------------
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "CHALLENGE_MODE_START", "ENCOUNTER_START",
    "ENCOUNTER_END", "BOSS_KILL", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED",
    "TRAIT_CONFIG_CREATED", "TRAIT_CONFIG_UPDATED", "CONFIG_COMMIT_FAILED", "ADDON_ACTION_BLOCKED",
    "ADDON_ACTION_FORBIDDEN", "PLAYER_LOGIN" }) do ev:RegisterEvent(e) end

ev:SetScript("OnEvent", function(_, e, a, b, c, d, f)
    if e == "PLAYER_LOGIN" then
        TK.db.spike = TK.db.spike or {}
        log = TK.db.spike
        P("---- session %s, %s", TK.build or "?", (select(2, UnitClass("player"))))
    elseif e == "PLAYER_ENTERING_WORLD" or e == "ZONE_CHANGED_NEW_AREA" then zone()
    elseif e == "CHALLENGE_MODE_START" then P("key started: map %s", tostring(a))
    elseif e == "ENCOUNTER_START" then P("encounter start: %s (%s), difficulty %s", tostring(b), tostring(a), tostring(c))
    elseif e == "ENCOUNTER_END" then P("encounter end: %s (%s), %s", tostring(b), tostring(a), f == 1 and "kill" or "wipe")
    elseif e == "BOSS_KILL" then P("boss kill: %s (%s)", tostring(b), tostring(a))
    elseif e == "PLAYER_TARGET_CHANGED" then probe("target", "target")
    elseif e == "UPDATE_MOUSEOVER_UNIT" then probe("mouseover", "mouseover")
    elseif e == "NAME_PLATE_UNIT_ADDED" then probe(a, "nameplate")
    elseif e == "TRAIT_CONFIG_CREATED" then
        if pending and a.name == SLOT then
            local populated = C_ClassTalents.IsConfigPopulated(a.ID)
            P("created slot %d, populated %s", a.ID, tostring(populated))
            if populated then load(a.ID) else waitID = a.ID end
        end
    elseif e == "TRAIT_CONFIG_UPDATED" then
        if waitID and a == waitID then load(a) end
    elseif e == "CONFIG_COMMIT_FAILED" then P("|cffff8888commit failed|r: config %s", tostring(a))
    elseif a == addonName then P("|cffff8888%s|r: %s", e, tostring(b))
    end
end)

-- Slash -------------------------------------------------------------------------
local TESTS = {
    "|cffffffffApply (S2)|r",
    "  /tk spike builds, then /tk spike apply <n>. Check: one TalentKeeper loadout in the dropdown, selected, talents and PvP right.",
    "  Apply a second build: still one TalentKeeper loadout, your others untouched.",
    "  Again with the talent window open.",
    "  Outdoors (not rested), at a dungeon entrance, and inside a started key (expect a refusal).",
    "|cffffffffTaint (S3)|r: /console taintLog 1 first",
    "  /tk spike button: apply from the TK button, then change a talent and Apply in Blizzard's window, then switch loadouts.",
    "  After a /reload, /tk spike hook: same steps from the dropdown entries.",
    "  Any red error or 'blocked' message: screenshot.",
    "|cffffffffSignals (S4)|r",
    "  Zone into a dungeon and a raid. Target and mouse over a boss before the pull. Kill a boss. Start a key.",
    "When done: /reload, then tell me.",
}

TK.commands.spike = function(msg)
    local sub, arg = msg:match("^(%S*)%s*(.-)$")
    if sub == "builds" then
        local list = tleBuilds()
        if #list == 0 then return P("no TLE builds for this spec") end
        for i, bd in ipairs(list) do print(("  %d. %s"):format(i, bd.name)) end
    elseif sub == "apply" then
        local bd = tleBuilds()[tonumber(arg) or 0]
        if bd then apply(bd) else P("no build %s; see /tk spike builds", arg) end
    elseif sub == "button" then addButton()
    elseif sub == "hook" then addHook()
    else for _, line in ipairs(TESTS) do print(line) end
    end
end
