
--[[
    BorcaHub • Free / mm2.lua
    Murder Mystery 2 - Free tier
--]]

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local MM2Free = {
    _connections = {},
}

local function Track(conn)
    table.insert(MM2Free._connections, conn)
    return conn
end

-- ================================================================
--  FEATURE: ROLE DETECTOR
-- ================================================================

local function GetMyRole()
    local char = LocalPlayer.Character
    if not char then return "Unknown" end
    -- MM2 simpan role di leaderstats atau PlayerGui
    local playerGui = LocalPlayer.PlayerGui
    local roleGui   = playerGui:FindFirstChild("RoleGui")
        or playerGui:FindFirstChild("InGame")
    if roleGui then
        local roleLbl = roleGui:FindFirstChild("Role", true)
        if roleLbl and roleLbl:IsA("TextLabel") then
            return roleLbl.Text
        end
    end
    return "Unknown"
end

-- ================================================================
--  FEATURE: MURDERER ESP
-- ================================================================

local _murdererESP = false
local _highlights  = {}
local _espLoop

local function SetMurdererESP(enabled)
    _murdererESP = enabled
    if _espLoop then _espLoop:Disconnect() _espLoop = nil end

    if not enabled then
        for _, hl in pairs(_highlights) do
            if hl and hl.Parent then hl:Destroy() end
        end
        _highlights = {}
        return
    end

    _espLoop = Track(RunService.Heartbeat:Connect(function()
        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            local char = player.Character
            if not char then continue end

            -- Cek apakah murderer (cari tool berdaun)
            local isMurderer = false
            for _, tool in ipairs(char:GetChildren()) do
                if tool:IsA("Tool") then
                    local name = tool.Name:lower()
                    if name:find("knife") or name:find("murderer") or name:find("blade") then
                        isMurderer = true
                        break
                    end
                end
            end

            local hl = _highlights[player]
            if isMurderer then
                if not hl or not hl.Parent then
                    hl = Instance.new("Highlight", char)
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    _highlights[player] = hl
                end
                hl.OutlineColor     = Color3.fromRGB(255, 50, 50)
                hl.FillColor        = Color3.fromRGB(255, 50, 50)
                hl.FillTransparency = 0.75
            else
                if hl and hl.Parent then
                    hl:Destroy()
                    _highlights[player] = nil
                end
            end
        end

        -- Prune
        for player, hl in pairs(_highlights) do
            if not player.Parent then
                if hl and hl.Parent then hl:Destroy() end
                _highlights[player] = nil
            end
        end
    end))
end

-- ================================================================
--  FEATURE: SHERIFF ESP
-- ================================================================

local _sheriffESP  = false
local _sHighlights = {}
local _sLoop

local function SetSheriffESP(enabled)
    _sheriffESP = enabled
    if _sLoop then _sLoop:Disconnect() _sLoop = nil end

    if not enabled then
        for _, hl in pairs(_sHighlights) do
            if hl and hl.Parent then hl:Destroy() end
        end
        _sHighlights = {}
        return
    end

    _sLoop = Track(RunService.Heartbeat:Connect(function()
        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            local char = player.Character
            if not char then continue end

            local isSheriff = false
            for _, tool in ipairs(char:GetChildren()) do
                if tool:IsA("Tool") then
                    local name = tool.Name:lower()
                    if name:find("gun") or name:find("sheriff") or name:find("pistol") then
                        isSheriff = true
                        break
                    end
                end
            end

            local hl = _sHighlights[player]
            if isSheriff then
                if not hl or not hl.Parent then
                    hl = Instance.new("Highlight", char)
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    _sHighlights[player] = hl
                end
                hl.OutlineColor     = Color3.fromRGB(50, 150, 255)
                hl.FillColor        = Color3.fromRGB(50, 150, 255)
                hl.FillTransparency = 0.75
            else
                if hl and hl.Parent then
                    hl:Destroy()
                    _sHighlights[player] = nil
                end
            end
        end

        for player, hl in pairs(_sHighlights) do
            if not player.Parent then
                if hl and hl.Parent then hl:Destroy() end
                _sHighlights[player] = nil
            end
        end
    end))
end

-- ================================================================
--  REGISTER UI
-- ================================================================

function MM2Free:RegisterUI(Lib, Win)
    local Tab    = Win:CreateTab({ Name = "MM2", Icon = "🔪" })
    local ESPSec = Tab:CreateSection("Player ESP")

    ESPSec:AddToggle({
        Name        = "Murderer ESP",
        Description = "Highlight player yang bawa pisau",
        Default     = false,
        Flag        = "MM2MurdererESP",
        Callback    = function(v) SetMurdererESP(v) end,
    })

    ESPSec:AddToggle({
        Name        = "Sheriff ESP",
        Description = "Highlight player yang bawa gun",
        Default     = false,
        Flag        = "MM2SheriffESP",
        Callback    = function(v) SetSheriffESP(v) end,
    })

    local InfoSec = Tab:CreateSection("Info")

    InfoSec:AddButton({
        Name     = "Check My Role",
        Callback = function()
            local role = GetMyRole()
            Lib:Notify({
                Title   = "MM2 Role",
                Content = "Role kamu: " .. role,
                Type    = "Info",
            })
        end,
    })
end

function MM2Free:Destroy()
    SetMurdererESP(false)
    SetSheriffESP(false)
    for _, conn in ipairs(self._connections) do
        pcall(function() conn:Disconnect() end)
    end
    self._connections = {}
end

return MM2Free
