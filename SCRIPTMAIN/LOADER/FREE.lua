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
--  EMERGENCY ERROR UI HELPER
-- ================================================================

local function ShowEmergencyUI(title, message)
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name           = "BorcaHub_EmergencyUI"
    ScreenGui.ResetOnSpawn   = false
    ScreenGui.DisplayOrder   = 99999
    ScreenGui.IgnoreGuiInset = true

    local ok = false
    if not ok then ok = pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end) end
    if not ok then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    -- Overlay background
    local Overlay = Instance.new("Frame", ScreenGui)
    Overlay.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
    Overlay.BackgroundTransparency = 0.5
    Overlay.Size                   = UDim2.new(1, 0, 1, 0)

    -- Container card
    local Card = Instance.new("Frame", Overlay)
    Card.BackgroundColor3 = Color3.fromRGB(18, 18, 27)
    Card.AnchorPoint      = Vector2.new(0.5, 0.5)
    Card.Position         = UDim2.new(0.5, 0, 0.5, 0)
    Card.Size             = UDim2.new(0, 420, 0, 240)
    Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 10)
    local Stroke = Instance.new("UIStroke", Card)
    Stroke.Color     = Color3.fromRGB(255, 75, 75)
    Stroke.Thickness = 1.6

    -- Title
    local TxtTitle = Instance.new("TextLabel", Card)
    TxtTitle.BackgroundTransparency = 1
    TxtTitle.Position   = UDim2.new(0, 20, 0, 15)
    TxtTitle.Size       = UDim2.new(1, -40, 0, 24)
    TxtTitle.Text       = "⚠️  " .. title
    TxtTitle.TextColor3 = Color3.fromRGB(255, 75, 75)
    TxtTitle.TextSize   = 16
    TxtTitle.Font       = Enum.Font.GothamBold
    TxtTitle.TextXAlignment = Enum.TextXAlignment.Left

    -- Error Message Display
    local ErrorBg = Instance.new("Frame", Card)
    ErrorBg.BackgroundColor3 = Color3.fromRGB(28, 24, 24)
    ErrorBg.Position         = UDim2.new(0.05, 0, 0, 50)
    ErrorBg.Size             = UDim2.new(0.9, 0, 0, 120)
    Instance.new("UICorner", ErrorBg).CornerRadius = UDim.new(0, 6)
    local ErrorStroke = Instance.new("UIStroke", ErrorBg)
    ErrorStroke.Color     = Color3.fromRGB(80, 40, 40)
    ErrorStroke.Thickness = 1

    local TxtMsg = Instance.new("TextBox", ErrorBg)
    TxtMsg.BackgroundTransparency = 1
    TxtMsg.Position          = UDim2.new(0, 10, 0, 10)
    TxtMsg.Size              = UDim2.new(1, -20, 1, -20)
    TxtMsg.Text              = message
    TxtMsg.TextColor3        = Color3.fromRGB(240, 180, 180)
    TxtMsg.TextSize          = 12
    TxtMsg.Font              = Enum.Font.Code
    TxtMsg.TextWrapped       = true
    TxtMsg.ClearTextOnFocus  = false
    TxtMsg.TextEditable      = false
    TxtMsg.TextXAlignment    = Enum.TextXAlignment.Left
    TxtMsg.TextYAlignment    = Enum.TextYAlignment.Top

    -- Close Button
    local CloseBtn = Instance.new("TextButton", Card)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 75, 75)
    CloseBtn.Position         = UDim2.new(0.5, -60, 0, 190)
    CloseBtn.Size             = UDim2.new(0, 120, 0, 32)
    CloseBtn.Text             = "Dismiss UI"
    CloseBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    CloseBtn.TextSize         = 13
    CloseBtn.Font             = Enum.Font.GothamBold
    Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

    CloseBtn.MouseButton1Click:Connect(function()
        ScreenGui:Destroy()
    end)
end

-- ================================================================
--  STEP 1: DETECT GAME
-- ================================================================

print("[BorcaHub] Free Loader v0.0.1 – Starting...")

local CheckGameID
local CheckGameFn, cgErr = SafeLoadFromGitHub("SCRIPTMAIN/SCRIPTS/CHECKGAMEID.lua")
local detectMethod = "Online Detection"

if CheckGameFn then
    local checkOk, checkRes = pcall(CheckGameFn)
    if checkOk and checkRes then
        CheckGameID = checkRes
    else
        cgErr = tostring(checkRes or "Execution failed")
    end
end

if not CheckGameID then
    warn("[BorcaHub] Failed to load CheckGameID online: " .. tostring(cgErr) .. " - Activating offline fallback detection...")
    detectMethod = "Offline Fallback"
    CheckGameID = {
        GetGameEntry = function()
            local db = {
                [17625359962] = { Name = "Rivals", Premium = "BorcaHub/SCRIPTMAIN/SCRIPTS/PREMIUM/RIVALS PREMIUM.lua", Free = "BorcaHub/SCRIPTMAIN/SCRIPTS/FREE/RIVALS FREE.lua" },
                [14143745658] = { Name = "Rivals (Beta)", Premium = "BorcaHub/SCRIPTMAIN/SCRIPTS/PREMIUM/RIVALS PREMIUM.lua", Free = "BorcaHub/SCRIPTMAIN/SCRIPTS/FREE/RIVALS FREE.lua" },
                [142823291] = { Name = "Murder Mystery 2", Premium = "BorcaHub/SCRIPTMAIN/SCRIPTS/PREMIUM/MM2 PREMIUM.lua", Free = "BorcaHub/SCRIPTMAIN/SCRIPTS/FREE/MM2 FREE.lua" },
                [286090429] = { Name = "Arsenal", Premium = "BorcaHub/SCRIPTMAIN/SCRIPTS/PREMIUM/ARSENAL PREMIUM.lua", Free = "BorcaHub/SCRIPTMAIN/SCRIPTS/FREE/ARSENAL FREE.lua" },
                [5765960238] = { Name = "Arsenal (Test Place)", Premium = "BorcaHub/SCRIPTMAIN/SCRIPTS/PREMIUM/ARSENAL PREMIUM.lua", Free = "BorcaHub/SCRIPTMAIN/SCRIPTS/FREE/ARSENAL FREE.lua" }
            }
            local entry = db[game.PlaceId]
            if entry then
                return entry, "Offline PlaceId"
            end
            return {
                Name = "Universal (Offline Fallback)",
                Premium = "BorcaHub/SCRIPTMAIN/SCRIPTS/PREMIUM/UNIVERSAL PREMIUM.lua",
                Free = "BorcaHub/SCRIPTMAIN/SCRIPTS/FREE/UNIVERSAL FREE.lua"
            }, "Offline Fallback"
        end
    end
end

local gameEntry, methodUsed = CheckGameID.GetGameEntry()
if detectMethod == "Offline Fallback" then
    methodUsed = "Offline Fallback (" .. methodUsed .. ")"
end
print("[BorcaHub] Game detected: " .. gameEntry.Name .. " (Method: " .. methodUsed .. ")")

-- ================================================================
--  STEP 2: LOAD FREE SCRIPT
-- ================================================================

local scriptPath = gameEntry.Free
if not scriptPath then
    local errMsg = "No Free script path configured for detected game: " .. gameEntry.Name
    warn("[BorcaHub] " .. errMsg)
    ShowEmergencyUI("Configuration Error", errMsg)
    return
end

-- Strip the "BorcaHub/" prefix for GitHub raw URL
local gitPath = scriptPath:gsub("^BorcaHub/", "")

print("[BorcaHub] Loading Free script: " .. gitPath)

local scriptFn, scriptErr = SafeLoadFromGitHub(gitPath)

if not scriptFn then
    warn("[BorcaHub] Failed to load main script: " .. tostring(scriptErr) .. " - Falling back to Universal...")
    local universalPath = "SCRIPTMAIN/SCRIPTS/FREE/UNIVERSAL FREE.lua"
    local fallbackFn, fallbackErr = SafeLoadFromGitHub(universalPath)
    if fallbackFn then
        scriptFn = fallbackFn
        print("[BorcaHub] Universal Free script fallback loaded successfully.")
    else
        local criticalErr = "Failed to load main script:\n" .. tostring(scriptErr) .. "\n\nFailed to load Universal fallback:\n" .. tostring(fallbackErr)
        warn("[BorcaHub] CRITICAL LOAD ERROR:\n" .. criticalErr)
        ShowEmergencyUI("BorcaHub - Connection / Load Error", criticalErr)
        return
    end
end

local execOk, execErr = pcall(scriptFn)
if execOk then
    print("[BorcaHub] Free script loaded successfully for: " .. gameEntry.Name)
else
    local runErr = "Script execution error: " .. tostring(execErr)
    warn("[BorcaHub] " .. runErr)
    ShowEmergencyUI("BorcaHub - Execution Error", runErr)
end
