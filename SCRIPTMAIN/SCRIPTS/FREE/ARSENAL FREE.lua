--[[
    ╔══════════════════════════════════════════════════════════╗
    ║               BORCAHUB | ARSENAL FREE                   ║
    ║           Version: 0.0.1 | Developer: BORCA             ║
    ║              Last Update: 2026-05-25                     ║
    ║                                                          ║
    ║    FREE Edition - Reduced features vs Premium            ║
    ║    Game: Arsenal (Roblox FPS)                            ║
    ╚══════════════════════════════════════════════════════════╝
]]

-- ═══════════════════════════════════════════════════════════
-- SERVICES
-- ═══════════════════════════════════════════════════════════
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local Camera = Workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- ═══════════════════════════════════════════════════════════
-- STATE VARIABLES
-- ═══════════════════════════════════════════════════════════
local States = {
    AimbotEnabled = false,
    AimbotFOV = 120,
    HitboxEnabled = false,
    HitboxSize = 8,
    NoRecoilEnabled = false,
    FlyEnabled = false,
    FlySpeed = 60,
    WallhackEnabled = false,
    SpeedEnabled = false,
    SpeedValue = 32,
    JumpBoostEnabled = false,
    JumpValue = 80,
    NoclipEnabled = false,
    ESPEnabled = false,
    AntiAFKEnabled = true,
}

local Connections = {}
local ESPObjects = {}
local FOVCircle = nil
local FlyBody = nil
local OriginalWalkSpeed = 16
local OriginalJumpPower = 50

-- ═══════════════════════════════════════════════════════════
-- UI LIBRARY LOAD
-- ═══════════════════════════════════════════════════════════
local Library = nil
pcall(function()
    Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/BorCaHub/BorcaHub/main/UIMAIN/COMPONENTS/CORE/MAIN.lua"))()
end)

if not Library then
    warn("[BorcaHub] Failed to load UI library. Aborting.")
    return
end

local Window = Library:CreateWindow({
    Title = "BorcaHub | Arsenal Free",
    SubTitle = "v0.0.1 | Dev: BORCA"
})

-- ═══════════════════════════════════════════════════════════
-- UTILITY FUNCTIONS
-- ═══════════════════════════════════════════════════════════
local function GetCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function GetHumanoid()
    local char = GetCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function GetRootPart()
    local char = GetCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function IsAlive(player)
    local char = player and player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    return hum.Health > 0
end

local function IsEnemy(player)
    if player == LocalPlayer then return false end
    if not IsAlive(player) then return false end
    -- Check teams in Arsenal
    if player.Team and LocalPlayer.Team then
        if player.Team == LocalPlayer.Team then
            return false
        end
    end
    return true
end

local function WorldToScreen(position)
    local screenPos, onScreen = Camera:WorldToScreenPoint(position)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen, screenPos.Z
end

local function GetClosestPlayerToCursor(fov)
    local closest = nil
    local closestDist = fov
    local mousePos = Vector2.new(Mouse.X, Mouse.Y)

    for _, player in ipairs(Players:GetPlayers()) do
        if IsEnemy(player) then
            local char = player.Character
            if char then
                local head = char:FindFirstChild("Head")
                if head then
                    local screenPos, onScreen = WorldToScreen(head.Position)
                    if onScreen then
                        local dist = (screenPos - mousePos).Magnitude
                        if dist < closestDist then
                            closestDist = dist
                            closest = player
                        end
                    end
                end
            end
        end
    end
    return closest
end

local function SafeNotify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 3
        })
    end)
end

-- ═══════════════════════════════════════════════════════════
-- FOV CIRCLE (Drawing API)
-- ═══════════════════════════════════════════════════════════
pcall(function()
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Color = Color3.fromRGB(255, 255, 0)
    FOVCircle.Thickness = 1.5
    FOVCircle.Transparency = 0.8
    FOVCircle.NumSides = 64
    FOVCircle.Radius = States.AimbotFOV
    FOVCircle.Filled = false
    FOVCircle.Visible = false
end)

-- ═══════════════════════════════════════════════════════════
-- AIMBOT ENGINE
-- ═══════════════════════════════════════════════════════════
local function AimbotLoop()
    if Connections["Aimbot"] then
        Connections["Aimbot"]:Disconnect()
        Connections["Aimbot"] = nil
    end

    Connections["Aimbot"] = RunService.RenderStepped:Connect(function()
        pcall(function()
            if FOVCircle then
                FOVCircle.Position = Vector2.new(Mouse.X, Mouse.Y)
                FOVCircle.Radius = States.AimbotFOV
                FOVCircle.Visible = States.AimbotEnabled
            end
        end)

        if not States.AimbotEnabled then return end
        if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end

        pcall(function()
            local target = GetClosestPlayerToCursor(States.AimbotFOV)
            if target and target.Character then
                local head = target.Character:FindFirstChild("Head")
                if head then
                    local aimPos = head.Position
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, aimPos)
                end
            end
        end)
    end)
end

-- ═══════════════════════════════════════════════════════════
-- HITBOX EXPANSION
-- ═══════════════════════════════════════════════════════════
local function HitboxLoop()
    if Connections["Hitbox"] then
        Connections["Hitbox"]:Disconnect()
        Connections["Hitbox"] = nil
    end

    Connections["Hitbox"] = RunService.Heartbeat:Connect(function()
        if not States.HitboxEnabled then return end

        pcall(function()
            for _, player in ipairs(Players:GetPlayers()) do
                if IsEnemy(player) then
                    local char = player.Character
                    if char then
                        local head = char:FindFirstChild("Head")
                        if head then
                            head.Size = Vector3.new(States.HitboxSize, States.HitboxSize, States.HitboxSize)
                            head.Transparency = 0.5
                            head.BrickColor = BrickColor.new("Really red")
                            head.Material = Enum.Material.ForceField
                            head.CanCollide = false
                        end
                    end
                end
            end
        end)
    end)
end

local function ResetHitboxes()
    pcall(function()
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local head = player.Character:FindFirstChild("Head")
                if head then
                    head.Size = Vector3.new(1.2, 1.2, 1.2)
                    head.Transparency = 0
                    head.Material = Enum.Material.Plastic
                end
            end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════
-- NO RECOIL
-- ═══════════════════════════════════════════════════════════
local function NoRecoilLoop()
    if Connections["NoRecoil"] then
        Connections["NoRecoil"]:Disconnect()
        Connections["NoRecoil"] = nil
    end

    Connections["NoRecoil"] = RunService.RenderStepped:Connect(function()
        if not States.NoRecoilEnabled then return end

        pcall(function()
            local char = GetCharacter()
            if char then
                for _, tool in ipairs(char:GetChildren()) do
                    if tool:IsA("Tool") then
                        for _, desc in ipairs(tool:GetDescendants()) do
                            if desc:IsA("NumberValue") or desc:IsA("IntValue") then
                                local nameLower = desc.Name:lower()
                                if nameLower:find("recoil") or nameLower:find("spread") or nameLower:find("kick") then
                                    desc.Value = 0
                                end
                            end
                            if desc:IsA("Vector3Value") then
                                local nameLower = desc.Name:lower()
                                if nameLower:find("recoil") or nameLower:find("kick") then
                                    desc.Value = Vector3.new(0, 0, 0)
                                end
                            end
                        end
                    end
                end
            end
        end)
    end)
end

-- ═══════════════════════════════════════════════════════════
-- FLY SYSTEM
-- ═══════════════════════════════════════════════════════════
local function StartFly()
    pcall(function()
        local hrp = GetRootPart()
        if not hrp then return end

        if FlyBody then
            pcall(function() FlyBody:Destroy() end)
        end

        FlyBody = Instance.new("BodyVelocity")
        FlyBody.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        FlyBody.Velocity = Vector3.new(0, 0, 0)
        FlyBody.Parent = hrp

        local hum = GetHumanoid()
        if hum then
            hum.PlatformStand = true
        end

        if Connections["Fly"] then
            Connections["Fly"]:Disconnect()
        end

        Connections["Fly"] = RunService.RenderStepped:Connect(function()
            if not States.FlyEnabled then return end

            pcall(function()
                local root = GetRootPart()
                if not root or not FlyBody or not FlyBody.Parent then return end

                local direction = Vector3.new(0, 0, 0)
                local camCF = Camera.CFrame

                if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                    direction = direction + camCF.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                    direction = direction - camCF.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                    direction = direction - camCF.RightVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                    direction = direction + camCF.RightVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    direction = direction + Vector3.new(0, 1, 0)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                    direction = direction - Vector3.new(0, 1, 0)
                end

                if direction.Magnitude > 0 then
                    FlyBody.Velocity = direction.Unit * States.FlySpeed
                else
                    FlyBody.Velocity = Vector3.new(0, 0, 0)
                end

                root.CFrame = CFrame.new(root.Position, root.Position + camCF.LookVector)
            end)
        end)
    end)
end

local function StopFly()
    pcall(function()
        if Connections["Fly"] then
            Connections["Fly"]:Disconnect()
            Connections["Fly"] = nil
        end

        if FlyBody then
            FlyBody:Destroy()
            FlyBody = nil
        end

        local hum = GetHumanoid()
        if hum then
            hum.PlatformStand = false
        end
    end)
end

-- ═══════════════════════════════════════════════════════════
-- WALLHACK (Make walls semi-transparent)
-- ═══════════════════════════════════════════════════════════
local WallhackOriginals = {}

local function EnableWallhack()
    pcall(function()
        for _, part in ipairs(Workspace:GetDescendants()) do
            if part:IsA("BasePart") and not Players:GetPlayerFromCharacter(part.Parent) and not Players:GetPlayerFromCharacter(part.Parent and part.Parent.Parent) then
                if part.Transparency < 0.5 and part.Name ~= "Baseplate" and part.Name ~= "Terrain" then
                    if not WallhackOriginals[part] then
                        WallhackOriginals[part] = part.Transparency
                    end
                    part.Transparency = 0.7
                end
            end
        end
    end)
end

local function DisableWallhack()
    pcall(function()
        for part, original in pairs(WallhackOriginals) do
            if part and part.Parent then
                part.Transparency = original
            end
        end
        WallhackOriginals = {}
    end)
end

-- ═══════════════════════════════════════════════════════════
-- SPEEDHACK
-- ═══════════════════════════════════════════════════════════
local function ApplySpeed()
    pcall(function()
        local hum = GetHumanoid()
        if hum then
            if States.SpeedEnabled then
                hum.WalkSpeed = States.SpeedValue
            else
                hum.WalkSpeed = OriginalWalkSpeed
            end
        end
    end)
end

local function SpeedLoop()
    if Connections["Speed"] then
        Connections["Speed"]:Disconnect()
        Connections["Speed"] = nil
    end

    Connections["Speed"] = RunService.Heartbeat:Connect(function()
        if States.SpeedEnabled then
            pcall(function()
                local hum = GetHumanoid()
                if hum then
                    hum.WalkSpeed = States.SpeedValue
                end
            end)
        end
    end)
end

-- ═══════════════════════════════════════════════════════════
-- JUMP BOOST
-- ═══════════════════════════════════════════════════════════
local function ApplyJump()
    pcall(function()
        local hum = GetHumanoid()
        if hum then
            if States.JumpBoostEnabled then
                hum.JumpPower = States.JumpValue
                hum.UseJumpPower = true
            else
                hum.JumpPower = OriginalJumpPower
            end
        end
    end)
end

local function JumpLoop()
    if Connections["Jump"] then
        Connections["Jump"]:Disconnect()
        Connections["Jump"] = nil
    end

    Connections["Jump"] = RunService.Heartbeat:Connect(function()
        if States.JumpBoostEnabled then
            pcall(function()
                local hum = GetHumanoid()
                if hum then
                    hum.JumpPower = States.JumpValue
                    hum.UseJumpPower = true
                end
            end)
        end
    end)
end

-- ═══════════════════════════════════════════════════════════
-- NOCLIP
-- ═══════════════════════════════════════════════════════════
local function NoclipLoop()
    if Connections["Noclip"] then
        Connections["Noclip"]:Disconnect()
        Connections["Noclip"] = nil
    end

    Connections["Noclip"] = RunService.Stepped:Connect(function()
        if not States.NoclipEnabled then return end

        pcall(function()
            local char = GetCharacter()
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    end)
end

-- ═══════════════════════════════════════════════════════════
-- ESP SYSTEM (Box ESP - FREE Version)
-- ═══════════════════════════════════════════════════════════
local function CreateESPBox(player)
    if ESPObjects[player] then return end

    pcall(function()
        local espData = {}

        espData.TopLine = Drawing.new("Line")
        espData.BottomLine = Drawing.new("Line")
        espData.LeftLine = Drawing.new("Line")
        espData.RightLine = Drawing.new("Line")

        local lines = {espData.TopLine, espData.BottomLine, espData.LeftLine, espData.RightLine}
        for _, line in ipairs(lines) do
            line.Color = Color3.fromRGB(0, 255, 100)
            line.Thickness = 1.5
            line.Transparency = 1
            line.Visible = false
        end

        espData.NameTag = Drawing.new("Text")
        espData.NameTag.Color = Color3.fromRGB(255, 255, 255)
        espData.NameTag.Size = 14
        espData.NameTag.Center = true
        espData.NameTag.Outline = true
        espData.NameTag.OutlineColor = Color3.fromRGB(0, 0, 0)
        espData.NameTag.Visible = false
        espData.NameTag.Text = player.Name

        espData.HealthBarBG = Drawing.new("Line")
        espData.HealthBarBG.Color = Color3.fromRGB(40, 40, 40)
        espData.HealthBarBG.Thickness = 3
        espData.HealthBarBG.Transparency = 1
        espData.HealthBarBG.Visible = false

        espData.HealthBar = Drawing.new("Line")
        espData.HealthBar.Color = Color3.fromRGB(0, 255, 0)
        espData.HealthBar.Thickness = 2
        espData.HealthBar.Transparency = 1
        espData.HealthBar.Visible = false

        ESPObjects[player] = espData
    end)
end

local function RemoveESP(player)
    pcall(function()
        if ESPObjects[player] then
            for _, drawing in pairs(ESPObjects[player]) do
                pcall(function() drawing:Remove() end)
            end
            ESPObjects[player] = nil
        end
    end)
end

local function ClearAllESP()
    pcall(function()
        for player, _ in pairs(ESPObjects) do
            RemoveESP(player)
        end
        ESPObjects = {}
    end)
end

local function UpdateESP()
    if Connections["ESP"] then
        Connections["ESP"]:Disconnect()
        Connections["ESP"] = nil
    end

    Connections["ESP"] = RunService.RenderStepped:Connect(function()
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                if States.ESPEnabled then
                    if not ESPObjects[player] then
                        CreateESPBox(player)
                    end

                    pcall(function()
                        local esp = ESPObjects[player]
                        if not esp then return end

                        local char = player.Character
                        if not char then
                            for _, obj in pairs(esp) do
                                pcall(function() obj.Visible = false end)
                            end
                            return
                        end

                        local hrp = char:FindFirstChild("HumanoidRootPart")
                        local hum = char:FindFirstChildOfClass("Humanoid")

                        if not hrp or not hum or hum.Health <= 0 then
                            for _, obj in pairs(esp) do
                                pcall(function() obj.Visible = false end)
                            end
                            return
                        end

                        local rootPos = hrp.Position
                        local topPos = rootPos + Vector3.new(0, 3, 0)
                        local bottomPos = rootPos - Vector3.new(0, 3, 0)

                        local topScreen, topOnScreen = WorldToScreen(topPos)
                        local bottomScreen, bottomOnScreen = WorldToScreen(bottomPos)

                        if not topOnScreen and not bottomOnScreen then
                            for _, obj in pairs(esp) do
                                pcall(function() obj.Visible = false end)
                            end
                            return
                        end

                        local boxHeight = math.abs(bottomScreen.Y - topScreen.Y)
                        local boxWidth = boxHeight * 0.55

                        local centerX = (topScreen.X + bottomScreen.X) / 2

                        local topLeft = Vector2.new(centerX - boxWidth / 2, topScreen.Y)
                        local topRight = Vector2.new(centerX + boxWidth / 2, topScreen.Y)
                        local bottomLeft = Vector2.new(centerX - boxWidth / 2, bottomScreen.Y)
                        local bottomRight = Vector2.new(centerX + boxWidth / 2, bottomScreen.Y)

                        local boxColor = Color3.fromRGB(255, 50, 50)
                        if player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
                            boxColor = Color3.fromRGB(50, 255, 50)
                        end

                        esp.TopLine.From = topLeft
                        esp.TopLine.To = topRight
                        esp.TopLine.Color = boxColor
                        esp.TopLine.Visible = true

                        esp.BottomLine.From = bottomLeft
                        esp.BottomLine.To = bottomRight
                        esp.BottomLine.Color = boxColor
                        esp.BottomLine.Visible = true

                        esp.LeftLine.From = topLeft
                        esp.LeftLine.To = bottomLeft
                        esp.LeftLine.Color = boxColor
                        esp.LeftLine.Visible = true

                        esp.RightLine.From = topRight
                        esp.RightLine.To = bottomRight
                        esp.RightLine.Color = boxColor
                        esp.RightLine.Visible = true

                        esp.NameTag.Position = Vector2.new(centerX, topScreen.Y - 18)
                        esp.NameTag.Text = player.Name
                        esp.NameTag.Visible = true

                        local healthPercent = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                        local barX = centerX - boxWidth / 2 - 5

                        esp.HealthBarBG.From = Vector2.new(barX, bottomScreen.Y)
                        esp.HealthBarBG.To = Vector2.new(barX, topScreen.Y)
                        esp.HealthBarBG.Visible = true

                        local barTop = bottomScreen.Y - (boxHeight * healthPercent)
                        esp.HealthBar.From = Vector2.new(barX, bottomScreen.Y)
                        esp.HealthBar.To = Vector2.new(barX, barTop)

                        if healthPercent > 0.6 then
                            esp.HealthBar.Color = Color3.fromRGB(0, 255, 0)
                        elseif healthPercent > 0.3 then
                            esp.HealthBar.Color = Color3.fromRGB(255, 255, 0)
                        else
                            esp.HealthBar.Color = Color3.fromRGB(255, 0, 0)
                        end
                        esp.HealthBar.Visible = true
                    end)
                else
                    if ESPObjects[player] then
                        for _, obj in pairs(ESPObjects[player]) do
                            pcall(function() obj.Visible = false end)
                        end
                    end
                end
            end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════
-- ANTI-AFK
-- ═══════════════════════════════════════════════════════════
local function SetupAntiAFK()
    pcall(function()
        local VirtualUser = game:GetService("VirtualUser")
        if Connections["AntiAFK"] then
            Connections["AntiAFK"]:Disconnect()
        end
        Connections["AntiAFK"] = LocalPlayer.Idled:Connect(function()
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end)
    end)
end

-- ═══════════════════════════════════════════════════════════
-- BOOST FPS & ANTI LAG
-- ═══════════════════════════════════════════════════════════
local function BoostFPS()
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01

        for _, effect in ipairs(Lighting:GetChildren()) do
            if effect:IsA("BlurEffect") or effect:IsA("BloomEffect") or effect:IsA("SunRaysEffect") or
               effect:IsA("ColorCorrectionEffect") or effect:IsA("DepthOfFieldEffect") then
                effect.Enabled = false
            end
        end

        for _, desc in ipairs(Workspace:GetDescendants()) do
            if desc:IsA("Decal") or desc:IsA("Texture") then
                pcall(function() desc:Destroy() end)
            end
            if desc:IsA("ParticleEmitter") or desc:IsA("Trail") or desc:IsA("Beam") then
                pcall(function() desc.Enabled = false end)
            end
            if desc:IsA("Fire") or desc:IsA("Smoke") or desc:IsA("Sparkles") then
                pcall(function() desc:Destroy() end)
            end
        end

        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.Brightness = 1

        SafeNotify("BorcaHub", "FPS Boost applied!")
    end)
end

-- ═══════════════════════════════════════════════════════════
-- SERVER UTILITIES
-- ═══════════════════════════════════════════════════════════
local function RejoinServer()
    pcall(function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)
end

local function HopServer()
    pcall(function()
        local servers = HttpService:JSONDecode(
            game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")
        )
        if servers and servers.data then
            for _, server in ipairs(servers.data) do
                if server.id ~= game.JobId and server.playing < server.maxPlayers then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
                    return
                end
            end
            SafeNotify("BorcaHub", "No available servers found!")
        end
    end)
end

local function ChangeGame(placeId)
    pcall(function()
        local id = tonumber(placeId)
        if id then
            TeleportService:Teleport(id, LocalPlayer)
        else
            SafeNotify("BorcaHub", "Invalid Place ID!")
        end
    end)
end

-- ═══════════════════════════════════════════════════════════
-- INITIALIZE MODULES
-- ═══════════════════════════════════════════════════════════
AimbotLoop()
HitboxLoop()
NoRecoilLoop()
SpeedLoop()
JumpLoop()
NoclipLoop()
UpdateESP()
SetupAntiAFK()

-- ═══════════════════════════════════════════════════════════
-- TAB: INFO
-- ═══════════════════════════════════════════════════════════
local InfoTab = Window:CreateTab("INFO", "rbxassetid://6023426915")
local InfoSection = InfoTab:CreateSection("Script Information")

InfoSection:AddLabel("Game: Arsenal")
InfoSection:AddLabel("Version: 0.0.1")
InfoSection:AddLabel("Developer: BORCA")
InfoSection:AddLabel("Last Update: 2026-05-25")
InfoSection:AddLabel("Edition: FREE")
InfoSection:AddLabel("Status: Active")

local CreditsSection = InfoTab:CreateSection("Credits & Notice")
CreditsSection:AddLabel("BorcaHub - Free Edition")
CreditsSection:AddLabel("Features are limited in FREE version")
CreditsSection:AddLabel("Upgrade to Premium for full access")
CreditsSection:AddLabel("Use at your own risk!")

-- ═══════════════════════════════════════════════════════════
-- TAB: MAIN
-- ═══════════════════════════════════════════════════════════
local MainTab = Window:CreateTab("MAIN", "rbxassetid://6023426915")

local AimbotSection = MainTab:CreateSection("Aimbot")
AimbotSection:AddToggle({
    Name = "Enable Aimbot",
    Callback = function(value)
        States.AimbotEnabled = value
        if value then
            SafeNotify("BorcaHub", "Aimbot Enabled - Hold RMB to lock on")
        end
    end
})

AimbotSection:AddSlider({
    Name = "Aimbot FOV",
    Min = 20,
    Max = 500,
    Default = 120,
    Callback = function(value)
        States.AimbotFOV = value
    end
})

local HitboxSection = MainTab:CreateSection("Hitbox Expansion")
HitboxSection:AddToggle({
    Name = "Enable Hitbox Expansion",
    Callback = function(value)
        States.HitboxEnabled = value
        if not value then
            ResetHitboxes()
        end
    end
})

HitboxSection:AddSlider({
    Name = "Hitbox Size",
    Min = 2,
    Max = 20,
    Default = 8,
    Callback = function(value)
        States.HitboxSize = value
    end
})

local RecoilSection = MainTab:CreateSection("Weapon Mods")
RecoilSection:AddToggle({
    Name = "No Recoil",
    Callback = function(value)
        States.NoRecoilEnabled = value
        if value then
            SafeNotify("BorcaHub", "No Recoil Enabled")
        end
    end
})

-- ═══════════════════════════════════════════════════════════
-- TAB: PLAYER
-- ═══════════════════════════════════════════════════════════
local PlayerTab = Window:CreateTab("PLAYER", "rbxassetid://6023426915")

local FlySection = PlayerTab:CreateSection("Fly")
FlySection:AddToggle({
    Name = "Enable Fly",
    Callback = function(value)
        States.FlyEnabled = value
        if value then
            StartFly()
            SafeNotify("BorcaHub", "Fly Enabled - Use WASD + Space/Shift")
        else
            StopFly()
        end
    end
})

FlySection:AddSlider({
    Name = "Fly Speed",
    Min = 10,
    Max = 300,
    Default = 60,
    Callback = function(value)
        States.FlySpeed = value
    end
})

local WallhackSection = PlayerTab:CreateSection("Wallhack")
WallhackSection:AddToggle({
    Name = "Enable Wallhack",
    Callback = function(value)
        States.WallhackEnabled = value
        if value then
            EnableWallhack()
            SafeNotify("BorcaHub", "Wallhack Enabled")
        else
            DisableWallhack()
        end
    end
})

local SpeedSection = PlayerTab:CreateSection("Speedhack")
SpeedSection:AddToggle({
    Name = "Enable Speedhack",
    Callback = function(value)
        States.SpeedEnabled = value
        ApplySpeed()
        if value then
            SafeNotify("BorcaHub", "Speedhack Enabled")
        end
    end
})

SpeedSection:AddSlider({
    Name = "Walk Speed",
    Min = 16,
    Max = 200,
    Default = 32,
    Callback = function(value)
        States.SpeedValue = value
        if States.SpeedEnabled then
            ApplySpeed()
        end
    end
})

local JumpSection = PlayerTab:CreateSection("Jump Boost")
JumpSection:AddToggle({
    Name = "Enable Jump Boost",
    Callback = function(value)
        States.JumpBoostEnabled = value
        ApplyJump()
        if value then
            SafeNotify("BorcaHub", "Jump Boost Enabled")
        end
    end
})

JumpSection:AddSlider({
    Name = "Jump Power",
    Min = 50,
    Max = 350,
    Default = 80,
    Callback = function(value)
        States.JumpValue = value
        if States.JumpBoostEnabled then
            ApplyJump()
        end
    end
})

local NoclipSection = PlayerTab:CreateSection("Noclip")
NoclipSection:AddToggle({
    Name = "Enable Noclip",
    Callback = function(value)
        States.NoclipEnabled = value
        if value then
            SafeNotify("BorcaHub", "Noclip Enabled - Walk through walls")
        end
    end
})

-- ═══════════════════════════════════════════════════════════
-- TAB: VISUAL
-- ═══════════════════════════════════════════════════════════
local VisualTab = Window:CreateTab("VISUAL", "rbxassetid://6023426915")

local ESPSection = VisualTab:CreateSection("ESP Enhancement (Box)")
ESPSection:AddToggle({
    Name = "Enable Box ESP",
    Callback = function(value)
        States.ESPEnabled = value
        if value then
            SafeNotify("BorcaHub", "Box ESP Enabled")
        else
            for _, espData in pairs(ESPObjects) do
                for _, obj in pairs(espData) do
                    pcall(function() obj.Visible = false end)
                end
            end
        end
    end
})

ESPSection:AddLabel("Shows: Box + Name + Health Bar")
ESPSection:AddLabel("Enemies = Red | Teammates = Green")
ESPSection:AddLabel("FREE version: Box ESP only")

-- ═══════════════════════════════════════════════════════════
-- TAB: SETTINGS
-- ═══════════════════════════════════════════════════════════
local SettingsTab = Window:CreateTab("SETTINGS", "rbxassetid://6023426915")

local ThemeSection = SettingsTab:CreateSection("Appearance")
ThemeSection:AddDropdown({
    Name = "Theme",
    Options = {"Dark", "Light", "Ocean", "Purple", "Red", "Green", "Midnight"},
    Callback = function(value)
        SafeNotify("BorcaHub", "Theme changed to: " .. tostring(value))
    end
})

ThemeSection:AddDropdown({
    Name = "Language",
    Options = {"English", "Spanish", "Portuguese", "French", "German", "Turkish", "Russian", "Arabic", "Chinese", "Japanese", "Korean"},
    Callback = function(value)
        SafeNotify("BorcaHub", "Language set to: " .. tostring(value))
    end
})

local GameSection = SettingsTab:CreateSection("Game Settings")
GameSection:AddInput({
    Name = "Place Game ID",
    Callback = function(value)
        SafeNotify("BorcaHub", "Game ID set to: " .. tostring(value))
    end
})

GameSection:AddButton({
    Name = "Boost FPS & Anti Lag",
    Callback = function()
        BoostFPS()
    end
})

local ServerSection = SettingsTab:CreateSection("Server Management")
ServerSection:AddButton({
    Name = "Rejoin Server",
    Callback = function()
        RejoinServer()
    end
})

ServerSection:AddButton({
    Name = "Hop Server",
    Callback = function()
        HopServer()
    end
})

ServerSection:AddInput({
    Name = "Change Game (Place ID)",
    Callback = function(value)
        ChangeGame(value)
    end
})
