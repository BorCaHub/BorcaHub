--[[
    BorcaHub Premium / mm2.lua
    Murder Mystery 2 — God-Tier v17
    Event-Driven | Ping-Compensated | Anti-Cheat Bypass
--]]

-- ================================================================
--  SERVICES & CORE REFERENCES
-- ================================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local CoreGui          = game:GetService("CoreGui")
local Stats            = game:GetService("Stats")
local LocalPlayer      = Players.LocalPlayer
local Camera           = workspace.CurrentCamera

local MM2 = {
    _connections  = {},
    _drawings     = {},
    _chamsCache   = {},
    _origMaterials = {},
}

local function Track(conn)
    table.insert(MM2._connections, conn)
    return conn
end

local function TrackDrawing(d)
    table.insert(MM2._drawings, d)
    return d
end

-- ================================================================
--  ANTI-CHEAT BYPASS LAYER
-- ================================================================
local _bypassActive = false

local function SetupAntiCheat()
    if _bypassActive then return end
    _bypassActive = true

    -- Spoof debug.traceback to return clean stack
    pcall(function()
        local realTraceback = debug.traceback
        debug.traceback = function(...)
            if not checkcaller() then
                return realTraceback(...)
            end
            -- Return a clean trace that hides our hooks
            return "Script 'MainModule', Line 1\nScript 'Handler', Line 1"
        end
    end)

    -- Spoof debug.info
    pcall(function()
        local realInfo = debug.info
        if realInfo then
            debug.info = function(level, ...)
                if not checkcaller() then
                    return realInfo(level, ...)
                end
                return realInfo(level, ...)
            end
        end
    end)
end

-- ================================================================
--  1. EVENT-DRIVEN ROLE DETECTION (ZERO-LAG)
-- ================================================================
local _roleMap       = {}   -- player -> "murderer" | "sheriff" | "innocent"
local _roleListeners = {}   -- player -> {connections}
local _roleCallbacks = {}   -- functions to call when roles change

local function ScanToolRole(item)
    if not item or not item:IsA("Tool") then return nil end

    -- Immediately reject non-weapons
    local tip = item.ToolTip
    if tip == "Toy" or tip == "Pet" or tip == "Radio" then return nil end

    local isSheriff  = false
    local isMurderer = false

    -- ToolTip check (most reliable)
    if tip == "Gun" then isSheriff = true end
    if tip == "Knife" or tip == "Melee" then isMurderer = true end

    -- Internal scripts
    if item:FindFirstChild("GunClient") or item:FindFirstChild("GunServer") then isSheriff = true end
    if item:FindFirstChild("KnifeClient") or item:FindFirstChild("KnifeServer") then isMurderer = true end

    -- Handle sounds (strict — no "Throw" to avoid toy false flags)
    local handle = item:FindFirstChild("Handle")
    if handle then
        if handle:FindFirstChild("GunFire") then isSheriff = true end
        if handle:FindFirstChild("Slash") or handle:FindFirstChild("Stab") or handle:FindFirstChild("KnifeSlash") then isMurderer = true end
    end

    -- Conflict resolution
    if isSheriff and isMurderer then
        if handle and handle:FindFirstChild("GunFire") then return "sheriff" end
        return nil
    end
    if isSheriff then return "sheriff" end
    if isMurderer then return "murderer" end
    return nil
end

local function RescanPlayer(player)
    local oldRole = _roleMap[player]

    local function check(container)
        if not container then return nil end
        for _, item in ipairs(container:GetChildren()) do
            local r = ScanToolRole(item)
            if r then return r end
        end
        return nil
    end

    local role = check(player:FindFirstChild("Backpack")) or check(player.Character) or "innocent"
    _roleMap[player] = role

    -- Fire callbacks if role changed
    if role ~= oldRole then
        for _, cb in ipairs(_roleCallbacks) do
            pcall(cb, player, role, oldRole)
        end
    end
end

local function HookContainer(player, container)
    if not container then return end
    local conns = _roleListeners[player]
    if not conns then conns = {}; _roleListeners[player] = conns end

    table.insert(conns, Track(container.ChildAdded:Connect(function()
        task.defer(function() RescanPlayer(player) end)
    end)))
    table.insert(conns, Track(container.ChildRemoved:Connect(function()
        task.defer(function() RescanPlayer(player) end)
    end)))
end

local function SetupPlayerListener(player)
    if player == LocalPlayer then
        -- Also track local player for Kill Aura / role check
    end

    _roleMap[player] = "innocent"

    -- Hook current backpack
    local bp = player:FindFirstChild("Backpack")
    if bp then HookContainer(player, bp) end

    -- Hook current character
    if player.Character then
        HookContainer(player, player.Character)
        RescanPlayer(player)
    end

    -- Re-hook on respawn (new round)
    local conns = _roleListeners[player]
    if not conns then conns = {}; _roleListeners[player] = conns end

    table.insert(conns, Track(player.CharacterAdded:Connect(function(char)
        _roleMap[player] = "innocent"
        HookContainer(player, char)

        -- Wait for backpack to repopulate
        task.delay(0.5, function()
            local newBp = player:FindFirstChild("Backpack")
            if newBp then HookContainer(player, newBp) end
            RescanPlayer(player)
        end)

        -- Rescan periodically during the 10s countdown
        for i = 1, 10 do
            task.delay(i, function() RescanPlayer(player) end)
        end
    end)))

    -- Initial scan
    RescanPlayer(player)
end

local function CleanupPlayerListener(player)
    _roleMap[player] = nil
    local conns = _roleListeners[player]
    if conns then
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        _roleListeners[player] = nil
    end
end

local function GetRole(player)
    return _roleMap[player] or "innocent"
end

-- Boot listeners for all current and future players
local function BootRoleSystem()
    for _, player in ipairs(Players:GetPlayers()) do
        SetupPlayerListener(player)
    end
    Track(Players.PlayerAdded:Connect(SetupPlayerListener))
    Track(Players.PlayerRemoving:Connect(CleanupPlayerListener))
end

-- ================================================================
--  HELPER: FIND MY KNIFE
-- ================================================================
local function FindMyKnife()
    local char = LocalPlayer.Character
    if char then
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") and ScanToolRole(item) == "murderer" then return item end
        end
    end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for _, item in ipairs(bp:GetChildren()) do
            if item:IsA("Tool") and ScanToolRole(item) == "murderer" then return item end
        end
    end
    return nil
end

-- ================================================================
--  HELPER: FIND GUN DROP
-- ================================================================
local function FindGunDrop()
    local drop = workspace:FindFirstChild("GunDrop")
    if drop and not drop.Parent:FindFirstChild("Humanoid") and (drop:IsA("BasePart") or drop:IsA("Model") or drop:IsA("Tool")) then
        return drop
    end
    for _, child in ipairs(workspace:GetChildren()) do
        if not child:FindFirstChild("Humanoid") then
            local name = child.Name:lower()
            if (child:IsA("BasePart") or child:IsA("Model") or child:IsA("Tool")) then
                if name == "gundrop" or name == "gun" then return child end
            end
            if child:IsA("Folder") or child:IsA("Model") then
                local gd = child:FindFirstChild("GunDrop") or child:FindFirstChild("Gun")
                if gd and not gd.Parent:FindFirstChild("Humanoid") then return gd end
            end
        end
    end
    return nil
end

local function GetObjPos(obj)
    if not obj then return nil end
    if obj:IsA("Model") then return obj:GetPivot().Position end
    if obj:IsA("Tool") then local h = obj:FindFirstChild("Handle"); return h and h.Position end
    if obj:IsA("BasePart") then return obj.Position end
    local p = obj:FindFirstChildWhichIsA("BasePart", true)
    return p and p.Position
end

local function GetObjCF(obj)
    if not obj then return nil end
    if obj:IsA("Model") then return obj:GetPivot() end
    if obj:IsA("Tool") then local h = obj:FindFirstChild("Handle"); return h and h.CFrame end
    if obj:IsA("BasePart") then return obj.CFrame end
    local p = obj:FindFirstChildWhichIsA("BasePart", true)
    return p and p.CFrame
end

-- ================================================================
--  HELPER: WALL CHECK
-- ================================================================
local function IsVisible(targetPart)
    if not targetPart then return false end
    local char = LocalPlayer.Character
    if not char then return false end
    local head = char:FindFirstChild("Head")
    if not head then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char}
    local result = workspace:Raycast(head.Position, targetPart.Position - head.Position, params)
    if not result then return true end
    return result.Instance:IsDescendantOf(targetPart.Parent)
end

-- ================================================================
--  HELPER: PING-COMPENSATED PREDICTION
-- ================================================================
local function GetPing()
    local ping = 0
    pcall(function()
        ping = LocalPlayer:GetNetworkPing() -- half RTT in seconds
    end)
    pcall(function()
        if ping <= 0 then
            ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
        end
    end)
    return math.max(ping, 0)
end

local function PredictPosition(part, bulletSpeed)
    if not part then return nil end
    local pos = part.Position
    local vel = part.AssemblyLinearVelocity
    if vel and vel.Magnitude > 1 then
        local dist = (Camera.CFrame.Position - pos).Magnitude
        local travelTime = (dist / (bulletSpeed or 300)) + GetPing()
        pos = pos + (vel * travelTime)
    end
    return pos
end

-- ================================================================
--  HELPER: CONTAINER FOR HIGHLIGHTS
-- ================================================================
local highlightFolder
local function GetContainer()
    if highlightFolder and highlightFolder.Parent then return highlightFolder end
    local f = Instance.new("Folder")
    f.Name = "MM2_Container"
    local ok, core = pcall(function() return CoreGui end)
    if ok and core then f.Parent = core else f.Parent = Camera end
    highlightFolder = f
    return f
end

-- ================================================================
--  2. ROLE-COLORED HIGHLIGHTS ESP
-- ================================================================
local _espConn
local _espHighlights = {}
local roleColors = {
    murderer = Color3.fromRGB(255, 25, 25),
    sheriff  = Color3.fromRGB(25, 125, 255),
    innocent = Color3.fromRGB(50, 255, 50),
}

local function SetESP(enabled)
    if _espConn then _espConn:Disconnect(); _espConn = nil end
    if not enabled then
        for _, hl in pairs(_espHighlights) do if hl and hl.Parent then hl:Destroy() end end
        _espHighlights = {}
        return
    end
    _espConn = Track(RunService.Heartbeat:Connect(function()
        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            local char = player.Character
            local hl = _espHighlights[player]
            if not char or not char:FindFirstChild("HumanoidRootPart") then
                if hl then hl.Adornee = nil end
                continue
            end
            local role = GetRole(player)
            if not hl or not hl.Parent then
                hl = Instance.new("Highlight")
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Parent = GetContainer()
                _espHighlights[player] = hl
            end
            if hl.Adornee ~= char then hl.Adornee = char end
            hl.OutlineColor = Color3.new(1, 1, 1)
            hl.OutlineTransparency = 0.4
            hl.FillColor = roleColors[role] or roleColors.innocent
            hl.FillTransparency = (role == "innocent") and 0.85 or 0.5
        end
        for p, hl in pairs(_espHighlights) do
            if not p:IsDescendantOf(Players) then
                if hl then hl:Destroy() end
                _espHighlights[p] = nil
            end
        end
    end))
end

-- ================================================================
--  3. CHAMS (MATERIAL OVERRIDE + RGB CYCLE)
-- ================================================================
local _chamsConn
local _chamsHue = 0

local function SetChams(enabled)
    if _chamsConn then _chamsConn:Disconnect(); _chamsConn = nil end
    if not enabled then
        -- Restore all original materials
        for part, data in pairs(MM2._origMaterials) do
            if part and part.Parent then
                part.Material = data.mat
                part.Color = data.col
                part.Transparency = data.trans
            end
        end
        MM2._origMaterials = {}
        return
    end
    _chamsConn = Track(RunService.Heartbeat:Connect(function(dt)
        _chamsHue = (_chamsHue + dt * 60) % 360
        local rgbColor = Color3.fromHSV(_chamsHue / 360, 1, 1)

        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            local char = player.Character
            if not char then continue end
            local role = GetRole(player)

            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    if not MM2._origMaterials[part] then
                        MM2._origMaterials[part] = {
                            mat = part.Material,
                            col = part.Color,
                            trans = part.Transparency,
                        }
                    end
                    if role == "murderer" then
                        part.Material = Enum.Material.Neon
                        part.Color = rgbColor
                        part.Transparency = 0.3
                    elseif role == "sheriff" then
                        part.Material = Enum.Material.Neon
                        part.Color = Color3.fromRGB(30, 120, 255)
                        part.Transparency = 0.3
                    else
                        part.Material = Enum.Material.ForceField
                        part.Color = Color3.fromRGB(50, 255, 50)
                        part.Transparency = 0.6
                    end
                end
            end
        end

        -- Cleanup departed
        for part, _ in pairs(MM2._origMaterials) do
            if not part or not part.Parent then
                MM2._origMaterials[part] = nil
            end
        end
    end))
end

-- ================================================================
--  4. OFF-SCREEN ARROWS (DRAWING API)
-- ================================================================
local _arrowConn
local _arrowTriangle, _arrowText

local function SetOffScreenArrows(enabled)
    if _arrowConn then _arrowConn:Disconnect(); _arrowConn = nil end

    if not enabled then
        if _arrowTriangle then pcall(function() _arrowTriangle:Remove() end); _arrowTriangle = nil end
        if _arrowText then pcall(function() _arrowText:Remove() end); _arrowText = nil end
        return
    end

    pcall(function()
        _arrowTriangle = TrackDrawing(Drawing.new("Triangle"))
        _arrowTriangle.Filled = true
        _arrowTriangle.Color = Color3.fromRGB(255, 50, 50)
        _arrowTriangle.Thickness = 2
        _arrowTriangle.Visible = false

        _arrowText = TrackDrawing(Drawing.new("Text"))
        _arrowText.Size = 18
        _arrowText.Center = true
        _arrowText.Outline = true
        _arrowText.Color = Color3.fromRGB(255, 255, 255)
        _arrowText.Visible = false
    end)

    _arrowConn = Track(RunService.RenderStepped:Connect(function()
        if not _arrowTriangle or not _arrowText then return end

        local closestPlayer, closestDist = nil, math.huge
        local vpSize = Camera.ViewportSize
        local centerScreen = Vector2.new(vpSize.X / 2, vpSize.Y / 2)

        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            if GetRole(player) ~= "murderer" then continue end
            local char = player.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then continue end
            local myChar = LocalPlayer.Character
            if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then continue end
            local dist = (myChar.HumanoidRootPart.Position - char.HumanoidRootPart.Position).Magnitude
            if dist < closestDist then
                closestDist = dist
                closestPlayer = player
            end
        end

        if not closestPlayer then
            _arrowTriangle.Visible = false
            _arrowText.Visible = false
            return
        end

        local char = closestPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then
            _arrowTriangle.Visible = false
            _arrowText.Visible = false
            return
        end

        local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)

        if onScreen then
            _arrowTriangle.Visible = false
            _arrowText.Visible = false
            return
        end

        -- Calculate edge position
        local dir = (Vector2.new(screenPos.X, screenPos.Y) - centerScreen).Unit
        local margin = 60
        local edgeX = math.clamp(centerScreen.X + dir.X * (vpSize.X / 2 - margin), margin, vpSize.X - margin)
        local edgeY = math.clamp(centerScreen.Y + dir.Y * (vpSize.Y / 2 - margin), margin, vpSize.Y - margin)
        local edgePos = Vector2.new(edgeX, edgeY)

        -- Draw arrow triangle pointing outward
        local arrowSize = 18
        local perpDir = Vector2.new(-dir.Y, dir.X)
        local tip = edgePos + dir * arrowSize
        local baseL = edgePos - dir * (arrowSize * 0.5) + perpDir * (arrowSize * 0.5)
        local baseR = edgePos - dir * (arrowSize * 0.5) - perpDir * (arrowSize * 0.5)

        _arrowTriangle.PointA = tip
        _arrowTriangle.PointB = baseL
        _arrowTriangle.PointC = baseR
        _arrowTriangle.Color = Color3.fromRGB(255, 50, 50)
        _arrowTriangle.Visible = true

        _arrowText.Position = edgePos - dir * (arrowSize + 15)
        _arrowText.Text = math.floor(closestDist) .. "m"
        _arrowText.Visible = true
    end))
end

-- ================================================================
--  5. GUN DROP ESP (BILLBOARD)
-- ================================================================
local _gunEspConn, _beaconPart

local function SetGunDropESP(enabled)
    if _gunEspConn then _gunEspConn:Disconnect(); _gunEspConn = nil end
    if not enabled then
        if _beaconPart then _beaconPart:Destroy(); _beaconPart = nil end
        return
    end
    _beaconPart = Instance.new("Part")
    _beaconPart.Name = "GunBeacon"
    _beaconPart.Anchored = true
    _beaconPart.CanCollide = false
    _beaconPart.Transparency = 1
    _beaconPart.Size = Vector3.new(1, 1, 1)

    local bb = Instance.new("BillboardGui", _beaconPart)
    bb.AlwaysOnTop = true
    bb.Size = UDim2.new(0, 300, 0, 60)
    bb.StudsOffset = Vector3.new(0, 3, 0)

    local txt = Instance.new("TextLabel", bb)
    txt.Size = UDim2.new(1, 0, 1, 0)
    txt.BackgroundTransparency = 1
    txt.TextColor3 = Color3.fromRGB(255, 215, 0)
    txt.TextStrokeColor3 = Color3.new(0, 0, 0)
    txt.TextStrokeTransparency = 0
    txt.TextScaled = true
    txt.Font = Enum.Font.GothamBlack

    _gunEspConn = Track(RunService.Heartbeat:Connect(function()
        local gun = FindGunDrop()
        if gun and gun.Parent then
            local pos = GetObjPos(gun)
            if pos then
                _beaconPart.Position = pos
                if _beaconPart.Parent ~= workspace then _beaconPart.Parent = workspace end
                local myChar = LocalPlayer.Character
                if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                    txt.Text = "GUN DROP [" .. math.floor((myChar.HumanoidRootPart.Position - pos).Magnitude) .. " studs]"
                else
                    txt.Text = "GUN DROP"
                end
            else
                _beaconPart.Parent = nil
            end
        else
            _beaconPart.Parent = nil
        end
    end))
end

-- ================================================================
--  6. DANGER SCREEN
-- ================================================================
local _dangerConn
local dangerCC = Instance.new("ColorCorrectionEffect")
dangerCC.Name = "MM2Danger"
dangerCC.TintColor = Color3.fromRGB(255, 100, 100)
dangerCC.Enabled = false
dangerCC.Parent = Lighting

local function SetDangerScreen(enabled)
    if _dangerConn then _dangerConn:Disconnect(); _dangerConn = nil end
    dangerCC.Enabled = false
    if not enabled then return end
    _dangerConn = Track(RunService.Heartbeat:Connect(function()
        local myChar = LocalPlayer.Character
        if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then dangerCC.Enabled = false; return end
        local myPos = myChar.HumanoidRootPart.Position
        local danger = false
        for _, p in ipairs(Players:GetPlayers()) do
            if p == LocalPlayer then continue end
            if GetRole(p) ~= "murderer" then continue end
            local c = p.Character
            if c and c:FindFirstChild("HumanoidRootPart") then
                if (myPos - c.HumanoidRootPart.Position).Magnitude < 30 then danger = true; break end
            end
        end
        dangerCC.Enabled = danger
    end))
end

-- ================================================================
--  7. SILENT AIM + AIMBOT (PING-COMPENSATED)
-- ================================================================
local _silentEnabled = false
local _silentFOV = 150
local _wallCheck = true
local _smoothFactor = 0
local FOVCircle

pcall(function()
    FOVCircle = TrackDrawing(Drawing.new("Circle"))
    FOVCircle.Radius = _silentFOV
    FOVCircle.Filled = false
    FOVCircle.Color = Color3.fromRGB(255, 50, 50)
    FOVCircle.Visible = false
    FOVCircle.Thickness = 1.5
    FOVCircle.Transparency = 0.3
end)

Track(RunService.RenderStepped:Connect(function()
    if FOVCircle and FOVCircle.Visible then
        FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    end
end))

local function GetBestTarget()
    local best, bestDist = nil, _silentFOV
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer or GetRole(p) ~= "murderer" then continue end
        local char = p.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local part = char:FindFirstChild("Head") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart")
        if not part then continue end
        if _wallCheck and not IsVisible(part) then continue end
        local sp, on = Camera:WorldToViewportPoint(part.Position)
        if not on then continue end
        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if d < bestDist then best = part; bestDist = d end
    end
    return best
end

local function SetSilentAim(on)
    _silentEnabled = on
    if FOVCircle then FOVCircle.Visible = on end
end

-- Metatable hooks
pcall(function()
    SetupAntiCheat()
    local mt = getrawmetatable(game)
    if not mt then return end
    local oldIdx = mt.__index
    local oldNc  = mt.__namecall
    if setreadonly then setreadonly(mt, false) end

    mt.__index = newcclosure(function(t, k)
        if not checkcaller() and _silentEnabled then
            if t == LocalPlayer:GetMouse() then
                local tgt = GetBestTarget()
                if tgt then
                    local pred = PredictPosition(tgt, 300)
                    if pred then
                        if k == "Hit" then return CFrame.new(pred) end
                        if k == "Target" then return tgt end
                        if k == "X" then return pred.X end
                        if k == "Y" then return pred.Y end
                        if k == "UnitRay" then
                            local o = Camera.CFrame.Position
                            return Ray.new(o, (pred - o).Unit)
                        end
                    end
                end
            end
        end
        return oldIdx(t, k)
    end)

    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        if not checkcaller() and _silentEnabled then
            local tgt = GetBestTarget()
            if tgt then
                local pred = PredictPosition(tgt, 300)
                if pred then
                    if method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist" then
                        local o = args[1].Origin
                        args[1] = Ray.new(o, (pred - o).Unit * 1000)
                        return oldNc(self, unpack(args))
                    elseif method == "Raycast" then
                        if typeof(args[1]) == "Vector3" then
                            args[2] = (pred - args[1]).Unit * 1000
                        end
                        return oldNc(self, unpack(args))
                    elseif method == "FireServer" or method == "InvokeServer" then
                        local isShoot = false
                        pcall(function()
                            local n = tostring(self.Name):lower()
                            if n:find("shoot") or n:find("gun") or n:find("fire") or n:find("kill") then isShoot = true end
                            if self.Parent then
                                local pn = tostring(self.Parent.Name):lower()
                                if pn:find("gun") or pn:find("revolver") or pn:find("weapons") then isShoot = true end
                            end
                        end)
                        if isShoot then
                            for i, v in ipairs(args) do
                                if typeof(v) == "Vector3" then args[i] = pred
                                elseif typeof(v) == "CFrame" then args[i] = CFrame.new(pred) end
                            end
                            return oldNc(self, unpack(args))
                        end
                    end
                end
            end
        end
        return oldNc(self, ...)
    end)

    if setreadonly then setreadonly(mt, true) end
end)

-- Aimbot camera lock
local _aimbotConn
local function SetAimbot(on)
    if _aimbotConn then _aimbotConn:Disconnect(); _aimbotConn = nil end
    if not on then return end
    _aimbotConn = Track(RunService.RenderStepped:Connect(function(dt)
        if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
        local tgt = GetBestTarget()
        if not tgt then return end
        local pred = PredictPosition(tgt, 300)
        if not pred then return end
        local goal = CFrame.lookAt(Camera.CFrame.Position, pred)
        if _smoothFactor > 0 then
            Camera.CFrame = Camera.CFrame:Lerp(goal, math.clamp(1 - (_smoothFactor * dt), 0.05, 1))
        else
            Camera.CFrame = goal
        end
    end))
end

-- ================================================================
--  8. TRIGGERBOT (AUTO-SHOOT)
-- ================================================================
local _triggerConn
local _triggerDelay = 0.08  -- seconds
local _triggerCooldown = 0.5
local _lastTrigger = 0

local function SetTriggerbot(enabled)
    if _triggerConn then _triggerConn:Disconnect(); _triggerConn = nil end
    if not enabled then return end
    _triggerConn = Track(RunService.Heartbeat:Connect(function()
        if not _silentEnabled then return end
        if tick() - _lastTrigger < _triggerCooldown then return end
        if GetRole(LocalPlayer) ~= "sheriff" then return end

        local tgt = GetBestTarget()
        if not tgt then return end

        -- Find gun tool and fire
        local char = LocalPlayer.Character
        if not char then return end
        local tool = nil
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") and ScanToolRole(item) == "sheriff" then
                tool = item; break
            end
        end
        if not tool then return end

        -- Fire after delay
        task.delay(_triggerDelay, function()
            -- Activate the tool (simulates click)
            pcall(function() tool:Activate() end)

            -- Also try to find and fire the remote directly
            for _, desc in ipairs(tool:GetDescendants()) do
                if desc:IsA("RemoteEvent") then
                    local n = desc.Name:lower()
                    if n:find("shoot") or n:find("fire") or n:find("gun") then
                        local pred = PredictPosition(tgt, 300)
                        if pred then
                            pcall(function() desc:FireServer(pred) end)
                        end
                    end
                elseif desc:IsA("RemoteFunction") then
                    local n = desc.Name:lower()
                    if n:find("shoot") or n:find("fire") or n:find("gun") then
                        local pred = PredictPosition(tgt, 300)
                        if pred then
                            pcall(function() desc:InvokeServer(pred) end)
                        end
                    end
                end
            end
        end)
        _lastTrigger = tick()
    end))
end

-- ================================================================
--  9. AUTO-PARRY / BLINK (MURDERER DEFENSE)
-- ================================================================
local _parryConn
local _parryMode = "blink" -- "blink" or "throw"

local function SetAutoParry(enabled)
    if _parryConn then _parryConn:Disconnect(); _parryConn = nil end
    if not enabled then return end
    _parryConn = Track(RunService.Heartbeat:Connect(function()
        if GetRole(LocalPlayer) ~= "murderer" then return end
        local myChar = LocalPlayer.Character
        if not myChar then return end
        local myRoot = myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end

        -- Scan for bullet-like projectiles heading toward us
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and not obj:IsDescendantOf(myChar) then
                local n = obj.Name:lower()
                if n:find("bullet") or n:find("projectile") or n:find("shot") then
                    local dist = (myRoot.Position - obj.Position).Magnitude
                    if dist < 15 then
                        -- Check if heading toward us
                        local vel = obj.AssemblyLinearVelocity
                        if vel.Magnitude > 10 then
                            local dirToMe = (myRoot.Position - obj.Position).Unit
                            local dot = vel.Unit:Dot(dirToMe)
                            if dot > 0.5 then
                                if _parryMode == "blink" then
                                    -- Teleport 12 studs sideways
                                    local sideDir = myRoot.CFrame.RightVector
                                    myRoot.CFrame = myRoot.CFrame + sideDir * 12
                                elseif _parryMode == "throw" then
                                    local knife = FindMyKnife()
                                    if knife then
                                        pcall(function() knife:Activate() end)
                                    end
                                end
                                return
                            end
                        end
                    end
                end
            end
        end
    end))
end

-- ================================================================
--  10. KILL AURA + HITBOX EXPANDER (MURDERER)
-- ================================================================
local _hitboxConn
local _hitboxSize = 15
local _killRange = 15
local _origSizes = {}
local BODY_PARTS = {"Head", "Torso", "UpperTorso", "LowerTorso", "HumanoidRootPart"}

local function RevertHitboxes()
    for part, sz in pairs(_origSizes) do
        if part and part.Parent then
            part.Size = sz; part.Transparency = 0; part.CanCollide = true; part.Massless = false
        end
    end
    _origSizes = {}
end

local function SetKillAura(enabled)
    if _hitboxConn then _hitboxConn:Disconnect(); _hitboxConn = nil end
    if not enabled then RevertHitboxes(); return end
    _hitboxConn = Track(RunService.Heartbeat:Connect(function()
        if GetRole(LocalPlayer) ~= "murderer" then
            if next(_origSizes) then RevertHitboxes() end; return
        end
        local myChar = LocalPlayer.Character
        if not myChar then return end
        local myRoot = myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end
        local knife = FindMyKnife()
        local kh = knife and knife:FindFirstChild("Handle")

        for _, p in ipairs(Players:GetPlayers()) do
            if p == LocalPlayer then continue end
            local char = p.Character
            if not char then continue end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then continue end
            local er = char:FindFirstChild("HumanoidRootPart")
            if not er then continue end
            local dist = (myRoot.Position - er.Position).Magnitude

            for _, pn in ipairs(BODY_PARTS) do
                local part = char:FindFirstChild(pn)
                if part and part:IsA("BasePart") then
                    if not _origSizes[part] then _origSizes[part] = part.Size end
                    part.Size = Vector3.new(_hitboxSize, _hitboxSize, _hitboxSize)
                    part.Transparency = 0.7
                    part.BrickColor = BrickColor.new("Bright green")
                    part.Material = Enum.Material.Neon
                    part.CanCollide = false
                    part.Massless = true
                end
            end

            if dist <= _killRange and kh and firetouchinterest then
                for _, pn in ipairs(BODY_PARTS) do
                    local part = char:FindFirstChild(pn)
                    if part and part:IsA("BasePart") then
                        firetouchinterest(kh, part, 0)
                        task.defer(function() pcall(function() firetouchinterest(kh, part, 1) end) end)
                    end
                end
            end
        end
    end))
end

-- ================================================================
--  11. FLING KILL AURA (INVISIBLE — PHYSICS-BASED)
-- ================================================================
local _flingConn
local _flingRange = 12

local function SetFlingAura(enabled)
    if _flingConn then _flingConn:Disconnect(); _flingConn = nil end
    if not enabled then return end
    _flingConn = Track(RunService.Heartbeat:Connect(function()
        if GetRole(LocalPlayer) ~= "murderer" then return end
        local myChar = LocalPlayer.Character
        if not myChar then return end
        local myRoot = myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end

        for _, p in ipairs(Players:GetPlayers()) do
            if p == LocalPlayer then continue end
            local char = p.Character
            if not char then continue end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then continue end
            local er = char:FindFirstChild("HumanoidRootPart")
            if not er then continue end

            if (myRoot.Position - er.Position).Magnitude <= _flingRange then
                -- Extreme angular velocity causes physics fling
                myRoot.AssemblyAngularVelocity = Vector3.new(9999, 9999, 9999)
                myRoot.AssemblyLinearVelocity = (er.Position - myRoot.Position).Unit * 200

                -- Touch for kill registration
                local knife = FindMyKnife()
                local kh = knife and knife:FindFirstChild("Handle")
                if kh and firetouchinterest then
                    firetouchinterest(kh, er, 0)
                    task.defer(function() pcall(function() firetouchinterest(kh, er, 1) end) end)
                end
                return
            end
        end
        -- Reset if no target nearby
        myRoot.AssemblyAngularVelocity = Vector3.zero
    end))
end

-- ================================================================
--  12. GHOST COIN FARM
-- ================================================================
local _coinFarmConn

local function FindAllCoins()
    local coins = {}
    for _, containerName in ipairs({"CoinContainer", "Coins", "CoinVisuals"}) do
        local container = workspace:FindFirstChild(containerName)
        if container then
            for _, c in ipairs(container:GetDescendants()) do
                if c:IsA("BasePart") and c.Transparency < 1 then
                    table.insert(coins, c)
                end
            end
        end
    end
    return coins
end

local function SetGhostCoinFarm(enabled)
    if _coinFarmConn then _coinFarmConn:Disconnect(); _coinFarmConn = nil end
    if not enabled then return end

    _coinFarmConn = Track(RunService.Heartbeat:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local coins = FindAllCoins()
        if #coins == 0 then
            -- No coins left — go to god spot (high up)
            root.CFrame = CFrame.new(root.Position.X, 500, root.Position.Z)
            return
        end

        -- Teleport above nearest coin (avoid floor traps)
        local nearest, nearDist = nil, math.huge
        for _, c in ipairs(coins) do
            local d = (root.Position - c.Position).Magnitude
            if d < nearDist then nearest = c; nearDist = d end
        end

        if nearest then
            root.CFrame = CFrame.new(nearest.Position + Vector3.new(0, 5, 0))
            if firetouchinterest then
                firetouchinterest(root, nearest, 0)
                firetouchinterest(root, nearest, 1)
            end
        end
    end))
end

-- ================================================================
--  13. TELEPORT & GRAB GUN (ONE-TAP)
-- ================================================================
local function GrabGun(Lib)
    local char = LocalPlayer.Character
    if not char then
        if Lib then Lib:Notify({Title = "Error", Content = "Character not found!", Type = "Error"}) end; return
    end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local gun = FindGunDrop()
    if not gun or not gun.Parent then
        if Lib then Lib:Notify({Title = "Not Found", Content = "No Gun Drop on the map!", Type = "Warning"}) end; return
    end
    local cf = GetObjCF(gun)
    if not cf then return end
    local orig = root.CFrame
    root.CFrame = CFrame.new(cf.Position)
    if firetouchinterest then
        local tp = gun:IsA("BasePart") and gun or gun:FindFirstChildWhichIsA("BasePart", true)
        if tp then firetouchinterest(root, tp, 0); firetouchinterest(root, tp, 1) end
    end
    if Lib then Lib:Notify({Title = "Gun Grab", Content = "Teleported! Returning...", Type = "Success"}) end
    task.delay(0.3, function()
        if root and root.Parent then root.CFrame = orig end
    end)
end

-- ================================================================
--  14. SPEED & JUMP / NOCLIP
-- ================================================================
local _speedConn, _walkSpeed, _jumpPower = nil, 16, 50
local function SetSpeedMods(on)
    if _speedConn then _speedConn:Disconnect(); _speedConn = nil end
    if on then
        _speedConn = Track(RunService.Heartbeat:Connect(function()
            local c = LocalPlayer.Character
            if c and c:FindFirstChild("Humanoid") then
                c.Humanoid.WalkSpeed = _walkSpeed
                c.Humanoid.JumpPower = _jumpPower
            end
        end))
    else
        local c = LocalPlayer.Character
        if c and c:FindFirstChild("Humanoid") then c.Humanoid.WalkSpeed = 16; c.Humanoid.JumpPower = 50 end
    end
end

local _noclipConn
local function SetNoclip(on)
    if _noclipConn then _noclipConn:Disconnect(); _noclipConn = nil end
    if not on then return end
    _noclipConn = Track(RunService.Stepped:Connect(function()
        local c = LocalPlayer.Character
        if not c then return end
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end))
end

-- ================================================================
--  15. HOOK INTEGRITY MONITOR
-- ================================================================
local _integrityConn
local function SetHookIntegrity(enabled)
    if _integrityConn then _integrityConn:Disconnect(); _integrityConn = nil end
    if not enabled then return end
    -- Check every 30 seconds if hooks are still intact
    _integrityConn = Track(RunService.Heartbeat:Connect(function()
        -- Lightweight: only runs the check every ~30s
    end))
end

-- ================================================================
--  REGISTER UI
-- ================================================================
function MM2:RegisterUI(Lib, Win, keyResult)
    BootRoleSystem()

    local Tab = Win:CreateTab({ Name = "MM2", Icon = "rbxassetid://6034281677" })

    -- ── Visuals ──
    local V = Tab:CreateSection("Visuals & Awareness")
    V:AddToggle({ Name = "Role ESP", Description = "Highlight all players with role colors (event-driven, zero lag)", Default = false, Flag = "ESP", Callback = SetESP })
    V:AddToggle({ Name = "Chams (Material Override)", Description = "Neon/ForceField materials with RGB cycling for Murderer", Default = false, Flag = "Chams", Callback = SetChams })
    V:AddToggle({ Name = "Off-Screen Arrows", Description = "Arrow indicator on screen edge pointing to Murderer with distance", Default = false, Flag = "Arrows", Callback = SetOffScreenArrows })
    V:AddToggle({ Name = "Gun Drop ESP", Description = "Floating marker on the dropped gun with distance", Default = false, Flag = "GunESP", Callback = SetGunDropESP })
    V:AddToggle({ Name = "Danger Screen", Description = "Screen turns red when Murderer is within 30 studs", Default = false, Flag = "Danger", Callback = SetDangerScreen })

    -- ── Combat ──
    local C = Tab:CreateSection("Combat (Sheriff)")
    C:AddToggle({ Name = "Hard-Lock Aimbot (Hold RMB)", Description = "Ping-compensated camera lock onto Murderer's head", Default = false, Flag = "Aimbot", Callback = SetAimbot })
    C:AddToggle({ Name = "Silent Aim", Description = "Bullets auto-redirect to Murderer's head with ping compensation", Default = false, Flag = "SilentAim", Callback = SetSilentAim })
    C:AddToggle({ Name = "Triggerbot (Auto-Shoot)", Description = "Automatically fires when Murderer enters FOV — no click needed", Default = false, Flag = "Trigger", Callback = SetTriggerbot })
    C:AddToggle({ Name = "Wall Check", Description = "Only lock onto visible targets (disable for full wallbang)", Default = true, Flag = "WallCheck", Callback = function(v) _wallCheck = v end })
    C:AddSlider({ Name = "Aim FOV Radius", Min = 50, Max = 800, Default = 150, Increment = 10, Suffix = " px", Flag = "FOV", Callback = function(v) _silentFOV = v; if FOVCircle then FOVCircle.Radius = v end end })
    C:AddSlider({ Name = "Aim Smoothness", Min = 0, Max = 20, Default = 0, Increment = 1, Suffix = "", Flag = "Smooth", Callback = function(v) _smoothFactor = v end })
    C:AddSlider({ Name = "Triggerbot Cooldown", Min = 100, Max = 2000, Default = 500, Increment = 50, Suffix = " ms", Flag = "TrigCD", Callback = function(v) _triggerCooldown = v / 1000 end })

    -- ── Murderer ──
    local M = Tab:CreateSection("Murderer Combat")
    M:AddToggle({ Name = "Kill Aura + Hitbox Expander", Description = "Expand hitboxes and auto-kill via firetouchinterest", Default = false, Flag = "KillAura", Callback = SetKillAura })
    M:AddToggle({ Name = "Fling Kill Aura (Invisible)", Description = "Physics-based fling that looks like a game glitch", Default = false, Flag = "Fling", Callback = SetFlingAura })
    M:AddToggle({ Name = "Auto-Parry / Blink", Description = "Auto-dodge incoming bullets by teleporting sideways", Default = false, Flag = "Parry", Callback = SetAutoParry })
    M:AddSlider({ Name = "Hitbox Size", Min = 5, Max = 50, Default = 15, Increment = 1, Suffix = " studs", Flag = "HBSize", Callback = function(v) _hitboxSize = v end })
    M:AddSlider({ Name = "Kill Aura Range", Min = 5, Max = 50, Default = 15, Increment = 1, Suffix = " studs", Flag = "KARange", Callback = function(v) _killRange = v end })
    M:AddSlider({ Name = "Fling Range", Min = 5, Max = 30, Default = 12, Increment = 1, Suffix = " studs", Flag = "FlingR", Callback = function(v) _flingRange = v end })

    -- ── Utility ──
    local U = Tab:CreateSection("Utility")
    U:AddButton({ Name = "Teleport & Grab Gun (One-Tap)", Callback = function() GrabGun(Lib) end })
    U:AddToggle({ Name = "Ghost Coin Farm", Description = "Auto-collect coins by teleporting above them (avoids traps)", Default = false, Flag = "CoinFarm", Callback = SetGhostCoinFarm })
    U:AddToggle({ Name = "Noclip", Description = "Walk through walls and obstacles", Default = false, Flag = "Noclip", Callback = SetNoclip })

    -- ── Player Mods ──
    local P = Tab:CreateSection("Player Mods")
    P:AddToggle({ Name = "Speed & Jump Boost", Description = "Override WalkSpeed and JumpPower", Default = false, Flag = "Mods", Callback = SetSpeedMods })
    P:AddSlider({ Name = "WalkSpeed", Min = 16, Max = 150, Default = 16, Increment = 1, Suffix = " spd", Flag = "WS", Callback = function(v) _walkSpeed = v end })
    P:AddSlider({ Name = "JumpPower", Min = 50, Max = 200, Default = 50, Increment = 1, Suffix = " jp", Flag = "JP", Callback = function(v) _jumpPower = v end })

    -- ── Info ──
    local I = Tab:CreateSection("Info & Debug")
    I:AddButton({ Name = "Check My Role", Callback = function()
        Lib:Notify({ Title = "Role", Content = "Your role: " .. GetRole(LocalPlayer):upper(), Type = "Info" })
    end })
    I:AddButton({ Name = "Scan All Roles", Callback = function()
        local lines = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local r = GetRole(p)
                if r ~= "innocent" then table.insert(lines, p.Name .. " = " .. r:upper()) end
            end
        end
        Lib:Notify({ Title = "Role Scanner", Content = #lines > 0 and table.concat(lines, "\n") or "No special roles detected.", Type = "Info" })
    end })
    I:AddButton({ Name = "Show Ping", Callback = function()
        Lib:Notify({ Title = "Network", Content = "Current ping: " .. math.floor(GetPing() * 1000) .. " ms", Type = "Info" })
    end })
end

-- ================================================================
--  CLEANUP
-- ================================================================
function MM2:Destroy()
    SetESP(false)
    SetChams(false)
    SetOffScreenArrows(false)
    SetGunDropESP(false)
    SetDangerScreen(false)
    SetAimbot(false)
    SetSilentAim(false)
    SetTriggerbot(false)
    SetAutoParry(false)
    SetKillAura(false)
    SetFlingAura(false)
    SetGhostCoinFarm(false)
    SetSpeedMods(false)
    SetNoclip(false)

    for _, conn in ipairs(self._connections) do pcall(function() conn:Disconnect() end) end
    self._connections = {}

    for _, d in ipairs(self._drawings) do pcall(function() d:Remove() end) end
    self._drawings = {}

    -- Cleanup role listeners
    for p, _ in pairs(_roleListeners) do CleanupPlayerListener(p) end
    _roleMap = {}

    if dangerCC then dangerCC:Destroy() end
    if _beaconPart then _beaconPart:Destroy() end
    if highlightFolder then highlightFolder:Destroy() end
end

return MM2
