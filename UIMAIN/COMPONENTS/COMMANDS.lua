--[[
    ╔══════════════════════════════════════════════════════════════════════╗
    ║           BorcaHub UI Library  •  Commands.lua                       ║
    ║      UIMain / Components / Commands.lua                              ║
    ║                                                                      ║
    ║  Role    : Central Command & Callback Controller                     ║
    ║  Version : 0.0.1                                                     ║
    ║                                                                      ║
    ║  Responsibilities:                                                   ║
    ║   • Build the BorcaHub window via the UI Library                     ║
    ║   • Wire game-data into the topbar / title                           ║
    ║   • Dispatch post-load notifications                                 ║
    ║   • Expose Commands.Window and Commands.Lib for loaders              ║
    ║                                                                      ║
    ║  Usage (called by a Loader):                                         ║
    ║    local Commands = require(Commands)                                ║
    ║    Commands:Init({                                                   ║
    ║        Library   = BorcaUI,   -- UIMain/Components/File/Main         ║
    ║        Tier      = "Free",    -- "Free" | "Premium"                  ║
    ║        GameData  = gameEntry, -- from CheckGameID                    ║
    ║        KeyResult = keyResult, -- from Key/Main (Premium only)        ║
    ║        Script    = scriptMod, -- Free or Premium script module       ║
    ║    })                                                                ║
    ╚══════════════════════════════════════════════════════════════════════╝
--]]

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- ====================================================================
--  MODULE
-- ====================================================================

local Commands = {
    Lib    = nil,
    Window = nil,
}

-- ====================================================================
--  HELPER: build window title
-- ====================================================================

local function BuildTitle(tier, gameName)
    if tier == "Premium" then
        return string.format("BorcaHub  💎  %s", gameName or "Universal")
    else
        return string.format("BorcaHub  •  %s", gameName or "Universal")
    end
end

-- ====================================================================
--  HELPER: default theme based on tier
-- ====================================================================

local function DefaultTheme(tier)
    if tier == "Premium" then
        return "Aqua"
    end
    return "Dark"
end

-- ====================================================================
--  INIT
-- ====================================================================

--[[
    Commands:Init({
        Library   = BorcaUI,
        Tier      = "Free",
        GameData  = { Name = "Blox Fruits", ... },
        KeyResult = nil,         -- only for Premium
        Script    = FreeScript,  -- or PremiumScript
    })
--]]
function Commands:Init(opt)
    opt = opt or {}

    -- FIX: Gunakan warn + return daripada error() agar tidak crash tanpa pcall
    local Lib = opt.Library
    if not Lib then
        warn("[Commands] Library required")
        return nil
    end

    local tier      = opt.Tier      or "Free"
    local gameData  = opt.GameData  or { Name = "Universal", Version = "1.0.0" }
    local keyResult = opt.KeyResult or nil
    local scriptMod = opt.Script    or nil

    -- Pastikan gameData memiliki field Version
    gameData.Version = gameData.Version or "1.0.0"

    self.Lib = Lib

    -- ── Create Window ─────────────────────────────────────────────
    local Win = Lib:CreateWindow({
        Title     = BuildTitle(tier, gameData.Name),
        Size      = UDim2.new(0, 600, 0, 420),
        Position  = UDim2.new(0.5, -300, 0.5, -210),
        Theme     = opt.Theme or DefaultTheme(tier),
        ToggleKey = opt.ToggleKey or Enum.KeyCode.RightShift,
    })

    self.Window = Win

    -- ── Wire script tabs into window ──────────────────────────────
    if scriptMod and scriptMod.RegisterUI then
        if tier == "Premium" then
            scriptMod:RegisterUI(Lib, Win, keyResult)
        else
            scriptMod:RegisterUI(Lib, Win)
        end
    end

    -- ── Post-load notifications ───────────────────────────────────
    -- FIX: Gunakan task.delay berantai daripada task.wait() di dalam task.delay
    --      untuk menghindari potensi race condition pada beberapa environment.
    task.delay(0.6, function()
        local playerName = (keyResult and keyResult.Username)
            or LocalPlayer.Name

        -- Welcome message
        Lib:Notify({
            Title    = "BorcaHub Loaded",
            Content  = string.format(
                "Welcome, %s!  Game: %s  (v%s)",
                playerName,
                gameData.Name,
                gameData.Version
            ),
            Type     = tier == "Premium" and "Success" or "Info",
            Duration = 5,
        })

        -- Tier badge notification
        task.delay(0.4, function()
            if tier == "Premium" then
                Lib:Notify({
                    Title    = "💎 Premium",
                    Content  = "All premium features unlocked.",
                    Type     = "Success",
                    Duration = 4,
                })
            else
                Lib:Notify({
                    Title    = "🆓 Free Tier",
                    Content  = "Upgrade to Premium for more features at borcahub.xyz",
                    Type     = "Info",
                    Duration = 5,
                })
            end

            -- Game-specific note (if any)
            if gameData.Note then
                task.delay(0.5, function()
                    Lib:Notify({
                        Title    = gameData.Name,
                        Content  = gameData.Note,
                        Type     = "Warning",
                        Duration = 5,
                    })
                end)
            end
        end)
    end)

    return Win
end

-- ====================================================================
--  CONVENIENCE: broadcast a notification from anywhere
-- ====================================================================

--- @function Commands:Notify
--- @param opt table — Same option table as Library:Notify()
function Commands:Notify(opt)
    if self.Lib then
        self.Lib:Notify(opt)
    end
end

-- ====================================================================
--  CONVENIENCE: get a flag value
-- ====================================================================

--- @function Commands:GetFlag
--- @param name string — Flag key
--- @return any  The current flag value, or nil.
function Commands:GetFlag(name)
    if self.Lib then
        return self.Lib:GetFlag(name)
    end
    return nil
end

-- ====================================================================
--  RETURN MODULE
-- ====================================================================
return Commands
