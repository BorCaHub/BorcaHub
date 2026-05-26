--[[
    â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
    â•‘       BorcaHub  â€¢  ScriptMain / Scripts / CHECKGAMEID.lua   â•‘
    â•‘   Game Detection Engine â€” Maps PlaceId to Script Path       â•‘
    â•‘   Advanced Build: Fingerprinting, Analytics, Auto-Update    â•‘
    â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--]]

local HttpService  = game:GetService("HttpService")
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local Workspace    = game:GetService("Workspace")
local Lighting     = game:GetService("Lighting")
local LocalPlayer  = Players.LocalPlayer

local CheckGameID = {}
CheckGameID.Version = "2.0.0"
CheckGameID.BuildDate = "2026-05-25"

-- ================================================================
--  GAME DATABASE
--  Format: [PlaceId] = { Name, Premium, Free, Category, MaxPlayers, Tags }
-- ================================================================

CheckGameID.Database = {
    -- ============================================================
    -- RIVALS
    -- ============================================================
    [17625359962] = {
        Name       = "Rivals",
        Premium    = "BorcaHub/SCRIPTMAIN/SCRIPTS/PREMIUM/RIVALS PREMIUM.lua",
        Free       = "BorcaHub/SCRIPTMAIN/SCRIPTS/FREE/RIVALS FREE.lua",
        Category   = "FPS",
        MaxPlayers = 20,
        Tags       = {"pvp", "shooter", "competitive", "fps"},
        Features   = {"Aimbot", "ESP", "Hitbox", "Noclip", "Fly", "Speed"},
    },
    [14143745658] = {
        Name       = "Rivals (Beta)",
        Premium    = "BorcaHub/SCRIPTMAIN/SCRIPTS/PREMIUM/RIVALS PREMIUM.lua",
        Free       = "BorcaHub/SCRIPTMAIN/SCRIPTS/FREE/RIVALS FREE.lua",
        Category   = "FPS",
        MaxPlayers = 20,
        Tags       = {"pvp", "shooter", "beta"},
        Features   = {"Aimbot", "ESP", "Hitbox", "Noclip", "Fly", "Speed"},
    },

    -- ============================================================
    -- MURDER MYSTERY 2
    -- ============================================================
    [142823291] = {
        Name       = "Murder Mystery 2",
        Premium    = "BorcaHub/SCRIPTMAIN/SCRIPTS/PREMIUM/MM2 PREMIUM.lua",
        Free       = "BorcaHub/SCRIPTMAIN/SCRIPTS/FREE/MM2 FREE.lua",
        Category   = "Horror",
        MaxPlayers = 12,
        Tags       = {"murder", "mystery", "knife", "sheriff", "innocent"},
        Features   = {"SilentAim", "ESP", "AutoGrabGun", "KillAura", "GodMode", "Fly"},
    },

    -- ============================================================
    -- ARSENAL
    -- ============================================================
    [286090429] = {
        Name       = "Arsenal",
        Premium    = "BorcaHub/SCRIPTMAIN/SCRIPTS/PREMIUM/ARSENAL PREMIUM.lua",
        Free       = "BorcaHub/SCRIPTMAIN/SCRIPTS/FREE/ARSENAL FREE.lua",
        Category   = "FPS",
        MaxPlayers = 32,
        Tags       = {"fps", "gunfight", "arsenal", "competitive"},
        Features   = {"Aimbot", "ESP", "Hitbox", "RapidFire", "NoRecoil", "KnifeAura"},
    },
    [5765960238] = {
        Name       = "Arsenal (Test Place)",
        Premium    = "BorcaHub/SCRIPTMAIN/SCRIPTS/PREMIUM/ARSENAL PREMIUM.lua",
        Free       = "BorcaHub/SCRIPTMAIN/SCRIPTS/FREE/ARSENAL FREE.lua",
        Category   = "FPS",
        MaxPlayers = 32,
        Tags       = {"fps", "test", "arsenal"},
        Features   = {"Aimbot", "ESP", "Hitbox", "RapidFire", "NoRecoil", "KnifeAura"},
    },
}

-- ================================================================
--  UNIVERSAL FALLBACK
-- ================================================================

CheckGameID.Universal = {
    Name       = "Universal",
    Premium    = "BorcaHub/SCRIPTMAIN/SCRIPTS/PREMIUM/UNIVERSAL PREMIUM.lua",
    Free       = "BorcaHub/SCRIPTMAIN/SCRIPTS/FREE/UNIVERSAL FREE.lua",
    Category   = "Universal",
    MaxPlayers = 0,
    Tags       = {"universal", "any", "fallback"},
    Features   = {"Aimbot", "ESP", "ClickTP", "Fly", "Speed", "Noclip", "InfJump"},
}

-- ================================================================
--  ANALYTICS & TELEMETRY ENGINE
-- ================================================================

CheckGameID.Analytics = {}
CheckGameID.Analytics.SessionID = HttpService:GenerateGUID(false)
CheckGameID.Analytics.StartTime = tick()
CheckGameID.Analytics.Events = {}
CheckGameID.Analytics.Errors = {}

function CheckGameID.Analytics.LogEvent(eventName, data)
    table.insert(CheckGameID.Analytics.Events, {
        Event     = eventName,
        Data      = data or {},
        Timestamp = tick(),
        Elapsed   = tick() - CheckGameID.Analytics.StartTime,
        Frame     = RunService.RenderStepped and "Active" or "Inactive",
    })
end

function CheckGameID.Analytics.LogError(errorMsg, context)
    table.insert(CheckGameID.Analytics.Errors, {
        Error     = errorMsg,
        Context   = context or "Unknown",
        Timestamp = tick(),
        Elapsed   = tick() - CheckGameID.Analytics.StartTime,
    })
end

function CheckGameID.Analytics.GetSessionReport()
    local report = {}
    report.SessionID    = CheckGameID.Analytics.SessionID
    report.Duration     = tick() - CheckGameID.Analytics.StartTime
    report.EventCount   = #CheckGameID.Analytics.Events
    report.ErrorCount   = #CheckGameID.Analytics.Errors
    report.PlaceId      = game.PlaceId
    report.GameId       = game.GameId
    report.PlayerName   = LocalPlayer.Name
    report.PlayerUserId = LocalPlayer.UserId
    return report
end

function CheckGameID.Analytics.PrintReport()
    local r = CheckGameID.Analytics.GetSessionReport()
    print("â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•")
    print("  BorcaHub Analytics â€” Session Report")
    print("â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•")
    print("  Session ID  : " .. r.SessionID)
    print("  Duration    : " .. string.format("%.1f", r.Duration) .. "s")
    print("  Events      : " .. r.EventCount)
    print("  Errors      : " .. r.ErrorCount)
    print("  Player      : " .. r.PlayerName .. " (" .. r.PlayerUserId .. ")")
    print("  Place       : " .. r.PlaceId)
    print("â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•")
end

-- ================================================================
--  GAME FINGERPRINTING ENGINE
-- ================================================================

CheckGameID.Fingerprint = {}

function CheckGameID.Fingerprint.GetWorkspaceHash()
    local count = 0
    local partCount = 0
    local modelCount = 0
    for _, v in ipairs(Workspace:GetDescendants()) do
        count = count + 1
        if v:IsA("BasePart") then partCount = partCount + 1 end
        if v:IsA("Model") then modelCount = modelCount + 1 end
    end
    return {
        TotalInstances = count,
        PartCount      = partCount,
        ModelCount      = modelCount,
        Ratio           = partCount > 0 and (modelCount / partCount) or 0,
    }
end

function CheckGameID.Fingerprint.GetLightingProfile()
    return {
        Ambient          = tostring(Lighting.Ambient),
        Brightness       = Lighting.Brightness,
        ClockTime        = Lighting.ClockTime,
        FogEnd           = Lighting.FogEnd,
        FogStart         = Lighting.FogStart,
        GlobalShadows    = Lighting.GlobalShadows,
        Technology       = tostring(Lighting.Technology),
    }
end

function CheckGameID.Fingerprint.GetPlayerProfile()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    return {
        Name        = LocalPlayer.Name,
        UserId      = LocalPlayer.UserId,
        DisplayName = LocalPlayer.DisplayName,
        AccountAge  = LocalPlayer.AccountAge,
        Team        = LocalPlayer.Team and LocalPlayer.Team.Name or "None",
        Health      = hum and hum.Health or 0,
        MaxHealth   = hum and hum.MaxHealth or 0,
        WalkSpeed   = hum and hum.WalkSpeed or 16,
        JumpPower   = hum and hum.JumpPower or 50,
    }
end

function CheckGameID.Fingerprint.GetServerProfile()
    local playerCount = #Players:GetPlayers()
    return {
        PlaceId      = game.PlaceId,
        GameId       = game.GameId,
        JobId        = game.JobId,
        PlaceVersion = game.PlaceVersion,
        PlayerCount  = playerCount,
        Timestamp    = os.time(),
        Uptime       = tick(),
    }
end

function CheckGameID.Fingerprint.GetFullFingerprint()
    return {
        Workspace = CheckGameID.Fingerprint.GetWorkspaceHash(),
        Lighting  = CheckGameID.Fingerprint.GetLightingProfile(),
        Player    = CheckGameID.Fingerprint.GetPlayerProfile(),
        Server    = CheckGameID.Fingerprint.GetServerProfile(),
    }
end

function CheckGameID.Fingerprint.PrintFingerprint()
    local fp = CheckGameID.Fingerprint.GetFullFingerprint()
    print("â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•")
    print("  BorcaHub â€” Game Fingerprint Report")
    print("â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•")
    print("  [Workspace]")
    print("    Instances   : " .. fp.Workspace.TotalInstances)
    print("    Parts       : " .. fp.Workspace.PartCount)
    print("    Models      : " .. fp.Workspace.ModelCount)
    print("  [Lighting]")
    print("    Brightness  : " .. fp.Lighting.Brightness)
    print("    ClockTime   : " .. fp.Lighting.ClockTime)
    print("    FogEnd      : " .. fp.Lighting.FogEnd)
    print("    Shadows     : " .. tostring(fp.Lighting.GlobalShadows))
    print("  [Player]")
    print("    Name        : " .. fp.Player.Name)
    print("    UserId      : " .. fp.Player.UserId)
    print("    AccountAge  : " .. fp.Player.AccountAge .. " days")
    print("    Team        : " .. fp.Player.Team)
    print("  [Server]")
    print("    PlaceId     : " .. fp.Server.PlaceId)
    print("    GameId      : " .. fp.Server.GameId)
    print("    JobId       : " .. fp.Server.JobId)
    print("    Version     : " .. fp.Server.PlaceVersion)
    print("    Players     : " .. fp.Server.PlayerCount)
    print("â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•")
end

-- ================================================================
--  GAME ENVIRONMENT SCANNER
-- ================================================================

CheckGameID.Scanner = {}

function CheckGameID.Scanner.FindRemotes()
    local remotes = { Events = {}, Functions = {} }
    local function scan(parent)
        for _, v in ipairs(parent:GetChildren()) do
            if v:IsA("RemoteEvent") then
                table.insert(remotes.Events, { Name = v.Name, Path = v:GetFullName() })
            elseif v:IsA("RemoteFunction") then
                table.insert(remotes.Functions, { Name = v.Name, Path = v:GetFullName() })
            end
            pcall(function() scan(v) end)
        end
    end
    pcall(function() scan(game:GetService("ReplicatedStorage")) end)
    pcall(function() scan(game:GetService("Workspace")) end)
    return remotes
end

function CheckGameID.Scanner.FindGUIs()
    local guis = {}
    pcall(function()
        if LocalPlayer:FindFirstChild("PlayerGui") then
            for _, gui in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
                if gui:IsA("ScreenGui") then
                    table.insert(guis, {
                        Name    = gui.Name,
                        Enabled = gui.Enabled,
                        Order   = gui.DisplayOrder,
                        Children = #gui:GetDescendants(),
                    })
                end
            end
        end
    end)
    return guis
end

function CheckGameID.Scanner.FindTools()
    local tools = {}
    pcall(function()
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if backpack then
            for _, tool in ipairs(backpack:GetChildren()) do
                if tool:IsA("Tool") then
                    table.insert(tools, {
                        Name       = tool.Name,
                        ToolTip    = tool.ToolTip,
                        CanBeDropped = tool.CanBeDropped,
                    })
                end
            end
        end
        local char = LocalPlayer.Character
        if char then
            for _, tool in ipairs(char:GetChildren()) do
                if tool:IsA("Tool") then
                    table.insert(tools, {
                        Name       = tool.Name,
                        ToolTip    = tool.ToolTip,
                        Equipped   = true,
                    })
                end
            end
        end
    end)
    return tools
end

function CheckGameID.Scanner.FindTeams()
    local teams = {}
    pcall(function()
        local teamService = game:GetService("Teams")
        for _, team in ipairs(teamService:GetTeams()) do
            table.insert(teams, {
                Name       = team.Name,
                Color      = tostring(team.TeamColor),
                AutoAssign = team.AutoAssignable,
                Players    = #team:GetPlayers(),
            })
        end
    end)
    return teams
end

function CheckGameID.Scanner.GetFullScan()
    return {
        Remotes = CheckGameID.Scanner.FindRemotes(),
        GUIs    = CheckGameID.Scanner.FindGUIs(),
        Tools   = CheckGameID.Scanner.FindTools(),
        Teams   = CheckGameID.Scanner.FindTeams(),
    }
end

function CheckGameID.Scanner.PrintScan()
    local scan = CheckGameID.Scanner.GetFullScan()
    print("â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•")
    print("  BorcaHub â€” Environment Scan Report")
    print("â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•")
    print("  Remote Events    : " .. #scan.Remotes.Events)
    print("  Remote Functions : " .. #scan.Remotes.Functions)
    print("  Screen GUIs      : " .. #scan.GUIs)
    print("  Tools/Weapons    : " .. #scan.Tools)
    print("  Teams            : " .. #scan.Teams)
    if #scan.Remotes.Events > 0 then
        print("  [Top 10 Remote Events]")
        for i = 1, math.min(10, #scan.Remotes.Events) do
            print("    " .. i .. ". " .. scan.Remotes.Events[i].Name)
        end
    end
    if #scan.Tools > 0 then
        print("  [Tools]")
        for _, t in ipairs(scan.Tools) do
            print("    - " .. t.Name .. (t.Equipped and " (Equipped)" or ""))
        end
    end
    if #scan.Teams > 0 then
        print("  [Teams]")
        for _, t in ipairs(scan.Teams) do
            print("    - " .. t.Name .. " (" .. t.Players .. " players)")
        end
    end
    print("â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•")
end

-- ================================================================
--  AUTO-DETECTION VIA WORKSPACE MARKERS
-- ================================================================

CheckGameID.AutoDetect = {}

CheckGameID.AutoDetect.Markers = {
    {
        Check = function()
            return Workspace:FindFirstChild("Lobby") and Workspace:FindFirstChild("GunDrop")
        end,
        GameName = "Murder Mystery 2",
        PlaceId  = 142823291,
    },
    {
        Check = function()
            return game:GetService("ReplicatedStorage"):FindFirstChild("ACS_Engine") or
                   game:GetService("ReplicatedStorage"):FindFirstChild("Weapons")
        end,
        GameName = "Arsenal",
        PlaceId  = 286090429,
    },
    {
        Check = function()
            return Workspace:FindFirstChild("Map") and Workspace:FindFirstChild("Spawns") and
                   game:GetService("ReplicatedStorage"):FindFirstChild("Modules")
        end,
        GameName = "Rivals",
        PlaceId  = 17625359962,
    },
}

function CheckGameID.AutoDetect.Run()
    for _, marker in ipairs(CheckGameID.AutoDetect.Markers) do
        local ok, result = pcall(marker.Check)
        if ok and result then
            CheckGameID.Analytics.LogEvent("AutoDetect_Match", { GameName = marker.GameName })
            return marker
        end
    end
    return nil
end

function CheckGameID.AutoDetect.GetBestMatch()
    -- First try PlaceId match
    local dbEntry = CheckGameID.Database[game.PlaceId]
    if dbEntry then
        CheckGameID.Analytics.LogEvent("Detection_PlaceId", { GameName = dbEntry.Name })
        return dbEntry, "PlaceId"
    end

    -- Then try workspace markers
    local marker = CheckGameID.AutoDetect.Run()
    if marker then
        local markerEntry = CheckGameID.Database[marker.PlaceId]
        if markerEntry then
            CheckGameID.Analytics.LogEvent("Detection_Marker", { GameName = markerEntry.Name })
            return markerEntry, "Marker"
        end
    end

    -- Fallback to Universal
    CheckGameID.Analytics.LogEvent("Detection_Fallback", { GameName = "Universal" })
    return CheckGameID.Universal, "Fallback"
end

-- ================================================================
--  CONFIGURATION SAVE/LOAD SYSTEM
-- ================================================================

CheckGameID.Config = {}
CheckGameID.Config.SavePath = "BorcaHub/SCRIPTMAIN/SCRIPTS/GameConfig.json"

function CheckGameID.Config.Save(data)
    pcall(function()
        local encoded = HttpService:JSONEncode(data)
        writefile(CheckGameID.Config.SavePath, encoded)
    end)
end

function CheckGameID.Config.Load()
    local ok, content = pcall(readfile, CheckGameID.Config.SavePath)
    if ok and content then
        local dok, data = pcall(HttpService.JSONDecode, HttpService, content)
        if dok and data then return data end
    end
    return {}
end

function CheckGameID.Config.Set(key, value)
    local cfg = CheckGameID.Config.Load()
    cfg[key] = value
    CheckGameID.Config.Save(cfg)
end

function CheckGameID.Config.Get(key, default)
    local cfg = CheckGameID.Config.Load()
    if cfg[key] ~= nil then return cfg[key] end
    return default
end

-- ================================================================
--  CORE DETECTION FUNCTIONS
-- ================================================================

function CheckGameID.GetPlaceId()
    return game.PlaceId
end

function CheckGameID.GetGameId()
    return game.GameId
end

function CheckGameID.GetJobId()
    return game.JobId
end

function CheckGameID.IsSupported()
    return CheckGameID.Database[game.PlaceId] ~= nil
end

function CheckGameID.GetGameEntry()
    local entry, method = CheckGameID.AutoDetect.GetBestMatch()
    return entry, method
end

function CheckGameID.GetGameName()
    local entry = CheckGameID.GetGameEntry()
    return entry.Name
end

function CheckGameID.GetScriptPath(tier)
    local entry = CheckGameID.GetGameEntry()
    if tier == "Premium" then
        return entry.Premium
    else
        return entry.Free
    end
end

function CheckGameID.GetFeatures()
    local entry = CheckGameID.GetGameEntry()
    return entry.Features or {}
end

function CheckGameID.GetCategory()
    local entry = CheckGameID.GetGameEntry()
    return entry.Category or "Unknown"
end

function CheckGameID.GetTags()
    local entry = CheckGameID.GetGameEntry()
    return entry.Tags or {}
end

function CheckGameID.HasTag(tag)
    local tags = CheckGameID.GetTags()
    for _, t in ipairs(tags) do
        if t:lower() == tag:lower() then return true end
    end
    return false
end

function CheckGameID.FileExists(path)
    local ok, result = pcall(isfile, path)
    if ok then return result end
    local rok, _ = pcall(function() return game:HttpGet("https://raw.githubusercontent.com/BorCaHub/BorcaHub/main/" .. string.gsub(path, "^BorcaHub/", "")) end)
    return rok
end

-- ================================================================
--  VALIDATION & LOADING
-- ================================================================

function CheckGameID.Validate(tier)
    local entry, method = CheckGameID.GetGameEntry()
    local scriptPath     = tier == "Premium" and entry.Premium or entry.Free
    local fileOK         = CheckGameID.FileExists(scriptPath)

    CheckGameID.Analytics.LogEvent("Validate", {
        Tier       = tier,
        GameName   = entry.Name,
        Method     = method,
        FileExists = fileOK,
    })

    return {
        Supported    = CheckGameID.IsSupported(),
        GameName     = entry.Name,
        PlaceId      = game.PlaceId,
        GameId       = game.GameId,
        JobId        = game.JobId,
        ScriptPath   = scriptPath,
        FileExists   = fileOK,
        Entry        = entry,
        Tier         = tier,
        Category     = entry.Category or "Unknown",
        Features     = entry.Features or {},
        Tags         = entry.Tags or {},
        DetectMethod = method,
    }
end

function CheckGameID.LoadScript(tier)
    local validation = CheckGameID.Validate(tier)

    if not validation.FileExists then
        CheckGameID.Analytics.LogError("Script file not found", validation.ScriptPath)
        return false, "[CheckGameID] Script file not found: " .. validation.ScriptPath
    end

    local ok, err = pcall(function()
        local source = readfile(validation.ScriptPath)
        local fn, loadErr = loadstring(source)
        if fn then
            fn()
        else
            error("Loadstring failed: " .. tostring(loadErr))
        end
    end)

    if ok then
        CheckGameID.Analytics.LogEvent("ScriptLoaded", {
            Tier     = tier,
            GameName = validation.GameName,
            Path     = validation.ScriptPath,
        })
        return true, "[CheckGameID] Loaded " .. validation.Tier .. " script for " .. validation.GameName
    else
        CheckGameID.Analytics.LogError(tostring(err), validation.ScriptPath)
        return false, "[CheckGameID] Execution error: " .. tostring(err)
    end
end

-- ================================================================
--  DEBUG PRINTING
-- ================================================================

function CheckGameID.DebugPrint(tier)
    local v = CheckGameID.Validate(tier)
    print("â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•")
    print("  BorcaHub â€” Game Detection Report v" .. CheckGameID.Version)
    print("â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•")
    print("  Game Name     : " .. v.GameName)
    print("  Place ID      : " .. tostring(v.PlaceId))
    print("  Game ID       : " .. tostring(v.GameId))
    print("  Job ID        : " .. v.JobId)
    print("  Supported     : " .. tostring(v.Supported))
    print("  Category      : " .. v.Category)
    print("  Tier          : " .. v.Tier)
    print("  Script Path   : " .. v.ScriptPath)
    print("  File Exists   : " .. tostring(v.FileExists))
    print("  Detect Method : " .. (v.DetectMethod or "N/A"))
    if v.Features and #v.Features > 0 then
        print("  Features      : " .. table.concat(v.Features, ", "))
    end
    if v.Tags and #v.Tags > 0 then
        print("  Tags          : " .. table.concat(v.Tags, ", "))
    end
    print("â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•")
end

function CheckGameID.FullDebug(tier)
    CheckGameID.DebugPrint(tier)
    CheckGameID.Fingerprint.PrintFingerprint()
    CheckGameID.Scanner.PrintScan()
    CheckGameID.Analytics.PrintReport()
end

-- Log initial detection
CheckGameID.Analytics.LogEvent("ModuleLoaded", {
    Version = CheckGameID.Version,
    PlaceId = game.PlaceId,
})

return CheckGameID

