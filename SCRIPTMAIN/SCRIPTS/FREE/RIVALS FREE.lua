--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║  BorcaHub  •  RIVALS V7 (PRODUCTION BUILD)                    ║
    ║                                                              ║
    ║  Fixes Applied:                                              ║
    ║   1. RenderStepped connection guard (no duplicates)          ║
    ║   2. Drawing API with Instance fallback                      ║
    ║   3. Throttled raycasts (0.15s per player)                   ║
    ║   4. Safe Tool/Backpack access                               ║
    ║   5. Velocity smoothing (EMA low-pass filter)                ║
    ║   6. CharacterAdded auto-refresh                             ║
    ║   7. Robust UI parent fallback chain                         ║
    ║   8. Reversible FPS Boost (toggle on/off)                    ║
    ╚══════════════════════════════════════════════════════════════╝
--]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local Lighting         = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

-- ================================================================
--  FIX #7: ROBUST UI PARENT CHAIN
-- ================================================================
local SafeUI
do
    local ok, result = pcall(function()
        if gethui then return gethui() end
    end)
    if ok and result then
        SafeUI = result
    else
        local coreOk, coreGui = pcall(function()
            return game:GetService("CoreGui")
        end)
        if coreOk and coreGui then
            SafeUI = coreGui
        else
            SafeUI = LocalPlayer:WaitForChild("PlayerGui")
        end
    end
end

local PremiumScript = {
    _connections      = {},
    _espObjects       = {},
    _espLoopConn      = nil,   -- FIX #1: single reference
    _aimbotLoopConn   = nil,   -- FIX #1: single reference
    _charAddedConn    = nil,   -- FIX #6: character listener
    _lib              = nil,
    _win              = nil,
}

local function Track(conn)
    table.insert(PremiumScript._connections, conn)
    return conn
end

-- ================================================================
--  FIX #6: CHARACTER REFERENCE AUTO-REFRESH
-- ================================================================
local MyCharacter = LocalPlayer.Character
local MyRoot      = MyCharacter and (MyCharacter:FindFirstChild("HumanoidRootPart") or MyCharacter.PrimaryPart)

local function RefreshCharacter(newChar)
    MyCharacter = newChar
    MyRoot = nil
    if newChar then
        local root = newChar:WaitForChild("HumanoidRootPart", 5)
        if root then
            MyRoot = root
        else
            MyRoot = newChar.PrimaryPart or newChar:FindFirstChild("Head")
        end
    end
end

PremiumScript._charAddedConn = LocalPlayer.CharacterAdded:Connect(function(char)
    RefreshCharacter(char)
end)

if MyCharacter then
    task.spawn(function() RefreshCharacter(MyCharacter) end)
end

-- ================================================================
--  CONFIGURATIONS
-- ================================================================
local Config = {
    AimbotEnabled  = false,
    AimbotKey      = Enum.UserInputType.MouseButton2,
    AimMethod      = "Mouse",
    TargetPart     = "Head",
    WallCheck      = true,
    TeamCheck      = true,
    Smoothness     = 1,
    Prediction     = false,
    PredFactor     = 0.15,

    FOVEnabled     = true,
    FOVRadius      = 120,

    ESPEnabled     = false,
    ESPArenaOnly   = false,
    ESPMaxDist     = 1000,
    ESPColor       = Color3.fromRGB(255, 60, 60),
    ESPVisibleClr  = Color3.fromRGB(60, 255, 60),
    ESPBox         = true,
    ESPCornerBox   = true,
    ESPTracer      = false,
    ESPSkeleton    = false,
    ESPHighlight   = false,
    ESPName        = true,
    ESPDist        = true,
    ESPHealth      = true,
    ESPHPText      = true,
    ESPWeapon      = true,
    ESPOffScreen   = false,

    FPSBoosted     = false,  -- FIX #8: toggle state
}

-- ================================================================
--  FIX #2: DRAWING API DETECTION + FALLBACK
-- ================================================================
local UseDrawingAPI = false
do
    local ok = pcall(function()
        local test = Drawing.new("Line")
        test:Remove()
    end)
    UseDrawingAPI = ok
end

-- ================================================================
--  FIX #3: THROTTLED VISIBILITY CACHE
-- ================================================================
local VisibilityCache = {}  -- [player] = { visible = bool, lastCheck = tick() }
local VIS_CHECK_INTERVAL = 0.15  -- seconds between raycasts per player

local function IsVisibleThrottled(targetPos, targetChar, player)
    if not MyCharacter then return false end
    
    local now = tick()
    local cached = VisibilityCache[player]
    
    if cached and (now - cached.lastCheck) < VIS_CHECK_INTERVAL then
        return cached.visible
    end
    
    local origin = Camera.CFrame.Position
    local direction = targetPos - origin

    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {MyCharacter, Camera}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.IgnoreWater = true

    local result = Workspace:Raycast(origin, direction, rayParams)
    local visible = true
    
    if result then
        if targetChar and result.Instance:IsDescendantOf(targetChar) then
            visible = true
        else
            visible = false
        end
    end
    
    VisibilityCache[player] = { visible = visible, lastCheck = now }
    return visible
end

-- ================================================================
--  FIX #5: VELOCITY SMOOTHING (EMA LOW-PASS FILTER)
-- ================================================================
local SmoothedVelocities = {}  -- [player] = Vector3
local EMA_ALPHA = 0.3  -- lower = smoother but slower to react

local function GetSmoothedVelocity(player, currentVelocity)
    if not currentVelocity then return Vector3.zero end
    
    local prev = SmoothedVelocities[player]
    if not prev then
        SmoothedVelocities[player] = currentVelocity
        return currentVelocity
    end
    
    local smoothed = prev:Lerp(currentVelocity, EMA_ALPHA)
    SmoothedVelocities[player] = smoothed
    return smoothed
end

-- ================================================================
--  UNIVERSAL GUI (for FOV circle only, ESP uses Drawing API)
-- ================================================================
local MainGui = Instance.new("ScreenGui")
MainGui.Name = "Borca_V7"
MainGui.IgnoreGuiInset = true
MainGui.ResetOnSpawn = false
MainGui.ZIndexBehavior = Enum.ZIndexBehavior.Global

do
    local ok = pcall(function() MainGui.Parent = SafeUI end)
    if not ok or not MainGui.Parent then
        pcall(function() MainGui.Parent = game:GetService("CoreGui") end)
    end
    if not MainGui.Parent then
        MainGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end

-- FOV Circle (lightweight, only 1 instance)
local FovCircle = Instance.new("Frame", MainGui)
FovCircle.BackgroundTransparency = 1
FovCircle.Visible = false
local FovStroke = Instance.new("UIStroke", FovCircle)
FovStroke.Color = Color3.fromRGB(255, 255, 255)
FovStroke.Thickness = 1.5
FovStroke.Transparency = 0.3
Instance.new("UICorner", FovCircle).CornerRadius = UDim.new(1, 0)

local function UpdateFOV()
    if Config.FOVEnabled then
        local diam = Config.FOVRadius * 2
        FovCircle.Size = UDim2.new(0, diam, 0, diam)
        FovCircle.Position = UDim2.new(0.5, -Config.FOVRadius, 0.5, -Config.FOVRadius)
        FovCircle.Visible = true
    else
        FovCircle.Visible = false
    end
end

-- ================================================================
--  FIX #2: DRAWING API WRAPPER (with Instance fallback)
-- ================================================================
local Draw = {}

if UseDrawingAPI then
    function Draw.Line()
        local obj = Drawing.new("Line")
        obj.Visible = false
        obj.Thickness = 1.5
        obj.Color = Color3.new(1, 1, 1)
        return {
            _type = "drawing",
            _obj = obj,
            SetLine = function(self, p1, p2, color, thick, vis)
                if not vis or not p1 or not p2 then
                    self._obj.Visible = false
                    return
                end
                self._obj.From = p1
                self._obj.To = p2
                self._obj.Color = color
                self._obj.Thickness = thick
                self._obj.Visible = true
            end,
            Hide = function(self) self._obj.Visible = false end,
            Destroy = function(self) self._obj:Remove() end,
        }
    end

    function Draw.Text()
        local obj = Drawing.new("Text")
        obj.Visible = false
        obj.Size = 13
        obj.Center = true
        obj.Outline = true
        obj.OutlineColor = Color3.new(0, 0, 0)
        obj.Color = Color3.new(1, 1, 1)
        return {
            _type = "drawing",
            _obj = obj,
            SetText = function(self, text, pos, color, size, vis, transparency)
                if not vis then self._obj.Visible = false return end
                self._obj.Text = text
                self._obj.Position = pos
                self._obj.Color = color
                self._obj.Size = size or 13
                self._obj.Transparency = transparency or 1
                self._obj.Visible = true
            end,
            Hide = function(self) self._obj.Visible = false end,
            Destroy = function(self) self._obj:Remove() end,
        }
    end
else
    -- Instance-based fallback
    function Draw.Line()
        local frame = Instance.new("Frame", MainGui)
        frame.AnchorPoint = Vector2.new(0.5, 0.5)
        frame.BackgroundColor3 = Color3.new(1, 1, 1)
        frame.BorderSizePixel = 0
        frame.Visible = false
        return {
            _type = "instance",
            _obj = frame,
            SetLine = function(self, p1, p2, color, thick, vis)
                if not vis or not p1 or not p2 then
                    self._obj.Visible = false
                    return
                end
                local d = (p2 - p1).Magnitude
                if d < 1 then self._obj.Visible = false return end
                local c = (p1 + p2) / 2
                local a = math.deg(math.atan2(p2.Y - p1.Y, p2.X - p1.X))
                self._obj.Size = UDim2.new(0, d, 0, thick)
                self._obj.Position = UDim2.new(0, c.X, 0, c.Y)
                self._obj.Rotation = a
                self._obj.BackgroundColor3 = color
                self._obj.Visible = true
            end,
            Hide = function(self) self._obj.Visible = false end,
            Destroy = function(self) self._obj:Destroy() end,
        }
    end

    function Draw.Text()
        local lbl = Instance.new("TextLabel", MainGui)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 13
        lbl.TextColor3 = Color3.new(1, 1, 1)
        lbl.Visible = false
        lbl.ZIndex = 10
        local s = Instance.new("UIStroke", lbl)
        s.Thickness = 1.2; s.Color = Color3.new(0, 0, 0)
        return {
            _type = "instance",
            _obj = lbl,
            _stroke = s,
            SetText = function(self, text, pos, color, size, vis, transparency)
                if not vis then self._obj.Visible = false return end
                self._obj.Text = text
                self._obj.Size = UDim2.new(0, 200, 0, size or 13)
                self._obj.Position = UDim2.new(0, pos.X - 100, 0, pos.Y)
                self._obj.TextColor3 = color
                self._obj.TextSize = size or 13
                self._obj.TextTransparency = transparency and (1 - transparency) or 0
                self._obj.Visible = true
            end,
            Hide = function(self) self._obj.Visible = false end,
            Destroy = function(self) self._obj:Destroy() end,
        }
    end
end

-- ================================================================
--  ESP OBJECT CREATION (Using Draw wrapper)
-- ================================================================
local function CreatePlayerESP()
    local e = {}
    e.corners = {} for i = 1, 8 do e.corners[i] = Draw.Line() end
    e.boxLines = {} for i = 1, 4 do e.boxLines[i] = Draw.Line() end
    e.nameLbl = Draw.Text()
    e.distLbl = Draw.Text()
    e.hpText = Draw.Text()
    e.weaponLbl = Draw.Text()
    e.hpBg = Draw.Line()
    e.hpFill = Draw.Line()
    e.tracer = Draw.Line()
    e.skel = {} for i = 1, 10 do e.skel[i] = Draw.Line() end

    -- Highlight (always Instance-based, lightweight)
    e.highlight = Instance.new("Highlight")
    e.highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    e.highlight.FillTransparency = 0.65
    e.highlight.OutlineTransparency = 0.1
    e.highlight.Enabled = false
    pcall(function() e.highlight.Parent = SafeUI end)
    if not e.highlight.Parent then
        pcall(function() e.highlight.Parent = LocalPlayer:WaitForChild("PlayerGui") end)
    end

    -- Off-screen arrow (simple text)
    e.arrow = Draw.Text()

    return e
end

local function ClearESP(player)
    local e = PremiumScript._espObjects[player]
    if not e then return end
    
    for _, c in ipairs(e.corners) do pcall(function() c:Destroy() end) end
    for _, b in ipairs(e.boxLines) do pcall(function() b:Destroy() end) end
    for _, s in ipairs(e.skel) do pcall(function() s:Destroy() end) end
    pcall(function() e.nameLbl:Destroy() end)
    pcall(function() e.distLbl:Destroy() end)
    pcall(function() e.hpText:Destroy() end)
    pcall(function() e.weaponLbl:Destroy() end)
    pcall(function() e.hpBg:Destroy() end)
    pcall(function() e.hpFill:Destroy() end)
    pcall(function() e.tracer:Destroy() end)
    pcall(function() e.highlight:Destroy() end)
    pcall(function() e.arrow:Destroy() end)
    
    PremiumScript._espObjects[player] = nil
    VisibilityCache[player] = nil
    SmoothedVelocities[player] = nil
end

-- ================================================================
--  UTILITY FUNCTIONS
-- ================================================================
local function GetCharacterRoot(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
        or char:FindFirstChild("Head") or char:FindFirstChild("Torso")
end

-- FIX #4: Safe weapon access
local function GetWeaponName(player, char)
    if not char then return nil end
    
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then return tool.Name end
    
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        local bt = backpack:FindFirstChildOfClass("Tool")
        if bt then return "[" .. bt.Name .. "]" end
    end
    return nil
end

local function HasWeapon(player, char)
    if not char then return false end
    if char:FindFirstChildOfClass("Tool") then return true end
    local backpack = player:FindFirstChild("Backpack")
    return backpack and backpack:FindFirstChildOfClass("Tool") ~= nil
end

-- ================================================================
--  CORNER / FULL BOX DRAWING
-- ================================================================
local function DrawCornerBox(corners, x, y, w, h, color)
    local cl = math.clamp(w * 0.25, 4, 20)
    corners[1]:SetLine(Vector2.new(x, y), Vector2.new(x + cl, y), color, 2, true)
    corners[2]:SetLine(Vector2.new(x, y), Vector2.new(x, y + cl), color, 2, true)
    corners[3]:SetLine(Vector2.new(x + w, y), Vector2.new(x + w - cl, y), color, 2, true)
    corners[4]:SetLine(Vector2.new(x + w, y), Vector2.new(x + w, y + cl), color, 2, true)
    corners[5]:SetLine(Vector2.new(x, y + h), Vector2.new(x + cl, y + h), color, 2, true)
    corners[6]:SetLine(Vector2.new(x, y + h), Vector2.new(x, y + h - cl), color, 2, true)
    corners[7]:SetLine(Vector2.new(x + w, y + h), Vector2.new(x + w - cl, y + h), color, 2, true)
    corners[8]:SetLine(Vector2.new(x + w, y + h), Vector2.new(x + w, y + h - cl), color, 2, true)
end

local function DrawFullBox(lines, x, y, w, h, color)
    lines[1]:SetLine(Vector2.new(x, y), Vector2.new(x + w, y), color, 1.5, true)
    lines[2]:SetLine(Vector2.new(x + w, y), Vector2.new(x + w, y + h), color, 1.5, true)
    lines[3]:SetLine(Vector2.new(x, y + h), Vector2.new(x + w, y + h), color, 1.5, true)
    lines[4]:SetLine(Vector2.new(x, y), Vector2.new(x, y + h), color, 1.5, true)
end

local function HideAll(list) for _, v in ipairs(list) do v:Hide() end end

-- ================================================================
--  ESP RENDER LOOP (FIX #1: GUARDED, SINGLE CONNECTION)
-- ================================================================
local function ESPHandler()
    -- FIX #1: Kill existing connection before creating new one
    if PremiumScript._espLoopConn then
        PremiumScript._espLoopConn:Disconnect()
        PremiumScript._espLoopConn = nil
    end

    PremiumScript._espLoopConn = RunService.RenderStepped:Connect(function()
        if not Config.ESPEnabled then
            for p in pairs(PremiumScript._espObjects) do ClearESP(p) end
            return
        end

        local camCFrame = Camera.CFrame
        local vSize = Camera.ViewportSize
        local cx, cy = vSize.X / 2, vSize.Y / 2

        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            if Config.TeamCheck and player.Team and player.Team == LocalPlayer.Team then
                ClearESP(player); continue
            end

            local char = player.Character
            local root = GetCharacterRoot(char)
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local head = char and char:FindFirstChild("Head")

            -- Enhanced dead check
            if not char or not root or not hum
                or hum.Health <= 0
                or hum:GetState() == Enum.HumanoidStateType.Dead then
                ClearESP(player); continue
            end

            local worldDist = MyRoot and (root.Position - MyRoot.Position).Magnitude or 0
            if worldDist > Config.ESPMaxDist then ClearESP(player); continue end

            if Config.ESPArenaOnly and not HasWeapon(player, char) then
                ClearESP(player); continue
            end

            if not PremiumScript._espObjects[player] then
                PremiumScript._espObjects[player] = CreatePlayerESP()
            end
            local e = PremiumScript._espObjects[player]

            -- FIX #3: Throttled visibility
            local isVis = IsVisibleThrottled(root.Position, char, player)
            local espClr = isVis and Config.ESPVisibleClr or Config.ESPColor
            local fadeFactor = math.clamp(1 - (worldDist / Config.ESPMaxDist) * 0.5, 0.4, 1)

            local tPos = (head and head.Position or root.Position) + Vector3.new(0, 0.5, 0)
            local bPos = root.Position - Vector3.new(0, 3, 0)
            local tScreen, tVis = Camera:WorldToViewportPoint(tPos)
            local bScreen = Camera:WorldToViewportPoint(bPos)
            local rootScreen = Camera:WorldToViewportPoint(root.Position)

            if tVis and rootScreen.Z > 0 then
                e.arrow:Hide()
                local height = math.abs(tScreen.Y - bScreen.Y)
                local width = math.clamp(height / 1.7, 10, 500)
                local bx = tScreen.X - width / 2
                local by = tScreen.Y

                -- Box
                if Config.ESPBox then
                    if Config.ESPCornerBox then
                        DrawCornerBox(e.corners, bx, by, width, height, espClr)
                        HideAll(e.boxLines)
                    else
                        DrawFullBox(e.boxLines, bx, by, width, height, espClr)
                        HideAll(e.corners)
                    end
                else
                    HideAll(e.corners); HideAll(e.boxLines)
                end

                -- Name
                local namePos = Vector2.new(tScreen.X, by - 16)
                e.nameLbl:SetText(player.DisplayName, namePos, espClr, 13, Config.ESPName, fadeFactor)

                -- Distance
                local distPos = Vector2.new(tScreen.X, by + height + 4)
                e.distLbl:SetText(math.floor(worldDist) .. "m", distPos, Color3.fromRGB(200,200,200), 11, Config.ESPDist, fadeFactor)

                -- Weapon
                if Config.ESPWeapon then
                    local wn = GetWeaponName(player, char)
                    if wn then
                        local wPos = Vector2.new(tScreen.X, by + height + (Config.ESPDist and 18 or 4))
                        e.weaponLbl:SetText(wn, wPos, Color3.fromRGB(255, 200, 60), 10, true, fadeFactor)
                    else
                        e.weaponLbl:Hide()
                    end
                else
                    e.weaponLbl:Hide()
                end

                -- Health (normalized)
                if Config.ESPHealth then
                    local maxHp = hum.MaxHealth
                    if maxHp <= 0 or maxHp == math.huge or maxHp > 1000 then maxHp = 100 end
                    local hpPct = math.clamp(hum.Health / maxHp, 0, 1)

                    local barX = bx - 6
                    local barTop = by
                    local barBot = by + height
                    local fillBot = barBot
                    local fillTop = barBot - (height * hpPct)
                    local barColor = Color3.fromRGB(255, 50, 50):Lerp(Color3.fromRGB(40, 255, 40), hpPct)

                    e.hpBg:SetLine(Vector2.new(barX, barTop), Vector2.new(barX, barBot), Color3.fromRGB(20,20,20), 4, true)
                    e.hpFill:SetLine(Vector2.new(barX, fillTop), Vector2.new(barX, fillBot), barColor, 3, true)

                    if Config.ESPHPText then
                        local hpPos = Vector2.new(barX - 20, fillTop - 6)
                        e.hpText:SetText(tostring(math.floor(hum.Health)), hpPos, barColor, 10, true, 1)
                    else
                        e.hpText:Hide()
                    end
                else
                    e.hpBg:Hide(); e.hpFill:Hide(); e.hpText:Hide()
                end

                -- Tracer
                if Config.ESPTracer then
                    e.tracer:SetLine(Vector2.new(cx, vSize.Y), Vector2.new(bScreen.X, bScreen.Y), espClr, 1.5, true)
                else
                    e.tracer:Hide()
                end

                -- Skeleton
                if Config.ESPSkeleton then
                    local function Bone(name)
                        local p = char:FindFirstChild(name)
                        if p then
                            local sp, v = Camera:WorldToViewportPoint(p.Position)
                            if v then return Vector2.new(sp.X, sp.Y) end
                        end
                        return nil
                    end

                    local h = Bone("Head")
                    local ut = Bone("UpperTorso") or Bone("Torso") or Bone("HumanoidRootPart")
                    local lt = Bone("LowerTorso") or ut
                    local lua = Bone("LeftUpperArm") or Bone("Left Arm")
                    local lla = Bone("LeftLowerArm")
                    local rua = Bone("RightUpperArm") or Bone("Right Arm")
                    local rla = Bone("RightLowerArm")
                    local lul = Bone("LeftUpperLeg") or Bone("Left Leg")
                    local lll = Bone("LeftLowerLeg")
                    local rul = Bone("RightUpperLeg") or Bone("Right Leg")
                    local rll = Bone("RightLowerLeg")

                    e.skel[1]:SetLine(h, ut, espClr, 1.5, h and ut)
                    e.skel[2]:SetLine(ut, lt, espClr, 1.5, ut and lt and ut ~= lt)
                    e.skel[3]:SetLine(ut, lua or lla, espClr, 1.5, ut and (lua or lla))
                    e.skel[4]:SetLine(lua, lla, espClr, 1.2, lua and lla)
                    e.skel[5]:SetLine(ut, rua or rla, espClr, 1.5, ut and (rua or rla))
                    e.skel[6]:SetLine(rua, rla, espClr, 1.2, rua and rla)
                    e.skel[7]:SetLine(lt, lul or lll, espClr, 1.5, lt and (lul or lll))
                    e.skel[8]:SetLine(lul, lll, espClr, 1.2, lul and lll)
                    e.skel[9]:SetLine(lt, rul or rll, espClr, 1.5, lt and (rul or rll))
                    e.skel[10]:SetLine(rul, rll, espClr, 1.2, rul and rll)
                else
                    HideAll(e.skel)
                end

            else
                -- Off-Screen
                HideAll(e.corners); HideAll(e.boxLines)
                e.nameLbl:Hide(); e.distLbl:Hide()
                e.hpBg:Hide(); e.hpFill:Hide(); e.hpText:Hide()
                e.weaponLbl:Hide(); e.tracer:Hide()
                HideAll(e.skel)

                if Config.ESPOffScreen then
                    local dir = (root.Position - camCFrame.Position)
                    local flat = Vector3.new(dir.X, 0, dir.Z).Unit
                    local camLook = Vector3.new(camCFrame.LookVector.X, 0, camCFrame.LookVector.Z).Unit
                    local camRight = Vector3.new(camCFrame.RightVector.X, 0, camCFrame.RightVector.Z).Unit

                    local angle = math.atan2(flat:Dot(camRight), flat:Dot(camLook))
                    local margin = 50
                    local ax = cx + math.sin(angle) * (cx - margin)
                    local ay = cy - math.cos(angle) * (cy - margin)

                    e.arrow:SetText("▶", Vector2.new(ax, ay), espClr, 22, true, 1)
                    if e.arrow._type == "instance" then
                        e.arrow._obj.Rotation = math.deg(angle)
                    end
                else
                    e.arrow:Hide()
                end
            end

            -- Highlight
            if Config.ESPHighlight then
                e.highlight.Adornee = char
                e.highlight.FillColor = espClr
                e.highlight.OutlineColor = espClr
                e.highlight.Enabled = true
            else
                e.highlight.Enabled = false
            end
        end
    end)

    Track(PremiumScript._espLoopConn)
    Track(Players.PlayerRemoving:Connect(function(player) ClearESP(player) end))
end

-- ================================================================
--  STICKY AIMBOT (FIX #1: GUARDED + FIX #5: SMOOTHED PREDICTION)
-- ================================================================
local CurrentLockedTarget = nil
local LockedPlayer = nil

local function IsTargetValid(targetPart)
    if not targetPart or not targetPart.Parent then return false end
    local char = targetPart.Parent
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 or hum:GetState() == Enum.HumanoidStateType.Dead then return false end
    local sp, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
    if not onScreen or sp.Z <= 0 then return false end
    if Config.WallCheck and not IsVisibleThrottled(targetPart.Position, char, LockedPlayer) then return false end
    return true
end

local function GetClosestTarget()
    local closestPart, closestPlayer, shortestDist = nil, nil, Config.FOVRadius
    local vSize = Camera.ViewportSize
    local center = Vector2.new(vSize.X / 2, vSize.Y / 2)

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if Config.TeamCheck and player.Team and player.Team == LocalPlayer.Team then continue end

        local char = player.Character
        local root = GetCharacterRoot(char)
        if not char or not root then continue end

        local worldDist = MyRoot and (root.Position - MyRoot.Position).Magnitude or 0
        if worldDist > Config.ESPMaxDist then continue end
        if Config.ESPArenaOnly and not HasWeapon(player, char) then continue end

        local targetNode = char:FindFirstChild(Config.TargetPart) or root
        
        -- Inline validity for target search (uses player for throttled cache)
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 or hum:GetState() == Enum.HumanoidStateType.Dead then continue end
        local sp, onScreen = Camera:WorldToViewportPoint(targetNode.Position)
        if not onScreen or sp.Z <= 0 then continue end
        if Config.WallCheck and not IsVisibleThrottled(targetNode.Position, char, player) then continue end

        local dist = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if dist < shortestDist then
            closestPart = targetNode
            closestPlayer = player
            shortestDist = dist
        end
    end
    return closestPart, closestPlayer
end

local function AimbotHandler()
    -- FIX #1: Kill existing connection before creating new one
    if PremiumScript._aimbotLoopConn then
        PremiumScript._aimbotLoopConn:Disconnect()
        PremiumScript._aimbotLoopConn = nil
    end

    PremiumScript._aimbotLoopConn = RunService.RenderStepped:Connect(function()
        UpdateFOV()
        if not Config.AimbotEnabled then
            CurrentLockedTarget = nil
            LockedPlayer = nil
            return
        end

        if UserInputService:IsMouseButtonPressed(Config.AimbotKey) then
            if not CurrentLockedTarget or not IsTargetValid(CurrentLockedTarget) then
                CurrentLockedTarget, LockedPlayer = GetClosestTarget()
            end

            if CurrentLockedTarget then
                local aimPos = CurrentLockedTarget.Position

                -- FIX #5: Smoothed prediction
                if Config.Prediction and LockedPlayer then
                    local rawVel = CurrentLockedTarget.AssemblyLinearVelocity
                    if rawVel then
                        local smoothVel = GetSmoothedVelocity(LockedPlayer, rawVel)
                        aimPos = aimPos + (smoothVel * Config.PredFactor)
                    end
                end

                if Config.AimMethod == "Mouse" and mousemoverel then
                    local sp = Camera:WorldToViewportPoint(aimPos)
                    local vSize = Camera.ViewportSize
                    local dX = sp.X - (vSize.X / 2)
                    local dY = sp.Y - (vSize.Y / 2)
                    mousemoverel(dX * Config.Smoothness * 0.5, dY * Config.Smoothness * 0.5)
                else
                    local tc = CFrame.new(Camera.CFrame.Position, aimPos)
                    Camera.CFrame = Config.Smoothness < 1 and Camera.CFrame:Lerp(tc, Config.Smoothness) or tc
                end
            end
        else
            CurrentLockedTarget = nil
            LockedPlayer = nil
        end
    end)

    Track(PremiumScript._aimbotLoopConn)
end

-- ================================================================
--  FIX #8: REVERSIBLE FPS BOOSTER
-- ================================================================
local OriginalProperties = {}  -- stores original state for restoration
local FPS_BOOSTED = false

local function BoostFPS()
    if FPS_BOOSTED then return end
    FPS_BOOSTED = true
    Config.FPSBoosted = true

    -- Save Lighting state
    OriginalProperties._lighting = {
        GlobalShadows = Lighting.GlobalShadows,
        FogEnd = Lighting.FogEnd,
    }

    Lighting.GlobalShadows = false
    Lighting.FogEnd = 9e9
    pcall(function() settings().Rendering.QualityLevel = 1 end)

    OriginalProperties._parts = {}
    OriginalProperties._effects = {}

    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and not obj:IsDescendantOf(MyCharacter or {}) then
            OriginalProperties._parts[obj] = {
                Material = obj.Material,
                Reflectance = obj.Reflectance,
                CastShadow = obj.CastShadow,
            }
            obj.Material = Enum.Material.SmoothPlastic
            obj.Reflectance = 0
            obj.CastShadow = false
        elseif obj:IsA("Texture") or obj:IsA("Decal") then
            OriginalProperties._effects[obj] = { Transparency = obj.Transparency }
            obj.Transparency = 1  -- hide instead of destroy
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
            OriginalProperties._effects[obj] = { Enabled = obj.Enabled }
            obj.Enabled = false
        end
    end
end

local function RestoreFPS()
    if not FPS_BOOSTED then return end
    FPS_BOOSTED = false
    Config.FPSBoosted = false

    -- Restore Lighting
    if OriginalProperties._lighting then
        Lighting.GlobalShadows = OriginalProperties._lighting.GlobalShadows
        Lighting.FogEnd = OriginalProperties._lighting.FogEnd
    end

    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)

    -- Restore parts
    for obj, props in pairs(OriginalProperties._parts or {}) do
        if obj and obj.Parent then
            pcall(function()
                obj.Material = props.Material
                obj.Reflectance = props.Reflectance
                obj.CastShadow = props.CastShadow
            end)
        end
    end

    -- Restore effects
    for obj, props in pairs(OriginalProperties._effects or {}) do
        if obj and obj.Parent then
            pcall(function()
                for k, v in pairs(props) do obj[k] = v end
            end)
        end
    end

    OriginalProperties = {}
end

-- ================================================================
--  REGISTER UI (ALL ENGLISH)
-- ================================================================
function PremiumScript:RegisterUI(Lib, Win, keyResult)
    self._lib = Lib
    self._win = Win

    local Tab = Win:CreateTab({ Name = "RIVALS", Icon = "🎯" })

    -- ====== COMBAT ======
    local A = Tab:CreateSection("🔥 Combat & Aimbot")
    A:AddToggle({Name = "Enable Aimbot (Right Click)", Default = false, Flag = "AimEnabled", Callback = function(v) Config.AimbotEnabled = v end})
    A:AddDropdown({Name = "Aim Method", Options = {"Mouse", "Camera CFrame"}, Default = "Mouse", Flag = "AimMethod", Callback = function(v) Config.AimMethod = v end})
    A:AddDropdown({Name = "Target Part", Options = {"Head", "HumanoidRootPart", "UpperTorso"}, Default = "Head", Flag = "TargetPart", Callback = function(v) Config.TargetPart = v end})
    A:AddToggle({Name = "Wall Check", Default = true, Flag = "WallCheck", Callback = function(v) Config.WallCheck = v end})
    A:AddToggle({Name = "Team Check", Default = true, Flag = "TeamCheck", Callback = function(v) Config.TeamCheck = v end})
    A:AddSlider({Name = "Smoothness", Min = 10, Max = 100, Default = 100, Increment = 5, Suffix = "%", Flag = "Smooth", Callback = function(v) Config.Smoothness = v / 100 end})
    A:AddToggle({Name = "Prediction Mode", Default = false, Flag = "PredEnabled", Callback = function(v) Config.Prediction = v end})
    A:AddSlider({Name = "Prediction Strength", Min = 1, Max = 50, Default = 15, Increment = 1, Suffix = "", Flag = "PredFactor", Callback = function(v) Config.PredFactor = v / 100 end})

    -- ====== FOV ======
    local F = Tab:CreateSection("⭕ Field of View")
    F:AddToggle({Name = "Show FOV Circle", Default = true, Flag = "ShowFOV", Callback = function(v) Config.FOVEnabled = v end})
    F:AddSlider({Name = "FOV Radius", Min = 20, Max = 800, Default = 120, Increment = 10, Suffix = "px", Flag = "FOVRadius", Callback = function(v) Config.FOVRadius = v end})

    -- ====== VISUALS ======
    local E = Tab:CreateSection("✨ Visuals & ESP")
    E:AddToggle({Name = "Enable ESP", Default = false, Flag = "ESPEnabled", Callback = function(v) Config.ESPEnabled = v; if not v then for p in pairs(PremiumScript._espObjects) do ClearESP(p) end end end})
    E:AddToggle({Name = "Arena Only (Armed Players)", Default = false, Flag = "ArenaOnly", Callback = function(v) Config.ESPArenaOnly = v end})
    E:AddSlider({Name = "Max Render Distance", Min = 100, Max = 5000, Default = 1000, Increment = 100, Suffix = "m", Flag = "MaxDist", Callback = function(v) Config.ESPMaxDist = v end})
    E:AddToggle({Name = "Corner Box", Default = true, Flag = "CornerBox", Callback = function(v) Config.ESPCornerBox = v end})
    E:AddToggle({Name = "Full Box", Default = true, Flag = "ESPBox", Callback = function(v) Config.ESPBox = v end})
    E:AddToggle({Name = "Skeleton", Default = false, Flag = "Skeleton", Callback = function(v) Config.ESPSkeleton = v end})
    E:AddToggle({Name = "Tracer Lines", Default = false, Flag = "Tracer", Callback = function(v) Config.ESPTracer = v end})
    E:AddToggle({Name = "Highlight (Chams)", Default = false, Flag = "Highlight", Callback = function(v) Config.ESPHighlight = v end})
    E:AddToggle({Name = "Off-Screen Arrows", Default = false, Flag = "OffScreen", Callback = function(v) Config.ESPOffScreen = v end})
    E:AddToggle({Name = "Show Name", Default = true, Flag = "Name", Callback = function(v) Config.ESPName = v end})
    E:AddToggle({Name = "Show Distance", Default = true, Flag = "Dist", Callback = function(v) Config.ESPDist = v end})
    E:AddToggle({Name = "Health Bar", Default = true, Flag = "Health", Callback = function(v) Config.ESPHealth = v end})
    E:AddToggle({Name = "HP Number", Default = true, Flag = "HPText", Callback = function(v) Config.ESPHPText = v end})
    E:AddToggle({Name = "Weapon Info", Default = true, Flag = "Weapon", Callback = function(v) Config.ESPWeapon = v end})
    E:AddColorPicker({Name = "Hidden Color (Behind Walls)", Default = Color3.fromRGB(255, 60, 60), Flag = "ESPColor", Callback = function(c) Config.ESPColor = c end})
    E:AddColorPicker({Name = "Visible Color", Default = Color3.fromRGB(60, 255, 60), Flag = "VisClr", Callback = function(c) Config.ESPVisibleClr = c end})

    -- ====== PERFORMANCE ======
    local O = Tab:CreateSection("⚡ System Optimization")
    O:AddToggle({Name = "FPS Boost Mode", Default = false, Flag = "FPSBoost", Callback = function(v)
        if v then
            BoostFPS()
            Lib:Notify({Title = "Performance Boosted", Content = "Graphics lowered. Game will run significantly smoother.", Type = "Success"})
        else
            RestoreFPS()
            Lib:Notify({Title = "Graphics Restored", Content = "Original graphics settings have been restored.", Type = "Info"})
        end
    end})

    ESPHandler()
    AimbotHandler()
end

function PremiumScript:Destroy()
    Config.AimbotEnabled = false
    Config.ESPEnabled = false

    -- Kill guarded connections
    if self._espLoopConn then pcall(function() self._espLoopConn:Disconnect() end) end
    if self._aimbotLoopConn then pcall(function() self._aimbotLoopConn:Disconnect() end) end
    if self._charAddedConn then pcall(function() self._charAddedConn:Disconnect() end) end

    -- Clean ESP objects
    for p in pairs(self._espObjects) do ClearESP(p) end

    -- Kill all tracked connections
    for _, conn in ipairs(self._connections) do pcall(function() conn:Disconnect() end) end
    self._connections = {}

    -- Restore FPS if boosted
    RestoreFPS()

    -- Destroy GUI
    if MainGui then pcall(function() MainGui:Destroy() end) end

    -- Clear caches
    VisibilityCache = {}
    SmoothedVelocities = {}
    OriginalProperties = {}
end

return PremiumScript
