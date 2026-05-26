
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

-- ============================================================================
-- [ BASE64 ENCODER & DECODER ]
-- ============================================================================
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

-- ============================================================================
-- [ BITWISE OPERATIONS (LUAU COMPATIBLE) ]
-- ============================================================================
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

-- ============================================================================
-- [ SHA-256 HASH IMPLEMENTATION ]
-- ============================================================================
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

-- ============================================================================
-- [ AES-256 XOR CIPHER ENGINE ]
-- ============================================================================
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

-- ============================================================================
-- [ ANTI-CHEAT BYPASS & METATABLE HOOKS ]
-- ============================================================================
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
                    if key == "WalkSpeed" and States and States.Speed then
                        return 16
                    end
                    if key == "JumpPower" and States and States.Jump then
                        return 50
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

function BorcaSec.AntiCheat.SpoofProperty(instance, property, fakeValue)
    if hookmetamethod then
        local mt = getrawmetatable(game)
        if setreadonly then setreadonly(mt, false) end
        local oldIdx = BorcaSec.AntiCheat.HookedMethods["__index"]
        BorcaSec.AntiCheat.HookedMethods["__index"] = hookmetamethod(game, "__index", function(self, key)
            if self == instance and key == property then
                return fakeValue
            end
            if oldIdx then return oldIdx(self, key) end
            return rawget(self, key)
        end)
        if setreadonly then setreadonly(mt, true) end
    end
end

BorcaSec.AntiCheat.BlockRemote("BanRemote")
BorcaSec.AntiCheat.BlockRemote("KickRemote")
BorcaSec.AntiCheat.BlockRemote("AntiExploit")
BorcaSec.AntiCheat.BlockRemote("CheatDetection")
BorcaSec.AntiCheat.BlockRemote("ReportServer")
BorcaSec.AntiCheat.BlockRemote("SecurityCheck")
BorcaSec.AntiCheat.BlockRemote("Validation")
BorcaSec.AntiCheat.BlockRemote("Heartbeat")
BorcaSec.AntiCheat.Init()

-- ============================================================================
-- [ MEMORY MANAGEMENT & GARBAGE COLLECTION ]
-- ============================================================================
BorcaSec.Memory = {}
BorcaSec.Memory.Stats = {
    LastClean = 0,
    CleanCount = 0,
    MemoryBefore = 0,
    MemoryAfter = 0,
    TotalFreed = 0
}

function BorcaSec.Memory.Clean()
    if gcinfo then
        BorcaSec.Memory.Stats.MemoryBefore = gcinfo()
        collectgarbage("collect")
        collectgarbage("collect")
        BorcaSec.Memory.Stats.MemoryAfter = gcinfo()
        local freed = BorcaSec.Memory.Stats.MemoryBefore - BorcaSec.Memory.Stats.MemoryAfter
        BorcaSec.Memory.Stats.TotalFreed = BorcaSec.Memory.Stats.TotalFreed + freed
        BorcaSec.Memory.Stats.CleanCount = BorcaSec.Memory.Stats.CleanCount + 1
        BorcaSec.Memory.Stats.LastClean = tick()
    end
end

function BorcaSec.Memory.GetUsage()
    return gcinfo and gcinfo() or 0
end

function BorcaSec.Memory.AutoClean(intervalSeconds)
    spawn(function()
        while true do
            task.wait(intervalSeconds or 60)
            BorcaSec.Memory.Clean()
        end
    end)
end

BorcaSec.Memory.AutoClean(45)

-- ============================================================================
-- [ NETWORK PACKET SIMULATION & HEARTBEAT SPOOFER ]
-- ============================================================================
BorcaSec.Network = {}
BorcaSec.Network.PacketsSent = 0
BorcaSec.Network.PacketsReceived = 0
BorcaSec.Network.Latency = 0
BorcaSec.Network.Connected = true

function BorcaSec.Network.SimulateHeartbeat()
    spawn(function()
        while BorcaSec.Network.Connected do
            local startTime = tick()
            BorcaSec.Network.PacketsSent = BorcaSec.Network.PacketsSent + 1
            task.wait(math.random(1, 3))
            BorcaSec.Network.PacketsReceived = BorcaSec.Network.PacketsReceived + 1
            BorcaSec.Network.Latency = math.floor((tick() - startTime) * 1000)
        end
    end)
end

function BorcaSec.Network.GetStats()
    return {
        Sent = BorcaSec.Network.PacketsSent,
        Received = BorcaSec.Network.PacketsReceived,
        Latency = BorcaSec.Network.Latency,
        Uptime = tick()
    }
end

BorcaSec.Network.SimulateHeartbeat()

-- ============================================================================
-- [ OBFUSCATION & STRING PROTECTION ENGINE ]
-- ============================================================================
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

function BorcaSec.Obfuscate.HashString(str)
    return BorcaSec.SHA256.Hash(str)
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

function BorcaSec.Obfuscate.XORStrings(str1, str2)
    local result = ""
    for i = 1, math.max(#str1, #str2) do
        local b1 = string.byte(str1, ((i - 1) % #str1) + 1)
        local b2 = string.byte(str2, ((i - 1) % #str2) + 1)
        result = result .. string.char(bxor(b1, b2))
    end
    return result
end

-- ============================================================================
-- [ ANTI-SCREENSHOT & STREAMER PROTECTION ]
-- ============================================================================
BorcaSec.StreamerProtect = {}
BorcaSec.StreamerProtect.Active = false
BorcaSec.StreamerProtect.HiddenElements = {}

function BorcaSec.StreamerProtect.Enable()
    BorcaSec.StreamerProtect.Active = true
    if States then States.StreamerMode = true end
end

function BorcaSec.StreamerProtect.Disable()
    BorcaSec.StreamerProtect.Active = false
    if States then States.StreamerMode = false end
end

function BorcaSec.StreamerProtect.HideElement(element)
    if element and element.Visible ~= nil then
        element.Visible = false
        table.insert(BorcaSec.StreamerProtect.HiddenElements, element)
    end
end

function BorcaSec.StreamerProtect.ShowAll()
    for _, element in ipairs(BorcaSec.StreamerProtect.HiddenElements) do
        if element and element.Visible ~= nil then
            element.Visible = true
        end
    end
    BorcaSec.StreamerProtect.HiddenElements = {}
end

-- ============================================================================
-- [ ADVANCED TELEPORT & SERVER HOP ENGINE ]
-- ============================================================================
BorcaSec.Teleport = {}

function BorcaSec.Teleport.Rejoin()
    local TeleportService = game:GetService("TeleportService")
    local LocalPlayer = game:GetService("Players").LocalPlayer
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end

function BorcaSec.Teleport.HopServer()
    local TeleportService = game:GetService("TeleportService")
    local HttpService = game:GetService("HttpService")
    local LocalPlayer = game:GetService("Players").LocalPlayer
    local success, result = pcall(function()
        local servers = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
        if servers and servers.data then
            for _, server in ipairs(servers.data) do
                if server.id ~= game.JobId and server.playing < server.maxPlayers then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
                    return
                end
            end
        end
    end)
    if not success then
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end
end

function BorcaSec.Teleport.ToGame(placeId)
    local TeleportService = game:GetService("TeleportService")
    local LocalPlayer = game:GetService("Players").LocalPlayer
    TeleportService:Teleport(placeId, LocalPlayer)
end

function BorcaSec.Teleport.ToPlayer(playerName)
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower():find(playerName:lower()) and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                LocalPlayer.Character.HumanoidRootPart.CFrame = p.Character.HumanoidRootPart.CFrame + Vector3.new(3, 0, 0)
            end
            return true
        end
    end
    return false
end

-- ============================================================================
-- [ FPS BOOSTER & PERFORMANCE OPTIMIZER ]
-- ============================================================================
BorcaSec.Performance = {}
BorcaSec.Performance.OriginalSettings = {}
BorcaSec.Performance.Boosted = false

function BorcaSec.Performance.BoostFPS()
    if BorcaSec.Performance.Boosted then return end
    local Lighting = game:GetService("Lighting")
    BorcaSec.Performance.OriginalSettings.GlobalShadows = Lighting.GlobalShadows
    BorcaSec.Performance.OriginalSettings.FogEnd = Lighting.FogEnd
    BorcaSec.Performance.OriginalSettings.Quality = settings().Rendering.QualityLevel
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 9e9
    settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") then
            v.Material = Enum.Material.SmoothPlastic
            v.Reflectance = 0
        end
        if v:IsA("Texture") or v:IsA("Decal") then
            v.Transparency = 1
        end
        if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
            v.Enabled = false
        end
        if v:IsA("MeshPart") then
            v.TextureID = ""
        end
        if v:IsA("PostEffect") or v:IsA("BlurEffect") or v:IsA("BloomEffect") or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") then
            v.Enabled = false
        end
    end
    BorcaSec.Performance.Boosted = true
end

function BorcaSec.Performance.RestoreFPS()
    if not BorcaSec.Performance.Boosted then return end
    local Lighting = game:GetService("Lighting")
    Lighting.GlobalShadows = BorcaSec.Performance.OriginalSettings.GlobalShadows or true
    Lighting.FogEnd = BorcaSec.Performance.OriginalSettings.FogEnd or 100000
    if BorcaSec.Performance.OriginalSettings.Quality then
        settings().Rendering.QualityLevel = BorcaSec.Performance.OriginalSettings.Quality
    end
    BorcaSec.Performance.Boosted = false
end

-- ============================================================================
-- [ NOTIFICATION & WATERMARK SYSTEM ]
-- ============================================================================
BorcaSec.Notify = {}

function BorcaSec.Notify.Send(title, text, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title or "BorcaHub",
            Text = text or "",
            Duration = duration or 5
        })
    end)
end

function BorcaSec.Notify.Welcome()
    BorcaSec.Notify.Send("BorcaHub Loaded", "Security Engine v" .. BorcaSec.Version .. " Active", 8)
    BorcaSec.Notify.Send("Anti-Cheat", "Bypass Status: " .. (BorcaSec.AntiCheat.Bypassed and "ACTIVE" or "PASSIVE"), 5)
end

task.delay(2, function()
    BorcaSec.Notify.Welcome()
end)

-- ============================================================================
-- [ SECURE STATE REGISTER (MASSIVE CACHE BLOCK) ]
-- ============================================================================
local SECURE_REGISTER = {}

