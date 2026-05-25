--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║    BorcaHub  •  ScriptMain / Scripts / Free / Universal.lua  ║
    ║                                                              ║
    ║  Universal feature set for FREE tier users.                  ║
    ║  These features work across all supported games.             ║
    ║                                                              ║
    ║  Exposed API (returned table):                               ║
    ║    FreeScript.Features   — { flagName → FeatureObject }      ║
    ║    FreeScript:RegisterUI(Lib, Win) — hooks UI callbacks       ║
    ║    FreeScript:Destroy()  — clean up all connections          ║
    ╚══════════════════════════════════════════════════════════════╝
--]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local StarterGui       = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

-- ================================================================
--  MODULE
-- ================================================================

local FreeScript = {
    Features     = {},   -- populated after RegisterUI
    _connections = {},
    _highlights  = {},
    _lib         = nil,
    _win         = nil,
}

-- ================================================================
--  UTILITY HELPERS
-- ================================================================

local function GetCharacter()
    return LocalPlayer.Character
end

local function GetHumanoid(char)
    char = char or GetCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function GetRootPart(char)
    char = char or GetCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function Track(conn)
    table.insert(FreeScript._connections, conn)
    return conn
end

-- ================================================================
--  FEATURE: FULLBRIGHT
-- ================================================================

local OriginalBrightness = game:GetService("Lighting").GlobalShadows
local OriginalAmbient = game:GetService("Lighting").Ambient
local Lighting = game:GetService("Lighting")

local function SetFullbright(enabled)
    if enabled then
        Lighting.Brightness      = 2
        Lighting.ClockTime       = 14
        Lighting.FogEnd          = 100000
        Lighting.GlobalShadows   = false
        Lighting.Ambient         = Color3.fromRGB(178, 178, 178)
        Lighting.OutdoorAmbient  = Color3.fromRGB(178, 178, 178)
    else
        Lighting.Brightness      = 1
        Lighting.ClockTime       = 14
        Lighting.FogEnd          = 100000
        Lighting.GlobalShadows   = true
        Lighting.Ambient         = OriginalAmbient
        Lighting.OutdoorAmbient  = Color3.fromRGB(128, 128, 128)
    end
end

-- ================================================================
--  FEATURE: INFINITE JUMP
-- ================================================================

local function SetInfiniteJump(enabled)
    if enabled then
        Track(UserInputService.JumpRequest:Connect(function()
            local char = GetCharacter()
            local hum  = GetHumanoid(char)
            if hum and hum:GetState() ~= Enum.HumanoidStateType.Dead then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end))
    end
    -- Connections are cleaned up wholesale via Destroy(); 
    -- toggling off fully requires a reload or a named-connection approach.
end

-- ================================================================
--  FEATURE: WALK SPEED
-- ================================================================

local DEFAULT_SPEED = 16
local _speedLoop

local function SetWalkSpeed(speed)
    if _speedLoop then
        _speedLoop:Disconnect()
        _speedLoop = nil
    end
    local function apply()
        local hum = GetHumanoid()
        if hum then hum.WalkSpeed = speed end
    end
    apply()
    _speedLoop = Track(RunService.Heartbeat:Connect(apply))
end

-- ================================================================
--  FEATURE: JUMP POWER
-- ================================================================

local DEFAULT_JUMP = 50
local _jumpLoop

local function SetJumpPower(power)
    if _jumpLoop then
        _jumpLoop:Disconnect()
        _jumpLoop = nil
    end
    local function apply()
        local hum = GetHumanoid()
        if hum then hum.JumpPower = power end
    end
    apply()
    _jumpLoop = Track(RunService.Heartbeat:Connect(apply))
end

-- ================================================================
--  FEATURE: NO CLIP
-- ================================================================

local _noclipEnabled = false
local _noclipConn

local function SetNoclip(enabled)
    _noclipEnabled = enabled
    if _noclipConn then
        _noclipConn:Disconnect()
        _noclipConn = nil
    end
    if enabled then
        _noclipConn = Track(RunService.Stepped:Connect(function()
            local char = GetCharacter()
            if not char then return end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end))
    else
        local char = GetCharacter()
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
    end
end

-- ================================================================
--  FEATURE: ESP (basic highlight-based)
-- ================================================================

local _espEnabled   = false
local _espColor     = Color3.fromRGB(255, 80, 80)
local _espTeamCheck = false
local _espLoop

local function CleanHighlights()
    for player, hl in pairs(FreeScript._highlights) do
        if hl and hl.Parent then hl:Destroy() end
        FreeScript._highlights[player] = nil
    end
end

local function UpdateESP()
    if not _espEnabled then
        CleanHighlights()
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end

        -- Team check
        if _espTeamCheck and player.Team == LocalPlayer.Team then
            if FreeScript._highlights[player] then
                FreeScript._highlights[player]:Destroy()
                FreeScript._highlights[player] = nil
            end
            continue
        end

        local char = player.Character
        if not char then continue end

        -- Create or update highlight
        local hl = FreeScript._highlights[player]
        if not hl or not hl.Parent then
            hl = Instance.new("Highlight")
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent    = char
            FreeScript._highlights[player] = hl
        end
        hl.OutlineColor    = _espColor
        hl.FillColor       = _espColor
        hl.FillTransparency = 0.85
        hl.OutlineTransparency = 0
    end

    -- Remove highlights for players who left
    for player, hl in pairs(FreeScript._highlights) do
        if not player.Parent then
            if hl and hl.Parent then hl:Destroy() end
            FreeScript._highlights[player] = nil
        end
    end
end

local function SetESP(enabled)
    _espEnabled = enabled
    if _espLoop then _espLoop:Disconnect() _espLoop = nil end
    if enabled then
        _espLoop = Track(RunService.Heartbeat:Connect(UpdateESP))
    else
        CleanHighlights()
    end
end

-- ================================================================
--  FEATURE: FOV CIRCLE  (basic camera circle indicator)
-- ================================================================

local _fovDrawing    = nil
local _fovRadius     = 90
local _fovEnabled    = false

local function SetFOVCircle(enabled, radius)
    _fovEnabled = enabled
    if radius then _fovRadius = radius end

    -- Clean up existing
    if _fovDrawing then
        pcall(function() _fovDrawing:Remove() end)
        _fovDrawing = nil
    end

    if not enabled then return end

    -- Attempt to use Drawing API (executor-specific)
    local ok, circle = pcall(function()
        local c = Drawing.new("Circle")
        c.Visible     = true
        c.Radius      = _fovRadius
        c.Color       = Color3.fromRGB(255, 255, 255)
        c.Thickness   = 1.5
        c.Filled      = false
        c.Transparency = 1
        c.Position    = Vector2.new(
            Camera.ViewportSize.X / 2,
            Camera.ViewportSize.Y / 2
        )
        return c
    end)

    if ok then
        _fovDrawing = circle
        Track(RunService.RenderStepped:Connect(function()
            if _fovEnabled and _fovDrawing then
                _fovDrawing.Position = Vector2.new(
                    Camera.ViewportSize.X / 2,
                    Camera.ViewportSize.Y / 2
                )
                _fovDrawing.Radius = _fovRadius
            end
        end))
    end
end

-- ================================================================
--  FEATURE: ANTI-AFK
-- ================================================================

local _antiAfkConn

local function SetAntiAfk(enabled)
    if _antiAfkConn then
        _antiAfkConn:Disconnect()
        _antiAfkConn = nil
    end
    if enabled then
        _antiAfkConn = Track(LocalPlayer.Idled:Connect(function()
            -- Fire a fake virtual input to reset the idle timer
            local vip = game:GetService("VirtualInputManager")
            pcall(function()
                vip:SendKeyEvent(true, Enum.KeyCode.F15, false, game)
                vip:SendKeyEvent(false, Enum.KeyCode.F15, false, game)
            end)
        end))
    end
end

-- ================================================================
--  FEATURE: CHAT SPAM BLOCK  (hide incoming spam messages)
-- ================================================================
-- Note: This is a client-side display-only filter.

local _chatFilterEnabled = false

local function SetChatFilter(enabled)
    _chatFilterEnabled = enabled
    -- Actual filtering hooks into the chat module;
    -- a light approach is to mute chat box visibility.
    pcall(function()
        local chatGui = LocalPlayer.PlayerGui:FindFirstChild("Chat")
        if chatGui then
            chatGui.Enabled = not enabled
        end
    end)
end

-- ================================================================
--  REGISTER UI  — wire all features to BorcaHub controls
-- ================================================================

function FreeScript:RegisterUI(Lib, Win)
    self._lib = Lib
    self._win = Win

    -- ── Tab: Player ──────────────────────────────────────────────
    local PlayerTab = Win:CreateTab({ Name = "Player", Icon = "👤" })

    local MoveSec = PlayerTab:CreateSection("Movement")

    MoveSec:AddSlider({
        Name      = "Walk Speed",
        Min       = 16, Max = 500, Default = 16,
        Increment = 1,  Suffix = "",
        Flag      = "WalkSpeed",
        Callback  = function(v) SetWalkSpeed(v) end,
    })

    MoveSec:AddSlider({
        Name      = "Jump Power",
        Min       = 50, Max = 500, Default = 50,
        Increment = 5,  Suffix = "",
        Flag      = "JumpPower",
        Callback  = function(v) SetJumpPower(v) end,
    })

    MoveSec:AddToggle({
        Name     = "Infinite Jump",
        Default  = false,
        Flag     = "InfiniteJump",
        Callback = function(v) SetInfiniteJump(v) end,
    })

    MoveSec:AddToggle({
        Name        = "No Clip",
        Description = "Walk through walls",
        Default     = false,
        Flag        = "NoClip",
        Callback    = function(v) SetNoclip(v) end,
    })

    MoveSec:AddButton({
        Name        = "Reset Speed",
        Description = "Restore default walk speed",
        Callback    = function()
            Lib.Flags["WalkSpeed"] = DEFAULT_SPEED
            SetWalkSpeed(DEFAULT_SPEED)
            Lib:Notify({ Title = "Player", Content = "Speed reset to default.", Type = "Info" })
        end,
    })

    local UtilSec = PlayerTab:CreateSection("Utility")

    UtilSec:AddToggle({
        Name     = "Anti-AFK",
        Default  = true,
        Flag     = "AntiAFK",
        Callback = function(v) SetAntiAfk(v) end,
    })
    SetAntiAfk(true) -- enable by default

    UtilSec:AddToggle({
        Name        = "Hide Chat",
        Description = "Mutes incoming chat on your screen",
        Default     = false,
        Flag        = "HideChat",
        Callback    = function(v) SetChatFilter(v) end,
    })

    -- ── Tab: Visual ──────────────────────────────────────────────
    local VisualTab = Win:CreateTab({ Name = "Visual", Icon = "🎨" })

    local WorldSec = VisualTab:CreateSection("World")

    WorldSec:AddToggle({
        Name     = "Fullbright",
        Default  = false,
        Flag     = "Fullbright",
        Callback = function(v) SetFullbright(v) end,
    })

    local ESPSec = VisualTab:CreateSection("ESP")

    ESPSec:AddToggle({
        Name     = "Player ESP",
        Default  = false,
        Flag     = "ESPEnabled",
        Callback = function(v) SetESP(v) end,
    })

    ESPSec:AddToggle({
        Name        = "Team Check",
        Description = "Skip teammates",
        Default     = false,
        Flag        = "ESPTeamCheck",
        Callback    = function(v) _espTeamCheck = v end,
    })

    ESPSec:AddColorPicker({
        Name     = "ESP Color",
        Default  = Color3.fromRGB(255, 80, 80),
        Flag     = "ESPColor",
        Callback = function(c)
            _espColor = c
        end,
    })

    local FOVSec = VisualTab:CreateSection("FOV Circle")

    FOVSec:AddToggle({
        Name     = "Show FOV Circle",
        Default  = false,
        Flag     = "FOVEnabled",
        Callback = function(v) SetFOVCircle(v, Lib.Flags["FOVRadius"]) end,
    })

    FOVSec:AddSlider({
        Name      = "FOV Radius",
        Min       = 20, Max = 500, Default = 90,
        Increment = 5,  Suffix = "px",
        Flag      = "FOVRadius",
        Callback  = function(v)
            _fovRadius = v
            if _fovEnabled and _fovDrawing then
                _fovDrawing.Radius = v
            end
        end,
    })

    -- ── Tab: Info ────────────────────────────────────────────────
    local InfoTab = Win:CreateTab({ Name = "Info", Icon = "ℹ" })
    local InfoSec = InfoTab:CreateSection("Script Info")

    InfoSec:AddLabel("Version:  BorcaHub Free  v1.0.0")
    InfoSec:AddLabel("Tier:  🆓  Free")
    InfoSec:AddSeparator()
    InfoSec:AddLabel("Discord:  discord.gg/borcahub")
    InfoSec:AddLabel("Upgrade at:  borcahub.xyz/premium")
    InfoSec:AddSeparator()

    InfoSec:AddButton({
        Name     = "Copy Discord Link",
        Callback = function()
            pcall(function()
                setclipboard("discord.gg/borcahub")
            end)
            Lib:Notify({ Title = "Copied!", Content = "Discord link copied to clipboard.", Type = "Success" })
        end,
    })

    InfoSec:AddButton({
        Name        = "Reset All Settings",
        Description = "Restores all features to default state",
        Callback    = function()
            SetWalkSpeed(DEFAULT_SPEED)
            SetJumpPower(DEFAULT_JUMP)
            SetNoclip(false)
            SetESP(false)
            SetFullbright(false)
            SetFOVCircle(false)
            SetAntiAfk(true)
            Lib:Notify({ Title = "Reset", Content = "All settings restored to default.", Type = "Warning" })
        end,
    })

    -- Populate feature map for external access
    self.Features = {
        WalkSpeed   = { Set = SetWalkSpeed,   Flag = "WalkSpeed"   },
        JumpPower   = { Set = SetJumpPower,   Flag = "JumpPower"   },
        Noclip      = { Set = SetNoclip,      Flag = "NoClip"      },
        InfiniteJump= { Set = SetInfiniteJump,Flag = "InfiniteJump"},
        ESP         = { Set = SetESP,         Flag = "ESPEnabled"  },
        Fullbright  = { Set = SetFullbright,  Flag = "Fullbright"  },
        FOVCircle   = { Set = SetFOVCircle,   Flag = "FOVEnabled"  },
        AntiAFK     = { Set = SetAntiAfk,     Flag = "AntiAFK"     },
    }
end

-- ================================================================
--  DESTROY
-- ================================================================

function FreeScript:Destroy()
    for _, conn in ipairs(self._connections) do
        pcall(function() conn:Disconnect() end)
    end
    self._connections = {}

    CleanHighlights()
    SetFOVCircle(false)

    print("[FreeScript] Cleaned up.")
end

return FreeScript
