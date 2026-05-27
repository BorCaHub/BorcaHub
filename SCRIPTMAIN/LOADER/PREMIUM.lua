--[[
    ╔═══════════════════════════════════════════════════════════════╗
    ║          BorcaHub  •  ScriptMain / Loader / Premium.lua      ║
    ║  Premium Loader – Key Validation + Game Detection + Execute  ║
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
--  STEP 1: VALIDATE PREMIUM KEY
-- ================================================================

print("[BorcaHub] Premium Loader v0.0.1 – Starting...")

local KeyModule, keyErr = SafeLoadFromGitHub("SCRIPTMAIN/KEY/MAIN.lua")
if not KeyModule then
    warn("[BorcaHub] Failed to load Key module: " .. tostring(keyErr))
    return
end

local KeySystem = KeyModule()
local keyResult = KeySystem:Validate()

if not keyResult or not keyResult.Valid then
    warn("[BorcaHub] Key validation failed: " .. tostring(keyResult and keyResult.Message or "Unknown error"))
    return
end

local tier = keyResult.Tier or "Free"
print("[BorcaHub] Key validated – Tier: " .. tier .. " | Expiry: " .. tostring(keyResult.Expiry))

-- If key is Free tier, redirect to Free loader
if tier == "Free" then
    warn("[BorcaHub] Free tier key detected. Loading Free loader instead...")
    local freeFn, freeErr = SafeLoadFromGitHub("SCRIPTMAIN/LOADER/FREE.lua")
    if freeFn then
        freeFn()
    else
        warn("[BorcaHub] Failed to load Free loader: " .. tostring(freeErr))
    end
    return
end

-- ================================================================
--  STEP 2: DETECT GAME & LOAD SCRIPT
-- ================================================================

local CheckGameFn, cgErr = SafeLoadFromGitHub("SCRIPTMAIN/SCRIPTS/CHECKGAMEID.lua")
if not CheckGameFn then
    warn("[BorcaHub] Failed to load CheckGameID: " .. tostring(cgErr))
    return
end

local CheckGameID = CheckGameFn()

local gameEntry, detectMethod = CheckGameID.GetGameEntry()
print("[BorcaHub] Game detected: " .. gameEntry.Name .. " (Method: " .. detectMethod .. ")")

-- ================================================================
--  STEP 3: LOAD PREMIUM SCRIPT
-- ================================================================

local scriptPath = gameEntry.Premium
if not scriptPath then
    warn("[BorcaHub] No Premium script path found for: " .. gameEntry.Name)
    return
end

-- Strip the "BorcaHub/" prefix for GitHub raw URL
local gitPath = scriptPath:gsub("^BorcaHub/", "")

print("[BorcaHub] Loading Premium script: " .. gitPath)

local scriptFn, scriptErr = SafeLoadFromGitHub(gitPath)
if not scriptFn then
    warn("[BorcaHub] Failed to load script: " .. tostring(scriptErr))
    return
end

local execOk, execErr = pcall(scriptFn)
if execOk then
    print("[BorcaHub] Premium script loaded successfully for: " .. gameEntry.Name)
else
    warn("[BorcaHub] Script execution error: " .. tostring(execErr))
end
