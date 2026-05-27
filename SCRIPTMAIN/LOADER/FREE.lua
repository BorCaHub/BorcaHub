--[[
    ╔═══════════════════════════════════════════════════════════════╗
    ║          BorcaHub  •  ScriptMain / Loader / Free.lua         ║
    ║  Free Loader – No Key Required + Game Detection + Execute    ║
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
