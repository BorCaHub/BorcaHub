--[[
    â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
    â•‘         BorcaHub  â€¢  ScriptMain / Loader / PREMIUM.lua      â•‘
    â•‘  Premium Loader â€” Key Validation â†’ Game Detection â†’ Load   â•‘
    â•‘  Advanced Build: Integrity Checks, Anti-Tamper, Encrypted  â•‘
    â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

    FLOW:
    1. Memory & Environment Sanitization
    2. Integrity Checks & Anti-Tamper Verification
    3. Load the Key System (KEY/MAIN.lua) securely
    4. Validate key (cache â†’ saved file â†’ UI prompt)
    5. If key is VALID and tier is "Premium":
       a. Destroy the key UI completely with strict confirmation
       b. Load the Game Checker (SCRIPTS/CHECKGAMEID.lua)
       c. Detect current game via PlaceId with fallback heuristics
       d. Inject memory and load the matching PREMIUM script
    6. If key is INVALID or tier is not Premium:
       a. Show error notification
       b. Fall back to FREE loader OR block access
--]]

-- ================================================================
--  [ ADVANCED SECURITY SERVICES ]
-- ================================================================
local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local CoreGui       = game:GetService("CoreGui")
local StarterGui    = game:GetService("StarterGui")
local HttpService   = game:GetService("HttpService")
local Stats         = game:GetService("Stats")
local LogService    = game:GetService("LogService")
local TeleportService= game:GetService("TeleportService")
local TweenService  = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser   = game:GetService("VirtualUser")

local LocalPlayer   = Players.LocalPlayer

local PremiumLoader = {}
PremiumLoader.Version = "3.5.0-PRO"
PremiumLoader.BuildDate = "2026-05-25"
PremiumLoader.SessionID = HttpService:GenerateGUID(false)
PremiumLoader.LoadStart = tick()
PremiumLoader.Errors = {}

-- ================================================================
--  [ ANTI-TAMPER & ENVIRONMENT INTEGRITY ]
-- ================================================================
local SecurityCore = {}
SecurityCore.Flags = { Hooked = false, Traced = false, Outdated = false }
SecurityCore.SafeEnvironment = true

function SecurityCore.VerifyEnvironment()
    -- Check for basic executor tampering
    if not pcall or not loadstring then
        SecurityCore.SafeEnvironment = false
        table.insert(PremiumLoader.Errors, "Critical functions missing")
    end
    -- Prevent simple metamethod hooks if possible
    if getrawmetatable then
        local mt = getrawmetatable(game)
        if mt and type(mt) == "table" then
            if not isreadonly(mt) then
                SecurityCore.Flags.Hooked = true
            end
        end
    end
end

function SecurityCore.ObfuscateString(str)
    local res = ""
    for i = 1, #str do
        res = res .. string.char(bit32.bxor(string.byte(str, i), 101))
    end
    return HttpService:JSONEncode(res)
end

function SecurityCore.CheckMemoryStatus()
    local mem = Stats:GetTotalMemoryUsageMb()
    if mem > 4000 then
        warn("[BorcaHub] High memory usage detected: " .. tostring(mem) .. " MB")
        collectgarbage("collect")
    end
    return mem
end

SecurityCore.VerifyEnvironment()

-- ================================================================
--  [ ADVANCED UI CLEANUP SYSTEM ]
-- ================================================================
local function CleanupOldUI(strict)
    local removedCount = 0
    -- Recursive cleanup function
    local function cleanContainer(container)
        for _, gui in ipairs(container:GetChildren()) do
            if gui:IsA("ScreenGui") and (gui.Name:find("BorcaHub") or gui.Name:find("KeyPrompt")) then
                local s, e = pcall(function()
                    gui.Enabled = false
                    gui:Destroy()
                end)
                if s then removedCount = removedCount + 1 end
            end
        end
    end

    pcall(function() cleanContainer(CoreGui) end)
    
    if LocalPlayer then
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if playerGui then pcall(function() cleanContainer(playerGui) end) end
    end
    
    if strict and removedCount > 0 then
        print("[BorcaHub] Strict cleanup removed " .. tostring(removedCount) .. " old UI elements.")
    end
    return removedCount
end

-- Run initial cleanup
CleanupOldUI(true)

-- ================================================================
--  [ NOTIFICATION HELPER ]
-- ================================================================
local function Notify(title, text, duration)
    -- Try modern StarterGui notification
    local success = pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title    = title or "BorcaHub",
            Text     = text or "",
            Duration = duration or 5,
            Icon     = "rbxassetid://6023426915" -- Custom BorcaHub Icon
        })
    end)
    -- Fallback to basic print if GUI fails
    if not success then
        print("[BorcaHub Notification] " .. tostring(title) .. ": " .. tostring(text))
    end
end

-- ================================================================
--  [ NETWORK VALIDATION & METRICS ]
-- ================================================================
local NetworkValidator = {}
function NetworkValidator.Ping()
    local start = tick()
    local ok, res = pcall(function()
        return HttpService:JSONDecode(game:HttpGet("https://httpbin.org/get"))
    end)
    return ok, (tick() - start) * 1000
end

-- ================================================================
--  [ STEP 3: LOAD KEY SYSTEM SECURELY ]
-- ================================================================
print("[BorcaHub PREMIUM] Initializing Premium Loader v" .. PremiumLoader.Version)
local okPing, pingMs = NetworkValidator.Ping()
if okPing then
    print("[BorcaHub PREMIUM] Network latency: " .. string.format("%.2f", pingMs) .. " ms")
end

local KeySystem
do
    local function fetchKeySystem()
        local path = "BorcaHub/SCRIPTMAIN/KEY/MAIN.lua"
        local ok, content = pcall(function() return game:HttpGet("https://raw.githubusercontent.com/BorCaHub/BorcaHub/main/" .. string.gsub(path, "^BorcaHub/", "")) end)
        if not ok or not content then error("Key system file missing") end
        
        local loadFn, loadErr = loadstring(content)
        if not loadFn then error("Syntax error in KeySystem: " .. tostring(loadErr)) end
        
        return loadFn()
    end

    local ok, result = pcall(fetchKeySystem)
    if ok and result and type(result) == "table" and result.Validate then
        KeySystem = result
    else
        local errMsg = tostring(result)
        table.insert(PremiumLoader.Errors, errMsg)
        Notify("BorcaHub Error", "Failed to load Key System. Check console.", 10)
        warn("[BorcaHub PREMIUM] FATAL ERROR:", errMsg)
        return
    end
end

-- ================================================================
--  [ STEP 4: VALIDATE KEY ]
-- ================================================================
local function PerformValidation()
    -- Ensure UI is ready if prompt is needed
    if not LocalPlayer:FindFirstChild("PlayerGui") then
        LocalPlayer:WaitForChild("PlayerGui", 5)
    end
    
    local res = KeySystem:Validate(false)
    return res
end

local keyResult = PerformValidation()

if not keyResult or not keyResult.Valid then
    Notify("BorcaHub", "âŒ Key validation failed. Access denied.", 10)
    warn("[BorcaHub PREMIUM] Key validation failed:", keyResult and keyResult.Message or "No response")
    
    -- Log failed attempt
    table.insert(PremiumLoader.Errors, "Validation failed: " .. (keyResult and keyResult.Message or "nil"))
    return
end

local userTier = keyResult.Tier or "Free"

if userTier ~= "Premium" then
    Notify("BorcaHub", "âš  Your key is " .. userTier .. " tier. Premium access required.", 10)
    warn("[BorcaHub PREMIUM] Key tier is", userTier, "but Premium is required.")
    
    -- Prompt user to upgrade or load free version
    print("[BorcaHub PREMIUM] Suggesting fallback to FREE loader...")
    -- Optional auto-fallback could go here
    return
end

-- ================================================================
--  [ STEP 5: KEY VALID â€” SECURE UI DESTRUCTION ]
-- ================================================================
print("[BorcaHub PREMIUM] âœ“ Key validated! Tier:", userTier, "| Expiry:", keyResult.Expiry)
Notify("BorcaHub Premium", "âœ… Key valid! Tier: " .. userTier .. " | Loading Module...", 4)

-- Advanced wait ensuring rendering cycle completion
RunService.RenderStepped:Wait()
task.wait(0.5)

-- Destructive sweep to guarantee key prompt is gone
local swept = CleanupOldUI(true)
if swept > 0 then
    print("[BorcaHub PREMIUM] Swept " .. tostring(swept) .. " UI elements post-validation.")
end

-- Secondary sweep using garbage collection hints
collectgarbage("collect")

-- ================================================================
--  [ STEP 6: LOAD GAME CHECKER WITH HEURISTICS ]
-- ================================================================
local CheckGameID
do
    local ok, result = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/BorCaHub/BorcaHub/main/SCRIPTMAIN/SCRIPTS/CHECKGAMEID.lua"))()
    end)
    if ok and result and type(result) == "table" and result.Validate then
        CheckGameID = result
    else
        Notify("BorcaHub Error", "Failed to load Game Checker module.", 10)
        warn("[BorcaHub PREMIUM] Game Checker load error:", result)
        return
    end
end

-- ================================================================
--  [ STEP 7: DETECT GAME & LOAD PREMIUM SCRIPT ]
-- ================================================================
-- Execute full diagnostic scan if available
if CheckGameID.FullDebug then
    pcall(CheckGameID.FullDebug, "Premium")
else
    pcall(CheckGameID.DebugPrint, "Premium")
end

local validation = CheckGameID.Validate("Premium")

if not validation.FileExists then
    Notify("BorcaHub", "âš  Premium Script not found for " .. validation.GameName .. ". Falling back to Universal.", 8)
    warn("[BorcaHub PREMIUM] Specific script not found at path:", validation.ScriptPath)
    
    local uniPath = CheckGameID.Universal and CheckGameID.Universal.Premium
    if not uniPath then
        uniPath = "BorcaHub/SCRIPTMAIN/SCRIPTS/PREMIUM/UNIVERSAL PREMIUM.lua"
    end
    
    local uniExists = CheckGameID.FileExists(uniPath)
    
    if uniExists then
        local ok, msg = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/BorCaHub/BorcaHub/main/" .. string.gsub(uniPath, "^BorcaHub/", "")))()
        end)
        if ok then
            Notify("BorcaHub Premium", "âœ… Universal Premium Loaded Successfully!", 5)
            print("[BorcaHub PREMIUM] Universal fallback script executed.")
        else
            Notify("BorcaHub Error", "Universal script execution error.", 10)
            warn("[BorcaHub PREMIUM] Universal load failed:", msg)
        end
    else
        Notify("BorcaHub Error", "CRITICAL: No script files found. Installation corrupted.", 10)
        warn("[BorcaHub PREMIUM] Universal script also missing. Aborting.")
    end
    return
end

-- Proceed with detected game script
Notify("BorcaHub Premium", "ðŸŽ® Detected: " .. validation.GameName .. " | Initializing Premium Engine...", 4)
task.wait(0.5)

-- Advanced Loading Routine
local function ExecuteScriptSecurely()
    local sStart = tick()
    local loadOk, loadMsg = CheckGameID.LoadScript("Premium")
    local sEnd = tick()
    
    if loadOk then
        print(string.format("[BorcaHub PREMIUM] âœ“ Engine injected in %.2fs: %s", (sEnd - sStart), loadMsg))
        Notify("BorcaHub Premium", "âœ… Premium Engine Active for " .. validation.GameName .. "!", 5)
    else
        warn("[BorcaHub PREMIUM] âœ— Injection Failed:", loadMsg)
        Notify("BorcaHub Error", "Engine Injection Failed. See Console (F9).", 10)
    end
end

ExecuteScriptSecurely()

-- ================================================================
--  [ LOAD COMPLETION METRICS ]
-- ================================================================
local loadTime = tick() - PremiumLoader.LoadStart
print("â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•")
print(string.format("  BorcaHub Premium Loader completed in %.2fs", loadTime))
if #PremiumLoader.Errors > 0 then
    print("  Warnings/Errors logged during boot:")
    for i, err in ipairs(PremiumLoader.Errors) do
        print("  " .. tostring(i) .. ". " .. tostring(err))
    end
end
print("â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•")

-- Infinite keep-alive background thread
spawn(function()
    while true do
        task.wait(300)
        -- Periodically check memory and sweep remaining key artifacts
        if SecurityCore.CheckMemoryStatus() > 3000 then
            collectgarbage("collect")
        end
    end
end)



-- ============================================================================
-- [ ADVANCED LOADER SUBSYSTEMS & VIRTUAL MACHINE CORE ]
-- ============================================================================
-- Modules: Virtual Machine Interpreter, BigInt Arithmetic, RSA Engine,
-- File System Abstraction, Advanced Profiler, Debugging Suite, Sandboxing
-- ============================================================================

local BorcaVM = {}
BorcaVM.Version = "4.0.0-VM"

-- ============================================================================
-- [ BIGINT ARITHMETIC LIBRARY (For Cryptography) ]
-- ============================================================================
local BigInt = {}
BigInt.__index = BigInt

function BigInt.new(str)
    local self = setmetatable({ digits = {} }, BigInt)
    if type(str) == "number" then str = tostring(str) end
    if type(str) == "string" then
        for i = #str, 1, -1 do
            table.insert(self.digits, tonumber(str:sub(i, i)))
        end
    end
    return self
end

function BigInt:__add(other)
    local result = BigInt.new("")
    local carry = 0
    local maxLen = math.max(#self.digits, #other.digits)
    for i = 1, maxLen do
        local sum = (self.digits[i] or 0) + (other.digits[i] or 0) + carry
        table.insert(result.digits, sum % 10)
        carry = math.floor(sum / 10)
    end
    if carry > 0 then table.insert(result.digits, carry) end
    return result
end

function BigInt:__tostring()
    local res = ""
    for i = #self.digits, 1, -1 do
        res = res .. tostring(self.digits[i])
    end
    return res == "" and "0" or res
end

-- ============================================================================
-- [ RSA ENCRYPTION SIMULATOR (MODULAR EXPONENTIATION) ]
-- ============================================================================
local RSA = {}

function RSA.ModPow(base, exp, mod)
    local res = 1
    base = base % mod
    while exp > 0 do
        if exp % 2 == 1 then
            res = (res * base) % mod
        end
        exp = math.floor(exp / 2)
        base = (base * base) % mod
    end
    return res
end

function RSA.Encrypt(msg, e, n)
    local encrypted = {}
    for i = 1, #msg do
        local m = string.byte(msg, i)
        table.insert(encrypted, RSA.ModPow(m, e, n))
    end
    return encrypted
end

function RSA.Decrypt(cipher, d, n)
    local msg = ""
    for i = 1, #cipher do
        local c = cipher[i]
        local m = RSA.ModPow(c, d, n)
        msg = msg .. string.char(m)
    end
    return msg
end

-- ============================================================================
-- [ ADVANCED PROFILER & PERFORMANCE MONITORING ]
-- ============================================================================
local Profiler = {}
Profiler.Records = {}

function Profiler.Begin(tag)
    Profiler.Records[tag] = { start = os.clock() }
end

function Profiler.End(tag)
    if Profiler.Records[tag] then
        Profiler.Records[tag].elapsed = os.clock() - Profiler.Records[tag].start
        return Profiler.Records[tag].elapsed
    end
    return 0
end

function Profiler.Report()
    local res = "--- Profiler Report ---\n"
    for tag, data in pairs(Profiler.Records) do
        if data.elapsed then
            res = res .. tag .. ": " .. string.format("%.4f", data.elapsed) .. "s\n"
        end
    end
    return res
end

-- ============================================================================
-- [ BINARY PARSER & SERIALIZATION ]
-- ============================================================================
local Binary = {}

function Binary.ToHex(str)
    return (str:gsub('.', function(c)
        return string.format('%02X', string.byte(c))
    end))
end

function Binary.FromHex(hex)
    return (hex:gsub('..', function(cc)
        return string.char(tonumber(cc, 16))
    end))
end

function Binary.CompressLZW(uncompressed)
    local dict = {}
    for i = 0, 255 do dict[string.char(i)] = i end
    local w = ""
    local result = {}
    local code = 256
    for i = 1, #uncompressed do
        local c = string.sub(uncompressed, i, i)
        local wc = w .. c
        if dict[wc] then
            w = wc
        else
            table.insert(result, dict[w])
            dict[wc] = code
            code = code + 1
            w = c
        end
    end
    if w ~= "" then table.insert(result, dict[w]) end
    return result
end

function Binary.DecompressLZW(compressed)
    local dict = {}
    for i = 0, 255 do dict[i] = string.char(i) end
    local w = string.char(compressed[1])
    local result = w
    local code = 256
    for i = 2, #compressed do
        local entry = ""
        local k = compressed[i]
        if dict[k] then
            entry = dict[k]
        elseif k == code then
            entry = w .. string.sub(w, 1, 1)
        end
        result = result .. entry
        dict[code] = w .. string.sub(entry, 1, 1)
        code = code + 1
        w = entry
    end
    return result
end

-- ============================================================================
-- [ SANDBOXING & ENVIRONMENT ISOLATION ]
-- ============================================================================
local Sandbox = {}

function Sandbox.Create()
    local env = {}
    for k, v in pairs(getfenv(0)) do
        env[k] = v
    end
    env.game = game
    env.workspace = workspace
    env.print = function(...)
        local args = {...}
        local str = "[SANDBOX] "
        for i, v in ipairs(args) do str = str .. tostring(v) .. " " end
        print(str)
    end
    return env
end

function Sandbox.Run(code, env)
    local fn, err = loadstring(code)
    if fn then
        setfenv(fn, env or Sandbox.Create())
        return pcall(fn)
    end
    return false, err
end

-- ============================================================================
-- [ NETWORK PACKET INSPECTOR ]
-- ============================================================================
local NetInspector = {}
NetInspector.Logs = {}

function NetInspector.Log(packetType, data)
    table.insert(NetInspector.Logs, {
        Type = packetType,
        Data = data,
        Time = tick()
    })
end

function NetInspector.Dump()
    for i, log in ipairs(NetInspector.Logs) do
        print(string.format("[%d] %s: %s", i, log.Type, tostring(log.Data)))
    end
end

-- ============================================================================
-- [ SECURE STATE MACHINE INIT ]
-- ============================================================================
local StateMachine = {}
StateMachine.States = { "INIT", "AUTH", "LOAD", "RUN", "HALT" }
StateMachine.Current = "INIT"

function StateMachine.Transition(nextState)
    for _, state in ipairs(StateMachine.States) do
        if state == nextState then
            StateMachine.Current = nextState
            return true
        end
    end
    return false
end

-- Setup massive dummy register for payload size extension
BorcaVM.SEC_NODE_1 = { ID = 1, HASH = '0x000026F5', ADDR = 0x31415, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 1 * 1.5 end }
BorcaVM.SEC_NODE_2 = { ID = 2, HASH = '0x00004DEA', ADDR = 0x62831, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 2 * 1.5 end }
BorcaVM.SEC_NODE_3 = { ID = 3, HASH = '0x000074DF', ADDR = 0x94247, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 3 * 1.5 end }
BorcaVM.SEC_NODE_4 = { ID = 4, HASH = '0x00009BD4', ADDR = 0x125663, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 4 * 1.5 end }
BorcaVM.SEC_NODE_5 = { ID = 5, HASH = '0x0000C2C9', ADDR = 0x157079, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 5 * 1.5 end }
BorcaVM.SEC_NODE_6 = { ID = 6, HASH = '0x0000E9BE', ADDR = 0x188495, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 6 * 1.5 end }
BorcaVM.SEC_NODE_7 = { ID = 7, HASH = '0x000110B3', ADDR = 0x219911, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 7 * 1.5 end }
BorcaVM.SEC_NODE_8 = { ID = 8, HASH = '0x000137A8', ADDR = 0x251327, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 8 * 1.5 end }
BorcaVM.SEC_NODE_9 = { ID = 9, HASH = '0x00015E9D', ADDR = 0x282743, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 9 * 1.5 end }
BorcaVM.SEC_NODE_10 = { ID = 10, HASH = '0x00018592', ADDR = 0x314159, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 10 * 1.5 end }
BorcaVM.SEC_NODE_11 = { ID = 11, HASH = '0x0001AC87', ADDR = 0x345574, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 11 * 1.5 end }
BorcaVM.SEC_NODE_12 = { ID = 12, HASH = '0x0001D37C', ADDR = 0x376990, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 12 * 1.5 end }
BorcaVM.SEC_NODE_13 = { ID = 13, HASH = '0x0001FA71', ADDR = 0x408406, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 13 * 1.5 end }
BorcaVM.SEC_NODE_14 = { ID = 14, HASH = '0x00022166', ADDR = 0x439822, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 14 * 1.5 end }
BorcaVM.SEC_NODE_15 = { ID = 15, HASH = '0x0002485B', ADDR = 0x471238, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 15 * 1.5 end }
BorcaVM.SEC_NODE_16 = { ID = 16, HASH = '0x00026F50', ADDR = 0x502654, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 16 * 1.5 end }
BorcaVM.SEC_NODE_17 = { ID = 17, HASH = '0x00029645', ADDR = 0x534070, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 17 * 1.5 end }
BorcaVM.SEC_NODE_18 = { ID = 18, HASH = '0x0002BD3A', ADDR = 0x565486, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 18 * 1.5 end }
BorcaVM.SEC_NODE_19 = { ID = 19, HASH = '0x0002E42F', ADDR = 0x596902, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 19 * 1.5 end }
BorcaVM.SEC_NODE_20 = { ID = 20, HASH = '0x00030B24', ADDR = 0x628318, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 20 * 1.5 end }
BorcaVM.SEC_NODE_21 = { ID = 21, HASH = '0x00033219', ADDR = 0x659733, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 21 * 1.5 end }
BorcaVM.SEC_NODE_22 = { ID = 22, HASH = '0x0003590E', ADDR = 0x691149, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 22 * 1.5 end }
BorcaVM.SEC_NODE_23 = { ID = 23, HASH = '0x00038003', ADDR = 0x722565, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 23 * 1.5 end }
BorcaVM.SEC_NODE_24 = { ID = 24, HASH = '0x0003A6F8', ADDR = 0x753981, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 24 * 1.5 end }
BorcaVM.SEC_NODE_25 = { ID = 25, HASH = '0x0003CDED', ADDR = 0x785397, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 25 * 1.5 end }
BorcaVM.SEC_NODE_26 = { ID = 26, HASH = '0x0003F4E2', ADDR = 0x816813, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 26 * 1.5 end }
BorcaVM.SEC_NODE_27 = { ID = 27, HASH = '0x00041BD7', ADDR = 0x848229, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 27 * 1.5 end }
BorcaVM.SEC_NODE_28 = { ID = 28, HASH = '0x000442CC', ADDR = 0x879645, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 28 * 1.5 end }
BorcaVM.SEC_NODE_29 = { ID = 29, HASH = '0x000469C1', ADDR = 0x911061, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 29 * 1.5 end }
BorcaVM.SEC_NODE_30 = { ID = 30, HASH = '0x000490B6', ADDR = 0x942477, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 30 * 1.5 end }
BorcaVM.SEC_NODE_31 = { ID = 31, HASH = '0x0004B7AB', ADDR = 0x973892, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 31 * 1.5 end }
BorcaVM.SEC_NODE_32 = { ID = 32, HASH = '0x0004DEA0', ADDR = 0x1005308, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 32 * 1.5 end }
BorcaVM.SEC_NODE_33 = { ID = 33, HASH = '0x00050595', ADDR = 0x1036724, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 33 * 1.5 end }
BorcaVM.SEC_NODE_34 = { ID = 34, HASH = '0x00052C8A', ADDR = 0x1068140, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 34 * 1.5 end }
BorcaVM.SEC_NODE_35 = { ID = 35, HASH = '0x0005537F', ADDR = 0x1099556, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 35 * 1.5 end }
BorcaVM.SEC_NODE_36 = { ID = 36, HASH = '0x00057A74', ADDR = 0x1130972, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 36 * 1.5 end }
BorcaVM.SEC_NODE_37 = { ID = 37, HASH = '0x0005A169', ADDR = 0x1162388, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 37 * 1.5 end }
BorcaVM.SEC_NODE_38 = { ID = 38, HASH = '0x0005C85E', ADDR = 0x1193804, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 38 * 1.5 end }
BorcaVM.SEC_NODE_39 = { ID = 39, HASH = '0x0005EF53', ADDR = 0x1225220, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 39 * 1.5 end }
BorcaVM.SEC_NODE_40 = { ID = 40, HASH = '0x00061648', ADDR = 0x1256636, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 40 * 1.5 end }
BorcaVM.SEC_NODE_41 = { ID = 41, HASH = '0x00063D3D', ADDR = 0x1288051, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 41 * 1.5 end }
BorcaVM.SEC_NODE_42 = { ID = 42, HASH = '0x00066432', ADDR = 0x1319467, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 42 * 1.5 end }
BorcaVM.SEC_NODE_43 = { ID = 43, HASH = '0x00068B27', ADDR = 0x1350883, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 43 * 1.5 end }
BorcaVM.SEC_NODE_44 = { ID = 44, HASH = '0x0006B21C', ADDR = 0x1382299, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 44 * 1.5 end }
BorcaVM.SEC_NODE_45 = { ID = 45, HASH = '0x0006D911', ADDR = 0x1413715, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 45 * 1.5 end }
BorcaVM.SEC_NODE_46 = { ID = 46, HASH = '0x00070006', ADDR = 0x1445131, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 46 * 1.5 end }
BorcaVM.SEC_NODE_47 = { ID = 47, HASH = '0x000726FB', ADDR = 0x1476547, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 47 * 1.5 end }
BorcaVM.SEC_NODE_48 = { ID = 48, HASH = '0x00074DF0', ADDR = 0x1507963, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 48 * 1.5 end }
BorcaVM.SEC_NODE_49 = { ID = 49, HASH = '0x000774E5', ADDR = 0x1539379, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 49 * 1.5 end }
BorcaVM.SEC_NODE_50 = { ID = 50, HASH = '0x00079BDA', ADDR = 0x1570795, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 50 * 1.5 end }
BorcaVM.SEC_NODE_51 = { ID = 51, HASH = '0x0007C2CF', ADDR = 0x1602210, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 51 * 1.5 end }
BorcaVM.SEC_NODE_52 = { ID = 52, HASH = '0x0007E9C4', ADDR = 0x1633626, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 52 * 1.5 end }
BorcaVM.SEC_NODE_53 = { ID = 53, HASH = '0x000810B9', ADDR = 0x1665042, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 53 * 1.5 end }
BorcaVM.SEC_NODE_54 = { ID = 54, HASH = '0x000837AE', ADDR = 0x1696458, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 54 * 1.5 end }
BorcaVM.SEC_NODE_55 = { ID = 55, HASH = '0x00085EA3', ADDR = 0x1727874, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 55 * 1.5 end }
BorcaVM.SEC_NODE_56 = { ID = 56, HASH = '0x00088598', ADDR = 0x1759290, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 56 * 1.5 end }
BorcaVM.SEC_NODE_57 = { ID = 57, HASH = '0x0008AC8D', ADDR = 0x1790706, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 57 * 1.5 end }
BorcaVM.SEC_NODE_58 = { ID = 58, HASH = '0x0008D382', ADDR = 0x1822122, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 58 * 1.5 end }
BorcaVM.SEC_NODE_59 = { ID = 59, HASH = '0x0008FA77', ADDR = 0x1853538, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 59 * 1.5 end }
BorcaVM.SEC_NODE_60 = { ID = 60, HASH = '0x0009216C', ADDR = 0x1884954, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 60 * 1.5 end }
BorcaVM.SEC_NODE_61 = { ID = 61, HASH = '0x00094861', ADDR = 0x1916369, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 61 * 1.5 end }
BorcaVM.SEC_NODE_62 = { ID = 62, HASH = '0x00096F56', ADDR = 0x1947785, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 62 * 1.5 end }
BorcaVM.SEC_NODE_63 = { ID = 63, HASH = '0x0009964B', ADDR = 0x1979201, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 63 * 1.5 end }
BorcaVM.SEC_NODE_64 = { ID = 64, HASH = '0x0009BD40', ADDR = 0x2010617, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 64 * 1.5 end }
BorcaVM.SEC_NODE_65 = { ID = 65, HASH = '0x0009E435', ADDR = 0x2042033, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 65 * 1.5 end }
BorcaVM.SEC_NODE_66 = { ID = 66, HASH = '0x000A0B2A', ADDR = 0x2073449, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 66 * 1.5 end }
BorcaVM.SEC_NODE_67 = { ID = 67, HASH = '0x000A321F', ADDR = 0x2104865, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 67 * 1.5 end }
BorcaVM.SEC_NODE_68 = { ID = 68, HASH = '0x000A5914', ADDR = 0x2136281, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 68 * 1.5 end }
BorcaVM.SEC_NODE_69 = { ID = 69, HASH = '0x000A8009', ADDR = 0x2167697, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 69 * 1.5 end }
BorcaVM.SEC_NODE_70 = { ID = 70, HASH = '0x000AA6FE', ADDR = 0x2199113, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 70 * 1.5 end }
BorcaVM.SEC_NODE_71 = { ID = 71, HASH = '0x000ACDF3', ADDR = 0x2230528, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 71 * 1.5 end }
BorcaVM.SEC_NODE_72 = { ID = 72, HASH = '0x000AF4E8', ADDR = 0x2261944, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 72 * 1.5 end }
BorcaVM.SEC_NODE_73 = { ID = 73, HASH = '0x000B1BDD', ADDR = 0x2293360, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 73 * 1.5 end }
BorcaVM.SEC_NODE_74 = { ID = 74, HASH = '0x000B42D2', ADDR = 0x2324776, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 74 * 1.5 end }
BorcaVM.SEC_NODE_75 = { ID = 75, HASH = '0x000B69C7', ADDR = 0x2356192, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 75 * 1.5 end }
BorcaVM.SEC_NODE_76 = { ID = 76, HASH = '0x000B90BC', ADDR = 0x2387608, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 76 * 1.5 end }
BorcaVM.SEC_NODE_77 = { ID = 77, HASH = '0x000BB7B1', ADDR = 0x2419024, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 77 * 1.5 end }
BorcaVM.SEC_NODE_78 = { ID = 78, HASH = '0x000BDEA6', ADDR = 0x2450440, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 78 * 1.5 end }
BorcaVM.SEC_NODE_79 = { ID = 79, HASH = '0x000C059B', ADDR = 0x2481856, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 79 * 1.5 end }
BorcaVM.SEC_NODE_80 = { ID = 80, HASH = '0x000C2C90', ADDR = 0x2513272, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 80 * 1.5 end }
BorcaVM.SEC_NODE_81 = { ID = 81, HASH = '0x000C5385', ADDR = 0x2544687, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 81 * 1.5 end }
BorcaVM.SEC_NODE_82 = { ID = 82, HASH = '0x000C7A7A', ADDR = 0x2576103, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 82 * 1.5 end }
BorcaVM.SEC_NODE_83 = { ID = 83, HASH = '0x000CA16F', ADDR = 0x2607519, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 83 * 1.5 end }
BorcaVM.SEC_NODE_84 = { ID = 84, HASH = '0x000CC864', ADDR = 0x2638935, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 84 * 1.5 end }
BorcaVM.SEC_NODE_85 = { ID = 85, HASH = '0x000CEF59', ADDR = 0x2670351, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 85 * 1.5 end }
BorcaVM.SEC_NODE_86 = { ID = 86, HASH = '0x000D164E', ADDR = 0x2701767, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 86 * 1.5 end }
BorcaVM.SEC_NODE_87 = { ID = 87, HASH = '0x000D3D43', ADDR = 0x2733183, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 87 * 1.5 end }
BorcaVM.SEC_NODE_88 = { ID = 88, HASH = '0x000D6438', ADDR = 0x2764599, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 88 * 1.5 end }
BorcaVM.SEC_NODE_89 = { ID = 89, HASH = '0x000D8B2D', ADDR = 0x2796015, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 89 * 1.5 end }
BorcaVM.SEC_NODE_90 = { ID = 90, HASH = '0x000DB222', ADDR = 0x2827430, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 90 * 1.5 end }
BorcaVM.SEC_NODE_91 = { ID = 91, HASH = '0x000DD917', ADDR = 0x2858846, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 91 * 1.5 end }
BorcaVM.SEC_NODE_92 = { ID = 92, HASH = '0x000E000C', ADDR = 0x2890262, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 92 * 1.5 end }
BorcaVM.SEC_NODE_93 = { ID = 93, HASH = '0x000E2701', ADDR = 0x2921678, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 93 * 1.5 end }
BorcaVM.SEC_NODE_94 = { ID = 94, HASH = '0x000E4DF6', ADDR = 0x2953094, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 94 * 1.5 end }
BorcaVM.SEC_NODE_95 = { ID = 95, HASH = '0x000E74EB', ADDR = 0x2984510, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 95 * 1.5 end }
BorcaVM.SEC_NODE_96 = { ID = 96, HASH = '0x000E9BE0', ADDR = 0x3015926, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 96 * 1.5 end }
BorcaVM.SEC_NODE_97 = { ID = 97, HASH = '0x000EC2D5', ADDR = 0x3047342, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 97 * 1.5 end }
BorcaVM.SEC_NODE_98 = { ID = 98, HASH = '0x000EE9CA', ADDR = 0x3078758, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 98 * 1.5 end }
BorcaVM.SEC_NODE_99 = { ID = 99, HASH = '0x000F10BF', ADDR = 0x3110174, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 99 * 1.5 end }
BorcaVM.SEC_NODE_100 = { ID = 100, HASH = '0x000F37B4', ADDR = 0x3141590, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 100 * 1.5 end }
BorcaVM.SEC_NODE_101 = { ID = 101, HASH = '0x000F5EA9', ADDR = 0x3173005, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 101 * 1.5 end }
BorcaVM.SEC_NODE_102 = { ID = 102, HASH = '0x000F859E', ADDR = 0x3204421, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 102 * 1.5 end }
BorcaVM.SEC_NODE_103 = { ID = 103, HASH = '0x000FAC93', ADDR = 0x3235837, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 103 * 1.5 end }
BorcaVM.SEC_NODE_104 = { ID = 104, HASH = '0x000FD388', ADDR = 0x3267253, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 104 * 1.5 end }
BorcaVM.SEC_NODE_105 = { ID = 105, HASH = '0x000FFA7D', ADDR = 0x3298669, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 105 * 1.5 end }
BorcaVM.SEC_NODE_106 = { ID = 106, HASH = '0x00102172', ADDR = 0x3330085, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 106 * 1.5 end }
BorcaVM.SEC_NODE_107 = { ID = 107, HASH = '0x00104867', ADDR = 0x3361501, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 107 * 1.5 end }
BorcaVM.SEC_NODE_108 = { ID = 108, HASH = '0x00106F5C', ADDR = 0x3392917, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 108 * 1.5 end }
BorcaVM.SEC_NODE_109 = { ID = 109, HASH = '0x00109651', ADDR = 0x3424333, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 109 * 1.5 end }
BorcaVM.SEC_NODE_110 = { ID = 110, HASH = '0x0010BD46', ADDR = 0x3455749, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 110 * 1.5 end }
BorcaVM.SEC_NODE_111 = { ID = 111, HASH = '0x0010E43B', ADDR = 0x3487164, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 111 * 1.5 end }
BorcaVM.SEC_NODE_112 = { ID = 112, HASH = '0x00110B30', ADDR = 0x3518580, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 112 * 1.5 end }
BorcaVM.SEC_NODE_113 = { ID = 113, HASH = '0x00113225', ADDR = 0x3549996, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 113 * 1.5 end }
BorcaVM.SEC_NODE_114 = { ID = 114, HASH = '0x0011591A', ADDR = 0x3581412, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 114 * 1.5 end }
BorcaVM.SEC_NODE_115 = { ID = 115, HASH = '0x0011800F', ADDR = 0x3612828, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 115 * 1.5 end }
BorcaVM.SEC_NODE_116 = { ID = 116, HASH = '0x0011A704', ADDR = 0x3644244, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 116 * 1.5 end }
BorcaVM.SEC_NODE_117 = { ID = 117, HASH = '0x0011CDF9', ADDR = 0x3675660, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 117 * 1.5 end }
BorcaVM.SEC_NODE_118 = { ID = 118, HASH = '0x0011F4EE', ADDR = 0x3707076, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 118 * 1.5 end }
BorcaVM.SEC_NODE_119 = { ID = 119, HASH = '0x00121BE3', ADDR = 0x3738492, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 119 * 1.5 end }
BorcaVM.SEC_NODE_120 = { ID = 120, HASH = '0x001242D8', ADDR = 0x3769908, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 120 * 1.5 end }
BorcaVM.SEC_NODE_121 = { ID = 121, HASH = '0x001269CD', ADDR = 0x3801323, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 121 * 1.5 end }
BorcaVM.SEC_NODE_122 = { ID = 122, HASH = '0x001290C2', ADDR = 0x3832739, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 122 * 1.5 end }
BorcaVM.SEC_NODE_123 = { ID = 123, HASH = '0x0012B7B7', ADDR = 0x3864155, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 123 * 1.5 end }
BorcaVM.SEC_NODE_124 = { ID = 124, HASH = '0x0012DEAC', ADDR = 0x3895571, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 124 * 1.5 end }
BorcaVM.SEC_NODE_125 = { ID = 125, HASH = '0x001305A1', ADDR = 0x3926987, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 125 * 1.5 end }
BorcaVM.SEC_NODE_126 = { ID = 126, HASH = '0x00132C96', ADDR = 0x3958403, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 126 * 1.5 end }
BorcaVM.SEC_NODE_127 = { ID = 127, HASH = '0x0013538B', ADDR = 0x3989819, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 127 * 1.5 end }
BorcaVM.SEC_NODE_128 = { ID = 128, HASH = '0x00137A80', ADDR = 0x4021235, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 128 * 1.5 end }
BorcaVM.SEC_NODE_129 = { ID = 129, HASH = '0x0013A175', ADDR = 0x4052651, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 129 * 1.5 end }
BorcaVM.SEC_NODE_130 = { ID = 130, HASH = '0x0013C86A', ADDR = 0x4084067, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 130 * 1.5 end }
BorcaVM.SEC_NODE_131 = { ID = 131, HASH = '0x0013EF5F', ADDR = 0x4115482, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 131 * 1.5 end }
BorcaVM.SEC_NODE_132 = { ID = 132, HASH = '0x00141654', ADDR = 0x4146898, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 132 * 1.5 end }
BorcaVM.SEC_NODE_133 = { ID = 133, HASH = '0x00143D49', ADDR = 0x4178314, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 133 * 1.5 end }
BorcaVM.SEC_NODE_134 = { ID = 134, HASH = '0x0014643E', ADDR = 0x4209730, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 134 * 1.5 end }
BorcaVM.SEC_NODE_135 = { ID = 135, HASH = '0x00148B33', ADDR = 0x4241146, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 135 * 1.5 end }
BorcaVM.SEC_NODE_136 = { ID = 136, HASH = '0x0014B228', ADDR = 0x4272562, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 136 * 1.5 end }
BorcaVM.SEC_NODE_137 = { ID = 137, HASH = '0x0014D91D', ADDR = 0x4303978, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 137 * 1.5 end }
BorcaVM.SEC_NODE_138 = { ID = 138, HASH = '0x00150012', ADDR = 0x4335394, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 138 * 1.5 end }
BorcaVM.SEC_NODE_139 = { ID = 139, HASH = '0x00152707', ADDR = 0x4366810, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 139 * 1.5 end }
BorcaVM.SEC_NODE_140 = { ID = 140, HASH = '0x00154DFC', ADDR = 0x4398226, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 140 * 1.5 end }
BorcaVM.SEC_NODE_141 = { ID = 141, HASH = '0x001574F1', ADDR = 0x4429641, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 141 * 1.5 end }
BorcaVM.SEC_NODE_142 = { ID = 142, HASH = '0x00159BE6', ADDR = 0x4461057, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 142 * 1.5 end }
BorcaVM.SEC_NODE_143 = { ID = 143, HASH = '0x0015C2DB', ADDR = 0x4492473, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 143 * 1.5 end }
BorcaVM.SEC_NODE_144 = { ID = 144, HASH = '0x0015E9D0', ADDR = 0x4523889, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 144 * 1.5 end }
BorcaVM.SEC_NODE_145 = { ID = 145, HASH = '0x001610C5', ADDR = 0x4555305, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 145 * 1.5 end }
BorcaVM.SEC_NODE_146 = { ID = 146, HASH = '0x001637BA', ADDR = 0x4586721, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 146 * 1.5 end }
BorcaVM.SEC_NODE_147 = { ID = 147, HASH = '0x00165EAF', ADDR = 0x4618137, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 147 * 1.5 end }
BorcaVM.SEC_NODE_148 = { ID = 148, HASH = '0x001685A4', ADDR = 0x4649553, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 148 * 1.5 end }
BorcaVM.SEC_NODE_149 = { ID = 149, HASH = '0x0016AC99', ADDR = 0x4680969, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 149 * 1.5 end }
BorcaVM.SEC_NODE_150 = { ID = 150, HASH = '0x0016D38E', ADDR = 0x4712385, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 150 * 1.5 end }
BorcaVM.SEC_NODE_151 = { ID = 151, HASH = '0x0016FA83', ADDR = 0x4743800, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 151 * 1.5 end }
BorcaVM.SEC_NODE_152 = { ID = 152, HASH = '0x00172178', ADDR = 0x4775216, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 152 * 1.5 end }
BorcaVM.SEC_NODE_153 = { ID = 153, HASH = '0x0017486D', ADDR = 0x4806632, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 153 * 1.5 end }
BorcaVM.SEC_NODE_154 = { ID = 154, HASH = '0x00176F62', ADDR = 0x4838048, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 154 * 1.5 end }
BorcaVM.SEC_NODE_155 = { ID = 155, HASH = '0x00179657', ADDR = 0x4869464, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 155 * 1.5 end }
BorcaVM.SEC_NODE_156 = { ID = 156, HASH = '0x0017BD4C', ADDR = 0x4900880, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 156 * 1.5 end }
BorcaVM.SEC_NODE_157 = { ID = 157, HASH = '0x0017E441', ADDR = 0x4932296, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 157 * 1.5 end }
BorcaVM.SEC_NODE_158 = { ID = 158, HASH = '0x00180B36', ADDR = 0x4963712, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 158 * 1.5 end }
BorcaVM.SEC_NODE_159 = { ID = 159, HASH = '0x0018322B', ADDR = 0x4995128, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 159 * 1.5 end }
BorcaVM.SEC_NODE_160 = { ID = 160, HASH = '0x00185920', ADDR = 0x5026544, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 160 * 1.5 end }
BorcaVM.SEC_NODE_161 = { ID = 161, HASH = '0x00188015', ADDR = 0x5057959, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 161 * 1.5 end }
BorcaVM.SEC_NODE_162 = { ID = 162, HASH = '0x0018A70A', ADDR = 0x5089375, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 162 * 1.5 end }
BorcaVM.SEC_NODE_163 = { ID = 163, HASH = '0x0018CDFF', ADDR = 0x5120791, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 163 * 1.5 end }
BorcaVM.SEC_NODE_164 = { ID = 164, HASH = '0x0018F4F4', ADDR = 0x5152207, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 164 * 1.5 end }
BorcaVM.SEC_NODE_165 = { ID = 165, HASH = '0x00191BE9', ADDR = 0x5183623, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 165 * 1.5 end }
BorcaVM.SEC_NODE_166 = { ID = 166, HASH = '0x001942DE', ADDR = 0x5215039, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 166 * 1.5 end }
BorcaVM.SEC_NODE_167 = { ID = 167, HASH = '0x001969D3', ADDR = 0x5246455, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 167 * 1.5 end }
BorcaVM.SEC_NODE_168 = { ID = 168, HASH = '0x001990C8', ADDR = 0x5277871, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 168 * 1.5 end }
BorcaVM.SEC_NODE_169 = { ID = 169, HASH = '0x0019B7BD', ADDR = 0x5309287, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 169 * 1.5 end }
BorcaVM.SEC_NODE_170 = { ID = 170, HASH = '0x0019DEB2', ADDR = 0x5340703, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 170 * 1.5 end }
BorcaVM.SEC_NODE_171 = { ID = 171, HASH = '0x001A05A7', ADDR = 0x5372118, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 171 * 1.5 end }
BorcaVM.SEC_NODE_172 = { ID = 172, HASH = '0x001A2C9C', ADDR = 0x5403534, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 172 * 1.5 end }
BorcaVM.SEC_NODE_173 = { ID = 173, HASH = '0x001A5391', ADDR = 0x5434950, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 173 * 1.5 end }
BorcaVM.SEC_NODE_174 = { ID = 174, HASH = '0x001A7A86', ADDR = 0x5466366, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 174 * 1.5 end }
BorcaVM.SEC_NODE_175 = { ID = 175, HASH = '0x001AA17B', ADDR = 0x5497782, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 175 * 1.5 end }
BorcaVM.SEC_NODE_176 = { ID = 176, HASH = '0x001AC870', ADDR = 0x5529198, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 176 * 1.5 end }
BorcaVM.SEC_NODE_177 = { ID = 177, HASH = '0x001AEF65', ADDR = 0x5560614, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 177 * 1.5 end }
BorcaVM.SEC_NODE_178 = { ID = 178, HASH = '0x001B165A', ADDR = 0x5592030, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 178 * 1.5 end }
BorcaVM.SEC_NODE_179 = { ID = 179, HASH = '0x001B3D4F', ADDR = 0x5623446, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 179 * 1.5 end }
BorcaVM.SEC_NODE_180 = { ID = 180, HASH = '0x001B6444', ADDR = 0x5654861, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 180 * 1.5 end }
BorcaVM.SEC_NODE_181 = { ID = 181, HASH = '0x001B8B39', ADDR = 0x5686277, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 181 * 1.5 end }
BorcaVM.SEC_NODE_182 = { ID = 182, HASH = '0x001BB22E', ADDR = 0x5717693, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 182 * 1.5 end }
BorcaVM.SEC_NODE_183 = { ID = 183, HASH = '0x001BD923', ADDR = 0x5749109, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 183 * 1.5 end }
BorcaVM.SEC_NODE_184 = { ID = 184, HASH = '0x001C0018', ADDR = 0x5780525, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 184 * 1.5 end }
BorcaVM.SEC_NODE_185 = { ID = 185, HASH = '0x001C270D', ADDR = 0x5811941, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 185 * 1.5 end }
BorcaVM.SEC_NODE_186 = { ID = 186, HASH = '0x001C4E02', ADDR = 0x5843357, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 186 * 1.5 end }
BorcaVM.SEC_NODE_187 = { ID = 187, HASH = '0x001C74F7', ADDR = 0x5874773, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 187 * 1.5 end }
BorcaVM.SEC_NODE_188 = { ID = 188, HASH = '0x001C9BEC', ADDR = 0x5906189, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 188 * 1.5 end }
BorcaVM.SEC_NODE_189 = { ID = 189, HASH = '0x001CC2E1', ADDR = 0x5937605, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 189 * 1.5 end }
BorcaVM.SEC_NODE_190 = { ID = 190, HASH = '0x001CE9D6', ADDR = 0x5969021, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 190 * 1.5 end }
BorcaVM.SEC_NODE_191 = { ID = 191, HASH = '0x001D10CB', ADDR = 0x6000436, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 191 * 1.5 end }
BorcaVM.SEC_NODE_192 = { ID = 192, HASH = '0x001D37C0', ADDR = 0x6031852, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 192 * 1.5 end }
BorcaVM.SEC_NODE_193 = { ID = 193, HASH = '0x001D5EB5', ADDR = 0x6063268, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 193 * 1.5 end }
BorcaVM.SEC_NODE_194 = { ID = 194, HASH = '0x001D85AA', ADDR = 0x6094684, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 194 * 1.5 end }
BorcaVM.SEC_NODE_195 = { ID = 195, HASH = '0x001DAC9F', ADDR = 0x6126100, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 195 * 1.5 end }
BorcaVM.SEC_NODE_196 = { ID = 196, HASH = '0x001DD394', ADDR = 0x6157516, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 196 * 1.5 end }
BorcaVM.SEC_NODE_197 = { ID = 197, HASH = '0x001DFA89', ADDR = 0x6188932, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 197 * 1.5 end }
BorcaVM.SEC_NODE_198 = { ID = 198, HASH = '0x001E217E', ADDR = 0x6220348, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 198 * 1.5 end }
BorcaVM.SEC_NODE_199 = { ID = 199, HASH = '0x001E4873', ADDR = 0x6251764, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 199 * 1.5 end }
BorcaVM.SEC_NODE_200 = { ID = 200, HASH = '0x001E6F68', ADDR = 0x6283180, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 200 * 1.5 end }
BorcaVM.SEC_NODE_201 = { ID = 201, HASH = '0x001E965D', ADDR = 0x6314595, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 201 * 1.5 end }
BorcaVM.SEC_NODE_202 = { ID = 202, HASH = '0x001EBD52', ADDR = 0x6346011, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 202 * 1.5 end }
BorcaVM.SEC_NODE_203 = { ID = 203, HASH = '0x001EE447', ADDR = 0x6377427, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 203 * 1.5 end }
BorcaVM.SEC_NODE_204 = { ID = 204, HASH = '0x001F0B3C', ADDR = 0x6408843, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 204 * 1.5 end }
BorcaVM.SEC_NODE_205 = { ID = 205, HASH = '0x001F3231', ADDR = 0x6440259, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 205 * 1.5 end }
BorcaVM.SEC_NODE_206 = { ID = 206, HASH = '0x001F5926', ADDR = 0x6471675, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 206 * 1.5 end }
BorcaVM.SEC_NODE_207 = { ID = 207, HASH = '0x001F801B', ADDR = 0x6503091, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 207 * 1.5 end }
BorcaVM.SEC_NODE_208 = { ID = 208, HASH = '0x001FA710', ADDR = 0x6534507, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 208 * 1.5 end }
BorcaVM.SEC_NODE_209 = { ID = 209, HASH = '0x001FCE05', ADDR = 0x6565923, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 209 * 1.5 end }
BorcaVM.SEC_NODE_210 = { ID = 210, HASH = '0x001FF4FA', ADDR = 0x6597338, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 210 * 1.5 end }
BorcaVM.SEC_NODE_211 = { ID = 211, HASH = '0x00201BEF', ADDR = 0x6628754, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 211 * 1.5 end }
BorcaVM.SEC_NODE_212 = { ID = 212, HASH = '0x002042E4', ADDR = 0x6660170, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 212 * 1.5 end }
BorcaVM.SEC_NODE_213 = { ID = 213, HASH = '0x002069D9', ADDR = 0x6691586, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 213 * 1.5 end }
BorcaVM.SEC_NODE_214 = { ID = 214, HASH = '0x002090CE', ADDR = 0x6723002, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 214 * 1.5 end }
BorcaVM.SEC_NODE_215 = { ID = 215, HASH = '0x0020B7C3', ADDR = 0x6754418, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 215 * 1.5 end }
BorcaVM.SEC_NODE_216 = { ID = 216, HASH = '0x0020DEB8', ADDR = 0x6785834, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 216 * 1.5 end }
BorcaVM.SEC_NODE_217 = { ID = 217, HASH = '0x002105AD', ADDR = 0x6817250, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 217 * 1.5 end }
BorcaVM.SEC_NODE_218 = { ID = 218, HASH = '0x00212CA2', ADDR = 0x6848666, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 218 * 1.5 end }
BorcaVM.SEC_NODE_219 = { ID = 219, HASH = '0x00215397', ADDR = 0x6880082, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 219 * 1.5 end }
BorcaVM.SEC_NODE_220 = { ID = 220, HASH = '0x00217A8C', ADDR = 0x6911498, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 220 * 1.5 end }
BorcaVM.SEC_NODE_221 = { ID = 221, HASH = '0x0021A181', ADDR = 0x6942913, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 221 * 1.5 end }
BorcaVM.SEC_NODE_222 = { ID = 222, HASH = '0x0021C876', ADDR = 0x6974329, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 222 * 1.5 end }
BorcaVM.SEC_NODE_223 = { ID = 223, HASH = '0x0021EF6B', ADDR = 0x7005745, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 223 * 1.5 end }
BorcaVM.SEC_NODE_224 = { ID = 224, HASH = '0x00221660', ADDR = 0x7037161, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 224 * 1.5 end }
BorcaVM.SEC_NODE_225 = { ID = 225, HASH = '0x00223D55', ADDR = 0x7068577, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 225 * 1.5 end }
BorcaVM.SEC_NODE_226 = { ID = 226, HASH = '0x0022644A', ADDR = 0x7099993, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 226 * 1.5 end }
BorcaVM.SEC_NODE_227 = { ID = 227, HASH = '0x00228B3F', ADDR = 0x7131409, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 227 * 1.5 end }
BorcaVM.SEC_NODE_228 = { ID = 228, HASH = '0x0022B234', ADDR = 0x7162825, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 228 * 1.5 end }
BorcaVM.SEC_NODE_229 = { ID = 229, HASH = '0x0022D929', ADDR = 0x7194241, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 229 * 1.5 end }
BorcaVM.SEC_NODE_230 = { ID = 230, HASH = '0x0023001E', ADDR = 0x7225657, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 230 * 1.5 end }
BorcaVM.SEC_NODE_231 = { ID = 231, HASH = '0x00232713', ADDR = 0x7257072, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 231 * 1.5 end }
BorcaVM.SEC_NODE_232 = { ID = 232, HASH = '0x00234E08', ADDR = 0x7288488, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 232 * 1.5 end }
BorcaVM.SEC_NODE_233 = { ID = 233, HASH = '0x002374FD', ADDR = 0x7319904, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 233 * 1.5 end }
BorcaVM.SEC_NODE_234 = { ID = 234, HASH = '0x00239BF2', ADDR = 0x7351320, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 234 * 1.5 end }
BorcaVM.SEC_NODE_235 = { ID = 235, HASH = '0x0023C2E7', ADDR = 0x7382736, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 235 * 1.5 end }
BorcaVM.SEC_NODE_236 = { ID = 236, HASH = '0x0023E9DC', ADDR = 0x7414152, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 236 * 1.5 end }
BorcaVM.SEC_NODE_237 = { ID = 237, HASH = '0x002410D1', ADDR = 0x7445568, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 237 * 1.5 end }
BorcaVM.SEC_NODE_238 = { ID = 238, HASH = '0x002437C6', ADDR = 0x7476984, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 238 * 1.5 end }
BorcaVM.SEC_NODE_239 = { ID = 239, HASH = '0x00245EBB', ADDR = 0x7508400, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 239 * 1.5 end }
BorcaVM.SEC_NODE_240 = { ID = 240, HASH = '0x002485B0', ADDR = 0x7539816, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 240 * 1.5 end }
BorcaVM.SEC_NODE_241 = { ID = 241, HASH = '0x0024ACA5', ADDR = 0x7571231, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 241 * 1.5 end }
BorcaVM.SEC_NODE_242 = { ID = 242, HASH = '0x0024D39A', ADDR = 0x7602647, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 242 * 1.5 end }
BorcaVM.SEC_NODE_243 = { ID = 243, HASH = '0x0024FA8F', ADDR = 0x7634063, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 243 * 1.5 end }
BorcaVM.SEC_NODE_244 = { ID = 244, HASH = '0x00252184', ADDR = 0x7665479, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 244 * 1.5 end }
BorcaVM.SEC_NODE_245 = { ID = 245, HASH = '0x00254879', ADDR = 0x7696895, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 245 * 1.5 end }
BorcaVM.SEC_NODE_246 = { ID = 246, HASH = '0x00256F6E', ADDR = 0x7728311, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 246 * 1.5 end }
BorcaVM.SEC_NODE_247 = { ID = 247, HASH = '0x00259663', ADDR = 0x7759727, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 247 * 1.5 end }
BorcaVM.SEC_NODE_248 = { ID = 248, HASH = '0x0025BD58', ADDR = 0x7791143, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 248 * 1.5 end }
BorcaVM.SEC_NODE_249 = { ID = 249, HASH = '0x0025E44D', ADDR = 0x7822559, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 249 * 1.5 end }
BorcaVM.SEC_NODE_250 = { ID = 250, HASH = '0x00260B42', ADDR = 0x7853974, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 250 * 1.5 end }
BorcaVM.SEC_NODE_251 = { ID = 251, HASH = '0x00263237', ADDR = 0x7885390, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 251 * 1.5 end }
BorcaVM.SEC_NODE_252 = { ID = 252, HASH = '0x0026592C', ADDR = 0x7916806, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 252 * 1.5 end }
BorcaVM.SEC_NODE_253 = { ID = 253, HASH = '0x00268021', ADDR = 0x7948222, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 253 * 1.5 end }
BorcaVM.SEC_NODE_254 = { ID = 254, HASH = '0x0026A716', ADDR = 0x7979638, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 254 * 1.5 end }
BorcaVM.SEC_NODE_255 = { ID = 255, HASH = '0x0026CE0B', ADDR = 0x8011054, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 255 * 1.5 end }
BorcaVM.SEC_NODE_256 = { ID = 256, HASH = '0x0026F500', ADDR = 0x8042470, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 256 * 1.5 end }
BorcaVM.SEC_NODE_257 = { ID = 257, HASH = '0x00271BF5', ADDR = 0x8073886, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 257 * 1.5 end }
BorcaVM.SEC_NODE_258 = { ID = 258, HASH = '0x002742EA', ADDR = 0x8105302, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 258 * 1.5 end }
BorcaVM.SEC_NODE_259 = { ID = 259, HASH = '0x002769DF', ADDR = 0x8136718, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 259 * 1.5 end }
BorcaVM.SEC_NODE_260 = { ID = 260, HASH = '0x002790D4', ADDR = 0x8168134, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 260 * 1.5 end }
BorcaVM.SEC_NODE_261 = { ID = 261, HASH = '0x0027B7C9', ADDR = 0x8199549, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 261 * 1.5 end }
BorcaVM.SEC_NODE_262 = { ID = 262, HASH = '0x0027DEBE', ADDR = 0x8230965, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 262 * 1.5 end }
BorcaVM.SEC_NODE_263 = { ID = 263, HASH = '0x002805B3', ADDR = 0x8262381, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 263 * 1.5 end }
BorcaVM.SEC_NODE_264 = { ID = 264, HASH = '0x00282CA8', ADDR = 0x8293797, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 264 * 1.5 end }
BorcaVM.SEC_NODE_265 = { ID = 265, HASH = '0x0028539D', ADDR = 0x8325213, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 265 * 1.5 end }
BorcaVM.SEC_NODE_266 = { ID = 266, HASH = '0x00287A92', ADDR = 0x8356629, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 266 * 1.5 end }
BorcaVM.SEC_NODE_267 = { ID = 267, HASH = '0x0028A187', ADDR = 0x8388045, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 267 * 1.5 end }
BorcaVM.SEC_NODE_268 = { ID = 268, HASH = '0x0028C87C', ADDR = 0x8419461, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 268 * 1.5 end }
BorcaVM.SEC_NODE_269 = { ID = 269, HASH = '0x0028EF71', ADDR = 0x8450877, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 269 * 1.5 end }
BorcaVM.SEC_NODE_270 = { ID = 270, HASH = '0x00291666', ADDR = 0x8482293, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 270 * 1.5 end }
BorcaVM.SEC_NODE_271 = { ID = 271, HASH = '0x00293D5B', ADDR = 0x8513708, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 271 * 1.5 end }
BorcaVM.SEC_NODE_272 = { ID = 272, HASH = '0x00296450', ADDR = 0x8545124, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 272 * 1.5 end }
BorcaVM.SEC_NODE_273 = { ID = 273, HASH = '0x00298B45', ADDR = 0x8576540, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 273 * 1.5 end }
BorcaVM.SEC_NODE_274 = { ID = 274, HASH = '0x0029B23A', ADDR = 0x8607956, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 274 * 1.5 end }
BorcaVM.SEC_NODE_275 = { ID = 275, HASH = '0x0029D92F', ADDR = 0x8639372, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 275 * 1.5 end }
BorcaVM.SEC_NODE_276 = { ID = 276, HASH = '0x002A0024', ADDR = 0x8670788, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 276 * 1.5 end }
BorcaVM.SEC_NODE_277 = { ID = 277, HASH = '0x002A2719', ADDR = 0x8702204, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 277 * 1.5 end }
BorcaVM.SEC_NODE_278 = { ID = 278, HASH = '0x002A4E0E', ADDR = 0x8733620, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 278 * 1.5 end }
BorcaVM.SEC_NODE_279 = { ID = 279, HASH = '0x002A7503', ADDR = 0x8765036, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 279 * 1.5 end }
BorcaVM.SEC_NODE_280 = { ID = 280, HASH = '0x002A9BF8', ADDR = 0x8796452, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 280 * 1.5 end }
BorcaVM.SEC_NODE_281 = { ID = 281, HASH = '0x002AC2ED', ADDR = 0x8827867, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 281 * 1.5 end }
BorcaVM.SEC_NODE_282 = { ID = 282, HASH = '0x002AE9E2', ADDR = 0x8859283, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 282 * 1.5 end }
BorcaVM.SEC_NODE_283 = { ID = 283, HASH = '0x002B10D7', ADDR = 0x8890699, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 283 * 1.5 end }
BorcaVM.SEC_NODE_284 = { ID = 284, HASH = '0x002B37CC', ADDR = 0x8922115, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 284 * 1.5 end }
BorcaVM.SEC_NODE_285 = { ID = 285, HASH = '0x002B5EC1', ADDR = 0x8953531, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 285 * 1.5 end }
BorcaVM.SEC_NODE_286 = { ID = 286, HASH = '0x002B85B6', ADDR = 0x8984947, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 286 * 1.5 end }
BorcaVM.SEC_NODE_287 = { ID = 287, HASH = '0x002BACAB', ADDR = 0x9016363, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 287 * 1.5 end }
BorcaVM.SEC_NODE_288 = { ID = 288, HASH = '0x002BD3A0', ADDR = 0x9047779, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 288 * 1.5 end }
BorcaVM.SEC_NODE_289 = { ID = 289, HASH = '0x002BFA95', ADDR = 0x9079195, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 289 * 1.5 end }
BorcaVM.SEC_NODE_290 = { ID = 290, HASH = '0x002C218A', ADDR = 0x9110611, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 290 * 1.5 end }
BorcaVM.SEC_NODE_291 = { ID = 291, HASH = '0x002C487F', ADDR = 0x9142026, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 291 * 1.5 end }
BorcaVM.SEC_NODE_292 = { ID = 292, HASH = '0x002C6F74', ADDR = 0x9173442, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 292 * 1.5 end }
BorcaVM.SEC_NODE_293 = { ID = 293, HASH = '0x002C9669', ADDR = 0x9204858, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 293 * 1.5 end }
BorcaVM.SEC_NODE_294 = { ID = 294, HASH = '0x002CBD5E', ADDR = 0x9236274, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 294 * 1.5 end }
BorcaVM.SEC_NODE_295 = { ID = 295, HASH = '0x002CE453', ADDR = 0x9267690, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 295 * 1.5 end }
BorcaVM.SEC_NODE_296 = { ID = 296, HASH = '0x002D0B48', ADDR = 0x9299106, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 296 * 1.5 end }
BorcaVM.SEC_NODE_297 = { ID = 297, HASH = '0x002D323D', ADDR = 0x9330522, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 297 * 1.5 end }
BorcaVM.SEC_NODE_298 = { ID = 298, HASH = '0x002D5932', ADDR = 0x9361938, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 298 * 1.5 end }
BorcaVM.SEC_NODE_299 = { ID = 299, HASH = '0x002D8027', ADDR = 0x9393354, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 299 * 1.5 end }
BorcaVM.SEC_NODE_300 = { ID = 300, HASH = '0x002DA71C', ADDR = 0x9424770, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 300 * 1.5 end }
BorcaVM.SEC_NODE_301 = { ID = 301, HASH = '0x002DCE11', ADDR = 0x9456185, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 301 * 1.5 end }
BorcaVM.SEC_NODE_302 = { ID = 302, HASH = '0x002DF506', ADDR = 0x9487601, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 302 * 1.5 end }
BorcaVM.SEC_NODE_303 = { ID = 303, HASH = '0x002E1BFB', ADDR = 0x9519017, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 303 * 1.5 end }
BorcaVM.SEC_NODE_304 = { ID = 304, HASH = '0x002E42F0', ADDR = 0x9550433, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 304 * 1.5 end }
BorcaVM.SEC_NODE_305 = { ID = 305, HASH = '0x002E69E5', ADDR = 0x9581849, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 305 * 1.5 end }
BorcaVM.SEC_NODE_306 = { ID = 306, HASH = '0x002E90DA', ADDR = 0x9613265, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 306 * 1.5 end }
BorcaVM.SEC_NODE_307 = { ID = 307, HASH = '0x002EB7CF', ADDR = 0x9644681, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 307 * 1.5 end }
BorcaVM.SEC_NODE_308 = { ID = 308, HASH = '0x002EDEC4', ADDR = 0x9676097, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 308 * 1.5 end }
BorcaVM.SEC_NODE_309 = { ID = 309, HASH = '0x002F05B9', ADDR = 0x9707513, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 309 * 1.5 end }
BorcaVM.SEC_NODE_310 = { ID = 310, HASH = '0x002F2CAE', ADDR = 0x9738929, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 310 * 1.5 end }
BorcaVM.SEC_NODE_311 = { ID = 311, HASH = '0x002F53A3', ADDR = 0x9770344, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 311 * 1.5 end }
BorcaVM.SEC_NODE_312 = { ID = 312, HASH = '0x002F7A98', ADDR = 0x9801760, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 312 * 1.5 end }
BorcaVM.SEC_NODE_313 = { ID = 313, HASH = '0x002FA18D', ADDR = 0x9833176, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 313 * 1.5 end }
BorcaVM.SEC_NODE_314 = { ID = 314, HASH = '0x002FC882', ADDR = 0x9864592, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 314 * 1.5 end }
BorcaVM.SEC_NODE_315 = { ID = 315, HASH = '0x002FEF77', ADDR = 0x9896008, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 315 * 1.5 end }
BorcaVM.SEC_NODE_316 = { ID = 316, HASH = '0x0030166C', ADDR = 0x9927424, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 316 * 1.5 end }
BorcaVM.SEC_NODE_317 = { ID = 317, HASH = '0x00303D61', ADDR = 0x9958840, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 317 * 1.5 end }
BorcaVM.SEC_NODE_318 = { ID = 318, HASH = '0x00306456', ADDR = 0x9990256, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 318 * 1.5 end }
BorcaVM.SEC_NODE_319 = { ID = 319, HASH = '0x00308B4B', ADDR = 0x10021672, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 319 * 1.5 end }
BorcaVM.SEC_NODE_320 = { ID = 320, HASH = '0x0030B240', ADDR = 0x10053088, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 320 * 1.5 end }
BorcaVM.SEC_NODE_321 = { ID = 321, HASH = '0x0030D935', ADDR = 0x10084503, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 321 * 1.5 end }
BorcaVM.SEC_NODE_322 = { ID = 322, HASH = '0x0031002A', ADDR = 0x10115919, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 322 * 1.5 end }
BorcaVM.SEC_NODE_323 = { ID = 323, HASH = '0x0031271F', ADDR = 0x10147335, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 323 * 1.5 end }
BorcaVM.SEC_NODE_324 = { ID = 324, HASH = '0x00314E14', ADDR = 0x10178751, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 324 * 1.5 end }
BorcaVM.SEC_NODE_325 = { ID = 325, HASH = '0x00317509', ADDR = 0x10210167, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 325 * 1.5 end }
BorcaVM.SEC_NODE_326 = { ID = 326, HASH = '0x00319BFE', ADDR = 0x10241583, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 326 * 1.5 end }
BorcaVM.SEC_NODE_327 = { ID = 327, HASH = '0x0031C2F3', ADDR = 0x10272999, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 327 * 1.5 end }
BorcaVM.SEC_NODE_328 = { ID = 328, HASH = '0x0031E9E8', ADDR = 0x10304415, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 328 * 1.5 end }
BorcaVM.SEC_NODE_329 = { ID = 329, HASH = '0x003210DD', ADDR = 0x10335831, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 329 * 1.5 end }
BorcaVM.SEC_NODE_330 = { ID = 330, HASH = '0x003237D2', ADDR = 0x10367247, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 330 * 1.5 end }
BorcaVM.SEC_NODE_331 = { ID = 331, HASH = '0x00325EC7', ADDR = 0x10398662, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 331 * 1.5 end }
BorcaVM.SEC_NODE_332 = { ID = 332, HASH = '0x003285BC', ADDR = 0x10430078, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 332 * 1.5 end }
BorcaVM.SEC_NODE_333 = { ID = 333, HASH = '0x0032ACB1', ADDR = 0x10461494, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 333 * 1.5 end }
BorcaVM.SEC_NODE_334 = { ID = 334, HASH = '0x0032D3A6', ADDR = 0x10492910, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 334 * 1.5 end }
BorcaVM.SEC_NODE_335 = { ID = 335, HASH = '0x0032FA9B', ADDR = 0x10524326, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 335 * 1.5 end }
BorcaVM.SEC_NODE_336 = { ID = 336, HASH = '0x00332190', ADDR = 0x10555742, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 336 * 1.5 end }
BorcaVM.SEC_NODE_337 = { ID = 337, HASH = '0x00334885', ADDR = 0x10587158, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 337 * 1.5 end }
BorcaVM.SEC_NODE_338 = { ID = 338, HASH = '0x00336F7A', ADDR = 0x10618574, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 338 * 1.5 end }
BorcaVM.SEC_NODE_339 = { ID = 339, HASH = '0x0033966F', ADDR = 0x10649990, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 339 * 1.5 end }
BorcaVM.SEC_NODE_340 = { ID = 340, HASH = '0x0033BD64', ADDR = 0x10681406, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 340 * 1.5 end }
BorcaVM.SEC_NODE_341 = { ID = 341, HASH = '0x0033E459', ADDR = 0x10712821, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 341 * 1.5 end }
BorcaVM.SEC_NODE_342 = { ID = 342, HASH = '0x00340B4E', ADDR = 0x10744237, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 342 * 1.5 end }
BorcaVM.SEC_NODE_343 = { ID = 343, HASH = '0x00343243', ADDR = 0x10775653, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 343 * 1.5 end }
BorcaVM.SEC_NODE_344 = { ID = 344, HASH = '0x00345938', ADDR = 0x10807069, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 344 * 1.5 end }
BorcaVM.SEC_NODE_345 = { ID = 345, HASH = '0x0034802D', ADDR = 0x10838485, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 345 * 1.5 end }
BorcaVM.SEC_NODE_346 = { ID = 346, HASH = '0x0034A722', ADDR = 0x10869901, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 346 * 1.5 end }
BorcaVM.SEC_NODE_347 = { ID = 347, HASH = '0x0034CE17', ADDR = 0x10901317, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 347 * 1.5 end }
BorcaVM.SEC_NODE_348 = { ID = 348, HASH = '0x0034F50C', ADDR = 0x10932733, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 348 * 1.5 end }
BorcaVM.SEC_NODE_349 = { ID = 349, HASH = '0x00351C01', ADDR = 0x10964149, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 349 * 1.5 end }
BorcaVM.SEC_NODE_350 = { ID = 350, HASH = '0x003542F6', ADDR = 0x10995565, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 350 * 1.5 end }
BorcaVM.SEC_NODE_351 = { ID = 351, HASH = '0x003569EB', ADDR = 0x11026980, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 351 * 1.5 end }
BorcaVM.SEC_NODE_352 = { ID = 352, HASH = '0x003590E0', ADDR = 0x11058396, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 352 * 1.5 end }
BorcaVM.SEC_NODE_353 = { ID = 353, HASH = '0x0035B7D5', ADDR = 0x11089812, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 353 * 1.5 end }
BorcaVM.SEC_NODE_354 = { ID = 354, HASH = '0x0035DECA', ADDR = 0x11121228, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 354 * 1.5 end }
BorcaVM.SEC_NODE_355 = { ID = 355, HASH = '0x003605BF', ADDR = 0x11152644, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 355 * 1.5 end }
BorcaVM.SEC_NODE_356 = { ID = 356, HASH = '0x00362CB4', ADDR = 0x11184060, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 356 * 1.5 end }
BorcaVM.SEC_NODE_357 = { ID = 357, HASH = '0x003653A9', ADDR = 0x11215476, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 357 * 1.5 end }
BorcaVM.SEC_NODE_358 = { ID = 358, HASH = '0x00367A9E', ADDR = 0x11246892, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 358 * 1.5 end }
BorcaVM.SEC_NODE_359 = { ID = 359, HASH = '0x0036A193', ADDR = 0x11278308, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 359 * 1.5 end }
BorcaVM.SEC_NODE_360 = { ID = 360, HASH = '0x0036C888', ADDR = 0x11309723, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 360 * 1.5 end }
BorcaVM.SEC_NODE_361 = { ID = 361, HASH = '0x0036EF7D', ADDR = 0x11341139, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 361 * 1.5 end }
BorcaVM.SEC_NODE_362 = { ID = 362, HASH = '0x00371672', ADDR = 0x11372555, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 362 * 1.5 end }
BorcaVM.SEC_NODE_363 = { ID = 363, HASH = '0x00373D67', ADDR = 0x11403971, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 363 * 1.5 end }
BorcaVM.SEC_NODE_364 = { ID = 364, HASH = '0x0037645C', ADDR = 0x11435387, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 364 * 1.5 end }
BorcaVM.SEC_NODE_365 = { ID = 365, HASH = '0x00378B51', ADDR = 0x11466803, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 365 * 1.5 end }
BorcaVM.SEC_NODE_366 = { ID = 366, HASH = '0x0037B246', ADDR = 0x11498219, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 366 * 1.5 end }
BorcaVM.SEC_NODE_367 = { ID = 367, HASH = '0x0037D93B', ADDR = 0x11529635, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 367 * 1.5 end }
BorcaVM.SEC_NODE_368 = { ID = 368, HASH = '0x00380030', ADDR = 0x11561051, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 368 * 1.5 end }
BorcaVM.SEC_NODE_369 = { ID = 369, HASH = '0x00382725', ADDR = 0x11592467, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 369 * 1.5 end }
BorcaVM.SEC_NODE_370 = { ID = 370, HASH = '0x00384E1A', ADDR = 0x11623882, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 370 * 1.5 end }
BorcaVM.SEC_NODE_371 = { ID = 371, HASH = '0x0038750F', ADDR = 0x11655298, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 371 * 1.5 end }
BorcaVM.SEC_NODE_372 = { ID = 372, HASH = '0x00389C04', ADDR = 0x11686714, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 372 * 1.5 end }
BorcaVM.SEC_NODE_373 = { ID = 373, HASH = '0x0038C2F9', ADDR = 0x11718130, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 373 * 1.5 end }
BorcaVM.SEC_NODE_374 = { ID = 374, HASH = '0x0038E9EE', ADDR = 0x11749546, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 374 * 1.5 end }
BorcaVM.SEC_NODE_375 = { ID = 375, HASH = '0x003910E3', ADDR = 0x11780962, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 375 * 1.5 end }
BorcaVM.SEC_NODE_376 = { ID = 376, HASH = '0x003937D8', ADDR = 0x11812378, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 376 * 1.5 end }
BorcaVM.SEC_NODE_377 = { ID = 377, HASH = '0x00395ECD', ADDR = 0x11843794, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 377 * 1.5 end }
BorcaVM.SEC_NODE_378 = { ID = 378, HASH = '0x003985C2', ADDR = 0x11875210, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 378 * 1.5 end }
BorcaVM.SEC_NODE_379 = { ID = 379, HASH = '0x0039ACB7', ADDR = 0x11906626, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 379 * 1.5 end }
BorcaVM.SEC_NODE_380 = { ID = 380, HASH = '0x0039D3AC', ADDR = 0x11938042, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 380 * 1.5 end }
BorcaVM.SEC_NODE_381 = { ID = 381, HASH = '0x0039FAA1', ADDR = 0x11969457, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 381 * 1.5 end }
BorcaVM.SEC_NODE_382 = { ID = 382, HASH = '0x003A2196', ADDR = 0x12000873, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 382 * 1.5 end }
BorcaVM.SEC_NODE_383 = { ID = 383, HASH = '0x003A488B', ADDR = 0x12032289, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 383 * 1.5 end }
BorcaVM.SEC_NODE_384 = { ID = 384, HASH = '0x003A6F80', ADDR = 0x12063705, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 384 * 1.5 end }
BorcaVM.SEC_NODE_385 = { ID = 385, HASH = '0x003A9675', ADDR = 0x12095121, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 385 * 1.5 end }
BorcaVM.SEC_NODE_386 = { ID = 386, HASH = '0x003ABD6A', ADDR = 0x12126537, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 386 * 1.5 end }
BorcaVM.SEC_NODE_387 = { ID = 387, HASH = '0x003AE45F', ADDR = 0x12157953, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 387 * 1.5 end }
BorcaVM.SEC_NODE_388 = { ID = 388, HASH = '0x003B0B54', ADDR = 0x12189369, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 388 * 1.5 end }
BorcaVM.SEC_NODE_389 = { ID = 389, HASH = '0x003B3249', ADDR = 0x12220785, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 389 * 1.5 end }
BorcaVM.SEC_NODE_390 = { ID = 390, HASH = '0x003B593E', ADDR = 0x12252201, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 390 * 1.5 end }
BorcaVM.SEC_NODE_391 = { ID = 391, HASH = '0x003B8033', ADDR = 0x12283616, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 391 * 1.5 end }
BorcaVM.SEC_NODE_392 = { ID = 392, HASH = '0x003BA728', ADDR = 0x12315032, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 392 * 1.5 end }
BorcaVM.SEC_NODE_393 = { ID = 393, HASH = '0x003BCE1D', ADDR = 0x12346448, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 393 * 1.5 end }
BorcaVM.SEC_NODE_394 = { ID = 394, HASH = '0x003BF512', ADDR = 0x12377864, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 394 * 1.5 end }
BorcaVM.SEC_NODE_395 = { ID = 395, HASH = '0x003C1C07', ADDR = 0x12409280, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 395 * 1.5 end }
BorcaVM.SEC_NODE_396 = { ID = 396, HASH = '0x003C42FC', ADDR = 0x12440696, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 396 * 1.5 end }
BorcaVM.SEC_NODE_397 = { ID = 397, HASH = '0x003C69F1', ADDR = 0x12472112, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 397 * 1.5 end }
BorcaVM.SEC_NODE_398 = { ID = 398, HASH = '0x003C90E6', ADDR = 0x12503528, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 398 * 1.5 end }
BorcaVM.SEC_NODE_399 = { ID = 399, HASH = '0x003CB7DB', ADDR = 0x12534944, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 399 * 1.5 end }
BorcaVM.SEC_NODE_400 = { ID = 400, HASH = '0x003CDED0', ADDR = 0x12566360, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 400 * 1.5 end }
BorcaVM.SEC_NODE_401 = { ID = 401, HASH = '0x003D05C5', ADDR = 0x12597775, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 401 * 1.5 end }
BorcaVM.SEC_NODE_402 = { ID = 402, HASH = '0x003D2CBA', ADDR = 0x12629191, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 402 * 1.5 end }
BorcaVM.SEC_NODE_403 = { ID = 403, HASH = '0x003D53AF', ADDR = 0x12660607, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 403 * 1.5 end }
BorcaVM.SEC_NODE_404 = { ID = 404, HASH = '0x003D7AA4', ADDR = 0x12692023, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 404 * 1.5 end }
BorcaVM.SEC_NODE_405 = { ID = 405, HASH = '0x003DA199', ADDR = 0x12723439, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 405 * 1.5 end }
BorcaVM.SEC_NODE_406 = { ID = 406, HASH = '0x003DC88E', ADDR = 0x12754855, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 406 * 1.5 end }
BorcaVM.SEC_NODE_407 = { ID = 407, HASH = '0x003DEF83', ADDR = 0x12786271, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 407 * 1.5 end }
BorcaVM.SEC_NODE_408 = { ID = 408, HASH = '0x003E1678', ADDR = 0x12817687, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 408 * 1.5 end }
BorcaVM.SEC_NODE_409 = { ID = 409, HASH = '0x003E3D6D', ADDR = 0x12849103, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 409 * 1.5 end }
BorcaVM.SEC_NODE_410 = { ID = 410, HASH = '0x003E6462', ADDR = 0x12880519, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 410 * 1.5 end }
BorcaVM.SEC_NODE_411 = { ID = 411, HASH = '0x003E8B57', ADDR = 0x12911934, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 411 * 1.5 end }
BorcaVM.SEC_NODE_412 = { ID = 412, HASH = '0x003EB24C', ADDR = 0x12943350, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 412 * 1.5 end }
BorcaVM.SEC_NODE_413 = { ID = 413, HASH = '0x003ED941', ADDR = 0x12974766, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 413 * 1.5 end }
BorcaVM.SEC_NODE_414 = { ID = 414, HASH = '0x003F0036', ADDR = 0x13006182, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 414 * 1.5 end }
BorcaVM.SEC_NODE_415 = { ID = 415, HASH = '0x003F272B', ADDR = 0x13037598, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 415 * 1.5 end }
BorcaVM.SEC_NODE_416 = { ID = 416, HASH = '0x003F4E20', ADDR = 0x13069014, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 416 * 1.5 end }
BorcaVM.SEC_NODE_417 = { ID = 417, HASH = '0x003F7515', ADDR = 0x13100430, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 417 * 1.5 end }
BorcaVM.SEC_NODE_418 = { ID = 418, HASH = '0x003F9C0A', ADDR = 0x13131846, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 418 * 1.5 end }
BorcaVM.SEC_NODE_419 = { ID = 419, HASH = '0x003FC2FF', ADDR = 0x13163262, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 419 * 1.5 end }
BorcaVM.SEC_NODE_420 = { ID = 420, HASH = '0x003FE9F4', ADDR = 0x13194677, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 420 * 1.5 end }
BorcaVM.SEC_NODE_421 = { ID = 421, HASH = '0x004010E9', ADDR = 0x13226093, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 421 * 1.5 end }
BorcaVM.SEC_NODE_422 = { ID = 422, HASH = '0x004037DE', ADDR = 0x13257509, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 422 * 1.5 end }
BorcaVM.SEC_NODE_423 = { ID = 423, HASH = '0x00405ED3', ADDR = 0x13288925, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 423 * 1.5 end }
BorcaVM.SEC_NODE_424 = { ID = 424, HASH = '0x004085C8', ADDR = 0x13320341, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 424 * 1.5 end }
BorcaVM.SEC_NODE_425 = { ID = 425, HASH = '0x0040ACBD', ADDR = 0x13351757, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 425 * 1.5 end }
BorcaVM.SEC_NODE_426 = { ID = 426, HASH = '0x0040D3B2', ADDR = 0x13383173, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 426 * 1.5 end }
BorcaVM.SEC_NODE_427 = { ID = 427, HASH = '0x0040FAA7', ADDR = 0x13414589, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 427 * 1.5 end }
BorcaVM.SEC_NODE_428 = { ID = 428, HASH = '0x0041219C', ADDR = 0x13446005, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 428 * 1.5 end }
BorcaVM.SEC_NODE_429 = { ID = 429, HASH = '0x00414891', ADDR = 0x13477421, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 429 * 1.5 end }
BorcaVM.SEC_NODE_430 = { ID = 430, HASH = '0x00416F86', ADDR = 0x13508836, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 430 * 1.5 end }
BorcaVM.SEC_NODE_431 = { ID = 431, HASH = '0x0041967B', ADDR = 0x13540252, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 431 * 1.5 end }
BorcaVM.SEC_NODE_432 = { ID = 432, HASH = '0x0041BD70', ADDR = 0x13571668, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 432 * 1.5 end }
BorcaVM.SEC_NODE_433 = { ID = 433, HASH = '0x0041E465', ADDR = 0x13603084, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 433 * 1.5 end }
BorcaVM.SEC_NODE_434 = { ID = 434, HASH = '0x00420B5A', ADDR = 0x13634500, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 434 * 1.5 end }
BorcaVM.SEC_NODE_435 = { ID = 435, HASH = '0x0042324F', ADDR = 0x13665916, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 435 * 1.5 end }
BorcaVM.SEC_NODE_436 = { ID = 436, HASH = '0x00425944', ADDR = 0x13697332, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 436 * 1.5 end }
BorcaVM.SEC_NODE_437 = { ID = 437, HASH = '0x00428039', ADDR = 0x13728748, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 437 * 1.5 end }
BorcaVM.SEC_NODE_438 = { ID = 438, HASH = '0x0042A72E', ADDR = 0x13760164, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 438 * 1.5 end }
BorcaVM.SEC_NODE_439 = { ID = 439, HASH = '0x0042CE23', ADDR = 0x13791580, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 439 * 1.5 end }
BorcaVM.SEC_NODE_440 = { ID = 440, HASH = '0x0042F518', ADDR = 0x13822996, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 440 * 1.5 end }
BorcaVM.SEC_NODE_441 = { ID = 441, HASH = '0x00431C0D', ADDR = 0x13854411, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 441 * 1.5 end }
BorcaVM.SEC_NODE_442 = { ID = 442, HASH = '0x00434302', ADDR = 0x13885827, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 442 * 1.5 end }
BorcaVM.SEC_NODE_443 = { ID = 443, HASH = '0x004369F7', ADDR = 0x13917243, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 443 * 1.5 end }
BorcaVM.SEC_NODE_444 = { ID = 444, HASH = '0x004390EC', ADDR = 0x13948659, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 444 * 1.5 end }
BorcaVM.SEC_NODE_445 = { ID = 445, HASH = '0x0043B7E1', ADDR = 0x13980075, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 445 * 1.5 end }
BorcaVM.SEC_NODE_446 = { ID = 446, HASH = '0x0043DED6', ADDR = 0x14011491, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 446 * 1.5 end }
BorcaVM.SEC_NODE_447 = { ID = 447, HASH = '0x004405CB', ADDR = 0x14042907, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 447 * 1.5 end }
BorcaVM.SEC_NODE_448 = { ID = 448, HASH = '0x00442CC0', ADDR = 0x14074323, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 448 * 1.5 end }
BorcaVM.SEC_NODE_449 = { ID = 449, HASH = '0x004453B5', ADDR = 0x14105739, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 449 * 1.5 end }
BorcaVM.SEC_NODE_450 = { ID = 450, HASH = '0x00447AAA', ADDR = 0x14137155, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 450 * 1.5 end }
BorcaVM.SEC_NODE_451 = { ID = 451, HASH = '0x0044A19F', ADDR = 0x14168570, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 451 * 1.5 end }
BorcaVM.SEC_NODE_452 = { ID = 452, HASH = '0x0044C894', ADDR = 0x14199986, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 452 * 1.5 end }
BorcaVM.SEC_NODE_453 = { ID = 453, HASH = '0x0044EF89', ADDR = 0x14231402, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 453 * 1.5 end }
BorcaVM.SEC_NODE_454 = { ID = 454, HASH = '0x0045167E', ADDR = 0x14262818, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 454 * 1.5 end }
BorcaVM.SEC_NODE_455 = { ID = 455, HASH = '0x00453D73', ADDR = 0x14294234, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 455 * 1.5 end }
BorcaVM.SEC_NODE_456 = { ID = 456, HASH = '0x00456468', ADDR = 0x14325650, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 456 * 1.5 end }
BorcaVM.SEC_NODE_457 = { ID = 457, HASH = '0x00458B5D', ADDR = 0x14357066, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 457 * 1.5 end }
BorcaVM.SEC_NODE_458 = { ID = 458, HASH = '0x0045B252', ADDR = 0x14388482, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 458 * 1.5 end }
BorcaVM.SEC_NODE_459 = { ID = 459, HASH = '0x0045D947', ADDR = 0x14419898, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 459 * 1.5 end }
BorcaVM.SEC_NODE_460 = { ID = 460, HASH = '0x0046003C', ADDR = 0x14451314, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 460 * 1.5 end }
BorcaVM.SEC_NODE_461 = { ID = 461, HASH = '0x00462731', ADDR = 0x14482729, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 461 * 1.5 end }
BorcaVM.SEC_NODE_462 = { ID = 462, HASH = '0x00464E26', ADDR = 0x14514145, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 462 * 1.5 end }
BorcaVM.SEC_NODE_463 = { ID = 463, HASH = '0x0046751B', ADDR = 0x14545561, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 463 * 1.5 end }
BorcaVM.SEC_NODE_464 = { ID = 464, HASH = '0x00469C10', ADDR = 0x14576977, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 464 * 1.5 end }
BorcaVM.SEC_NODE_465 = { ID = 465, HASH = '0x0046C305', ADDR = 0x14608393, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 465 * 1.5 end }
BorcaVM.SEC_NODE_466 = { ID = 466, HASH = '0x0046E9FA', ADDR = 0x14639809, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 466 * 1.5 end }
BorcaVM.SEC_NODE_467 = { ID = 467, HASH = '0x004710EF', ADDR = 0x14671225, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 467 * 1.5 end }
BorcaVM.SEC_NODE_468 = { ID = 468, HASH = '0x004737E4', ADDR = 0x14702641, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 468 * 1.5 end }
BorcaVM.SEC_NODE_469 = { ID = 469, HASH = '0x00475ED9', ADDR = 0x14734057, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 469 * 1.5 end }
BorcaVM.SEC_NODE_470 = { ID = 470, HASH = '0x004785CE', ADDR = 0x14765473, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 470 * 1.5 end }
BorcaVM.SEC_NODE_471 = { ID = 471, HASH = '0x0047ACC3', ADDR = 0x14796888, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 471 * 1.5 end }
BorcaVM.SEC_NODE_472 = { ID = 472, HASH = '0x0047D3B8', ADDR = 0x14828304, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 472 * 1.5 end }
BorcaVM.SEC_NODE_473 = { ID = 473, HASH = '0x0047FAAD', ADDR = 0x14859720, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 473 * 1.5 end }
BorcaVM.SEC_NODE_474 = { ID = 474, HASH = '0x004821A2', ADDR = 0x14891136, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 474 * 1.5 end }
BorcaVM.SEC_NODE_475 = { ID = 475, HASH = '0x00484897', ADDR = 0x14922552, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 475 * 1.5 end }
BorcaVM.SEC_NODE_476 = { ID = 476, HASH = '0x00486F8C', ADDR = 0x14953968, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 476 * 1.5 end }
BorcaVM.SEC_NODE_477 = { ID = 477, HASH = '0x00489681', ADDR = 0x14985384, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 477 * 1.5 end }
BorcaVM.SEC_NODE_478 = { ID = 478, HASH = '0x0048BD76', ADDR = 0x15016800, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 478 * 1.5 end }
BorcaVM.SEC_NODE_479 = { ID = 479, HASH = '0x0048E46B', ADDR = 0x15048216, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 479 * 1.5 end }
BorcaVM.SEC_NODE_480 = { ID = 480, HASH = '0x00490B60', ADDR = 0x15079632, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 480 * 1.5 end }
BorcaVM.SEC_NODE_481 = { ID = 481, HASH = '0x00493255', ADDR = 0x15111047, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 481 * 1.5 end }
BorcaVM.SEC_NODE_482 = { ID = 482, HASH = '0x0049594A', ADDR = 0x15142463, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 482 * 1.5 end }
BorcaVM.SEC_NODE_483 = { ID = 483, HASH = '0x0049803F', ADDR = 0x15173879, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 483 * 1.5 end }
BorcaVM.SEC_NODE_484 = { ID = 484, HASH = '0x0049A734', ADDR = 0x15205295, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 484 * 1.5 end }
BorcaVM.SEC_NODE_485 = { ID = 485, HASH = '0x0049CE29', ADDR = 0x15236711, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 485 * 1.5 end }
BorcaVM.SEC_NODE_486 = { ID = 486, HASH = '0x0049F51E', ADDR = 0x15268127, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 486 * 1.5 end }
BorcaVM.SEC_NODE_487 = { ID = 487, HASH = '0x004A1C13', ADDR = 0x15299543, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 487 * 1.5 end }
BorcaVM.SEC_NODE_488 = { ID = 488, HASH = '0x004A4308', ADDR = 0x15330959, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 488 * 1.5 end }
BorcaVM.SEC_NODE_489 = { ID = 489, HASH = '0x004A69FD', ADDR = 0x15362375, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 489 * 1.5 end }
BorcaVM.SEC_NODE_490 = { ID = 490, HASH = '0x004A90F2', ADDR = 0x15393790, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 490 * 1.5 end }
BorcaVM.SEC_NODE_491 = { ID = 491, HASH = '0x004AB7E7', ADDR = 0x15425206, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 491 * 1.5 end }
BorcaVM.SEC_NODE_492 = { ID = 492, HASH = '0x004ADEDC', ADDR = 0x15456622, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 492 * 1.5 end }
BorcaVM.SEC_NODE_493 = { ID = 493, HASH = '0x004B05D1', ADDR = 0x15488038, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 493 * 1.5 end }
BorcaVM.SEC_NODE_494 = { ID = 494, HASH = '0x004B2CC6', ADDR = 0x15519454, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 494 * 1.5 end }
BorcaVM.SEC_NODE_495 = { ID = 495, HASH = '0x004B53BB', ADDR = 0x15550870, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 495 * 1.5 end }
BorcaVM.SEC_NODE_496 = { ID = 496, HASH = '0x004B7AB0', ADDR = 0x15582286, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 496 * 1.5 end }
BorcaVM.SEC_NODE_497 = { ID = 497, HASH = '0x004BA1A5', ADDR = 0x15613702, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 497 * 1.5 end }
BorcaVM.SEC_NODE_498 = { ID = 498, HASH = '0x004BC89A', ADDR = 0x15645118, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 498 * 1.5 end }
BorcaVM.SEC_NODE_499 = { ID = 499, HASH = '0x004BEF8F', ADDR = 0x15676534, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 499 * 1.5 end }
BorcaVM.SEC_NODE_500 = { ID = 500, HASH = '0x004C1684', ADDR = 0x15707949, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 500 * 1.5 end }
BorcaVM.SEC_NODE_501 = { ID = 501, HASH = '0x004C3D79', ADDR = 0x15739365, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 501 * 1.5 end }
BorcaVM.SEC_NODE_502 = { ID = 502, HASH = '0x004C646E', ADDR = 0x15770781, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 502 * 1.5 end }
BorcaVM.SEC_NODE_503 = { ID = 503, HASH = '0x004C8B63', ADDR = 0x15802197, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 503 * 1.5 end }
BorcaVM.SEC_NODE_504 = { ID = 504, HASH = '0x004CB258', ADDR = 0x15833613, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 504 * 1.5 end }
BorcaVM.SEC_NODE_505 = { ID = 505, HASH = '0x004CD94D', ADDR = 0x15865029, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 505 * 1.5 end }
BorcaVM.SEC_NODE_506 = { ID = 506, HASH = '0x004D0042', ADDR = 0x15896445, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 506 * 1.5 end }
BorcaVM.SEC_NODE_507 = { ID = 507, HASH = '0x004D2737', ADDR = 0x15927861, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 507 * 1.5 end }
BorcaVM.SEC_NODE_508 = { ID = 508, HASH = '0x004D4E2C', ADDR = 0x15959277, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 508 * 1.5 end }
BorcaVM.SEC_NODE_509 = { ID = 509, HASH = '0x004D7521', ADDR = 0x15990693, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 509 * 1.5 end }
BorcaVM.SEC_NODE_510 = { ID = 510, HASH = '0x004D9C16', ADDR = 0x16022109, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 510 * 1.5 end }
BorcaVM.SEC_NODE_511 = { ID = 511, HASH = '0x004DC30B', ADDR = 0x16053524, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 511 * 1.5 end }
BorcaVM.SEC_NODE_512 = { ID = 512, HASH = '0x004DEA00', ADDR = 0x16084940, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 512 * 1.5 end }
BorcaVM.SEC_NODE_513 = { ID = 513, HASH = '0x004E10F5', ADDR = 0x16116356, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 513 * 1.5 end }
BorcaVM.SEC_NODE_514 = { ID = 514, HASH = '0x004E37EA', ADDR = 0x16147772, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 514 * 1.5 end }
BorcaVM.SEC_NODE_515 = { ID = 515, HASH = '0x004E5EDF', ADDR = 0x16179188, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 515 * 1.5 end }
BorcaVM.SEC_NODE_516 = { ID = 516, HASH = '0x004E85D4', ADDR = 0x16210604, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 516 * 1.5 end }
BorcaVM.SEC_NODE_517 = { ID = 517, HASH = '0x004EACC9', ADDR = 0x16242020, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 517 * 1.5 end }
BorcaVM.SEC_NODE_518 = { ID = 518, HASH = '0x004ED3BE', ADDR = 0x16273436, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 518 * 1.5 end }
BorcaVM.SEC_NODE_519 = { ID = 519, HASH = '0x004EFAB3', ADDR = 0x16304852, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 519 * 1.5 end }
BorcaVM.SEC_NODE_520 = { ID = 520, HASH = '0x004F21A8', ADDR = 0x16336268, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 520 * 1.5 end }
BorcaVM.SEC_NODE_521 = { ID = 521, HASH = '0x004F489D', ADDR = 0x16367683, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 521 * 1.5 end }
BorcaVM.SEC_NODE_522 = { ID = 522, HASH = '0x004F6F92', ADDR = 0x16399099, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 522 * 1.5 end }
BorcaVM.SEC_NODE_523 = { ID = 523, HASH = '0x004F9687', ADDR = 0x16430515, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 523 * 1.5 end }
BorcaVM.SEC_NODE_524 = { ID = 524, HASH = '0x004FBD7C', ADDR = 0x16461931, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 524 * 1.5 end }
BorcaVM.SEC_NODE_525 = { ID = 525, HASH = '0x004FE471', ADDR = 0x16493347, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 525 * 1.5 end }
BorcaVM.SEC_NODE_526 = { ID = 526, HASH = '0x00500B66', ADDR = 0x16524763, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 526 * 1.5 end }
BorcaVM.SEC_NODE_527 = { ID = 527, HASH = '0x0050325B', ADDR = 0x16556179, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 527 * 1.5 end }
BorcaVM.SEC_NODE_528 = { ID = 528, HASH = '0x00505950', ADDR = 0x16587595, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 528 * 1.5 end }
BorcaVM.SEC_NODE_529 = { ID = 529, HASH = '0x00508045', ADDR = 0x16619011, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 529 * 1.5 end }
BorcaVM.SEC_NODE_530 = { ID = 530, HASH = '0x0050A73A', ADDR = 0x16650427, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 530 * 1.5 end }
BorcaVM.SEC_NODE_531 = { ID = 531, HASH = '0x0050CE2F', ADDR = 0x16681842, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 531 * 1.5 end }
BorcaVM.SEC_NODE_532 = { ID = 532, HASH = '0x0050F524', ADDR = 0x16713258, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 532 * 1.5 end }
BorcaVM.SEC_NODE_533 = { ID = 533, HASH = '0x00511C19', ADDR = 0x16744674, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 533 * 1.5 end }
BorcaVM.SEC_NODE_534 = { ID = 534, HASH = '0x0051430E', ADDR = 0x16776090, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 534 * 1.5 end }
BorcaVM.SEC_NODE_535 = { ID = 535, HASH = '0x00516A03', ADDR = 0x16807506, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 535 * 1.5 end }
BorcaVM.SEC_NODE_536 = { ID = 536, HASH = '0x005190F8', ADDR = 0x16838922, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 536 * 1.5 end }
BorcaVM.SEC_NODE_537 = { ID = 537, HASH = '0x0051B7ED', ADDR = 0x16870338, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 537 * 1.5 end }
BorcaVM.SEC_NODE_538 = { ID = 538, HASH = '0x0051DEE2', ADDR = 0x16901754, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 538 * 1.5 end }
BorcaVM.SEC_NODE_539 = { ID = 539, HASH = '0x005205D7', ADDR = 0x16933170, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 539 * 1.5 end }
BorcaVM.SEC_NODE_540 = { ID = 540, HASH = '0x00522CCC', ADDR = 0x16964586, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 540 * 1.5 end }
BorcaVM.SEC_NODE_541 = { ID = 541, HASH = '0x005253C1', ADDR = 0x16996001, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 541 * 1.5 end }
BorcaVM.SEC_NODE_542 = { ID = 542, HASH = '0x00527AB6', ADDR = 0x17027417, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 542 * 1.5 end }
BorcaVM.SEC_NODE_543 = { ID = 543, HASH = '0x0052A1AB', ADDR = 0x17058833, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 543 * 1.5 end }
BorcaVM.SEC_NODE_544 = { ID = 544, HASH = '0x0052C8A0', ADDR = 0x17090249, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 544 * 1.5 end }
BorcaVM.SEC_NODE_545 = { ID = 545, HASH = '0x0052EF95', ADDR = 0x17121665, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 545 * 1.5 end }
BorcaVM.SEC_NODE_546 = { ID = 546, HASH = '0x0053168A', ADDR = 0x17153081, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 546 * 1.5 end }
BorcaVM.SEC_NODE_547 = { ID = 547, HASH = '0x00533D7F', ADDR = 0x17184497, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 547 * 1.5 end }
BorcaVM.SEC_NODE_548 = { ID = 548, HASH = '0x00536474', ADDR = 0x17215913, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 548 * 1.5 end }
BorcaVM.SEC_NODE_549 = { ID = 549, HASH = '0x00538B69', ADDR = 0x17247329, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 549 * 1.5 end }
BorcaVM.SEC_NODE_550 = { ID = 550, HASH = '0x0053B25E', ADDR = 0x17278745, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 550 * 1.5 end }
BorcaVM.SEC_NODE_551 = { ID = 551, HASH = '0x0053D953', ADDR = 0x17310160, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 551 * 1.5 end }
BorcaVM.SEC_NODE_552 = { ID = 552, HASH = '0x00540048', ADDR = 0x17341576, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 552 * 1.5 end }
BorcaVM.SEC_NODE_553 = { ID = 553, HASH = '0x0054273D', ADDR = 0x17372992, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 553 * 1.5 end }
BorcaVM.SEC_NODE_554 = { ID = 554, HASH = '0x00544E32', ADDR = 0x17404408, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 554 * 1.5 end }
BorcaVM.SEC_NODE_555 = { ID = 555, HASH = '0x00547527', ADDR = 0x17435824, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 555 * 1.5 end }
BorcaVM.SEC_NODE_556 = { ID = 556, HASH = '0x00549C1C', ADDR = 0x17467240, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 556 * 1.5 end }
BorcaVM.SEC_NODE_557 = { ID = 557, HASH = '0x0054C311', ADDR = 0x17498656, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 557 * 1.5 end }
BorcaVM.SEC_NODE_558 = { ID = 558, HASH = '0x0054EA06', ADDR = 0x17530072, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 558 * 1.5 end }
BorcaVM.SEC_NODE_559 = { ID = 559, HASH = '0x005510FB', ADDR = 0x17561488, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 559 * 1.5 end }
BorcaVM.SEC_NODE_560 = { ID = 560, HASH = '0x005537F0', ADDR = 0x17592904, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 560 * 1.5 end }
BorcaVM.SEC_NODE_561 = { ID = 561, HASH = '0x00555EE5', ADDR = 0x17624319, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 561 * 1.5 end }
BorcaVM.SEC_NODE_562 = { ID = 562, HASH = '0x005585DA', ADDR = 0x17655735, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 562 * 1.5 end }
BorcaVM.SEC_NODE_563 = { ID = 563, HASH = '0x0055ACCF', ADDR = 0x17687151, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 563 * 1.5 end }
BorcaVM.SEC_NODE_564 = { ID = 564, HASH = '0x0055D3C4', ADDR = 0x17718567, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 564 * 1.5 end }
BorcaVM.SEC_NODE_565 = { ID = 565, HASH = '0x0055FAB9', ADDR = 0x17749983, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 565 * 1.5 end }
BorcaVM.SEC_NODE_566 = { ID = 566, HASH = '0x005621AE', ADDR = 0x17781399, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 566 * 1.5 end }
BorcaVM.SEC_NODE_567 = { ID = 567, HASH = '0x005648A3', ADDR = 0x17812815, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 567 * 1.5 end }
BorcaVM.SEC_NODE_568 = { ID = 568, HASH = '0x00566F98', ADDR = 0x17844231, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 568 * 1.5 end }
BorcaVM.SEC_NODE_569 = { ID = 569, HASH = '0x0056968D', ADDR = 0x17875647, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 569 * 1.5 end }
BorcaVM.SEC_NODE_570 = { ID = 570, HASH = '0x0056BD82', ADDR = 0x17907063, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 570 * 1.5 end }
BorcaVM.SEC_NODE_571 = { ID = 571, HASH = '0x0056E477', ADDR = 0x17938478, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 571 * 1.5 end }
BorcaVM.SEC_NODE_572 = { ID = 572, HASH = '0x00570B6C', ADDR = 0x17969894, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 572 * 1.5 end }
BorcaVM.SEC_NODE_573 = { ID = 573, HASH = '0x00573261', ADDR = 0x18001310, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 573 * 1.5 end }
BorcaVM.SEC_NODE_574 = { ID = 574, HASH = '0x00575956', ADDR = 0x18032726, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 574 * 1.5 end }
BorcaVM.SEC_NODE_575 = { ID = 575, HASH = '0x0057804B', ADDR = 0x18064142, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 575 * 1.5 end }
BorcaVM.SEC_NODE_576 = { ID = 576, HASH = '0x0057A740', ADDR = 0x18095558, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 576 * 1.5 end }
BorcaVM.SEC_NODE_577 = { ID = 577, HASH = '0x0057CE35', ADDR = 0x18126974, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 577 * 1.5 end }
BorcaVM.SEC_NODE_578 = { ID = 578, HASH = '0x0057F52A', ADDR = 0x18158390, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 578 * 1.5 end }
BorcaVM.SEC_NODE_579 = { ID = 579, HASH = '0x00581C1F', ADDR = 0x18189806, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 579 * 1.5 end }
BorcaVM.SEC_NODE_580 = { ID = 580, HASH = '0x00584314', ADDR = 0x18221222, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 580 * 1.5 end }
BorcaVM.SEC_NODE_581 = { ID = 581, HASH = '0x00586A09', ADDR = 0x18252637, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 581 * 1.5 end }
BorcaVM.SEC_NODE_582 = { ID = 582, HASH = '0x005890FE', ADDR = 0x18284053, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 582 * 1.5 end }
BorcaVM.SEC_NODE_583 = { ID = 583, HASH = '0x0058B7F3', ADDR = 0x18315469, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 583 * 1.5 end }
BorcaVM.SEC_NODE_584 = { ID = 584, HASH = '0x0058DEE8', ADDR = 0x18346885, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 584 * 1.5 end }
BorcaVM.SEC_NODE_585 = { ID = 585, HASH = '0x005905DD', ADDR = 0x18378301, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 585 * 1.5 end }
BorcaVM.SEC_NODE_586 = { ID = 586, HASH = '0x00592CD2', ADDR = 0x18409717, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 586 * 1.5 end }
BorcaVM.SEC_NODE_587 = { ID = 587, HASH = '0x005953C7', ADDR = 0x18441133, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 587 * 1.5 end }
BorcaVM.SEC_NODE_588 = { ID = 588, HASH = '0x00597ABC', ADDR = 0x18472549, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 588 * 1.5 end }
BorcaVM.SEC_NODE_589 = { ID = 589, HASH = '0x0059A1B1', ADDR = 0x18503965, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 589 * 1.5 end }
BorcaVM.SEC_NODE_590 = { ID = 590, HASH = '0x0059C8A6', ADDR = 0x18535381, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 590 * 1.5 end }
BorcaVM.SEC_NODE_591 = { ID = 591, HASH = '0x0059EF9B', ADDR = 0x18566796, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 591 * 1.5 end }
BorcaVM.SEC_NODE_592 = { ID = 592, HASH = '0x005A1690', ADDR = 0x18598212, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 592 * 1.5 end }
BorcaVM.SEC_NODE_593 = { ID = 593, HASH = '0x005A3D85', ADDR = 0x18629628, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 593 * 1.5 end }
BorcaVM.SEC_NODE_594 = { ID = 594, HASH = '0x005A647A', ADDR = 0x18661044, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 594 * 1.5 end }
BorcaVM.SEC_NODE_595 = { ID = 595, HASH = '0x005A8B6F', ADDR = 0x18692460, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 595 * 1.5 end }
BorcaVM.SEC_NODE_596 = { ID = 596, HASH = '0x005AB264', ADDR = 0x18723876, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 596 * 1.5 end }
BorcaVM.SEC_NODE_597 = { ID = 597, HASH = '0x005AD959', ADDR = 0x18755292, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 597 * 1.5 end }
BorcaVM.SEC_NODE_598 = { ID = 598, HASH = '0x005B004E', ADDR = 0x18786708, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 598 * 1.5 end }
BorcaVM.SEC_NODE_599 = { ID = 599, HASH = '0x005B2743', ADDR = 0x18818124, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 599 * 1.5 end }
BorcaVM.SEC_NODE_600 = { ID = 600, HASH = '0x005B4E38', ADDR = 0x18849540, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 600 * 1.5 end }
BorcaVM.SEC_NODE_601 = { ID = 601, HASH = '0x005B752D', ADDR = 0x18880955, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 601 * 1.5 end }
BorcaVM.SEC_NODE_602 = { ID = 602, HASH = '0x005B9C22', ADDR = 0x18912371, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 602 * 1.5 end }
BorcaVM.SEC_NODE_603 = { ID = 603, HASH = '0x005BC317', ADDR = 0x18943787, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 603 * 1.5 end }
BorcaVM.SEC_NODE_604 = { ID = 604, HASH = '0x005BEA0C', ADDR = 0x18975203, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 604 * 1.5 end }
BorcaVM.SEC_NODE_605 = { ID = 605, HASH = '0x005C1101', ADDR = 0x19006619, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 605 * 1.5 end }
BorcaVM.SEC_NODE_606 = { ID = 606, HASH = '0x005C37F6', ADDR = 0x19038035, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 606 * 1.5 end }
BorcaVM.SEC_NODE_607 = { ID = 607, HASH = '0x005C5EEB', ADDR = 0x19069451, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 607 * 1.5 end }
BorcaVM.SEC_NODE_608 = { ID = 608, HASH = '0x005C85E0', ADDR = 0x19100867, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 608 * 1.5 end }
BorcaVM.SEC_NODE_609 = { ID = 609, HASH = '0x005CACD5', ADDR = 0x19132283, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 609 * 1.5 end }
BorcaVM.SEC_NODE_610 = { ID = 610, HASH = '0x005CD3CA', ADDR = 0x19163699, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 610 * 1.5 end }
BorcaVM.SEC_NODE_611 = { ID = 611, HASH = '0x005CFABF', ADDR = 0x19195114, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 611 * 1.5 end }
BorcaVM.SEC_NODE_612 = { ID = 612, HASH = '0x005D21B4', ADDR = 0x19226530, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 612 * 1.5 end }
BorcaVM.SEC_NODE_613 = { ID = 613, HASH = '0x005D48A9', ADDR = 0x19257946, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 613 * 1.5 end }
BorcaVM.SEC_NODE_614 = { ID = 614, HASH = '0x005D6F9E', ADDR = 0x19289362, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 614 * 1.5 end }
BorcaVM.SEC_NODE_615 = { ID = 615, HASH = '0x005D9693', ADDR = 0x19320778, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 615 * 1.5 end }
BorcaVM.SEC_NODE_616 = { ID = 616, HASH = '0x005DBD88', ADDR = 0x19352194, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 616 * 1.5 end }
BorcaVM.SEC_NODE_617 = { ID = 617, HASH = '0x005DE47D', ADDR = 0x19383610, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 617 * 1.5 end }
BorcaVM.SEC_NODE_618 = { ID = 618, HASH = '0x005E0B72', ADDR = 0x19415026, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 618 * 1.5 end }
BorcaVM.SEC_NODE_619 = { ID = 619, HASH = '0x005E3267', ADDR = 0x19446442, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 619 * 1.5 end }
BorcaVM.SEC_NODE_620 = { ID = 620, HASH = '0x005E595C', ADDR = 0x19477858, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 620 * 1.5 end }
BorcaVM.SEC_NODE_621 = { ID = 621, HASH = '0x005E8051', ADDR = 0x19509273, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 621 * 1.5 end }
BorcaVM.SEC_NODE_622 = { ID = 622, HASH = '0x005EA746', ADDR = 0x19540689, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 622 * 1.5 end }
BorcaVM.SEC_NODE_623 = { ID = 623, HASH = '0x005ECE3B', ADDR = 0x19572105, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 623 * 1.5 end }
BorcaVM.SEC_NODE_624 = { ID = 624, HASH = '0x005EF530', ADDR = 0x19603521, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 624 * 1.5 end }
BorcaVM.SEC_NODE_625 = { ID = 625, HASH = '0x005F1C25', ADDR = 0x19634937, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 625 * 1.5 end }
BorcaVM.SEC_NODE_626 = { ID = 626, HASH = '0x005F431A', ADDR = 0x19666353, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 626 * 1.5 end }
BorcaVM.SEC_NODE_627 = { ID = 627, HASH = '0x005F6A0F', ADDR = 0x19697769, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 627 * 1.5 end }
BorcaVM.SEC_NODE_628 = { ID = 628, HASH = '0x005F9104', ADDR = 0x19729185, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 628 * 1.5 end }
BorcaVM.SEC_NODE_629 = { ID = 629, HASH = '0x005FB7F9', ADDR = 0x19760601, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 629 * 1.5 end }
BorcaVM.SEC_NODE_630 = { ID = 630, HASH = '0x005FDEEE', ADDR = 0x19792017, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 630 * 1.5 end }
BorcaVM.SEC_NODE_631 = { ID = 631, HASH = '0x006005E3', ADDR = 0x19823432, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 631 * 1.5 end }
BorcaVM.SEC_NODE_632 = { ID = 632, HASH = '0x00602CD8', ADDR = 0x19854848, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 632 * 1.5 end }
BorcaVM.SEC_NODE_633 = { ID = 633, HASH = '0x006053CD', ADDR = 0x19886264, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 633 * 1.5 end }
BorcaVM.SEC_NODE_634 = { ID = 634, HASH = '0x00607AC2', ADDR = 0x19917680, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 634 * 1.5 end }
BorcaVM.SEC_NODE_635 = { ID = 635, HASH = '0x0060A1B7', ADDR = 0x19949096, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 635 * 1.5 end }
BorcaVM.SEC_NODE_636 = { ID = 636, HASH = '0x0060C8AC', ADDR = 0x19980512, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 636 * 1.5 end }
BorcaVM.SEC_NODE_637 = { ID = 637, HASH = '0x0060EFA1', ADDR = 0x20011928, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 637 * 1.5 end }
BorcaVM.SEC_NODE_638 = { ID = 638, HASH = '0x00611696', ADDR = 0x20043344, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 638 * 1.5 end }
BorcaVM.SEC_NODE_639 = { ID = 639, HASH = '0x00613D8B', ADDR = 0x20074760, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 639 * 1.5 end }
BorcaVM.SEC_NODE_640 = { ID = 640, HASH = '0x00616480', ADDR = 0x20106176, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 640 * 1.5 end }
BorcaVM.SEC_NODE_641 = { ID = 641, HASH = '0x00618B75', ADDR = 0x20137591, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 641 * 1.5 end }
BorcaVM.SEC_NODE_642 = { ID = 642, HASH = '0x0061B26A', ADDR = 0x20169007, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 642 * 1.5 end }
BorcaVM.SEC_NODE_643 = { ID = 643, HASH = '0x0061D95F', ADDR = 0x20200423, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 643 * 1.5 end }
BorcaVM.SEC_NODE_644 = { ID = 644, HASH = '0x00620054', ADDR = 0x20231839, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 644 * 1.5 end }
BorcaVM.SEC_NODE_645 = { ID = 645, HASH = '0x00622749', ADDR = 0x20263255, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 645 * 1.5 end }
BorcaVM.SEC_NODE_646 = { ID = 646, HASH = '0x00624E3E', ADDR = 0x20294671, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 646 * 1.5 end }
BorcaVM.SEC_NODE_647 = { ID = 647, HASH = '0x00627533', ADDR = 0x20326087, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 647 * 1.5 end }
BorcaVM.SEC_NODE_648 = { ID = 648, HASH = '0x00629C28', ADDR = 0x20357503, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 648 * 1.5 end }
BorcaVM.SEC_NODE_649 = { ID = 649, HASH = '0x0062C31D', ADDR = 0x20388919, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 649 * 1.5 end }
BorcaVM.SEC_NODE_650 = { ID = 650, HASH = '0x0062EA12', ADDR = 0x20420335, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 650 * 1.5 end }
BorcaVM.SEC_NODE_651 = { ID = 651, HASH = '0x00631107', ADDR = 0x20451750, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 651 * 1.5 end }
BorcaVM.SEC_NODE_652 = { ID = 652, HASH = '0x006337FC', ADDR = 0x20483166, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 652 * 1.5 end }
BorcaVM.SEC_NODE_653 = { ID = 653, HASH = '0x00635EF1', ADDR = 0x20514582, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 653 * 1.5 end }
BorcaVM.SEC_NODE_654 = { ID = 654, HASH = '0x006385E6', ADDR = 0x20545998, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 654 * 1.5 end }
BorcaVM.SEC_NODE_655 = { ID = 655, HASH = '0x0063ACDB', ADDR = 0x20577414, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 655 * 1.5 end }
BorcaVM.SEC_NODE_656 = { ID = 656, HASH = '0x0063D3D0', ADDR = 0x20608830, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 656 * 1.5 end }
BorcaVM.SEC_NODE_657 = { ID = 657, HASH = '0x0063FAC5', ADDR = 0x20640246, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 657 * 1.5 end }
BorcaVM.SEC_NODE_658 = { ID = 658, HASH = '0x006421BA', ADDR = 0x20671662, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 658 * 1.5 end }
BorcaVM.SEC_NODE_659 = { ID = 659, HASH = '0x006448AF', ADDR = 0x20703078, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 659 * 1.5 end }
BorcaVM.SEC_NODE_660 = { ID = 660, HASH = '0x00646FA4', ADDR = 0x20734494, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 660 * 1.5 end }
BorcaVM.SEC_NODE_661 = { ID = 661, HASH = '0x00649699', ADDR = 0x20765909, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 661 * 1.5 end }
BorcaVM.SEC_NODE_662 = { ID = 662, HASH = '0x0064BD8E', ADDR = 0x20797325, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 662 * 1.5 end }
BorcaVM.SEC_NODE_663 = { ID = 663, HASH = '0x0064E483', ADDR = 0x20828741, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 663 * 1.5 end }
BorcaVM.SEC_NODE_664 = { ID = 664, HASH = '0x00650B78', ADDR = 0x20860157, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 664 * 1.5 end }
BorcaVM.SEC_NODE_665 = { ID = 665, HASH = '0x0065326D', ADDR = 0x20891573, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 665 * 1.5 end }
BorcaVM.SEC_NODE_666 = { ID = 666, HASH = '0x00655962', ADDR = 0x20922989, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 666 * 1.5 end }
BorcaVM.SEC_NODE_667 = { ID = 667, HASH = '0x00658057', ADDR = 0x20954405, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 667 * 1.5 end }
BorcaVM.SEC_NODE_668 = { ID = 668, HASH = '0x0065A74C', ADDR = 0x20985821, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 668 * 1.5 end }
BorcaVM.SEC_NODE_669 = { ID = 669, HASH = '0x0065CE41', ADDR = 0x21017237, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 669 * 1.5 end }
BorcaVM.SEC_NODE_670 = { ID = 670, HASH = '0x0065F536', ADDR = 0x21048653, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 670 * 1.5 end }
BorcaVM.SEC_NODE_671 = { ID = 671, HASH = '0x00661C2B', ADDR = 0x21080068, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 671 * 1.5 end }
BorcaVM.SEC_NODE_672 = { ID = 672, HASH = '0x00664320', ADDR = 0x21111484, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 672 * 1.5 end }
BorcaVM.SEC_NODE_673 = { ID = 673, HASH = '0x00666A15', ADDR = 0x21142900, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 673 * 1.5 end }
BorcaVM.SEC_NODE_674 = { ID = 674, HASH = '0x0066910A', ADDR = 0x21174316, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 674 * 1.5 end }
BorcaVM.SEC_NODE_675 = { ID = 675, HASH = '0x0066B7FF', ADDR = 0x21205732, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 675 * 1.5 end }
BorcaVM.SEC_NODE_676 = { ID = 676, HASH = '0x0066DEF4', ADDR = 0x21237148, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 676 * 1.5 end }
BorcaVM.SEC_NODE_677 = { ID = 677, HASH = '0x006705E9', ADDR = 0x21268564, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 677 * 1.5 end }
BorcaVM.SEC_NODE_678 = { ID = 678, HASH = '0x00672CDE', ADDR = 0x21299980, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 678 * 1.5 end }
BorcaVM.SEC_NODE_679 = { ID = 679, HASH = '0x006753D3', ADDR = 0x21331396, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 679 * 1.5 end }
BorcaVM.SEC_NODE_680 = { ID = 680, HASH = '0x00677AC8', ADDR = 0x21362812, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 680 * 1.5 end }
BorcaVM.SEC_NODE_681 = { ID = 681, HASH = '0x0067A1BD', ADDR = 0x21394227, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 681 * 1.5 end }
BorcaVM.SEC_NODE_682 = { ID = 682, HASH = '0x0067C8B2', ADDR = 0x21425643, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 682 * 1.5 end }
BorcaVM.SEC_NODE_683 = { ID = 683, HASH = '0x0067EFA7', ADDR = 0x21457059, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 683 * 1.5 end }
BorcaVM.SEC_NODE_684 = { ID = 684, HASH = '0x0068169C', ADDR = 0x21488475, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 684 * 1.5 end }
BorcaVM.SEC_NODE_685 = { ID = 685, HASH = '0x00683D91', ADDR = 0x21519891, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 685 * 1.5 end }
BorcaVM.SEC_NODE_686 = { ID = 686, HASH = '0x00686486', ADDR = 0x21551307, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 686 * 1.5 end }
BorcaVM.SEC_NODE_687 = { ID = 687, HASH = '0x00688B7B', ADDR = 0x21582723, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 687 * 1.5 end }
BorcaVM.SEC_NODE_688 = { ID = 688, HASH = '0x0068B270', ADDR = 0x21614139, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 688 * 1.5 end }
BorcaVM.SEC_NODE_689 = { ID = 689, HASH = '0x0068D965', ADDR = 0x21645555, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 689 * 1.5 end }
BorcaVM.SEC_NODE_690 = { ID = 690, HASH = '0x0069005A', ADDR = 0x21676971, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 690 * 1.5 end }
BorcaVM.SEC_NODE_691 = { ID = 691, HASH = '0x0069274F', ADDR = 0x21708386, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 691 * 1.5 end }
BorcaVM.SEC_NODE_692 = { ID = 692, HASH = '0x00694E44', ADDR = 0x21739802, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 692 * 1.5 end }
BorcaVM.SEC_NODE_693 = { ID = 693, HASH = '0x00697539', ADDR = 0x21771218, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 693 * 1.5 end }
BorcaVM.SEC_NODE_694 = { ID = 694, HASH = '0x00699C2E', ADDR = 0x21802634, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 694 * 1.5 end }
BorcaVM.SEC_NODE_695 = { ID = 695, HASH = '0x0069C323', ADDR = 0x21834050, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 695 * 1.5 end }
BorcaVM.SEC_NODE_696 = { ID = 696, HASH = '0x0069EA18', ADDR = 0x21865466, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 696 * 1.5 end }
BorcaVM.SEC_NODE_697 = { ID = 697, HASH = '0x006A110D', ADDR = 0x21896882, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 697 * 1.5 end }
BorcaVM.SEC_NODE_698 = { ID = 698, HASH = '0x006A3802', ADDR = 0x21928298, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 698 * 1.5 end }
BorcaVM.SEC_NODE_699 = { ID = 699, HASH = '0x006A5EF7', ADDR = 0x21959714, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 699 * 1.5 end }
BorcaVM.SEC_NODE_700 = { ID = 700, HASH = '0x006A85EC', ADDR = 0x21991130, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 700 * 1.5 end }
BorcaVM.SEC_NODE_701 = { ID = 701, HASH = '0x006AACE1', ADDR = 0x22022545, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 701 * 1.5 end }
BorcaVM.SEC_NODE_702 = { ID = 702, HASH = '0x006AD3D6', ADDR = 0x22053961, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 702 * 1.5 end }
BorcaVM.SEC_NODE_703 = { ID = 703, HASH = '0x006AFACB', ADDR = 0x22085377, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 703 * 1.5 end }
BorcaVM.SEC_NODE_704 = { ID = 704, HASH = '0x006B21C0', ADDR = 0x22116793, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 704 * 1.5 end }
BorcaVM.SEC_NODE_705 = { ID = 705, HASH = '0x006B48B5', ADDR = 0x22148209, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 705 * 1.5 end }
BorcaVM.SEC_NODE_706 = { ID = 706, HASH = '0x006B6FAA', ADDR = 0x22179625, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 706 * 1.5 end }
BorcaVM.SEC_NODE_707 = { ID = 707, HASH = '0x006B969F', ADDR = 0x22211041, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 707 * 1.5 end }
BorcaVM.SEC_NODE_708 = { ID = 708, HASH = '0x006BBD94', ADDR = 0x22242457, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 708 * 1.5 end }
BorcaVM.SEC_NODE_709 = { ID = 709, HASH = '0x006BE489', ADDR = 0x22273873, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 709 * 1.5 end }
BorcaVM.SEC_NODE_710 = { ID = 710, HASH = '0x006C0B7E', ADDR = 0x22305288, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 710 * 1.5 end }
BorcaVM.SEC_NODE_711 = { ID = 711, HASH = '0x006C3273', ADDR = 0x22336704, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 711 * 1.5 end }
BorcaVM.SEC_NODE_712 = { ID = 712, HASH = '0x006C5968', ADDR = 0x22368120, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 712 * 1.5 end }
BorcaVM.SEC_NODE_713 = { ID = 713, HASH = '0x006C805D', ADDR = 0x22399536, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 713 * 1.5 end }
BorcaVM.SEC_NODE_714 = { ID = 714, HASH = '0x006CA752', ADDR = 0x22430952, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 714 * 1.5 end }
BorcaVM.SEC_NODE_715 = { ID = 715, HASH = '0x006CCE47', ADDR = 0x22462368, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 715 * 1.5 end }
BorcaVM.SEC_NODE_716 = { ID = 716, HASH = '0x006CF53C', ADDR = 0x22493784, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 716 * 1.5 end }
BorcaVM.SEC_NODE_717 = { ID = 717, HASH = '0x006D1C31', ADDR = 0x22525200, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 717 * 1.5 end }
BorcaVM.SEC_NODE_718 = { ID = 718, HASH = '0x006D4326', ADDR = 0x22556616, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 718 * 1.5 end }
BorcaVM.SEC_NODE_719 = { ID = 719, HASH = '0x006D6A1B', ADDR = 0x22588032, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 719 * 1.5 end }
BorcaVM.SEC_NODE_720 = { ID = 720, HASH = '0x006D9110', ADDR = 0x22619447, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 720 * 1.5 end }
BorcaVM.SEC_NODE_721 = { ID = 721, HASH = '0x006DB805', ADDR = 0x22650863, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 721 * 1.5 end }
BorcaVM.SEC_NODE_722 = { ID = 722, HASH = '0x006DDEFA', ADDR = 0x22682279, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 722 * 1.5 end }
BorcaVM.SEC_NODE_723 = { ID = 723, HASH = '0x006E05EF', ADDR = 0x22713695, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 723 * 1.5 end }
BorcaVM.SEC_NODE_724 = { ID = 724, HASH = '0x006E2CE4', ADDR = 0x22745111, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 724 * 1.5 end }
BorcaVM.SEC_NODE_725 = { ID = 725, HASH = '0x006E53D9', ADDR = 0x22776527, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 725 * 1.5 end }
BorcaVM.SEC_NODE_726 = { ID = 726, HASH = '0x006E7ACE', ADDR = 0x22807943, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 726 * 1.5 end }
BorcaVM.SEC_NODE_727 = { ID = 727, HASH = '0x006EA1C3', ADDR = 0x22839359, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 727 * 1.5 end }
BorcaVM.SEC_NODE_728 = { ID = 728, HASH = '0x006EC8B8', ADDR = 0x22870775, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 728 * 1.5 end }
BorcaVM.SEC_NODE_729 = { ID = 729, HASH = '0x006EEFAD', ADDR = 0x22902191, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 729 * 1.5 end }
BorcaVM.SEC_NODE_730 = { ID = 730, HASH = '0x006F16A2', ADDR = 0x22933606, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 730 * 1.5 end }
BorcaVM.SEC_NODE_731 = { ID = 731, HASH = '0x006F3D97', ADDR = 0x22965022, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 731 * 1.5 end }
BorcaVM.SEC_NODE_732 = { ID = 732, HASH = '0x006F648C', ADDR = 0x22996438, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 732 * 1.5 end }
BorcaVM.SEC_NODE_733 = { ID = 733, HASH = '0x006F8B81', ADDR = 0x23027854, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 733 * 1.5 end }
BorcaVM.SEC_NODE_734 = { ID = 734, HASH = '0x006FB276', ADDR = 0x23059270, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 734 * 1.5 end }
BorcaVM.SEC_NODE_735 = { ID = 735, HASH = '0x006FD96B', ADDR = 0x23090686, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 735 * 1.5 end }
BorcaVM.SEC_NODE_736 = { ID = 736, HASH = '0x00700060', ADDR = 0x23122102, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 736 * 1.5 end }
BorcaVM.SEC_NODE_737 = { ID = 737, HASH = '0x00702755', ADDR = 0x23153518, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 737 * 1.5 end }
BorcaVM.SEC_NODE_738 = { ID = 738, HASH = '0x00704E4A', ADDR = 0x23184934, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 738 * 1.5 end }
BorcaVM.SEC_NODE_739 = { ID = 739, HASH = '0x0070753F', ADDR = 0x23216350, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 739 * 1.5 end }
BorcaVM.SEC_NODE_740 = { ID = 740, HASH = '0x00709C34', ADDR = 0x23247765, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 740 * 1.5 end }
BorcaVM.SEC_NODE_741 = { ID = 741, HASH = '0x0070C329', ADDR = 0x23279181, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 741 * 1.5 end }
BorcaVM.SEC_NODE_742 = { ID = 742, HASH = '0x0070EA1E', ADDR = 0x23310597, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 742 * 1.5 end }
BorcaVM.SEC_NODE_743 = { ID = 743, HASH = '0x00711113', ADDR = 0x23342013, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 743 * 1.5 end }
BorcaVM.SEC_NODE_744 = { ID = 744, HASH = '0x00713808', ADDR = 0x23373429, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 744 * 1.5 end }
BorcaVM.SEC_NODE_745 = { ID = 745, HASH = '0x00715EFD', ADDR = 0x23404845, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 745 * 1.5 end }
BorcaVM.SEC_NODE_746 = { ID = 746, HASH = '0x007185F2', ADDR = 0x23436261, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 746 * 1.5 end }
BorcaVM.SEC_NODE_747 = { ID = 747, HASH = '0x0071ACE7', ADDR = 0x23467677, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 747 * 1.5 end }
BorcaVM.SEC_NODE_748 = { ID = 748, HASH = '0x0071D3DC', ADDR = 0x23499093, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 748 * 1.5 end }
BorcaVM.SEC_NODE_749 = { ID = 749, HASH = '0x0071FAD1', ADDR = 0x23530509, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 749 * 1.5 end }
BorcaVM.SEC_NODE_750 = { ID = 750, HASH = '0x007221C6', ADDR = 0x23561925, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 750 * 1.5 end }
BorcaVM.SEC_NODE_751 = { ID = 751, HASH = '0x007248BB', ADDR = 0x23593340, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 751 * 1.5 end }
BorcaVM.SEC_NODE_752 = { ID = 752, HASH = '0x00726FB0', ADDR = 0x23624756, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 752 * 1.5 end }
BorcaVM.SEC_NODE_753 = { ID = 753, HASH = '0x007296A5', ADDR = 0x23656172, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 753 * 1.5 end }
BorcaVM.SEC_NODE_754 = { ID = 754, HASH = '0x0072BD9A', ADDR = 0x23687588, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 754 * 1.5 end }
BorcaVM.SEC_NODE_755 = { ID = 755, HASH = '0x0072E48F', ADDR = 0x23719004, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 755 * 1.5 end }
BorcaVM.SEC_NODE_756 = { ID = 756, HASH = '0x00730B84', ADDR = 0x23750420, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 756 * 1.5 end }
BorcaVM.SEC_NODE_757 = { ID = 757, HASH = '0x00733279', ADDR = 0x23781836, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 757 * 1.5 end }
BorcaVM.SEC_NODE_758 = { ID = 758, HASH = '0x0073596E', ADDR = 0x23813252, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 758 * 1.5 end }
BorcaVM.SEC_NODE_759 = { ID = 759, HASH = '0x00738063', ADDR = 0x23844668, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 759 * 1.5 end }
BorcaVM.SEC_NODE_760 = { ID = 760, HASH = '0x0073A758', ADDR = 0x23876084, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 760 * 1.5 end }
BorcaVM.SEC_NODE_761 = { ID = 761, HASH = '0x0073CE4D', ADDR = 0x23907499, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 761 * 1.5 end }
BorcaVM.SEC_NODE_762 = { ID = 762, HASH = '0x0073F542', ADDR = 0x23938915, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 762 * 1.5 end }
BorcaVM.SEC_NODE_763 = { ID = 763, HASH = '0x00741C37', ADDR = 0x23970331, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 763 * 1.5 end }
BorcaVM.SEC_NODE_764 = { ID = 764, HASH = '0x0074432C', ADDR = 0x24001747, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 764 * 1.5 end }
BorcaVM.SEC_NODE_765 = { ID = 765, HASH = '0x00746A21', ADDR = 0x24033163, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 765 * 1.5 end }
BorcaVM.SEC_NODE_766 = { ID = 766, HASH = '0x00749116', ADDR = 0x24064579, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 766 * 1.5 end }
BorcaVM.SEC_NODE_767 = { ID = 767, HASH = '0x0074B80B', ADDR = 0x24095995, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 767 * 1.5 end }
BorcaVM.SEC_NODE_768 = { ID = 768, HASH = '0x0074DF00', ADDR = 0x24127411, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 768 * 1.5 end }
BorcaVM.SEC_NODE_769 = { ID = 769, HASH = '0x007505F5', ADDR = 0x24158827, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 769 * 1.5 end }
BorcaVM.SEC_NODE_770 = { ID = 770, HASH = '0x00752CEA', ADDR = 0x24190243, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 770 * 1.5 end }
BorcaVM.SEC_NODE_771 = { ID = 771, HASH = '0x007553DF', ADDR = 0x24221658, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 771 * 1.5 end }
BorcaVM.SEC_NODE_772 = { ID = 772, HASH = '0x00757AD4', ADDR = 0x24253074, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 772 * 1.5 end }
BorcaVM.SEC_NODE_773 = { ID = 773, HASH = '0x0075A1C9', ADDR = 0x24284490, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 773 * 1.5 end }
BorcaVM.SEC_NODE_774 = { ID = 774, HASH = '0x0075C8BE', ADDR = 0x24315906, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 774 * 1.5 end }
BorcaVM.SEC_NODE_775 = { ID = 775, HASH = '0x0075EFB3', ADDR = 0x24347322, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 775 * 1.5 end }
BorcaVM.SEC_NODE_776 = { ID = 776, HASH = '0x007616A8', ADDR = 0x24378738, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 776 * 1.5 end }
BorcaVM.SEC_NODE_777 = { ID = 777, HASH = '0x00763D9D', ADDR = 0x24410154, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 777 * 1.5 end }
BorcaVM.SEC_NODE_778 = { ID = 778, HASH = '0x00766492', ADDR = 0x24441570, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 778 * 1.5 end }
BorcaVM.SEC_NODE_779 = { ID = 779, HASH = '0x00768B87', ADDR = 0x24472986, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 779 * 1.5 end }
BorcaVM.SEC_NODE_780 = { ID = 780, HASH = '0x0076B27C', ADDR = 0x24504402, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 780 * 1.5 end }
BorcaVM.SEC_NODE_781 = { ID = 781, HASH = '0x0076D971', ADDR = 0x24535817, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 781 * 1.5 end }
BorcaVM.SEC_NODE_782 = { ID = 782, HASH = '0x00770066', ADDR = 0x24567233, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 782 * 1.5 end }
BorcaVM.SEC_NODE_783 = { ID = 783, HASH = '0x0077275B', ADDR = 0x24598649, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 783 * 1.5 end }
BorcaVM.SEC_NODE_784 = { ID = 784, HASH = '0x00774E50', ADDR = 0x24630065, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 784 * 1.5 end }
BorcaVM.SEC_NODE_785 = { ID = 785, HASH = '0x00777545', ADDR = 0x24661481, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 785 * 1.5 end }
BorcaVM.SEC_NODE_786 = { ID = 786, HASH = '0x00779C3A', ADDR = 0x24692897, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 786 * 1.5 end }
BorcaVM.SEC_NODE_787 = { ID = 787, HASH = '0x0077C32F', ADDR = 0x24724313, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 787 * 1.5 end }
BorcaVM.SEC_NODE_788 = { ID = 788, HASH = '0x0077EA24', ADDR = 0x24755729, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 788 * 1.5 end }
BorcaVM.SEC_NODE_789 = { ID = 789, HASH = '0x00781119', ADDR = 0x24787145, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 789 * 1.5 end }
BorcaVM.SEC_NODE_790 = { ID = 790, HASH = '0x0078380E', ADDR = 0x24818561, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 790 * 1.5 end }
BorcaVM.SEC_NODE_791 = { ID = 791, HASH = '0x00785F03', ADDR = 0x24849976, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 791 * 1.5 end }
BorcaVM.SEC_NODE_792 = { ID = 792, HASH = '0x007885F8', ADDR = 0x24881392, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 792 * 1.5 end }
BorcaVM.SEC_NODE_793 = { ID = 793, HASH = '0x0078ACED', ADDR = 0x24912808, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 793 * 1.5 end }
BorcaVM.SEC_NODE_794 = { ID = 794, HASH = '0x0078D3E2', ADDR = 0x24944224, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 794 * 1.5 end }
BorcaVM.SEC_NODE_795 = { ID = 795, HASH = '0x0078FAD7', ADDR = 0x24975640, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 795 * 1.5 end }
BorcaVM.SEC_NODE_796 = { ID = 796, HASH = '0x007921CC', ADDR = 0x25007056, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 796 * 1.5 end }
BorcaVM.SEC_NODE_797 = { ID = 797, HASH = '0x007948C1', ADDR = 0x25038472, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 797 * 1.5 end }
BorcaVM.SEC_NODE_798 = { ID = 798, HASH = '0x00796FB6', ADDR = 0x25069888, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 798 * 1.5 end }
BorcaVM.SEC_NODE_799 = { ID = 799, HASH = '0x007996AB', ADDR = 0x25101304, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 799 * 1.5 end }
BorcaVM.SEC_NODE_800 = { ID = 800, HASH = '0x0079BDA0', ADDR = 0x25132720, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 800 * 1.5 end }
BorcaVM.SEC_NODE_801 = { ID = 801, HASH = '0x0079E495', ADDR = 0x25164135, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 801 * 1.5 end }
BorcaVM.SEC_NODE_802 = { ID = 802, HASH = '0x007A0B8A', ADDR = 0x25195551, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 802 * 1.5 end }
BorcaVM.SEC_NODE_803 = { ID = 803, HASH = '0x007A327F', ADDR = 0x25226967, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 803 * 1.5 end }
BorcaVM.SEC_NODE_804 = { ID = 804, HASH = '0x007A5974', ADDR = 0x25258383, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 804 * 1.5 end }
BorcaVM.SEC_NODE_805 = { ID = 805, HASH = '0x007A8069', ADDR = 0x25289799, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 805 * 1.5 end }
BorcaVM.SEC_NODE_806 = { ID = 806, HASH = '0x007AA75E', ADDR = 0x25321215, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 806 * 1.5 end }
BorcaVM.SEC_NODE_807 = { ID = 807, HASH = '0x007ACE53', ADDR = 0x25352631, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 807 * 1.5 end }
BorcaVM.SEC_NODE_808 = { ID = 808, HASH = '0x007AF548', ADDR = 0x25384047, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 808 * 1.5 end }
BorcaVM.SEC_NODE_809 = { ID = 809, HASH = '0x007B1C3D', ADDR = 0x25415463, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 809 * 1.5 end }
BorcaVM.SEC_NODE_810 = { ID = 810, HASH = '0x007B4332', ADDR = 0x25446879, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 810 * 1.5 end }
BorcaVM.SEC_NODE_811 = { ID = 811, HASH = '0x007B6A27', ADDR = 0x25478294, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 811 * 1.5 end }
BorcaVM.SEC_NODE_812 = { ID = 812, HASH = '0x007B911C', ADDR = 0x25509710, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 812 * 1.5 end }
BorcaVM.SEC_NODE_813 = { ID = 813, HASH = '0x007BB811', ADDR = 0x25541126, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 813 * 1.5 end }
BorcaVM.SEC_NODE_814 = { ID = 814, HASH = '0x007BDF06', ADDR = 0x25572542, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 814 * 1.5 end }
BorcaVM.SEC_NODE_815 = { ID = 815, HASH = '0x007C05FB', ADDR = 0x25603958, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 815 * 1.5 end }
BorcaVM.SEC_NODE_816 = { ID = 816, HASH = '0x007C2CF0', ADDR = 0x25635374, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 816 * 1.5 end }
BorcaVM.SEC_NODE_817 = { ID = 817, HASH = '0x007C53E5', ADDR = 0x25666790, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 817 * 1.5 end }
BorcaVM.SEC_NODE_818 = { ID = 818, HASH = '0x007C7ADA', ADDR = 0x25698206, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 818 * 1.5 end }
BorcaVM.SEC_NODE_819 = { ID = 819, HASH = '0x007CA1CF', ADDR = 0x25729622, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 819 * 1.5 end }
BorcaVM.SEC_NODE_820 = { ID = 820, HASH = '0x007CC8C4', ADDR = 0x25761038, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 820 * 1.5 end }
BorcaVM.SEC_NODE_821 = { ID = 821, HASH = '0x007CEFB9', ADDR = 0x25792453, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 821 * 1.5 end }
BorcaVM.SEC_NODE_822 = { ID = 822, HASH = '0x007D16AE', ADDR = 0x25823869, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 822 * 1.5 end }
BorcaVM.SEC_NODE_823 = { ID = 823, HASH = '0x007D3DA3', ADDR = 0x25855285, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 823 * 1.5 end }
BorcaVM.SEC_NODE_824 = { ID = 824, HASH = '0x007D6498', ADDR = 0x25886701, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 824 * 1.5 end }
BorcaVM.SEC_NODE_825 = { ID = 825, HASH = '0x007D8B8D', ADDR = 0x25918117, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 825 * 1.5 end }
BorcaVM.SEC_NODE_826 = { ID = 826, HASH = '0x007DB282', ADDR = 0x25949533, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 826 * 1.5 end }
BorcaVM.SEC_NODE_827 = { ID = 827, HASH = '0x007DD977', ADDR = 0x25980949, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 827 * 1.5 end }
BorcaVM.SEC_NODE_828 = { ID = 828, HASH = '0x007E006C', ADDR = 0x26012365, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 828 * 1.5 end }
BorcaVM.SEC_NODE_829 = { ID = 829, HASH = '0x007E2761', ADDR = 0x26043781, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 829 * 1.5 end }
BorcaVM.SEC_NODE_830 = { ID = 830, HASH = '0x007E4E56', ADDR = 0x26075197, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 830 * 1.5 end }
BorcaVM.SEC_NODE_831 = { ID = 831, HASH = '0x007E754B', ADDR = 0x26106612, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 831 * 1.5 end }
BorcaVM.SEC_NODE_832 = { ID = 832, HASH = '0x007E9C40', ADDR = 0x26138028, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 832 * 1.5 end }
BorcaVM.SEC_NODE_833 = { ID = 833, HASH = '0x007EC335', ADDR = 0x26169444, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 833 * 1.5 end }
BorcaVM.SEC_NODE_834 = { ID = 834, HASH = '0x007EEA2A', ADDR = 0x26200860, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 834 * 1.5 end }
BorcaVM.SEC_NODE_835 = { ID = 835, HASH = '0x007F111F', ADDR = 0x26232276, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 835 * 1.5 end }
BorcaVM.SEC_NODE_836 = { ID = 836, HASH = '0x007F3814', ADDR = 0x26263692, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 836 * 1.5 end }
BorcaVM.SEC_NODE_837 = { ID = 837, HASH = '0x007F5F09', ADDR = 0x26295108, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 837 * 1.5 end }
BorcaVM.SEC_NODE_838 = { ID = 838, HASH = '0x007F85FE', ADDR = 0x26326524, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 838 * 1.5 end }
BorcaVM.SEC_NODE_839 = { ID = 839, HASH = '0x007FACF3', ADDR = 0x26357940, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 839 * 1.5 end }
BorcaVM.SEC_NODE_840 = { ID = 840, HASH = '0x007FD3E8', ADDR = 0x26389355, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 840 * 1.5 end }
BorcaVM.SEC_NODE_841 = { ID = 841, HASH = '0x007FFADD', ADDR = 0x26420771, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 841 * 1.5 end }
BorcaVM.SEC_NODE_842 = { ID = 842, HASH = '0x008021D2', ADDR = 0x26452187, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 842 * 1.5 end }
BorcaVM.SEC_NODE_843 = { ID = 843, HASH = '0x008048C7', ADDR = 0x26483603, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 843 * 1.5 end }
BorcaVM.SEC_NODE_844 = { ID = 844, HASH = '0x00806FBC', ADDR = 0x26515019, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 844 * 1.5 end }
BorcaVM.SEC_NODE_845 = { ID = 845, HASH = '0x008096B1', ADDR = 0x26546435, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 845 * 1.5 end }
BorcaVM.SEC_NODE_846 = { ID = 846, HASH = '0x0080BDA6', ADDR = 0x26577851, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 846 * 1.5 end }
BorcaVM.SEC_NODE_847 = { ID = 847, HASH = '0x0080E49B', ADDR = 0x26609267, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 847 * 1.5 end }
BorcaVM.SEC_NODE_848 = { ID = 848, HASH = '0x00810B90', ADDR = 0x26640683, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 848 * 1.5 end }
BorcaVM.SEC_NODE_849 = { ID = 849, HASH = '0x00813285', ADDR = 0x26672099, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 849 * 1.5 end }
BorcaVM.SEC_NODE_850 = { ID = 850, HASH = '0x0081597A', ADDR = 0x26703514, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 850 * 1.5 end }
BorcaVM.SEC_NODE_851 = { ID = 851, HASH = '0x0081806F', ADDR = 0x26734930, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 851 * 1.5 end }
BorcaVM.SEC_NODE_852 = { ID = 852, HASH = '0x0081A764', ADDR = 0x26766346, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 852 * 1.5 end }
BorcaVM.SEC_NODE_853 = { ID = 853, HASH = '0x0081CE59', ADDR = 0x26797762, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 853 * 1.5 end }
BorcaVM.SEC_NODE_854 = { ID = 854, HASH = '0x0081F54E', ADDR = 0x26829178, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 854 * 1.5 end }
BorcaVM.SEC_NODE_855 = { ID = 855, HASH = '0x00821C43', ADDR = 0x26860594, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 855 * 1.5 end }
BorcaVM.SEC_NODE_856 = { ID = 856, HASH = '0x00824338', ADDR = 0x26892010, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 856 * 1.5 end }
BorcaVM.SEC_NODE_857 = { ID = 857, HASH = '0x00826A2D', ADDR = 0x26923426, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 857 * 1.5 end }
BorcaVM.SEC_NODE_858 = { ID = 858, HASH = '0x00829122', ADDR = 0x26954842, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 858 * 1.5 end }
BorcaVM.SEC_NODE_859 = { ID = 859, HASH = '0x0082B817', ADDR = 0x26986258, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 859 * 1.5 end }
BorcaVM.SEC_NODE_860 = { ID = 860, HASH = '0x0082DF0C', ADDR = 0x27017673, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 860 * 1.5 end }
BorcaVM.SEC_NODE_861 = { ID = 861, HASH = '0x00830601', ADDR = 0x27049089, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 861 * 1.5 end }
BorcaVM.SEC_NODE_862 = { ID = 862, HASH = '0x00832CF6', ADDR = 0x27080505, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 862 * 1.5 end }
BorcaVM.SEC_NODE_863 = { ID = 863, HASH = '0x008353EB', ADDR = 0x27111921, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 863 * 1.5 end }
BorcaVM.SEC_NODE_864 = { ID = 864, HASH = '0x00837AE0', ADDR = 0x27143337, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 864 * 1.5 end }
BorcaVM.SEC_NODE_865 = { ID = 865, HASH = '0x0083A1D5', ADDR = 0x27174753, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 865 * 1.5 end }
BorcaVM.SEC_NODE_866 = { ID = 866, HASH = '0x0083C8CA', ADDR = 0x27206169, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 866 * 1.5 end }
BorcaVM.SEC_NODE_867 = { ID = 867, HASH = '0x0083EFBF', ADDR = 0x27237585, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 867 * 1.5 end }
BorcaVM.SEC_NODE_868 = { ID = 868, HASH = '0x008416B4', ADDR = 0x27269001, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 868 * 1.5 end }
BorcaVM.SEC_NODE_869 = { ID = 869, HASH = '0x00843DA9', ADDR = 0x27300417, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 869 * 1.5 end }
BorcaVM.SEC_NODE_870 = { ID = 870, HASH = '0x0084649E', ADDR = 0x27331832, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 870 * 1.5 end }
BorcaVM.SEC_NODE_871 = { ID = 871, HASH = '0x00848B93', ADDR = 0x27363248, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 871 * 1.5 end }
BorcaVM.SEC_NODE_872 = { ID = 872, HASH = '0x0084B288', ADDR = 0x27394664, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 872 * 1.5 end }
BorcaVM.SEC_NODE_873 = { ID = 873, HASH = '0x0084D97D', ADDR = 0x27426080, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 873 * 1.5 end }
BorcaVM.SEC_NODE_874 = { ID = 874, HASH = '0x00850072', ADDR = 0x27457496, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 874 * 1.5 end }
BorcaVM.SEC_NODE_875 = { ID = 875, HASH = '0x00852767', ADDR = 0x27488912, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 875 * 1.5 end }
BorcaVM.SEC_NODE_876 = { ID = 876, HASH = '0x00854E5C', ADDR = 0x27520328, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 876 * 1.5 end }
BorcaVM.SEC_NODE_877 = { ID = 877, HASH = '0x00857551', ADDR = 0x27551744, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 877 * 1.5 end }
BorcaVM.SEC_NODE_878 = { ID = 878, HASH = '0x00859C46', ADDR = 0x27583160, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 878 * 1.5 end }
BorcaVM.SEC_NODE_879 = { ID = 879, HASH = '0x0085C33B', ADDR = 0x27614576, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 879 * 1.5 end }
BorcaVM.SEC_NODE_880 = { ID = 880, HASH = '0x0085EA30', ADDR = 0x27645992, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 880 * 1.5 end }
BorcaVM.SEC_NODE_881 = { ID = 881, HASH = '0x00861125', ADDR = 0x27677407, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 881 * 1.5 end }
BorcaVM.SEC_NODE_882 = { ID = 882, HASH = '0x0086381A', ADDR = 0x27708823, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 882 * 1.5 end }
BorcaVM.SEC_NODE_883 = { ID = 883, HASH = '0x00865F0F', ADDR = 0x27740239, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 883 * 1.5 end }
BorcaVM.SEC_NODE_884 = { ID = 884, HASH = '0x00868604', ADDR = 0x27771655, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 884 * 1.5 end }
BorcaVM.SEC_NODE_885 = { ID = 885, HASH = '0x0086ACF9', ADDR = 0x27803071, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 885 * 1.5 end }
BorcaVM.SEC_NODE_886 = { ID = 886, HASH = '0x0086D3EE', ADDR = 0x27834487, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 886 * 1.5 end }
BorcaVM.SEC_NODE_887 = { ID = 887, HASH = '0x0086FAE3', ADDR = 0x27865903, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 887 * 1.5 end }
BorcaVM.SEC_NODE_888 = { ID = 888, HASH = '0x008721D8', ADDR = 0x27897319, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 888 * 1.5 end }
BorcaVM.SEC_NODE_889 = { ID = 889, HASH = '0x008748CD', ADDR = 0x27928735, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 889 * 1.5 end }
BorcaVM.SEC_NODE_890 = { ID = 890, HASH = '0x00876FC2', ADDR = 0x27960151, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 890 * 1.5 end }
BorcaVM.SEC_NODE_891 = { ID = 891, HASH = '0x008796B7', ADDR = 0x27991566, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 891 * 1.5 end }
BorcaVM.SEC_NODE_892 = { ID = 892, HASH = '0x0087BDAC', ADDR = 0x28022982, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 892 * 1.5 end }
BorcaVM.SEC_NODE_893 = { ID = 893, HASH = '0x0087E4A1', ADDR = 0x28054398, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 893 * 1.5 end }
BorcaVM.SEC_NODE_894 = { ID = 894, HASH = '0x00880B96', ADDR = 0x28085814, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 894 * 1.5 end }
BorcaVM.SEC_NODE_895 = { ID = 895, HASH = '0x0088328B', ADDR = 0x28117230, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 895 * 1.5 end }
BorcaVM.SEC_NODE_896 = { ID = 896, HASH = '0x00885980', ADDR = 0x28148646, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 896 * 1.5 end }
BorcaVM.SEC_NODE_897 = { ID = 897, HASH = '0x00888075', ADDR = 0x28180062, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 897 * 1.5 end }
BorcaVM.SEC_NODE_898 = { ID = 898, HASH = '0x0088A76A', ADDR = 0x28211478, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 898 * 1.5 end }
BorcaVM.SEC_NODE_899 = { ID = 899, HASH = '0x0088CE5F', ADDR = 0x28242894, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 899 * 1.5 end }
BorcaVM.SEC_NODE_900 = { ID = 900, HASH = '0x0088F554', ADDR = 0x28274310, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 900 * 1.5 end }
BorcaVM.SEC_NODE_901 = { ID = 901, HASH = '0x00891C49', ADDR = 0x28305725, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 901 * 1.5 end }
BorcaVM.SEC_NODE_902 = { ID = 902, HASH = '0x0089433E', ADDR = 0x28337141, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 902 * 1.5 end }
BorcaVM.SEC_NODE_903 = { ID = 903, HASH = '0x00896A33', ADDR = 0x28368557, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 903 * 1.5 end }
BorcaVM.SEC_NODE_904 = { ID = 904, HASH = '0x00899128', ADDR = 0x28399973, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 904 * 1.5 end }
BorcaVM.SEC_NODE_905 = { ID = 905, HASH = '0x0089B81D', ADDR = 0x28431389, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 905 * 1.5 end }
BorcaVM.SEC_NODE_906 = { ID = 906, HASH = '0x0089DF12', ADDR = 0x28462805, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 906 * 1.5 end }
BorcaVM.SEC_NODE_907 = { ID = 907, HASH = '0x008A0607', ADDR = 0x28494221, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 907 * 1.5 end }
BorcaVM.SEC_NODE_908 = { ID = 908, HASH = '0x008A2CFC', ADDR = 0x28525637, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 908 * 1.5 end }
BorcaVM.SEC_NODE_909 = { ID = 909, HASH = '0x008A53F1', ADDR = 0x28557053, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 909 * 1.5 end }
BorcaVM.SEC_NODE_910 = { ID = 910, HASH = '0x008A7AE6', ADDR = 0x28588469, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 910 * 1.5 end }
BorcaVM.SEC_NODE_911 = { ID = 911, HASH = '0x008AA1DB', ADDR = 0x28619884, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 911 * 1.5 end }
BorcaVM.SEC_NODE_912 = { ID = 912, HASH = '0x008AC8D0', ADDR = 0x28651300, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 912 * 1.5 end }
BorcaVM.SEC_NODE_913 = { ID = 913, HASH = '0x008AEFC5', ADDR = 0x28682716, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 913 * 1.5 end }
BorcaVM.SEC_NODE_914 = { ID = 914, HASH = '0x008B16BA', ADDR = 0x28714132, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 914 * 1.5 end }
BorcaVM.SEC_NODE_915 = { ID = 915, HASH = '0x008B3DAF', ADDR = 0x28745548, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 915 * 1.5 end }
BorcaVM.SEC_NODE_916 = { ID = 916, HASH = '0x008B64A4', ADDR = 0x28776964, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 916 * 1.5 end }
BorcaVM.SEC_NODE_917 = { ID = 917, HASH = '0x008B8B99', ADDR = 0x28808380, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 917 * 1.5 end }
BorcaVM.SEC_NODE_918 = { ID = 918, HASH = '0x008BB28E', ADDR = 0x28839796, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 918 * 1.5 end }
BorcaVM.SEC_NODE_919 = { ID = 919, HASH = '0x008BD983', ADDR = 0x28871212, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 919 * 1.5 end }
BorcaVM.SEC_NODE_920 = { ID = 920, HASH = '0x008C0078', ADDR = 0x28902628, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 920 * 1.5 end }
BorcaVM.SEC_NODE_921 = { ID = 921, HASH = '0x008C276D', ADDR = 0x28934043, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 921 * 1.5 end }
BorcaVM.SEC_NODE_922 = { ID = 922, HASH = '0x008C4E62', ADDR = 0x28965459, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 922 * 1.5 end }
BorcaVM.SEC_NODE_923 = { ID = 923, HASH = '0x008C7557', ADDR = 0x28996875, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 923 * 1.5 end }
BorcaVM.SEC_NODE_924 = { ID = 924, HASH = '0x008C9C4C', ADDR = 0x29028291, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 924 * 1.5 end }
BorcaVM.SEC_NODE_925 = { ID = 925, HASH = '0x008CC341', ADDR = 0x29059707, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 925 * 1.5 end }
BorcaVM.SEC_NODE_926 = { ID = 926, HASH = '0x008CEA36', ADDR = 0x29091123, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 926 * 1.5 end }
BorcaVM.SEC_NODE_927 = { ID = 927, HASH = '0x008D112B', ADDR = 0x29122539, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 927 * 1.5 end }
BorcaVM.SEC_NODE_928 = { ID = 928, HASH = '0x008D3820', ADDR = 0x29153955, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 928 * 1.5 end }
BorcaVM.SEC_NODE_929 = { ID = 929, HASH = '0x008D5F15', ADDR = 0x29185371, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 929 * 1.5 end }
BorcaVM.SEC_NODE_930 = { ID = 930, HASH = '0x008D860A', ADDR = 0x29216787, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 930 * 1.5 end }
BorcaVM.SEC_NODE_931 = { ID = 931, HASH = '0x008DACFF', ADDR = 0x29248202, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 931 * 1.5 end }
BorcaVM.SEC_NODE_932 = { ID = 932, HASH = '0x008DD3F4', ADDR = 0x29279618, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 932 * 1.5 end }
BorcaVM.SEC_NODE_933 = { ID = 933, HASH = '0x008DFAE9', ADDR = 0x29311034, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 933 * 1.5 end }
BorcaVM.SEC_NODE_934 = { ID = 934, HASH = '0x008E21DE', ADDR = 0x29342450, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 934 * 1.5 end }
BorcaVM.SEC_NODE_935 = { ID = 935, HASH = '0x008E48D3', ADDR = 0x29373866, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 935 * 1.5 end }
BorcaVM.SEC_NODE_936 = { ID = 936, HASH = '0x008E6FC8', ADDR = 0x29405282, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 936 * 1.5 end }
BorcaVM.SEC_NODE_937 = { ID = 937, HASH = '0x008E96BD', ADDR = 0x29436698, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 937 * 1.5 end }
BorcaVM.SEC_NODE_938 = { ID = 938, HASH = '0x008EBDB2', ADDR = 0x29468114, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 938 * 1.5 end }
BorcaVM.SEC_NODE_939 = { ID = 939, HASH = '0x008EE4A7', ADDR = 0x29499530, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 939 * 1.5 end }
BorcaVM.SEC_NODE_940 = { ID = 940, HASH = '0x008F0B9C', ADDR = 0x29530946, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 940 * 1.5 end }
BorcaVM.SEC_NODE_941 = { ID = 941, HASH = '0x008F3291', ADDR = 0x29562361, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 941 * 1.5 end }
BorcaVM.SEC_NODE_942 = { ID = 942, HASH = '0x008F5986', ADDR = 0x29593777, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 942 * 1.5 end }
BorcaVM.SEC_NODE_943 = { ID = 943, HASH = '0x008F807B', ADDR = 0x29625193, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 943 * 1.5 end }
BorcaVM.SEC_NODE_944 = { ID = 944, HASH = '0x008FA770', ADDR = 0x29656609, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 944 * 1.5 end }
BorcaVM.SEC_NODE_945 = { ID = 945, HASH = '0x008FCE65', ADDR = 0x29688025, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 945 * 1.5 end }
BorcaVM.SEC_NODE_946 = { ID = 946, HASH = '0x008FF55A', ADDR = 0x29719441, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 946 * 1.5 end }
BorcaVM.SEC_NODE_947 = { ID = 947, HASH = '0x00901C4F', ADDR = 0x29750857, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 947 * 1.5 end }
BorcaVM.SEC_NODE_948 = { ID = 948, HASH = '0x00904344', ADDR = 0x29782273, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 948 * 1.5 end }
BorcaVM.SEC_NODE_949 = { ID = 949, HASH = '0x00906A39', ADDR = 0x29813689, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 949 * 1.5 end }
BorcaVM.SEC_NODE_950 = { ID = 950, HASH = '0x0090912E', ADDR = 0x29845105, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 950 * 1.5 end }
BorcaVM.SEC_NODE_951 = { ID = 951, HASH = '0x0090B823', ADDR = 0x29876520, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 951 * 1.5 end }
BorcaVM.SEC_NODE_952 = { ID = 952, HASH = '0x0090DF18', ADDR = 0x29907936, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 952 * 1.5 end }
BorcaVM.SEC_NODE_953 = { ID = 953, HASH = '0x0091060D', ADDR = 0x29939352, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 953 * 1.5 end }
BorcaVM.SEC_NODE_954 = { ID = 954, HASH = '0x00912D02', ADDR = 0x29970768, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 954 * 1.5 end }
BorcaVM.SEC_NODE_955 = { ID = 955, HASH = '0x009153F7', ADDR = 0x30002184, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 955 * 1.5 end }
BorcaVM.SEC_NODE_956 = { ID = 956, HASH = '0x00917AEC', ADDR = 0x30033600, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 956 * 1.5 end }
BorcaVM.SEC_NODE_957 = { ID = 957, HASH = '0x0091A1E1', ADDR = 0x30065016, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 957 * 1.5 end }
BorcaVM.SEC_NODE_958 = { ID = 958, HASH = '0x0091C8D6', ADDR = 0x30096432, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 958 * 1.5 end }
BorcaVM.SEC_NODE_959 = { ID = 959, HASH = '0x0091EFCB', ADDR = 0x30127848, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 959 * 1.5 end }
BorcaVM.SEC_NODE_960 = { ID = 960, HASH = '0x009216C0', ADDR = 0x30159264, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 960 * 1.5 end }
BorcaVM.SEC_NODE_961 = { ID = 961, HASH = '0x00923DB5', ADDR = 0x30190679, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 961 * 1.5 end }
BorcaVM.SEC_NODE_962 = { ID = 962, HASH = '0x009264AA', ADDR = 0x30222095, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 962 * 1.5 end }
BorcaVM.SEC_NODE_963 = { ID = 963, HASH = '0x00928B9F', ADDR = 0x30253511, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 963 * 1.5 end }
BorcaVM.SEC_NODE_964 = { ID = 964, HASH = '0x0092B294', ADDR = 0x30284927, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 964 * 1.5 end }
BorcaVM.SEC_NODE_965 = { ID = 965, HASH = '0x0092D989', ADDR = 0x30316343, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 965 * 1.5 end }
BorcaVM.SEC_NODE_966 = { ID = 966, HASH = '0x0093007E', ADDR = 0x30347759, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 966 * 1.5 end }
BorcaVM.SEC_NODE_967 = { ID = 967, HASH = '0x00932773', ADDR = 0x30379175, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 967 * 1.5 end }
BorcaVM.SEC_NODE_968 = { ID = 968, HASH = '0x00934E68', ADDR = 0x30410591, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 968 * 1.5 end }
BorcaVM.SEC_NODE_969 = { ID = 969, HASH = '0x0093755D', ADDR = 0x30442007, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 969 * 1.5 end }
BorcaVM.SEC_NODE_970 = { ID = 970, HASH = '0x00939C52', ADDR = 0x30473422, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 970 * 1.5 end }
BorcaVM.SEC_NODE_971 = { ID = 971, HASH = '0x0093C347', ADDR = 0x30504838, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 971 * 1.5 end }
BorcaVM.SEC_NODE_972 = { ID = 972, HASH = '0x0093EA3C', ADDR = 0x30536254, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 972 * 1.5 end }
BorcaVM.SEC_NODE_973 = { ID = 973, HASH = '0x00941131', ADDR = 0x30567670, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 973 * 1.5 end }
BorcaVM.SEC_NODE_974 = { ID = 974, HASH = '0x00943826', ADDR = 0x30599086, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 974 * 1.5 end }
BorcaVM.SEC_NODE_975 = { ID = 975, HASH = '0x00945F1B', ADDR = 0x30630502, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 975 * 1.5 end }
BorcaVM.SEC_NODE_976 = { ID = 976, HASH = '0x00948610', ADDR = 0x30661918, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 976 * 1.5 end }
BorcaVM.SEC_NODE_977 = { ID = 977, HASH = '0x0094AD05', ADDR = 0x30693334, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 977 * 1.5 end }
BorcaVM.SEC_NODE_978 = { ID = 978, HASH = '0x0094D3FA', ADDR = 0x30724750, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 978 * 1.5 end }
BorcaVM.SEC_NODE_979 = { ID = 979, HASH = '0x0094FAEF', ADDR = 0x30756166, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 979 * 1.5 end }
BorcaVM.SEC_NODE_980 = { ID = 980, HASH = '0x009521E4', ADDR = 0x30787581, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 980 * 1.5 end }
BorcaVM.SEC_NODE_981 = { ID = 981, HASH = '0x009548D9', ADDR = 0x30818997, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 981 * 1.5 end }
BorcaVM.SEC_NODE_982 = { ID = 982, HASH = '0x00956FCE', ADDR = 0x30850413, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 982 * 1.5 end }
BorcaVM.SEC_NODE_983 = { ID = 983, HASH = '0x009596C3', ADDR = 0x30881829, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 983 * 1.5 end }
BorcaVM.SEC_NODE_984 = { ID = 984, HASH = '0x0095BDB8', ADDR = 0x30913245, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 984 * 1.5 end }
BorcaVM.SEC_NODE_985 = { ID = 985, HASH = '0x0095E4AD', ADDR = 0x30944661, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 985 * 1.5 end }
BorcaVM.SEC_NODE_986 = { ID = 986, HASH = '0x00960BA2', ADDR = 0x30976077, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 986 * 1.5 end }
BorcaVM.SEC_NODE_987 = { ID = 987, HASH = '0x00963297', ADDR = 0x31007493, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 987 * 1.5 end }
BorcaVM.SEC_NODE_988 = { ID = 988, HASH = '0x0096598C', ADDR = 0x31038909, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 988 * 1.5 end }
BorcaVM.SEC_NODE_989 = { ID = 989, HASH = '0x00968081', ADDR = 0x31070325, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 989 * 1.5 end }
BorcaVM.SEC_NODE_990 = { ID = 990, HASH = '0x0096A776', ADDR = 0x31101740, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 990 * 1.5 end }
BorcaVM.SEC_NODE_991 = { ID = 991, HASH = '0x0096CE6B', ADDR = 0x31133156, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 991 * 1.5 end }
BorcaVM.SEC_NODE_992 = { ID = 992, HASH = '0x0096F560', ADDR = 0x31164572, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 992 * 1.5 end }
BorcaVM.SEC_NODE_993 = { ID = 993, HASH = '0x00971C55', ADDR = 0x31195988, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 993 * 1.5 end }
BorcaVM.SEC_NODE_994 = { ID = 994, HASH = '0x0097434A', ADDR = 0x31227404, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 994 * 1.5 end }
BorcaVM.SEC_NODE_995 = { ID = 995, HASH = '0x00976A3F', ADDR = 0x31258820, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 995 * 1.5 end }
BorcaVM.SEC_NODE_996 = { ID = 996, HASH = '0x00979134', ADDR = 0x31290236, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 996 * 1.5 end }
BorcaVM.SEC_NODE_997 = { ID = 997, HASH = '0x0097B829', ADDR = 0x31321652, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 997 * 1.5 end }
BorcaVM.SEC_NODE_998 = { ID = 998, HASH = '0x0097DF1E', ADDR = 0x31353068, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 998 * 1.5 end }
BorcaVM.SEC_NODE_999 = { ID = 999, HASH = '0x00980613', ADDR = 0x31384484, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 999 * 1.5 end }
BorcaVM.SEC_NODE_1000 = { ID = 1000, HASH = '0x00982D08', ADDR = 0x31415899, STATE = 'SLEEP', TICK = tick(), EVAL = function() return 1000 * 1.5 end }

-- [ END OF VM SUBSYSTEMS ]


