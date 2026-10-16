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
tInvert = function(t) local r = {} for k, v in pairs(t) do r[v] = k end return r end
debugstack = function() return "stack" end
geterrorhandler = function() return function(e) error(e, 0) end end
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
Enum = { LoadConfigResult = { Error = 0, NoChangesNecessary = 1, LoadInProgress = 2, Ready = 3 } }
MenuResponse = { Close = 3, CloseAll = 4, Refresh = 2 }

-- Strings in tests look like "SPEC:<id>:<anything>"; the reader returns that spec.
ClassTalentImportExportMixin = {
    ReadLoadoutHeader = function(_, stream) local spec = stream.text:match("^SPEC:(%d+):") return spec ~= nil, 2, tonumber(spec) end,
    ReadLoadoutContent = function() return {} end,
    ConvertToImportLoadoutEntryInfo = function() return { { nodeID = 1, ranksPurchased = 1 } } end,
}
ExportUtil = { MakeImportDataStream = function(text) return { text = text } end }
local configs, loads, imports = {}, {}, 0
C_Traits = {
    GetLoadoutSerializationVersion = function() return 2 end,
    GenerateImportString = function() return "SPEC:" .. currentSpec .. ":current" end,
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
}
C_SpecializationInfo = { GetAllSelectedPvpTalentIDs = function() return { 15, 18 } end, GetPvpTalentSlotInfo = function() return nil end }
local menuGen
MenuUtil = { CreateContextMenu = function(_, gen) menuGen = gen end }

-- Load in TOC order ---------------------------------------------------------------
local ns = {}
for line in io.lines("TalentKeeper.toc") do
    if line:match("%.lua$") and not line:match("^#") and not line:match("^Dev") then
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
    { name = "HC Cleave", text = "SPEC:267:a", isInGroup = true, pvp1 = 157 },
    { name = "HC ST", text = "SPEC:267:b", isInGroup = true },
    { name = "Solo", text = "SPEC:267:c" },
    { name = "Copy", text = "SPEC:267:c" },
}, [1] = { { name = "Aff", text = "SPEC:265:a" } } } }
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

local a = B.add(267, { name = "Solo", text = "SPEC:267:d" })
ok(a and a.name == "Solo (2)", "names stay unique: " .. tostring(a and a.name))
ok(B.add(267, { name = "x", text = "SPEC:267:d" }) == nil, "same string not saved twice")
B.saveCurrent("")
ok(B.list(267)[#B.list(267)].name == "Destruction 5", "save current gets a default name")
ok(TK.db.active[267] == "Destruction 5", "saved build is the active one")
B.rename(267, B.list(267)[#B.list(267)], "Solo")
ok(TK.db.active[267] == "Solo (3)", "rename keeps names unique and follows active: " .. tostring(TK.db.active[267]))
B.delete(267, B.list(267)[#B.list(267)])
ok(TK.db.active[267] == nil and #B.list(267) == 4, "delete clears active")
B.importString("not a string")
ok(said("isn't a talent string"), "bad import rejected")
B.importString("SPEC:265:new")
ok(#B.list(265) == 2, "import goes to the string's spec")
section("save, import, rename, delete")

configs[7] = { name = "TalentKeeper" }
local target = destro[1]
B.apply(target)
ok(configs[7] == nil, "old TalentKeeper loadout replaced")
ok(TK.db.active[267] == target.name, "active set on apply")
configs[8] = { name = "TalentKeeper" }
fire("TRAIT_CONFIG_CREATED", { name = "TalentKeeper", ID = 8 })
ok(#loads == 1, "loaded once")
runTimers() -- the retry after LoadConfig's error
ok(imports == 2, "retried once after an error")
fire("TRAIT_CONFIG_CREATED", { name = "TalentKeeper", ID = 9 })
ok(#loads == 2 and TK.db.active[267] == target.name, "second load succeeds")
runTimers() -- verify
ok(not said("no longer fit"), "talents verified")
currentSpec = 265
B.apply(target)
ok(said("That build is for Destruction"), "wrong-spec build refused")
currentSpec = 267
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
local del = raid.children[1].children[3]
ok(del.label == "Delete", "build submenu: rename, copy, delete")
local before = #B.list(267)
ok(del.args[1]() == MenuResponse.Refresh, "first delete click arms")
ok(del.args[1]() == MenuResponse.CloseAll and #B.list(267) == before - 1, "second click deletes")
section("menu")

print_("smoke: all passed")
