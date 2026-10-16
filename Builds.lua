-- TalentKeeper builds: saved data, reading talent strings, save / apply / rename / delete,
-- and the one-time import of builds saved by another talent addon.
local _, TK = ...
local B = {}
TK.builds = B

local SLOT = "TalentKeeper"  -- the one Blizzard loadout per spec that TalentKeeper applies into

-- Saved data ----------------------------------------------------------------
function B.specID() return PlayerUtil.GetCurrentSpecID() end

function B.specName(specID)
    return select(2, GetSpecializationInfoByID(specID)) or ("spec " .. tostring(specID))
end

function B.list(specID)
    specID = specID or B.specID()
    TK.db.builds[specID] = TK.db.builds[specID] or {}
    return TK.db.builds[specID]
end

local function find(list, name)
    for i, b in ipairs(list) do if b.name == name then return b, i end end
end

-- Names are unique per spec: "Raid", "Raid (2)", ...
function B.uniqueName(list, name, except)
    name = strtrim(name or "")
    if name == "" then name = "Build" end
    local try, n = name, 1
    while true do
        local other = find(list, try)
        if not other or other == except then return try end
        n = n + 1
        try = ("%s (%d)"):format(name, n)
    end
end

-- Adds a build unless the same string is already saved for that spec.
-- Returns the build, or nil plus the existing build it matched.
function B.add(specID, b)
    b.text = strtrim(b.text)
    local list = B.list(specID)
    for _, other in ipairs(list) do
        if strtrim(other.text) == b.text then return nil, other end
    end
    local same = TK.compare.same(list, b.text)  -- same talents, different string
    if same then return nil, same end
    b.name = B.uniqueName(list, b.name)
    b.added = b.added or time()
    list[#list + 1] = b
    return b
end

-- Reading talent strings ---------------------------------------------------------
-- Blizzard's own reader (ClassTalentImportExportMixin), called on the mixin itself.
local function mixin()
    C_AddOns.LoadAddOn("Blizzard_PlayerSpells")
    return ClassTalentImportExportMixin
end
B.mixin = mixin

-- Which spec a string is for, without needing to be on that spec.
function B.stringSpec(text)
    text = strtrim(text or "")
    if text == "" then return nil, "That box is empty." end
    local ok, ver, spec = mixin():ReadLoadoutHeader(ExportUtil.MakeImportDataStream(text))
    if not ok or not spec or spec == 0 then return nil, "That isn't a talent string." end
    if ver ~= C_Traits.GetLoadoutSerializationVersion() then
        return nil, "That string was made for a different version of the game."
    end
    return spec
end

-- The string's picks, ready for ImportLoadout. Only for the current spec.
local function entries(text)
    local M = mixin()
    local specID = B.specID()
    local spec, err = B.stringSpec(text)
    if not spec then return nil, err end
    if spec ~= specID then return nil, ("That build is for %s."):format(B.specName(spec)) end
    local treeID = C_ClassTalents.GetTraitTreeForSpec(specID)
    local stream = ExportUtil.MakeImportDataStream(strtrim(text))
    M:ReadLoadoutHeader(stream)
    return M:ConvertToImportLoadoutEntryInfo(C_ClassTalents.GetActiveConfigID(), treeID, M:ReadLoadoutContent(stream, treeID))
end

local function currentString()
    return C_Traits.GenerateImportString(C_ClassTalents.GetActiveConfigID())
end
B.currentString = currentString

local function currentPvp()
    local ids = C_SpecializationInfo.GetAllSelectedPvpTalentIDs and C_SpecializationInfo.GetAllSelectedPvpTalentIDs()
    return ids and #ids > 0 and { ids[1], ids[2], ids[3] } or nil
end

-- Save, import, rename, delete ------------------------------------------------------
function B.saveCurrent(name)
    local specID = B.specID()
    local text = currentString()
    if not text or text == "" then return TK.chat("|cffff8888Couldn't read your talents.|r Open the talent window once and try again.") end
    local list = B.list(specID)
    local b, same = B.add(specID, {
        name = name ~= "" and name or ("%s %d"):format(B.specName(specID), #list + 1),
        text = text, pvp = currentPvp(),
    })
    if not b then return TK.chat(("Same talents as |cffffffff%s|r, so nothing new to save."):format(same.name)) end
    TK.db.active[specID] = b.name
    TK.log("saved '%s' (%s)", b.name, B.specName(specID))
    TK.chat(("Saved |cffffffff%s|r.%s"):format(b.name, TK.compare.nearNote(list, b)))
    TK.changed()
end

function B.importString(text, name)
    local spec, err = B.stringSpec(text)
    if not spec then return TK.chat("|cffff8888" .. err .. "|r") end
    local list = B.list(spec)
    local b, same = B.add(spec, {
        name = name and name ~= "" and name or ("Imported %d"):format(#list + 1),
        text = strtrim(text),
    })
    if not b then return TK.chat(("Same talents as |cffffffff%s|r (%s), so nothing new to save."):format(same.name, B.specName(spec))) end
    TK.log("imported '%s' (%s)", b.name, B.specName(spec))
    TK.chat(("Saved |cffffffff%s|r for %s.%s"):format(b.name, B.specName(spec), TK.compare.nearNote(list, b)))
    TK.changed()
end

function B.rename(specID, b, name)
    local old = b.name
    b.name = B.uniqueName(B.list(specID), name, b)
    if TK.db.active[specID] == old then TK.db.active[specID] = b.name end
    TK.log("renamed '%s' to '%s'", old, b.name)
    TK.changed()
end

-- Move a build into a group (nil = no group).
function B.setGroup(b, group)
    group = group and strtrim(group) or nil
    b.group = group ~= "" and group or nil
    TK.log("'%s' moved to %s", b.name, b.group or "no group")
    TK.changed()
end

function B.delete(specID, b)
    local list = B.list(specID)
    local _, i = find(list, b.name)
    if not i then return end
    table.remove(list, i)
    if TK.db.active[specID] == b.name then TK.db.active[specID] = nil end
    TK.log("deleted '%s' (%s)", b.name, B.specName(specID))
    TK.chat(("Deleted |cffffffff%s|r."):format(b.name))
    TK.changed()
end

-- Apply --------------------------------------------------------------------------
-- Import the build into TalentKeeper's own Blizzard loadout (replacing the last one),
-- load it, set PvP talents, then check the talents came out as saved.
local pending, waitID
local resultName = tInvert(Enum.LoadConfigResult)

local function findSlot(specID)
    for _, id in ipairs(C_ClassTalents.GetConfigIDsBySpecID(specID) or {}) do
        local info = C_Traits.GetConfigInfo(id)
        if info and info.name == SLOT then return id end
    end
end

local function setPvp(b)
    for i = 1, 3 do
        local want, slot = b.pvp and b.pvp[i], C_SpecializationInfo.GetPvpTalentSlotInfo(i)
        if want and slot and slot.enabled and slot.selectedTalentID ~= want then
            local ok, err = pcall(LearnPvpTalent, want, i)
            TK.debug("PvP slot %d -> %d: %s", i, want, ok and "sent" or tostring(err))
        end
    end
end

local lastApply -- { b, failed } for the build being applied, so a refused commit isn't reported as outdated

local function verify(b)
    if lastApply and lastApply.b == b and lastApply.failed then return end
    local d = TK.compare.diff(b.text, currentString())
    if not d then return TK.log("check '%s': couldn't read talents", b.name) end
    local names = TK.compare.describe(d)
    TK.log("check '%s': %d differences%s", b.name, #d, #d > 0 and (": " .. table.concat(names, ", ")) or "")
    b.outdated = #d > 0 and #d or nil
    TK.changed()
    if #d > 0 then
        TK.chat(("|cffffb84dApplied %s, but %d of its talents didn't come out as saved|r (%s). Re-save it once you've fixed them.")
            :format(b.name, #d, table.concat(TK.compare.describe(d, 3), ", ")))
    end
end

TK.on("CONFIG_COMMIT_FAILED", function(configID)
    if not lastApply or not B.muteUntil or GetTime() > B.muteUntil then return end
    lastApply.failed = true
    TK.log("apply '%s': the game refused the change (config %s)", lastApply.b.name, tostring(configID))
    TK.chat(("|cffff8888The game didn't accept %s.|r Your talents weren't changed; try again out of combat, or check the build in the talent window."):format(lastApply.b.name))
end)

-- Load the freshly imported loadout. A load error right after import is usually timing,
-- so the same loadout is loaded once more a second later before giving up.
local function load(id, p)
    local specID = B.specID()
    local r, changeError = C_ClassTalents.LoadConfig(id, true)
    TK.log("apply '%s': LoadConfig %s %s%s", p.b.name, resultName[r] or tostring(r), changeError or "", p.retried and " (retry)" or "")
    if r == Enum.LoadConfigResult.Error then
        if not p.retried then
            p.retried = true
            return C_Timer.After(1, TK.safe(function() load(id, p) end))
        end
        TK.db.active[specID] = p.prev
        return TK.chat(("|cffff8888Couldn't apply %s.|r %s"):format(p.b.name, changeError or "Try again in a moment."))
    end
    C_ClassTalents.UpdateLastSelectedSavedConfigID(specID, id)
    TK.changed()
    setPvp(p.b)
    C_Timer.After(5, TK.safe(function() verify(p.b) end))
end

function B.apply(b)
    if InCombatLockdown() then return TK.chat("|cffff8888Can't change talents in combat.|r") end
    local okCheck, canChange, _, changeError = pcall(C_ClassTalents.CanChangeTalents)
    if okCheck and canChange == false then
        TK.log("apply '%s': refused, can't change talents (%s)", b.name, tostring(changeError))
        return TK.chat("|cffff8888Can't change talents right now.|r " .. (changeError or ""))
    end
    local e, err = entries(b.text)
    if not e then return TK.chat("|cffff8888" .. err .. "|r") end
    local specID = B.specID()
    local old = findSlot(specID)
    if old then C_ClassTalents.DeleteConfig(old) end
    local prev = TK.db.active[specID]
    TK.db.active[specID] = b.name
    pending = { b = b, prev = prev }
    lastApply = { b = b }
    B.muteUntil = GetTime() + 10
    local ok, importErr = C_ClassTalents.ImportLoadout(C_ClassTalents.GetActiveConfigID(), e, SLOT, strtrim(b.text))
    TK.log("apply '%s' (%s): import %s %s", b.name, B.specName(specID), tostring(ok), importErr or "")
    if not ok then
        pending = nil
        TK.db.active[specID] = prev
        TK.chat(("|cffff8888Couldn't apply %s.|r %s"):format(b.name, importErr or ""))
    end
end

-- Loading in the same frame the loadout appears fails more often than not; wait a moment.
local function loadPending(id)
    local p = pending
    pending, waitID = nil, nil
    C_Timer.After(0.3, TK.safe(function() load(id, p) end))
end

TK.on("TRAIT_CONFIG_CREATED", function(info)
    if not pending or info.name ~= SLOT then return end
    local populated = C_ClassTalents.IsConfigPopulated(info.ID)
    TK.debug("created loadout %d, populated %s", info.ID, tostring(populated))
    if populated then loadPending(info.ID) else waitID = info.ID end
end)

TK.on("TRAIT_CONFIG_UPDATED", function(id)
    if waitID and id == waitID then loadPending(id) end
end)
-- While a build applies, hide the game's "You have learned / unlearned ..." lines.
local function pattern(fmt) return "^" .. fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", ".+") .. "$" end
local spam = {}
for _, key in ipairs({ "ERR_LEARN_SPELL_S", "ERR_LEARN_ABILITY_S", "ERR_LEARN_PASSIVE_S", "ERR_SPELL_UNLEARNED_S",
    "ERR_PET_LEARN_ABILITY_S", "ERR_PET_SPELL_UNLEARNED_S" }) do
    if type(_G[key]) == "string" then spam[#spam + 1] = pattern(_G[key]) end
end
local addFilter = ChatFrame_AddMessageEventFilter or (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter)
if addFilter then
    addFilter("CHAT_MSG_SYSTEM", function(_, _, msg)
        if not B.muteUntil or GetTime() > B.muteUntil or type(msg) ~= "string" then return false end
        if issecretvalue and issecretvalue(msg) then return false end
        for _, p in ipairs(spam) do if msg:find(p) then return true end end
        return false
    end)
end

-- One-time import from another talent addon's saved builds ------------------------------
-- Its saved data: [classFile][specIndex] = rows; a row with a string is a build, a row
-- without one is a group heading, and builds flagged isInGroup sit under the last heading.
function B.importOther()
    local src = _G.TalentLoadoutEx
    if type(src) ~= "table" then return 0 end
    local classIDs = {}
    for i = 1, GetNumClasses() do
        local _, file, id = GetClassInfo(i)
        if file then classIDs[file] = id end
    end
    local added = 0
    for classFile, specs in pairs(src) do
        local classID = classIDs[classFile]
        if classID and type(specs) == "table" then
            for specIndex, rows in pairs(specs) do
                local specID = type(specIndex) == "number" and GetSpecializationInfoForClassID(classID, specIndex)
                if specID and type(rows) == "table" then
                    local heading
                    for _, row in ipairs(rows) do
                        if type(row) == "table" and type(row.text) == "string" and row.text ~= "" then
                            local pvp = (row.pvp1 or row.pvp2 or row.pvp3) and { row.pvp1, row.pvp2, row.pvp3 } or nil
                            if B.add(specID, { name = row.name, text = row.text, pvp = pvp, group = row.isInGroup and heading or nil }) then
                                added = added + 1
                            end
                        elseif type(row) == "table" and row.name then
                            heading = row.name
                        end
                    end
                end
            end
        end
    end
    TK.log("imported %d builds from Talent Loadout Ex", added)
    return added
end

TK.on("PLAYER_LOGIN", function()
    if TK.db.imported.other or type(_G.TalentLoadoutEx) ~= "table" then return end
    TK.db.imported.other = true
    local n = B.importOther()
    if n > 0 then TK.chat(("Brought over %d builds from Talent Loadout Ex."):format(n)) end
end)

TK.commands.save = function(name) B.saveCurrent(name) end
TK.commands.import = function()
    TK.ui.textWindow({
        title = "Import a talent string", okText = "Save", text = "",
        onOK = function(text) B.importString(text) end,
    })
end
