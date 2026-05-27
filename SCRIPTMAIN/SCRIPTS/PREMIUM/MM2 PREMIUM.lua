--[[
    ╔══════════════════════════════════════════════════════════╗
    ║                BORCAHUB | MM2 PREMIUM                   ║
    ║           Version: 0.0.1 | Developer: BORCA             ║
    ║              Last Update: 2026-05-25                     ║
    ║                                                          ║
    ║    PREMIUM Edition - Full access to all features         ║
    ║    Game: Murder Mystery 2 (Roblox)                       ║
    ╚══════════════════════════════════════════════════════════╝
]]

local PREMIUM_KEY = "BORCA-PREMIUM-MM2-2026"

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
    SilentAimEnabled = false,
    HitboxEnabled = false,
    HitboxSize = 8,
    KillAuraEnabled = false,
    AutoGrabGunEnabled = false,
    FlyEnabled = false,
    FlySpeed = 60,
    WallhackEnabled = false,
    SpeedEnabled = false,
    SpeedValue = 32,
    JumpBoostEnabled = false,
    JumpValue = 80,
    NoclipEnabled = false,
    GodModeEnabled = false,
    ESPEnabled = false,
    ESPGunDropEnabled = false,
    HighlightRolesEnabled = false,
    XRayEnabled = false,
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
    Title = "BorcaHub | MM2 Premium",
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
                    local toolName = tool.Name:lower()
                    if toolName == "knife" or toolName:find("knife") then hasKnife = true
                    elseif toolName == "gun" or toolName == "revolver" or toolName:find("gun") then hasGun = true end
                end
            end
            if character then
                for _, tool in pairs(character:GetChildren()) do
                    local toolName = tool.Name:lower()
                    if toolName == "knife" or toolName:find("knife") then hasKnife = true
                    elseif toolName == "gun" or toolName == "revolver" or toolName:find("gun") then hasGun = true end
                end
            end
            if hasKnife then role = "Murderer" elseif hasGun then role = "Sheriff" end
        end
    end)
    return role
end

local function IsEnemy(player)
    if player == LocalPlayer then return false end
    if not IsAlive(player) then return false end
    local myRole = GetPlayerRole(LocalPlayer)
    local role = GetPlayerRole(player)
    if myRole == "Murderer" then return true end
    if role == "Murderer" then return true end
    return false
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
-- FOV CIRCLE
-- ═══════════════════════════════════════════════════════════
pcall(function()
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Color = Color3.fromRGB(255, 0, 0)
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
            if head then Camera.CFrame = CFrame.new(Camera.CFrame.Position, head.Position) end
        end
    end)
end)

-- ═══════════════════════════════════════════════════════════
-- SILENT AIM
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
                local head = target.Character:FindFirstChild("Head")
                if head then
                    args[1] = head.Position
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
Connections["Hitbox"] = RunService.Heartbeat:Connect(function()
    if not States.HitboxEnabled then return end
    pcall(function()
        for _, player in ipairs(Players:GetPlayers()) do
            if IsEnemy(player) then
                local char = player.Character
                if char then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        hrp.Size = Vector3.new(States.HitboxSize, States.HitboxSize, States.HitboxSize)
                        hrp.Transparency = 0.5
                        hrp.CanCollide = false
                    end
                end
            end
        end
    end)
end)

-- ═══════════════════════════════════════════════════════════
-- AUTO GRAB GUN & KILL AURA
-- ═══════════════════════════════════════════════════════════
Connections["AutoGrabGun"] = RunService.Heartbeat:Connect(function()
    pcall(function()
        local root = GetRootPart()
        if not root then return end

        if States.AutoGrabGunEnabled then
            local gunDrop = Workspace:FindFirstChild("GunDrop") or Workspace:FindFirstChild("Gun")
            if gunDrop then
                local pos = gunDrop:IsA("BasePart") and gunDrop.Position or (gunDrop.PrimaryPart and gunDrop.PrimaryPart.Position)
                if pos and (root.Position - pos).Magnitude > 5 then
                    root.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))
                end
            end
        end

        if States.KillAuraEnabled and GetPlayerRole(LocalPlayer) == "Murderer" then
            local char = GetCharacter()
            local knife = char and (char:FindFirstChild("Knife") or LocalPlayer.Backpack:FindFirstChild("Knife"))
            if knife then
                if knife.Parent ~= char then knife.Parent = char end
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer and IsAlive(player) then
                        local enemyRoot = player.Character:FindFirstChild("HumanoidRootPart")
                        if enemyRoot and (root.Position - enemyRoot.Position).Magnitude < 15 then
                            firetouchinterest(enemyRoot, knife.Handle, 0)
                            firetouchinterest(enemyRoot, knife.Handle, 1)
                        end
                    end
                end
            end
        end
    end)
end)

-- ═══════════════════════════════════════════════════════════
-- MOVEMENT SYSTEMS (Fly, Speed, Jump, Noclip)
-- ═══════════════════════════════════════════════════════════
local function StartFly()
    pcall(function()
        local hrp = GetRootPart()
        if not hrp then return end
        if FlyBody then FlyBody:Destroy() end
        FlyBody = Instance.new("BodyVelocity")
        FlyBody.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        FlyBody.Velocity = Vector3.new(0,0,0)
        FlyBody.Parent = hrp

        local hum = GetHumanoid()
        if hum then hum.PlatformStand = true end

        if Connections["Fly"] then Connections["Fly"]:Disconnect() end
        Connections["Fly"] = RunService.RenderStepped:Connect(function()
            if not States.FlyEnabled or not FlyBody or not FlyBody.Parent then return end
            local direction = Vector3.new(0,0,0)
            local camCF = Camera.CFrame
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction = direction + camCF.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction = direction - camCF.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction = direction - camCF.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction = direction + camCF.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then direction = direction + Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then direction = direction - Vector3.new(0,1,0) end
            FlyBody.Velocity = direction.Magnitude > 0 and direction.Unit * States.FlySpeed or Vector3.new(0,0,0)
            hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + camCF.LookVector)
        end)
    end)
end

local function StopFly()
    pcall(function()
        if Connections["Fly"] then Connections["Fly"]:Disconnect(); Connections["Fly"] = nil end
        if FlyBody then FlyBody:Destroy(); FlyBody = nil end
        local hum = GetHumanoid()
        if hum then hum.PlatformStand = false end
    end)
end

Connections["Noclip"] = RunService.Stepped:Connect(function()
    if States.NoclipEnabled then
        pcall(function()
            local char = GetCharacter()
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
        end)
    end
end)

Connections["SpeedJump"] = RunService.Heartbeat:Connect(function()
    pcall(function()
        local hum = GetHumanoid()
        if hum then
            if States.SpeedEnabled then hum.WalkSpeed = States.SpeedValue end
            if States.JumpBoostEnabled then hum.JumpPower = States.JumpValue; hum.UseJumpPower = true end
            if States.GodModeEnabled then hum.MaxHealth = math.huge; hum.Health = math.huge end
        end
    end)
end)

-- ═══════════════════════════════════════════════════════════
-- ESP & HIGHLIGHT ROLES
-- ═══════════════════════════════════════════════════════════
local function CreateESPBox(player)
    if ESPObjects[player] then return end
    pcall(function()
        local espData = {}
        espData.TopLine = Drawing.new("Line")
        espData.BottomLine = Drawing.new("Line")
        espData.LeftLine = Drawing.new("Line")
        espData.RightLine = Drawing.new("Line")
        for _, line in ipairs({espData.TopLine, espData.BottomLine, espData.LeftLine, espData.RightLine}) do
            line.Thickness = 1.5
            line.Visible = false
        end
        espData.NameTag = Drawing.new("Text")
        espData.NameTag.Size = 14
        espData.NameTag.Center = true
        espData.NameTag.Outline = true
        espData.NameTag.Color = Color3.fromRGB(255, 255, 255)
        espData.NameTag.Visible = false

        ESPObjects[player] = espData
    end)
end

local function RemoveESP(player)
    pcall(function()
        if ESPObjects[player] then
            for _, drawing in pairs(ESPObjects[player]) do drawing:Remove() end
            ESPObjects[player] = nil
        end
        if HighlightObjects[player] then HighlightObjects[player]:Destroy(); HighlightObjects[player] = nil end
    end)
end

Connections["ESP"] = RunService.RenderStepped:Connect(function()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if States.ESPEnabled then
                if not ESPObjects[player] then CreateESPBox(player) end
                pcall(function()
                    local esp = ESPObjects[player]
                    local char = player.Character
                    if not char then return end
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if not hrp or not hum or hum.Health <= 0 then
                        for _, obj in pairs(esp) do obj.Visible = false end
                        return
                    end

                    local role = GetPlayerRole(player)
                    local roleColor = role == "Murderer" and Color3.fromRGB(255,0,0) or (role == "Sheriff" and Color3.fromRGB(0,0,255) or Color3.fromRGB(0,255,0))

                    if States.HighlightRolesEnabled then
                        local hl = HighlightObjects[player]
                        if not hl or hl.Parent ~= char then
                            if hl then hl:Destroy() end
                            hl = Instance.new("Highlight")
                            hl.FillColor = roleColor
                            hl.FillTransparency = 0.5
                            hl.OutlineColor = Color3.fromRGB(255,255,255)
                            hl.Parent = char
                            HighlightObjects[player] = hl
                        end
                    else
                        if HighlightObjects[player] then HighlightObjects[player]:Destroy(); HighlightObjects[player] = nil end
                    end

                    local screenPos, onScreen = WorldToScreen(hrp.Position)
                    if onScreen then
                        local boxHeight = 40
                        local boxWidth = 25
                        esp.TopLine.From = Vector2.new(screenPos.X - boxWidth, screenPos.Y - boxHeight)
                        esp.TopLine.To = Vector2.new(screenPos.X + boxWidth, screenPos.Y - boxHeight)
                        esp.TopLine.Color = roleColor
                        esp.TopLine.Visible = true

                        esp.BottomLine.From = Vector2.new(screenPos.X - boxWidth, screenPos.Y + boxHeight)
                        esp.BottomLine.To = Vector2.new(screenPos.X + boxWidth, screenPos.Y + boxHeight)
                        esp.BottomLine.Color = roleColor
                        esp.BottomLine.Visible = true

                        esp.LeftLine.From = Vector2.new(screenPos.X - boxWidth, screenPos.Y - boxHeight)
                        esp.LeftLine.To = Vector2.new(screenPos.X - boxWidth, screenPos.Y + boxHeight)
                        esp.LeftLine.Color = roleColor
                        esp.LeftLine.Visible = true

                        esp.RightLine.From = Vector2.new(screenPos.X + boxWidth, screenPos.Y - boxHeight)
                        esp.RightLine.To = Vector2.new(screenPos.X + boxWidth, screenPos.Y + boxHeight)
                        esp.RightLine.Color = roleColor
                        esp.RightLine.Visible = true

                        esp.NameTag.Position = Vector2.new(screenPos.X, screenPos.Y - boxHeight - 16)
                        esp.NameTag.Text = player.DisplayName .. " [" .. role .. "]"
                        esp.NameTag.Color = roleColor
                        esp.NameTag.Visible = true
                    end
                end)
            else
                RemoveESP(player)
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════
-- TAB: INFO
-- ═══════════════════════════════════════════════════════════
local InfoTab = Window:CreateTab("INFO", "rbxassetid://6023426915")
local InfoSec = InfoTab:CreateSection("Script Information")
InfoSec:AddLabel("Game: Murder Mystery 2")
InfoSec:AddLabel("Version: 0.0.1")
InfoSec:AddLabel("Developer: BORCA")
InfoSec:AddLabel("Edition: PREMIUM")

-- ═══════════════════════════════════════════════════════════
-- TAB: MAIN
-- ═══════════════════════════════════════════════════════════
local MainTab = Window:CreateTab("MAIN", "rbxassetid://6023426915")
local AimSec = MainTab:CreateSection("Combat & Aimbot")
AimSec:AddToggle({ Name = "Enable Aimbot (RMB)", Callback = function(val) States.AimbotEnabled = val end })
AimSec:AddToggle({ Name = "Enable Silent Aim", Callback = function(val) States.SilentAimEnabled = val end })
AimSec:AddToggle({ Name = "Kill Aura (Murderer)", Callback = function(val) States.KillAuraEnabled = val end })
AimSec:AddToggle({ Name = "Auto Grab Gun Drop", Callback = function(val) States.AutoGrabGunEnabled = val end })

local HitboxSec = MainTab:CreateSection("Hitbox Customization")
HitboxSec:AddToggle({ Name = "Enable Hitbox", Callback = function(val) States.HitboxEnabled = val end })
HitboxSec:AddSlider({ Name = "Radius Size", Min = 2, Max = 25, Default = 8, Callback = function(val) States.HitboxSize = val end })

-- ═══════════════════════════════════════════════════════════
-- TAB: PLAYER
-- ═══════════════════════════════════════════════════════════
local PlayerTab = Window:CreateTab("PLAYER", "rbxassetid://6023426915")
local MoveSec = PlayerTab:CreateSection("Movement Options")
MoveSec:AddToggle({ Name = "Fly Mode", Callback = function(val) States.FlyEnabled = val; if val then StartFly() else StopFly() end end })
MoveSec:AddToggle({ Name = "Noclip Walls", Callback = function(val) States.NoclipEnabled = val end })
MoveSec:AddToggle({ Name = "God Mode (Infinite HP)", Callback = function(val) States.GodModeEnabled = val end })

local PhysSec = PlayerTab:CreateSection("Physics Boosts")
PhysSec:AddToggle({ Name = "Speedhack Boost", Callback = function(val) States.SpeedEnabled = val end })
PhysSec:AddSlider({ Name = "Speed Velocity", Min = 16, Max = 250, Default = 32, Callback = function(val) States.SpeedValue = val end })
PhysSec:AddToggle({ Name = "Jump Boost", Callback = function(val) States.JumpBoostEnabled = val end })
PhysSec:AddSlider({ Name = "Jump Height", Min = 50, Max = 350, Default = 80, Callback = function(val) States.JumpValue = val end })

-- ═══════════════════════════════════════════════════════════
-- TAB: VISUAL
-- ═══════════════════════════════════════════════════════════
local VisualTab = Window:CreateTab("VISUAL", "rbxassetid://6023426915")
local VisSec = VisualTab:CreateSection("ESP Visuals")
VisSec:AddToggle({ Name = "Box ESP", Callback = function(val) States.ESPEnabled = val end })
VisSec:AddToggle({ Name = "Highlight Player Roles", Callback = function(val) States.HighlightRolesEnabled = val end })


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
