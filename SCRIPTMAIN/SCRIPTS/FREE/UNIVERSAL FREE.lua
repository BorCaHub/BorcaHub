--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║  BorcaHub  •  Premium / Universal.lua  v6.0.0                ║
    ║                                                              ║
    ║  ULTIMATE Universal feature set for PREMIUM tier.            ║
    ║  Hardened, optimized, zero deprecated APIs, leak-free.       ║
    ║                                                              ║
    ║  Exposed API (populated at module load, before RegisterUI):  ║
    ║    PremiumScript.Features  — { name → { Set = fn } }        ║
    ║    PremiumScript:RegisterUI(Lib, Win, keyResult)             ║
    ║    PremiumScript:Destroy()                                   ║
    ╚══════════════════════════════════════════════════════════════╝
--]]

-- ================================================================
--  SERVICES
-- ================================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local Lighting         = game:GetService("Lighting")
local TeleportService  = game:GetService("TeleportService")
local HttpService      = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

-- ================================================================
--  MODULE
-- ================================================================

local PremiumScript = {
    Features     = {},    -- Populated after all feature functions are defined
    _connections = {},
    _highlights  = {},
    _drawings    = {},
    _billboards  = {},    -- BillboardGuis stored separately (CoreGui parented)
    _lib         = nil,
    _win         = nil,
    _version     = "6.0.0",
}

-- ================================================================
--  ESP GUI FOLDER (Fix #6: CoreGui-based BillboardGuis)
-- ================================================================

local _espGuiFolder

local function GetESPFolder()
    if _espGuiFolder and _espGuiFolder.Parent then return _espGuiFolder end
    local ok = pcall(function()
        _espGuiFolder = Instance.new("Folder")
        _espGuiFolder.Name = "BorcaESP_Guis"
        _espGuiFolder.Parent = game:GetService("CoreGui")
    end)
    -- Fallback to PlayerGui if CoreGui access is denied by executor
    if not ok or not _espGuiFolder or not _espGuiFolder.Parent then
        _espGuiFolder = Instance.new("Folder")
        _espGuiFolder.Name = "BorcaESP_Guis"
        _espGuiFolder.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
    return _espGuiFolder
end

-- ================================================================
--  UTILITY CORE
-- ================================================================

local function Track(conn)
    if conn then table.insert(PremiumScript._connections, conn) end
    return conn
end

local function SafeDisconnect(conn)
    if conn then pcall(function() conn:Disconnect() end) end
    return nil
end

local function CleanDraw(key)
    local d = PremiumScript._drawings[key]
    if d then pcall(function() d:Remove() end) end
    PremiumScript._drawings[key] = nil
end

local function MakeDraw(key, dtype)
    CleanDraw(key)
    local ok, d = pcall(Drawing.new, dtype)
    if ok and d then
        PremiumScript._drawings[key] = d
        return d
    end
    return nil
end

local function GetMousePos()
    return UserInputService:GetMouseLocation()
end

local function IsAlive(player)
    player = player or LocalPlayer
    local char = player and player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    return true, char, hum, root
end

-- Cached RaycastParams (Fix #3: avoid per-frame allocation)
local _sharedRayParams = RaycastParams.new()
_sharedRayParams.FilterType = Enum.RaycastFilterType.Exclude
_sharedRayParams.IgnoreWater = true

local function WallCheck(origin, target, ignoreList)
    _sharedRayParams.FilterDescendantsInstances = ignoreList
    local result = Workspace:Raycast(origin, target - origin, _sharedRayParams)
    if not result then return true end
    return false, result
end

local function GetColorFromHealth(health, maxHealth)
    local pct = math.clamp(health / maxHealth, 0, 1)
    if pct > 0.5 then
        return Color3.fromRGB(255 * (1 - pct) * 2, 255, 0)
    else
        return Color3.fromRGB(255, 255 * pct * 2, 0)
    end
end

local function Notify(lib, title, content, ntype, dur)
    if lib and lib.Notify then
        pcall(function()
            lib:Notify({
                Title = title or "BorcaHub",
                Content = content or "",
                Type = ntype or "Info",
                Duration = dur or 3,
            })
        end)
    end
end

local function GetClosestPartOnChar(char, screenPos)
    local cam = Workspace.CurrentCamera
    local closest, dist = nil, math.huge
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") then
            local pos, onScreen = cam:WorldToViewportPoint(part.Position)
            if onScreen then
                local d = (Vector2.new(pos.X, pos.Y) - screenPos).Magnitude
                if d < dist then dist = d; closest = part end
            end
        end
    end
    return closest
end

local function GetCurrentWeapon(char)
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then return child.Name end
    end
    return nil
end

-- ================================================================
--  INPUT TRACKER (Fix #5: WindowFocusReleased clears stuck keys)
-- ================================================================

local KeysDown = {}

Track(UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe then KeysDown[input.KeyCode] = true end
end))

Track(UserInputService.InputEnded:Connect(function(input)
    KeysDown[input.KeyCode] = nil
end))

-- Fix #5: Clear all keys when window loses focus (Alt+Tab safety)
Track(UserInputService.WindowFocusReleased:Connect(function()
    table.clear(KeysDown)
end))

local function IsKeyDown(kc) return KeysDown[kc] == true end

-- ================================================================
--  FEATURE: WALK SPEED
-- ================================================================

local _speedLoop
local _currentSpeed = 16

local function SetWalkSpeed(speed)
    _currentSpeed = speed
    _speedLoop = SafeDisconnect(_speedLoop)
    _speedLoop = Track(RunService.Heartbeat:Connect(function()
        local alive, _, hum = IsAlive()
        if alive then hum.WalkSpeed = _currentSpeed end
    end))
end

-- ================================================================
--  FEATURE: JUMP POWER
-- ================================================================

local _jumpLoop
local _currentJump = 50

local function SetJumpPower(power)
    _currentJump = power
    _jumpLoop = SafeDisconnect(_jumpLoop)
    _jumpLoop = Track(RunService.Heartbeat:Connect(function()
        local alive, _, hum = IsAlive()
        if alive then
            hum.UseJumpPower = true
            hum.JumpPower = _currentJump
        end
    end))
end

-- ================================================================
--  FEATURE: INFINITE JUMP
-- ================================================================

local _infJumpConn

local function SetInfiniteJump(enabled)
    _infJumpConn = SafeDisconnect(_infJumpConn)
    if enabled then
        _infJumpConn = Track(UserInputService.JumpRequest:Connect(function()
            local alive, _, hum = IsAlive()
            if alive and hum:GetState() ~= Enum.HumanoidStateType.Dead then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end))
    end
end

-- ================================================================
--  FEATURE: BUNNY HOP
-- ================================================================

local _bhopConn

local function SetBunnyHop(enabled)
    _bhopConn = SafeDisconnect(_bhopConn)
    if enabled then
        _bhopConn = Track(RunService.Heartbeat:Connect(function()
            local alive, _, hum = IsAlive()
            if alive and hum:GetState() == Enum.HumanoidStateType.Running
                and hum.MoveDirection.Magnitude > 0 then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end))
    end
end

-- ================================================================
--  FEATURE: NO CLIP
-- ================================================================

local _noclipConn

local function SetNoclip(enabled)
    _noclipConn = SafeDisconnect(_noclipConn)
    if enabled then
        _noclipConn = Track(RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if not char then return end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end))
    else
        pcall(function()
            local char = LocalPlayer.Character
            if char then
                for _, p in ipairs(char:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = true end
                end
            end
        end)
    end
end

-- ================================================================
--  FEATURE: ADVANCED FLY
--  Fix #3: Uses LinearVelocity + AlignOrientation (modern constraints)
-- ================================================================

local _flyEnabled   = false
local _flySpeed     = 60
local _flyElytra    = false
local _flyConn
local _flyVelocity  = Vector3.zero
local _flyLV, _flyAO, _flyAttach

local function CleanFlyConstraints()
    if _flyAttach then pcall(function() _flyAttach:Destroy() end) _flyAttach = nil end
    if _flyLV then pcall(function() _flyLV:Destroy() end) _flyLV = nil end
    if _flyAO then pcall(function() _flyAO:Destroy() end) _flyAO = nil end
end

local function EnsureFlyConstraints(root)
    -- If constraints already exist and are parented correctly, reuse them
    if _flyAttach and _flyAttach.Parent == root
        and _flyLV and _flyLV.Parent == root
        and _flyAO and _flyAO.Parent == root then
        return true
    end

    CleanFlyConstraints()

    _flyAttach = Instance.new("Attachment")
    _flyAttach.Name = "BorcaFlyAttach"
    _flyAttach.Parent = root

    _flyLV = Instance.new("LinearVelocity")
    _flyLV.Name = "BorcaFlyLV"
    _flyLV.Attachment0 = _flyAttach
    _flyLV.MaxForce = 1e6
    _flyLV.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    _flyLV.RelativeTo = Enum.ActuatorRelativeTo.World
    _flyLV.VectorVelocity = Vector3.zero
    _flyLV.Parent = root

    _flyAO = Instance.new("AlignOrientation")
    _flyAO.Name = "BorcaFlyAO"
    _flyAO.Attachment0 = _flyAttach
    _flyAO.Mode = Enum.OrientationAlignmentMode.OneAttachment
    _flyAO.RigidityEnabled = true
    _flyAO.Parent = root

    return true
end

local function SetFly(enabled, speed)
    _flyEnabled = enabled
    if speed then _flySpeed = speed end
    _flyConn = SafeDisconnect(_flyConn)

    if not enabled then
        CleanFlyConstraints()
        _flyVelocity = Vector3.zero
        local alive, _, hum = IsAlive()
        if alive then hum.PlatformStand = false end
        return
    end

    local alive, _, hum, root = IsAlive()
    if not alive then return end
    hum.PlatformStand = true
    EnsureFlyConstraints(root)

    _flyConn = Track(RunService.RenderStepped:Connect(function(dt)
        local isAlive, _, h, r = IsAlive()
        if not isAlive then return end

        h.PlatformStand = true
        r.AssemblyLinearVelocity = Vector3.zero

        -- Re-create constraints if character respawned
        if not EnsureFlyConstraints(r) then return end

        local cam = Workspace.CurrentCamera
        local targetDir = Vector3.zero
        local sprintMult = IsKeyDown(Enum.KeyCode.LeftShift) and 2.5 or 1

        if IsKeyDown(Enum.KeyCode.W) then targetDir = targetDir + cam.CFrame.LookVector end
        if IsKeyDown(Enum.KeyCode.S) then targetDir = targetDir - cam.CFrame.LookVector end
        if IsKeyDown(Enum.KeyCode.A) then targetDir = targetDir - cam.CFrame.RightVector end
        if IsKeyDown(Enum.KeyCode.D) then targetDir = targetDir + cam.CFrame.RightVector end
        if IsKeyDown(Enum.KeyCode.Space) or IsKeyDown(Enum.KeyCode.E) then
            targetDir = targetDir + Vector3.new(0, 1, 0)
        end
        if IsKeyDown(Enum.KeyCode.Q) then
            targetDir = targetDir - Vector3.new(0, 1, 0)
        end

        if targetDir.Magnitude > 0 then targetDir = targetDir.Unit * _flySpeed * sprintMult end

        -- Smooth acceleration / deceleration via lerp
        local lerpFactor = math.clamp(dt * 8, 0, 1)
        _flyVelocity = _flyVelocity:Lerp(targetDir, lerpFactor)

        if _flyElytra and targetDir.Magnitude == 0 then
            _flyVelocity = _flyVelocity:Lerp(
                Vector3.new(_flyVelocity.X * 0.99, -8, _flyVelocity.Z * 0.99),
                lerpFactor
            )
        end

        -- Apply via modern constraints
        _flyLV.VectorVelocity = _flyVelocity
        _flyAO.CFrame = cam.CFrame
    end))
end

-- ================================================================
--  FEATURE: CFRAME SPEED
-- ================================================================

local _cframeSpeedConn
local _cframeSpeedVal = 2

local function SetCFrameSpeed(enabled, multiplier)
    if multiplier then _cframeSpeedVal = multiplier end
    _cframeSpeedConn = SafeDisconnect(_cframeSpeedConn)
    if enabled then
        _cframeSpeedConn = Track(RunService.RenderStepped:Connect(function()
            local alive, _, hum, root = IsAlive()
            if alive and hum.MoveDirection.Magnitude > 0 then
                root.CFrame = root.CFrame + (hum.MoveDirection * _cframeSpeedVal)
            end
        end))
    end
end

-- ================================================================
--  FEATURE: LONG JUMP (Fix #3: AssemblyLinearVelocity)
-- ================================================================

local _longJumpConn
local _longJumpPower = 120

local function SetLongJump(enabled, power)
    if power then _longJumpPower = power end
    _longJumpConn = SafeDisconnect(_longJumpConn)
    if enabled then
        _longJumpConn = Track(RunService.Heartbeat:Connect(function()
            local alive, _, hum, root = IsAlive()
            if not alive then return end
            local state = hum:GetState()
            if (state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall)
                and hum.MoveDirection.Magnitude > 0 then
                local vel = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = Vector3.new(
                    hum.MoveDirection.X * _longJumpPower,
                    vel.Y,
                    hum.MoveDirection.Z * _longJumpPower
                )
            end
        end))
    end
end

-- ================================================================
--  FEATURE: SPIDER CLIMB (Fix #3: AssemblyLinearVelocity)
-- ================================================================

local _spiderConn

local function SetSpiderClimb(enabled)
    _spiderConn = SafeDisconnect(_spiderConn)
    if enabled then
        local spiderRayParams = RaycastParams.new()
        spiderRayParams.FilterType = Enum.RaycastFilterType.Exclude

        _spiderConn = Track(RunService.Heartbeat:Connect(function()
            local alive, char, hum, root = IsAlive()
            if not alive then return end

            spiderRayParams.FilterDescendantsInstances = {char}
            local direction = root.CFrame.LookVector * 3
            local result = Workspace:Raycast(root.Position, direction, spiderRayParams)

            if result and hum.MoveDirection.Magnitude > 0 then
                local vel = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = Vector3.new(vel.X, 50, vel.Z)
            end
        end))
    end
end

-- ================================================================
--  FEATURE: CLICK TELEPORT
-- ================================================================

local _clickTpConn

local function SetClickTP(enabled)
    _clickTpConn = SafeDisconnect(_clickTpConn)
    if enabled then
        _clickTpConn = Track(UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1
                and IsKeyDown(Enum.KeyCode.LeftControl) then
                local mouse = LocalPlayer:GetMouse()
                local alive, _, _, root = IsAlive()
                if alive and mouse.Hit then
                    root.CFrame = mouse.Hit + Vector3.new(0, 5, 0)
                end
            end
        end))
    end
end

-- ================================================================
--  FEATURE: SPIN BOT
-- ================================================================

local _spinConn
local _spinSpeed = 20

local function SetSpinBot(enabled, speed)
    if speed then _spinSpeed = speed end
    _spinConn = SafeDisconnect(_spinConn)
    if enabled then
        _spinConn = Track(RunService.RenderStepped:Connect(function()
            local alive, _, _, root = IsAlive()
            if alive then
                root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(_spinSpeed), 0)
            end
        end))
    end
end

-- ================================================================
--  FEATURE: FREEZE CHARACTER (Fix #3: AssemblyLinearVelocity)
-- ================================================================

local _freezeConn
local _frozenPos

local function SetFreeze(enabled)
    _freezeConn = SafeDisconnect(_freezeConn)
    if enabled then
        local alive, _, _, root = IsAlive()
        if alive then
            _frozenPos = root.CFrame
            _freezeConn = Track(RunService.Heartbeat:Connect(function()
                local isAlive, _, _, r = IsAlive()
                if isAlive and _frozenPos then
                    r.CFrame = _frozenPos
                    r.AssemblyLinearVelocity = Vector3.zero
                    r.AssemblyAngularVelocity = Vector3.zero
                end
            end))
        end
    else
        _frozenPos = nil
    end
end

-- ================================================================
--  FEATURE: CHARACTER SCALE
-- ================================================================

local function SetCharacterScale(headScale, bodyWidth, bodyHeight, bodyDepth)
    local alive, _, humanoid = IsAlive()
    if not alive then return end
    pcall(function()
        local hs = humanoid:FindFirstChild("HeadScale")
        local bw = humanoid:FindFirstChild("BodyWidthScale")
        local bh = humanoid:FindFirstChild("BodyHeightScale")
        local bd = humanoid:FindFirstChild("BodyDepthScale")
        if hs then hs.Value = headScale end
        if bw then bw.Value = bodyWidth end
        if bh then bh.Value = bodyHeight end
        if bd then bd.Value = bodyDepth end
    end)
end

-- ================================================================
--  FEATURE: HIP HEIGHT
-- ================================================================

local _hipHeightConn
local _hipHeightVal = 0

local function SetHipHeight(val)
    _hipHeightVal = val
    _hipHeightConn = SafeDisconnect(_hipHeightConn)
    _hipHeightConn = Track(RunService.Heartbeat:Connect(function()
        local alive, _, hum = IsAlive()
        if alive then hum.HipHeight = _hipHeightVal end
    end))
end

-- ================================================================
--  FEATURE: ANTI-FALL DAMAGE
-- ================================================================

local _antiFallConn

local function SetAntiFallDamage(enabled)
    _antiFallConn = SafeDisconnect(_antiFallConn)
    if enabled then
        _antiFallConn = Track(RunService.Heartbeat:Connect(function()
            local alive, _, hum = IsAlive()
            if alive then
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            end
        end))
    else
        local alive, _, hum = IsAlive()
        if alive then
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
        end
    end
end

-- ================================================================
--  FEATURE: AUTO RESPAWN
-- ================================================================

local _autoRespawnConn

local function SetAutoRespawn(enabled)
    _autoRespawnConn = SafeDisconnect(_autoRespawnConn)
    if enabled then
        _autoRespawnConn = Track(LocalPlayer.CharacterAdded:Connect(function(char)
            local hum = char:WaitForChild("Humanoid", 10)
            if hum then
                hum.Died:Connect(function()
                    task.wait(0.5)
                    pcall(function() LocalPlayer:LoadCharacter() end)
                end)
            end
        end))
    end
end

-- ================================================================
--  FEATURE: SAVED POSITIONS
-- ================================================================

local _savedPositions = {}

local function SavePosition(slot)
    local alive, _, _, root = IsAlive()
    if alive then _savedPositions[slot] = root.CFrame; return true end
    return false
end

local function LoadPosition(slot)
    local alive, _, _, root = IsAlive()
    local cf = _savedPositions[slot]
    if alive and cf then root.CFrame = cf; return true end
    return false
end

-- ================================================================
--  FEATURE: TP WALK
-- ================================================================

local _tpWalkConn
local _tpWalkDist = 3

local function SetTPWalk(enabled, dist)
    if dist then _tpWalkDist = dist end
    _tpWalkConn = SafeDisconnect(_tpWalkConn)
    if enabled then
        _tpWalkConn = Track(RunService.RenderStepped:Connect(function()
            local alive, _, hum, root = IsAlive()
            if alive and hum.MoveDirection.Magnitude > 0 then
                root.CFrame = root.CFrame + (hum.MoveDirection * _tpWalkDist)
            end
        end))
    end
end

-- ================================================================
--  FEATURE: FAKE LAG (Fix #3: AssemblyLinearVelocity)
-- ================================================================

local _fakeLagConn
local _fakeLagTick = 0
local _fakeLagInterval = 5

local function SetFakeLag(enabled, interval)
    if interval then _fakeLagInterval = interval end
    _fakeLagConn = SafeDisconnect(_fakeLagConn)
    _fakeLagTick = 0
    if enabled then
        _fakeLagConn = Track(RunService.Heartbeat:Connect(function()
            _fakeLagTick = _fakeLagTick + 1
            local alive, _, _, root = IsAlive()
            if not alive then return end
            if _fakeLagTick % _fakeLagInterval ~= 0 then
                root.AssemblyLinearVelocity = Vector3.zero
            end
        end))
    end
end

-- ================================================================
--  FEATURE: STRAFE (Fix #3: AssemblyLinearVelocity)
-- ================================================================

local _strafeConn

local function SetStrafe(enabled)
    _strafeConn = SafeDisconnect(_strafeConn)
    if enabled then
        _strafeConn = Track(RunService.RenderStepped:Connect(function()
            local alive, _, hum, root = IsAlive()
            if not alive then return end
            if hum:GetState() == Enum.HumanoidStateType.Freefall
                and hum.MoveDirection.Magnitude > 0 then
                local vel = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = Vector3.new(
                    hum.MoveDirection.X * hum.WalkSpeed,
                    vel.Y,
                    hum.MoveDirection.Z * hum.WalkSpeed
                )
            end
        end))
    end
end

-- ================================================================
--  FEATURE: MOON JUMP (Fix #3: AssemblyLinearVelocity)
-- ================================================================

local _moonJumpConn

local function SetMoonJump(enabled)
    _moonJumpConn = SafeDisconnect(_moonJumpConn)
    if enabled then
        _moonJumpConn = Track(RunService.Heartbeat:Connect(function()
            local alive, _, hum, root = IsAlive()
            if not alive then return end
            if hum:GetState() == Enum.HumanoidStateType.Freefall
                and IsKeyDown(Enum.KeyCode.Space) then
                local vel = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = Vector3.new(vel.X, 25, vel.Z)
            end
        end))
    end
end

-- ================================================================
--  FEATURE: ANNOY PLAYER
--  Fix #4: Target search runs on a 0.5s cycle, orbit uses Heartbeat
-- ================================================================

local _annoyConn
local _annoySearchTask
local _annoyRadius   = 8
local _annoyAngle    = 0
local _annoyTarget   = nil  -- Cached target root part

local function SetAnnoy(enabled, radius)
    if radius then _annoyRadius = radius end
    _annoyConn = SafeDisconnect(_annoyConn)
    _annoyAngle = 0
    _annoyTarget = nil

    if _annoySearchTask then
        pcall(function() task.cancel(_annoySearchTask) end)
        _annoySearchTask = nil
    end

    if enabled then
        -- Separate task: find closest player every 0.5 seconds
        _annoySearchTask = task.spawn(function()
            while true do
                local myAlive, _, _, myRoot = IsAlive()
                if myAlive then
                    local closest, minDist = nil, math.huge
                    for _, player in ipairs(Players:GetPlayers()) do
                        if player == LocalPlayer then continue end
                        local alive, _, _, pRoot = IsAlive(player)
                        if alive then
                            local d = (myRoot.Position - pRoot.Position).Magnitude
                            if d < minDist then minDist = d; closest = pRoot end
                        end
                    end
                    _annoyTarget = closest
                else
                    _annoyTarget = nil
                end
                task.wait(0.5)
            end
        end)

        -- Heartbeat: just orbit the already-locked target
        _annoyConn = Track(RunService.Heartbeat:Connect(function(dt)
            local myAlive, _, _, myRoot = IsAlive()
            if not myAlive or not _annoyTarget or not _annoyTarget.Parent then return end

            _annoyAngle = _annoyAngle + dt * 5
            local offset = Vector3.new(
                math.cos(_annoyAngle) * _annoyRadius,
                0,
                math.sin(_annoyAngle) * _annoyRadius
            )
            myRoot.CFrame = CFrame.new(_annoyTarget.Position + offset, _annoyTarget.Position)
        end))
    end
end

-- ================================================================
--  FEATURE: AUTO WALK
-- ================================================================

local _autoWalkConn

local function SetAutoWalk(enabled)
    _autoWalkConn = SafeDisconnect(_autoWalkConn)
    if enabled then
        _autoWalkConn = Track(RunService.Heartbeat:Connect(function()
            local alive, _, hum = IsAlive()
            if alive then hum:Move(Workspace.CurrentCamera.CFrame.LookVector) end
        end))
    end
end

-- ================================================================
--  FEATURE: TRAIL EFFECT
-- ================================================================

local _trailParts = {}
local _trailConn
local _trailColor = Color3.fromRGB(100, 200, 255)

local function CleanTrail()
    _trailConn = SafeDisconnect(_trailConn)
    for _, p in ipairs(_trailParts) do pcall(function() p:Destroy() end) end
    table.clear(_trailParts)
end

local function SetTrail(enabled, color)
    if color then _trailColor = color end
    CleanTrail()
    if enabled then
        _trailConn = Track(RunService.RenderStepped:Connect(function()
            local alive, _, _, root = IsAlive()
            if not alive then return end

            local part = Instance.new("Part")
            part.Anchored = true
            part.CanCollide = false
            part.Size = Vector3.new(1, 1, 1)
            part.Position = root.Position - Vector3.new(0, 2.5, 0)
            part.Material = Enum.Material.Neon
            part.Color = _trailColor
            part.Transparency = 0.3
            part.Shape = Enum.PartType.Ball
            part.Parent = Workspace

            table.insert(_trailParts, part)

            task.spawn(function()
                for i = 0.3, 1, 0.05 do
                    part.Transparency = i
                    part.Size = part.Size * 0.95
                    task.wait(0.03)
                end
                part:Destroy()
                for idx, p in ipairs(_trailParts) do
                    if p == part then table.remove(_trailParts, idx) break end
                end
            end)
        end))
    end
end

-- ================================================================
--  FEATURE: PERSISTENT FULLBRIGHT
-- ================================================================

local _fullbrightLoop
local _savedLighting = {}

local function SaveLighting()
    _savedLighting = {
        Brightness     = Lighting.Brightness,
        ClockTime      = Lighting.ClockTime,
        FogEnd         = Lighting.FogEnd,
        GlobalShadows  = Lighting.GlobalShadows,
        Ambient        = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
    }
end

local function SetFullbright(enabled)
    _fullbrightLoop = SafeDisconnect(_fullbrightLoop)
    if enabled then
        SaveLighting()
        _fullbrightLoop = Track(RunService.RenderStepped:Connect(function()
            Lighting.Brightness     = 2
            Lighting.ClockTime      = 14
            Lighting.FogEnd         = 1e6
            Lighting.GlobalShadows  = false
            Lighting.Ambient        = Color3.fromRGB(178, 178, 178)
            Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
        end))
    else
        if next(_savedLighting) then
            for k, v in pairs(_savedLighting) do
                pcall(function() Lighting[k] = v end)
            end
        else
            Lighting.Brightness     = 1
            Lighting.GlobalShadows  = true
            Lighting.Ambient        = Color3.fromRGB(70, 70, 70)
            Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
            Lighting.FogEnd         = 10000
        end
    end
end

-- ================================================================
--  FEATURE: CAMERA FOV
-- ================================================================

local _camFovLoop

local function SetCameraFOV(fov)
    _camFovLoop = SafeDisconnect(_camFovLoop)
    _camFovLoop = Track(RunService.RenderStepped:Connect(function()
        Workspace.CurrentCamera.FieldOfView = fov
    end))
end

-- ================================================================
--  FEATURE: REMOVE FOG
-- ================================================================

local _fogLoop

local function SetRemoveFog(enabled)
    _fogLoop = SafeDisconnect(_fogLoop)
    if enabled then
        _fogLoop = Track(RunService.RenderStepped:Connect(function()
            Lighting.FogEnd = 1e9
            Lighting.FogStart = 1e9
            for _, v in ipairs(Lighting:GetDescendants()) do
                if v:IsA("Atmosphere") then v.Density = 0 end
            end
        end))
    end
end

-- ================================================================
--  FEATURE: PREMIUM ESP
--  Fix #1: Complete rendering including Box, HealthBar, Tracer, prune
--  Fix #6: BillboardGuis stored in CoreGui folder, not parented to char
-- ================================================================

local _espEnabled     = false
local _espColor       = Color3.fromRGB(255, 80, 80)
local _espTeamCheck   = false
local _espShowHealth  = true
local _espShowName    = true
local _espShowDist    = true
local _espTracers     = false
local _espBoxes       = false
local _espHealthBar   = false
local _espShowWeapon  = false
local _espLoop

local _chamsEnabled = false
local _chamsColor   = Color3.fromRGB(30, 200, 255)

local function CleanPlayerESP(player)
    -- Destroy Highlight
    local hl = PremiumScript._highlights[player]
    if hl then pcall(function() hl:Destroy() end) end
    PremiumScript._highlights[player] = nil

    -- Destroy BillboardGui from CoreGui folder
    local bb = PremiumScript._billboards[player]
    if bb then pcall(function() bb:Destroy() end) end
    PremiumScript._billboards[player] = nil

    -- Destroy all Drawing objects for this player
    local uid = tostring(player.UserId)
    CleanDraw("Tracer_" .. uid)
    for _, prefix in ipairs({"BoxT_","BoxB_","BoxL_","BoxR_","HealthBarBG_","HealthBarFG_"}) do
        CleanDraw(prefix .. uid)
    end
end

local function CleanAllESP()
    for player, _ in pairs(PremiumScript._highlights) do
        CleanPlayerESP(player)
    end
    table.clear(PremiumScript._highlights)
    table.clear(PremiumScript._billboards)

    -- Also clean any orphaned drawing objects
    local toRemove = {}
    for key, _ in pairs(PremiumScript._drawings) do
        if key:find("Tracer_") or key:find("Box") or key:find("HealthBar") then
            table.insert(toRemove, key)
        end
    end
    for _, key in ipairs(toRemove) do CleanDraw(key) end

    -- Destroy the CoreGui folder itself
    if _espGuiFolder then
        pcall(function() _espGuiFolder:Destroy() end)
        _espGuiFolder = nil
    end
end

local function DrawBox(uid, x1, y1, x2, y2, color)
    local lines = {
        {key = "BoxT_"..uid, from = Vector2.new(x1,y1), to = Vector2.new(x2,y1)},
        {key = "BoxB_"..uid, from = Vector2.new(x1,y2), to = Vector2.new(x2,y2)},
        {key = "BoxL_"..uid, from = Vector2.new(x1,y1), to = Vector2.new(x1,y2)},
        {key = "BoxR_"..uid, from = Vector2.new(x2,y1), to = Vector2.new(x2,y2)},
    }
    for _, info in ipairs(lines) do
        local d = PremiumScript._drawings[info.key] or MakeDraw(info.key, "Line")
        if d then
            d.From = info.from; d.To = info.to; d.Color = color
            d.Thickness = 1; d.Transparency = 1; d.Visible = true
        end
    end
end

local function HideBox(uid)
    for _, prefix in ipairs({"BoxT_","BoxB_","BoxL_","BoxR_"}) do
        local d = PremiumScript._drawings[prefix..uid]
        if d then d.Visible = false end
    end
end

local function DrawHealthBar(uid, x, y1, y2, pct, color)
    local bg = PremiumScript._drawings["HealthBarBG_"..uid] or MakeDraw("HealthBarBG_"..uid, "Line")
    local fg = PremiumScript._drawings["HealthBarFG_"..uid] or MakeDraw("HealthBarFG_"..uid, "Line")
    if bg then
        bg.From = Vector2.new(x - 5, y1); bg.To = Vector2.new(x - 5, y2)
        bg.Color = Color3.fromRGB(40, 40, 40); bg.Thickness = 3
        bg.Transparency = 1; bg.Visible = true
    end
    if fg then
        fg.From = Vector2.new(x - 5, y2); fg.To = Vector2.new(x - 5, y2 - ((y2 - y1) * pct))
        fg.Color = color; fg.Thickness = 2
        fg.Transparency = 1; fg.Visible = true
    end
end

local function HideHealthBar(uid)
    local bg = PremiumScript._drawings["HealthBarBG_"..uid]
    local fg = PremiumScript._drawings["HealthBarFG_"..uid]
    if bg then bg.Visible = false end
    if fg then fg.Visible = false end
end

local function UpdateESP()
    if not _espEnabled then CleanAllESP() return end

    local myAlive, _, _, myRoot = IsAlive()
    local cam = Workspace.CurrentCamera

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end

        local uid = tostring(player.UserId)
        local alive, char, hum, root = IsAlive(player)

        -- Player is dead or has no character: clean up all visuals
        if not alive then
            CleanPlayerESP(player)
            continue
        end

        -- Team check: skip allies
        if _espTeamCheck and player.Team and player.Team == LocalPlayer.Team then
            CleanPlayerESP(player)
            continue
        end

        local head = char:FindFirstChild("Head")
        local rootPos, rootOnScreen = cam:WorldToViewportPoint(root.Position)

        -- ── 1. HIGHLIGHT (parented to character, auto-cleaned on death) ──
        local hl = PremiumScript._highlights[player]
        if not hl or hl.Parent ~= char then
            if hl then pcall(function() hl:Destroy() end) end
            hl = Instance.new("Highlight")
            hl.Name = "BorcaESP_HL"
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = char
            PremiumScript._highlights[player] = hl
        end
        hl.OutlineColor = _espColor; hl.OutlineTransparency = 0
        if _chamsEnabled then
            hl.FillColor = _chamsColor; hl.FillTransparency = 0.45
        else
            hl.FillColor = _espColor; hl.FillTransparency = 1
        end

        -- ── 2. BILLBOARD GUI (Fix #6: parented to CoreGui, Adornee-based) ──
        local bb = PremiumScript._billboards[player]
        if not bb or not bb.Parent then
            if bb then pcall(function() bb:Destroy() end) end
            bb = Instance.new("BillboardGui")
            bb.Name = "BorcaESP_BB_" .. uid
            bb.AlwaysOnTop = true
            bb.Size = UDim2.new(0, 180, 0, 56)
            bb.StudsOffset = Vector3.new(0, 3.5, 0)
            bb.ZIndexBehavior = Enum.ZIndexBehavior.Global
            bb.Parent = GetESPFolder()
            PremiumScript._billboards[player] = bb

            local n = Instance.new("TextLabel", bb)
            n.Name = "NameLbl"; n.BackgroundTransparency = 1
            n.Size = UDim2.new(1,0,0.35,0); n.TextSize = 13
            n.Font = Enum.Font.GothamBold; n.TextStrokeTransparency = 0.15

            local d = Instance.new("TextLabel", bb)
            d.Name = "DistLbl"; d.BackgroundTransparency = 1
            d.Position = UDim2.new(0,0,0.35,0); d.Size = UDim2.new(1,0,0.35,0)
            d.TextSize = 11; d.Font = Enum.Font.Gotham; d.TextStrokeTransparency = 0.15

            local w = Instance.new("TextLabel", bb)
            w.Name = "WeaponLbl"; w.BackgroundTransparency = 1
            w.Position = UDim2.new(0,0,0.7,0); w.Size = UDim2.new(1,0,0.3,0)
            w.TextSize = 10; w.Font = Enum.Font.GothamMedium
            w.TextStrokeTransparency = 0.15; w.TextColor3 = Color3.fromRGB(255,200,50)
        end

        -- Update Adornee to current character head (survives respawn)
        bb.Adornee = head or root

        local nameL = bb:FindFirstChild("NameLbl")
        local distL = bb:FindFirstChild("DistLbl")
        local weapL = bb:FindFirstChild("WeaponLbl")

        if nameL then
            nameL.Visible = _espShowName
            nameL.Text = player.DisplayName .. " (@" .. player.Name .. ")"
            nameL.TextColor3 = _espColor
        end

        if distL then
            local dist = (myAlive and myRoot)
                and math.floor((root.Position - myRoot.Position).Magnitude) or 0
            local parts = {}
            if _espShowDist then table.insert(parts, dist .. " studs") end
            if _espShowHealth then
                table.insert(parts, string.format("%d/%d HP",
                    math.floor(hum.Health), math.floor(hum.MaxHealth)))
            end
            distL.Text = table.concat(parts, " | ")
            distL.TextColor3 = GetColorFromHealth(hum.Health, hum.MaxHealth)
            distL.Visible = _espShowDist or _espShowHealth
        end

        if weapL then
            local weapon = GetCurrentWeapon(char)
            weapL.Visible = _espShowWeapon and weapon ~= nil
            weapL.Text = weapon and ("⚔ " .. weapon) or ""
        end

        -- ── 3. BOX ESP (Drawing API) ──
        if _espBoxes and rootOnScreen and head then
            local headPos = cam:WorldToViewportPoint(head.Position + Vector3.new(0,1,0))
            local footPos = cam:WorldToViewportPoint(root.Position - Vector3.new(0,3,0))
            local boxH = math.abs(footPos.Y - headPos.Y)
            local boxW = boxH * 0.55
            DrawBox(uid,
                rootPos.X - boxW/2, headPos.Y,
                rootPos.X + boxW/2, footPos.Y,
                _espColor)
        else
            HideBox(uid)
        end

        -- ── 4. HEALTH BAR (Drawing API) ──
        if _espHealthBar and rootOnScreen and head then
            local headPos = cam:WorldToViewportPoint(head.Position + Vector3.new(0,1,0))
            local footPos = cam:WorldToViewportPoint(root.Position - Vector3.new(0,3,0))
            local boxH = math.abs(footPos.Y - headPos.Y)
            local boxW = boxH * 0.55
            local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            DrawHealthBar(uid,
                rootPos.X - boxW/2, headPos.Y, footPos.Y,
                pct, GetColorFromHealth(hum.Health, hum.MaxHealth))
        else
            HideHealthBar(uid)
        end

        -- ── 5. TRACERS (Drawing API) ──
        local tracerKey = "Tracer_" .. uid
        if _espTracers and rootOnScreen then
            local tracer = PremiumScript._drawings[tracerKey] or MakeDraw(tracerKey, "Line")
            if tracer then
                tracer.Visible = true
                tracer.From = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y)
                tracer.To = Vector2.new(rootPos.X, rootPos.Y)
                tracer.Color = _espColor
                tracer.Thickness = 1.2
                tracer.Transparency = 1
            end
        else
            local t = PremiumScript._drawings[tracerKey]
            if t then t.Visible = false end
        end
    end

    -- ── PRUNE: remove visuals for players who left the game ──
    for player, _ in pairs(PremiumScript._highlights) do
        if not player.Parent then CleanPlayerESP(player) end
    end
    for player, _ in pairs(PremiumScript._billboards) do
        if not player.Parent then CleanPlayerESP(player) end
    end
end

local function SetESP(enabled)
    _espEnabled = enabled
    _espLoop = SafeDisconnect(_espLoop)
    if enabled then
        _espLoop = Track(RunService.RenderStepped:Connect(UpdateESP))
    else
        CleanAllESP()
    end
end

local function SetChams(enabled)
    _chamsEnabled = enabled
end

-- ================================================================
--  FEATURE: AIMBOT (Wall Check + Silent + Prediction)
-- ================================================================

local _aimbotEnabled     = false
local _aimbotWallCheck   = true
local _aimbotSmoothness  = 5
local _aimbotRadius      = 150
local _aimbotPart        = "Head"
local _aimbotSilent      = false
local _aimbotPrediction  = Vector3.zero
local _aimbotPredEnabled = false
local _aimbotConn

local function GetAimTarget()
    local maxDist  = _aimbotRadius
    local target   = nil
    local mousePos = GetMousePos()
    local cam      = Workspace.CurrentCamera
    local myChar   = LocalPlayer.Character

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if _espTeamCheck and player.Team and player.Team == LocalPlayer.Team then continue end

        local alive, char, hum, root = IsAlive(player)
        if not alive then continue end

        local part
        if _aimbotPart == "Closest" then
            part = GetClosestPartOnChar(char, mousePos)
        else
            part = char:FindFirstChild(_aimbotPart) or char:FindFirstChild("Head") or root
        end
        if not part then continue end

        local targetPos = part.Position
        if _aimbotPredEnabled and root then
            targetPos = targetPos + (root.AssemblyLinearVelocity * _aimbotPrediction)
        end

        local pos, onScreen = cam:WorldToViewportPoint(targetPos)
        if not onScreen then continue end

        local dist = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
        if dist >= maxDist then continue end

        -- Wall check with cached raycast params
        if _aimbotWallCheck then
            local clear, result = WallCheck(cam.CFrame.Position, targetPos, {myChar, cam})
            if not clear then
                -- Check if the obstruction IS the target character
                if not (result and result.Instance and result.Instance:IsDescendantOf(char)) then
                    continue
                end
            end
        end

        maxDist = dist
        target = {Part = part, Position = targetPos, Player = player}
    end
    return target
end

local function SetAimbot(enabled)
    _aimbotEnabled = enabled
    _aimbotConn = SafeDisconnect(_aimbotConn)

    if enabled then
        _aimbotConn = Track(RunService.RenderStepped:Connect(function()
            if not _aimbotEnabled then return end
            local cam = Workspace.CurrentCamera
            local isAiming = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)

            if not isAiming then
                local ind = PremiumScript._drawings["AimIndicator"]
                if ind then ind.Visible = false end
                return
            end

            local info = GetAimTarget()
            if not info then
                local ind = PremiumScript._drawings["AimIndicator"]
                if ind then ind.Visible = false end
                return
            end

            -- Target lock indicator
            local pos = cam:WorldToViewportPoint(info.Position)
            local ind = PremiumScript._drawings["AimIndicator"] or MakeDraw("AimIndicator", "Circle")
            if ind then
                ind.Position = Vector2.new(pos.X, pos.Y)
                ind.Radius = 6; ind.Color = Color3.fromRGB(255, 50, 50)
                ind.Thickness = 2; ind.Filled = false
                ind.Transparency = 1; ind.Visible = true
            end

            if _aimbotSilent then
                cam.CFrame = CFrame.new(cam.CFrame.Position, info.Position)
            else
                local smooth = math.clamp(_aimbotSmoothness / 10, 0.05, 1)
                cam.CFrame = cam.CFrame:Lerp(
                    CFrame.new(cam.CFrame.Position, info.Position), smooth)
            end
        end))
    else
        local ind = PremiumScript._drawings["AimIndicator"]
        if ind then ind.Visible = false end
    end
end

-- ================================================================
--  FEATURE: KILL AURA
-- ================================================================

local _killAuraConn
local _killAuraRange = 15

local function SetKillAura(enabled, range)
    if range then _killAuraRange = range end
    _killAuraConn = SafeDisconnect(_killAuraConn)
    if enabled then
        _killAuraConn = Track(RunService.Heartbeat:Connect(function()
            local alive, myChar, _, myRoot = IsAlive()
            if not alive then return end
            local tool
            for _, c in ipairs(myChar:GetChildren()) do
                if c:IsA("Tool") then tool = c; break end
            end
            if not tool then return end

            for _, player in ipairs(Players:GetPlayers()) do
                if player == LocalPlayer then continue end
                if _espTeamCheck and player.Team and player.Team == LocalPlayer.Team then continue end
                local pAlive, _, _, pRoot = IsAlive(player)
                if pAlive and (myRoot.Position - pRoot.Position).Magnitude <= _killAuraRange then
                    pcall(function()
                        tool:Activate()
                        local handle = tool:FindFirstChild("Handle")
                        if handle and pRoot then
                            pcall(firetouchinterest, handle, pRoot, 0)
                            task.defer(function() pcall(firetouchinterest, handle, pRoot, 1) end)
                        end
                    end)
                end
            end
        end))
    end
end

-- ================================================================
--  FEATURE: REACH MODIFIER
-- ================================================================

local _reachConn
local _reachAmount = 20

local function SetReach(enabled, amount)
    if amount then _reachAmount = amount end
    _reachConn = SafeDisconnect(_reachConn)
    if enabled then
        _reachConn = Track(RunService.Heartbeat:Connect(function()
            local char = LocalPlayer.Character
            if not char then return end
            for _, c in ipairs(char:GetChildren()) do
                if c:IsA("Tool") then
                    local handle = c:FindFirstChild("Handle")
                    if handle then
                        handle.Size = Vector3.new(_reachAmount, _reachAmount, _reachAmount)
                        handle.Transparency = 1; handle.Massless = true
                    end
                end
            end
        end))
    end
end

-- ================================================================
--  FEATURE: FOV CIRCLE
-- ================================================================

local _fovEnabled = false
local _fovColor   = Color3.fromRGB(255, 255, 255)
local _fovConn

local function SetFOVCircle(enabled, radius)
    _fovEnabled = enabled
    if radius then _aimbotRadius = radius end
    CleanDraw("fov")
    _fovConn = SafeDisconnect(_fovConn)

    if not enabled then return end
    pcall(function()
        local c = Drawing.new("Circle")
        c.Visible = true; c.Radius = _aimbotRadius; c.Color = _fovColor
        c.Thickness = 1.5; c.Filled = false; c.Transparency = 1
        c.Position = GetMousePos()
        PremiumScript._drawings["fov"] = c

        _fovConn = Track(RunService.RenderStepped:Connect(function()
            if _fovEnabled and PremiumScript._drawings["fov"] then
                PremiumScript._drawings["fov"].Position = GetMousePos()
                PremiumScript._drawings["fov"].Radius = _aimbotRadius
                PremiumScript._drawings["fov"].Color = _fovColor
            end
        end))
    end)
end

-- ================================================================
--  FEATURE: ANTI-AFK
-- ================================================================

local _antiAfkConn

local function SetAntiAfk(enabled)
    _antiAfkConn = SafeDisconnect(_antiAfkConn)
    if enabled then
        _antiAfkConn = Track(LocalPlayer.Idled:Connect(function()
            pcall(function()
                local vim = game:GetService("VirtualInputManager")
                vim:SendKeyEvent(true, Enum.KeyCode.F15, false, game)
                task.wait(0.1)
                vim:SendKeyEvent(false, Enum.KeyCode.F15, false, game)
            end)
        end))
    end
end

-- ================================================================
--  FEATURE: ANTI-KICK
-- ================================================================

local function SetAntiKick(enabled)
    if enabled then
        pcall(function()
            local mt = getrawmetatable(game)
            if mt then
                local oldNc = mt.__namecall
                setreadonly(mt, false)
                mt.__namecall = newcclosure(function(self, ...)
                    if getnamecallmethod() == "Kick" and self == LocalPlayer then return end
                    return oldNc(self, ...)
                end)
                setreadonly(mt, true)
            end
        end)
    end
end

-- ================================================================
--  FEATURE: TELEPORT TO PLAYER
-- ================================================================

local function TeleportToPlayer(targetName)
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local lowerName = string.lower(targetName)
        if string.lower(player.Name):find(lowerName)
            or string.lower(player.DisplayName):find(lowerName) then
            local alive, _, _, tRoot = IsAlive(player)
            local myAlive, _, _, myRoot = IsAlive()
            if alive and myAlive then
                myRoot.CFrame = tRoot.CFrame + Vector3.new(0, 3, 0)
                return true, player.Name
            end
        end
    end
    return false, nil
end

-- ================================================================
--  FEATURE: SERVER HOP
-- ================================================================

local function ServerHop()
    pcall(function()
        local placeId = game.PlaceId
        local servers = HttpService:JSONDecode(
            game:HttpGet("https://games.roblox.com/v1/games/"
                .. placeId .. "/servers/Public?sortOrder=Asc&limit=100")
        )
        for _, server in ipairs(servers.data or {}) do
            if server.playing < server.maxPlayers and server.id ~= game.JobId then
                TeleportService:TeleportToPlaceInstance(placeId, server.id, LocalPlayer)
                return
            end
        end
    end)
end

-- ================================================================
--  FEATURE: CHAT SPY
-- ================================================================

local _chatSpyConn
local _chatSpyPlayerConns = {}

local function SetChatSpy(enabled)
    _chatSpyConn = SafeDisconnect(_chatSpyConn)
    for _, c in ipairs(_chatSpyPlayerConns) do SafeDisconnect(c) end
    table.clear(_chatSpyPlayerConns)

    if enabled then
        local function hookPlayer(player)
            if player == LocalPlayer then return end
            pcall(function()
                local c = player.Chatted:Connect(function(msg)
                    Notify(PremiumScript._lib, "Chat Spy",
                        player.Name .. ": " .. msg, "Info", 4)
                end)
                table.insert(_chatSpyPlayerConns, c)
                Track(c)
            end)
        end
        for _, player in ipairs(Players:GetPlayers()) do hookPlayer(player) end
        _chatSpyConn = Track(Players.PlayerAdded:Connect(hookPlayer))
    end
end

-- ================================================================
--  FEATURE: GRAVITY
-- ================================================================

local function SetGravity(value)
    Workspace.Gravity = value
end

-- ================================================================
--  FIX #2: EXPORT API (Populated at module load, before RegisterUI)
-- ================================================================

PremiumScript.Features = {
    WalkSpeed     = { Set = SetWalkSpeed },
    JumpPower     = { Set = SetJumpPower },
    InfiniteJump  = { Set = SetInfiniteJump },
    BunnyHop      = { Set = SetBunnyHop },
    MoonJump      = { Set = SetMoonJump },
    LongJump      = { Set = SetLongJump },
    Noclip        = { Set = SetNoclip },
    SpiderClimb   = { Set = SetSpiderClimb },
    Strafe        = { Set = SetStrafe },
    AutoWalk      = { Set = SetAutoWalk },
    FakeLag       = { Set = SetFakeLag },
    CFrameSpeed   = { Set = SetCFrameSpeed },
    TPWalk        = { Set = SetTPWalk },
    Fly           = { Set = SetFly },
    SpinBot       = { Set = SetSpinBot },
    Freeze        = { Set = SetFreeze },
    Trail         = { Set = SetTrail },
    CharScale     = { Set = SetCharacterScale },
    HipHeight     = { Set = SetHipHeight },
    AntiFallDmg   = { Set = SetAntiFallDamage },
    AutoRespawn   = { Set = SetAutoRespawn },
    Annoy         = { Set = SetAnnoy },
    ClickTP       = { Set = SetClickTP },
    SavePos       = { Set = SavePosition },
    LoadPos       = { Set = LoadPosition },
    ESP           = { Set = SetESP },
    Chams         = { Set = SetChams },
    Fullbright    = { Set = SetFullbright },
    RemoveFog     = { Set = SetRemoveFog },
    CameraFOV     = { Set = SetCameraFOV },
    FOVCircle     = { Set = SetFOVCircle },
    AntiAFK       = { Set = SetAntiAfk },
    AntiKick      = { Set = SetAntiKick },
    Aimbot        = { Set = SetAimbot },
    KillAura      = { Set = SetKillAura },
    Reach         = { Set = SetReach },
    ChatSpy       = { Set = SetChatSpy },
    Gravity       = { Set = SetGravity },
    Teleport      = { Set = TeleportToPlayer },
    ServerHop     = { Set = ServerHop },
}

-- ================================================================
--  REGISTER UI
-- ================================================================

function PremiumScript:RegisterUI(Lib, Win, keyResult)
    self._lib = Lib
    self._win = Win

    local tier     = keyResult and keyResult.Tier     or "Premium"
    local username = keyResult and keyResult.Username or LocalPlayer.Name
    local expiry   = keyResult and keyResult.Expiry   or "Lifetime"

    -- ═══════════════════════════════════════════════════════════
    --  TAB: COMBAT
    -- ═══════════════════════════════════════════════════════════
    local CombatTab = Win:CreateTab({ Name = "Combat", Icon = "⚔️" })

    local AimSec = CombatTab:CreateSection("Aimbot")
    AimSec:AddToggle({ Name = "Enable Aimbot", Description = "Hold right-click to lock on to the nearest target", Default = false, Flag = "AimbotEnabled", Callback = function(v) SetAimbot(v) end })
    AimSec:AddToggle({ Name = "Wall Check", Description = "Skip targets obstructed by walls", Default = true, Flag = "AimbotWallCheck", Callback = function(v) _aimbotWallCheck = v end })
    AimSec:AddToggle({ Name = "Silent Aim", Description = "Instant camera snap with no visible transition", Default = false, Flag = "AimbotSilent", Callback = function(v) _aimbotSilent = v end })
    AimSec:AddToggle({ Name = "Target Prediction", Description = "Lead moving targets based on their velocity", Default = false, Flag = "AimbotPrediction", Callback = function(v)
        _aimbotPredEnabled = v
        _aimbotPrediction = v and Vector3.new(0.12, 0.12, 0.12) or Vector3.zero
    end })
    AimSec:AddSlider({ Name = "Smoothness", Min = 1, Max = 10, Default = 5, Increment = 1, Suffix = "", Flag = "AimbotSmoothness", Callback = function(v) _aimbotSmoothness = v end })
    AimSec:AddDropdown({ Name = "Aim Part", Default = "Head", Flag = "AimbotPart", Options = {"Head", "HumanoidRootPart", "Closest"}, Callback = function(v) _aimbotPart = v end })

    local AuraSec = CombatTab:CreateSection("Kill Aura")
    AuraSec:AddToggle({ Name = "Enable Kill Aura", Description = "Auto-attack nearby enemies using your equipped weapon", Default = false, Flag = "KillAura", Callback = function(v) SetKillAura(v) end })
    AuraSec:AddSlider({ Name = "Aura Range", Min = 5, Max = 50, Default = 15, Increment = 1, Suffix = " studs", Flag = "KillAuraRange", Callback = function(v) _killAuraRange = v end })

    local ReachSec = CombatTab:CreateSection("Reach")
    ReachSec:AddToggle({ Name = "Extended Reach", Description = "Drastically expand weapon hitbox size", Default = false, Flag = "Reach", Callback = function(v) SetReach(v) end })
    ReachSec:AddSlider({ Name = "Reach Amount", Min = 5, Max = 100, Default = 20, Increment = 5, Suffix = " studs", Flag = "ReachAmount", Callback = function(v) _reachAmount = v end })

    -- ═══════════════════════════════════════════════════════════
    --  TAB: PLAYER
    -- ═══════════════════════════════════════════════════════════
    local PlayerTab = Win:CreateTab({ Name = "Player", Icon = "👤" })

    local SpeedSec = PlayerTab:CreateSection("Speed")
    SpeedSec:AddSlider({ Name = "Walk Speed", Min = 0, Max = 1000, Default = 16, Increment = 1, Suffix = "", Flag = "WalkSpeed", Callback = function(v) SetWalkSpeed(v) end })
    SpeedSec:AddToggle({ Name = "CFrame Speed", Description = "Alternative speed method that bypasses some anti-cheats", Default = false, Flag = "CFrameSpeed", Callback = function(v) SetCFrameSpeed(v) end })
    SpeedSec:AddSlider({ Name = "CFrame Multiplier", Min = 1, Max = 20, Default = 2, Increment = 1, Suffix = "x", Flag = "CFrameSpeedMult", Callback = function(v) _cframeSpeedVal = v end })
    SpeedSec:AddToggle({ Name = "TP Walk", Description = "Teleport-based movement for anti-cheat speed bypass", Default = false, Flag = "TPWalk", Callback = function(v) SetTPWalk(v) end })
    SpeedSec:AddSlider({ Name = "TP Distance", Min = 1, Max = 20, Default = 3, Increment = 1, Suffix = " studs", Flag = "TPWalkDist", Callback = function(v) _tpWalkDist = v end })

    local JumpSec = PlayerTab:CreateSection("Jumping")
    JumpSec:AddSlider({ Name = "Jump Power", Min = 0, Max = 1000, Default = 50, Increment = 5, Suffix = "", Flag = "JumpPower", Callback = function(v) SetJumpPower(v) end })
    JumpSec:AddToggle({ Name = "Infinite Jump", Description = "Jump unlimited times in mid-air", Default = false, Flag = "InfiniteJump", Callback = function(v) SetInfiniteJump(v) end })
    JumpSec:AddToggle({ Name = "Bunny Hop", Description = "Automatically jump while moving continuously", Default = false, Flag = "BunnyHop", Callback = function(v) SetBunnyHop(v) end })
    JumpSec:AddToggle({ Name = "Moon Jump", Description = "Hold Space to float upward during freefall", Default = false, Flag = "MoonJump", Callback = function(v) SetMoonJump(v) end })
    JumpSec:AddToggle({ Name = "Long Jump", Description = "Launch forward with momentum while jumping", Default = false, Flag = "LongJump", Callback = function(v) SetLongJump(v) end })
    JumpSec:AddSlider({ Name = "Long Jump Power", Min = 50, Max = 500, Default = 120, Increment = 10, Suffix = "", Flag = "LongJumpPower", Callback = function(v) _longJumpPower = v end })

    local MoveSec = PlayerTab:CreateSection("Movement")
    MoveSec:AddToggle({ Name = "No Clip", Description = "Phase through all solid objects effortlessly", Default = false, Flag = "NoClip", Callback = function(v) SetNoclip(v) end })
    MoveSec:AddToggle({ Name = "Spider Climb", Description = "Climb any wall on direct contact", Default = false, Flag = "SpiderClimb", Callback = function(v) SetSpiderClimb(v) end })
    MoveSec:AddToggle({ Name = "Air Strafe", Description = "Retain full movement control while airborne", Default = false, Flag = "Strafe", Callback = function(v) SetStrafe(v) end })
    MoveSec:AddToggle({ Name = "Auto Walk", Description = "Walk forward automatically towards camera direction", Default = false, Flag = "AutoWalk", Callback = function(v) SetAutoWalk(v) end })
    MoveSec:AddToggle({ Name = "Fake Lag", Description = "Stutter your movement making you harder to hit", Default = false, Flag = "FakeLag", Callback = function(v) SetFakeLag(v) end })
    MoveSec:AddSlider({ Name = "Lag Intensity", Min = 2, Max = 15, Default = 5, Increment = 1, Suffix = "", Flag = "FakeLagInterval", Callback = function(v) _fakeLagInterval = v end })

    local FlySec = PlayerTab:CreateSection("Fly")
    FlySec:AddToggle({ Name = "Fly", Description = "WASD + Space/Q to fly, hold Shift for 2.5x boost", Default = false, Flag = "FlyEnabled", Callback = function(v) SetFly(v, Lib.Flags and Lib.Flags["FlySpeed"] or 60) end })
    FlySec:AddSlider({ Name = "Fly Speed", Min = 10, Max = 500, Default = 60, Increment = 5, Suffix = "", Flag = "FlySpeed", Callback = function(v) _flySpeed = v end })
    FlySec:AddToggle({ Name = "Elytra Glide", Description = "Slowly glide downward when idle in fly mode", Default = false, Flag = "FlyElytra", Callback = function(v) _flyElytra = v end })

    local PhySec = PlayerTab:CreateSection("Physics")
    PhySec:AddSlider({ Name = "Gravity", Min = 0, Max = 500, Default = 196, Increment = 1, Suffix = "", Flag = "Gravity", Callback = function(v) SetGravity(v) end })
    PhySec:AddSlider({ Name = "Hip Height", Min = 0, Max = 100, Default = 0, Increment = 1, Suffix = " studs", Flag = "HipHeight", Callback = function(v) SetHipHeight(v) end })
    PhySec:AddToggle({ Name = "Anti Fall Damage", Description = "Disable ragdoll and falling-down states completely", Default = false, Flag = "AntiFallDamage", Callback = function(v) SetAntiFallDamage(v) end })

    local CharSec = PlayerTab:CreateSection("Character")
    CharSec:AddSlider({ Name = "Head Scale", Min = 0.5, Max = 10, Default = 1, Increment = 0.5, Suffix = "x", Flag = "HeadScale", Callback = function(v) SetCharacterScale(v, Lib.Flags and Lib.Flags["BodyWidth"] or 1, Lib.Flags and Lib.Flags["BodyHeight"] or 1, Lib.Flags and Lib.Flags["BodyDepth"] or 1) end })
    CharSec:AddSlider({ Name = "Body Width", Min = 0.5, Max = 10, Default = 1, Increment = 0.5, Suffix = "x", Flag = "BodyWidth", Callback = function(v) SetCharacterScale(Lib.Flags and Lib.Flags["HeadScale"] or 1, v, Lib.Flags and Lib.Flags["BodyHeight"] or 1, Lib.Flags and Lib.Flags["BodyDepth"] or 1) end })
    CharSec:AddSlider({ Name = "Body Height", Min = 0.5, Max = 10, Default = 1, Increment = 0.5, Suffix = "x", Flag = "BodyHeight", Callback = function(v) SetCharacterScale(Lib.Flags and Lib.Flags["HeadScale"] or 1, Lib.Flags and Lib.Flags["BodyWidth"] or 1, v, Lib.Flags and Lib.Flags["BodyDepth"] or 1) end })
    CharSec:AddSlider({ Name = "Body Depth", Min = 0.5, Max = 10, Default = 1, Increment = 0.5, Suffix = "x", Flag = "BodyDepth", Callback = function(v) SetCharacterScale(Lib.Flags and Lib.Flags["HeadScale"] or 1, Lib.Flags and Lib.Flags["BodyWidth"] or 1, Lib.Flags and Lib.Flags["BodyHeight"] or 1, v) end })
    CharSec:AddToggle({ Name = "Spin Bot", Description = "Rapidly spin your character on its Y-axis", Default = false, Flag = "SpinBot", Callback = function(v) SetSpinBot(v) end })
    CharSec:AddSlider({ Name = "Spin Speed", Min = 1, Max = 100, Default = 20, Increment = 1, Suffix = "°/f", Flag = "SpinSpeed", Callback = function(v) _spinSpeed = v end })
    CharSec:AddToggle({ Name = "Freeze Character", Description = "Lock your position perfectly in place", Default = false, Flag = "Freeze", Callback = function(v) SetFreeze(v) end })
    CharSec:AddToggle({ Name = "Trail Effect", Description = "Leave a glowing neon trail behind you", Default = false, Flag = "Trail", Callback = function(v) SetTrail(v) end })
    CharSec:AddColorPicker({ Name = "Trail Color", Default = Color3.fromRGB(100, 200, 255), Flag = "TrailColor", Callback = function(c) _trailColor = c end })
    CharSec:AddToggle({ Name = "Auto Respawn", Description = "Automatically respawn upon death", Default = false, Flag = "AutoRespawn", Callback = function(v) SetAutoRespawn(v) end })

    local AnnoySec = PlayerTab:CreateSection("Trolling")
    AnnoySec:AddToggle({ Name = "Orbit Player", Description = "Orbit around the closest player continuously", Default = false, Flag = "Annoy", Callback = function(v) SetAnnoy(v) end })
    AnnoySec:AddSlider({ Name = "Orbit Radius", Min = 3, Max = 30, Default = 8, Increment = 1, Suffix = " studs", Flag = "AnnoyRadius", Callback = function(v) _annoyRadius = v end })

    local TpSec = PlayerTab:CreateSection("Teleport")
    TpSec:AddToggle({ Name = "Click Teleport", Description = "Hold Ctrl and Left-Click to teleport to your cursor", Default = false, Flag = "ClickTP", Callback = function(v) SetClickTP(v) end })
    TpSec:AddInput({ Name = "Player Name", Default = "", Placeholder = "Enter target name...", Flag = "TpTarget", Callback = function() end })
    TpSec:AddButton({ Name = "Teleport to Player", Callback = function()
        local name = Lib.Flags and Lib.Flags["TpTarget"] or ""
        if name == "" then Notify(Lib, "Error", "Enter a player name first.", "Error"); return end
        local ok, pName = TeleportToPlayer(name)
        if ok then Notify(Lib, "Success", "Teleported to " .. pName .. ".", "Success")
        else Notify(Lib, "Error", "Player not found or dead.", "Error") end
    end })
    TpSec:AddButton({ Name = "Save Position (Slot 1)", Description = "Store your current coordinates", Callback = function()
        if SavePosition(1) then Notify(Lib, "Saved", "Position saved to Slot 1.", "Success")
        else Notify(Lib, "Error", "Character not found.", "Error") end
    end })
    TpSec:AddButton({ Name = "Save Position (Slot 2)", Callback = function()
        if SavePosition(2) then Notify(Lib, "Saved", "Position saved to Slot 2.", "Success")
        else Notify(Lib, "Error", "Character not found.", "Error") end
    end })
    TpSec:AddButton({ Name = "Load Position (Slot 1)", Callback = function()
        if LoadPosition(1) then Notify(Lib, "Loaded", "Teleported to Slot 1.", "Success")
        else Notify(Lib, "Error", "No position saved in Slot 1.", "Error") end
    end })
    TpSec:AddButton({ Name = "Load Position (Slot 2)", Callback = function()
        if LoadPosition(2) then Notify(Lib, "Loaded", "Teleported to Slot 2.", "Success")
        else Notify(Lib, "Error", "No position saved in Slot 2.", "Error") end
    end })

    -- ═══════════════════════════════════════════════════════════
    --  TAB: VISUAL
    -- ═══════════════════════════════════════════════════════════
    local VisualTab = Win:CreateTab({ Name = "Visual", Icon = "🎨" })

    local ESPSec = VisualTab:CreateSection("Player ESP")
    ESPSec:AddToggle({ Name = "Enable ESP", Default = false, Flag = "ESPEnabled", Callback = function(v) SetESP(v) end })
    ESPSec:AddToggle({ Name = "Team Check", Default = false, Flag = "ESPTeamCheck", Callback = function(v) _espTeamCheck = v end })
    ESPSec:AddToggle({ Name = "Show Name", Default = true, Flag = "ESPName", Callback = function(v) _espShowName = v end })
    ESPSec:AddToggle({ Name = "Show Distance", Default = true, Flag = "ESPDist", Callback = function(v) _espShowDist = v end })
    ESPSec:AddToggle({ Name = "Show Health", Default = true, Flag = "ESPHealth", Callback = function(v) _espShowHealth = v end })
    ESPSec:AddToggle({ Name = "Show Weapon", Description = "Display the name of the equipped tool", Default = false, Flag = "ESPWeapon", Callback = function(v) _espShowWeapon = v end })
    ESPSec:AddToggle({ Name = "Box ESP", Description = "Draw 2D bounding boxes around all players", Default = false, Flag = "ESPBoxes", Callback = function(v) _espBoxes = v end })
    ESPSec:AddToggle({ Name = "Health Bar", Description = "Render a color-coded HP bar beside the box", Default = false, Flag = "ESPHealthBar", Callback = function(v) _espHealthBar = v end })
    ESPSec:AddToggle({ Name = "Tracers", Description = "Draw lines from screen bottom to each player", Default = false, Flag = "ESPTracers", Callback = function(v) _espTracers = v end })
    ESPSec:AddColorPicker({ Name = "ESP Color", Default = Color3.fromRGB(255, 80, 80), Flag = "ESPColor", Callback = function(c) _espColor = c end })

    local ChamsSec = VisualTab:CreateSection("Chams")
    ChamsSec:AddToggle({ Name = "Enable Chams", Default = false, Flag = "ChamsEnabled", Callback = function(v) SetChams(v) end })
    ChamsSec:AddColorPicker({ Name = "Chams Color", Default = Color3.fromRGB(30, 200, 255), Flag = "ChamsColor", Callback = function(c) _chamsColor = c end })

    local FOVSec = VisualTab:CreateSection("FOV Circle")
    FOVSec:AddToggle({ Name = "Show FOV Circle", Default = false, Flag = "FOVEnabled", Callback = function(v) SetFOVCircle(v, Lib.Flags and Lib.Flags["FOVRadius"] or 150) end })
    FOVSec:AddSlider({ Name = "FOV Radius", Min = 20, Max = 600, Default = 150, Increment = 5, Suffix = "px", Flag = "FOVRadius", Callback = function(v) _aimbotRadius = v end })
    FOVSec:AddColorPicker({ Name = "FOV Color", Default = Color3.fromRGB(255, 255, 255), Flag = "FOVColor", Callback = function(c) _fovColor = c end })

    local WorldSec = VisualTab:CreateSection("World")
    WorldSec:AddToggle({ Name = "Fullbright", Default = false, Flag = "Fullbright", Callback = function(v) SetFullbright(v) end })
    WorldSec:AddToggle({ Name = "Remove Fog", Description = "Completely remove fog and atmosphere effects", Default = false, Flag = "RemoveFog", Callback = function(v) SetRemoveFog(v) end })
    WorldSec:AddSlider({ Name = "Camera FOV", Min = 30, Max = 120, Default = 70, Increment = 1, Suffix = "°", Flag = "CameraFOV", Callback = function(v) SetCameraFOV(v) end })

    -- ═══════════════════════════════════════════════════════════
    --  TAB: MISC
    -- ═══════════════════════════════════════════════════════════
    local MiscTab = Win:CreateTab({ Name = "Misc", Icon = "⚙️" })

    local UtilSec = MiscTab:CreateSection("Utility")
    UtilSec:AddToggle({ Name = "Anti-AFK", Default = true, Flag = "AntiAFK", Callback = function(v) SetAntiAfk(v) end })
    SetAntiAfk(true)
    UtilSec:AddToggle({ Name = "Anti-Kick", Description = "Block server kick attempts (executor dependent)", Default = false, Flag = "AntiKick", Callback = function(v) SetAntiKick(v) end })
    UtilSec:AddToggle({ Name = "Chat Spy", Description = "Log and view all player chat messages privately", Default = false, Flag = "ChatSpy", Callback = function(v) SetChatSpy(v) end })

    local ServerSec = MiscTab:CreateSection("Server")
    ServerSec:AddButton({ Name = "Server Hop", Description = "Join a different public server instantly", Callback = function()
        Notify(Lib, "Server Hop", "Finding a new server...", "Info")
        ServerHop()
    end })
    ServerSec:AddButton({ Name = "Rejoin Server", Description = "Disconnect and reconnect to the same server", Callback = function()
        pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
    end })
    ServerSec:AddLabel("Server ID: " .. string.sub(game.JobId, 1, 12) .. "...")
    ServerSec:AddLabel("Players: " .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers)

    -- ═══════════════════════════════════════════════════════════
    --  TAB: ACCOUNT
    -- ═══════════════════════════════════════════════════════════
    local AccTab = Win:CreateTab({ Name = "Account", Icon = "💎" })
    local AccSec = AccTab:CreateSection("Premium Account")

    AccSec:AddLabel("User:     " .. username)
    AccSec:AddLabel("Tier:     💎 " .. tier)
    AccSec:AddLabel("Expires:  " .. tostring(expiry))
    AccSec:AddSeparator()
    AccSec:AddLabel("Version:  BorcaHub Premium  v" .. self._version)
    AccSec:AddLabel("Discord:  discord.gg/borcahub")
    AccSec:AddSeparator()

    AccSec:AddButton({ Name = "Copy Discord Link", Callback = function()
        pcall(setclipboard, "discord.gg/borcahub")
        Notify(Lib, "Copied!", "Discord link copied to clipboard.", "Success")
    end })
    AccSec:AddButton({ Name = "Reset Key", Description = "Clear saved license key and re-prompt on next launch", Callback = function()
        pcall(writefile, "BorcaHub_Key.txt", "")
        pcall(writefile, "BorcaHub_KeyCache.txt", "")
        Notify(Lib, "Key Reset", "License key cleared. Rejoin to re-enter.", "Warning", 5)
    end })
    AccSec:AddButton({ Name = "Destroy Script", Description = "Safely shut down all active features and clean up", Callback = function()
        PremiumScript:Destroy()
        Notify(Lib, "Destroyed", "All features have been terminated safely.", "Warning")
    end })
end

-- ================================================================
--  DESTROY (Full Cleanup — Zero Leaks)
-- ================================================================

function PremiumScript:Destroy()
    -- Disable every feature (each function cleans its own connection)
    SetFly(false)
    SetESP(false)
    SetFOVCircle(false)
    SetAimbot(false)
    SetInfiniteJump(false)
    SetBunnyHop(false)
    SetMoonJump(false)
    SetLongJump(false)
    SetNoclip(false)
    SetSpiderClimb(false)
    SetStrafe(false)
    SetAutoWalk(false)
    SetFakeLag(false)
    SetCFrameSpeed(false)
    SetTPWalk(false)
    SetFullbright(false)
    SetRemoveFog(false)
    SetAntiAfk(false)
    SetKillAura(false)
    SetReach(false)
    SetChatSpy(false)
    SetSpinBot(false)
    SetFreeze(false)
    SetAntiFallDamage(false)
    SetAutoRespawn(false)
    SetAnnoy(false)
    SetClickTP(false)
    CleanTrail()
    CleanFlyConstraints()
    SetGravity(196.2)

    -- Kill Annoy search task
    if _annoySearchTask then
        pcall(function() task.cancel(_annoySearchTask) end)
        _annoySearchTask = nil
    end

    -- Disconnect every tracked connection
    for _, conn in ipairs(self._connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(self._connections)

    -- Remove all Drawing objects
    for key, _ in pairs(self._drawings) do CleanDraw(key) end
    table.clear(self._drawings)

    -- Remove all ESP visuals (highlights, billboards, CoreGui folder)
    CleanAllESP()

    -- Reset camera FOV
    pcall(function() Workspace.CurrentCamera.FieldOfView = 70 end)

    print("[BorcaHub Premium v" .. self._version .. "] Full cleanup complete. Zero leaks.")
end

return PremiumScript
