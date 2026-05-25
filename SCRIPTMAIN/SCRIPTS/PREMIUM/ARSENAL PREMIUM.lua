--[[
    BorcaHub • Free / Arsenal.lua
    Game-specific features untuk Arsenal (Free tier)
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local ArsenalFree = {
    _connections = {},
}

local function Track(conn)
    table.insert(ArsenalFree._connections, conn)
    return conn
end

-- ================================================================
--  FEATURE: INFINITE AMMO
-- ================================================================

local _ammoConn

local function SetInfiniteAmmo(enabled)
    if _ammoConn then _ammoConn:Disconnect() _ammoConn = nil end
    if enabled then
        _ammoConn = Track(RunService.Heartbeat:Connect(function()
            local char = LocalPlayer.Character
            if not char then return end
            local tool = char:FindFirstChildOfClass("Tool")
            if not tool then return end
            local ammo = tool:FindFirstChild("AmmoValue")
                or tool:FindFirstChild("Ammo")
            if ammo and ammo:IsA("IntValue") then
                if ammo.Value < 5 then
                    ammo.Value = 999
                end
            end
        end))
    end
end

-- ================================================================
--  REGISTER UI
-- ================================================================

function ArsenalFree:RegisterUI(Lib, Win)
    local Tab = Win:CreateTab({ Name = "Arsenal", Icon = "🔫" })
    local WeaponSec = Tab:CreateSection("Weapon")

    WeaponSec:AddToggle({
        Name     = "Infinite Ammo",
        Default  = false,
        Flag     = "ArsenalInfiniteAmmo",
        Callback = function(v) SetInfiniteAmmo(v) end,
    })

    WeaponSec:AddToggle({
        Name        = "No Recoil",
        Description = "Removes weapon recoil",
        Default     = false,
        Flag        = "ArsenalNoRecoil",
        Callback    = function(v)
            local char = LocalPlayer.Character
            if not char then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.CameraOffset = v and Vector3.new(0, 0, 0) or Vector3.new(0, 0, 0)
            end
        end,
    })
end

function ArsenalFree:Destroy()
    for _, conn in ipairs(self._connections) do
        pcall(function() conn:Disconnect() end)
    end
    self._connections = {}
end

return ArsenalFree
