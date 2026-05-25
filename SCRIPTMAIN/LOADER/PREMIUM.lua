--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║        BorcaHub  •  ScriptMain / Loader / Premium.lua        ║
    ║                                                              ║
    ║  Entry-point for PREMIUM tier users.                         ║
    ║                                                              ║
    ║  Boot sequence:                                              ║
    ║    1. Load UI Library                                        ║
    ║    2. Validate Premium key  (Key/Main)                       ║
    ║    3. Check GameID for Premium tier                          ║
    ║    4. Load Premium/Universal script module                   ║
    ║    5. Load Commands controller → build window                ║
    ║    6. Fire ready notification                                ║
    ╚══════════════════════════════════════════════════════════════╝
--]]

-- ================================================================
--  RAW-SOURCE URLS
--  Replace with your actual raw GitHub / CDN links.
-- ================================================================

local URLS = {
    UILibrary      = "https://raw.githubusercontent.com/BorCaHub/BorcaHub/main/UIMain/Components/File/Main.lua",
    KeySystem      = "https://raw.githubusercontent.com/BorCaHub/BorcaHub/main/ScriptMain/Key/Main.lua",
    CheckGameID    = "https://raw.githubusercontent.com/BorCaHub/BorcaHub/main/ScriptMain/Scripts/CheckGameID.lua",
    PremiumScript  = "https://raw.githubusercontent.com/BorCaHub/BorcaHub/main/ScriptMain/Scripts/Premium/Universal.lua",
    Commands       = "https://raw.githubusercontent.com/BorCaHub/BorcaHub/main/UIMain/Components/Commands.lua",
    Icons          = "https://raw.githubusercontent.com/BorCaHub/BorcaHub/main/UIMain/Assets/Icons.lua",
}

-- ================================================================
--  UTILITIES
-- ================================================================

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

print("[BorcaHub] Premium Loader starting…")

-- Step 1 — UI Library  (loaded first so we can show error notifs)
print("[BorcaHub] Loading UI Library…")
local BorcaUI = SafeLoad(URLS.UILibrary, "UI Library")

-- Step 2 — Key validation
print("[BorcaHub] Loading Key System…")
local KeySystem = SafeLoad(URLS.KeySystem, "Key/Main")

print("[BorcaHub] Validating key…")
local keyResult = KeySystem:Validate()

if not keyResult or not keyResult.Valid then
    local msg = keyResult and keyResult.Message or "Key validation failed."
    warn("[BorcaHub] " .. msg)
    BorcaUI:Notify({
        Title    = "Key Invalid",
        Content  = msg,
        Type     = "Error",
        Duration = 8,
    })
    return
end

if keyResult.Tier ~= "Premium" then
    warn("[BorcaHub] Key is not a Premium key (tier: " .. tostring(keyResult.Tier) .. "). Use Free loader instead.")
    BorcaUI:Notify({
        Title    = "Wrong Tier",
        Content  = "This key is for the " .. keyResult.Tier .. " tier. Use the Free loader.",
        Type     = "Warning",
        Duration = 7,
    })
    return
end

print(string.format("[BorcaHub] Key valid — User: %s  Tier: %s  Expires: %s",
    keyResult.Username or "?",
    keyResult.Tier,
    keyResult.Expiry or "Lifetime"
))

-- Step 3 — Check GameID
print("[BorcaHub] Checking Game ID…")
local CheckGameID = SafeLoad(URLS.CheckGameID, "CheckGameID")

local supported, gameData, gameMsg = CheckGameID.Check("Premium")
print("[BorcaHub] " .. gameMsg)

if not supported then
    warn("[BorcaHub] Unsupported game for Premium. Aborting.")
    BorcaUI:Notify({
        Title    = "Unsupported Game",
        Content  = gameMsg,
        Type     = "Error",
        Duration = 8,
    })
    return
end

-- Step 4 — Icons
local Icons = SafeLoad(URLS.Icons, "Icons")

-- Step 5 — Premium Universal Script
print("[BorcaHub] Loading Premium script module…")
local scriptUrl = string.format(
    "https://raw.githubusercontent.com/BorCaHub/BorcaHub/main/ScriptMain/Scripts/Premium/%s.lua",
    gameData.Short or "Universal"
)
local PremiumScript
local ok, result = pcall(function()
    return loadstring(game:HttpGet(scriptUrl, true))()
end)
if ok and result then
    PremiumScript = result
else
    warn("[BorcaHub] Fallback ke Universal…")
    PremiumScript = SafeLoad(URLS.PremiumScript, "Premium/Universal")
end

-- Step 6 — Commands controller
print("[BorcaHub] Initialising Commands…")
local Commands = SafeLoad(URLS.Commands, "Commands")

Commands:Init({
    Library   = BorcaUI,
    Tier      = "Premium",
    GameData  = gameData,
    KeyResult = keyResult,
    Script    = PremiumScript,
})

print("[BorcaHub] ✓ Premium loader complete — game:", gameData.Name, "— user:", keyResult.Username)

-- Expose globally
_G.BorcaHub = {
    Lib        = BorcaUI,
    Window     = Commands.Window,
    Commands   = Commands,
    Icons      = Icons,
    Flags      = BorcaUI.Flags,
    Tier       = "Premium",
    Game       = gameData,
    KeyResult  = keyResult,
}
