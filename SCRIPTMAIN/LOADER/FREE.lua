--[[
    ╔═══════════════════════════════════════════════════════════════╗
    ║          BorcaHub  •  ScriptMain / Loader / Free.lua         ║
    ║  Free Loader – No Key Required + Game Detection + Execute    ║
    ║  Version : 0.0.1                                             ║
    ╚═══════════════════════════════════════════════════════════════╝
--]]

local GITHUB_ROOT = "https://raw.githubusercontent.com/BorCaHub/BorcaHub/main/"

-- ================================================================
--  SAFE LOADER HELPER
-- ================================================================

local function SafeLoadFromGitHub(path)
    local url = GITHUB_ROOT .. path:gsub(" ", "%%20")
    local ok, source = pcall(function()
        return game:HttpGet(url)
    end)
    if not ok or not source or #source < 10 or source:find("404: Not Found") then
        return nil, "Failed to download: " .. path
    end
    local fn, loadErr = loadstring(source)
    if not fn then
        return nil, "Loadstring error in " .. path .. ": " .. tostring(loadErr)
    end
    return fn
end

-- ================================================================
--  STEP 1: DETECT GAME
-- ================================================================

print("[BorcaHub] Free Loader v0.0.1 – Starting...")

local CheckGameFn, cgErr = SafeLoadFromGitHub("SCRIPTMAIN/SCRIPTS/CHECKGAMEID.lua")
if not CheckGameFn then
    warn("[BorcaHub] Failed to load CheckGameID: " .. tostring(cgErr))
    return
end

local CheckGameID = CheckGameFn()

local gameEntry, detectMethod = CheckGameID.GetGameEntry()
print("[BorcaHub] Game detected: " .. gameEntry.Name .. " (Method: " .. detectMethod .. ")")

-- ================================================================
--  STEP 2: LOAD FREE SCRIPT
-- ================================================================

local scriptPath = gameEntry.Free
if not scriptPath then
    warn("[BorcaHub] No Free script path found for: " .. gameEntry.Name)
    return
end

-- Strip the "BorcaHub/" prefix for GitHub raw URL
local gitPath = scriptPath:gsub("^BorcaHub/", "")

print("[BorcaHub] Loading Free script: " .. gitPath)

local scriptFn, scriptErr = SafeLoadFromGitHub(gitPath)
if not scriptFn then
    warn("[BorcaHub] Failed to load script: " .. tostring(scriptErr))
    return
end

local execOk, execErr = pcall(scriptFn)
if execOk then
    print("[BorcaHub] Free script loaded successfully for: " .. gameEntry.Name)
else
    warn("[BorcaHub] Script execution error: " .. tostring(execErr))
end
