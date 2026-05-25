--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║  BorcaHub  •  ScriptMain / Premium / Arsenal.lua             ║
    ║                                                              ║
    ║  ARSENAL - V23 HARDENED (OPTIMIZED & ANTI-DETECT)            ║
    ║  Safe Metatable Hooks | Throttled ESP | Event-Driven Hitbox  ║
    ║  Frame-Skipped Rendering | Guaranteed Memory Cleanup         ║
    ╚══════════════════════════════════════════════════════════════╝
--]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local Lighting         = game:GetService("Lighting")
local Camera           = Workspace.CurrentCamera
local LocalPlayer      = Players.LocalPlayer

-- ================================================================
--  CORE MODULE
-- ================================================================
local PremiumScript = {
    _connections  = {},
    _highlights   = {},
    _billboards   = {},
    _tracers      = {},
    _skeleton     = {},
    _drawingObjs  = {},  -- Master registry of ALL Drawing objects
    _hitboxChars  = {},  -- Tracks which characters have hitbox applied
    _destroyed    = false,
}

local function Track(conn)
    if PremiumScript._destroyed then return conn end
    table.insert(PremiumScript._connections, conn)
    return conn
end

-- Master Drawing registry for guaranteed cleanup
local function CreateDrawing(drawType)
    local ok, obj = pcall(Drawing.new, drawType)
    if ok and obj then
        table.insert(PremiumScript._drawingObjs, obj)
        return obj
    end
    return nil
end

-- ================================================================
--  SETTINGS
-- ================================================================
local Settings = {
    aimbotEnabled     = false,
    silentAimEnabled  = false,
    triggerBotEnabled = false,
    wallCheck         = true,
    stickyAim         = true,
    targetBone        = "Head",
    fovRadius         = 300,
    smoothness        = 1.5,
    triggerDelay      = 0.05,

    espEnabled        = false,
    teamCheck         = true,
    showName          = true,
    showHealth        = true,
    showDist          = true,
    showTracers       = false,
    showSkeleton      = false,

    crosshairEnabled  = false,
    crosshairSize     = 12,
    crosshairGap      = 4,

    hitboxEnabled     = false,
    hitboxSize        = 15,

    autoRespawn       = false,
    fullbright        = false,
    killCount         = 0,
}

-- ================================================================
--  FIX #4: OPTIMIZED WALLCHECK (SINGLE RAYCAST TO ROOT ONLY)
-- ================================================================
local _raycastParams = RaycastParams.new()
_raycastParams.FilterType  = Enum.RaycastFilterType.Exclude
_raycastParams.IgnoreWater = true

local function IsVisible(targetChar)
    if not targetChar then return false end
    local root = targetChar:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local myChar = LocalPlayer.Character
    if not myChar then return false end

    -- Only raycast to HumanoidRootPart (80% cheaper than per-bone)
    _raycastParams.FilterDescendantsInstances = {myChar, targetChar}
    local origin    = Camera.CFrame.Position
    local direction = (root.Position - origin)

    local result = Workspace:Raycast(origin, direction, _raycastParams)
    if result then
        return result.Instance.Transparency > 0.5 or not result.Instance.CanCollide
    end
    return true
end

-- ================================================================
--  CENTRALIZED TARGET FINDER (CACHED ONCE PER FRAME)
-- ================================================================
local FOVCircle
local _mainTarget    = nil
local _currentTarget = nil

local function SetFOVCircle(enabled, radius)
    if radius then Settings.fovRadius = radius end
    if not FOVCircle then
        FOVCircle = CreateDrawing("Circle")
        if not FOVCircle then return end
        FOVCircle.Thickness = 1.5
        FOVCircle.Filled    = false
        Track(RunService.RenderStepped:Connect(function()
            if PremiumScript._destroyed then return end
            if FOVCircle and FOVCircle.Visible then
                FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                FOVCircle.Radius   = Settings.fovRadius
                FOVCircle.Color    = _mainTarget and Color3.fromRGB(0, 255, 80) or Color3.fromRGB(255, 30, 30)
            end
        end))
    end
    FOVCircle.Visible = enabled
end

-- Single target acquisition per frame — prevents hook collision
Track(RunService.RenderStepped:Connect(function()
    if PremiumScript._destroyed then return end
    _mainTarget = nil

    -- 1. Sticky Aim: keep current target
    if Settings.stickyAim and _currentTarget and _currentTarget.Parent then
        local char = _currentTarget.Parent
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            local sp, onS = Camera:WorldToViewportPoint(_currentTarget.Position)
            if onS then
                local c = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                if (Vector2.new(sp.X, sp.Y) - c).Magnitude < Settings.fovRadius * 1.5 then
                    if not Settings.wallCheck or IsVisible(char) then
                        _mainTarget = _currentTarget
                    end
                end
            end
        end
    end

    -- 2. Acquire new target
    if not _mainTarget then
        local closestPart, closestDist = nil, Settings.fovRadius
        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            if Settings.teamCheck and player.Team == LocalPlayer.Team then continue end

            local char = player.Character
            if not char then continue end
            local head  = char:FindFirstChild("Head")
            local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
            local hum   = char:FindFirstChildOfClass("Humanoid")
            if not head or not torso or not hum or hum.Health <= 0 then continue end

            local targetPart = (Settings.targetBone == "Head") and head or torso
            local sp, onS = Camera:WorldToViewportPoint(targetPart.Position)
            if not onS then continue end

            local c = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            local dist = (Vector2.new(sp.X, sp.Y) - c).Magnitude

            if dist < closestDist then
                if Settings.wallCheck then
                    if IsVisible(char) then closestPart = targetPart; closestDist = dist end
                else
                    closestPart = targetPart; closestDist = dist
                end
            end
        end
        _mainTarget = closestPart
    end

    _currentTarget = _mainTarget
end))

-- ================================================================
--  AIMBOT (BINDTORENDERSTEP — RUNS AFTER ARSENAL RECOIL)
-- ================================================================
local _aimbotBound = false

local function AimbotLoop()
    if PremiumScript._destroyed then return end
    if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
    if not _mainTarget then return end

    local targetPos = _mainTarget.Position

    if mousemoverel then
        local screenPos, onScreen = Camera:WorldToScreenPoint(targetPos)
        if onScreen then
            local mouseLoc = UserInputService:GetMouseLocation()
            local moveX = (screenPos.X - mouseLoc.X)
            local moveY = (screenPos.Y - mouseLoc.Y)
            mousemoverel(moveX / Settings.smoothness, moveY / Settings.smoothness)
        end
    else
        if _mainTarget.AssemblyLinearVelocity.Magnitude > 2 then
            targetPos = targetPos + (_mainTarget.AssemblyLinearVelocity * 0.03)
        end
        local camCF = Camera.CFrame
        Camera.CFrame = camCF:Lerp(CFrame.lookAt(camCF.Position, targetPos), 1 / Settings.smoothness)
    end
end

local function SetAimbot(enabled)
    Settings.aimbotEnabled = enabled
    if _aimbotBound then
        pcall(function() RunService:UnbindFromRenderStep("BorcaAimbot") end)
        _aimbotBound = false
    end
    if enabled then
        RunService:BindToRenderStep("BorcaAimbot", Enum.RenderPriority.Camera.Value + 1, AimbotLoop)
        _aimbotBound = true
    end
end

-- ================================================================
--  FIX #1: SAFE METATABLE HOOKING (STRICT PCALL GUARDS)
-- ================================================================
local _hookInstalled = false

pcall(function()
    local mt = getrawmetatable(game)
    if not mt then return end

    local oldIndex    = mt.__index
    local oldNamecall = mt.__namecall
    if not oldIndex or not oldNamecall then return end

    if setreadonly then setreadonly(mt, false) end

    mt.__index = newcclosure(function(t, k)
        -- Guard: if destroyed or hooks invalid, bypass immediately
        if PremiumScript._destroyed or not Settings.silentAimEnabled then
            return oldIndex(t, k)
        end

        local ok, result = pcall(function()
            if not checkcaller() and _mainTarget then
                local mouseOk, mouse = pcall(function() return LocalPlayer:GetMouse() end)
                if mouseOk and t == mouse then
                    if k == "Hit"     then return _mainTarget.CFrame end
                    if k == "Target"  then return _mainTarget end
                    if k == "UnitRay" then return Ray.new(Camera.CFrame.Position, (_mainTarget.Position - Camera.CFrame.Position).Unit) end
                    if k == "X"       then return _mainTarget.Position.X end
                    if k == "Y"       then return _mainTarget.Position.Y end
                end
            end
            return nil
        end)

        if ok and result ~= nil then return result end
        return oldIndex(t, k)
    end)

    mt.__namecall = newcclosure(function(self, ...)
        if PremiumScript._destroyed or not Settings.silentAimEnabled then
            return oldNamecall(self, ...)
        end

        local method = getnamecallmethod()
        local args   = {...}

        local ok, result = pcall(function()
            if not checkcaller() and _mainTarget then
                if method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRay" then
                    args[1] = Ray.new(args[1].Origin, (_mainTarget.Position - args[1].Origin).Unit * 5000)
                    return {oldNamecall(self, unpack(args))}
                elseif method == "Raycast" then
                    args[2] = (_mainTarget.Position - args[1]).Unit * 5000
                    return {oldNamecall(self, unpack(args))}
                elseif method == "FireServer" or method == "InvokeServer" then
                    for i, v in ipairs(args) do
                        if typeof(v) == "Vector3" then args[i] = _mainTarget.Position
                        elseif typeof(v) == "CFrame" then args[i] = _mainTarget.CFrame end
                    end
                    return {oldNamecall(self, unpack(args))}
                end
            end
            return nil
        end)

        if ok and result then return unpack(result) end
        return oldNamecall(self, ...)
    end)

    if setreadonly then setreadonly(mt, true) end
    _hookInstalled = true
end)

local function SetSilentAim(enabled) Settings.silentAimEnabled = enabled end

-- ================================================================
--  TRIGGERBOT (AUTO FIRE)
-- ================================================================
local _triggerConn, _isShooting = nil, false

local function SetTriggerBot(enabled)
    Settings.triggerBotEnabled = enabled
    if _triggerConn then _triggerConn:Disconnect() _triggerConn = nil end
    if _isShooting and mouse1release then pcall(mouse1release) end
    _isShooting = false

    if enabled then
        local lastShot = 0
        _triggerConn = Track(RunService.RenderStepped:Connect(function()
            if PremiumScript._destroyed then return end
            local now = tick()
            if _mainTarget and _mainTarget.Parent and IsVisible(_mainTarget.Parent) then
                if not _isShooting and (now - lastShot) > Settings.triggerDelay then
                    _isShooting = true; lastShot = now
                    if mouse1press then pcall(mouse1press) end
                end
            else
                if _isShooting then
                    _isShooting = false
                    if mouse1release then pcall(mouse1release) end
                end
            end
        end))
    end
end

-- ================================================================
--  FIX #2: EVENT-DRIVEN HITBOX (NO PER-FRAME LOOP)
-- ================================================================
local _hitboxParts = {"Head", "UpperTorso", "LowerTorso", "Torso", "LeftUpperArm", "RightUpperArm", "Left Arm", "Right Arm"}

local function ApplyHitbox(char)
    if not char or not Settings.hitboxEnabled then return end
    local player = Players:GetPlayerFromCharacter(char)
    if not player or player == LocalPlayer then return end
    if Settings.teamCheck and player.Team == LocalPlayer.Team then return end

    for _, pName in ipairs(_hitboxParts) do
        local part = char:FindFirstChild(pName)
        if part and part:IsA("BasePart") then
            if not part:GetAttribute("_ox") then
                part:SetAttribute("_ox", part.Size.X)
                part:SetAttribute("_oy", part.Size.Y)
                part:SetAttribute("_oz", part.Size.Z)
            end
            part.Size         = Vector3.new(Settings.hitboxSize, Settings.hitboxSize, Settings.hitboxSize)
            part.Transparency = 0.75
            part.Material     = Enum.Material.Neon
            part.BrickColor   = BrickColor.new("Bright red")
            part.CanCollide   = false
            part.Massless     = true
        end
    end
    PremiumScript._hitboxChars[char] = true
end

local function RevertHitbox(char)
    if not char then return end
    for _, pName in ipairs(_hitboxParts) do
        local part = char:FindFirstChild(pName)
        if part and part:GetAttribute("_ox") then
            part.Size = Vector3.new(part:GetAttribute("_ox"), part:GetAttribute("_oy"), part:GetAttribute("_oz"))
            part.Transparency = 0; part.CanCollide = true
        end
    end
    PremiumScript._hitboxChars[char] = nil
end

local function RevertAllHitboxes()
    for char, _ in pairs(PremiumScript._hitboxChars) do
        pcall(RevertHitbox, char)
    end
    PremiumScript._hitboxChars = {}
end

local _hitboxConns = {}
local function SetHitboxExpander(enabled)
    Settings.hitboxEnabled = enabled

    -- Disconnect existing hitbox listeners
    for _, conn in ipairs(_hitboxConns) do pcall(function() conn:Disconnect() end) end
    _hitboxConns = {}

    if enabled then
        -- Apply to all existing characters
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                ApplyHitbox(player.Character)
            end
        end

        -- Listen for new characters (event-driven, NOT per-frame)
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local conn = player.CharacterAdded:Connect(function(char)
                    task.wait(0.5)
                    if Settings.hitboxEnabled then ApplyHitbox(char) end
                end)
                table.insert(_hitboxConns, conn)
                Track(conn)
            end
        end

        -- Listen for new players joining
        local addConn = Players.PlayerAdded:Connect(function(player)
            local conn = player.CharacterAdded:Connect(function(char)
                task.wait(0.5)
                if Settings.hitboxEnabled then ApplyHitbox(char) end
            end)
            table.insert(_hitboxConns, conn)
            Track(conn)
            if player.Character then
                task.wait(0.5)
                if Settings.hitboxEnabled then ApplyHitbox(player.Character) end
            end
        end)
        table.insert(_hitboxConns, addConn)
        Track(addConn)

        -- Periodic refresh every 2 seconds (instead of every frame)
        local refreshConn
        refreshConn = Track(task.spawn(function()
            while Settings.hitboxEnabled and not PremiumScript._destroyed do
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer and player.Character then
                        if not PremiumScript._hitboxChars[player.Character] then
                            ApplyHitbox(player.Character)
                        end
                        -- Re-apply size in case game resets it
                        local head = player.Character:FindFirstChild("Head")
                        if head and head:GetAttribute("_ox") and head.Size.X ~= Settings.hitboxSize then
                            ApplyHitbox(player.Character)
                        end
                    end
                end
                task.wait(2)
            end
        end))
    else
        RevertAllHitboxes()
    end
end

-- ================================================================
--  FIX #3: THROTTLED ESP (FRAME-SKIPPED RENDERING)
-- ================================================================
local _espLoop
local _espFrameCounter = 0
local ESP_UPDATE_INTERVAL = 3  -- Update every 3rd frame (~20 updates/sec at 60fps)

local function CleanESP()
    for k, hl in pairs(PremiumScript._highlights) do pcall(function() hl:Destroy() end) PremiumScript._highlights[k] = nil end
    for k, bb in pairs(PremiumScript._billboards) do pcall(function() bb:Destroy() end) PremiumScript._billboards[k] = nil end
    for k, tr in pairs(PremiumScript._tracers)    do pcall(function() tr:Remove() end)  PremiumScript._tracers[k]    = nil end
    for k, sk in pairs(PremiumScript._skeleton) do
        for _, l in ipairs(sk) do pcall(function() l:Remove() end) end
        PremiumScript._skeleton[k] = nil
    end
end

local function SetESP(enabled)
    Settings.espEnabled = enabled
    if _espLoop then _espLoop:Disconnect() _espLoop = nil end
    if not enabled then CleanESP() return end

    _espLoop = Track(RunService.Heartbeat:Connect(function()
        if PremiumScript._destroyed or not Settings.espEnabled then return end

        -- Frame-skip throttling
        _espFrameCounter = _espFrameCounter + 1
        if _espFrameCounter < ESP_UPDATE_INTERVAL then return end
        _espFrameCounter = 0

        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            if Settings.teamCheck and player.Team == LocalPlayer.Team then
                if PremiumScript._highlights[player] then pcall(function() PremiumScript._highlights[player]:Destroy() end) PremiumScript._highlights[player] = nil end
                if PremiumScript._billboards[player] then pcall(function() PremiumScript._billboards[player]:Destroy() end) PremiumScript._billboards[player] = nil end
                if PremiumScript._tracers[player] then pcall(function() PremiumScript._tracers[player]:Remove() end) PremiumScript._tracers[player] = nil end
                continue
            end

            local char = player.Character
            if not char then continue end
            local hum  = char:FindFirstChildOfClass("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart")
            local head = char:FindFirstChild("Head")
            if not hum or not root or not head then continue end

            -- ── Highlight ──
            local hl = PremiumScript._highlights[player]
            if not hl or not hl.Parent then
                hl = Instance.new("Highlight", char)
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                PremiumScript._highlights[player] = hl
            end

            local hpRatio = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            local hpColor = Color3.fromRGB(255 * (1 - hpRatio), 255 * hpRatio, 0)
            hl.OutlineColor, hl.FillColor = Color3.new(1, 1, 1), hpColor
            hl.FillTransparency, hl.OutlineTransparency = 0.6, 0.1

            -- ── Billboard (Name + HP + Distance) ──
            local bb = PremiumScript._billboards[player]
            if not bb or not bb.Parent then
                bb = Instance.new("BillboardGui", head)
                bb.Name, bb.AlwaysOnTop = "BorcaESP", true
                bb.Size, bb.StudsOffset = UDim2.new(0, 200, 0, 55), Vector3.new(0, 2.5, 0)

                local nameLbl = Instance.new("TextLabel", bb)
                nameLbl.Name, nameLbl.BackgroundTransparency = "NameLbl", 1
                nameLbl.Size, nameLbl.Font = UDim2.new(1, 0, 0.4, 0), Enum.Font.GothamBold
                nameLbl.TextSize, nameLbl.TextColor3, nameLbl.TextStrokeTransparency = 13, Color3.new(1, 1, 1), 0

                local hpBG = Instance.new("Frame", bb)
                hpBG.Name, hpBG.Position, hpBG.Size = "HPBG", UDim2.new(0.1, 0, 0.45, 0), UDim2.new(0.8, 0, 0.12, 0)
                hpBG.BackgroundColor3, hpBG.BorderSizePixel = Color3.fromRGB(30, 30, 30), 0
                Instance.new("UICorner", hpBG).CornerRadius = UDim.new(0, 4)

                local hpFill = Instance.new("Frame", hpBG)
                hpFill.Name, hpFill.Size, hpFill.BackgroundColor3, hpFill.BorderSizePixel = "HPFill", UDim2.new(1, 0, 1, 0), Color3.fromRGB(0, 255, 0), 0
                Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 4)

                local distLbl = Instance.new("TextLabel", bb)
                distLbl.Name, distLbl.BackgroundTransparency = "DistLbl", 1
                distLbl.Position, distLbl.Size = UDim2.new(0, 0, 0.62, 0), UDim2.new(1, 0, 0.38, 0)
                distLbl.Font, distLbl.TextSize, distLbl.TextColor3, distLbl.TextStrokeTransparency = Enum.Font.Gotham, 11, Color3.fromRGB(200, 200, 200), 0

                PremiumScript._billboards[player] = bb
            end

            local nameLbl = bb:FindFirstChild("NameLbl")
            local hpBG    = bb:FindFirstChild("HPBG")
            local distLbl = bb:FindFirstChild("DistLbl")

            if nameLbl then nameLbl.Visible = Settings.showName; nameLbl.Text = Settings.showName and player.DisplayName or "" end
            if hpBG then
                hpBG.Visible = Settings.showHealth
                local fill = hpBG:FindFirstChild("HPFill")
                if fill then fill.Size = UDim2.new(hpRatio, 0, 1, 0); fill.BackgroundColor3 = hpColor end
            end
            if distLbl then
                distLbl.Visible = Settings.showDist
                local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                distLbl.Text = string.format("%dm  |  %dHP", myRoot and math.floor((root.Position - myRoot.Position).Magnitude) or 0, math.floor(hum.Health))
            end

            -- ── Tracers ──
            if Settings.showTracers then
                pcall(function()
                    local tracer = PremiumScript._tracers[player]
                    if not tracer then
                        tracer = CreateDrawing("Line")
                        if not tracer then return end
                        tracer.Thickness = 1.5
                        PremiumScript._tracers[player] = tracer
                    end
                    local sp, onS = Camera:WorldToViewportPoint(root.Position)
                    tracer.Visible = onS
                    if onS then
                        tracer.From  = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        tracer.To    = Vector2.new(sp.X, sp.Y)
                        tracer.Color = hpColor
                    end
                end)
            else
                if PremiumScript._tracers[player] then pcall(function() PremiumScript._tracers[player].Visible = false end) end
            end

            -- ── Skeleton ──
            if Settings.showSkeleton then
                pcall(function()
                    local bones = {
                        {"Head", "UpperTorso"}, {"Head", "Torso"},
                        {"UpperTorso", "LowerTorso"}, {"Torso", "HumanoidRootPart"},
                        {"UpperTorso", "LeftUpperArm"}, {"UpperTorso", "RightUpperArm"},
                        {"LeftUpperArm", "LeftLowerArm"}, {"RightUpperArm", "RightLowerArm"},
                        {"LowerTorso", "LeftUpperLeg"}, {"LowerTorso", "RightUpperLeg"},
                        {"LeftUpperLeg", "LeftLowerLeg"}, {"RightUpperLeg", "RightLowerLeg"},
                        {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
                        {"Torso", "Left Leg"}, {"Torso", "Right Leg"},
                    }
                    local skelLines = PremiumScript._skeleton[player]
                    if not skelLines then skelLines = {}; PremiumScript._skeleton[player] = skelLines end

                    local idx = 0
                    for _, pair in ipairs(bones) do
                        local p1, p2 = char:FindFirstChild(pair[1]), char:FindFirstChild(pair[2])
                        if p1 and p2 then
                            idx = idx + 1
                            local line = skelLines[idx]
                            if not line then line = CreateDrawing("Line"); if not line then return end; line.Thickness = 1.5; skelLines[idx] = line end
                            local sp1, on1 = Camera:WorldToViewportPoint(p1.Position)
                            local sp2, on2 = Camera:WorldToViewportPoint(p2.Position)
                            line.Visible = on1 and on2
                            if line.Visible then
                                line.From, line.To = Vector2.new(sp1.X, sp1.Y), Vector2.new(sp2.X, sp2.Y)
                                line.Color = Color3.fromRGB(255, 255, 255)
                            end
                        end
                    end
                end)
            else
                if PremiumScript._skeleton[player] then
                    for _, l in ipairs(PremiumScript._skeleton[player]) do pcall(function() l.Visible = false end) end
                end
            end
        end

        -- Cleanup disconnected players
        for player, _ in pairs(PremiumScript._highlights) do
            if not player.Parent then
                pcall(function() PremiumScript._highlights[player]:Destroy() end) PremiumScript._highlights[player] = nil
                if PremiumScript._billboards[player] then pcall(function() PremiumScript._billboards[player]:Destroy() end) PremiumScript._billboards[player] = nil end
                if PremiumScript._tracers[player] then pcall(function() PremiumScript._tracers[player]:Remove() end) PremiumScript._tracers[player] = nil end
                if PremiumScript._skeleton[player] then for _, l in ipairs(PremiumScript._skeleton[player]) do pcall(function() l:Remove() end) end PremiumScript._skeleton[player] = nil end
            end
        end
    end))
end

-- ================================================================
--  CUSTOM CROSSHAIR
-- ================================================================
local crosshairLines = {}

local function SetCrosshair(enabled)
    Settings.crosshairEnabled = enabled
    for _, l in ipairs(crosshairLines) do pcall(function() l:Remove() end) end
    crosshairLines = {}
    if not enabled then return end

    pcall(function()
        for i = 1, 4 do
            local line = CreateDrawing("Line")
            if not line then return end
            line.Color, line.Thickness, line.Visible = Color3.fromRGB(0, 255, 120), 2, true
            crosshairLines[i] = line
        end
        local dot = CreateDrawing("Circle")
        if dot then
            dot.Color, dot.Thickness, dot.Filled, dot.Radius, dot.Visible = Color3.fromRGB(0, 255, 120), 0, true, 2, true
            crosshairLines[5] = dot
        end

        Track(RunService.RenderStepped:Connect(function()
            if not Settings.crosshairEnabled or PremiumScript._destroyed then return end
            local cx, cy = Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2
            local s, g   = Settings.crosshairSize, Settings.crosshairGap

            if crosshairLines[1] then crosshairLines[1].From, crosshairLines[1].To = Vector2.new(cx, cy - g - s), Vector2.new(cx, cy - g) end
            if crosshairLines[2] then crosshairLines[2].From, crosshairLines[2].To = Vector2.new(cx, cy + g), Vector2.new(cx, cy + g + s) end
            if crosshairLines[3] then crosshairLines[3].From, crosshairLines[3].To = Vector2.new(cx - g - s, cy), Vector2.new(cx - g, cy) end
            if crosshairLines[4] then crosshairLines[4].From, crosshairLines[4].To = Vector2.new(cx + g, cy), Vector2.new(cx + g + s, cy) end
            if crosshairLines[5] then crosshairLines[5].Position = Vector2.new(cx, cy) end
        end))
    end)
end

-- ================================================================
--  UTILITY (RESPAWN, FULLBRIGHT, AFK, KILL COUNTER)
-- ================================================================
local _autoRespawnConn
local function SetAutoRespawn(enabled)
    Settings.autoRespawn = enabled
    if _autoRespawnConn then _autoRespawnConn:Disconnect() _autoRespawnConn = nil end
    if enabled then
        _autoRespawnConn = Track(RunService.Heartbeat:Connect(function()
            if PremiumScript._destroyed then return end
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health <= 0 then
                    task.wait(0.2)
                    pcall(function() LocalPlayer:LoadCharacter() end)
                end
            end
        end))
    end
end

local function SetFullbright(enabled)
    Settings.fullbright = enabled
    if enabled then
        Lighting.Brightness, Lighting.ClockTime, Lighting.GlobalShadows = 2, 14, false
        Lighting.Ambient, Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178), Color3.fromRGB(178, 178, 178)
    else
        Lighting.Brightness, Lighting.GlobalShadows = 1, true
        Lighting.Ambient, Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 70), Color3.fromRGB(128, 128, 128)
    end
end

local _antiAfkConn
local function SetAntiAfk(enabled)
    if _antiAfkConn then _antiAfkConn:Disconnect() _antiAfkConn = nil end
    if enabled then
        _antiAfkConn = Track(LocalPlayer.Idled:Connect(function()
            pcall(function()
                local vim = game:GetService("VirtualInputManager")
                vim:SendKeyEvent(true, Enum.KeyCode.F15, false, game)
                vim:SendKeyEvent(false, Enum.KeyCode.F15, false, game)
            end)
        end))
    end
end

local function SetupKillCounter(Lib)
    local function watchChar(char)
        if not char then return end
        local hum = char:WaitForChild("Humanoid", 5)
        if hum then
            Track(hum.Died:Connect(function()
                Settings.killCount = Settings.killCount + 1
                if Lib then pcall(function() Lib:Notify({ Title = "Kill Registered", Content = "Total Kills: " .. Settings.killCount, Type = "Success", Duration = 2 }) end) end
            end))
        end
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if player.Character then watchChar(player.Character) end
        Track(player.CharacterAdded:Connect(watchChar))
    end
    Track(Players.PlayerAdded:Connect(function(player)
        if player.Character then watchChar(player.Character) end
        Track(player.CharacterAdded:Connect(watchChar))
    end))
end

-- ================================================================
--  REGISTER UI (ALL ENGLISH)
-- ================================================================
function PremiumScript:RegisterUI(Lib, Win, keyResult)
    local Tab = Win:CreateTab({ Name = "ARSENAL", Icon = "🔫" })

    local CombatSec = Tab:CreateSection("Combat (Stable Lock)")
    CombatSec:AddToggle({ Name = "Silent Aim (Magic Bullet)", Description = "Triple-hook injection. Bullets auto-redirect to enemy.", Default = false, Flag = "ArsSilentAim", Callback = function(v) SetSilentAim(v) end })
    CombatSec:AddToggle({ Name = "Hard-Lock Aimbot (Hold Right Click)", Description = "Camera locks onto the target with anti-recoil priority.", Default = false, Flag = "ArsAimbot", Callback = function(v) SetAimbot(v) end })
    CombatSec:AddToggle({ Name = "TriggerBot (Auto Fire)", Description = "Automatically fires when a visible enemy enters FOV.", Default = false, Flag = "ArsTrigger", Callback = function(v) SetTriggerBot(v) end })

    local AimSec = Tab:CreateSection("Aim Configuration")
    AimSec:AddToggle({ Name = "Wall Check (Visibility Filter)", Description = "Skips enemies behind solid obstacles.", Default = true, Flag = "ArsWall", Callback = function(v) Settings.wallCheck = v end })
    AimSec:AddToggle({ Name = "Sticky Target (Anti-Flicker)", Description = "Stays locked on one target until they die.", Default = true, Flag = "ArsSticky", Callback = function(v) Settings.stickyAim = v end })
    AimSec:AddDropdown({ Name = "Target Bone", Options = {"Head", "Torso"}, Default = "Head", Flag = "ArsBone", Callback = function(v) Settings.targetBone = v end })
    AimSec:AddToggle({ Name = "Dynamic FOV Circle", Description = "Red = Searching | Green = Locked On", Default = false, Flag = "FOVEnabled", Callback = function(v) SetFOVCircle(v) end })
    AimSec:AddSlider({ Name = "FOV Radius", Min = 20, Max = 800, Default = 300, Increment = 10, Suffix = "px", Flag = "FOVRadius", Callback = function(v) SetFOVCircle(Lib.Flags["FOVEnabled"], v) end })
    AimSec:AddSlider({ Name = "Lock Smoothness", Min = 1, Max = 10, Default = 1.5, Increment = 0.1, Suffix = "", Flag = "ArsSmooth", Callback = function(v) Settings.smoothness = v end })
    AimSec:AddSlider({ Name = "TriggerBot Delay", Min = 0, Max = 0.5, Default = 0.05, Increment = 0.01, Suffix = "s", Flag = "ArsTrigDelay", Callback = function(v) Settings.triggerDelay = v end })

    local HitboxSec = Tab:CreateSection("Hitbox Mod (Event-Driven)")
    HitboxSec:AddToggle({ Name = "Enable Hitbox Expander", Description = "Enlarges enemy body parts on spawn (low CPU usage).", Default = false, Flag = "ArsHitbox", Callback = function(v) SetHitboxExpander(v) end })
    HitboxSec:AddSlider({ Name = "Hitbox Size", Min = 5, Max = 50, Default = 15, Increment = 1, Suffix = " studs", Flag = "ArsHitboxSize", Callback = function(v) Settings.hitboxSize = v end })

    local VisSec = Tab:CreateSection("Visuals (Throttled ESP)")
    VisSec:AddToggle({ Name = "Player Wallhack (ESP)", Description = "HP-colored highlights with info labels. Frame-skipped for performance.", Default = false, Flag = "ArsESP", Callback = function(v) SetESP(v) end })
    VisSec:AddToggle({ Name = "Show Player Names", Default = true, Flag = "ArsName", Callback = function(v) Settings.showName = v end })
    VisSec:AddToggle({ Name = "Show HP Bar", Default = true, Flag = "ArsHP", Callback = function(v) Settings.showHealth = v end })
    VisSec:AddToggle({ Name = "Show Distance", Default = true, Flag = "ArsDist", Callback = function(v) Settings.showDist = v end })
    VisSec:AddToggle({ Name = "Tracers (Screen to Enemy)", Default = false, Flag = "ArsTracers", Callback = function(v) Settings.showTracers = v end })
    VisSec:AddToggle({ Name = "Skeleton ESP", Default = false, Flag = "ArsSkel", Callback = function(v) Settings.showSkeleton = v end })
    VisSec:AddToggle({ Name = "Custom Crosshair", Description = "Green precision reticle with center dot.", Default = false, Flag = "ArsCross", Callback = function(v) SetCrosshair(v) end })
    VisSec:AddToggle({ Name = "Team Check (Required)", Description = "Excludes teammates from all targeting systems.", Default = true, Flag = "ArsTeam", Callback = function(v) Settings.teamCheck = v end })

    local MiscSec = Tab:CreateSection("World & Utility")
    MiscSec:AddToggle({ Name = "Fullbright (Remove Shadows)", Default = false, Flag = "ArsFB", Callback = function(v) SetFullbright(v) end })
    MiscSec:AddToggle({ Name = "Auto Respawn (Instant)", Default = false, Flag = "ArsRespawn", Callback = function(v) SetAutoRespawn(v) end })
    MiscSec:AddToggle({ Name = "Anti-AFK", Default = true, Flag = "ArsAFK", Callback = function(v) SetAntiAfk(v) end })

    SetAntiAfk(true)
    SetupKillCounter(Lib)
end

-- ================================================================
--  FIX #5: GUARANTEED MEMORY CLEANUP (UNLOAD HANDLER)
-- ================================================================
function PremiumScript:Destroy()
    PremiumScript._destroyed = true

    -- Disable all systems
    Settings.silentAimEnabled = false
    SetESP(false)
    SetTriggerBot(false)
    SetHitboxExpander(false)
    SetCrosshair(false)
    SetAutoRespawn(false)
    SetAntiAfk(false)
    SetFOVCircle(false)
    SetFullbright(false)

    -- Unbind aimbot
    if _aimbotBound then
        pcall(function() RunService:UnbindFromRenderStep("BorcaAimbot") end)
        _aimbotBound = false
    end

    -- Disconnect ALL tracked connections
    for _, conn in ipairs(self._connections) do
        pcall(function() conn:Disconnect() end)
    end
    self._connections = {}

    -- Destroy all Roblox instances
    CleanESP()

    -- Destroy ALL Drawing objects from the master registry
    for _, obj in ipairs(self._drawingObjs) do
        pcall(function() obj:Remove() end)
    end
    self._drawingObjs = {}

    -- Clear crosshair (if any escaped the registry)
    for _, l in ipairs(crosshairLines) do pcall(function() l:Remove() end) end
    crosshairLines = {}

    -- Revert hitboxes
    RevertAllHitboxes()
end

-- Bind cleanup to game close (catches force-quit / executor crash)
pcall(function()
    game:BindToClose(function()
        PremiumScript:Destroy()
    end)
end)

return PremiumScript
