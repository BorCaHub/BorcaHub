--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║                   BorcaHub | Universal Free                 ║
    ║                      Version: 0.0.1                        ║
    ║                    Developer: BORCA                        ║
    ║                Last Update: 2026-05-25                     ║
    ║                                                            ║
    ║          Works on ANY Roblox Game - Free Edition            ║
    ╚══════════════════════════════════════════════════════════════╝
]]

-- ============================================================
-- SERVICES
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local VirtualUser = game:GetService("VirtualUser")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- STATE VARIABLES
-- ============================================================
local States = {
    -- MAIN
    AimbotEnabled = false,
    AimbotFOV = 120,
    HitboxEnabled = false,
    HitboxSize = 5,

    -- PLAYER
    FlyEnabled = false,
    FlySpeed = 50,
    WallhackEnabled = false,
    SpeedhackEnabled = false,
    SpeedValue = 32,
    JumpBoostEnabled = false,
    JumpValue = 50,
    NoclipEnabled = false,
    AntiAFKEnabled = false,

    -- VISUAL
    ESPEnabled = false,

    -- INTERNAL
    FlyBodyVelocity = nil,
    FlyBodyGyro = nil,
    ESPFolder = nil,
    FOVCircle = nil,
    Connections = {},
}

-- ============================================================
-- UTILITY FUNCTIONS
-- ============================================================
local function GetCharacter()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    return char
end

local function GetHumanoid()
    local char = GetCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function GetRootPart()
    local char = GetCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function GetClosestPlayer(fov)
    local closest = nil
    local shortestDistance = fov
    local mousePos = UserInputService:GetMouseLocation()

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Head") then
            local head = player.Character.Head
            local screenPoint, onScreen = Camera:WorldToScreenPoint(head.Position)
            if onScreen then
                local screenPos = Vector2.new(screenPoint.X, screenPoint.Y)
                local dist = (screenPos - mousePos).Magnitude
                if dist < shortestDistance then
                    shortestDistance = dist
                    closest = player
                end
            end
        end
    end
    return closest
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

local function DisconnectAll()
    for key, conn in pairs(States.Connections) do
        if typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        end
        States.Connections[key] = nil
    end
end

-- ============================================================
-- LOAD UI LIBRARY
-- ============================================================
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/BorCaHub/BorcaHub/main/UIMAIN/COMPONENTS/CORE/MAIN.lua"))()

local Window = Library:CreateWindow({
    Title = "BorcaHub | Universal Free",
    SubTitle = "v0.0.1 | Dev: BORCA"
})

-- ============================================================
-- TAB: INFO
-- ============================================================
local InfoTab = Window:CreateTab("INFO", "rbxassetid://6023426915")
local InfoSection = InfoTab:CreateSection("Script Information")

InfoSection:AddLabel("Script: Universal Free")
InfoSection:AddLabel("Version: 0.0.1")
InfoSection:AddLabel("Developer: BORCA")
InfoSection:AddLabel("Last Update: 2026-05-25")
InfoSection:AddLabel("Edition: FREE")
InfoSection:AddLabel("Compatibility: All Games")

local StatusSection = InfoTab:CreateSection("Status")
StatusSection:AddLabel("Game: " .. tostring(game.Name))
StatusSection:AddLabel("Place ID: " .. tostring(game.PlaceId))
StatusSection:AddLabel("Player: " .. tostring(LocalPlayer.Name))
StatusSection:AddLabel("Display: " .. tostring(LocalPlayer.DisplayName))

local CreditsSection = InfoTab:CreateSection("Credits")
CreditsSection:AddLabel("UI Library: BorcaHub Core")
CreditsSection:AddLabel("Scripts: BORCA Team")
CreditsSection:AddLabel("Thank you for using BorcaHub!")

-- ============================================================
-- TAB: MAIN
-- ============================================================
local MainTab = Window:CreateTab("MAIN", "rbxassetid://6023426915")

-- ==================== AIMBOT SECTION ====================
local AimbotSection = MainTab:CreateSection("Aimbot")

-- FOV Circle Drawing
pcall(function()
    if Drawing then
        States.FOVCircle = Drawing.new("Circle")
        States.FOVCircle.Color = Color3.fromRGB(255, 255, 0)
        States.FOVCircle.Thickness = 1.5
        States.FOVCircle.Filled = false
        States.FOVCircle.Transparency = 0.8
        States.FOVCircle.Radius = States.AimbotFOV
        States.FOVCircle.Visible = false
        States.FOVCircle.NumSides = 64
    end
end)

AimbotSection:AddToggle({
    Name = "Enable Aimbot",
    Callback = function(value)
        States.AimbotEnabled = value

        pcall(function()
            if States.FOVCircle then
                States.FOVCircle.Visible = value
            end
        end)

        if value then
            Notify("BorcaHub", "Aimbot Enabled")

            if States.Connections["aimbot"] then
                States.Connections["aimbot"]:Disconnect()
            end

            States.Connections["aimbot"] = RunService.RenderStepped:Connect(function()
                if not States.AimbotEnabled then return end

                pcall(function()
                    if States.FOVCircle then
                        local mousePos = UserInputService:GetMouseLocation()
                        States.FOVCircle.Position = mousePos
                        States.FOVCircle.Radius = States.AimbotFOV
                    end

                    if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
                        local target = GetClosestPlayer(States.AimbotFOV)
                        if target and target.Character and target.Character:FindFirstChild("Head") then
                            local headPos = target.Character.Head.Position
                            Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, headPos)
                        end
                    end
                end)
            end)
        else
            Notify("BorcaHub", "Aimbot Disabled")
            if States.Connections["aimbot"] then
                States.Connections["aimbot"]:Disconnect()
                States.Connections["aimbot"] = nil
            end
        end
    end
})

AimbotSection:AddSlider({
    Name = "Aimbot FOV",
    Min = 10,
    Max = 500,
    Default = 120,
    Callback = function(value)
        States.AimbotFOV = value
        pcall(function()
            if States.FOVCircle then
                States.FOVCircle.Radius = value
            end
        end)
    end
})

-- ==================== HITBOX SECTION ====================
local HitboxSection = MainTab:CreateSection("Hitbox Expander")

HitboxSection:AddToggle({
    Name = "Enable Hitbox Expander",
    Callback = function(value)
        States.HitboxEnabled = value

        if value then
            Notify("BorcaHub", "Hitbox Expander Enabled")

            if States.Connections["hitbox"] then
                States.Connections["hitbox"]:Disconnect()
            end

            States.Connections["hitbox"] = RunService.RenderStepped:Connect(function()
                if not States.HitboxEnabled then return end

                pcall(function()
                    for _, player in ipairs(Players:GetPlayers()) do
                        if player ~= LocalPlayer and player.Character then
                            local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
                            if rootPart then
                                rootPart.Size = Vector3.new(States.HitboxSize, States.HitboxSize, States.HitboxSize)
                                rootPart.Transparency = 0.7
                                rootPart.BrickColor = BrickColor.new("Really red")
                                rootPart.Material = Enum.Material.ForceField
                                rootPart.CanCollide = false
                            end
                        end
                    end
                end)
            end)
        else
            Notify("BorcaHub", "Hitbox Expander Disabled")

            if States.Connections["hitbox"] then
                States.Connections["hitbox"]:Disconnect()
                States.Connections["hitbox"] = nil
            end

            pcall(function()
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer and player.Character then
                        local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
                        if rootPart then
                            rootPart.Size = Vector3.new(2, 2, 1)
                            rootPart.Transparency = 1
                            rootPart.Material = Enum.Material.Plastic
                        end
                    end
                end
            end)
        end
    end
})

HitboxSection:AddSlider({
    Name = "Hitbox Size",
    Min = 2,
    Max = 25,
    Default = 5,
    Callback = function(value)
        States.HitboxSize = value
    end
})

-- ============================================================
-- TAB: PLAYER
-- ============================================================
local PlayerTab = Window:CreateTab("PLAYER", "rbxassetid://6023426915")

-- ==================== FLY SECTION ====================
local FlySection = PlayerTab:CreateSection("Fly")

local function StartFly()
    pcall(function()
        local rootPart = GetRootPart()
        if not rootPart then return end

        -- Remove old instances
        if States.FlyBodyVelocity then
            States.FlyBodyVelocity:Destroy()
        end
        if States.FlyBodyGyro then
            States.FlyBodyGyro:Destroy()
        end

        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Velocity = Vector3.new(0, 0, 0)
        bv.Parent = rootPart
        States.FlyBodyVelocity = bv

        local bg = Instance.new("BodyGyro")
        bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        bg.D = 100
        bg.P = 10000
        bg.Parent = rootPart
        States.FlyBodyGyro = bg

        if States.Connections["fly"] then
            States.Connections["fly"]:Disconnect()
        end

        States.Connections["fly"] = RunService.RenderStepped:Connect(function()
            if not States.FlyEnabled then return end

            pcall(function()
                local camCF = Camera.CFrame
                bg.CFrame = camCF

                local moveDir = Vector3.new(0, 0, 0)

                if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                    moveDir = moveDir + camCF.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                    moveDir = moveDir - camCF.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                    moveDir = moveDir - camCF.RightVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                    moveDir = moveDir + camCF.RightVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    moveDir = moveDir + Vector3.new(0, 1, 0)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                    moveDir = moveDir - Vector3.new(0, 1, 0)
                end

                if moveDir.Magnitude > 0 then
                    bv.Velocity = moveDir.Unit * States.FlySpeed
                else
                    bv.Velocity = Vector3.new(0, 0, 0)
                end
            end)
        end)
    end)
end

local function StopFly()
    pcall(function()
        if States.Connections["fly"] then
            States.Connections["fly"]:Disconnect()
            States.Connections["fly"] = nil
        end
        if States.FlyBodyVelocity then
            States.FlyBodyVelocity:Destroy()
            States.FlyBodyVelocity = nil
        end
        if States.FlyBodyGyro then
            States.FlyBodyGyro:Destroy()
            States.FlyBodyGyro = nil
        end
    end)
end

FlySection:AddToggle({
    Name = "Enable Fly",
    Callback = function(value)
        States.FlyEnabled = value
        if value then
            Notify("BorcaHub", "Fly Enabled - Use WASD + Space/Ctrl")
            StartFly()
        else
            Notify("BorcaHub", "Fly Disabled")
            StopFly()
        end
    end
})

FlySection:AddSlider({
    Name = "Fly Speed",
    Min = 10,
    Max = 300,
    Default = 50,
    Callback = function(value)
        States.FlySpeed = value
    end
})

-- ==================== WALLHACK SECTION ====================
local WallhackSection = PlayerTab:CreateSection("Wallhack")

WallhackSection:AddToggle({
    Name = "Enable Wallhack",
    Callback = function(value)
        States.WallhackEnabled = value

        if value then
            Notify("BorcaHub", "Wallhack Enabled")

            if States.Connections["wallhack"] then
                States.Connections["wallhack"]:Disconnect()
            end

            States.Connections["wallhack"] = RunService.RenderStepped:Connect(function()
                if not States.WallhackEnabled then return end

                pcall(function()
                    for _, player in ipairs(Players:GetPlayers()) do
                        if player ~= LocalPlayer and player.Character then
                            for _, part in ipairs(player.Character:GetDescendants()) do
                                if part:IsA("BasePart") then
                                    part.Material = Enum.Material.ForceField
                                end
                            end
                        end
                    end
                end)
            end)
        else
            Notify("BorcaHub", "Wallhack Disabled")

            if States.Connections["wallhack"] then
                States.Connections["wallhack"]:Disconnect()
                States.Connections["wallhack"] = nil
            end

            pcall(function()
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer and player.Character then
                        for _, part in ipairs(player.Character:GetDescendants()) do
                            if part:IsA("BasePart") then
                                part.Material = Enum.Material.Plastic
                            end
                        end
                    end
                end
            end)
        end
    end
})

-- ==================== SPEEDHACK SECTION ====================
local SpeedSection = PlayerTab:CreateSection("Speedhack")

SpeedSection:AddToggle({
    Name = "Enable Speedhack",
    Callback = function(value)
        States.SpeedhackEnabled = value

        if value then
            Notify("BorcaHub", "Speedhack Enabled")

            if States.Connections["speed"] then
                States.Connections["speed"]:Disconnect()
            end

            States.Connections["speed"] = RunService.RenderStepped:Connect(function()
                if not States.SpeedhackEnabled then return end

                pcall(function()
                    local humanoid = GetHumanoid()
                    if humanoid then
                        humanoid.WalkSpeed = States.SpeedValue
                    end
                end)
            end)
        else
            Notify("BorcaHub", "Speedhack Disabled")

            if States.Connections["speed"] then
                States.Connections["speed"]:Disconnect()
                States.Connections["speed"] = nil
            end

            pcall(function()
                local humanoid = GetHumanoid()
                if humanoid then
                    humanoid.WalkSpeed = 16
                end
            end)
        end
    end
})

SpeedSection:AddSlider({
    Name = "Walk Speed",
    Min = 16,
    Max = 250,
    Default = 32,
    Callback = function(value)
        States.SpeedValue = value
    end
})

-- ==================== JUMP BOOST SECTION ====================
local JumpSection = PlayerTab:CreateSection("Jump Boost")

JumpSection:AddToggle({
    Name = "Enable Jump Boost",
    Callback = function(value)
        States.JumpBoostEnabled = value

        if value then
            Notify("BorcaHub", "Jump Boost Enabled")

            if States.Connections["jump"] then
                States.Connections["jump"]:Disconnect()
            end

            States.Connections["jump"] = RunService.RenderStepped:Connect(function()
                if not States.JumpBoostEnabled then return end

                pcall(function()
                    local humanoid = GetHumanoid()
                    if humanoid then
                        humanoid.JumpPower = States.JumpValue
                        humanoid.UseJumpPower = true
                    end
                end)
            end)
        else
            Notify("BorcaHub", "Jump Boost Disabled")

            if States.Connections["jump"] then
                States.Connections["jump"]:Disconnect()
                States.Connections["jump"] = nil
            end

            pcall(function()
                local humanoid = GetHumanoid()
                if humanoid then
                    humanoid.JumpPower = 50
                    humanoid.UseJumpPower = true
                end
            end)
        end
    end
})

JumpSection:AddSlider({
    Name = "Jump Power",
    Min = 50,
    Max = 350,
    Default = 50,
    Callback = function(value)
        States.JumpValue = value
    end
})

-- ==================== NOCLIP SECTION ====================
local NoclipSection = PlayerTab:CreateSection("Noclip")

NoclipSection:AddToggle({
    Name = "Enable Noclip",
    Callback = function(value)
        States.NoclipEnabled = value

        if value then
            Notify("BorcaHub", "Noclip Enabled")

            if States.Connections["noclip"] then
                States.Connections["noclip"]:Disconnect()
            end

            States.Connections["noclip"] = RunService.Stepped:Connect(function()
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
        else
            Notify("BorcaHub", "Noclip Disabled")

            if States.Connections["noclip"] then
                States.Connections["noclip"]:Disconnect()
                States.Connections["noclip"] = nil
            end

            pcall(function()
                local char = GetCharacter()
                if char then
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                            part.CanCollide = true
                        end
                    end
                end
            end)
        end
    end
})

-- ==================== ANTI-AFK SECTION ====================
local AntiAFKSection = PlayerTab:CreateSection("Anti-AFK")

AntiAFKSection:AddToggle({
    Name = "Enable Anti-AFK",
    Callback = function(value)
        States.AntiAFKEnabled = value

        if value then
            Notify("BorcaHub", "Anti-AFK Enabled")

            if States.Connections["antiafk"] then
                States.Connections["antiafk"]:Disconnect()
            end

            States.Connections["antiafk"] = LocalPlayer.Idled:Connect(function()
                if States.AntiAFKEnabled then
                    pcall(function()
                        VirtualUser:CaptureController()
                        VirtualUser:ClickButton2(Vector2.new())
                    end)
                end
            end)
        else
            Notify("BorcaHub", "Anti-AFK Disabled")

            if States.Connections["antiafk"] then
                States.Connections["antiafk"]:Disconnect()
                States.Connections["antiafk"] = nil
            end
        end
    end
})

-- ============================================================
-- TAB: VISUAL
-- ============================================================
local VisualTab = Window:CreateTab("VISUAL", "rbxassetid://6023426915")

-- ==================== ESP SECTION ====================
local ESPSection = VisualTab:CreateSection("ESP Enhancement")

local function CreateESPBox(player)
    pcall(function()
        if not player.Character then return end
        if not player.Character:FindFirstChild("HumanoidRootPart") then return end
        if not States.ESPFolder then return end

        -- Remove existing ESP for this player
        local existing = States.ESPFolder:FindFirstChild(player.Name .. "_ESP")
        if existing then existing:Destroy() end

        local highlight = Instance.new("Highlight")
        highlight.Name = player.Name .. "_ESP"
        highlight.Adornee = player.Character
        highlight.FillColor = Color3.fromRGB(255, 0, 0)
        highlight.FillTransparency = 0.85
        highlight.OutlineColor = Color3.fromRGB(255, 255, 0)
        highlight.OutlineTransparency = 0
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = States.ESPFolder

        -- Billboard for name and distance
        local billboard = Instance.new("BillboardGui")
        billboard.Name = player.Name .. "_Billboard"
        billboard.Adornee = player.Character:FindFirstChild("Head") or player.Character:FindFirstChild("HumanoidRootPart")
        billboard.Size = UDim2.new(0, 200, 0, 50)
        billboard.StudsOffset = Vector3.new(0, 3, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = States.ESPFolder

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextStrokeTransparency = 0
        nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 14
        nameLabel.Text = player.DisplayName .. " [" .. player.Name .. "]"
        nameLabel.Parent = billboard

        local distLabel = Instance.new("TextLabel")
        distLabel.Name = "DistLabel"
        distLabel.Size = UDim2.new(1, 0, 0.5, 0)
        distLabel.Position = UDim2.new(0, 0, 0.5, 0)
        distLabel.BackgroundTransparency = 1
        distLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
        distLabel.TextStrokeTransparency = 0
        distLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        distLabel.Font = Enum.Font.GothamBold
        distLabel.TextSize = 12
        distLabel.Text = "0m"
        distLabel.Parent = billboard

        -- Health bar using another billboard
        local healthBillboard = Instance.new("BillboardGui")
        healthBillboard.Name = player.Name .. "_HealthBar"
        healthBillboard.Adornee = player.Character:FindFirstChild("Head") or player.Character:FindFirstChild("HumanoidRootPart")
        healthBillboard.Size = UDim2.new(0, 100, 0, 8)
        healthBillboard.StudsOffset = Vector3.new(0, 2.5, 0)
        healthBillboard.AlwaysOnTop = true
        healthBillboard.Parent = States.ESPFolder

        local healthBG = Instance.new("Frame")
        healthBG.Name = "HealthBG"
        healthBG.Size = UDim2.new(1, 0, 1, 0)
        healthBG.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        healthBG.BorderSizePixel = 1
        healthBG.BorderColor3 = Color3.fromRGB(0, 0, 0)
        healthBG.Parent = healthBillboard

        local healthFill = Instance.new("Frame")
        healthFill.Name = "HealthFill"
        healthFill.Size = UDim2.new(1, 0, 1, 0)
        healthFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
        healthFill.BorderSizePixel = 0
        healthFill.Parent = healthBG
    end)
end

local function RemoveESPBox(playerName)
    pcall(function()
        if not States.ESPFolder then return end
        for _, obj in ipairs(States.ESPFolder:GetChildren()) do
            if obj.Name:find(playerName) then
                obj:Destroy()
            end
        end
    end)
end

local function UpdateESP()
    pcall(function()
        if not States.ESPFolder then return end
        local myRoot = GetRootPart()

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local theirRoot = player.Character:FindFirstChild("HumanoidRootPart")
                local humanoid = player.Character:FindFirstChildOfClass("Humanoid")

                -- Update distance label
                local billboard = States.ESPFolder:FindFirstChild(player.Name .. "_Billboard")
                if billboard and myRoot and theirRoot then
                    local distLabel = billboard:FindFirstChild("DistLabel")
                    if distLabel then
                        local dist = math.floor((myRoot.Position - theirRoot.Position).Magnitude)
                        distLabel.Text = tostring(dist) .. "m"
                    end
                end

                -- Update health bar
                local healthBar = States.ESPFolder:FindFirstChild(player.Name .. "_HealthBar")
                if healthBar and humanoid then
                    local healthBG = healthBar:FindFirstChild("HealthBG")
                    if healthBG then
                        local healthFill = healthBG:FindFirstChild("HealthFill")
                        if healthFill then
                            local ratio = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                            healthFill.Size = UDim2.new(ratio, 0, 1, 0)

                            if ratio > 0.6 then
                                healthFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
                            elseif ratio > 0.3 then
                                healthFill.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
                            else
                                healthFill.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
                            end
                        end
                    end
                end
            end
        end
    end)
end

local function ClearAllESP()
    pcall(function()
        if States.ESPFolder then
            States.ESPFolder:ClearAllChildren()
        end
        if States.Connections["espupdate"] then
            States.Connections["espupdate"]:Disconnect()
            States.Connections["espupdate"] = nil
        end
        if States.Connections["espadded"] then
            States.Connections["espadded"]:Disconnect()
            States.Connections["espadded"] = nil
        end
        if States.Connections["espremoved"] then
            States.Connections["espremoved"]:Disconnect()
            States.Connections["espremoved"] = nil
        end
    end)
end

ESPSection:AddToggle({
    Name = "Enable ESP Boxes",
    Callback = function(value)
        States.ESPEnabled = value

        if value then
            Notify("BorcaHub", "ESP Boxes Enabled")

            -- Create ESP folder
            if not States.ESPFolder then
                States.ESPFolder = Instance.new("Folder")
                States.ESPFolder.Name = "BorcaHub_ESP"
                States.ESPFolder.Parent = game:GetService("CoreGui")
            end

            -- Create ESP for all current players
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    CreateESPBox(player)

                    -- Re-create on respawn
                    pcall(function()
                        player.CharacterAdded:Connect(function(char)
                            if States.ESPEnabled then
                                task.wait(0.5)
                                CreateESPBox(player)
                            end
                        end)
                    end)
                end
            end

            -- Listen for new players
            States.Connections["espadded"] = Players.PlayerAdded:Connect(function(player)
                if not States.ESPEnabled then return end

                player.CharacterAdded:Connect(function(char)
                    if States.ESPEnabled then
                        task.wait(0.5)
                        CreateESPBox(player)
                    end
                end)

                if player.Character then
                    CreateESPBox(player)
                end
            end)

            -- Remove ESP when player leaves
            States.Connections["espremoved"] = Players.PlayerRemoving:Connect(function(player)
                RemoveESPBox(player.Name)
            end)

            -- Update loop for distance and health
            States.Connections["espupdate"] = RunService.RenderStepped:Connect(function()
                if States.ESPEnabled then
                    UpdateESP()
                end
            end)
        else
            Notify("BorcaHub", "ESP Boxes Disabled")
            ClearAllESP()
        end
    end
})

ESPSection:AddLabel("ESP shows: Box, Name, Distance, Health")
ESPSection:AddLabel("Free Edition: Box ESP Only")

-- ============================================================
-- TAB: SETTINGS
-- ============================================================
local SettingsTab = Window:CreateTab("SETTINGS", "rbxassetid://6023426915")

-- ==================== THEME SECTION ====================
local ThemeSection = SettingsTab:CreateSection("Appearance")

ThemeSection:AddDropdown({
    Name = "Theme",
    Options = {"Dark", "Light", "Blue", "Red", "Green", "Purple", "Orange"},
    Callback = function(value)
        Notify("BorcaHub", "Theme selected: " .. tostring(value))
        -- Theme application is handled by the UI library if supported
    end
})

ThemeSection:AddDropdown({
    Name = "Language",
    Options = {"English", "Spanish", "Portuguese", "French", "German", "Russian", "Chinese", "Japanese", "Korean", "Arabic", "Turkish", "Indonesian"},
    Callback = function(value)
        Notify("BorcaHub", "Language selected: " .. tostring(value))
        -- Free version: English only
        if value ~= "English" then
            Notify("BorcaHub", "Free version supports English only. Upgrade to Premium for more languages.")
        end
    end
})

-- ==================== GAME SETTINGS SECTION ====================
local GameSection = SettingsTab:CreateSection("Game Settings")

GameSection:AddInput({
    Name = "Place Game ID",
    Callback = function(value)
        Notify("BorcaHub", "Game ID set to: " .. tostring(value))
    end
})

-- ==================== PERFORMANCE SECTION ====================
local PerformanceSection = SettingsTab:CreateSection("Performance")

PerformanceSection:AddButton({
    Name = "Boost FPS & Anti Lag",
    Callback = function()
        pcall(function()
            Notify("BorcaHub", "Applying FPS Boost & Anti Lag...")

            -- Reduce terrain detail
            local terrain = Workspace:FindFirstChildOfClass("Terrain")
            if terrain then
                terrain.WaterWaveSize = 0
                terrain.WaterWaveSpeed = 0
                terrain.WaterReflectance = 0
                terrain.WaterTransparency = 0
            end

            -- Lower lighting quality
            local lighting = game:GetService("Lighting")
            lighting.GlobalShadows = false
            lighting.FogEnd = 9e9

            -- Remove unnecessary visual effects
            for _, effect in ipairs(lighting:GetDescendants()) do
                if effect:IsA("BlurEffect") or effect:IsA("SunRaysEffect") or effect:IsA("BloomEffect") or effect:IsA("ColorCorrectionEffect") or effect:IsA("DepthOfFieldEffect") then
                    effect.Enabled = false
                end
            end

            -- Reduce part detail in workspace
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01

            -- Clean up old textures and decals for performance
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("Decal") or obj:IsA("Texture") then
                    obj.Transparency = 1
                end
                if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                    obj.Enabled = false
                end
            end

            -- Force garbage collection
            gcinfo()

            Notify("BorcaHub", "FPS Boost Applied Successfully!")
        end)
    end
})

-- ==================== SERVER SECTION ====================
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
            Notify("BorcaHub", "Finding a new server...")

            local success, servers = pcall(function()
                local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
                return HttpService:JSONDecode(game:HttpGet(url))
            end)

            if success and servers and servers.data then
                local validServers = {}
                for _, server in ipairs(servers.data) do
                    if server.id ~= game.JobId and server.playing < server.maxPlayers then
                        table.insert(validServers, server)
                    end
                end

                if #validServers > 0 then
                    local randomServer = validServers[math.random(1, #validServers)]
                    Notify("BorcaHub", "Hopping to new server...")
                    task.wait(0.5)
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, randomServer.id, LocalPlayer)
                else
                    Notify("BorcaHub", "No available servers found!")
                end
            else
                Notify("BorcaHub", "Failed to fetch server list!")
            end
        end)
    end
})

ServerSection:AddButton({
    Name = "Change Game",
    Callback = function()
        pcall(function()
            Notify("BorcaHub", "Enter a Place ID in the input above, then use this button to teleport.")
        end)
    end
})

ServerSection:AddInput({
    Name = "Teleport to Place ID",
    Callback = function(value)
        pcall(function()
            local placeId = tonumber(value)
            if placeId then
                Notify("BorcaHub", "Teleporting to Place ID: " .. tostring(placeId))
                task.wait(1)
                TeleportService:Teleport(placeId, LocalPlayer)
            else
                Notify("BorcaHub", "Invalid Place ID! Please enter a number.")
            end
        end)
    end
})

-- ==================== SCRIPT MANAGEMENT SECTION ====================
local ScriptManagement = SettingsTab:CreateSection("Script Management")

ScriptManagement:AddButton({
    Name = "Destroy Script",
    Callback = function()
        pcall(function()
            Notify("BorcaHub", "Destroying BorcaHub...")

            -- Disable all features
            States.AimbotEnabled = false
            States.HitboxEnabled = false
            States.FlyEnabled = false
            States.WallhackEnabled = false
            States.SpeedhackEnabled = false
            States.JumpBoostEnabled = false
            States.NoclipEnabled = false
            States.AntiAFKEnabled = false
            States.ESPEnabled = false

            -- Stop fly
            StopFly()

            -- Reset speed and jump
            local humanoid = GetHumanoid()
            if humanoid then
                humanoid.WalkSpeed = 16
                humanoid.JumpPower = 50
            end

            -- Re-enable collisions
            local char = GetCharacter()
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        part.CanCollide = true
                    end
                end
            end

            -- Clear ESP
            ClearAllESP()
            if States.ESPFolder then
                States.ESPFolder:Destroy()
                States.ESPFolder = nil
            end

            -- Remove FOV circle
            if States.FOVCircle then
                States.FOVCircle:Remove()
                States.FOVCircle = nil
            end

            -- Reset hitboxes
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
                    if rootPart then
                        rootPart.Size = Vector3.new(2, 2, 1)
                        rootPart.Transparency = 1
                        rootPart.Material = Enum.Material.Plastic
                    end
                end
            end

            -- Reset wallhack materials
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    for _, part in ipairs(player.Character:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.Material = Enum.Material.Plastic
                        end
                    end
                end
            end

            -- Disconnect all events
            DisconnectAll()

            -- Destroy UI
            task.wait(0.5)
            Library:Destroy()
        end)
    end
})

ScriptManagement:AddLabel("BorcaHub | Universal Free v0.0.1")
ScriptManagement:AddLabel("Developed by BORCA")
ScriptManagement:AddLabel("Free Edition - Upgrade for more features!")

-- ============================================================
-- CHARACTER RESPAWN HANDLER
-- ============================================================
pcall(function()
    LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(1)

        -- Re-apply speed if enabled
        if States.SpeedhackEnabled then
            local humanoid = char:WaitForChild("Humanoid", 5)
            if humanoid then
                humanoid.WalkSpeed = States.SpeedValue
            end
        end

        -- Re-apply jump boost if enabled
        if States.JumpBoostEnabled then
            local humanoid = char:WaitForChild("Humanoid", 5)
            if humanoid then
                humanoid.JumpPower = States.JumpValue
                humanoid.UseJumpPower = true
            end
        end

        -- Restart fly if enabled
        if States.FlyEnabled then
            StopFly()
            task.wait(0.5)
            StartFly()
        end

        -- Re-create ESP boxes
        if States.ESPEnabled then
            task.wait(0.5)
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    CreateESPBox(player)
                end
            end
        end
    end)
end)

-- ============================================================
-- STARTUP NOTIFICATION
-- ============================================================
pcall(function()
    Notify("BorcaHub", "Universal Free v0.0.1 Loaded!")
    task.wait(1)
    Notify("BorcaHub", "Developed by BORCA | Free Edition")
end)

-- ============================================================
-- END OF SCRIPT
-- ============================================================
--[[
    BorcaHub | Universal Free v0.0.1
    Free Edition - No Security Engine
    Upgrade to Premium for full features:
    - Advanced Aimbot with prediction
    - Full ESP suite (Tracers, Skeleton, Chams)
    - Anti-Cheat Bypass Engine
    - Security & Cryptography Engine
    - Multi-language support
    - Priority updates
    
    © 2026 BORCA - All Rights Reserved
]]
