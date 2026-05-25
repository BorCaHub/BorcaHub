--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║          BorcaHub  •  ScriptMain / Loader / Free.lua         ║
    ║                                                              ║
    ║  Entry-point for FREE tier users.                            ║
    ║                                                              ║
    ║  Boot sequence:                                              ║
    ║    1. Load UI Library                                        ║
    ║    2. Check GameID                                           ║
    ║    3. Load Free/Universal script module                      ║
    ║    4. Load Commands controller → build window                ║
    ║    5. Fire ready notification                                ║
    ╚══════════════════════════════════════════════════════════════╝
--]]

-- ================================================================
--  RAW-SOURCE URLS
--  Replace these with your actual raw GitHub / CDN links.
-- ================================================================

local URLS = {
    UILibrary   = "https://raw.githubusercontent.com/BorCaHub/BorcaHub/main/UIMain/Components/File/Main.lua",
    CheckGameID = "https://raw.githubusercontent.com/BorCaHub/BorcaHub/main/ScriptMain/Scripts/CheckGameID.lua",
    FreeScript  = "https://raw.githubusercontent.com/BorCaHub/BorcaHub/main/ScriptMain/Scripts/Free/Universal.lua",
    Commands    = "https://raw.githubusercontent.com/BorCaHub/BorcaHub/main/UIMain/Components/Commands.lua",
    Icons       = "https://raw.githubusercontent.com/BorCaHub/BorcaHub/main/UIMain/Assets/Icons.lua",
}

-- ================================================================
--  UTILITIES
-- ================================================================

local HttpService = game:GetService("HttpService")

local function SafeLoad(url, label)
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(url, true))()
    end)
    if not ok then
        error(string.format("[BorcaHub Loader] Failed to load %s:\n%s", label, tostring(result)), 2)
    end
    return result
end

-- ================================================================
--  BOOT
-- ================================================================

print("[BorcaHub] Free Loader starting…")

-- Step 1 — UI Library
print("[BorcaHub] Loading UI Library…")
local BorcaUI = SafeLoad(URLS.UILibrary, "UI Library")

-- Step 2 — Check GameID
print("[BorcaHub] Checking Game ID…")
local CheckGameID = SafeLoad(URLS.CheckGameID, "CheckGameID")

local supported, gameData, gameMsg = CheckGameID.Check("Free")
print("[BorcaHub] " .. gameMsg)

if not supported then
    -- Show an error notification using the library (window-less notify)
    warn("[BorcaHub] Unsupported game or tier. Aborting.")
    BorcaUI:Notify({
        Title    = "Unsupported Game",
        Content  = gameMsg,
        Type     = "Error",
        Duration = 8,
    })
    return
end

-- Step 3 — Icons (optional, loaded for script use)
local Icons = SafeLoad(URLS.Icons, "Icons")

-- Step 4 — Free Universal Script
print("[BorcaHub] Loading Free script module…")
local scriptUrl = string.format(
    "https://raw.githubusercontent.com/BorCaHub/BorcaHub/main/ScriptMain/Scripts/Free/%s.lua",
    gameData.Short or "Universal"
)
local FreeScript
local ok, result = pcall(function()
    return loadstring(game:HttpGet(scriptUrl, true))()
end)
if ok and result then
    FreeScript = result
else
    warn("[BorcaHub] Fallback ke Universal…")
    FreeScript = SafeLoad(URLS.FreeScript, "Free/Universal")
end
-- Step 5 — Commands controller
print("[BorcaHub] Initialising Commands…")
local Commands = SafeLoad(URLS.Commands, "Commands")

Commands:Init({
    Library   = BorcaUI,
    Tier      = "Free",
    GameData  = gameData,
    KeyResult = nil,
    Script    = FreeScript,
})

print("[BorcaHub] ✓ Free loader complete — game:", gameData.Name)

-- Expose to global scope for debugging / external scripts
_G.BorcaHub = {
    Lib      = BorcaUI,
    Window   = Commands.Window,
    Commands = Commands,
    Icons    = Icons,
    Flags    = BorcaUI.Flags,
    Tier     = "Free",
    Game     = gameData,
}
