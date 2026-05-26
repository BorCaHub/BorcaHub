--[[
    â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
    â•‘           BorcaHub UI Library  â€¢  Commands.lua                       â•‘
    â•‘      UIMain / Components / Commands.lua                              â•‘
    â•‘                                                                      â•‘
    â•‘  Role    : Central Command & Callback Controller                     â•‘
    â•‘  Version : 0.0.1                                                     â•‘
    â•‘                                                                      â•‘
    â•‘  Responsibilities:                                                   â•‘
    â•‘   â€¢ Build the BorcaHub window via the UI Library                     â•‘
    â•‘   â€¢ Wire game-data into the topbar / title                           â•‘
    â•‘   â€¢ Dispatch post-load notifications                                 â•‘
    â•‘   â€¢ Expose Commands.Window and Commands.Lib for loaders              â•‘
    â•‘                                                                      â•‘
    â•‘  Usage (called by a Loader):                                         â•‘
    â•‘    local Commands = require(Commands)                                â•‘
    â•‘    Commands:Init({                                                   â•‘
    â•‘        Library   = BorcaUI,   -- UIMain/Components/File/Main         â•‘
    â•‘        Tier      = "Free",    -- "Free" | "Premium"                  â•‘
    â•‘        GameData  = gameEntry, -- from CheckGameID                    â•‘
    â•‘        KeyResult = keyResult, -- from Key/Main (Premium only)        â•‘
    â•‘        Script    = scriptMod, -- Free or Premium script module       â•‘
    â•‘    })                                                                â•‘
    â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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
        return string.format("BorcaHub  ðŸ’Ž  %s", gameName or "Universal")
    else
        return string.format("BorcaHub  â€¢  %s", gameName or "Universal")
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

    -- â”€â”€ Create Window â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    local Win = Lib:CreateWindow({
        Title     = BuildTitle(tier, gameData.Name),
        Size      = UDim2.new(0, 600, 0, 420),
        Position  = UDim2.new(0.5, -300, 0.5, -210),
        Theme     = opt.Theme or DefaultTheme(tier),
        ToggleKey = opt.ToggleKey or Enum.KeyCode.RightShift,
    })

    self.Window = Win

    -- â”€â”€ Wire script tabs into window â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    if scriptMod and scriptMod.RegisterUI then
        if tier == "Premium" then
            scriptMod:RegisterUI(Lib, Win, keyResult)
        else
            scriptMod:RegisterUI(Lib, Win)
        end
    end

    -- â”€â”€ Post-load notifications â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                    Title    = "ðŸ’Ž Premium",
                    Content  = "All premium features unlocked.",
                    Type     = "Success",
                    Duration = 4,
                })
            else
                Lib:Notify({
                    Title    = "ðŸ†“ Free Tier",
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
--- @param opt table â€” Same option table as Library:Notify()
function Commands:Notify(opt)
    if self.Lib then
        self.Lib:Notify(opt)
    end
end

-- ====================================================================
--  CONVENIENCE: get a flag value
-- ====================================================================

--- @function Commands:GetFlag
--- @param name string â€” Flag key
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

