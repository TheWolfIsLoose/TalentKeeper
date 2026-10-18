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
        if k:match("^Create") then return function() return Frame() end end
        return function() return Stub end
    end })
end
setmetatable(_G, { __index = function(_, k)
    if k:match("^TalentKeeper") or k == "TalentLoadoutEx" then return nil end
    if k:match("^[A-Z]") or k:match("^C_") then return Stub end
end })
CreateFrame = function() local f = Frame(); frames[#frames + 1] = f; return f end
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
EventUtil = { ContinueOnAddOnLoaded = function() end }
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
EJ_GetInstanceByIndex = function(i) if i == 1 then return 10, "Raid A" end end
EJ_GetInstanceInfo = function() return "Raid A", nil, nil, nil, nil, nil, nil, nil, nil, 2700 end
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

-- in place on a small simulated tree: only differences change, apex ranks add up, hero kept
do
    local T = Enum.TraitNodeType
    local tree = {
        [1] = { type = T.Single, max = 1, y = 0, x = 0 },
        [2] = { type = T.Single, max = 2, y = 1, x = 0, req = 1 },
        [3] = { type = T.Selection, y = 1, x = 1 },
        [4] = { type = T.Single, max = 4, y = 9, x = 0, req = 2 }, -- apex
        [5] = { type = T.SubTreeSelection, y = 0, x = 5 },
        [6] = { type = T.Single, max = 1, y = 1, x = 5, req = 5 },
        [7] = { type = T.Single, max = 1, y = 2, x = 2, free = true },
    }
    local have = { [1] = 1, [2] = 2, [3] = 31, [4] = 2, [5] = 51, [6] = 1 }
    local saved, heroResets, committed = {}, 0, 0
    local function snapshot() local c = {} for k, v in pairs(have) do c[k] = v end return c end
    local function bought(id) local n = tree[id] return have[id] and (n.type == T.Single and have[id] or 1) or 0 end
    local function kids(id) for k, n in pairs(tree) do if n.req == id and bought(k) > 0 then return true end end end
    local T0 = {}
    for k, v in pairs(C_Traits) do T0[k] = v end
    C_Traits.GetTreeNodes = function() return { 1, 2, 3, 4, 5, 6, 7 } end
    C_Traits.GetNodeInfo = function(_, id)
        local n = tree[id]
        if not n then return nil end
        local r = bought(id)
        return { ID = id, type = n.type, isVisible = true, posX = n.x, posY = n.y, ranksPurchased = r,
            activeRank = n.free and 1 or r, activeEntry = n.type ~= T.Single and have[id] and { entryID = have[id] } or nil }
    end
    C_Traits.PurchaseRank = function(_, id)
        local n = tree[id]
        if n.free or (n.req and bought(n.req) == 0) or bought(id) >= n.max then return false end
        have[id] = bought(id) + 1 return true
    end
    C_Traits.RefundRank = function(_, id)
        if bought(id) == 0 or (bought(id) == 1 and kids(id)) then return false end
        have[id] = bought(id) > 1 and bought(id) - 1 or nil return true
    end
    C_Traits.RefundAllRanks = function(_, id) if kids(id) then return false end have[id] = nil return true end
    C_Traits.SetSelection = function(_, id, entry)
        if entry == nil and kids(id) then return false end
        have[id] = entry return true
    end
    C_Traits.ResetTreeByCurrency = function() heroResets = heroResets + 1 have[5], have[6] = nil, nil end
    C_Traits.ConfigHasStagedChanges = function() for k in pairs(tree) do if have[k] ~= saved[k] then return true end end return false end
    C_Traits.RollbackConfig = function() have = {} for k, v in pairs(saved) do have[k] = v end end
    C_Traits.GetSubTreeInfo = function() return { traitCurrencyID = 9 } end
    C_ClassTalents.GetHeroTalentSpecsForClassSpec = function() return { 1 } end
    C_ClassTalents.CommitConfig = function() committed = committed + 1 saved = snapshot() return true end
    saved = snapshot()
    local build = {
        { nodeID = 1, ranksPurchased = 1 }, { nodeID = 2, ranksPurchased = 1 }, { nodeID = 3, ranksPurchased = 1, selectionEntryID = 32 },
        { nodeID = 4, ranksPurchased = 2 }, { nodeID = 4, ranksPurchased = 2 }, -- apex as two entries
        { nodeID = 5, ranksPurchased = 1, selectionEntryID = 51 }, { nodeID = 6, ranksPurchased = 1 },
    }
    ok(B.inPlace({ name = "sim" }, build, 266, 20) and committed == 1, "in place commits once")
    ok(have[2] == 1 and have[3] == 32 and have[4] == 4 and have[1] == 1, "only differences changed, apex at full ranks")
    ok(heroResets == 0 and have[5] == 51 and have[6] == 1, "same hero tree left alone")
    ok(B.inPlace({ name = "sim" }, build, 266, 20) and committed == 1, "nothing to change: no commit")
    build[6].selectionEntryID = 52
    ok(B.inPlace({ name = "sim" }, build, 266, 20) and heroResets == 1 and have[5] == 52 and have[6] == 1, "other hero tree: hero talents reset and rebought")
    ok(B.inPlace({ name = "sim" }, { { nodeID = 1, ranksPurchased = 1 }, { nodeID = 7, ranksPurchased = 1 } }, 266, 20), "free talent doesn't block")
    tree[2].req = 99 -- node 2 can no longer be bought: in place gives up and leaves nothing staged
    have[2] = nil saved = snapshot()
    ok(not B.inPlace({ name = "sim" }, build, 266, 20) and not C_Traits.ConfigHasStagedChanges(), "can't take a talent: rolled back, import instead")
    -- a swap where the kept talent hangs off the one going away (it has two ways in), with no
    -- points to spare: refund waits on the purchase, so it's done in alternating passes
    tree = {
        [8] = { type = T.Single, max = 1, y = 0, x = 0 },
        [9] = { type = T.Single, max = 1, y = 0, x = 2 },
        [10] = { type = T.Single, max = 1, y = 1, x = 1, req = { 8, 9 } },
    }
    local function anyBought(r) if type(r) ~= "table" then return bought(r) > 0 end for _, x in ipairs(r) do if bought(x) > 0 then return true end end end
    kids = function(id)
        for k, n in pairs(tree) do
            if bought(k) > 0 and n.req then
                local r = type(n.req) == "table" and n.req or { n.req }
                local other = false
                for _, x in ipairs(r) do if x ~= id and bought(x) > 0 then other = true end end
                for _, x in ipairs(r) do if x == id and not other then return true end end
            end
        end
    end
    C_Traits.PurchaseRank = function(_, id)
        local n, spent = tree[id], 0
        for k in pairs(tree) do spent = spent + bought(k) end
        if spent >= 3 or (n.req and not anyBought(n.req)) or bought(id) >= n.max then return false end
        have[id] = bought(id) + 1 return true
    end
    C_Traits.GetTreeNodes = function() return { 8, 9, 10 } end
    have = { [8] = 1, [10] = 1 } saved = snapshot()
    ok(B.inPlace({ name = "sim" }, { { nodeID = 9, ranksPurchased = 1 }, { nodeID = 10, ranksPurchased = 1 } }, 266, 20)
        and have[9] == 1 and have[10] == 1 and not have[8], "swap under a kept talent works in place")
    for k, v in pairs(T0) do C_Traits[k] = v end
end
lastSelected = nil
section("apply with one retry")

SlashCmdList.TALENTKEEPER("debug")
ok(TK.debugOn, "debug on")
SlashCmdList.TALENTKEEPER("log clear")
ok(#TK.db.log == 0, "log cleared")
SlashCmdList.TALENTKEEPER("nonsense")
ok(said("/tk save"), "help on unknown command")
SlashCmdList.TALENTKEEPER("")
ok(menuGen, "menu opens")
section("slash commands")

local calls = {}
local function Desc(label)
    local d = { label = label, children = {} }
    local function add(kind) return function(self, text, ...) local c = Desc(text) c.kind = kind c.args = { ... } table.insert(self.children, c) return c end end
    d.CreateTitle, d.CreateButton, d.CreateRadio, d.CreateDivider = add("title"), add("button"), add("radio"), add("divider")
    d.CreateCheckbox = add("checkbox")
    d.SetEnabled = function() end
    d.AddInitializer = function(self, fn) self.init = fn end
    return d
end
local root = Desc("root")
menuGen(nil, root)
local labels = {}
for _, c in ipairs(root.children) do labels[#labels + 1] = c.kind .. ":" .. tostring(c.label) end
local flat = table.concat(labels, ",")
ok(flat:find("title:TalentKeeper: Destruction"), "title names the spec")
ok(flat:find("radio:Solo,") and flat:find("button:Raid,"), "ungrouped builds and the group submenu: " .. flat)
ok(flat:find("button:Save current talents") and flat:find("button:Import a talent string"), "save and import entries")
local raid
for _, c in ipairs(root.children) do if c.label == "Raid" then raid = c end end
ok(#raid.children == 2 and raid.children[1].kind == "radio", "group holds its builds")
local sub, del = {}, nil
for _, c in ipairs(raid.children[1].children) do sub[#sub + 1] = tostring(c.label); if c.label == "Delete" then del = c end end
sub = table.concat(sub, ",")
ok(del and sub:find("Rename") and sub:find("Copy talent string"), "build submenu: rename, copy, delete: " .. sub)
ok(sub:find("Differs from your current talents by 1"), "submenu says how it differs from current talents")
local tagsMenu
for _, c in ipairs(raid.children[1].children) do if tostring(c.label):find("^Tags") then tagsMenu = c end end
local tl = {}
local function walk(d) for _, c in ipairs(d.children) do tl[#tl + 1] = c.kind .. ":" .. tostring(c.label) walk(c) end end
walk(tagsMenu)
tl = table.concat(tl, ",")
ok(tl:find("checkbox:Dungeon A |cff8c8c8c%(here%)|r") and tl:find("checkbox:Mythic%+") and tl:find("button:Mythic%+ dungeons")
    and tl:find("button:Raid A,checkbox:Whole raid,checkbox:Boss A"), "tags menu: here, content, dungeons, raid bosses: " .. tl)
local before = #B.list(267)
ok(del.args[1]() == MenuResponse.Refresh, "first delete click arms")
ok(del.args[1]() == MenuResponse.CloseAll and #B.list(267) == before - 1, "second click deletes")
section("menu")

-- Main builds and variants
local function setCurrent(p) C_Traits.GenerateImportString = function() return "SPEC:267:" .. p end end
local main = B.add(267, { name = "Main", text = "SPEC:267:1200", group = "Raid" })
setCurrent("1210")
B.saveVariant(main, "Var")
local var = B.list(267)[#B.list(267)]
ok(var.main == "Main" and var.group == "Raid" and #var.changes == 1, "variant saved with its changes and group")
ok(TK.compare.write(267, TK.compare.picks("SPEC:267:1200")) == "SPEC:267:1200", "writer round-trips")
setCurrent("0200")
B.updateToCurrent(main)
ok(main.text == "SPEC:267:0200" and var.text == "SPEC:267:0210" and not var.needsReview, "variant follows its main build")
setCurrent("0210")
B.updateToCurrent(main)
ok(var.needsReview, "variant needs review when the main build changes the same talent")
B.rename(267, main, "Main2")
ok(var.main == "Main2", "variant follows a renamed main build")
B.setGroup(var, "M+")
ok(main.group == "M+" and var.group == "M+", "moving a variant moves its whole family")
B.delete(267, main)
ok(var.main == nil and var.changes == nil, "variants become main builds when the main is deleted")
setCurrent("1000")
local base = B.add(267, { name = "Base", text = "SPEC:267:1200", group = "M+" })
local imp = B.add(267, { name = "Imported", text = "SPEC:267:1210" })
B.setMain(imp, base)
ok(imp.main == "Base" and #imp.changes == 1 and imp.group == "M+", "an imported build becomes a variant of a main build")
B.setMain(imp, nil)
ok(imp.main == nil and imp.changes == nil, "and a main build again")
B.delete(267, imp) B.delete(267, base)
section("main builds and variants")

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
menuGen = nil
setCurrent(tb.text:match("^SPEC:267:(.*)$"))
B.saveCurrent("Again")
ok(said("Same talents as |cffffffff" .. tb.name) and menuGen, "saving talents you have offers to tag that build")
local offer = Desc("root")
menuGen(nil, offer)
ok(offer.children[1].label == "Tag " .. tb.name .. " for" and offer.children[2].kind == "checkbox", "tag offer menu")
offer.children[2].args[2]()
ok(tb.tags and tb.tags["zone:501"] == "Dungeon A", "tag from the offer: " .. tostring(tb.tags and next(tb.tags)))
UnitClass = function() return "Warlock", "WARLOCK", 9 end
GetNumSpecializationsForClassID = function() return 3 end
GetInstanceInfo = function() return "Dungeon A", "party", 23, nil, nil, nil, nil, 501 end
local other = B.list(267)[2]
B.toggleTag(tb, "zone:9", "D9")
B.toggleTag(other, "zone:9", "D9")
ok(other.tags["zone:9"] and not (tb.tags and tb.tags["zone:9"]) and said("D9 moved from"), "a tag moves: one build per spec per situation")
other.tags = nil
local mp = B.add(265, { name = "Aff M+", text = "SPEC:265:1111", tags = { mplus = "Mythic+" } })
local hits = B.forHere(B.here())
ok(#hits == 1 and hits[1].b == tb, "zone-in: builds tagged for this instance win over content tags")
tb.tags = nil
hits = B.forHere(B.here())
ok(#hits == 1 and hits[1].b == mp and hits[1].specID == 265, "zone-in: else builds for its kind of content, any spec")
B.delete(265, mp)
section("tags")

-- Tidy up planner (pure: picks given directly)
local T = TK.tidy
local places = T.places({ { key = "zone:1", name = "Murder Row", kind = "dungeon" }, { key = "zone:2", name = "Altar of Fangs", kind = "dungeon" },
    { key = "boss:3", name = "Kith'ix", kind = "boss" }, { key = "boss:4", name = "Nymora the Shrouded", kind = "boss" } })
local function P(n, extra) local p = {} for i = 1, n do p[i] = "0:0" end for k, v in pairs(extra or {}) do p[k] = v end return p end
local far = P(20) for i = 21, 28 do far[i] = "0:0" end for i = 1, 8 do far[i] = nil end
local input = {
    { id = 1, name = "M+ Baseline", hero = "Soul Harvester", picks = P(20) },
    { id = 2, name = "Altar", hero = "Soul Harvester", picks = P(20, { [30] = "0:0" }) },
    { id = 3, name = "copy", hero = "Soul Harvester", picks = P(20) },
    { id = 4, name = "KITHIX", hero = "Soul Harvester", picks = far },
    { id = 5, name = "Raid ST", hero = "Hellcaller", picks = P(20) },
    { id = 6, name = "Imported 8", hero = "Soul Harvester", picks = P(20, { [31] = "0:0" }) },
    { id = 7, name = "MR aoe", hero = "Soul Harvester", picks = P(20, { [32] = "0:0", [33] = "0:0" }), tags = { mplus = "Mythic+" } },
}
local plan = T.plan(input, places)
local function find(id) for _, e in ipairs(plan.cores) do for _, m in ipairs(e.members) do if m.id == id then return e, m end end end end
local e1, m1 = find(1)
ok(m1.action == "core" and e1.name == "Soul Harvester M+", "core named from hero tree and names: " .. tostring(e1.name))
ok(select(2, find(3)).action == "merge" and select(2, find(6)).action == "merge", "copies and nameless near-copies merge")
local _, m2 = find(2)
ok(m2.action == "swap" and m2.tags["zone:2"] == "Altar of Fangs", "'Altar' read as Altar of Fangs, kept as a swap")
local _, m7 = find(7)
ok(m7.action == "swap" and m7.tags["zone:1"] == "Murder Row" and m7.tags.mplus == "Mythic+", "'MR' read as Murder Row; its own tag kept")
ok(not m1.tags.mplus, "Mythic+ stays with the one build tagged for it")
local e4, m4 = find(4)
ok(m4.action == "core" and e4 ~= e1 and m4.tags["boss:3"] == "Kith'ix", "far build is its own core; 'KITHIX' read as Kith'ix")
local e5 = find(5)
ok(e5.name == "Hellcaller Raid ST" and e5.group == "Raid", "other hero tree never combined: " .. e5.name)
ok(T.read("Nym", places).places[1].place.key == "boss:4", "'Nym' read as the start of a boss name")
ok(plan.counts.cores == 3 and plan.counts.swaps == 2 and plan.counts.merges == 2, "counts")
local before265 = #B.list(265)
B.add(265, { name = "Altar", text = "SPEC:265:1101" })
B.add(265, { name = "copy", text = "SPEC:265:1100" })
B.add(265, { name = "copy2", text = "SPEC:265:1100 " })
local n265 = #B.list(265)
T.show(265)
local p265 = TK.db.tidy[265].plan
ok(p265 and TK.db.tidy[265].input[1].picks, "plan and its input kept in saved data")
T.apply(265, p265)
ok(#B.list(265) == n265 - p265.counts.merges and said("Tidied Affliction"), "applied: merged builds gone")
T.undo(265)
ok(#B.list(265) == n265 and said("Put Affliction"), "undo puts the builds back")
-- "Altar": boss or dungeon, decided by the build's neighbours
local pl2 = T.places({ { key = "zone:2", name = "Altar of Fangs", kind = "dungeon" }, { key = "boss:8", name = "The Coiled Altar", kind = "boss" } })
local plan2 = T.plan({
    { id = 1, name = "Altar", hero = "H", picks = P(20) },
    { id = 2, name = "Raid ST", hero = "H", picks = P(20, { [40] = "0:0" }), tags = { raid = "Raid" } },
}, pl2)
local _, alt = (function() for _, e in ipairs(plan2.cores) do for _, m in ipairs(e.members) do if m.id == 1 then return e, m end end end end)()
local holderTags = {}
for _, e in ipairs(plan2.cores) do for _, m in ipairs(e.members) do for k in pairs(m.tags) do holderTags[k] = true end end end
ok(holderTags["boss:8"] and not holderTags["zone:2"], "'Altar' next to a raid build is the raid boss")
-- fill up from a registered source
TK.sources.Test = function(spec) return { { name = "Src all", text = "SPEC:265:1110", tags = { mplus = "Mythic+" } },
    { name = "Src MR", text = "SPEC:265:1110", tags = { ["zone:1"] = "Murder Row" } } } end
local before = #B.list(265)
T.fill(265)
local got
for _, b in ipairs(B.list(265)) do if b.name == "Src all" then got = b end end
ok(got and got.group == "Test" and got.tags.mplus and got.tags["zone:1"] and #B.list(265) == before + 1, "fill up: same talents fold their tags into one build")
T.undo(265)
ok(#B.list(265) == before, "undo after fill up")
TK.sources.Test = nil
section("tidy up planner")

print_("smoke: all passed")
