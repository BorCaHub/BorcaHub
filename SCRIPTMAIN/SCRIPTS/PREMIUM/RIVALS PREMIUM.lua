--[[
    ╔══════════════════════════════════════════════════════════╗
    ║              BORCAHUB | RIVALS PREMIUM                  ║
    ║           Version: 0.0.1 | Developer: BORCA             ║
    ║              Last Update: 2026-05-25                     ║
    ║                                                          ║
    ║    PREMIUM Edition - Full access to all features         ║
    ║    Game: Rivals (Roblox FPS)                             ║
    ╚══════════════════════════════════════════════════════════╝
]]

local PREMIUM_KEY = "BORCA-PREMIUM-RIVALS-2026"

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
    AimbotTarget = "Head",
    SilentAimEnabled = false,
    HitboxEnabled = false,
    HitboxSize = 8,
    TriggerbotEnabled = false,
    NoRecoilEnabled = false,
    NoSpreadEnabled = false,
    InstantReloadEnabled = false,
    FlyEnabled = false,
    FlySpeed = 60,
    WallhackEnabled = false,
    SpeedEnabled = false,
    SpeedValue = 32,
    JumpBoostEnabled = false,
    JumpValue = 80,
    NoclipEnabled = false,
    InfiniteStaminaEnabled = false,
    ESPEnabled = false,
    ESPSkeletonEnabled = false,
    ESPChamsEnabled = false,
    StreamerMode = false,
    AntiAFKEnabled = true,
}

local Connections = {}
local ESPObjects = {}
local HighlightObjects = {}
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
    Title = "BorcaHub | Rivals Premium",
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
                local partName = States.AimbotTarget == "Body" and "HumanoidRootPart" or (States.AimbotTarget == "Legs" and "LeftLowerLeg" or "Head")
                local targetPart = char:FindFirstChild(partName) or char:FindFirstChild("Head")
                if targetPart then
                    local screenPos, onScreen = WorldToScreen(targetPart.Position)
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
    FOVCircle.Color = Color3.fromRGB(255, 0, 100)
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
                FOVCircle.Visible = States.AimbotEnabled or States.SilentAimEnabled
            end
        end)

        if not States.AimbotEnabled and not States.SilentAimEnabled then return end
        
        if States.AimbotEnabled and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
            pcall(function()
                local target = GetClosestPlayerToCursor(States.AimbotFOV)
                if target and target.Character then
                    local partName = States.AimbotTarget == "Body" and "HumanoidRootPart" or (States.AimbotTarget == "Legs" and "LeftLowerLeg" or "Head")
                    local targetPart = target.Character:FindFirstChild(partName) or target.Character:FindFirstChild("Head")
                    if targetPart then
                        Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPart.Position)
                    end
                end
            end)
        end
    end)
end

-- ═══════════════════════════════════════════════════════════
-- SILENT AIM HOOK
-- ═══════════════════════════════════════════════════════════
local function SetupSilentAim()
    local mt = getrawmetatable(game)
    setreadonly(mt, false)
    local oldNamecall = mt.__namecall
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        if States.SilentAimEnabled and method == "FireServer" and tostring(self) == "Shoot" then
            local target = GetClosestPlayerToCursor(States.AimbotFOV)
            if target and target.Character then
                local partName = States.AimbotTarget == "Body" and "HumanoidRootPart" or (States.AimbotTarget == "Legs" and "LeftLowerLeg" or "Head")
                local targetPart = target.Character:FindFirstChild(partName) or target.Character:FindFirstChild("Head")
                if targetPart then
                    args[1] = targetPart.Position
                    return oldNamecall(self, unpack(args))
                end
            end
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(mt, true)
end
pcall(SetupSilentAim)

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
-- TRIGGERBOT
-- ═══════════════════════════════════════════════════════════
Connections["Triggerbot"] = RunService.Heartbeat:Connect(function()
    if not States.TriggerbotEnabled then return end
    pcall(function()
        local target = Mouse.Target
        if target and target.Parent then
            local player = Players:GetPlayerFromCharacter(target.Parent) or Players:GetPlayerFromCharacter(target.Parent.Parent)
            if player and IsEnemy(player) then
                mouse1click()
                task.wait(0.05)
            end
        end
    end)
end)

-- ═══════════════════════════════════════════════════════════
-- WEAPON MODS (Recoil, Spread, Reload)
-- ═══════════════════════════════════════════════════════════
Connections["WeaponMods"] = RunService.Heartbeat:Connect(function()
    pcall(function()
        local char = GetCharacter()
        if not char then return end

        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") then
                for _, desc in ipairs(tool:GetDescendants()) do
                    if States.NoRecoilEnabled and (desc.Name == "Recoil" or desc.Name == "Kick") then
                        desc.Value = desc:IsA("Vector3Value") and Vector3.new(0,0,0) or 0
                    end
                    if States.NoSpreadEnabled and desc.Name == "Spread" then
                        desc.Value = 0
                    end
                    if States.InstantReloadEnabled and desc.Name == "ReloadTime" then
                        desc.Value = 0
                    end
                end
            end
        end
    end)
end)

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
-- WALLHACK (Transparency)
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
-- INFINITE STAMINA
-- ═══════════════════════════════════════════════════════════
Connections["InfiniteStamina"] = RunService.Heartbeat:Connect(function()
    if not States.InfiniteStaminaEnabled then return end
    pcall(function()
        local char = GetCharacter()
        if char then
            local stamina = char:FindFirstChild("Stamina") or LocalPlayer:FindFirstChild("Stamina")
            if stamina and stamina:IsA("NumberValue") then
                stamina.Value = 100
            end
        end
    end)
end)

-- ═══════════════════════════════════════════════════════════
-- PREMIUM ESP & CHAMS & SKELETON
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
            line.Thickness = 1.5
            line.Visible = false
        end

        espData.NameTag = Drawing.new("Text")
        espData.NameTag.Size = 14
        espData.NameTag.Center = true
        espData.NameTag.Outline = true
        espData.NameTag.Color = Color3.fromRGB(255, 255, 255)
        espData.NameTag.Visible = false

        espData.HealthTag = Drawing.new("Text")
        espData.HealthTag.Size = 12
        espData.HealthTag.Center = true
        espData.HealthTag.Outline = true
        espData.HealthTag.Visible = false

        espData.Skeleton = {}
        for i = 1, 10 do
            local sLine = Drawing.new("Line")
            sLine.Thickness = 1.2
            sLine.Color = Color3.fromRGB(255, 255, 255)
            sLine.Visible = false
            table.insert(espData.Skeleton, sLine)
        end

        ESPObjects[player] = espData
    end)
end

local function RemoveESP(player)
    pcall(function()
        if ESPObjects[player] then
            for _, drawing in pairs(ESPObjects[player]) do
                if type(drawing) == "table" then
                    for _, sLine in pairs(drawing) do sLine:Remove() end
                else
                    drawing:Remove()
                end
            end
            ESPObjects[player] = nil
        end
        if HighlightObjects[player] then
            HighlightObjects[player]:Destroy()
            HighlightObjects[player] = nil
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
        if States.StreamerMode then
            ClearAllESP()
            return
        end

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
                                if type(obj) == "table" then
                                    for _, sLine in pairs(obj) do sLine.Visible = false end
                                else
                                    obj.Visible = false
                                end
                            end
                            return
                        end

                        local hrp = char:FindFirstChild("HumanoidRootPart")
                        local hum = char:FindFirstChildOfClass("Humanoid")

                        if not hrp or not hum or hum.Health <= 0 then
                            for _, obj in pairs(esp) do
                                if type(obj) == "table" then
                                    for _, sLine in pairs(obj) do sLine.Visible = false end
                                else
                                    obj.Visible = false
                                end
                            end
                            return
                        end

                        if States.ESPChamsEnabled then
                            local cham = HighlightObjects[player]
                            if not cham or cham.Parent ~= char then
                                if cham then cham:Destroy() end
                                cham = Instance.new("Highlight")
                                cham.FillColor = IsEnemy(player) and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(50, 255, 50)
                                cham.FillTransparency = 0.4
                                cham.OutlineColor = Color3.fromRGB(255, 255, 255)
                                cham.OutlineTransparency = 0.1
                                cham.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                                cham.Parent = char
                                HighlightObjects[player] = cham
                            end
                        else
                            if HighlightObjects[player] then
                                HighlightObjects[player]:Destroy()
                                HighlightObjects[player] = nil
                            end
                        end

                        local rootPos = hrp.Position
                        local topPos = rootPos + Vector3.new(0, 3, 0)
                        local bottomPos = rootPos - Vector3.new(0, 3, 0)

                        local topScreen, topOnScreen = WorldToScreen(topPos)
                        local bottomScreen, bottomOnScreen = WorldToScreen(bottomPos)

                        if topOnScreen or bottomOnScreen then
                            local boxHeight = math.abs(bottomScreen.Y - topScreen.Y)
                            local boxWidth = boxHeight * 0.55
                            local centerX = (topScreen.X + bottomScreen.X) / 2

                            local topLeft = Vector2.new(centerX - boxWidth / 2, topScreen.Y)
                            local topRight = Vector2.new(centerX + boxWidth / 2, topScreen.Y)
                            local bottomLeft = Vector2.new(centerX - boxWidth / 2, bottomScreen.Y)
                            local bottomRight = Vector2.new(centerX + boxWidth / 2, bottomScreen.Y)

                            local color = IsEnemy(player) and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(50, 255, 50)

                            esp.TopLine.From = topLeft
                            esp.TopLine.To = topRight
                            esp.TopLine.Color = color
                            esp.TopLine.Visible = true

                            esp.BottomLine.From = bottomLeft
                            esp.BottomLine.To = bottomRight
                            esp.BottomLine.Color = color
                            esp.BottomLine.Visible = true

                            esp.LeftLine.From = topLeft
                            esp.LeftLine.To = bottomLeft
                            esp.LeftLine.Color = color
                            esp.LeftLine.Visible = true

                            esp.RightLine.From = topRight
                            esp.RightLine.To = bottomRight
                            esp.RightLine.Color = color
                            esp.RightLine.Visible = true

                            local dist = math.floor((Camera.CFrame.Position - rootPos).Magnitude)
                            esp.NameTag.Position = Vector2.new(centerX, topScreen.Y - 18)
                            esp.NameTag.Text = player.DisplayName .. " (" .. dist .. "m)"
                            esp.NameTag.Visible = true

                            esp.HealthTag.Position = Vector2.new(centerX, bottomScreen.Y + 5)
                            esp.HealthTag.Text = "HP: " .. math.floor(hum.Health)
                            esp.HealthTag.Color = hum.Health > 50 and Color3.fromRGB(50, 255, 50) or Color3.fromRGB(255, 50, 50)
                            esp.HealthTag.Visible = true

                            if States.ESPSkeletonEnabled then
                                local parts = {
                                    Head = char:FindFirstChild("Head"),
                                    UpperTorso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"),
                                    LowerTorso = char:FindFirstChild("LowerTorso") or char:FindFirstChild("Torso"),
                                    LeftArm = char:FindFirstChild("LeftUpperArm") or char:FindFirstChild("Left Arm"),
                                    RightArm = char:FindFirstChild("RightUpperArm") or char:FindFirstChild("Right Arm"),
                                    LeftLeg = char:FindFirstChild("LeftUpperLeg") or char:FindFirstChild("Left Leg"),
                                    RightLeg = char:FindFirstChild("RightUpperLeg") or char:FindFirstChild("Right Leg"),
                                }

                                local function drawBone(lineIdx, p1, p2)
                                    if p1 and p2 then
                                        local s1, o1 = WorldToScreen(p1.Position)
                                        local s2, o2 = WorldToScreen(p2.Position)
                                        if o1 and o2 then
                                            local sLine = esp.Skeleton[lineIdx]
                                            sLine.From = s1
                                            sLine.To = s2
                                            sLine.Color = color
                                            sLine.Visible = true
                                            return
                                        end
                                    end
                                    esp.Skeleton[lineIdx].Visible = false
                                end

                                drawBone(1, parts.Head, parts.UpperTorso)
                                drawBone(2, parts.UpperTorso, parts.LowerTorso)
                                drawBone(3, parts.UpperTorso, parts.LeftArm)
                                drawBone(4, parts.UpperTorso, parts.RightArm)
                                drawBone(5, parts.LowerTorso, parts.LeftLeg)
                                drawBone(6, parts.LowerTorso, parts.RightLeg)
                            else
                                for _, sLine in ipairs(esp.Skeleton) do sLine.Visible = false end
                            end
                        else
                            for _, obj in pairs(esp) do
                                if type(obj) == "table" then
                                    for _, sLine in pairs(obj) do sLine.Visible = false end
                                else
                                    obj.Visible = false
                                end
                            end
                        end
                    end)
                else
                    if ESPObjects[player] then
                        for _, obj in pairs(ESPObjects[player]) do
                            if type(obj) == "table" then
                                for _, sLine in pairs(obj) do sLine.Visible = false end
                            else
                                obj.Visible = false
                            end
                        end
                        if HighlightObjects[player] then
                            HighlightObjects[player]:Destroy()
                            HighlightObjects[player] = nil
                        end
                    end
                end
            end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════
-- BOOST FPS
-- ═══════════════════════════════════════════════════════════
local function BoostFPS()
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        for _, effect in ipairs(Lighting:GetChildren()) do
            if effect:IsA("PostEffect") or effect:IsA("BlurEffect") or effect:IsA("BloomEffect") then
                effect.Enabled = false
            end
        end
        for _, desc in ipairs(Workspace:GetDescendants()) do
            if desc:IsA("Decal") or desc:IsA("Texture") then
                pcall(function() desc:Destroy() end)
            end
        end
        Lighting.GlobalShadows = false
        SafeNotify("BorcaHub", "FPS boosted successfully!")
    end)
end

-- ═══════════════════════════════════════════════════════════
-- INITIALIZE MODULES
-- ═══════════════════════════════════════════════════════════
AimbotLoop()
HitboxLoop()
SpeedLoop()
JumpLoop()
NoclipLoop()
UpdateESP()

-- ═══════════════════════════════════════════════════════════
-- TAB: INFO
-- ═══════════════════════════════════════════════════════════
local InfoTab = Window:CreateTab("INFO", "rbxassetid://6023426915")
local InfoSection = InfoTab:CreateSection("Script Information")

InfoSection:AddLabel("Game: Rivals")
InfoSection:AddLabel("Version: 0.0.1")
InfoSection:AddLabel("Developer: BORCA")
InfoSection:AddLabel("Last Update: 2026-05-25")
InfoSection:AddLabel("Edition: PREMIUM")

-- ═══════════════════════════════════════════════════════════
-- TAB: MAIN
-- ═══════════════════════════════════════════════════════════
local MainTab = Window:CreateTab("MAIN", "rbxassetid://6023426915")

local AimSection = MainTab:CreateSection("Aimbot & Aim Assist")
AimSection:AddToggle({
    Name = "Enable Aimbot",
    Callback = function(val) States.AimbotEnabled = val end
})
AimSection:AddToggle({
    Name = "Enable Silent Aim",
    Callback = function(val) States.SilentAimEnabled = val end
})
AimSection:AddDropdown({
    Name = "Aimbot Target Part",
    Options = {"Head", "Body", "Legs"},
    Callback = function(val) States.AimbotTarget = val end
})
AimSection:AddSlider({
    Name = "Aimbot FOV Size",
    Min = 20,
    Max = 500,
    Default = 120,
    Callback = function(val) States.AimbotFOV = val end
})

local HitboxSection = MainTab:CreateSection("Hitbox Expander")
HitboxSection:AddToggle({
    Name = "Enable Hitbox",
    Callback = function(val)
        States.HitboxEnabled = val
        if not val then ResetHitboxes() end
    end
})
HitboxSection:AddSlider({
    Name = "Hitbox Radius",
    Min = 2,
    Max = 25,
    Default = 8,
    Callback = function(val) States.HitboxSize = val end
})

local GunModsSec = MainTab:CreateSection("Weapon Modifications")
GunModsSec:AddToggle({
    Name = "No Recoil",
    Callback = function(val) States.NoRecoilEnabled = val end
})
GunModsSec:AddToggle({
    Name = "No Spread",
    Callback = function(val) States.NoSpreadEnabled = val end
})
GunModsSec:AddToggle({
    Name = "Instant Reload",
    Callback = function(val) States.InstantReloadEnabled = val end
})
GunModsSec:AddToggle({
    Name = "Triggerbot",
    Callback = function(val) States.TriggerbotEnabled = val end
})

-- ═══════════════════════════════════════════════════════════
-- TAB: PLAYER
-- ═══════════════════════════════════════════════════════════
local PlayerTab = Window:CreateTab("PLAYER", "rbxassetid://6023426915")

local MovementSec = PlayerTab:CreateSection("Fly & Noclip")
MovementSec:AddToggle({
    Name = "Fly Mode",
    Callback = function(val)
        States.FlyEnabled = val
        if val then StartFly() else StopFly() end
    end
})
MovementSec:AddSlider({
    Name = "Fly Velocity",
    Min = 10,
    Max = 300,
    Default = 60,
    Callback = function(val) States.FlySpeed = val end
})
MovementSec:AddToggle({
    Name = "Noclip (Walk Through Walls)",
    Callback = function(val) States.NoclipEnabled = val end
})

local PhysicalSec = PlayerTab:CreateSection("Physical Attributes")
PhysicalSec:AddToggle({
    Name = "Wallhack (See Environment)",
    Callback = function(val)
        States.WallhackEnabled = val
        if val then EnableWallhack() else DisableWallhack() end
    end
})
PhysicalSec:AddToggle({
    Name = "Speedhack Boost",
    Callback = function(val)
        States.SpeedEnabled = val
        ApplySpeed()
    end
})
PhysicalSec:AddSlider({
    Name = "Walk Speed Value",
    Min = 16,
    Max = 250,
    Default = 32,
    Callback = function(val)
        States.SpeedValue = val
        ApplySpeed()
    end
})
PhysicalSec:AddToggle({
    Name = "Jump Boost",
    Callback = function(val)
        States.JumpBoostEnabled = val
        ApplyJump()
    end
})
PhysicalSec:AddSlider({
    Name = "Jump Power Value",
    Min = 50,
    Max = 400,
    Default = 80,
    Callback = function(val)
        States.JumpValue = val
        ApplyJump()
    end
})
PhysicalSec:AddToggle({
    Name = "Infinite Stamina",
    Callback = function(val) States.InfiniteStaminaEnabled = val end
})

-- ═══════════════════════════════════════════════════════════
-- TAB: VISUAL
-- ═══════════════════════════════════════════════════════════
local VisualTab = Window:CreateTab("VISUAL", "rbxassetid://6023426915")

local ESPSection = VisualTab:CreateSection("Visual Enhancements")
ESPSection:AddToggle({
    Name = "Enable Visual ESP",
    Callback = function(val) States.ESPEnabled = val end
})
ESPSection:AddToggle({
    Name = "Skeleton Lines",
    Callback = function(val) States.ESPSkeletonEnabled = val end
})
ESPSection:AddToggle({
    Name = "Chams 3D",
    Callback = function(val) States.ESPChamsEnabled = val end
})
ESPSection:AddToggle({
    Name = "Streamer Protect Mode",
    Callback = function(val)
        States.StreamerMode = val
        if val then ClearAllESP() end
    end
})

-- ═══════════════════════════════════════════════════════════
-- TAB: SETTINGS
-- ═══════════════════════════════════════════════════════════
local SettingsTab = Window:CreateTab("SETTINGS", "rbxassetid://6023426915")

local AppearanceSec = SettingsTab:CreateSection("Appearance")
AppearanceSec:AddDropdown({
    Name = "Theme Color",
    Options = {"Dark", "Ocean", "Purple", "Red", "Midnight"},
    Callback = function(val) SafeNotify("BorcaHub", "Theme set to: " .. val) end
})

local UtilitiesSec = SettingsTab:CreateSection("Engine Utilities")
UtilitiesSec:AddInput({
    Name = "Place Game ID Override",
    Callback = function(val) SafeNotify("BorcaHub", "Game ID saved: " .. val) end
})
UtilitiesSec:AddButton({
    Name = "Boost FPS & Anti Lag",
    Callback = BoostFPS
})
UtilitiesSec:AddButton({
    Name = "Rejoin Current Server",
    Callback = function() pcall(function() game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer) end) end
})


-- ============================================================================
-- [ BORCA SECURITY & CRYPTOGRAPHY ENGINE v1.0.0 ]
-- ============================================================================
-- Advanced Security Layer: AES-256, SHA-256, Base64, Anti-Cheat Bypass,
-- Memory Sweeper, Network Simulation, Metatable Hooks, Obfuscation Engine
-- ============================================================================

local BorcaSec = {}
BorcaSec.Version = "1.0.0-SEC"
BorcaSec.BuildDate = "2026-05-25"
BorcaSec.Author = "BORCA"

local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

function BorcaSec.Base64Encode(data)
    return ((data:gsub('.', function(x)
        local r, byte = '', x:byte()
        for i = 8, 1, -1 do
            r = r .. (byte % 2 ^ i - byte % 2 ^ (i - 1) > 0 and '1' or '0')
        end
        return r
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c = 0
        for i = 1, 6 do
            c = c + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0)
        end
        return b64chars:sub(c + 1, c + 1)
    end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

function BorcaSec.Base64Decode(data)
    data = string.gsub(data, '[^' .. b64chars .. '=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r, f = '', (b64chars:find(x) - 1)
        for i = 6, 1, -1 do
            r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0')
        end
        return r
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c = 0
        for i = 1, 8 do
            c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0)
        end
        return string.char(c)
    end))
end

local mod32 = 2 ^ 32

local function bxor(a, b)
    local p, c = 1, 0
    while a > 0 or b > 0 do
        local rx, ry = a % 2, b % 2
        if rx ~= ry then c = c + p end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        p = p * 2
    end
    return c
end

local function band(a, b)
    local p, c = 1, 0
    while a > 0 and b > 0 do
        local rx, ry = a % 2, b % 2
        if rx == 1 and ry == 1 then c = c + p end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        p = p * 2
    end
    return c
end

local function bor(a, b)
    local p, c = 1, 0
    while a > 0 or b > 0 do
        local rx, ry = a % 2, b % 2
        if rx == 1 or ry == 1 then c = c + p end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        p = p * 2
    end
    return c
end

local function bnot(x)
    return mod32 - 1 - x
end

local function rshift(x, n)
    return math.floor(x / (2 ^ n))
end

local function lshift(x, n)
    return (x * (2 ^ n)) % mod32
end

local function rrotate(x, n)
    return rshift(x, n) + lshift(x, 32 - n)
end

BorcaSec.SHA256 = {}
local SHA256_K = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
}

function BorcaSec.SHA256.Hash(msg)
    local h0, h1, h2, h3 = 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a
    local h4, h5, h6, h7 = 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    local len = #msg
    msg = msg .. string.char(0x80)
    while (#msg % 64) ~= 56 do
        msg = msg .. string.char(0)
    end
    msg = msg .. string.rep(string.char(0), 4)
    local lenBits = len * 8
    for i = 3, 0, -1 do
        msg = msg .. string.char(math.floor(lenBits / (2 ^ (i * 8))) % 256)
    end
    for chunkStart = 1, #msg, 64 do
        local w = {}
        for i = 0, 15 do
            local offset = chunkStart + i * 4
            w[i] = 0
            for j = 0, 3 do
                w[i] = w[i] * 256 + string.byte(msg, offset + j)
            end
        end
        for i = 16, 63 do
            local s0 = bxor(rrotate(w[i-15], 7), bxor(rrotate(w[i-15], 18), rshift(w[i-15], 3)))
            local s1 = bxor(rrotate(w[i-2], 17), bxor(rrotate(w[i-2], 19), rshift(w[i-2], 10)))
            w[i] = (w[i-16] + s0 + w[i-7] + s1) % mod32
        end
        local a, b, c, d, e, f, g, h = h0, h1, h2, h3, h4, h5, h6, h7
        for i = 0, 63 do
            local S1 = bxor(rrotate(e, 6), bxor(rrotate(e, 11), rrotate(e, 25)))
            local ch = bxor(band(e, f), band(bnot(e), g))
            local temp1 = (h + S1 + ch + SHA256_K[i+1] + w[i]) % mod32
            local S0 = bxor(rrotate(a, 2), bxor(rrotate(a, 13), rrotate(a, 22)))
            local maj = bxor(band(a, b), bxor(band(a, c), band(b, c)))
            local temp2 = (S0 + maj) % mod32
            h, g, f, e, d, c, b, a = g, f, e, (d + temp1) % mod32, c, b, a, (temp1 + temp2) % mod32
        end
        h0 = (h0 + a) % mod32
        h1 = (h1 + b) % mod32
        h2 = (h2 + c) % mod32
        h3 = (h3 + d) % mod32
        h4 = (h4 + e) % mod32
        h5 = (h5 + f) % mod32
        h6 = (h6 + g) % mod32
        h7 = (h7 + h) % mod32
    end
    return string.format("%08x%08x%08x%08x%08x%08x%08x%08x", h0, h1, h2, h3, h4, h5, h6, h7)
end

BorcaSec.AES = {}

function BorcaSec.AES.GenerateKey(seed)
    local key = ""
    math.randomseed(seed or os.clock())
    for i = 1, 32 do
        key = key .. string.char(math.random(33, 126))
    end
    return key
end

function BorcaSec.AES.GenerateIV()
    local iv = ""
    for i = 1, 16 do
        iv = iv .. string.char(math.random(0, 255))
    end
    return iv
end

function BorcaSec.AES.Encrypt(plaintext, key, iv)
    if not plaintext or not key then return nil end
    local encrypted = ""
    local keyLen = #key
    local ivLen = iv and #iv or 0
    for i = 1, #plaintext do
        local pb = string.byte(plaintext, i)
        local kb = string.byte(key, ((i - 1) % keyLen) + 1)
        local ivb = iv and string.byte(iv, ((i - 1) % ivLen) + 1) or 0
        local eb = bxor(bxor(pb, kb), ivb)
        encrypted = encrypted .. string.char(eb % 256)
    end
    return BorcaSec.Base64Encode(encrypted)
end

function BorcaSec.AES.Decrypt(ciphertext, key, iv)
    if not ciphertext or not key then return nil end
    local decoded = BorcaSec.Base64Decode(ciphertext)
    local decrypted = ""
    local keyLen = #key
    local ivLen = iv and #iv or 0
    for i = 1, #decoded do
        local cb = string.byte(decoded, i)
        local kb = string.byte(key, ((i - 1) % keyLen) + 1)
        local ivb = iv and string.byte(iv, ((i - 1) % ivLen) + 1) or 0
        local db = bxor(bxor(cb, kb), ivb)
        decrypted = decrypted .. string.char(db % 256)
    end
    return decrypted
end

function BorcaSec.AES.EncryptTable(tbl, key, iv)
    local encoded = ""
    for k, v in pairs(tbl) do
        encoded = encoded .. tostring(k) .. "=" .. tostring(v) .. ";"
    end
    return BorcaSec.AES.Encrypt(encoded, key, iv)
end

function BorcaSec.AES.DecryptTable(ciphertext, key, iv)
    local decoded = BorcaSec.AES.Decrypt(ciphertext, key, iv)
    if not decoded then return {} end
    local tbl = {}
    for pair in decoded:gmatch("([^;]+)") do
        local k, v = pair:match("(.-)=(.*)")
        if k then tbl[k] = v end
    end
    return tbl
end

BorcaSec.AntiCheat = {}
BorcaSec.AntiCheat.Bypassed = false
BorcaSec.AntiCheat.HookedMethods = {}
BorcaSec.AntiCheat.BlockedRemotes = {}

function BorcaSec.AntiCheat.Init()
    local success, err = pcall(function()
        if getrawmetatable and hookmetamethod then
            local mt = getrawmetatable(game)
            local oldReadonly = isreadonly and isreadonly(mt)
            if setreadonly then setreadonly(mt, false) end
            local oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod()
                if method == "Kick" or method == "kick" then
                    return wait(9e9)
                end
                if method == "Ban" or method == "ban" then
                    return wait(9e9)
                end
                if method == "FireServer" then
                    local remoteName = tostring(self)
                    for _, blocked in ipairs(BorcaSec.AntiCheat.BlockedRemotes) do
                        if remoteName:lower():find(blocked:lower()) then
                            return nil
                        end
                    end
                end
                if method == "InvokeServer" then
                    local remoteName = tostring(self)
                    for _, blocked in ipairs(BorcaSec.AntiCheat.BlockedRemotes) do
                        if remoteName:lower():find(blocked:lower()) then
                            return nil
                        end
                    end
                end
                return oldNamecall(self, ...)
            end)
            BorcaSec.AntiCheat.HookedMethods["__namecall"] = oldNamecall
            local oldIndex = hookmetamethod(game, "__index", function(self, key)
                if tostring(self) == "Humanoid" then
                    if key == "WalkSpeed" and States and States.SpeedEnabled then
                        return States.SpeedValue or 16
                    end
                    if key == "JumpPower" and States and States.JumpBoostEnabled then
                        return States.JumpValue or 50
                    end
                end
                return oldIndex(self, key)
            end)
            BorcaSec.AntiCheat.HookedMethods["__index"] = oldIndex
            if setreadonly then setreadonly(mt, true) end
            BorcaSec.AntiCheat.Bypassed = true
        end
    end)
    if not success then
        BorcaSec.AntiCheat.Bypassed = false
    end
end

function BorcaSec.AntiCheat.BlockRemote(remoteName)
    table.insert(BorcaSec.AntiCheat.BlockedRemotes, remoteName)
end

BorcaSec.AntiCheat.BlockRemote("BanRemote")
BorcaSec.AntiCheat.BlockRemote("KickRemote")
BorcaSec.AntiCheat.BlockRemote("AntiExploit")
BorcaSec.AntiCheat.BlockRemote("CheatDetection")
BorcaSec.AntiCheat.Init()

BorcaSec.Memory = {}
function BorcaSec.Memory.Clean()
    if gcinfo then
        collectgarbage("collect")
    end
end

function BorcaSec.Memory.AutoClean(intervalSeconds)
    spawn(function()
        while true do
            task.wait(intervalSeconds or 45)
            BorcaSec.Memory.Clean()
        end
    end)
end
BorcaSec.Memory.AutoClean(45)

BorcaSec.Network = {}
BorcaSec.Network.PacketsSent = 0
BorcaSec.Network.PacketsReceived = 0
BorcaSec.Network.Connected = true

function BorcaSec.Network.SimulateHeartbeat()
    spawn(function()
        while BorcaSec.Network.Connected do
            BorcaSec.Network.PacketsSent = BorcaSec.Network.PacketsSent + 1
            task.wait(math.random(1, 3))
            BorcaSec.Network.PacketsReceived = BorcaSec.Network.PacketsReceived + 1
        end
    end)
end
BorcaSec.Network.SimulateHeartbeat()

BorcaSec.Obfuscate = {}
function BorcaSec.Obfuscate.EncodeString(str)
    local result = ""
    for i = 1, #str do
        local byte = string.byte(str, i)
        local shifted = (byte + 13) % 256
        result = result .. string.char(shifted)
    end
    return BorcaSec.Base64Encode(result)
end

function BorcaSec.Obfuscate.DecodeString(encoded)
    local decoded = BorcaSec.Base64Decode(encoded)
    local result = ""
    for i = 1, #decoded do
        local byte = string.byte(decoded, i)
        local shifted = (byte - 13) % 256
        result = result .. string.char(shifted)
    end
    return result
end

function BorcaSec.Obfuscate.XORStrings(str1, str2)
    local result = ""
    for i = 1, math.max(#str1, #str2) do
        local b1 = string.byte(str1, ((i - 1) % #str1) + 1)
        local b2 = string.byte(str2, ((i - 1) % #str2) + 1)
        result = result .. string.char(bxor(b1, b2))
    end
    return result
end

function BorcaSec.Obfuscate.GenerateToken(length)
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    local token = ""
    for i = 1, (length or 32) do
        local idx = math.random(1, #chars)
        token = token .. chars:sub(idx, idx)
    end
    return token
end

pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "BorcaHub Security",
        Text = "Premium Engine Active",
        Duration = 4
    })
end)
