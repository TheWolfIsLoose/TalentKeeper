-- TalentKeeper smoke test (dev only; Dev/ never ships).
-- Loads the addon in TOC order against stubbed WoW APIs and checks saved data, the
-- build list rules, the one-time import, the apply chain (with its one retry), slash
-- commands and the menu. Needs a Lua 5.1 interpreter, run from the addon folder:
--   lua5.1 Dev/smoke.lua
-- Prints a line per section; any failure raises with the reason.

local printed = {}
print_ = print
print = function(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end printed[#printed + 1] = table.concat(t, " ") end
local function said(pat) for _, l in ipairs(printed) do if l:find(pat) then return true end end end
local function ok(cond, msg) if not cond then error("FAIL: " .. msg, 2) end end
local function section(name) print_("ok  " .. name) end

-- Stubs ------------------------------------------------------------------------
local Stub
Stub = setmetatable({}, { __index = function() return Stub end, __call = function() return Stub end })
local frames, timers = {}, {}
local function Frame()
    local f = { scripts = {}, events = {} }
    return setmetatable(f, { __index = function(t, k)
        if k == "SetScript" then return function(self, n, fn) self.scripts[n] = fn end end
        if k == "RegisterEvent" then return function(self, e) self.events[e] = true end end
        if k == "GetHeight" then return function() return 400 end end
        if k == "GetFrameLevel" or k == "GetWidth" or k == "GetEffectiveScale" or k == "GetStringWidth" or k == "GetTextWidth" then return function() return 10 end end
        if k == "IsShown" or k == "IsVisible" then return function() return true end end
        if k:match("^Create") then return function() return Frame() end end
        return function() return Stub end
    end })
end
setmetatable(_G, { __index = function(_, k)
    if k:match("^TalentKeeper") or k == "TalentLoadoutEx" then return nil end
    if k:match("^[A-Z]") or k:match("^C_") then return Stub end
end })
CreateFrame = function() local f = Frame(); frames[#frames + 1] = f; return f end
UIParent = Frame()
GetCursorPosition = function() return 100, 100 end
CreateFont = function() return Frame() end
date, time = os.date, os.time
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
tinsert = table.insert
tContains = function(t, v) for _, x in pairs(t) do if x == v then return true end end return false end
tInvert = function(t) local r = {} for k, v in pairs(t) do r[v] = k end return r end
debugstack = function() return "stack" end
geterrorhandler = function() return function(e) error(e, 0) end end
GetTime = function() return 100 end
ERR_LEARN_SPELL_S, ERR_SPELL_UNLEARNED_S = "You have learned a new spell: %s.", "You have unlearned %s."
local chatFilter
ChatFrame_AddMessageEventFilter = function(_, fn) chatFilter = fn end
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function runTimers() local t = timers; timers = {}; for _, fn in ipairs(t) do fn() end end
C_AddOns = { GetAddOnMetadata = function() return "@project-version@" end, LoadAddOn = function() end }
UISpecialFrames = {}
SlashCmdList = {}
local onSpells = {}
EventUtil = { ContinueOnAddOnLoaded = function(_, fn) onSpells[#onSpells + 1] = fn end }
InCombatLockdown = function() return false end
GetNumClasses = function() return 1 end
GetClassInfo = function() return "Warlock", "WARLOCK", 9 end
local SPECS = { [265] = "Affliction", [266] = "Demonology", [267] = "Destruction" }
GetSpecializationInfoForClassID = function(_, i) return ({ 265, 266, 267 })[i] end
GetSpecializationInfoByID = function(id) return id, SPECS[id] end
local currentSpec = 267
PlayerUtil = { GetCurrentSpecID = function() return currentSpec end }
Enum = { LoadConfigResult = { Error = 0, NoChangesNecessary = 1, LoadInProgress = 2, Ready = 3 },
         TraitNodeType = { Single = 0, Tiered = 1, Selection = 2, SubTreeSelection = 3 } }
debugprofilestop = function() return 0 end
local lastSelected, commits = nil, 0
MenuResponse = { Close = 3, CloseAll = 4, Refresh = 2 }

-- Strings in tests look like "SPEC:<id>:<anything>"; the reader returns that spec.
ClassTalentImportExportMixin = {
    bitWidthHeaderVersion = 8, bitWidthSpecID = 16, bitWidthRanksPurchased = 6,
    ReadLoadoutHeader = function(_, stream) local spec = stream.text:match("^SPEC:(%d+):") return spec ~= nil, 2, tonumber(spec) end,
    -- payload digit per node: 0 none, 1 taken, 2 choice 2, 3 granted (free)
    ReadLoadoutContent = function(_, stream)
        local payload, r = stream.text:match("^SPEC:%d+:(.*)$") or "", {}
        for i = 1, 4 do
            local ch = payload:sub(i, i)
            r[i] = { isNodeSelected = ch ~= "0" and ch ~= "", isNodeGranted = ch == "3", isPartiallyRanked = false,
                     isChoiceNode = ch == "2", choiceNodeSelection = ch == "2" and 2 or 1 }
        end
        return r
    end,
    ConvertToImportLoadoutEntryInfo = function() return { { nodeID = 1, ranksPurchased = 1 } } end,
}
-- Export stream: rebuilds the test digit format from the bits the writer adds.
local function exportStream()
    local vals = {}
    return {
        AddValue = function(_, _, v) vals[#vals + 1] = v end,
        GetExportString = function()
            local spec, i, out = vals[2], 19, {}
            while i <= #vals do
                local sel = vals[i]; i = i + 1
                if sel == 0 then out[#out + 1] = "0" else
                    i = i + 1 -- purchased
                    local partial = vals[i]; i = i + 1
                    if partial == 1 then i = i + 1 end
                    local choice = vals[i]; i = i + 1
                    local c = 0
                    if choice == 1 then c = vals[i] + 1; i = i + 1 end
                    out[#out + 1] = c == 2 and "2" or "1"
                end
            end
            return "SPEC:" .. spec .. ":" .. table.concat(out)
        end,
    }
end
ExportUtil = { MakeImportDataStream = function(text) return { text = text } end, MakeExportDataStream = exportStream }
local configs, loads, imports = {}, {}, 0
C_Traits = {
    GetLoadoutSerializationVersion = function() return 2 end,
    GenerateImportString = function() return "SPEC:" .. currentSpec .. ":1000" end,
    GetTreeNodes = function() return { 101, 102, 103, 104 } end,
    GetTreeHash = function() local h = {} for i = 1, 16 do h[i] = 0 end return h end,
    GetNodeInfo = function(_, node) return { entryIDs = { node * 10 + 1, node * 10 + 2 } } end,
    GetEntryInfo = function(_, e) return { definitionID = e } end,
    GetDefinitionInfo = function(d) return { spellID = d } end,
    GetTreeCurrencyInfo = function() return { { traitCurrencyID = 1 }, { traitCurrencyID = 2 } } end,
    ResetTree = function() end, ConfigHasStagedChanges = function() return staged end, ResetTreeByCurrency = function() end, RollbackConfig = function() rolledBack = true; staged = false end,
    PurchaseRank = function() return true end, SetSelection = function() return true end,
    GetConfigInfo = function(id) return configs[id] end,
}
C_ClassTalents = {
    GetTraitTreeForSpec = function() return 1 end,
    GetActiveConfigID = function() return 1 end,
    GetConfigIDsBySpecID = function() local r = {} for id in pairs(configs) do r[#r + 1] = id end return r end,
    DeleteConfig = function(id) configs[id] = nil return true end,
    ImportLoadout = function() imports = imports + 1 return true end,
    IsConfigPopulated = function() return true end,
    LoadConfig = function(id) loads[#loads + 1] = id return #loads == 1 and Enum.LoadConfigResult.Error or Enum.LoadConfigResult.LoadInProgress end,
    UpdateLastSelectedSavedConfigID = function() end,
    CanChangeTalents = function() return true, true, nil end,
    GetLastSelectedSavedConfigID = function() return lastSelected end,
    CommitConfig = function() commits = commits + 1 return true end,
}
C_Spell = { GetSpellName = function(id) return "T" .. id end }
C_SpecializationInfo = { GetAllSelectedPvpTalentIDs = function() return { 15, 18 } end, GetPvpTalentSlotInfo = function() return nil end }
-- Talent tree library: node 104 is a class node, 103 a hero node; nothing is free.
local libNodes = { [101] = {}, [102] = {}, [103] = { subTreeID = 7 }, [104] = { isClassNode = true } }
local lib = {
    GetLibNodeInfo = function(_, node) return libNodes[node] end,
    IsNodeGrantedForSpec = function() return false end,
    GetClassTreeID = function() return 1 end,
    GetEntryInfo = function() return nil end,
}
LibStub = function(name) if name == "LibTalentTree-1.0" then return lib end end
local menuGen
-- this season: one dungeon (instance 501, where you are), one raid with one boss
GetInstanceInfo = function() return "Dungeon A", "party", 8, nil, nil, nil, nil, 501 end
C_ChallengeMode = { GetMapTable = function() return { 1 } end, GetMapUIInfo = function() return "Dungeon A", 1, 0, 0, 0, 501 end }
EJ_GetNumTiers, EJ_GetCurrentTier, EJ_SelectTier, EJ_SelectInstance = function() return 2 end, function() return 1 end, function() end, function() end
EJ_GetInstanceByIndex = function(i) if i == 1 then return 10, "Raid A" elseif i == 2 then return 11, "World" end end
EJ_GetInstanceInfo = function(id) if id == 11 then return "World", nil, nil, nil, nil, nil, nil, nil, false, 2200 end return "Raid A", nil, nil, nil, nil, nil, nil, nil, true, 2700 end
EJ_GetEncounterInfoByIndex = function(j) if j == 1 then return "Boss A", nil, nil, nil, nil, nil, 3001 end end
MenuUtil = { CreateContextMenu = function(_, gen) menuGen = gen end }

-- Load in TOC order ---------------------------------------------------------------
local ns = {}
for line in io.lines("TalentKeeper.toc") do
    if line:match("%.lua$") and not line:match("^#") and not line:match("^Dev") and not line:match("^libs") then
        local chunk = assert(loadfile(line))
        chunk("TalentKeeper", ns)
    end
end
local TK, B = ns, ns.builds
local events = frames[1].scripts.OnEvent
local function fire(e, ...) events(nil, e, ...) end
section("loads in TOC order")

TalentLoadoutEx = { WARLOCK = { [3] = {
    { name = "Raid", isExpanded = true },
    { name = "HC Cleave", text = "SPEC:267:1100", isInGroup = true, pvp1 = 157 },
    { name = "HC ST", text = "SPEC:267:1010", isInGroup = true },
    { name = "Solo", text = "SPEC:267:0111" },
    { name = "Copy", text = "SPEC:267:0111" },
}, [1] = { { name = "Aff", text = "SPEC:265:1" } } } }
fire("ADDON_LOADED", "TalentKeeper")
ok(TalentKeeperDB and TK.db == TalentKeeperDB, "saved data set up")
ok(said("TalentKeeper|r: dev loaded"), "load line")
section("saved data and load line")

fire("PLAYER_LOGIN")
local destro = B.list(267)
ok(#destro == 3, "3 Destruction builds imported (copy skipped), got " .. #destro)
ok(destro[1].group == "Raid" and destro[2].group == "Raid" and destro[3].group == nil, "groups carried over")
ok(destro[1].pvp and destro[1].pvp[1] == 157, "PvP talents carried over")
ok(#B.list(265) == 1, "other spec imported")
ok(said("Brought over 4 builds"), "import message")
fire("PLAYER_LOGIN")
ok(#B.list(267) == 3, "import runs once")
section("one-time import")

local a = B.add(267, { name = "Solo", text = "SPEC:267:1111" })
ok(a and a.name == "Solo (2)", "names stay unique: " .. tostring(a and a.name))
ok(B.add(267, { name = "x", text = "SPEC:267:1111" }) == nil, "same string not saved twice")
ok(B.add(267, { name = "x", text = "SPEC:267:1103" }) == nil, "same talents (a free node aside) not saved twice")
local C = TK.compare
local d = C.diff("SPEC:267:1100", "SPEC:267:2101")
local lines = C.describe(d)
ok(#d == 2 and lines[1] == "T1011 -> T1012" and lines[2] == "+ T1041 (class)", "differences by name: " .. table.concat(lines, " | "))
B.saveCurrent("")
ok(B.list(267)[#B.list(267)].name == "Destruction 5", "save current gets a default name")
ok(TK.db.active[267] == "Destruction 5", "saved build is the active one")
ok(said("Close to HC Cleave: 1 talent apart") or said("Close to HC ST: 1 talent apart"), "near match named on save")
B.rename(267, B.list(267)[#B.list(267)], "Solo")
ok(TK.db.active[267] == "Solo (3)", "rename keeps names unique and follows active: " .. tostring(TK.db.active[267]))
B.delete(267, B.list(267)[#B.list(267)])
ok(TK.db.active[267] == nil and #B.list(267) == 4, "delete clears active")
B.importString("not a string")
ok(said("isn't a talent string"), "bad import rejected")
B.importString("SPEC:265:01")
ok(#B.list(265) == 2, "import goes to the string's spec")
section("save, import, rename, delete")

configs[7] = { name = "TalentKeeper" }
local target = destro[1]
B.apply(target)
ok(configs[7] == nil, "old TalentKeeper loadout replaced")
ok(TK.db.active[267] == target.name, "active set on apply")
configs[8] = { name = "TalentKeeper" }
fire("TRAIT_CONFIG_CREATED", { name = "TalentKeeper", ID = 8 })
ok(#loads == 0, "waits a moment before loading")
runTimers()
ok(#loads == 1, "loaded once")
runTimers() -- the retry after LoadConfig's error
ok(imports == 1 and #loads == 2 and loads[2] == 8, "same loadout loaded again after an error")
ok(TK.db.active[267] == target.name, "second load succeeds")
runTimers() -- verify
ok(not said("no longer fit"), "talents verified")
currentSpec = 265
B.apply(target)
ok(said("That build is for Destruction"), "wrong-spec build refused")
currentSpec = 267
ok(chatFilter(nil, nil, "You have unlearned [Banish].") == true, "unlearn line hidden while applying")
ok(chatFilter(nil, nil, "Welcome to the realm.") == false, "other system lines pass")
ok(B.add(267, { name = "dup", text = "  " .. B.list(267)[2].text .. "\n" }) == nil, "pasted copy with spaces is a duplicate")
fire("CONFIG_COMMIT_FAILED", 1)
runTimers()
ok(not said("didn't accept"), "a refused commit that still landed isn't reported")
-- a node a patch made free: old string lists it as bought (1), today's export as free (3)
C_Traits.GenerateImportString = function() return "SPEC:267:3100" end
ok(#TK.compare.diff("SPEC:267:1100", "SPEC:267:3100") == 0, "talents made free since don't count as differences")
C_Traits.GenerateImportString = function() return "SPEC:" .. currentSpec .. ":1000" end
-- stuck staged changes are dropped before applying
staged = true
B.apply(target)
ok(rolledBack and not said("Can't change talents"), "staged changes rolled back before applying")
staged = false
local currencyInfo = C_Traits.GetTreeCurrencyInfo
C_Traits.GetTreeCurrencyInfo = function() return { { traitCurrencyID = 1, quantity = 4 } } end
B.saveCurrent("short")
ok(said("left to spend") and not (function() for _, x in ipairs(B.list(267)) do if x.name == "short" then return true end end end)(), "won't save with points left to spend")
C_Traits.GetTreeCurrencyInfo = function() return { { traitCurrencyID = 1, quantity = 0 }, { traitCurrencyID = 2, quantity = 0 }, { traitCurrencyID = 9, quantity = 0 }, { traitCurrencyID = 8, quantity = 10 } } end
local subInfo, activeHero = C_Traits.GetSubTreeInfo, C_ClassTalents.GetActiveHeroTalentSpec
C_Traits.GetSubTreeInfo = function() return { traitCurrencyID = 9 } end
C_ClassTalents.GetActiveHeroTalentSpec = function() return 1 end
ok(not B.unspent(), "the other hero tree's unspent points don't block saving")
C_Traits.GetSubTreeInfo, C_ClassTalents.GetActiveHeroTalentSpec = subInfo, activeHero
C_Traits.GetTreeCurrencyInfo = currencyInfo

lastSelected = nil
section("apply with one retry")

SlashCmdList.TALENTKEEPER("debug")
ok(TK.debugOn, "debug on")
SlashCmdList.TALENTKEEPER("log clear")
ok(#TK.db.log == 0, "log cleared")
SlashCmdList.TALENTKEEPER("nonsense")
ok(said("/tk save"), "help on unknown command")
SlashCmdList.TALENTKEEPER("")
ok(not said("Pick a specialization"), "quick list opens")
section("slash commands")

local function labelsOf(items) local out = {} for _, it in ipairs(items) do
    if it.label or it.heading then
        out[#out + 1] = it.heading and ("head:" .. it.heading) or ((it.checked and "check:" or "item:") .. (type(it.label) == "function" and it.label() or it.label))
    end end
    return table.concat(out, ",") end
local quick = TK.ui.quickItems(267)
local flat = labelsOf(quick)
ok(flat:find("head:Raid,check:HC Cleave") and flat:find("check:Solo"), "quick list: group headings, builds: " .. flat)
local applied
local realApply = B.apply
B.apply = function(b) applied = b end
for _, it in ipairs(quick) do if it.label == "Solo" then it.onClick() end end
B.apply = realApply
ok(applied and applied.name == "Solo", "clicking a build in the quick list applies it")
local tl = labelsOf(TK.ui.tagItems(B.list(267)[1]))
ok(tl:find("^check:Delves,head:Mythic%+ dungeons,check:Dungeon A,head:Raid A,check:Boss A$"),
    "tag list: delves, open world, dungeons, then raid bosses (no Raid / Mythic+ / whole raid): " .. tl)
local cols = 0
for _, it in ipairs(TK.ui.tagItems(B.list(267)[1])) do if it.column then cols = cols + 1 end end
ok(cols == 1, "raids in a second column")
ok(not tl:find("World"), "no world bosses in the tag list")
section("menu")

local function setCurrent(p) C_Traits.GenerateImportString = function() return "SPEC:267:" .. p end end

local mb = B.list(267)[1]
B.setGroup(mb, "  M+  ")
ok(mb.group == "M+", "move to a group (trimmed)")
B.setGroup(mb, "")
ok(mb.group == nil, "move out of groups")
section("groups")

local tb = B.list(267)[1]
B.toggleTag(tb, "boss:3001", "Boss A")
B.toggleTag(tb, "raid", "Raid")
ok(TK.ui.tagSummary(tb) == "Boss A +1" and tb.tags.raid == "Raid", "tags saved and summarized")
B.toggleTag(tb, "raid", "Raid")
B.toggleTag(tb, "boss:3001", "Boss A")
ok(tb.tags == nil and TK.ui.tagSummary(tb) == nil, "untagging clears tags")
setCurrent(tb.text:match("^SPEC:267:(.*)$"))
B.saveCurrent("Again")
ok(said("Same talents as |cffffffff" .. tb.name) and TK.selected == tb, "saving talents you have selects that build")
B.toggleTag(tb, "zone:501", "Dungeon A")
ok(tb.tags and tb.tags["zone:501"] == "Dungeon A", "tag from the offer: " .. tostring(tb.tags and next(tb.tags)))
UnitClass = function() return "Warlock", "WARLOCK", 9 end
GetNumSpecializationsForClassID = function() return 3 end
GetInstanceInfo = function() return "Delve A", "scenario", 208, nil, nil, nil, nil, 501 end
local other = B.list(267)[2]
B.toggleTag(tb, "zone:9", "D9")
B.toggleTag(other, "zone:9", "D9")
ok(other.tags["zone:9"] and not (tb.tags and tb.tags["zone:9"]) and said("D9 moved from"), "a tag moves: one build per spec per situation")
other.tags = nil
local mp = B.add(265, { name = "Aff delve", text = "SPEC:265:1111", tags = { delve = "Delves" } })
local hits = B.forHere(B.here())
ok(#hits == 1 and hits[1].b == tb, "zone-in: builds tagged for this place win over Delves")
tb.tags = nil
hits = B.forHere(B.here())
ok(#hits == 1 and hits[1].b == mp and hits[1].specID == 265, "zone-in: else the Delves build, any spec")
B.delete(265, mp)
other.tags = { ["boss:7"] = "Boss Z" }
ok(B.add(267, { name = "dup", text = tb.text, tags = { ["boss:7"] = "Boss Z", ["zone:8"] = "D8" } }) == nil, "a duplicate with tags isn't saved")
ok(tb.tags["boss:7"] and tb.tags["zone:8"] and not other.tags, "a duplicate's tags land on the saved build, moved off others")
tb.tags = { ["zone:8"] = "D8" }
B.importString(tb.text, "dup2", nil, { ["zone:8"] = "D8" })
ok(tb.tags["zone:8"] and said("Tagged it for D8"), "importing a duplicate keeps a tag it already has and says so")
tb.tags = nil
section("tags")

-- groups: save into a group, rename it, delete it with its builds
setCurrent("2222")
B.saveCurrent("Grouped", "Lab")
local gb = B.list(267)[#B.list(267)]
ok(gb.group == "Lab" and TK.selected == gb, "save current goes into the chosen group and is selected")
B.importString("SPEC:267:2223", "Imp", "Lab")
ok(B.list(267)[#B.list(267)].group == "Lab", "import goes into the chosen group")
B.renameGroup(267, "Lab", "Test")
ok(gb.group == "Test", "group renamed")
local n0 = #B.list(267)
B.deleteGroup(267, "Test")
ok(#B.list(267) == n0 - 2, "group deleted with its builds")
-- old saved data: variant and gear fields are dropped once
TalentKeeperDB.plainBuilds = nil
TalentKeeperDB.tidy = {}
B.list(267)[1].main, B.list(267)[1].gear = "x", "y"
fire("ADDON_LOADED", "TalentKeeper")
ok(B.list(267)[1].main == nil and B.list(267)[1].gear == nil and TalentKeeperDB.tidy == nil, "old variant / gear / tidy data cleared")
section("groups and old data")

-- the side pane: rows, click to select (preview), the panel's buttons, the save / import dialog
PlayerSpellsFrame = Frame()
PlayerSpellsFrame.TalentsFrame = Frame()
PlayerSpellsFrame.TalentsFrame.GetTalentButtonByNodeID = function() return nil end
PlayerSpellsFrame.TalentsFrame.HeroTalentsContainer = false
GetNumSpecializations, GetSpecialization = function() return 3 end, function() return 3 end
GetSpecializationInfo = function(i) return 264 + i, "Spec" .. i, nil, 1 end
for _, fn in ipairs(onSpells) do fn() end
local before = #frames
local tfShow = PlayerSpellsFrame.TalentsFrame.scripts
TK.selected = nil
TK.window.refresh() -- pane hidden until the talent window shows: nothing to draw yet
local function rowsNow() local out = {} for _, f in ipairs(frames) do if f.scripts.OnDoubleClick then out[#out + 1] = f end end return out end
-- show it: HookScript is a stub, so call the refresh the hook would
TK.window.refresh()
local rs = rowsNow()
ok(#rs > 0, "pane draws build rows: " .. #rs)
rawset(rs[1], "dragged", false)
rs[1].scripts.OnClick(rs[1], "LeftButton")
ok(TK.selected == rs[1].b, "click selects a build")
rs[1].scripts.OnClick(rs[1], "LeftButton")
ok(TK.selected == nil, "click again clears the selection")
TK.ui.buildDialog(true)
TK.ui.buildDialog(false)
section("side pane and dialog")

-- prompt: tagged build on another build offers a switch; nothing set offers use current
GetInstanceInfo = function() return "Dungeon A", "party", 23, nil, nil, nil, nil, 501 end
local P = TK.prompt
local pb = B.list(267)[1]
pb.tags = { ["zone:501"] = "Dungeon A" }
C_Traits.GenerateImportString = function() return "SPEC:267:0001" end
P.check()
ok(TK.db.log[#TK.db.log]:find("offering '" .. pb.name .. "'"), "prompt offers the tagged build: " .. TK.db.log[#TK.db.log])
P.check()
ok(TK.db.log[#TK.db.log]:find("offering"), "same place isn't asked twice")
pb.tags = nil
C_ChallengeMode.GetMapTable = function() return { 1, 2 } end
C_ChallengeMode.GetMapUIInfo = function(id) if id == 2 then return "Dungeon B", 2, 0, 0, 0, 502 end return "Dungeon A", 1, 0, 0, 0, 501 end
GetInstanceInfo = function() return "Dungeon B", "party", 23, nil, nil, nil, nil, 502 end
P.check()
ok(TK.db.log[#TK.db.log]:find("Dungeon B, nothing set"), "nothing set: asks once: " .. TK.db.log[#TK.db.log])
GetInstanceInfo = function() return "Old Dungeon", "party", 1, nil, nil, nil, nil, 999 end
local n9 = #TK.db.log
P.check()
ok(#TK.db.log == n9, "old / timewalking dungeons: no prompt")
GetInstanceInfo = function() return "Dornogal", "none", 0, nil, nil, nil, nil, 2552 end
local n0 = #TK.db.log
P.check()
ok(#TK.db.log == n0, "open world: no prompt")
GetInstanceInfo = function() return "Raid A", "raid", 16, nil, nil, nil, nil, 2700 end
local n = #TK.db.log
P.check()
ok(#TK.db.log == n, "raids wait for boss awareness")
section("prompt")

-- ready check: dungeon tag, raid boss by room / lockout / pick
local RC = TK.readycheck
GetInstanceInfo = function() return "Dungeon A", "party", 23, nil, nil, nil, nil, 501 end
local rb = B.list(267)[1]
rb.tags = { ["zone:501"] = "Dungeon A" }
C_Traits.GenerateImportString = function() return "SPEC:267:0001" end
RC.show()
ok(TK.db.log[#TK.db.log]:find("readycheck: Dungeon A, tagged '" .. rb.name .. "'"), "ready check in a dungeon: wrong build named: " .. TK.db.log[#TK.db.log])
rb.tags = nil
GetInstanceInfo = function() return "Raid A", "raid", 15, nil, nil, nil, nil, 2700 end
C_RaidLocks = { IsEncounterComplete = function() return false end }
GetSubZoneText = function() return "Boss Room" end
local boss, how = RC.expectedBoss()
ok(boss and boss.name == "Boss A" and how == "lockout", "raid: first boss alive in the lockout: " .. tostring(how))
fire("ENCOUNTER_START", 3001, "Boss A", 15, 20)
ok(TK.db.rooms[2700]["Boss Room"] == 3001, "a pull teaches the room")
boss, how = RC.expectedBoss()
ok(how == "room", "raid: the room wins once learned")
RC.show()
ok(TK.db.log[#TK.db.log]:find("readycheck: Boss A %(room%), nothing tagged"), "raid ready check: " .. TK.db.log[#TK.db.log])
section("ready check")

print_("smoke: all passed")
