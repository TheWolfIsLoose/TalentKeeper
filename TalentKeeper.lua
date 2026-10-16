-- TalentKeeper core. Phase 0: just the addon table, saved data, slash and load line.
local addonName, TK = ...
_G[addonName] = TK

TK.commands = {}  -- /tk <sub> handlers, filled by other files

local function chat(msg) print("|cff98ff98TalentKeeper|r: " .. msg) end
TK.chat = chat

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, name)
    if name ~= addonName then return end
    f:UnregisterEvent("ADDON_LOADED")
    TalentKeeperDB = TalentKeeperDB or {}
    TK.db = TalentKeeperDB
    local version = C_AddOns.GetAddOnMetadata(addonName, "Version")
    if TK.build then version = "dev " .. TK.build elseif version:find("@") then version = "dev" else version = "v" .. version end
    chat(version .. " loaded. Type |cff98ff98/tk spike|r for the test list.")
end)

SLASH_TALENTKEEPER1, SLASH_TALENTKEEPER2 = "/tk", "/talentkeeper"
SlashCmdList.TALENTKEEPER = function(msg)
    local sub, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
    local fn = TK.commands[sub:lower()]
    if fn then fn(rest) else chat("nothing here yet. Try |cff98ff98/tk spike|r.") end
end
