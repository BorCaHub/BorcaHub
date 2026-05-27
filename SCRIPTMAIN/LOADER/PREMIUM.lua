--[[
    ╔═══════════════════════════════════════════════════════════════╗
    ║          BorcaHub  •  ScriptMain / Loader / Premium.lua      ║
    ║  Premium Loader – Key Validation + Game Detection + Execute  ║
    ║  Version : 0.0.1                                             ║
    ╚═══════════════════════════════════════════════════════════════╝
--]]

local GITHUB_ROOT = "https://raw.githubusercontent.com/BorcaHub/BorcaHub/main/"

-- ================================================================
--  SAFE LOADER HELPER
-- ================================================================

local function SafeLoad(path)
    -- Try local file first (resilient local execution fallback)
    local localPaths = {
        path,
        "BorcaHub/" .. path,
        "C:/Users/SPIDER X/Downloads/BorcaHub/" .. path
    }
    for _, lpath in ipairs(localPaths) do
        local ok, content = pcall(function()
            if isfile and isfile(lpath) then
                return readfile(lpath)
            end
        end)
        if ok and content and #content > 10 then
            local fn, loadErr = loadstring(content)
            if fn then
                return fn
            end
        end
    end

    -- Try multiple raw GitHub URL variations
    local urlVariations = {
        "https://raw.githubusercontent.com/BorCaHub/BorcaHub/main/" .. path:gsub(" ", "%%20"),
        "https://raw.githubusercontent.com/BorCaHub/BorcaHub/master/" .. path:gsub(" ", "%%20"),
        "https://raw.githubusercontent.com/borcahub/BorcaHub/main/" .. path:gsub(" ", "%%20")
    }

    local lastErr = "No connection"
    for _, url in ipairs(urlVariations) do
        local ok, source = pcall(function()
            return game:HttpGet(url)
        end)
        if ok and source and #source > 10 and not source:find("404: Not Found") then
            local fn, loadErr = loadstring(source)
            if fn then
                return fn
            else
                lastErr = "Loadstring error: " .. tostring(loadErr)
            end
        end
    end

    return nil, "Failed to download: " .. path .. " (Error: " .. lastErr .. ")"
end

local SafeLoadFromGitHub = SafeLoad

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
