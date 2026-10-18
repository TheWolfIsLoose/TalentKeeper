-- TalentKeeper core: addon table, saved data, chat, log, events, slash commands, load line.
local addonName, TK = ...
_G[addonName] = TK

TK.commands = {}  -- /tk <sub> handlers, filled by other files
TK.sources = {}   -- build sources other addons register: [name] = function(specID) return { { name, text, tags }, ... } end

-- Saved builds changed: lets an open window redraw.
function TK.changed() if TK.onChange then TK.onChange() end end

function TK.chat(msg) print("|cff98ff98TalentKeeper|r: " .. msg) end

-- Log -----------------------------------------------------------------------
-- One line per entry in TalentKeeperDB.log, newest last. /tk log shows it for copying
-- into a report; /tk debug adds detailed steps until /reload.
local MAX_LOG = 500
function TK.log(fmt, ...)
    local log = TK.db and TK.db.log
    if not log then return end
    log[#log + 1] = date("[%Y-%m-%d %H:%M:%S] ") .. (select("#", ...) > 0 and fmt:format(...) or fmt)
    while #log > MAX_LOG do table.remove(log, 1) end -- ponytail: shifts the array; fine at 500 lines
end

function TK.debug(fmt, ...)
    if TK.debugOn then TK.log("debug: " .. fmt, ...) end
end

-- Handler errors go to the log (so a pasted /tk log shows them), then to the game's handler.
local function onError(err)
    TK.log("error: %s | %s", tostring(err), (debugstack(2, 3, 0) or ""):gsub("\n", " | "))
    return err
end

function TK.safe(fn)
    return function(...)
        local n, args = select("#", ...), { ... }
        local ok, err = xpcall(function() return fn(unpack(args, 1, n)) end, onError)
        if not ok then geterrorhandler()(err) end
    end
end

-- Events --------------------------------------------------------------------
local handlers = {}
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(handlers[event]) do fn(...) end
end)

function TK.on(event, fn)
    if not handlers[event] then handlers[event] = {}; events:RegisterEvent(event) end
    table.insert(handlers[event], TK.safe(fn))
end

TK.on("ADDON_LOADED", function(name)
    if name ~= addonName then return end
    TalentKeeperDB = TalentKeeperDB or {}
    local db = TalentKeeperDB
    db.builds = db.builds or {}     -- [specID] = { { name, text, pvp?, group?, added }, ... }
    db.active = db.active or {}     -- [specID] = name of the build last applied
    db.imported = db.imported or {} -- one-time imports already done
    db.log = db.log or {}
    TK.db = db
    -- 2c48aa6 marked builds Outdated for talents a patch made free; clear those marks once.
    if db.freeNodeFix ~= 2 then -- 2: also marks left by checking a build after another was applied
        for _, list in pairs(db.builds) do for _, b in ipairs(list) do b.outdated = nil end end
        db.freeNodeFix = 2
    end
    local version = C_AddOns.GetAddOnMetadata(addonName, "Version")
    if TK.build then version = "dev " .. TK.build elseif version:find("@") then version = "dev" else version = "v" .. version end
    if db.lastVersion ~= version then TK.log("version: %s -> %s", tostring(db.lastVersion), version) end
    db.lastVersion = version
    TK.chat(version .. " loaded. Type |cff98ff98/tk|r to open your builds.")
end)

-- Slash commands -------------------------------------------------------------
local HELP = {
    "  /tk |cff8c8c8c— open your builds for this spec|r",
    "  /tk save [name] |cff8c8c8c— save your current talents as a build|r",
    "  /tk import |cff8c8c8c— paste a talent string to save it|r",
    "  /tk log [clear] |cff8c8c8c— open the log to copy into a bug report, or clear it|r",
    "  /tk debug |cff8c8c8c— record detailed steps into the log until /reload|r",
}

TK.commands.help = function()
    TK.chat("commands:")
    for _, line in ipairs(HELP) do print(line) end
end

TK.commands.log = function(arg)
    if arg == "clear" then
        wipe(TK.db.log)
        return TK.chat("Log cleared.")
    end
    TK.ui.textWindow({ title = "TalentKeeper log", text = table.concat(TK.db.log, "\n"), readOnly = true })
end

TK.commands.debug = function()
    TK.debugOn = not TK.debugOn
    if TK.debugOn then
        TK.chat("Detailed recording |cff98ff98on|r until you /reload. Repeat the problem, then type |cff98ff98/tk log|r.")
    else
        TK.chat("Detailed recording |cff8c8c8coff|r.")
    end
end

SLASH_TALENTKEEPER1, SLASH_TALENTKEEPER2 = "/tk", "/talentkeeper"
SlashCmdList.TALENTKEEPER = TK.safe(function(msg)
    local sub, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
    sub = sub:lower()
    if sub == "" then return TK.ui.openMenu() end
    local fn = TK.commands[sub]
    if fn then fn(rest) else TK.commands.help() end
end)
