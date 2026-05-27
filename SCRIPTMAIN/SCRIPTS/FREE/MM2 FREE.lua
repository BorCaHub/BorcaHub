--[[
    BorcaHub | MM2 Free
    Game: Murder Mystery 2 (Roblox)
    Version: 0.0.1
    Developer: BORCA
    Last Update: 2026-05-25
    Type: FREE (Reduced Features)
]]

-- ═══════════════════════════════════════════════════
-- SERVICES
-- ═══════════════════════════════════════════════════
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- ═══════════════════════════════════════════════════
-- LOAD UI LIBRARY
-- ═══════════════════════════════════════════════════
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/BorCaHub/BorcaHub/main/UIMAIN/COMPONENTS/CORE/MAIN.lua"))()

-- ═══════════════════════════════════════════════════
-- STATE VARIABLES
-- ═══════════════════════════════════════════════════
local AimbotEnabled = false
local AimbotFOV = 120
local HitboxEnabled = false
local HitboxSize = 5
local AutoGrabGunEnabled = false
local FlyEnabled = false
local FlySpeed = 50
local WallhackEnabled = false
local SpeedhackEnabled = false
local SpeedValue = 16
local JumpBoostEnabled = false
local JumpValue = 50
local NoclipEnabled = false
local ESPEnabled = false
local HighlightRolesEnabled = false
local AntiAFKEnabled = true

local FlyBodyGyro = nil
local FlyBodyVelocity = nil
local FOVCircle = nil
local ESPObjects = {}
local HighlightObjects = {}
local Connections = {}

-- ═══════════════════════════════════════════════════
-- UTILITY FUNCTIONS
-- ═══════════════════════════════════════════════════
local function GetCharacter()
    local success, result = pcall(function()
        return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    end)
    if success then return result end
    return nil
end

local function GetHumanoid()
    local char = GetCharacter()
    if char then
        local success, result = pcall(function()
            return char:FindFirstChildOfClass("Humanoid")
        end)
        if success then return result end
    end
    return nil
end

local function GetRootPart()
    local char = GetCharacter()
    if char then
        local success, result = pcall(function()
            return char:FindFirstChild("HumanoidRootPart")
        end)
        if success then return result end
    end
    return nil
end

local function GetMouse()
    local success, result = pcall(function()
        return LocalPlayer:GetMouse()
    end)
    if success then return result end
    return nil
end

local function Notify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 3
        })
    end)
end

-- ═══════════════════════════════════════════════════
-- MM2 ROLE DETECTION
-- ═══════════════════════════════════════════════════
local function GetPlayerRole(player)
    local role = "Innocent"
    pcall(function()
        if player and player.Character then
            local backpack = player:FindFirstChild("Backpack")
            local character = player.Character

            local hasKnife = false
            local hasGun = false

            if backpack then
                for _, tool in pairs(backpack:GetChildren()) do
                    if tool:IsA("Tool") then
                        local toolName = tool.Name:lower()
                        if toolName == "knife" or toolName:find("knife") then
                            hasKnife = true
                        elseif toolName == "gun" or toolName == "revolver" or toolName:find("gun") then
                            hasGun = true
                        end
                    end
                end
            end

            if character then
                for _, tool in pairs(character:GetChildren()) do
                    if tool:IsA("Tool") then
                        local toolName = tool.Name:lower()
                        if toolName == "knife" or toolName:find("knife") then
                            hasKnife = true
                        elseif toolName == "gun" or toolName == "revolver" or toolName:find("gun") then
                            hasGun = true
                        end
                    end
                end
            end

            if hasKnife then
                role = "Murderer"
            elseif hasGun then
                role = "Sheriff"
            end
        end
    end)
    return role
end

local function GetRoleColor(role)
    if role == "Murderer" then
        return Color3.fromRGB(255, 0, 0)
    elseif role == "Sheriff" then
        return Color3.fromRGB(0, 100, 255)
    else
        return Color3.fromRGB(0, 255, 0)
    end
end

-- ═══════════════════════════════════════════════════
-- FOV CIRCLE (Drawing API)
-- ═══════════════════════════════════════════════════
local function CreateFOVCircle()
    pcall(function()
        if FOVCircle then
            FOVCircle:Remove()
        end
        FOVCircle = Drawing.new("Circle")
        FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        FOVCircle.Radius = AimbotFOV
        FOVCircle.Color = Color3.fromRGB(255, 255, 0)
        FOVCircle.Thickness = 1.5
        FOVCircle.Filled = false
        FOVCircle.Transparency = 0.7
        FOVCircle.NumSides = 64
        FOVCircle.Visible = false
    end)
end

local function UpdateFOVCircle()
    pcall(function()
        if FOVCircle then
            FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            FOVCircle.Radius = AimbotFOV
            FOVCircle.Visible = AimbotEnabled
        end
    end)
end

local function DestroyFOVCircle()
    pcall(function()
        if FOVCircle then
            FOVCircle:Remove()
            FOVCircle = nil
        end
    end)
end

CreateFOVCircle()

-- ═══════════════════════════════════════════════════
-- AIMBOT SYSTEM
-- ═══════════════════════════════════════════════════
local function GetClosestPlayerInFOV()
    local closestPlayer = nil
    local closestDistance = AimbotFOV

    pcall(function()
        local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local character = player.Character
                local head = character:FindFirstChild("Head")
                local humanoid = character:FindFirstChildOfClass("Humanoid")

                if head and humanoid and humanoid.Health > 0 then
                    local screenPoint, onScreen = Camera:WorldToViewportPoint(head.Position)
                    if onScreen then
                        local screenPos = Vector2.new(screenPoint.X, screenPoint.Y)
                        local distance = (screenPos - screenCenter).Magnitude

                        if distance < closestDistance then
                            closestDistance = distance
                            closestPlayer = player
                        end
                    end
                end
            end
        end
    end)

    return closestPlayer
end

Connections["Aimbot"] = RunService.RenderStepped:Connect(function()
    pcall(function()
        UpdateFOVCircle()

        if AimbotEnabled then
            if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
                local target = GetClosestPlayerInFOV()
                if target and target.Character then
                    local head = target.Character:FindFirstChild("Head")
                    if head then
                        Camera.CFrame = CFrame.new(Camera.CFrame.Position, head.Position)
                    end
                end
            end
        end
    end)
end)

-- ═══════════════════════════════════════════════════
-- HITBOX EXPANDER
-- ═══════════════════════════════════════════════════
local function ApplyHitbox()
    pcall(function()
        if HitboxEnabled then
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local head = player.Character:FindFirstChild("Head")
                    if head then
                        head.Size = Vector3.new(HitboxSize, HitboxSize, HitboxSize)
                        head.Transparency = 0.5
                        head.Color = Color3.fromRGB(255, 0, 0)
                        head.Material = Enum.Material.ForceField
                        head.CanCollide = false
                    end
                end
            end
        else
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local head = player.Character:FindFirstChild("Head")
                    if head then
                        head.Size = Vector3.new(1.2, 1.2, 1.2)
                        head.Transparency = 0
                        head.Material = Enum.Material.SmoothPlastic
                    end
                end
            end
        end
    end)
end

Connections["Hitbox"] = RunService.Heartbeat:Connect(function()
    if HitboxEnabled then
        pcall(function()
            ApplyHitbox()
        end)
    end
end)

-- ═══════════════════════════════════════════════════
-- AUTO GRAB GUN
-- ═══════════════════════════════════════════════════
Connections["AutoGrabGun"] = RunService.Heartbeat:Connect(function()
    pcall(function()
        if AutoGrabGunEnabled then
            local rootPart = GetRootPart()
            if rootPart then
                local gunDrop = Workspace:FindFirstChild("GunDrop")
                if gunDrop then
                    local dropPos = nil
                    if gunDrop:IsA("BasePart") then
                        dropPos = gunDrop.Position
                    elseif gunDrop:IsA("Model") then
                        local primary = gunDrop.PrimaryPart or gunDrop:FindFirstChildWhichIsA("BasePart")
                        if primary then
                            dropPos = primary.Position
                        end
                    end

                    if dropPos then
                        local distance = (rootPart.Position - dropPos).Magnitude
                        if distance > 15 then
                            rootPart.CFrame = CFrame.new(dropPos + Vector3.new(0, 3, 0))
                        end
                    end
                end

                for _, obj in pairs(Workspace:GetChildren()) do
                    if obj.Name == "GunDrop" or obj.Name:lower():find("gundrop") then
                        local pos = nil
                        if obj:IsA("BasePart") then
                            pos = obj.Position
                        elseif obj:IsA("Model") then
                            local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                            if part then
                                pos = part.Position
                            end
                        end

                        if pos then
                            local dist = (rootPart.Position - pos).Magnitude
                            if dist > 15 then
                                rootPart.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
                            end
                        end
                    end
                end
            end
        end
    end)
end)

-- ═══════════════════════════════════════════════════
-- FLY SYSTEM
-- ═══════════════════════════════════════════════════
local function StartFly()
    pcall(function()
        local rootPart = GetRootPart()
        local humanoid = GetHumanoid()
        if not rootPart or not humanoid then return end

        FlyBodyGyro = Instance.new("BodyGyro")
        FlyBodyGyro.P = 9e4
        FlyBodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        FlyBodyGyro.CFrame = rootPart.CFrame
        FlyBodyGyro.Parent = rootPart

        FlyBodyVelocity = Instance.new("BodyVelocity")
        FlyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
        FlyBodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        FlyBodyVelocity.Parent = rootPart

        if Connections["Fly"] then
            Connections["Fly"]:Disconnect()
        end

        Connections["Fly"] = RunService.RenderStepped:Connect(function()
            pcall(function()
                if FlyEnabled and FlyBodyGyro and FlyBodyVelocity then
                    local rp = GetRootPart()
                    if not rp then return end

                    FlyBodyGyro.CFrame = Camera.CFrame

                    local direction = Vector3.new(0, 0, 0)
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                        direction = direction + Camera.CFrame.LookVector
                    end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                        direction = direction - Camera.CFrame.LookVector
                    end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                        direction = direction - Camera.CFrame.RightVector
                    end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                        direction = direction + Camera.CFrame.RightVector
                    end
                    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                        direction = direction + Vector3.new(0, 1, 0)
                    end
                    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                        direction = direction - Vector3.new(0, 1, 0)
                    end

                    if direction.Magnitude > 0 then
                        FlyBodyVelocity.Velocity = direction.Unit * FlySpeed
                    else
                        FlyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
                    end
                end
            end)
        end)
    end)
end

local function StopFly()
    pcall(function()
        if FlyBodyGyro then
            FlyBodyGyro:Destroy()
            FlyBodyGyro = nil
        end
        if FlyBodyVelocity then
            FlyBodyVelocity:Destroy()
            FlyBodyVelocity = nil
        end
        if Connections["Fly"] then
            Connections["Fly"]:Disconnect()
            Connections["Fly"] = nil
        end
    end)
end

-- ═══════════════════════════════════════════════════
-- WALLHACK (Transparency)
-- ═══════════════════════════════════════════════════
local WallhackParts = {}

local function EnableWallhack()
    pcall(function()
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Transparency == 0 then
                local char = LocalPlayer.Character
                local isPlayerPart = false

                for _, player in pairs(Players:GetPlayers()) do
                    if player.Character and obj:IsDescendantOf(player.Character) then
                        isPlayerPart = true
                        break
                    end
                end

                if not isPlayerPart then
                    WallhackParts[obj] = obj.Transparency
                    obj.Transparency = 0.7
                end
            end
        end
    end)
end

local function DisableWallhack()
    pcall(function()
        for part, originalTransparency in pairs(WallhackParts) do
            if part and part.Parent then
                part.Transparency = originalTransparency
            end
        end
        WallhackParts = {}
    end)
end

-- ═══════════════════════════════════════════════════
-- NOCLIP SYSTEM
-- ═══════════════════════════════════════════════════
Connections["Noclip"] = RunService.Stepped:Connect(function()
    pcall(function()
        if NoclipEnabled then
            local char = GetCharacter()
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end
    end)
end)

-- ═══════════════════════════════════════════════════
-- SPEEDHACK & JUMP BOOST
-- ═══════════════════════════════════════════════════
Connections["SpeedJump"] = RunService.Heartbeat:Connect(function()
    pcall(function()
        local humanoid = GetHumanoid()
        if humanoid then
            if SpeedhackEnabled then
                humanoid.WalkSpeed = SpeedValue
            end
            if JumpBoostEnabled then
                humanoid.JumpPower = JumpValue
            end
        end
    end)
end)

-- ═══════════════════════════════════════════════════
-- ESP SYSTEM (Box ESP)
-- ═══════════════════════════════════════════════════
local function CreateESPBox(player)
    pcall(function()
        if player == LocalPlayer then return end
        if ESPObjects[player] then return end

        local espData = {}

        espData.TopLine = Drawing.new("Line")
        espData.TopLine.Thickness = 1.5
        espData.TopLine.Color = Color3.fromRGB(0, 255, 0)
        espData.TopLine.Visible = false

        espData.BottomLine = Drawing.new("Line")
        espData.BottomLine.Thickness = 1.5
        espData.BottomLine.Color = Color3.fromRGB(0, 255, 0)
        espData.BottomLine.Visible = false

        espData.LeftLine = Drawing.new("Line")
        espData.LeftLine.Thickness = 1.5
        espData.LeftLine.Color = Color3.fromRGB(0, 255, 0)
        espData.LeftLine.Visible = false

        espData.RightLine = Drawing.new("Line")
        espData.RightLine.Thickness = 1.5
        espData.RightLine.Color = Color3.fromRGB(0, 255, 0)
        espData.RightLine.Visible = false

        espData.NameTag = Drawing.new("Text")
        espData.NameTag.Size = 14
        espData.NameTag.Center = true
        espData.NameTag.Outline = true
        espData.NameTag.Color = Color3.fromRGB(255, 255, 255)
        espData.NameTag.Visible = false

        espData.RoleTag = Drawing.new("Text")
        espData.RoleTag.Size = 12
        espData.RoleTag.Center = true
        espData.RoleTag.Outline = true
        espData.RoleTag.Visible = false

        ESPObjects[player] = espData
    end)
end

local function RemoveESPBox(player)
    pcall(function()
        if ESPObjects[player] then
            for _, drawing in pairs(ESPObjects[player]) do
                drawing:Remove()
            end
            ESPObjects[player] = nil
        end
    end)
end

local function ClearAllESP()
    pcall(function()
        for player, _ in pairs(ESPObjects) do
            RemoveESPBox(player)
        end
        ESPObjects = {}
    end)
end

local function UpdateESP()
    pcall(function()
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                if not ESPObjects[player] then
                    CreateESPBox(player)
                end

                local espData = ESPObjects[player]
                if espData and player.Character then
                    local character = player.Character
                    local humanoid = character:FindFirstChildOfClass("Humanoid")
                    local rootPart = character:FindFirstChild("HumanoidRootPart")
                    local head = character:FindFirstChild("Head")

                    if humanoid and rootPart and head and humanoid.Health > 0 then
                        local role = GetPlayerRole(player)
                        local roleColor = GetRoleColor(role)

                        local topPos, topOnScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 1.5, 0))
                        local bottomPos, bottomOnScreen = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))

                        if topOnScreen and bottomOnScreen then
                            local height = math.abs(bottomPos.Y - topPos.Y)
                            local width = height * 0.6

                            local topLeft = Vector2.new(topPos.X - width / 2, topPos.Y)
                            local topRight = Vector2.new(topPos.X + width / 2, topPos.Y)
                            local bottomLeft = Vector2.new(topPos.X - width / 2, bottomPos.Y)
                            local bottomRight = Vector2.new(topPos.X + width / 2, bottomPos.Y)

                            espData.TopLine.From = topLeft
                            espData.TopLine.To = topRight
                            espData.TopLine.Color = roleColor
                            espData.TopLine.Visible = ESPEnabled

                            espData.BottomLine.From = bottomLeft
                            espData.BottomLine.To = bottomRight
                            espData.BottomLine.Color = roleColor
                            espData.BottomLine.Visible = ESPEnabled

                            espData.LeftLine.From = topLeft
                            espData.LeftLine.To = bottomLeft
                            espData.LeftLine.Color = roleColor
                            espData.LeftLine.Visible = ESPEnabled

                            espData.RightLine.From = topRight
                            espData.RightLine.To = bottomRight
                            espData.RightLine.Color = roleColor
                            espData.RightLine.Visible = ESPEnabled

                            espData.NameTag.Position = Vector2.new(topPos.X, topPos.Y - 18)
                            espData.NameTag.Text = player.DisplayName .. " [" .. player.Name .. "]"
                            espData.NameTag.Visible = ESPEnabled

                            espData.RoleTag.Position = Vector2.new(topPos.X, topPos.Y - 32)
                            espData.RoleTag.Text = role
                            espData.RoleTag.Color = roleColor
                            espData.RoleTag.Visible = ESPEnabled
                        else
                            for _, drawing in pairs(espData) do
                                drawing.Visible = false
                            end
                        end
                    else
                        for _, drawing in pairs(espData) do
                            drawing.Visible = false
                        end
                    end
                elseif espData then
                    for _, drawing in pairs(espData) do
                        drawing.Visible = false
                    end
                end
            end
        end
    end)
end

Connections["ESP"] = RunService.RenderStepped:Connect(function()
    if ESPEnabled then
        UpdateESP()
    end
end)

-- ═══════════════════════════════════════════════════
-- HIGHLIGHT ROLES SYSTEM
-- ═══════════════════════════════════════════════════
local function ApplyHighlightRoles()
    pcall(function()
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local role = GetPlayerRole(player)
                local roleColor = GetRoleColor(role)

                local existingHighlight = player.Character:FindFirstChild("BorcaHighlight")

                if HighlightRolesEnabled then
                    if not existingHighlight then
                        existingHighlight = Instance.new("Highlight")
                        existingHighlight.Name = "BorcaHighlight"
                        existingHighlight.Adornee = player.Character
                        existingHighlight.Parent = player.Character
                    end
                    existingHighlight.FillColor = roleColor
                    existingHighlight.FillTransparency = 0.5
                    existingHighlight.OutlineColor = roleColor
                    existingHighlight.OutlineTransparency = 0
                    existingHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                else
                    if existingHighlight then
                        existingHighlight:Destroy()
                    end
                end
            end
        end
    end)
end

Connections["HighlightRoles"] = RunService.Heartbeat:Connect(function()
    pcall(function()
        if HighlightRolesEnabled then
            ApplyHighlightRoles()
        end
    end)
end)

-- ═══════════════════════════════════════════════════
-- ANTI-AFK
-- ═══════════════════════════════════════════════════
pcall(function()
    local VirtualUser = game:GetService("VirtualUser")
    LocalPlayer.Idled:Connect(function()
        if AntiAFKEnabled then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end)
end)

-- ═══════════════════════════════════════════════════
-- CREATE WINDOW & TABS
-- ═══════════════════════════════════════════════════
local Window = Library:CreateWindow({
    Title = "BorcaHub | MM2 Free",
    SubTitle = "v0.0.1 | Dev: BORCA"
})

-- ═══════════════════════════════════════════════════
-- TAB: INFO
-- ═══════════════════════════════════════════════════
local InfoTab = Window:CreateTab("INFO", "rbxassetid://6023426915")
local InfoSection = InfoTab:CreateSection("Script Information")

InfoSection:AddLabel("Game: Murder Mystery 2")
InfoSection:AddLabel("Version: 0.0.1")
InfoSection:AddLabel("Type: FREE")
InfoSection:AddLabel("Developer: BORCA")
InfoSection:AddLabel("Last Update: 2026-05-25")

local CreditsSection = InfoTab:CreateSection("Credits")
CreditsSection:AddLabel("UI Library: BorcaHub Custom")
CreditsSection:AddLabel("Script: BORCA Team")
CreditsSection:AddLabel("Thank you for using BorcaHub!")

local StatusSection = InfoTab:CreateSection("Session Info")
StatusSection:AddLabel("Player: " .. LocalPlayer.Name)
StatusSection:AddLabel("Display: " .. LocalPlayer.DisplayName)
StatusSection:AddLabel("Place ID: " .. tostring(game.PlaceId))
StatusSection:AddLabel("Job ID: " .. tostring(game.JobId):sub(1, 20) .. "...")

-- ═══════════════════════════════════════════════════
-- TAB: MAIN
-- ═══════════════════════════════════════════════════
local MainTab = Window:CreateTab("MAIN", "rbxassetid://6023426915")

-- Aimbot Section
local AimbotSection = MainTab:CreateSection("Aimbot")

AimbotSection:AddToggle({
    Name = "Enable Aimbot (Hold RMB)",
    Callback = function(value)
        AimbotEnabled = value
        if FOVCircle then
            FOVCircle.Visible = value
        end
        Notify("BorcaHub", value and "Aimbot Enabled" or "Aimbot Disabled")
    end
})

AimbotSection:AddSlider({
    Name = "Aimbot FOV Radius",
    Min = 50,
    Max = 500,
    Default = 120,
    Callback = function(value)
        AimbotFOV = value
        if FOVCircle then
            FOVCircle.Radius = value
        end
    end
})

-- Hitbox Section
local HitboxSection = MainTab:CreateSection("Hitbox Expander")

HitboxSection:AddToggle({
    Name = "Enable Hitbox Expander",
    Callback = function(value)
        HitboxEnabled = value
        if not value then
            ApplyHitbox()
        end
        Notify("BorcaHub", value and "Hitbox Expander Enabled" or "Hitbox Expander Disabled")
    end
})

HitboxSection:AddSlider({
    Name = "Hitbox Size",
    Min = 2,
    Max = 20,
    Default = 5,
    Callback = function(value)
        HitboxSize = value
    end
})

-- Auto Grab Gun Section
local GrabSection = MainTab:CreateSection("Auto Grab Gun")

GrabSection:AddToggle({
    Name = "Auto Grab Dropped Gun",
    Callback = function(value)
        AutoGrabGunEnabled = value
        Notify("BorcaHub", value and "Auto Grab Gun Enabled" or "Auto Grab Gun Disabled")
    end
})

GrabSection:AddLabel("Teleports to GunDrop in Workspace")

-- ═══════════════════════════════════════════════════
-- TAB: PLAYER
-- ═══════════════════════════════════════════════════
local PlayerTab = Window:CreateTab("PLAYER", "rbxassetid://6023426915")

-- Fly Section
local FlySection = PlayerTab:CreateSection("Fly")

FlySection:AddToggle({
    Name = "Enable Fly",
    Callback = function(value)
        FlyEnabled = value
        if value then
            StartFly()
        else
            StopFly()
        end
        Notify("BorcaHub", value and "Fly Enabled" or "Fly Disabled")
    end
})

FlySection:AddSlider({
    Name = "Fly Speed",
    Min = 10,
    Max = 200,
    Default = 50,
    Callback = function(value)
        FlySpeed = value
    end
})

-- Wallhack Section
local WallhackSection = PlayerTab:CreateSection("Wallhack")

WallhackSection:AddToggle({
    Name = "Enable Wallhack",
    Callback = function(value)
        WallhackEnabled = value
        if value then
            EnableWallhack()
        else
            DisableWallhack()
        end
        Notify("BorcaHub", value and "Wallhack Enabled" or "Wallhack Disabled")
    end
})

-- Speed Section
local SpeedSection = PlayerTab:CreateSection("Speed Hack")

SpeedSection:AddToggle({
    Name = "Enable Speed Hack",
    Callback = function(value)
        SpeedhackEnabled = value
        if not value then
            pcall(function()
                local humanoid = GetHumanoid()
                if humanoid then
                    humanoid.WalkSpeed = 16
                end
            end)
        end
        Notify("BorcaHub", value and "Speed Hack Enabled" or "Speed Hack Disabled")
    end
})

SpeedSection:AddSlider({
    Name = "Walk Speed",
    Min = 16,
    Max = 200,
    Default = 16,
    Callback = function(value)
        SpeedValue = value
    end
})

-- Jump Boost Section
local JumpSection = PlayerTab:CreateSection("Jump Boost")

JumpSection:AddToggle({
    Name = "Enable Jump Boost",
    Callback = function(value)
        JumpBoostEnabled = value
        if not value then
            pcall(function()
                local humanoid = GetHumanoid()
                if humanoid then
                    humanoid.JumpPower = 50
                end
            end)
        end
        Notify("BorcaHub", value and "Jump Boost Enabled" or "Jump Boost Disabled")
    end
})

JumpSection:AddSlider({
    Name = "Jump Power",
    Min = 50,
    Max = 350,
    Default = 50,
    Callback = function(value)
        JumpValue = value
    end
})

-- Noclip Section
local NoclipSection = PlayerTab:CreateSection("Noclip")

NoclipSection:AddToggle({
    Name = "Enable Noclip",
    Callback = function(value)
        NoclipEnabled = value
        Notify("BorcaHub", value and "Noclip Enabled" or "Noclip Disabled")
    end
})

NoclipSection:AddLabel("Walk through walls and objects")

-- ═══════════════════════════════════════════════════
-- TAB: VISUAL
-- ═══════════════════════════════════════════════════
local VisualTab = Window:CreateTab("VISUAL", "rbxassetid://6023426915")

-- ESP Section
local ESPSection = VisualTab:CreateSection("ESP Enhancement")

ESPSection:AddToggle({
    Name = "Enable Box ESP",
    Callback = function(value)
        ESPEnabled = value
        if not value then
            pcall(function()
                for _, espData in pairs(ESPObjects) do
                    for _, drawing in pairs(espData) do
                        drawing.Visible = false
                    end
                end
            end)
        end
        Notify("BorcaHub", value and "Box ESP Enabled" or "Box ESP Disabled")
    end
})

ESPSection:AddLabel("Shows box around all players")
ESPSection:AddLabel("Color coded by role (R/B/G)")

-- Highlight Roles Section
local HighlightSection = VisualTab:CreateSection("Highlight Roles")

HighlightSection:AddToggle({
    Name = "Highlight Player Roles",
    Callback = function(value)
        HighlightRolesEnabled = value
        if not value then
            pcall(function()
                for _, player in pairs(Players:GetPlayers()) do
                    if player.Character then
                        local h = player.Character:FindFirstChild("BorcaHighlight")
                        if h then h:Destroy() end
                    end
                end
            end)
        end
        Notify("BorcaHub", value and "Highlight Roles Enabled" or "Highlight Roles Disabled")
    end
})

HighlightSection:AddLabel("Red = Murderer")
HighlightSection:AddLabel("Blue = Sheriff")
HighlightSection:AddLabel("Green = Innocent")

-- ═══════════════════════════════════════════════════
-- TAB: SETTINGS
-- ═══════════════════════════════════════════════════
local SettingsTab = Window:CreateTab("SETTINGS", "rbxassetid://6023426915")

-- Theme Section
local ThemeSection = SettingsTab:CreateSection("Appearance")

ThemeSection:AddDropdown({
    Name = "Theme",
    Options = {"Dark", "Light", "Midnight", "Ocean", "Blood", "Neon"},
    Callback = function(value)
        Notify("BorcaHub", "Theme set to: " .. value)
    end
})

ThemeSection:AddDropdown({
    Name = "Language",
    Options = {"English", "Spanish", "Portuguese", "French", "German", "Turkish", "Russian", "Arabic", "Japanese", "Chinese", "Korean", "Indonesian"},
    Callback = function(value)
        Notify("BorcaHub", "Language set to: " .. value)
    end
})

-- Game Section
local GameSection = SettingsTab:CreateSection("Game Settings")

GameSection:AddInput({
    Name = "Place Game ID",
    Callback = function(value)
        Notify("BorcaHub", "Game ID set: " .. tostring(value))
    end
})

-- Performance Section
local PerfSection = SettingsTab:CreateSection("Performance")

PerfSection:AddButton({
    Name = "Boost FPS & Anti Lag",
    Callback = function()
        pcall(function()
            local lighting = game:GetService("Lighting")
            lighting.GlobalShadows = false
            lighting.FogEnd = 9e9
            lighting.Brightness = 1

            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01

            for _, v in pairs(Workspace:GetDescendants()) do
                if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                    v.Enabled = false
                elseif v:IsA("Decal") or v:IsA("Texture") then
                    v.Transparency = 1
                elseif v:IsA("MeshPart") or v:IsA("Union") then
                    v.Material = Enum.Material.SmoothPlastic
                    v.Reflectance = 0
                end
            end

            if sethiddenproperty then
                pcall(function()
                    sethiddenproperty(lighting, "Technology", Enum.Technology.Compatibility)
                end)
            end

            Notify("BorcaHub", "FPS Boost & Anti Lag Applied!")
        end)
    end
})

-- Server Section
local ServerSection = SettingsTab:CreateSection("Server Management")

ServerSection:AddButton({
    Name = "Rejoin Server",
    Callback = function()
        pcall(function()
            Notify("BorcaHub", "Rejoining server...")
            task.wait(1)
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end
})

ServerSection:AddButton({
    Name = "Hop Server",
    Callback = function()
        pcall(function()
            Notify("BorcaHub", "Finding new server...")

            local servers = {}
            local success, result = pcall(function()
                local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
                return HttpService:JSONDecode(game:HttpGet(url))
            end)

            if success and result and result.data then
                for _, server in pairs(result.data) do
                    if server.playing and server.maxPlayers and server.id ~= game.JobId then
                        if server.playing < server.maxPlayers then
                            table.insert(servers, server.id)
                        end
                    end
                end
            end

            if #servers > 0 then
                local randomServer = servers[math.random(1, #servers)]
                TeleportService:TeleportToPlaceInstance(game.PlaceId, randomServer, LocalPlayer)
            else
                Notify("BorcaHub", "No available servers found!")
            end
        end)
    end
})

ServerSection:AddButton({
    Name = "Change Game",
    Callback = function()
        pcall(function()
            Notify("BorcaHub", "Use Place Game ID input above, then click here")
        end)
    end
})

-- Anti-AFK Section
local AfkSection = SettingsTab:CreateSection("Anti-AFK")

AfkSection:AddToggle({
    Name = "Anti-AFK (Default ON)",
    Callback = function(value)
        AntiAFKEnabled = value
        Notify("BorcaHub", value and "Anti-AFK Enabled" or "Anti-AFK Disabled")
    end
})

AfkSection:AddLabel("Prevents idle kick")

-- ═══════════════════════════════════════════════════
-- CLEANUP ON CHARACTER RESPAWN
-- ═══════════════════════════════════════════════════
pcall(function()
    LocalPlayer.CharacterAdded:Connect(function(character)
        pcall(function()
            task.wait(1)

            if FlyEnabled then
                StopFly()
                StartFly()
            end

            if SpeedhackEnabled then
                local humanoid = character:WaitForChild("Humanoid", 5)
                if humanoid then
                    humanoid.WalkSpeed = SpeedValue
                end
            end

            if JumpBoostEnabled then
                local humanoid = character:WaitForChild("Humanoid", 5)
                if humanoid then
                    humanoid.JumpPower = JumpValue
                end
            end
        end)
    end)
end)

-- ═══════════════════════════════════════════════════
-- PLAYER ADDED / REMOVING (ESP Cleanup)
-- ═══════════════════════════════════════════════════
pcall(function()
    Players.PlayerAdded:Connect(function(player)
        pcall(function()
            if ESPEnabled then
                CreateESPBox(player)
            end
        end)
    end)

    Players.PlayerRemoving:Connect(function(player)
        pcall(function()
            RemoveESPBox(player)
            if HighlightObjects[player] then
                HighlightObjects[player] = nil
            end
        end)
    end)
end)

-- ═══════════════════════════════════════════════════
-- INITIALIZATION COMPLETE
-- ═══════════════════════════════════════════════════
Notify("BorcaHub", "MM2 Free v0.0.1 Loaded Successfully!")
print("[BorcaHub] MM2 Free v0.0.1 | Loaded at " .. os.date("%Y-%m-%d %H:%M:%S"))
print("[BorcaHub] Developer: BORCA | Type: FREE")
print("[BorcaHub] All systems initialized.")
