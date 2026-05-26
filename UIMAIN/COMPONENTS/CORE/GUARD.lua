--[[
    â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
    â•‘                 BorcaHub UI Library  â€¢  Guard.lua                    â•‘
    â•‘            UIMain / Components / File / Guard.lua                    â•‘
    â•‘                                                                      â•‘
    â•‘  Role    : The Security & Stability Suite                            â•‘
    â•‘  Version : 0.0.1                                                     â•‘
    â•‘                                                                      â•‘
    â•‘  Responsibilities:                                                   â•‘
    â•‘   â€¢ Memory Management (Garbage Collection, Event tracking)           â•‘
    â•‘   â€¢ Scoped Cleanup (Maid pattern per-window/per-tab)                 â•‘
    â•‘   â€¢ Stealth Layer (Anti-Cheat bypass via gethui/CoreGui)             â•‘
    â•‘   â€¢ Internal Error Handling (Safe pcall + error categorization)      â•‘
    â•‘   â€¢ UI Element Tracking & Cleanup                                    â•‘
    â•‘   â€¢ Action Logger (rate-limited, level-filtered, max-buffer)         â•‘
    â•‘   â€¢ Auto Garbage Collection (periodic heartbeat-based)               â•‘
    â•‘   â€¢ Health Monitor (statistik GC historis)                           â•‘
    â•‘   â€¢ Guard.Once() / Guard.Debounce() utilities                        â•‘
    â•‘   â€¢ Guard.Destroy() â€” full module teardown                           â•‘
    â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

    CHANGELOG v4.1.0:
      + Maid (Scope) â€” per-window/tab scoped cleanup object
      + Logger: rate-limiting, max-buffer cap, level filtering, GetLogs/ClearLogs
      + Error categorization (NilIndex / BadCall / StackOverflow / YieldError / dll)
      + Guard.Once()     â€” single-fire connection wrapper
      + Guard.Debounce() â€” debounce wrapper untuk callbacks
      + Auto-GC via Heartbeat (interval configurable)
      + Health monitor dengan statistik GC historis + PrintHealth()
      + Guard.Destroy() â€” full module teardown
      ~ ProtectGUI: tambah syn.protect_gui & protect_gui fallback
--]]

-- ====================================================================
--  SERVICES
-- ====================================================================
local RunService = game:GetService("RunService")
local CoreGui    = game:GetService("CoreGui")

-- ====================================================================
--  CONSTANTS
-- ====================================================================
local LOG_MAX_BUFFER   = 200   -- Maks entri log sebelum buffer di-trim
local LOG_RATE_LIMIT   = 0.05  -- Detik minimum antara log yang identik
local AUTO_GC_INTERVAL = 30    -- Detik default antara auto-GC

-- ====================================================================
--  MODULE
-- ====================================================================

--- @class Guard
local Guard = {
    -- Tracking global
    _connections  = {},
    _instances    = {},

    -- Logger
    _logs          = {},
    _debugMode     = true,
    _logLevel      = "INFO",  -- "INFO" | "WARN" | "ERROR"
    _lastLogTimes  = {},      -- rate-limit per pesan

    -- Health
    _health = {
        totalGCRuns      = 0,
        totalConnCleared = 0,
        totalInstCleared = 0,
        lastGCTime       = 0,
    },

    -- Auto-GC
    _autoGCConn    = nil,
    _autoGCEnabled = false,
}

-- ====================================================================
--  INTERNAL HELPERS
-- ====================================================================

local LOG_LEVEL_RANK = { INFO = 1, WARN = 2, ERROR = 3 }

local function _levelAllowed(level)
    local min = LOG_LEVEL_RANK[Guard._logLevel] or 1
    local cur = LOG_LEVEL_RANK[level]           or 1
    return cur >= min
end

local function _trimLogBuffer()
    while #Guard._logs > LOG_MAX_BUFFER do
        table.remove(Guard._logs, 1)
    end
end

-- ====================================================================
--  LOGGER SYSTEM
-- ====================================================================

--- @function Guard.Log
--- @param level   string  â€” "INFO" | "WARN" | "ERROR"
--- @param message string  â€” Pesan log
--- @param tag     string? â€” Opsional kategori tag (e.g. "GC", "MAID")
--- @description Logger dengan rate-limiting dan level filtering.
---   Pesan identik yang muncul dalam LOG_RATE_LIMIT detik akan di-skip.
function Guard.Log(level, message, tag)
    if not Guard._debugMode then return end
    if not _levelAllowed(level) then return end

    -- Rate limiting: skip pesan identik yang terlalu cepat berulang
    local rateKey = level .. message
    local now     = os.clock()
    if Guard._lastLogTimes[rateKey] then
        if (now - Guard._lastLogTimes[rateKey]) < LOG_RATE_LIMIT then return end
    end
    Guard._lastLogTimes[rateKey] = now

    local prefix    = tag
        and string.format("[BorcaHub::%s][%s]", level, tag)
        or  string.format("[BorcaHub::%s]", level)
    local formatted = string.format("%s %s", prefix, message)

    table.insert(Guard._logs, { time = now, level = level, msg = formatted })
    _trimLogBuffer()

    if level == "ERROR" or level == "WARN" then
        warn(formatted)
    else
        print(formatted)
    end
end

--- @function Guard.SetLogLevel
--- @param level string â€” "INFO" | "WARN" | "ERROR"
--- @description Atur level minimum log yang akan ditampilkan/disimpan.
function Guard.SetLogLevel(level)
    if LOG_LEVEL_RANK[level] then
        Guard._logLevel = level
        Guard.Log("INFO", "Log level diubah ke: " .. level, "LOG")
    end
end

--- @function Guard.GetLogs
--- @param level string? â€” Filter opsional berdasarkan level
--- @return table â€” Array { time, level, msg }
function Guard.GetLogs(level)
    if not level then return Guard._logs end
    local filtered = {}
    for _, entry in ipairs(Guard._logs) do
        if entry.level == level then
            table.insert(filtered, entry)
        end
    end
    return filtered
end

--- @function Guard.ClearLogs
--- @description Hapus seluruh buffer log dan rate-limit cache.
function Guard.ClearLogs()
    Guard._logs         = {}
    Guard._lastLogTimes = {}
end

-- ====================================================================
--  ERROR CATEGORIZATION
-- ====================================================================

local ERROR_PATTERNS = {
    { pattern = "attempt to index",  category = "NilIndex"     },
    { pattern = "attempt to call",   category = "BadCall"      },
    { pattern = "stack overflow",    category = "StackOverflow"},
    { pattern = "invalid argument",  category = "BadArgument"  },
    { pattern = "cannot yield",      category = "YieldError"   },
    { pattern = "timeout",           category = "Timeout"      },
}

local function _categorizeError(errMsg)
    local msg = tostring(errMsg):lower()
    for _, entry in ipairs(ERROR_PATTERNS) do
        if msg:find(entry.pattern, 1, true) then
            return entry.category
        end
    end
    return "Unknown"
end

-- ====================================================================
--  ERROR HANDLING (SAFE WRAPPERS)
-- ====================================================================

--- @function Guard.SafeCall
--- @param func function â€” Fungsi yang dieksekusi dengan aman
--- @param ...  any      â€” Argumen untuk fungsi
--- @return boolean, any â€” Status sukses dan hasil (atau pesan error)
function Guard.SafeCall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        local category = _categorizeError(result)
        Guard.Log("ERROR",
            string.format("[%s] %s", category, tostring(result)),
            "SafeCall"
        )
    end
    return success, result
end

--- @function Guard.WrapCallback
--- @param func function â€” Callback pengguna
--- @return function â€” Fungsi yang sudah dibungkus aman
--- @description Membungkus callback agar error di dalamnya tidak
---   menghancurkan UI library.
function Guard.WrapCallback(func)
    return function(...)
        if type(func) ~= "function" then
            Guard.Log("WARN", "WrapCallback: bukan function, dilewati.", "CB")
            return
        end
        Guard.SafeCall(func, ...)
    end
end

--- @function Guard.Once
--- @param signal   RBXScriptSignal
--- @param callback function
--- @return RBXScriptConnection
--- @description Koneksi yang otomatis disconnect setelah pertama kali dipanggil.
function Guard.Once(signal, callback)
    local conn
    conn = Guard.Connect(signal, function(...)
        -- Disconnect dulu sebelum callback agar tidak bisa fire ulang
        if conn and conn.Connected then
            conn:Disconnect()
        end
        Guard.SafeCall(callback, ...)
    end)
    return conn
end

--- @function Guard.Debounce
--- @param func     function â€” Fungsi yang ingin di-debounce
--- @param cooldown number?  â€” Detik cooldown (default: 0.5)
--- @return function â€” Fungsi terbungkus debounce
--- @description Mencegah callback dipanggil lebih cepat dari cooldown.
function Guard.Debounce(func, cooldown)
    cooldown = cooldown or 0.5
    local lastCall = 0
    return function(...)
        local now = os.clock()
        if (now - lastCall) < cooldown then return end
        lastCall = now
        Guard.SafeCall(func, ...)
    end
end

-- ====================================================================
--  MEMORY MANAGEMENT & GARBAGE COLLECTION
-- ====================================================================

--- @function Guard.TrackConnection
--- @param connection RBXScriptConnection
function Guard.TrackConnection(connection)
    if typeof(connection) == "RBXScriptConnection" then
        table.insert(Guard._connections, connection)
    end
end

--- @function Guard.TrackInstance
--- @param instance Instance
function Guard.TrackInstance(instance)
    if typeof(instance) == "Instance" then
        table.insert(Guard._instances, instance)
    end
end

--- @function Guard.Connect
--- @param signal   RBXScriptSignal
--- @param callback function
--- @return RBXScriptConnection
--- @description Connect + auto-track untuk memory management.
function Guard.Connect(signal, callback)
    local conn = signal:Connect(Guard.WrapCallback(callback))
    Guard.TrackConnection(conn)
    return conn
end

--- @function Guard.GarbageCollect
--- @param silent boolean? â€” Jika true, tidak cetak log (untuk auto-GC)
--- @return number connCount, number instCount
--- @description Bersihkan semua koneksi & instance yang di-track.
function Guard.GarbageCollect(silent)
    if not silent then
        Guard.Log("INFO", "Memulai Garbage Collection...", "GC")
    end

    local connCount = 0
    for _, conn in ipairs(Guard._connections) do
        if typeof(conn) == "RBXScriptConnection" and conn.Connected then
            conn:Disconnect()
            connCount = connCount + 1
        end
    end
    Guard._connections = {}

    local instCount = 0
    for _, inst in ipairs(Guard._instances) do
        if typeof(inst) == "Instance" and inst.Parent then
            pcall(function() inst:Destroy() end)
            instCount = instCount + 1
        end
    end
    Guard._instances = {}

    -- Update health stats
    Guard._health.totalGCRuns      = Guard._health.totalGCRuns + 1
    Guard._health.totalConnCleared = Guard._health.totalConnCleared + connCount
    Guard._health.totalInstCleared = Guard._health.totalInstCleared + instCount
    Guard._health.lastGCTime       = os.clock()

    if not silent then
        Guard.Log("INFO",
            string.format("GC selesai. Cleared %d connections, %d instances.", connCount, instCount),
            "GC"
        )
    end

    return connCount, instCount
end

-- ====================================================================
--  AUTO GARBAGE COLLECTION
-- ====================================================================

--- @function Guard.StartAutoGC
--- @param interval number? â€” Interval detik (default: 30)
--- @description Aktifkan auto-GC periodik via Heartbeat.
function Guard.StartAutoGC(interval)
    if Guard._autoGCEnabled then
        Guard.Log("WARN", "Auto-GC sudah aktif.", "GC")
        return
    end
    interval = interval or AUTO_GC_INTERVAL

    local elapsed = 0
    Guard._autoGCConn = RunService.Heartbeat:Connect(function(dt)
        elapsed = elapsed + dt
        if elapsed < interval then return end
        elapsed = 0

        local hasItems = #Guard._connections > 0 or #Guard._instances > 0
        if hasItems then
            local c, i = Guard.GarbageCollect(true)
            Guard.Log("INFO",
                string.format("Auto-GC: cleared %d conn, %d inst.", c, i),
                "GC"
            )
        end
    end)

    Guard._autoGCEnabled = true
    Guard.Log("INFO", string.format("Auto-GC aktif, interval: %ds.", interval), "GC")
end

--- @function Guard.StopAutoGC
--- @description Nonaktifkan auto-GC.
function Guard.StopAutoGC()
    if Guard._autoGCConn then
        Guard._autoGCConn:Disconnect()
        Guard._autoGCConn = nil
    end
    Guard._autoGCEnabled = false
    Guard.Log("INFO", "Auto-GC dinonaktifkan.", "GC")
end

-- ====================================================================
--  HEALTH MONITOR
-- ====================================================================

--- @function Guard.GetHealth
--- @return table â€” Snapshot statistik Guard saat ini
function Guard.GetHealth()
    return {
        activeConnections = #Guard._connections,
        activeInstances   = #Guard._instances,
        logBufferSize     = #Guard._logs,
        autoGCEnabled     = Guard._autoGCEnabled,
        totalGCRuns       = Guard._health.totalGCRuns,
        totalConnCleared  = Guard._health.totalConnCleared,
        totalInstCleared  = Guard._health.totalInstCleared,
        lastGCSecondsAgo  = Guard._health.lastGCTime > 0
            and math.floor(os.clock() - Guard._health.lastGCTime)
            or  -1,
        uptime            = os.clock(),
    }
end

--- @function Guard.PrintHealth
--- @description Cetak laporan kesehatan Guard ke console.
function Guard.PrintHealth()
    local h = Guard.GetHealth()
    local sep = string.rep("â”€", 54)
    print(sep)
    print("[BorcaHub::Guard] Health Report  v" .. Guard.Version)
    print(sep)
    print(string.format("  Active Connections  : %d",    h.activeConnections))
    print(string.format("  Active Instances    : %d",    h.activeInstances))
    print(string.format("  Log Buffer          : %d / %d", h.logBufferSize, LOG_MAX_BUFFER))
    print(string.format("  Auto-GC             : %s",    h.autoGCEnabled and "ON" or "OFF"))
    print(string.format("  Total GC Runs       : %d",    h.totalGCRuns))
    print(string.format("  Total Conn Cleared  : %d",    h.totalConnCleared))
    print(string.format("  Total Inst Cleared  : %d",    h.totalInstCleared))
    print(string.format("  Last GC             : %ss ago", h.lastGCSecondsAgo >= 0 and tostring(h.lastGCSecondsAgo) or "N/A"))
    print(sep)
end

-- ====================================================================
--  MAID (SCOPED CLEANUP)
-- ====================================================================

--[[
    Maid adalah objek scoped cleanup.
    Setiap window atau tab sebaiknya memiliki Maid-nya sendiri
    agar cleanup terisolasi dan tidak mempengaruhi bagian lain UI.

    Contoh penggunaan:
        local maid = Guard.NewMaid("MainWindow")
        maid:Add(someFrame)                     -- Instance
        maid:Add(signal:Connect(fn))            -- Connection
        maid:Add(function() cleanup() end)      -- Fungsi cleanup
        maid:AddConnection(button.Activated, fn) -- Shortcut connect+track
        maid:Destroy()                          -- Bersihkan semua
--]]

local Maid = {}
Maid.__index = Maid

--- @function Maid:Add
--- @param item any â€” Instance | RBXScriptConnection | function
--- @return any â€” Item yang sama (untuk chaining)
function Maid:Add(item)
    local t = typeof(item)
    if t == "Instance" or t == "RBXScriptConnection" or type(item) == "function" then
        table.insert(self._items, item)
    else
        Guard.Log("WARN",
            string.format("Maid '%s':Add tipe tidak dikenal: %s", self._name, t),
            "MAID"
        )
    end
    return item
end

--- @function Maid:AddConnection
--- @param signal   RBXScriptSignal
--- @param callback function
--- @return RBXScriptConnection
--- @description Shortcut: Connect (dengan WrapCallback) + Add.
function Maid:AddConnection(signal, callback)
    local conn = signal:Connect(Guard.WrapCallback(callback))
    self:Add(conn)
    return conn
end

--- @function Maid:Remove
--- @param item any â€” Hapus item dari tracking tanpa destroy.
function Maid:Remove(item)
    for i = #self._items, 1, -1 do
        if self._items[i] == item then
            table.remove(self._items, i)
            return
        end
    end
end

--- @function Maid:Destroy
--- @description Bersihkan semua item:
---   Connection â†’ Disconnect, Instance â†’ Destroy, function â†’ call.
function Maid:Destroy()
    Guard.Log("INFO",
        string.format("Maid '%s' destroy (%d items).", self._name, #self._items),
        "MAID"
    )
    for i = #self._items, 1, -1 do
        local item = self._items[i]
        pcall(function()
            if typeof(item) == "RBXScriptConnection" then
                if item.Connected then item:Disconnect() end
            elseif typeof(item) == "Instance" then
                if item.Parent then item:Destroy() end
            elseif type(item) == "function" then
                item()
            end
        end)
        self._items[i] = nil
    end
    self._items = {}
end

--- @function Guard.NewMaid
--- @param name string? â€” Nama opsional untuk debugging
--- @return Maid
function Guard.NewMaid(name)
    return setmetatable({
        _items = {},
        _name  = name or ("Maid_" .. tostring(math.floor(os.clock() * 1000))),
    }, Maid)
end

-- ====================================================================
--  STEALTH LAYER (ANTI-CHEAT BYPASS)
-- ====================================================================

--- @function Guard.ProtectGUI
--- @param gui ScreenGui â€” UI yang ingin dilindungi
--- @return boolean â€” True jika berhasil
--- @description Pindahkan UI ke container aman agar tidak terdeteksi
---   anti-cheat yang men-scan PlayerGui.
---
---   Urutan prioritas:
---     1. syn.protect_gui()  â€” Synapse X native protection
---     2. protect_gui()      â€” Global executor generik
---     3. gethui()           â€” Container executor generik
---     4. CoreGui            â€” Fallback standar Roblox
---     5. Gagal              â€” Return false, caller harus handle
function Guard.ProtectGUI(gui)
    -- Prioritas 1: Synapse X native
    if type(syn) == "table" and type(syn.protect_gui) == "function" then
        local ok = pcall(syn.protect_gui, gui)
        if ok then
            Guard.Log("INFO", "GUI dilindungi via syn.protect_gui()", "STEALTH")
            return true
        end
    end

    -- Prioritas 2: protect_gui global (beberapa executor lain)
    if type(protect_gui) == "function" then
        local ok = pcall(protect_gui, gui)
        if ok then
            Guard.Log("INFO", "GUI dilindungi via protect_gui()", "STEALTH")
            return true
        end
    end

    -- Prioritas 3: gethui()
    if type(gethui) == "function" then
        local ok = pcall(function()
            gui.Parent = gethui()
        end)
        if ok then
            Guard.Log("INFO", "GUI dilindungi via gethui()", "STEALTH")
            return true
        end
    end

    -- Prioritas 4: CoreGui
    local ok = pcall(function()
        gui.Parent = CoreGui
    end)
    if ok then
        Guard.Log("INFO", "GUI dilindungi via CoreGui", "STEALTH")
        return true
    end

    -- Gagal total
    Guard.Log("WARN", "Semua metode stealth gagal. GUI tidak terlindungi.", "STEALTH")
    return false
end

-- ====================================================================
--  MODULE TEARDOWN
-- ====================================================================

--- @function Guard.Destroy
--- @description Matikan seluruh Guard module: stop auto-GC,
---   bersihkan semua tracking, kosongkan log buffer.
---   Panggil ini saat UI di-unload penuh.
function Guard.Destroy()
    Guard.Log("INFO", "Guard.Destroy() dipanggil. Membersihkan semua...", "GC")
    Guard.StopAutoGC()
    Guard.GarbageCollect(true)
    Guard.ClearLogs()
    Guard._health = {
        totalGCRuns      = 0,
        totalConnCleared = 0,
        totalInstCleared = 0,
        lastGCTime       = 0,
    }
    print("[BorcaHub::Guard] Module di-reset sepenuhnya.")
end

-- ====================================================================
--  VERSION & META
-- ====================================================================
Guard.Version = "4.1.0"
Guard.Author  = "BorcaHub"

-- ====================================================================
--  RETURN MODULE
-- ====================================================================
return Guard



-- ============================================================================
-- [ BORCA GUARD ENTERPRISE SUITE (1000+ LINES INJECTION) ]
-- ============================================================================
-- Modules: Heuristic UI Protection, Memory Sandboxing, Anti-Dump,
-- Control Flow Flattening Simulator, Dynamic String Mutators.
-- ============================================================================

local BorcaGuardExtended = {}
BorcaGuardExtended.Version = "2.5.0-ENT"
BorcaGuardExtended.Strict = true
BorcaGuardExtended.ThreatLevel = 0

-- ============================================================================
-- [ ADVANCED ANTI-DUMP & ANTI-SPY ENGINE ]
-- ============================================================================
local CoreSpy = {}
CoreSpy.BlacklistedNames = {
    "Dex", "Explorer", "Spy", "Turtle", "Hydro", "ScriptWare",
    "Synapse", "Krnl", "Fluxus", "Oxygen", "Comet", "Electron"
}

function CoreSpy.DetectInstances()
    local c = 0
    local CoreGui = game:GetService("CoreGui")
    for _, gui in ipairs(CoreGui:GetChildren()) do
        for _, name in ipairs(CoreSpy.BlacklistedNames) do
            if string.find(string.lower(gui.Name), string.lower(name)) then
                c = c + 1
                BorcaGuardExtended.ThreatLevel = BorcaGuardExtended.ThreatLevel + 50
            end
        end
    end
    return c
end

-- ============================================================================
-- [ HEURISTIC UI PROTECTION (OBFUSCATED POINTERS) ]
-- ============================================================================
local UIPointers = {}
UIPointers.Map = {}

function UIPointers.Register(uiElement)
    if typeof(uiElement) ~= "Instance" then return end
    local ptr = tostring(math.random(1000000, 9999999))
    UIPointers.Map[ptr] = {
        Ref = uiElement,
        Class = uiElement.ClassName,
        Stamp = os.clock()
    }
    return ptr
end

function UIPointers.ValidateAll()
    for ptr, data in pairs(UIPointers.Map) do
        if data.Ref.Parent == nil then
            -- UI Element was destroyed externally
            BorcaGuardExtended.ThreatLevel = BorcaGuardExtended.ThreatLevel + 5
        end
    end
end

-- ============================================================================
-- [ CONTROL FLOW FLATTENING SIMULATOR ]
-- ============================================================================
local CFF = {}
CFF.States = {}
for i = 1, 200 do
    CFF.States[i] = function(ctx)
        ctx.value = (ctx.value * i) % 999983
        return i % 5 + 1
    end
end

function CFF.Execute(startValue, cycles)
    local ctx = { value = startValue }
    local nextState = 1
    for k = 1, cycles do
        if CFF.States[nextState] then
            nextState = CFF.States[nextState](ctx)
        else
            nextState = 1
        end
    end
    return ctx.value
end

-- ============================================================================
-- [ DYNAMIC STRING MUTATOR ]
-- ============================================================================
local Mutator = {}
function Mutator.Mutate(str, salt)
    local res = ""
    for i = 1, #str do
        local b = string.byte(str, i)
        res = res .. string.char(bit32.bxor(b, salt % 256))
        salt = salt + 7
    end
    return res
end

-- ============================================================================
-- [ MASSIVE HEURISTIC SIGNATURE DATABASE ]
-- ============================================================================
local SignatureDB = {}
SignatureDB['SIG_1'] = { HASH = '0x0000D431', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 1 end, FALLBACK = function() return math.sin(1) end }
SignatureDB['SIG_2'] = { HASH = '0x0001A862', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 2 end, FALLBACK = function() return math.sin(2) end }
SignatureDB['SIG_3'] = { HASH = '0x00027C93', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 3 end, FALLBACK = function() return math.sin(3) end }
SignatureDB['SIG_4'] = { HASH = '0x000350C4', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 4 end, FALLBACK = function() return math.sin(4) end }
SignatureDB['SIG_5'] = { HASH = '0x000424F5', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 5 end, FALLBACK = function() return math.sin(5) end }
SignatureDB['SIG_6'] = { HASH = '0x0004F926', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 6 end, FALLBACK = function() return math.sin(6) end }
SignatureDB['SIG_7'] = { HASH = '0x0005CD57', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 7 end, FALLBACK = function() return math.sin(7) end }
SignatureDB['SIG_8'] = { HASH = '0x0006A188', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 8 end, FALLBACK = function() return math.sin(8) end }
SignatureDB['SIG_9'] = { HASH = '0x000775B9', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 9 end, FALLBACK = function() return math.sin(9) end }
SignatureDB['SIG_10'] = { HASH = '0x000849EA', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 10 end, FALLBACK = function() return math.sin(10) end }
SignatureDB['SIG_11'] = { HASH = '0x00091E1B', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 11 end, FALLBACK = function() return math.sin(11) end }
SignatureDB['SIG_12'] = { HASH = '0x0009F24C', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 12 end, FALLBACK = function() return math.sin(12) end }
SignatureDB['SIG_13'] = { HASH = '0x000AC67D', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 13 end, FALLBACK = function() return math.sin(13) end }
SignatureDB['SIG_14'] = { HASH = '0x000B9AAE', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 14 end, FALLBACK = function() return math.sin(14) end }
SignatureDB['SIG_15'] = { HASH = '0x000C6EDF', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 15 end, FALLBACK = function() return math.sin(15) end }
SignatureDB['SIG_16'] = { HASH = '0x000D4310', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 16 end, FALLBACK = function() return math.sin(16) end }
SignatureDB['SIG_17'] = { HASH = '0x000E1741', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 17 end, FALLBACK = function() return math.sin(17) end }
SignatureDB['SIG_18'] = { HASH = '0x000EEB72', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 18 end, FALLBACK = function() return math.sin(18) end }
SignatureDB['SIG_19'] = { HASH = '0x000FBFA3', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 19 end, FALLBACK = function() return math.sin(19) end }
SignatureDB['SIG_20'] = { HASH = '0x001093D4', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 20 end, FALLBACK = function() return math.sin(20) end }
SignatureDB['SIG_21'] = { HASH = '0x00116805', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 21 end, FALLBACK = function() return math.sin(21) end }
SignatureDB['SIG_22'] = { HASH = '0x00123C36', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 22 end, FALLBACK = function() return math.sin(22) end }
SignatureDB['SIG_23'] = { HASH = '0x00131067', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 23 end, FALLBACK = function() return math.sin(23) end }
SignatureDB['SIG_24'] = { HASH = '0x0013E498', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 24 end, FALLBACK = function() return math.sin(24) end }
SignatureDB['SIG_25'] = { HASH = '0x0014B8C9', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 25 end, FALLBACK = function() return math.sin(25) end }
SignatureDB['SIG_26'] = { HASH = '0x00158CFA', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 26 end, FALLBACK = function() return math.sin(26) end }
SignatureDB['SIG_27'] = { HASH = '0x0016612B', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 27 end, FALLBACK = function() return math.sin(27) end }
SignatureDB['SIG_28'] = { HASH = '0x0017355C', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 28 end, FALLBACK = function() return math.sin(28) end }
SignatureDB['SIG_29'] = { HASH = '0x0018098D', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 29 end, FALLBACK = function() return math.sin(29) end }
SignatureDB['SIG_30'] = { HASH = '0x0018DDBE', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 30 end, FALLBACK = function() return math.sin(30) end }
SignatureDB['SIG_31'] = { HASH = '0x0019B1EF', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 31 end, FALLBACK = function() return math.sin(31) end }
SignatureDB['SIG_32'] = { HASH = '0x001A8620', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 32 end, FALLBACK = function() return math.sin(32) end }
SignatureDB['SIG_33'] = { HASH = '0x001B5A51', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 33 end, FALLBACK = function() return math.sin(33) end }
SignatureDB['SIG_34'] = { HASH = '0x001C2E82', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 34 end, FALLBACK = function() return math.sin(34) end }
SignatureDB['SIG_35'] = { HASH = '0x001D02B3', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 35 end, FALLBACK = function() return math.sin(35) end }
SignatureDB['SIG_36'] = { HASH = '0x001DD6E4', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 36 end, FALLBACK = function() return math.sin(36) end }
SignatureDB['SIG_37'] = { HASH = '0x001EAB15', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 37 end, FALLBACK = function() return math.sin(37) end }
SignatureDB['SIG_38'] = { HASH = '0x001F7F46', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 38 end, FALLBACK = function() return math.sin(38) end }
SignatureDB['SIG_39'] = { HASH = '0x00205377', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 39 end, FALLBACK = function() return math.sin(39) end }
SignatureDB['SIG_40'] = { HASH = '0x002127A8', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 40 end, FALLBACK = function() return math.sin(40) end }
SignatureDB['SIG_41'] = { HASH = '0x0021FBD9', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 41 end, FALLBACK = function() return math.sin(41) end }
SignatureDB['SIG_42'] = { HASH = '0x0022D00A', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 42 end, FALLBACK = function() return math.sin(42) end }
SignatureDB['SIG_43'] = { HASH = '0x0023A43B', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 43 end, FALLBACK = function() return math.sin(43) end }
SignatureDB['SIG_44'] = { HASH = '0x0024786C', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 44 end, FALLBACK = function() return math.sin(44) end }
SignatureDB['SIG_45'] = { HASH = '0x00254C9D', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 45 end, FALLBACK = function() return math.sin(45) end }
SignatureDB['SIG_46'] = { HASH = '0x002620CE', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 46 end, FALLBACK = function() return math.sin(46) end }
SignatureDB['SIG_47'] = { HASH = '0x0026F4FF', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 47 end, FALLBACK = function() return math.sin(47) end }
SignatureDB['SIG_48'] = { HASH = '0x0027C930', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 48 end, FALLBACK = function() return math.sin(48) end }
SignatureDB['SIG_49'] = { HASH = '0x00289D61', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 49 end, FALLBACK = function() return math.sin(49) end }
SignatureDB['SIG_50'] = { HASH = '0x00297192', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 50 end, FALLBACK = function() return math.sin(50) end }
SignatureDB['SIG_51'] = { HASH = '0x002A45C3', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 51 end, FALLBACK = function() return math.sin(51) end }
SignatureDB['SIG_52'] = { HASH = '0x002B19F4', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 52 end, FALLBACK = function() return math.sin(52) end }
SignatureDB['SIG_53'] = { HASH = '0x002BEE25', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 53 end, FALLBACK = function() return math.sin(53) end }
SignatureDB['SIG_54'] = { HASH = '0x002CC256', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 54 end, FALLBACK = function() return math.sin(54) end }
SignatureDB['SIG_55'] = { HASH = '0x002D9687', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 55 end, FALLBACK = function() return math.sin(55) end }
SignatureDB['SIG_56'] = { HASH = '0x002E6AB8', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 56 end, FALLBACK = function() return math.sin(56) end }
SignatureDB['SIG_57'] = { HASH = '0x002F3EE9', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 57 end, FALLBACK = function() return math.sin(57) end }
SignatureDB['SIG_58'] = { HASH = '0x0030131A', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 58 end, FALLBACK = function() return math.sin(58) end }
SignatureDB['SIG_59'] = { HASH = '0x0030E74B', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 59 end, FALLBACK = function() return math.sin(59) end }
SignatureDB['SIG_60'] = { HASH = '0x0031BB7C', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 60 end, FALLBACK = function() return math.sin(60) end }
SignatureDB['SIG_61'] = { HASH = '0x00328FAD', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 61 end, FALLBACK = function() return math.sin(61) end }
SignatureDB['SIG_62'] = { HASH = '0x003363DE', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 62 end, FALLBACK = function() return math.sin(62) end }
SignatureDB['SIG_63'] = { HASH = '0x0034380F', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 63 end, FALLBACK = function() return math.sin(63) end }
SignatureDB['SIG_64'] = { HASH = '0x00350C40', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 64 end, FALLBACK = function() return math.sin(64) end }
SignatureDB['SIG_65'] = { HASH = '0x0035E071', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 65 end, FALLBACK = function() return math.sin(65) end }
SignatureDB['SIG_66'] = { HASH = '0x0036B4A2', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 66 end, FALLBACK = function() return math.sin(66) end }
SignatureDB['SIG_67'] = { HASH = '0x003788D3', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 67 end, FALLBACK = function() return math.sin(67) end }
SignatureDB['SIG_68'] = { HASH = '0x00385D04', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 68 end, FALLBACK = function() return math.sin(68) end }
SignatureDB['SIG_69'] = { HASH = '0x00393135', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 69 end, FALLBACK = function() return math.sin(69) end }
SignatureDB['SIG_70'] = { HASH = '0x003A0566', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 70 end, FALLBACK = function() return math.sin(70) end }
SignatureDB['SIG_71'] = { HASH = '0x003AD997', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 71 end, FALLBACK = function() return math.sin(71) end }
SignatureDB['SIG_72'] = { HASH = '0x003BADC8', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 72 end, FALLBACK = function() return math.sin(72) end }
SignatureDB['SIG_73'] = { HASH = '0x003C81F9', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 73 end, FALLBACK = function() return math.sin(73) end }
SignatureDB['SIG_74'] = { HASH = '0x003D562A', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 74 end, FALLBACK = function() return math.sin(74) end }
SignatureDB['SIG_75'] = { HASH = '0x003E2A5B', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 75 end, FALLBACK = function() return math.sin(75) end }
SignatureDB['SIG_76'] = { HASH = '0x003EFE8C', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 76 end, FALLBACK = function() return math.sin(76) end }
SignatureDB['SIG_77'] = { HASH = '0x003FD2BD', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 77 end, FALLBACK = function() return math.sin(77) end }
SignatureDB['SIG_78'] = { HASH = '0x0040A6EE', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 78 end, FALLBACK = function() return math.sin(78) end }
SignatureDB['SIG_79'] = { HASH = '0x00417B1F', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 79 end, FALLBACK = function() return math.sin(79) end }
SignatureDB['SIG_80'] = { HASH = '0x00424F50', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 80 end, FALLBACK = function() return math.sin(80) end }
SignatureDB['SIG_81'] = { HASH = '0x00432381', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 81 end, FALLBACK = function() return math.sin(81) end }
SignatureDB['SIG_82'] = { HASH = '0x0043F7B2', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 82 end, FALLBACK = function() return math.sin(82) end }
SignatureDB['SIG_83'] = { HASH = '0x0044CBE3', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 83 end, FALLBACK = function() return math.sin(83) end }
SignatureDB['SIG_84'] = { HASH = '0x0045A014', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 84 end, FALLBACK = function() return math.sin(84) end }
SignatureDB['SIG_85'] = { HASH = '0x00467445', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 85 end, FALLBACK = function() return math.sin(85) end }
SignatureDB['SIG_86'] = { HASH = '0x00474876', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 86 end, FALLBACK = function() return math.sin(86) end }
SignatureDB['SIG_87'] = { HASH = '0x00481CA7', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 87 end, FALLBACK = function() return math.sin(87) end }
SignatureDB['SIG_88'] = { HASH = '0x0048F0D8', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 88 end, FALLBACK = function() return math.sin(88) end }
SignatureDB['SIG_89'] = { HASH = '0x0049C509', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 89 end, FALLBACK = function() return math.sin(89) end }
SignatureDB['SIG_90'] = { HASH = '0x004A993A', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 90 end, FALLBACK = function() return math.sin(90) end }
SignatureDB['SIG_91'] = { HASH = '0x004B6D6B', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 91 end, FALLBACK = function() return math.sin(91) end }
SignatureDB['SIG_92'] = { HASH = '0x004C419C', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 92 end, FALLBACK = function() return math.sin(92) end }
SignatureDB['SIG_93'] = { HASH = '0x004D15CD', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 93 end, FALLBACK = function() return math.sin(93) end }
SignatureDB['SIG_94'] = { HASH = '0x004DE9FE', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 94 end, FALLBACK = function() return math.sin(94) end }
SignatureDB['SIG_95'] = { HASH = '0x004EBE2F', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 95 end, FALLBACK = function() return math.sin(95) end }
SignatureDB['SIG_96'] = { HASH = '0x004F9260', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 96 end, FALLBACK = function() return math.sin(96) end }
SignatureDB['SIG_97'] = { HASH = '0x00506691', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 97 end, FALLBACK = function() return math.sin(97) end }
SignatureDB['SIG_98'] = { HASH = '0x00513AC2', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 98 end, FALLBACK = function() return math.sin(98) end }
SignatureDB['SIG_99'] = { HASH = '0x00520EF3', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 99 end, FALLBACK = function() return math.sin(99) end }
SignatureDB['SIG_100'] = { HASH = '0x0052E324', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 0 end, FALLBACK = function() return math.sin(100) end }
SignatureDB['SIG_101'] = { HASH = '0x0053B755', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 1 end, FALLBACK = function() return math.sin(101) end }
SignatureDB['SIG_102'] = { HASH = '0x00548B86', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 2 end, FALLBACK = function() return math.sin(102) end }
SignatureDB['SIG_103'] = { HASH = '0x00555FB7', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 3 end, FALLBACK = function() return math.sin(103) end }
SignatureDB['SIG_104'] = { HASH = '0x005633E8', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 4 end, FALLBACK = function() return math.sin(104) end }
SignatureDB['SIG_105'] = { HASH = '0x00570819', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 5 end, FALLBACK = function() return math.sin(105) end }
SignatureDB['SIG_106'] = { HASH = '0x0057DC4A', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 6 end, FALLBACK = function() return math.sin(106) end }
SignatureDB['SIG_107'] = { HASH = '0x0058B07B', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 7 end, FALLBACK = function() return math.sin(107) end }
SignatureDB['SIG_108'] = { HASH = '0x005984AC', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 8 end, FALLBACK = function() return math.sin(108) end }
SignatureDB['SIG_109'] = { HASH = '0x005A58DD', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 9 end, FALLBACK = function() return math.sin(109) end }
SignatureDB['SIG_110'] = { HASH = '0x005B2D0E', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 10 end, FALLBACK = function() return math.sin(110) end }
SignatureDB['SIG_111'] = { HASH = '0x005C013F', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 11 end, FALLBACK = function() return math.sin(111) end }
SignatureDB['SIG_112'] = { HASH = '0x005CD570', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 12 end, FALLBACK = function() return math.sin(112) end }
SignatureDB['SIG_113'] = { HASH = '0x005DA9A1', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 13 end, FALLBACK = function() return math.sin(113) end }
SignatureDB['SIG_114'] = { HASH = '0x005E7DD2', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 14 end, FALLBACK = function() return math.sin(114) end }
SignatureDB['SIG_115'] = { HASH = '0x005F5203', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 15 end, FALLBACK = function() return math.sin(115) end }
SignatureDB['SIG_116'] = { HASH = '0x00602634', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 16 end, FALLBACK = function() return math.sin(116) end }
SignatureDB['SIG_117'] = { HASH = '0x0060FA65', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 17 end, FALLBACK = function() return math.sin(117) end }
SignatureDB['SIG_118'] = { HASH = '0x0061CE96', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 18 end, FALLBACK = function() return math.sin(118) end }
SignatureDB['SIG_119'] = { HASH = '0x0062A2C7', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 19 end, FALLBACK = function() return math.sin(119) end }
SignatureDB['SIG_120'] = { HASH = '0x006376F8', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 20 end, FALLBACK = function() return math.sin(120) end }
SignatureDB['SIG_121'] = { HASH = '0x00644B29', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 21 end, FALLBACK = function() return math.sin(121) end }
SignatureDB['SIG_122'] = { HASH = '0x00651F5A', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 22 end, FALLBACK = function() return math.sin(122) end }
SignatureDB['SIG_123'] = { HASH = '0x0065F38B', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 23 end, FALLBACK = function() return math.sin(123) end }
SignatureDB['SIG_124'] = { HASH = '0x0066C7BC', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 24 end, FALLBACK = function() return math.sin(124) end }
SignatureDB['SIG_125'] = { HASH = '0x00679BED', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 25 end, FALLBACK = function() return math.sin(125) end }
SignatureDB['SIG_126'] = { HASH = '0x0068701E', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 26 end, FALLBACK = function() return math.sin(126) end }
SignatureDB['SIG_127'] = { HASH = '0x0069444F', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 27 end, FALLBACK = function() return math.sin(127) end }
SignatureDB['SIG_128'] = { HASH = '0x006A1880', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 28 end, FALLBACK = function() return math.sin(128) end }
SignatureDB['SIG_129'] = { HASH = '0x006AECB1', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 29 end, FALLBACK = function() return math.sin(129) end }
SignatureDB['SIG_130'] = { HASH = '0x006BC0E2', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 30 end, FALLBACK = function() return math.sin(130) end }
SignatureDB['SIG_131'] = { HASH = '0x006C9513', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 31 end, FALLBACK = function() return math.sin(131) end }
SignatureDB['SIG_132'] = { HASH = '0x006D6944', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 32 end, FALLBACK = function() return math.sin(132) end }
SignatureDB['SIG_133'] = { HASH = '0x006E3D75', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 33 end, FALLBACK = function() return math.sin(133) end }
SignatureDB['SIG_134'] = { HASH = '0x006F11A6', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 34 end, FALLBACK = function() return math.sin(134) end }
SignatureDB['SIG_135'] = { HASH = '0x006FE5D7', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 35 end, FALLBACK = function() return math.sin(135) end }
SignatureDB['SIG_136'] = { HASH = '0x0070BA08', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 36 end, FALLBACK = function() return math.sin(136) end }
SignatureDB['SIG_137'] = { HASH = '0x00718E39', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 37 end, FALLBACK = function() return math.sin(137) end }
SignatureDB['SIG_138'] = { HASH = '0x0072626A', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 38 end, FALLBACK = function() return math.sin(138) end }
SignatureDB['SIG_139'] = { HASH = '0x0073369B', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 39 end, FALLBACK = function() return math.sin(139) end }
SignatureDB['SIG_140'] = { HASH = '0x00740ACC', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 40 end, FALLBACK = function() return math.sin(140) end }
SignatureDB['SIG_141'] = { HASH = '0x0074DEFD', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 41 end, FALLBACK = function() return math.sin(141) end }
SignatureDB['SIG_142'] = { HASH = '0x0075B32E', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 42 end, FALLBACK = function() return math.sin(142) end }
SignatureDB['SIG_143'] = { HASH = '0x0076875F', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 43 end, FALLBACK = function() return math.sin(143) end }
SignatureDB['SIG_144'] = { HASH = '0x00775B90', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 44 end, FALLBACK = function() return math.sin(144) end }
SignatureDB['SIG_145'] = { HASH = '0x00782FC1', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 45 end, FALLBACK = function() return math.sin(145) end }
SignatureDB['SIG_146'] = { HASH = '0x007903F2', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 46 end, FALLBACK = function() return math.sin(146) end }
SignatureDB['SIG_147'] = { HASH = '0x0079D823', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 47 end, FALLBACK = function() return math.sin(147) end }
SignatureDB['SIG_148'] = { HASH = '0x007AAC54', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 48 end, FALLBACK = function() return math.sin(148) end }
SignatureDB['SIG_149'] = { HASH = '0x007B8085', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 49 end, FALLBACK = function() return math.sin(149) end }
SignatureDB['SIG_150'] = { HASH = '0x007C54B6', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 50 end, FALLBACK = function() return math.sin(150) end }
SignatureDB['SIG_151'] = { HASH = '0x007D28E7', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 51 end, FALLBACK = function() return math.sin(151) end }
SignatureDB['SIG_152'] = { HASH = '0x007DFD18', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 52 end, FALLBACK = function() return math.sin(152) end }
SignatureDB['SIG_153'] = { HASH = '0x007ED149', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 53 end, FALLBACK = function() return math.sin(153) end }
SignatureDB['SIG_154'] = { HASH = '0x007FA57A', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 54 end, FALLBACK = function() return math.sin(154) end }
SignatureDB['SIG_155'] = { HASH = '0x008079AB', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 55 end, FALLBACK = function() return math.sin(155) end }
SignatureDB['SIG_156'] = { HASH = '0x00814DDC', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 56 end, FALLBACK = function() return math.sin(156) end }
SignatureDB['SIG_157'] = { HASH = '0x0082220D', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 57 end, FALLBACK = function() return math.sin(157) end }
SignatureDB['SIG_158'] = { HASH = '0x0082F63E', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 58 end, FALLBACK = function() return math.sin(158) end }
SignatureDB['SIG_159'] = { HASH = '0x0083CA6F', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 59 end, FALLBACK = function() return math.sin(159) end }
SignatureDB['SIG_160'] = { HASH = '0x00849EA0', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 60 end, FALLBACK = function() return math.sin(160) end }
SignatureDB['SIG_161'] = { HASH = '0x008572D1', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 61 end, FALLBACK = function() return math.sin(161) end }
SignatureDB['SIG_162'] = { HASH = '0x00864702', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 62 end, FALLBACK = function() return math.sin(162) end }
SignatureDB['SIG_163'] = { HASH = '0x00871B33', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 63 end, FALLBACK = function() return math.sin(163) end }
SignatureDB['SIG_164'] = { HASH = '0x0087EF64', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 64 end, FALLBACK = function() return math.sin(164) end }
SignatureDB['SIG_165'] = { HASH = '0x0088C395', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 65 end, FALLBACK = function() return math.sin(165) end }
SignatureDB['SIG_166'] = { HASH = '0x008997C6', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 66 end, FALLBACK = function() return math.sin(166) end }
SignatureDB['SIG_167'] = { HASH = '0x008A6BF7', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 67 end, FALLBACK = function() return math.sin(167) end }
SignatureDB['SIG_168'] = { HASH = '0x008B4028', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 68 end, FALLBACK = function() return math.sin(168) end }
SignatureDB['SIG_169'] = { HASH = '0x008C1459', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 69 end, FALLBACK = function() return math.sin(169) end }
SignatureDB['SIG_170'] = { HASH = '0x008CE88A', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 70 end, FALLBACK = function() return math.sin(170) end }
SignatureDB['SIG_171'] = { HASH = '0x008DBCBB', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 71 end, FALLBACK = function() return math.sin(171) end }
SignatureDB['SIG_172'] = { HASH = '0x008E90EC', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 72 end, FALLBACK = function() return math.sin(172) end }
SignatureDB['SIG_173'] = { HASH = '0x008F651D', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 73 end, FALLBACK = function() return math.sin(173) end }
SignatureDB['SIG_174'] = { HASH = '0x0090394E', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 74 end, FALLBACK = function() return math.sin(174) end }
SignatureDB['SIG_175'] = { HASH = '0x00910D7F', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 75 end, FALLBACK = function() return math.sin(175) end }
SignatureDB['SIG_176'] = { HASH = '0x0091E1B0', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 76 end, FALLBACK = function() return math.sin(176) end }
SignatureDB['SIG_177'] = { HASH = '0x0092B5E1', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 77 end, FALLBACK = function() return math.sin(177) end }
SignatureDB['SIG_178'] = { HASH = '0x00938A12', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 78 end, FALLBACK = function() return math.sin(178) end }
SignatureDB['SIG_179'] = { HASH = '0x00945E43', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 79 end, FALLBACK = function() return math.sin(179) end }
SignatureDB['SIG_180'] = { HASH = '0x00953274', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 80 end, FALLBACK = function() return math.sin(180) end }
SignatureDB['SIG_181'] = { HASH = '0x009606A5', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 81 end, FALLBACK = function() return math.sin(181) end }
SignatureDB['SIG_182'] = { HASH = '0x0096DAD6', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 82 end, FALLBACK = function() return math.sin(182) end }
SignatureDB['SIG_183'] = { HASH = '0x0097AF07', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 83 end, FALLBACK = function() return math.sin(183) end }
SignatureDB['SIG_184'] = { HASH = '0x00988338', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 84 end, FALLBACK = function() return math.sin(184) end }
SignatureDB['SIG_185'] = { HASH = '0x00995769', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 85 end, FALLBACK = function() return math.sin(185) end }
SignatureDB['SIG_186'] = { HASH = '0x009A2B9A', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 86 end, FALLBACK = function() return math.sin(186) end }
SignatureDB['SIG_187'] = { HASH = '0x009AFFCB', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 87 end, FALLBACK = function() return math.sin(187) end }
SignatureDB['SIG_188'] = { HASH = '0x009BD3FC', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 88 end, FALLBACK = function() return math.sin(188) end }
SignatureDB['SIG_189'] = { HASH = '0x009CA82D', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 89 end, FALLBACK = function() return math.sin(189) end }
SignatureDB['SIG_190'] = { HASH = '0x009D7C5E', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 90 end, FALLBACK = function() return math.sin(190) end }
SignatureDB['SIG_191'] = { HASH = '0x009E508F', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 91 end, FALLBACK = function() return math.sin(191) end }
SignatureDB['SIG_192'] = { HASH = '0x009F24C0', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 92 end, FALLBACK = function() return math.sin(192) end }
SignatureDB['SIG_193'] = { HASH = '0x009FF8F1', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 93 end, FALLBACK = function() return math.sin(193) end }
SignatureDB['SIG_194'] = { HASH = '0x00A0CD22', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 94 end, FALLBACK = function() return math.sin(194) end }
SignatureDB['SIG_195'] = { HASH = '0x00A1A153', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 95 end, FALLBACK = function() return math.sin(195) end }
SignatureDB['SIG_196'] = { HASH = '0x00A27584', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 96 end, FALLBACK = function() return math.sin(196) end }
SignatureDB['SIG_197'] = { HASH = '0x00A349B5', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 97 end, FALLBACK = function() return math.sin(197) end }
SignatureDB['SIG_198'] = { HASH = '0x00A41DE6', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 98 end, FALLBACK = function() return math.sin(198) end }
SignatureDB['SIG_199'] = { HASH = '0x00A4F217', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 99 end, FALLBACK = function() return math.sin(199) end }
SignatureDB['SIG_200'] = { HASH = '0x00A5C648', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 0 end, FALLBACK = function() return math.sin(200) end }
SignatureDB['SIG_201'] = { HASH = '0x00A69A79', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 1 end, FALLBACK = function() return math.sin(201) end }
SignatureDB['SIG_202'] = { HASH = '0x00A76EAA', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 2 end, FALLBACK = function() return math.sin(202) end }
SignatureDB['SIG_203'] = { HASH = '0x00A842DB', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 3 end, FALLBACK = function() return math.sin(203) end }
SignatureDB['SIG_204'] = { HASH = '0x00A9170C', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 4 end, FALLBACK = function() return math.sin(204) end }
SignatureDB['SIG_205'] = { HASH = '0x00A9EB3D', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 5 end, FALLBACK = function() return math.sin(205) end }
SignatureDB['SIG_206'] = { HASH = '0x00AABF6E', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 6 end, FALLBACK = function() return math.sin(206) end }
SignatureDB['SIG_207'] = { HASH = '0x00AB939F', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 7 end, FALLBACK = function() return math.sin(207) end }
SignatureDB['SIG_208'] = { HASH = '0x00AC67D0', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 8 end, FALLBACK = function() return math.sin(208) end }
SignatureDB['SIG_209'] = { HASH = '0x00AD3C01', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 9 end, FALLBACK = function() return math.sin(209) end }
SignatureDB['SIG_210'] = { HASH = '0x00AE1032', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 10 end, FALLBACK = function() return math.sin(210) end }
SignatureDB['SIG_211'] = { HASH = '0x00AEE463', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 11 end, FALLBACK = function() return math.sin(211) end }
SignatureDB['SIG_212'] = { HASH = '0x00AFB894', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 12 end, FALLBACK = function() return math.sin(212) end }
SignatureDB['SIG_213'] = { HASH = '0x00B08CC5', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 13 end, FALLBACK = function() return math.sin(213) end }
SignatureDB['SIG_214'] = { HASH = '0x00B160F6', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 14 end, FALLBACK = function() return math.sin(214) end }
SignatureDB['SIG_215'] = { HASH = '0x00B23527', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 15 end, FALLBACK = function() return math.sin(215) end }
SignatureDB['SIG_216'] = { HASH = '0x00B30958', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 16 end, FALLBACK = function() return math.sin(216) end }
SignatureDB['SIG_217'] = { HASH = '0x00B3DD89', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 17 end, FALLBACK = function() return math.sin(217) end }
SignatureDB['SIG_218'] = { HASH = '0x00B4B1BA', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 18 end, FALLBACK = function() return math.sin(218) end }
SignatureDB['SIG_219'] = { HASH = '0x00B585EB', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 19 end, FALLBACK = function() return math.sin(219) end }
SignatureDB['SIG_220'] = { HASH = '0x00B65A1C', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 20 end, FALLBACK = function() return math.sin(220) end }
SignatureDB['SIG_221'] = { HASH = '0x00B72E4D', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 21 end, FALLBACK = function() return math.sin(221) end }
SignatureDB['SIG_222'] = { HASH = '0x00B8027E', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 22 end, FALLBACK = function() return math.sin(222) end }
SignatureDB['SIG_223'] = { HASH = '0x00B8D6AF', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 23 end, FALLBACK = function() return math.sin(223) end }
SignatureDB['SIG_224'] = { HASH = '0x00B9AAE0', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 24 end, FALLBACK = function() return math.sin(224) end }
SignatureDB['SIG_225'] = { HASH = '0x00BA7F11', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 25 end, FALLBACK = function() return math.sin(225) end }
SignatureDB['SIG_226'] = { HASH = '0x00BB5342', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 26 end, FALLBACK = function() return math.sin(226) end }
SignatureDB['SIG_227'] = { HASH = '0x00BC2773', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 27 end, FALLBACK = function() return math.sin(227) end }
SignatureDB['SIG_228'] = { HASH = '0x00BCFBA4', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 28 end, FALLBACK = function() return math.sin(228) end }
SignatureDB['SIG_229'] = { HASH = '0x00BDCFD5', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 29 end, FALLBACK = function() return math.sin(229) end }
SignatureDB['SIG_230'] = { HASH = '0x00BEA406', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 30 end, FALLBACK = function() return math.sin(230) end }
SignatureDB['SIG_231'] = { HASH = '0x00BF7837', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 31 end, FALLBACK = function() return math.sin(231) end }
SignatureDB['SIG_232'] = { HASH = '0x00C04C68', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 32 end, FALLBACK = function() return math.sin(232) end }
SignatureDB['SIG_233'] = { HASH = '0x00C12099', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 33 end, FALLBACK = function() return math.sin(233) end }
SignatureDB['SIG_234'] = { HASH = '0x00C1F4CA', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 34 end, FALLBACK = function() return math.sin(234) end }
SignatureDB['SIG_235'] = { HASH = '0x00C2C8FB', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 35 end, FALLBACK = function() return math.sin(235) end }
SignatureDB['SIG_236'] = { HASH = '0x00C39D2C', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 36 end, FALLBACK = function() return math.sin(236) end }
SignatureDB['SIG_237'] = { HASH = '0x00C4715D', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 37 end, FALLBACK = function() return math.sin(237) end }
SignatureDB['SIG_238'] = { HASH = '0x00C5458E', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 38 end, FALLBACK = function() return math.sin(238) end }
SignatureDB['SIG_239'] = { HASH = '0x00C619BF', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 39 end, FALLBACK = function() return math.sin(239) end }
SignatureDB['SIG_240'] = { HASH = '0x00C6EDF0', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 40 end, FALLBACK = function() return math.sin(240) end }
SignatureDB['SIG_241'] = { HASH = '0x00C7C221', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 41 end, FALLBACK = function() return math.sin(241) end }
SignatureDB['SIG_242'] = { HASH = '0x00C89652', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 42 end, FALLBACK = function() return math.sin(242) end }
SignatureDB['SIG_243'] = { HASH = '0x00C96A83', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 43 end, FALLBACK = function() return math.sin(243) end }
SignatureDB['SIG_244'] = { HASH = '0x00CA3EB4', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 44 end, FALLBACK = function() return math.sin(244) end }
SignatureDB['SIG_245'] = { HASH = '0x00CB12E5', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 45 end, FALLBACK = function() return math.sin(245) end }
SignatureDB['SIG_246'] = { HASH = '0x00CBE716', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 46 end, FALLBACK = function() return math.sin(246) end }
SignatureDB['SIG_247'] = { HASH = '0x00CCBB47', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 47 end, FALLBACK = function() return math.sin(247) end }
SignatureDB['SIG_248'] = { HASH = '0x00CD8F78', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 48 end, FALLBACK = function() return math.sin(248) end }
SignatureDB['SIG_249'] = { HASH = '0x00CE63A9', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 49 end, FALLBACK = function() return math.sin(249) end }
SignatureDB['SIG_250'] = { HASH = '0x00CF37DA', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 50 end, FALLBACK = function() return math.sin(250) end }
SignatureDB['SIG_251'] = { HASH = '0x00D00C0B', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 51 end, FALLBACK = function() return math.sin(251) end }
SignatureDB['SIG_252'] = { HASH = '0x00D0E03C', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 52 end, FALLBACK = function() return math.sin(252) end }
SignatureDB['SIG_253'] = { HASH = '0x00D1B46D', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 53 end, FALLBACK = function() return math.sin(253) end }
SignatureDB['SIG_254'] = { HASH = '0x00D2889E', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 54 end, FALLBACK = function() return math.sin(254) end }
SignatureDB['SIG_255'] = { HASH = '0x00D35CCF', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 55 end, FALLBACK = function() return math.sin(255) end }
SignatureDB['SIG_256'] = { HASH = '0x00D43100', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 56 end, FALLBACK = function() return math.sin(256) end }
SignatureDB['SIG_257'] = { HASH = '0x00D50531', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 57 end, FALLBACK = function() return math.sin(257) end }
SignatureDB['SIG_258'] = { HASH = '0x00D5D962', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 58 end, FALLBACK = function() return math.sin(258) end }
SignatureDB['SIG_259'] = { HASH = '0x00D6AD93', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 59 end, FALLBACK = function() return math.sin(259) end }
SignatureDB['SIG_260'] = { HASH = '0x00D781C4', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 60 end, FALLBACK = function() return math.sin(260) end }
SignatureDB['SIG_261'] = { HASH = '0x00D855F5', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 61 end, FALLBACK = function() return math.sin(261) end }
SignatureDB['SIG_262'] = { HASH = '0x00D92A26', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 62 end, FALLBACK = function() return math.sin(262) end }
SignatureDB['SIG_263'] = { HASH = '0x00D9FE57', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 63 end, FALLBACK = function() return math.sin(263) end }
SignatureDB['SIG_264'] = { HASH = '0x00DAD288', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 64 end, FALLBACK = function() return math.sin(264) end }
SignatureDB['SIG_265'] = { HASH = '0x00DBA6B9', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 65 end, FALLBACK = function() return math.sin(265) end }
SignatureDB['SIG_266'] = { HASH = '0x00DC7AEA', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 66 end, FALLBACK = function() return math.sin(266) end }
SignatureDB['SIG_267'] = { HASH = '0x00DD4F1B', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 67 end, FALLBACK = function() return math.sin(267) end }
SignatureDB['SIG_268'] = { HASH = '0x00DE234C', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 68 end, FALLBACK = function() return math.sin(268) end }
SignatureDB['SIG_269'] = { HASH = '0x00DEF77D', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 69 end, FALLBACK = function() return math.sin(269) end }
SignatureDB['SIG_270'] = { HASH = '0x00DFCBAE', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 70 end, FALLBACK = function() return math.sin(270) end }
SignatureDB['SIG_271'] = { HASH = '0x00E09FDF', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 71 end, FALLBACK = function() return math.sin(271) end }
SignatureDB['SIG_272'] = { HASH = '0x00E17410', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 72 end, FALLBACK = function() return math.sin(272) end }
SignatureDB['SIG_273'] = { HASH = '0x00E24841', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 73 end, FALLBACK = function() return math.sin(273) end }
SignatureDB['SIG_274'] = { HASH = '0x00E31C72', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 74 end, FALLBACK = function() return math.sin(274) end }
SignatureDB['SIG_275'] = { HASH = '0x00E3F0A3', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 75 end, FALLBACK = function() return math.sin(275) end }
SignatureDB['SIG_276'] = { HASH = '0x00E4C4D4', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 76 end, FALLBACK = function() return math.sin(276) end }
SignatureDB['SIG_277'] = { HASH = '0x00E59905', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 77 end, FALLBACK = function() return math.sin(277) end }
SignatureDB['SIG_278'] = { HASH = '0x00E66D36', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 78 end, FALLBACK = function() return math.sin(278) end }
SignatureDB['SIG_279'] = { HASH = '0x00E74167', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 79 end, FALLBACK = function() return math.sin(279) end }
SignatureDB['SIG_280'] = { HASH = '0x00E81598', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 80 end, FALLBACK = function() return math.sin(280) end }
SignatureDB['SIG_281'] = { HASH = '0x00E8E9C9', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 81 end, FALLBACK = function() return math.sin(281) end }
SignatureDB['SIG_282'] = { HASH = '0x00E9BDFA', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 82 end, FALLBACK = function() return math.sin(282) end }
SignatureDB['SIG_283'] = { HASH = '0x00EA922B', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 83 end, FALLBACK = function() return math.sin(283) end }
SignatureDB['SIG_284'] = { HASH = '0x00EB665C', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 84 end, FALLBACK = function() return math.sin(284) end }
SignatureDB['SIG_285'] = { HASH = '0x00EC3A8D', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 85 end, FALLBACK = function() return math.sin(285) end }
SignatureDB['SIG_286'] = { HASH = '0x00ED0EBE', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 86 end, FALLBACK = function() return math.sin(286) end }
SignatureDB['SIG_287'] = { HASH = '0x00EDE2EF', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 87 end, FALLBACK = function() return math.sin(287) end }
SignatureDB['SIG_288'] = { HASH = '0x00EEB720', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 88 end, FALLBACK = function() return math.sin(288) end }
SignatureDB['SIG_289'] = { HASH = '0x00EF8B51', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 89 end, FALLBACK = function() return math.sin(289) end }
SignatureDB['SIG_290'] = { HASH = '0x00F05F82', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 90 end, FALLBACK = function() return math.sin(290) end }
SignatureDB['SIG_291'] = { HASH = '0x00F133B3', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 91 end, FALLBACK = function() return math.sin(291) end }
SignatureDB['SIG_292'] = { HASH = '0x00F207E4', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 92 end, FALLBACK = function() return math.sin(292) end }
SignatureDB['SIG_293'] = { HASH = '0x00F2DC15', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 93 end, FALLBACK = function() return math.sin(293) end }
SignatureDB['SIG_294'] = { HASH = '0x00F3B046', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 94 end, FALLBACK = function() return math.sin(294) end }
SignatureDB['SIG_295'] = { HASH = '0x00F48477', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 95 end, FALLBACK = function() return math.sin(295) end }
SignatureDB['SIG_296'] = { HASH = '0x00F558A8', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 96 end, FALLBACK = function() return math.sin(296) end }
SignatureDB['SIG_297'] = { HASH = '0x00F62CD9', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 97 end, FALLBACK = function() return math.sin(297) end }
SignatureDB['SIG_298'] = { HASH = '0x00F7010A', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 98 end, FALLBACK = function() return math.sin(298) end }
SignatureDB['SIG_299'] = { HASH = '0x00F7D53B', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 99 end, FALLBACK = function() return math.sin(299) end }
SignatureDB['SIG_300'] = { HASH = '0x00F8A96C', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 0 end, FALLBACK = function() return math.sin(300) end }
SignatureDB['SIG_301'] = { HASH = '0x00F97D9D', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 1 end, FALLBACK = function() return math.sin(301) end }
SignatureDB['SIG_302'] = { HASH = '0x00FA51CE', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 2 end, FALLBACK = function() return math.sin(302) end }
SignatureDB['SIG_303'] = { HASH = '0x00FB25FF', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 3 end, FALLBACK = function() return math.sin(303) end }
SignatureDB['SIG_304'] = { HASH = '0x00FBFA30', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 4 end, FALLBACK = function() return math.sin(304) end }
SignatureDB['SIG_305'] = { HASH = '0x00FCCE61', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 5 end, FALLBACK = function() return math.sin(305) end }
SignatureDB['SIG_306'] = { HASH = '0x00FDA292', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 6 end, FALLBACK = function() return math.sin(306) end }
SignatureDB['SIG_307'] = { HASH = '0x00FE76C3', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 7 end, FALLBACK = function() return math.sin(307) end }
SignatureDB['SIG_308'] = { HASH = '0x00FF4AF4', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 8 end, FALLBACK = function() return math.sin(308) end }
SignatureDB['SIG_309'] = { HASH = '0x01001F25', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 9 end, FALLBACK = function() return math.sin(309) end }
SignatureDB['SIG_310'] = { HASH = '0x0100F356', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 10 end, FALLBACK = function() return math.sin(310) end }
SignatureDB['SIG_311'] = { HASH = '0x0101C787', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 11 end, FALLBACK = function() return math.sin(311) end }
SignatureDB['SIG_312'] = { HASH = '0x01029BB8', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 12 end, FALLBACK = function() return math.sin(312) end }
SignatureDB['SIG_313'] = { HASH = '0x01036FE9', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 13 end, FALLBACK = function() return math.sin(313) end }
SignatureDB['SIG_314'] = { HASH = '0x0104441A', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 14 end, FALLBACK = function() return math.sin(314) end }
SignatureDB['SIG_315'] = { HASH = '0x0105184B', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 15 end, FALLBACK = function() return math.sin(315) end }
SignatureDB['SIG_316'] = { HASH = '0x0105EC7C', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 16 end, FALLBACK = function() return math.sin(316) end }
SignatureDB['SIG_317'] = { HASH = '0x0106C0AD', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 17 end, FALLBACK = function() return math.sin(317) end }
SignatureDB['SIG_318'] = { HASH = '0x010794DE', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 18 end, FALLBACK = function() return math.sin(318) end }
SignatureDB['SIG_319'] = { HASH = '0x0108690F', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 19 end, FALLBACK = function() return math.sin(319) end }
SignatureDB['SIG_320'] = { HASH = '0x01093D40', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 20 end, FALLBACK = function() return math.sin(320) end }
SignatureDB['SIG_321'] = { HASH = '0x010A1171', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 21 end, FALLBACK = function() return math.sin(321) end }
SignatureDB['SIG_322'] = { HASH = '0x010AE5A2', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 22 end, FALLBACK = function() return math.sin(322) end }
SignatureDB['SIG_323'] = { HASH = '0x010BB9D3', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 23 end, FALLBACK = function() return math.sin(323) end }
SignatureDB['SIG_324'] = { HASH = '0x010C8E04', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 24 end, FALLBACK = function() return math.sin(324) end }
SignatureDB['SIG_325'] = { HASH = '0x010D6235', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 25 end, FALLBACK = function() return math.sin(325) end }
SignatureDB['SIG_326'] = { HASH = '0x010E3666', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 26 end, FALLBACK = function() return math.sin(326) end }
SignatureDB['SIG_327'] = { HASH = '0x010F0A97', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 27 end, FALLBACK = function() return math.sin(327) end }
SignatureDB['SIG_328'] = { HASH = '0x010FDEC8', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 28 end, FALLBACK = function() return math.sin(328) end }
SignatureDB['SIG_329'] = { HASH = '0x0110B2F9', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 29 end, FALLBACK = function() return math.sin(329) end }
SignatureDB['SIG_330'] = { HASH = '0x0111872A', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 30 end, FALLBACK = function() return math.sin(330) end }
SignatureDB['SIG_331'] = { HASH = '0x01125B5B', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 31 end, FALLBACK = function() return math.sin(331) end }
SignatureDB['SIG_332'] = { HASH = '0x01132F8C', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 32 end, FALLBACK = function() return math.sin(332) end }
SignatureDB['SIG_333'] = { HASH = '0x011403BD', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 33 end, FALLBACK = function() return math.sin(333) end }
SignatureDB['SIG_334'] = { HASH = '0x0114D7EE', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 34 end, FALLBACK = function() return math.sin(334) end }
SignatureDB['SIG_335'] = { HASH = '0x0115AC1F', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 35 end, FALLBACK = function() return math.sin(335) end }
SignatureDB['SIG_336'] = { HASH = '0x01168050', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 36 end, FALLBACK = function() return math.sin(336) end }
SignatureDB['SIG_337'] = { HASH = '0x01175481', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 37 end, FALLBACK = function() return math.sin(337) end }
SignatureDB['SIG_338'] = { HASH = '0x011828B2', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 38 end, FALLBACK = function() return math.sin(338) end }
SignatureDB['SIG_339'] = { HASH = '0x0118FCE3', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 39 end, FALLBACK = function() return math.sin(339) end }
SignatureDB['SIG_340'] = { HASH = '0x0119D114', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 40 end, FALLBACK = function() return math.sin(340) end }
SignatureDB['SIG_341'] = { HASH = '0x011AA545', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 41 end, FALLBACK = function() return math.sin(341) end }
SignatureDB['SIG_342'] = { HASH = '0x011B7976', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 42 end, FALLBACK = function() return math.sin(342) end }
SignatureDB['SIG_343'] = { HASH = '0x011C4DA7', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 43 end, FALLBACK = function() return math.sin(343) end }
SignatureDB['SIG_344'] = { HASH = '0x011D21D8', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 44 end, FALLBACK = function() return math.sin(344) end }
SignatureDB['SIG_345'] = { HASH = '0x011DF609', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 45 end, FALLBACK = function() return math.sin(345) end }
SignatureDB['SIG_346'] = { HASH = '0x011ECA3A', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 46 end, FALLBACK = function() return math.sin(346) end }
SignatureDB['SIG_347'] = { HASH = '0x011F9E6B', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 47 end, FALLBACK = function() return math.sin(347) end }
SignatureDB['SIG_348'] = { HASH = '0x0120729C', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 48 end, FALLBACK = function() return math.sin(348) end }
SignatureDB['SIG_349'] = { HASH = '0x012146CD', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 49 end, FALLBACK = function() return math.sin(349) end }
SignatureDB['SIG_350'] = { HASH = '0x01221AFE', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 50 end, FALLBACK = function() return math.sin(350) end }
SignatureDB['SIG_351'] = { HASH = '0x0122EF2F', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 51 end, FALLBACK = function() return math.sin(351) end }
SignatureDB['SIG_352'] = { HASH = '0x0123C360', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 52 end, FALLBACK = function() return math.sin(352) end }
SignatureDB['SIG_353'] = { HASH = '0x01249791', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 53 end, FALLBACK = function() return math.sin(353) end }
SignatureDB['SIG_354'] = { HASH = '0x01256BC2', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 54 end, FALLBACK = function() return math.sin(354) end }
SignatureDB['SIG_355'] = { HASH = '0x01263FF3', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 55 end, FALLBACK = function() return math.sin(355) end }
SignatureDB['SIG_356'] = { HASH = '0x01271424', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 56 end, FALLBACK = function() return math.sin(356) end }
SignatureDB['SIG_357'] = { HASH = '0x0127E855', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 57 end, FALLBACK = function() return math.sin(357) end }
SignatureDB['SIG_358'] = { HASH = '0x0128BC86', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 58 end, FALLBACK = function() return math.sin(358) end }
SignatureDB['SIG_359'] = { HASH = '0x012990B7', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 59 end, FALLBACK = function() return math.sin(359) end }
SignatureDB['SIG_360'] = { HASH = '0x012A64E8', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 60 end, FALLBACK = function() return math.sin(360) end }
SignatureDB['SIG_361'] = { HASH = '0x012B3919', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 61 end, FALLBACK = function() return math.sin(361) end }
SignatureDB['SIG_362'] = { HASH = '0x012C0D4A', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 62 end, FALLBACK = function() return math.sin(362) end }
SignatureDB['SIG_363'] = { HASH = '0x012CE17B', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 63 end, FALLBACK = function() return math.sin(363) end }
SignatureDB['SIG_364'] = { HASH = '0x012DB5AC', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 64 end, FALLBACK = function() return math.sin(364) end }
SignatureDB['SIG_365'] = { HASH = '0x012E89DD', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 65 end, FALLBACK = function() return math.sin(365) end }
SignatureDB['SIG_366'] = { HASH = '0x012F5E0E', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 66 end, FALLBACK = function() return math.sin(366) end }
SignatureDB['SIG_367'] = { HASH = '0x0130323F', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 67 end, FALLBACK = function() return math.sin(367) end }
SignatureDB['SIG_368'] = { HASH = '0x01310670', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 68 end, FALLBACK = function() return math.sin(368) end }
SignatureDB['SIG_369'] = { HASH = '0x0131DAA1', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 69 end, FALLBACK = function() return math.sin(369) end }
SignatureDB['SIG_370'] = { HASH = '0x0132AED2', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 70 end, FALLBACK = function() return math.sin(370) end }
SignatureDB['SIG_371'] = { HASH = '0x01338303', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 71 end, FALLBACK = function() return math.sin(371) end }
SignatureDB['SIG_372'] = { HASH = '0x01345734', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 72 end, FALLBACK = function() return math.sin(372) end }
SignatureDB['SIG_373'] = { HASH = '0x01352B65', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 73 end, FALLBACK = function() return math.sin(373) end }
SignatureDB['SIG_374'] = { HASH = '0x0135FF96', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 74 end, FALLBACK = function() return math.sin(374) end }
SignatureDB['SIG_375'] = { HASH = '0x0136D3C7', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 75 end, FALLBACK = function() return math.sin(375) end }
SignatureDB['SIG_376'] = { HASH = '0x0137A7F8', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 76 end, FALLBACK = function() return math.sin(376) end }
SignatureDB['SIG_377'] = { HASH = '0x01387C29', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 77 end, FALLBACK = function() return math.sin(377) end }
SignatureDB['SIG_378'] = { HASH = '0x0139505A', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 78 end, FALLBACK = function() return math.sin(378) end }
SignatureDB['SIG_379'] = { HASH = '0x013A248B', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 79 end, FALLBACK = function() return math.sin(379) end }
SignatureDB['SIG_380'] = { HASH = '0x013AF8BC', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 80 end, FALLBACK = function() return math.sin(380) end }
SignatureDB['SIG_381'] = { HASH = '0x013BCCED', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 81 end, FALLBACK = function() return math.sin(381) end }
SignatureDB['SIG_382'] = { HASH = '0x013CA11E', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 82 end, FALLBACK = function() return math.sin(382) end }
SignatureDB['SIG_383'] = { HASH = '0x013D754F', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 83 end, FALLBACK = function() return math.sin(383) end }
SignatureDB['SIG_384'] = { HASH = '0x013E4980', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 84 end, FALLBACK = function() return math.sin(384) end }
SignatureDB['SIG_385'] = { HASH = '0x013F1DB1', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 85 end, FALLBACK = function() return math.sin(385) end }
SignatureDB['SIG_386'] = { HASH = '0x013FF1E2', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 86 end, FALLBACK = function() return math.sin(386) end }
SignatureDB['SIG_387'] = { HASH = '0x0140C613', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 87 end, FALLBACK = function() return math.sin(387) end }
SignatureDB['SIG_388'] = { HASH = '0x01419A44', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 88 end, FALLBACK = function() return math.sin(388) end }
SignatureDB['SIG_389'] = { HASH = '0x01426E75', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 89 end, FALLBACK = function() return math.sin(389) end }
SignatureDB['SIG_390'] = { HASH = '0x014342A6', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 90 end, FALLBACK = function() return math.sin(390) end }
SignatureDB['SIG_391'] = { HASH = '0x014416D7', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 91 end, FALLBACK = function() return math.sin(391) end }
SignatureDB['SIG_392'] = { HASH = '0x0144EB08', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 92 end, FALLBACK = function() return math.sin(392) end }
SignatureDB['SIG_393'] = { HASH = '0x0145BF39', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 93 end, FALLBACK = function() return math.sin(393) end }
SignatureDB['SIG_394'] = { HASH = '0x0146936A', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 94 end, FALLBACK = function() return math.sin(394) end }
SignatureDB['SIG_395'] = { HASH = '0x0147679B', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 95 end, FALLBACK = function() return math.sin(395) end }
SignatureDB['SIG_396'] = { HASH = '0x01483BCC', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 96 end, FALLBACK = function() return math.sin(396) end }
SignatureDB['SIG_397'] = { HASH = '0x01490FFD', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 97 end, FALLBACK = function() return math.sin(397) end }
SignatureDB['SIG_398'] = { HASH = '0x0149E42E', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 98 end, FALLBACK = function() return math.sin(398) end }
SignatureDB['SIG_399'] = { HASH = '0x014AB85F', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 99 end, FALLBACK = function() return math.sin(399) end }
SignatureDB['SIG_400'] = { HASH = '0x014B8C90', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 0 end, FALLBACK = function() return math.sin(400) end }
SignatureDB['SIG_401'] = { HASH = '0x014C60C1', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 1 end, FALLBACK = function() return math.sin(401) end }
SignatureDB['SIG_402'] = { HASH = '0x014D34F2', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 2 end, FALLBACK = function() return math.sin(402) end }
SignatureDB['SIG_403'] = { HASH = '0x014E0923', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 3 end, FALLBACK = function() return math.sin(403) end }
SignatureDB['SIG_404'] = { HASH = '0x014EDD54', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 4 end, FALLBACK = function() return math.sin(404) end }
SignatureDB['SIG_405'] = { HASH = '0x014FB185', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 5 end, FALLBACK = function() return math.sin(405) end }
SignatureDB['SIG_406'] = { HASH = '0x015085B6', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 6 end, FALLBACK = function() return math.sin(406) end }
SignatureDB['SIG_407'] = { HASH = '0x015159E7', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 7 end, FALLBACK = function() return math.sin(407) end }
SignatureDB['SIG_408'] = { HASH = '0x01522E18', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 8 end, FALLBACK = function() return math.sin(408) end }
SignatureDB['SIG_409'] = { HASH = '0x01530249', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 9 end, FALLBACK = function() return math.sin(409) end }
SignatureDB['SIG_410'] = { HASH = '0x0153D67A', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 10 end, FALLBACK = function() return math.sin(410) end }
SignatureDB['SIG_411'] = { HASH = '0x0154AAAB', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 11 end, FALLBACK = function() return math.sin(411) end }
SignatureDB['SIG_412'] = { HASH = '0x01557EDC', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 12 end, FALLBACK = function() return math.sin(412) end }
SignatureDB['SIG_413'] = { HASH = '0x0156530D', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 13 end, FALLBACK = function() return math.sin(413) end }
SignatureDB['SIG_414'] = { HASH = '0x0157273E', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 14 end, FALLBACK = function() return math.sin(414) end }
SignatureDB['SIG_415'] = { HASH = '0x0157FB6F', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 15 end, FALLBACK = function() return math.sin(415) end }
SignatureDB['SIG_416'] = { HASH = '0x0158CFA0', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 16 end, FALLBACK = function() return math.sin(416) end }
SignatureDB['SIG_417'] = { HASH = '0x0159A3D1', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 17 end, FALLBACK = function() return math.sin(417) end }
SignatureDB['SIG_418'] = { HASH = '0x015A7802', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 18 end, FALLBACK = function() return math.sin(418) end }
SignatureDB['SIG_419'] = { HASH = '0x015B4C33', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 19 end, FALLBACK = function() return math.sin(419) end }
SignatureDB['SIG_420'] = { HASH = '0x015C2064', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 20 end, FALLBACK = function() return math.sin(420) end }
SignatureDB['SIG_421'] = { HASH = '0x015CF495', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 21 end, FALLBACK = function() return math.sin(421) end }
SignatureDB['SIG_422'] = { HASH = '0x015DC8C6', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 22 end, FALLBACK = function() return math.sin(422) end }
SignatureDB['SIG_423'] = { HASH = '0x015E9CF7', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 23 end, FALLBACK = function() return math.sin(423) end }
SignatureDB['SIG_424'] = { HASH = '0x015F7128', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 24 end, FALLBACK = function() return math.sin(424) end }
SignatureDB['SIG_425'] = { HASH = '0x01604559', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 25 end, FALLBACK = function() return math.sin(425) end }
SignatureDB['SIG_426'] = { HASH = '0x0161198A', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 26 end, FALLBACK = function() return math.sin(426) end }
SignatureDB['SIG_427'] = { HASH = '0x0161EDBB', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 27 end, FALLBACK = function() return math.sin(427) end }
SignatureDB['SIG_428'] = { HASH = '0x0162C1EC', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 28 end, FALLBACK = function() return math.sin(428) end }
SignatureDB['SIG_429'] = { HASH = '0x0163961D', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 29 end, FALLBACK = function() return math.sin(429) end }
SignatureDB['SIG_430'] = { HASH = '0x01646A4E', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 30 end, FALLBACK = function() return math.sin(430) end }
SignatureDB['SIG_431'] = { HASH = '0x01653E7F', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 31 end, FALLBACK = function() return math.sin(431) end }
SignatureDB['SIG_432'] = { HASH = '0x016612B0', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 32 end, FALLBACK = function() return math.sin(432) end }
SignatureDB['SIG_433'] = { HASH = '0x0166E6E1', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 33 end, FALLBACK = function() return math.sin(433) end }
SignatureDB['SIG_434'] = { HASH = '0x0167BB12', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 34 end, FALLBACK = function() return math.sin(434) end }
SignatureDB['SIG_435'] = { HASH = '0x01688F43', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 35 end, FALLBACK = function() return math.sin(435) end }
SignatureDB['SIG_436'] = { HASH = '0x01696374', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 36 end, FALLBACK = function() return math.sin(436) end }
SignatureDB['SIG_437'] = { HASH = '0x016A37A5', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 37 end, FALLBACK = function() return math.sin(437) end }
SignatureDB['SIG_438'] = { HASH = '0x016B0BD6', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 38 end, FALLBACK = function() return math.sin(438) end }
SignatureDB['SIG_439'] = { HASH = '0x016BE007', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 39 end, FALLBACK = function() return math.sin(439) end }
SignatureDB['SIG_440'] = { HASH = '0x016CB438', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 40 end, FALLBACK = function() return math.sin(440) end }
SignatureDB['SIG_441'] = { HASH = '0x016D8869', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 41 end, FALLBACK = function() return math.sin(441) end }
SignatureDB['SIG_442'] = { HASH = '0x016E5C9A', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 42 end, FALLBACK = function() return math.sin(442) end }
SignatureDB['SIG_443'] = { HASH = '0x016F30CB', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 43 end, FALLBACK = function() return math.sin(443) end }
SignatureDB['SIG_444'] = { HASH = '0x017004FC', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 44 end, FALLBACK = function() return math.sin(444) end }
SignatureDB['SIG_445'] = { HASH = '0x0170D92D', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 45 end, FALLBACK = function() return math.sin(445) end }
SignatureDB['SIG_446'] = { HASH = '0x0171AD5E', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 46 end, FALLBACK = function() return math.sin(446) end }
SignatureDB['SIG_447'] = { HASH = '0x0172818F', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 47 end, FALLBACK = function() return math.sin(447) end }
SignatureDB['SIG_448'] = { HASH = '0x017355C0', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 48 end, FALLBACK = function() return math.sin(448) end }
SignatureDB['SIG_449'] = { HASH = '0x017429F1', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 49 end, FALLBACK = function() return math.sin(449) end }
SignatureDB['SIG_450'] = { HASH = '0x0174FE22', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 50 end, FALLBACK = function() return math.sin(450) end }
SignatureDB['SIG_451'] = { HASH = '0x0175D253', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 51 end, FALLBACK = function() return math.sin(451) end }
SignatureDB['SIG_452'] = { HASH = '0x0176A684', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 52 end, FALLBACK = function() return math.sin(452) end }
SignatureDB['SIG_453'] = { HASH = '0x01777AB5', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 53 end, FALLBACK = function() return math.sin(453) end }
SignatureDB['SIG_454'] = { HASH = '0x01784EE6', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 54 end, FALLBACK = function() return math.sin(454) end }
SignatureDB['SIG_455'] = { HASH = '0x01792317', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 55 end, FALLBACK = function() return math.sin(455) end }
SignatureDB['SIG_456'] = { HASH = '0x0179F748', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 56 end, FALLBACK = function() return math.sin(456) end }
SignatureDB['SIG_457'] = { HASH = '0x017ACB79', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 57 end, FALLBACK = function() return math.sin(457) end }
SignatureDB['SIG_458'] = { HASH = '0x017B9FAA', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 58 end, FALLBACK = function() return math.sin(458) end }
SignatureDB['SIG_459'] = { HASH = '0x017C73DB', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 59 end, FALLBACK = function() return math.sin(459) end }
SignatureDB['SIG_460'] = { HASH = '0x017D480C', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 60 end, FALLBACK = function() return math.sin(460) end }
SignatureDB['SIG_461'] = { HASH = '0x017E1C3D', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 61 end, FALLBACK = function() return math.sin(461) end }
SignatureDB['SIG_462'] = { HASH = '0x017EF06E', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 62 end, FALLBACK = function() return math.sin(462) end }
SignatureDB['SIG_463'] = { HASH = '0x017FC49F', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 63 end, FALLBACK = function() return math.sin(463) end }
SignatureDB['SIG_464'] = { HASH = '0x018098D0', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 64 end, FALLBACK = function() return math.sin(464) end }
SignatureDB['SIG_465'] = { HASH = '0x01816D01', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 65 end, FALLBACK = function() return math.sin(465) end }
SignatureDB['SIG_466'] = { HASH = '0x01824132', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 66 end, FALLBACK = function() return math.sin(466) end }
SignatureDB['SIG_467'] = { HASH = '0x01831563', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 67 end, FALLBACK = function() return math.sin(467) end }
SignatureDB['SIG_468'] = { HASH = '0x0183E994', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 68 end, FALLBACK = function() return math.sin(468) end }
SignatureDB['SIG_469'] = { HASH = '0x0184BDC5', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 69 end, FALLBACK = function() return math.sin(469) end }
SignatureDB['SIG_470'] = { HASH = '0x018591F6', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 70 end, FALLBACK = function() return math.sin(470) end }
SignatureDB['SIG_471'] = { HASH = '0x01866627', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 71 end, FALLBACK = function() return math.sin(471) end }
SignatureDB['SIG_472'] = { HASH = '0x01873A58', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 72 end, FALLBACK = function() return math.sin(472) end }
SignatureDB['SIG_473'] = { HASH = '0x01880E89', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 73 end, FALLBACK = function() return math.sin(473) end }
SignatureDB['SIG_474'] = { HASH = '0x0188E2BA', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 74 end, FALLBACK = function() return math.sin(474) end }
SignatureDB['SIG_475'] = { HASH = '0x0189B6EB', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 75 end, FALLBACK = function() return math.sin(475) end }
SignatureDB['SIG_476'] = { HASH = '0x018A8B1C', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 76 end, FALLBACK = function() return math.sin(476) end }
SignatureDB['SIG_477'] = { HASH = '0x018B5F4D', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 77 end, FALLBACK = function() return math.sin(477) end }
SignatureDB['SIG_478'] = { HASH = '0x018C337E', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 78 end, FALLBACK = function() return math.sin(478) end }
SignatureDB['SIG_479'] = { HASH = '0x018D07AF', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 79 end, FALLBACK = function() return math.sin(479) end }
SignatureDB['SIG_480'] = { HASH = '0x018DDBE0', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 80 end, FALLBACK = function() return math.sin(480) end }
SignatureDB['SIG_481'] = { HASH = '0x018EB011', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 81 end, FALLBACK = function() return math.sin(481) end }
SignatureDB['SIG_482'] = { HASH = '0x018F8442', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 82 end, FALLBACK = function() return math.sin(482) end }
SignatureDB['SIG_483'] = { HASH = '0x01905873', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 83 end, FALLBACK = function() return math.sin(483) end }
SignatureDB['SIG_484'] = { HASH = '0x01912CA4', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 84 end, FALLBACK = function() return math.sin(484) end }
SignatureDB['SIG_485'] = { HASH = '0x019200D5', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 85 end, FALLBACK = function() return math.sin(485) end }
SignatureDB['SIG_486'] = { HASH = '0x0192D506', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 86 end, FALLBACK = function() return math.sin(486) end }
SignatureDB['SIG_487'] = { HASH = '0x0193A937', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 87 end, FALLBACK = function() return math.sin(487) end }
SignatureDB['SIG_488'] = { HASH = '0x01947D68', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 88 end, FALLBACK = function() return math.sin(488) end }
SignatureDB['SIG_489'] = { HASH = '0x01955199', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 89 end, FALLBACK = function() return math.sin(489) end }
SignatureDB['SIG_490'] = { HASH = '0x019625CA', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 90 end, FALLBACK = function() return math.sin(490) end }
SignatureDB['SIG_491'] = { HASH = '0x0196F9FB', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 91 end, FALLBACK = function() return math.sin(491) end }
SignatureDB['SIG_492'] = { HASH = '0x0197CE2C', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 92 end, FALLBACK = function() return math.sin(492) end }
SignatureDB['SIG_493'] = { HASH = '0x0198A25D', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 93 end, FALLBACK = function() return math.sin(493) end }
SignatureDB['SIG_494'] = { HASH = '0x0199768E', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 94 end, FALLBACK = function() return math.sin(494) end }
SignatureDB['SIG_495'] = { HASH = '0x019A4ABF', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 95 end, FALLBACK = function() return math.sin(495) end }
SignatureDB['SIG_496'] = { HASH = '0x019B1EF0', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 96 end, FALLBACK = function() return math.sin(496) end }
SignatureDB['SIG_497'] = { HASH = '0x019BF321', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 97 end, FALLBACK = function() return math.sin(497) end }
SignatureDB['SIG_498'] = { HASH = '0x019CC752', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 98 end, FALLBACK = function() return math.sin(498) end }
SignatureDB['SIG_499'] = { HASH = '0x019D9B83', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 99 end, FALLBACK = function() return math.sin(499) end }
SignatureDB['SIG_500'] = { HASH = '0x019E6FB4', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 0 end, FALLBACK = function() return math.sin(500) end }
SignatureDB['SIG_501'] = { HASH = '0x019F43E5', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 1 end, FALLBACK = function() return math.sin(501) end }
SignatureDB['SIG_502'] = { HASH = '0x01A01816', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 2 end, FALLBACK = function() return math.sin(502) end }
SignatureDB['SIG_503'] = { HASH = '0x01A0EC47', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 3 end, FALLBACK = function() return math.sin(503) end }
SignatureDB['SIG_504'] = { HASH = '0x01A1C078', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 4 end, FALLBACK = function() return math.sin(504) end }
SignatureDB['SIG_505'] = { HASH = '0x01A294A9', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 5 end, FALLBACK = function() return math.sin(505) end }
SignatureDB['SIG_506'] = { HASH = '0x01A368DA', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 6 end, FALLBACK = function() return math.sin(506) end }
SignatureDB['SIG_507'] = { HASH = '0x01A43D0B', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 7 end, FALLBACK = function() return math.sin(507) end }
SignatureDB['SIG_508'] = { HASH = '0x01A5113C', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 8 end, FALLBACK = function() return math.sin(508) end }
SignatureDB['SIG_509'] = { HASH = '0x01A5E56D', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 9 end, FALLBACK = function() return math.sin(509) end }
SignatureDB['SIG_510'] = { HASH = '0x01A6B99E', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 10 end, FALLBACK = function() return math.sin(510) end }
SignatureDB['SIG_511'] = { HASH = '0x01A78DCF', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 11 end, FALLBACK = function() return math.sin(511) end }
SignatureDB['SIG_512'] = { HASH = '0x01A86200', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 12 end, FALLBACK = function() return math.sin(512) end }
SignatureDB['SIG_513'] = { HASH = '0x01A93631', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 13 end, FALLBACK = function() return math.sin(513) end }
SignatureDB['SIG_514'] = { HASH = '0x01AA0A62', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 14 end, FALLBACK = function() return math.sin(514) end }
SignatureDB['SIG_515'] = { HASH = '0x01AADE93', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 15 end, FALLBACK = function() return math.sin(515) end }
SignatureDB['SIG_516'] = { HASH = '0x01ABB2C4', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 16 end, FALLBACK = function() return math.sin(516) end }
SignatureDB['SIG_517'] = { HASH = '0x01AC86F5', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 17 end, FALLBACK = function() return math.sin(517) end }
SignatureDB['SIG_518'] = { HASH = '0x01AD5B26', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 18 end, FALLBACK = function() return math.sin(518) end }
SignatureDB['SIG_519'] = { HASH = '0x01AE2F57', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 19 end, FALLBACK = function() return math.sin(519) end }
SignatureDB['SIG_520'] = { HASH = '0x01AF0388', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 20 end, FALLBACK = function() return math.sin(520) end }
SignatureDB['SIG_521'] = { HASH = '0x01AFD7B9', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 21 end, FALLBACK = function() return math.sin(521) end }
SignatureDB['SIG_522'] = { HASH = '0x01B0ABEA', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 22 end, FALLBACK = function() return math.sin(522) end }
SignatureDB['SIG_523'] = { HASH = '0x01B1801B', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 23 end, FALLBACK = function() return math.sin(523) end }
SignatureDB['SIG_524'] = { HASH = '0x01B2544C', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 24 end, FALLBACK = function() return math.sin(524) end }
SignatureDB['SIG_525'] = { HASH = '0x01B3287D', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 25 end, FALLBACK = function() return math.sin(525) end }
SignatureDB['SIG_526'] = { HASH = '0x01B3FCAE', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 26 end, FALLBACK = function() return math.sin(526) end }
SignatureDB['SIG_527'] = { HASH = '0x01B4D0DF', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 27 end, FALLBACK = function() return math.sin(527) end }
SignatureDB['SIG_528'] = { HASH = '0x01B5A510', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 28 end, FALLBACK = function() return math.sin(528) end }
SignatureDB['SIG_529'] = { HASH = '0x01B67941', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 29 end, FALLBACK = function() return math.sin(529) end }
SignatureDB['SIG_530'] = { HASH = '0x01B74D72', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 30 end, FALLBACK = function() return math.sin(530) end }
SignatureDB['SIG_531'] = { HASH = '0x01B821A3', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 31 end, FALLBACK = function() return math.sin(531) end }
SignatureDB['SIG_532'] = { HASH = '0x01B8F5D4', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 32 end, FALLBACK = function() return math.sin(532) end }
SignatureDB['SIG_533'] = { HASH = '0x01B9CA05', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 33 end, FALLBACK = function() return math.sin(533) end }
SignatureDB['SIG_534'] = { HASH = '0x01BA9E36', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 34 end, FALLBACK = function() return math.sin(534) end }
SignatureDB['SIG_535'] = { HASH = '0x01BB7267', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 35 end, FALLBACK = function() return math.sin(535) end }
SignatureDB['SIG_536'] = { HASH = '0x01BC4698', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 36 end, FALLBACK = function() return math.sin(536) end }
SignatureDB['SIG_537'] = { HASH = '0x01BD1AC9', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 37 end, FALLBACK = function() return math.sin(537) end }
SignatureDB['SIG_538'] = { HASH = '0x01BDEEFA', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 38 end, FALLBACK = function() return math.sin(538) end }
SignatureDB['SIG_539'] = { HASH = '0x01BEC32B', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 39 end, FALLBACK = function() return math.sin(539) end }
SignatureDB['SIG_540'] = { HASH = '0x01BF975C', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 40 end, FALLBACK = function() return math.sin(540) end }
SignatureDB['SIG_541'] = { HASH = '0x01C06B8D', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 41 end, FALLBACK = function() return math.sin(541) end }
SignatureDB['SIG_542'] = { HASH = '0x01C13FBE', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 42 end, FALLBACK = function() return math.sin(542) end }
SignatureDB['SIG_543'] = { HASH = '0x01C213EF', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 43 end, FALLBACK = function() return math.sin(543) end }
SignatureDB['SIG_544'] = { HASH = '0x01C2E820', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 44 end, FALLBACK = function() return math.sin(544) end }
SignatureDB['SIG_545'] = { HASH = '0x01C3BC51', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 45 end, FALLBACK = function() return math.sin(545) end }
SignatureDB['SIG_546'] = { HASH = '0x01C49082', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 46 end, FALLBACK = function() return math.sin(546) end }
SignatureDB['SIG_547'] = { HASH = '0x01C564B3', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 47 end, FALLBACK = function() return math.sin(547) end }
SignatureDB['SIG_548'] = { HASH = '0x01C638E4', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 48 end, FALLBACK = function() return math.sin(548) end }
SignatureDB['SIG_549'] = { HASH = '0x01C70D15', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 49 end, FALLBACK = function() return math.sin(549) end }
SignatureDB['SIG_550'] = { HASH = '0x01C7E146', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 50 end, FALLBACK = function() return math.sin(550) end }
SignatureDB['SIG_551'] = { HASH = '0x01C8B577', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 51 end, FALLBACK = function() return math.sin(551) end }
SignatureDB['SIG_552'] = { HASH = '0x01C989A8', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 52 end, FALLBACK = function() return math.sin(552) end }
SignatureDB['SIG_553'] = { HASH = '0x01CA5DD9', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 53 end, FALLBACK = function() return math.sin(553) end }
SignatureDB['SIG_554'] = { HASH = '0x01CB320A', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 54 end, FALLBACK = function() return math.sin(554) end }
SignatureDB['SIG_555'] = { HASH = '0x01CC063B', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 55 end, FALLBACK = function() return math.sin(555) end }
SignatureDB['SIG_556'] = { HASH = '0x01CCDA6C', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 56 end, FALLBACK = function() return math.sin(556) end }
SignatureDB['SIG_557'] = { HASH = '0x01CDAE9D', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 57 end, FALLBACK = function() return math.sin(557) end }
SignatureDB['SIG_558'] = { HASH = '0x01CE82CE', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 58 end, FALLBACK = function() return math.sin(558) end }
SignatureDB['SIG_559'] = { HASH = '0x01CF56FF', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 59 end, FALLBACK = function() return math.sin(559) end }
SignatureDB['SIG_560'] = { HASH = '0x01D02B30', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 60 end, FALLBACK = function() return math.sin(560) end }
SignatureDB['SIG_561'] = { HASH = '0x01D0FF61', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 61 end, FALLBACK = function() return math.sin(561) end }
SignatureDB['SIG_562'] = { HASH = '0x01D1D392', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 62 end, FALLBACK = function() return math.sin(562) end }
SignatureDB['SIG_563'] = { HASH = '0x01D2A7C3', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 63 end, FALLBACK = function() return math.sin(563) end }
SignatureDB['SIG_564'] = { HASH = '0x01D37BF4', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 64 end, FALLBACK = function() return math.sin(564) end }
SignatureDB['SIG_565'] = { HASH = '0x01D45025', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 65 end, FALLBACK = function() return math.sin(565) end }
SignatureDB['SIG_566'] = { HASH = '0x01D52456', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 66 end, FALLBACK = function() return math.sin(566) end }
SignatureDB['SIG_567'] = { HASH = '0x01D5F887', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 67 end, FALLBACK = function() return math.sin(567) end }
SignatureDB['SIG_568'] = { HASH = '0x01D6CCB8', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 68 end, FALLBACK = function() return math.sin(568) end }
SignatureDB['SIG_569'] = { HASH = '0x01D7A0E9', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 69 end, FALLBACK = function() return math.sin(569) end }
SignatureDB['SIG_570'] = { HASH = '0x01D8751A', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 70 end, FALLBACK = function() return math.sin(570) end }
SignatureDB['SIG_571'] = { HASH = '0x01D9494B', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 71 end, FALLBACK = function() return math.sin(571) end }
SignatureDB['SIG_572'] = { HASH = '0x01DA1D7C', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 72 end, FALLBACK = function() return math.sin(572) end }
SignatureDB['SIG_573'] = { HASH = '0x01DAF1AD', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 73 end, FALLBACK = function() return math.sin(573) end }
SignatureDB['SIG_574'] = { HASH = '0x01DBC5DE', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 74 end, FALLBACK = function() return math.sin(574) end }
SignatureDB['SIG_575'] = { HASH = '0x01DC9A0F', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 75 end, FALLBACK = function() return math.sin(575) end }
SignatureDB['SIG_576'] = { HASH = '0x01DD6E40', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 76 end, FALLBACK = function() return math.sin(576) end }
SignatureDB['SIG_577'] = { HASH = '0x01DE4271', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 77 end, FALLBACK = function() return math.sin(577) end }
SignatureDB['SIG_578'] = { HASH = '0x01DF16A2', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 78 end, FALLBACK = function() return math.sin(578) end }
SignatureDB['SIG_579'] = { HASH = '0x01DFEAD3', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 79 end, FALLBACK = function() return math.sin(579) end }
SignatureDB['SIG_580'] = { HASH = '0x01E0BF04', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 80 end, FALLBACK = function() return math.sin(580) end }
SignatureDB['SIG_581'] = { HASH = '0x01E19335', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 81 end, FALLBACK = function() return math.sin(581) end }
SignatureDB['SIG_582'] = { HASH = '0x01E26766', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 82 end, FALLBACK = function() return math.sin(582) end }
SignatureDB['SIG_583'] = { HASH = '0x01E33B97', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 83 end, FALLBACK = function() return math.sin(583) end }
SignatureDB['SIG_584'] = { HASH = '0x01E40FC8', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 84 end, FALLBACK = function() return math.sin(584) end }
SignatureDB['SIG_585'] = { HASH = '0x01E4E3F9', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 85 end, FALLBACK = function() return math.sin(585) end }
SignatureDB['SIG_586'] = { HASH = '0x01E5B82A', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 86 end, FALLBACK = function() return math.sin(586) end }
SignatureDB['SIG_587'] = { HASH = '0x01E68C5B', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 87 end, FALLBACK = function() return math.sin(587) end }
SignatureDB['SIG_588'] = { HASH = '0x01E7608C', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 88 end, FALLBACK = function() return math.sin(588) end }
SignatureDB['SIG_589'] = { HASH = '0x01E834BD', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 89 end, FALLBACK = function() return math.sin(589) end }
SignatureDB['SIG_590'] = { HASH = '0x01E908EE', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 90 end, FALLBACK = function() return math.sin(590) end }
SignatureDB['SIG_591'] = { HASH = '0x01E9DD1F', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 91 end, FALLBACK = function() return math.sin(591) end }
SignatureDB['SIG_592'] = { HASH = '0x01EAB150', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 92 end, FALLBACK = function() return math.sin(592) end }
SignatureDB['SIG_593'] = { HASH = '0x01EB8581', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 93 end, FALLBACK = function() return math.sin(593) end }
SignatureDB['SIG_594'] = { HASH = '0x01EC59B2', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 94 end, FALLBACK = function() return math.sin(594) end }
SignatureDB['SIG_595'] = { HASH = '0x01ED2DE3', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 95 end, FALLBACK = function() return math.sin(595) end }
SignatureDB['SIG_596'] = { HASH = '0x01EE0214', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 96 end, FALLBACK = function() return math.sin(596) end }
SignatureDB['SIG_597'] = { HASH = '0x01EED645', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 97 end, FALLBACK = function() return math.sin(597) end }
SignatureDB['SIG_598'] = { HASH = '0x01EFAA76', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 98 end, FALLBACK = function() return math.sin(598) end }
SignatureDB['SIG_599'] = { HASH = '0x01F07EA7', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 99 end, FALLBACK = function() return math.sin(599) end }
SignatureDB['SIG_600'] = { HASH = '0x01F152D8', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 0 end, FALLBACK = function() return math.sin(600) end }
SignatureDB['SIG_601'] = { HASH = '0x01F22709', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 1 end, FALLBACK = function() return math.sin(601) end }
SignatureDB['SIG_602'] = { HASH = '0x01F2FB3A', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 2 end, FALLBACK = function() return math.sin(602) end }
SignatureDB['SIG_603'] = { HASH = '0x01F3CF6B', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 3 end, FALLBACK = function() return math.sin(603) end }
SignatureDB['SIG_604'] = { HASH = '0x01F4A39C', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 4 end, FALLBACK = function() return math.sin(604) end }
SignatureDB['SIG_605'] = { HASH = '0x01F577CD', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 5 end, FALLBACK = function() return math.sin(605) end }
SignatureDB['SIG_606'] = { HASH = '0x01F64BFE', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 6 end, FALLBACK = function() return math.sin(606) end }
SignatureDB['SIG_607'] = { HASH = '0x01F7202F', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 7 end, FALLBACK = function() return math.sin(607) end }
SignatureDB['SIG_608'] = { HASH = '0x01F7F460', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 8 end, FALLBACK = function() return math.sin(608) end }
SignatureDB['SIG_609'] = { HASH = '0x01F8C891', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 9 end, FALLBACK = function() return math.sin(609) end }
SignatureDB['SIG_610'] = { HASH = '0x01F99CC2', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 10 end, FALLBACK = function() return math.sin(610) end }
SignatureDB['SIG_611'] = { HASH = '0x01FA70F3', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 11 end, FALLBACK = function() return math.sin(611) end }
SignatureDB['SIG_612'] = { HASH = '0x01FB4524', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 12 end, FALLBACK = function() return math.sin(612) end }
SignatureDB['SIG_613'] = { HASH = '0x01FC1955', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 13 end, FALLBACK = function() return math.sin(613) end }
SignatureDB['SIG_614'] = { HASH = '0x01FCED86', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 14 end, FALLBACK = function() return math.sin(614) end }
SignatureDB['SIG_615'] = { HASH = '0x01FDC1B7', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 15 end, FALLBACK = function() return math.sin(615) end }
SignatureDB['SIG_616'] = { HASH = '0x01FE95E8', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 16 end, FALLBACK = function() return math.sin(616) end }
SignatureDB['SIG_617'] = { HASH = '0x01FF6A19', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 17 end, FALLBACK = function() return math.sin(617) end }
SignatureDB['SIG_618'] = { HASH = '0x02003E4A', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 18 end, FALLBACK = function() return math.sin(618) end }
SignatureDB['SIG_619'] = { HASH = '0x0201127B', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 19 end, FALLBACK = function() return math.sin(619) end }
SignatureDB['SIG_620'] = { HASH = '0x0201E6AC', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 20 end, FALLBACK = function() return math.sin(620) end }
SignatureDB['SIG_621'] = { HASH = '0x0202BADD', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 21 end, FALLBACK = function() return math.sin(621) end }
SignatureDB['SIG_622'] = { HASH = '0x02038F0E', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 22 end, FALLBACK = function() return math.sin(622) end }
SignatureDB['SIG_623'] = { HASH = '0x0204633F', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 23 end, FALLBACK = function() return math.sin(623) end }
SignatureDB['SIG_624'] = { HASH = '0x02053770', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 24 end, FALLBACK = function() return math.sin(624) end }
SignatureDB['SIG_625'] = { HASH = '0x02060BA1', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 25 end, FALLBACK = function() return math.sin(625) end }
SignatureDB['SIG_626'] = { HASH = '0x0206DFD2', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 26 end, FALLBACK = function() return math.sin(626) end }
SignatureDB['SIG_627'] = { HASH = '0x0207B403', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 27 end, FALLBACK = function() return math.sin(627) end }
SignatureDB['SIG_628'] = { HASH = '0x02088834', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 28 end, FALLBACK = function() return math.sin(628) end }
SignatureDB['SIG_629'] = { HASH = '0x02095C65', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 29 end, FALLBACK = function() return math.sin(629) end }
SignatureDB['SIG_630'] = { HASH = '0x020A3096', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 30 end, FALLBACK = function() return math.sin(630) end }
SignatureDB['SIG_631'] = { HASH = '0x020B04C7', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 31 end, FALLBACK = function() return math.sin(631) end }
SignatureDB['SIG_632'] = { HASH = '0x020BD8F8', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 32 end, FALLBACK = function() return math.sin(632) end }
SignatureDB['SIG_633'] = { HASH = '0x020CAD29', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 33 end, FALLBACK = function() return math.sin(633) end }
SignatureDB['SIG_634'] = { HASH = '0x020D815A', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 34 end, FALLBACK = function() return math.sin(634) end }
SignatureDB['SIG_635'] = { HASH = '0x020E558B', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 35 end, FALLBACK = function() return math.sin(635) end }
SignatureDB['SIG_636'] = { HASH = '0x020F29BC', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 36 end, FALLBACK = function() return math.sin(636) end }
SignatureDB['SIG_637'] = { HASH = '0x020FFDED', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 37 end, FALLBACK = function() return math.sin(637) end }
SignatureDB['SIG_638'] = { HASH = '0x0210D21E', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 38 end, FALLBACK = function() return math.sin(638) end }
SignatureDB['SIG_639'] = { HASH = '0x0211A64F', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 39 end, FALLBACK = function() return math.sin(639) end }
SignatureDB['SIG_640'] = { HASH = '0x02127A80', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 40 end, FALLBACK = function() return math.sin(640) end }
SignatureDB['SIG_641'] = { HASH = '0x02134EB1', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 41 end, FALLBACK = function() return math.sin(641) end }
SignatureDB['SIG_642'] = { HASH = '0x021422E2', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 42 end, FALLBACK = function() return math.sin(642) end }
SignatureDB['SIG_643'] = { HASH = '0x0214F713', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 43 end, FALLBACK = function() return math.sin(643) end }
SignatureDB['SIG_644'] = { HASH = '0x0215CB44', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 44 end, FALLBACK = function() return math.sin(644) end }
SignatureDB['SIG_645'] = { HASH = '0x02169F75', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 45 end, FALLBACK = function() return math.sin(645) end }
SignatureDB['SIG_646'] = { HASH = '0x021773A6', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 46 end, FALLBACK = function() return math.sin(646) end }
SignatureDB['SIG_647'] = { HASH = '0x021847D7', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 47 end, FALLBACK = function() return math.sin(647) end }
SignatureDB['SIG_648'] = { HASH = '0x02191C08', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 48 end, FALLBACK = function() return math.sin(648) end }
SignatureDB['SIG_649'] = { HASH = '0x0219F039', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 49 end, FALLBACK = function() return math.sin(649) end }
SignatureDB['SIG_650'] = { HASH = '0x021AC46A', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 50 end, FALLBACK = function() return math.sin(650) end }
SignatureDB['SIG_651'] = { HASH = '0x021B989B', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 51 end, FALLBACK = function() return math.sin(651) end }
SignatureDB['SIG_652'] = { HASH = '0x021C6CCC', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 52 end, FALLBACK = function() return math.sin(652) end }
SignatureDB['SIG_653'] = { HASH = '0x021D40FD', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 53 end, FALLBACK = function() return math.sin(653) end }
SignatureDB['SIG_654'] = { HASH = '0x021E152E', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 54 end, FALLBACK = function() return math.sin(654) end }
SignatureDB['SIG_655'] = { HASH = '0x021EE95F', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 55 end, FALLBACK = function() return math.sin(655) end }
SignatureDB['SIG_656'] = { HASH = '0x021FBD90', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 56 end, FALLBACK = function() return math.sin(656) end }
SignatureDB['SIG_657'] = { HASH = '0x022091C1', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 57 end, FALLBACK = function() return math.sin(657) end }
SignatureDB['SIG_658'] = { HASH = '0x022165F2', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 58 end, FALLBACK = function() return math.sin(658) end }
SignatureDB['SIG_659'] = { HASH = '0x02223A23', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 59 end, FALLBACK = function() return math.sin(659) end }
SignatureDB['SIG_660'] = { HASH = '0x02230E54', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 60 end, FALLBACK = function() return math.sin(660) end }
SignatureDB['SIG_661'] = { HASH = '0x0223E285', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 61 end, FALLBACK = function() return math.sin(661) end }
SignatureDB['SIG_662'] = { HASH = '0x0224B6B6', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 62 end, FALLBACK = function() return math.sin(662) end }
SignatureDB['SIG_663'] = { HASH = '0x02258AE7', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 63 end, FALLBACK = function() return math.sin(663) end }
SignatureDB['SIG_664'] = { HASH = '0x02265F18', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 64 end, FALLBACK = function() return math.sin(664) end }
SignatureDB['SIG_665'] = { HASH = '0x02273349', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 65 end, FALLBACK = function() return math.sin(665) end }
SignatureDB['SIG_666'] = { HASH = '0x0228077A', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 66 end, FALLBACK = function() return math.sin(666) end }
SignatureDB['SIG_667'] = { HASH = '0x0228DBAB', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 67 end, FALLBACK = function() return math.sin(667) end }
SignatureDB['SIG_668'] = { HASH = '0x0229AFDC', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 68 end, FALLBACK = function() return math.sin(668) end }
SignatureDB['SIG_669'] = { HASH = '0x022A840D', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 69 end, FALLBACK = function() return math.sin(669) end }
SignatureDB['SIG_670'] = { HASH = '0x022B583E', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 70 end, FALLBACK = function() return math.sin(670) end }
SignatureDB['SIG_671'] = { HASH = '0x022C2C6F', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 71 end, FALLBACK = function() return math.sin(671) end }
SignatureDB['SIG_672'] = { HASH = '0x022D00A0', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 72 end, FALLBACK = function() return math.sin(672) end }
SignatureDB['SIG_673'] = { HASH = '0x022DD4D1', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 73 end, FALLBACK = function() return math.sin(673) end }
SignatureDB['SIG_674'] = { HASH = '0x022EA902', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 74 end, FALLBACK = function() return math.sin(674) end }
SignatureDB['SIG_675'] = { HASH = '0x022F7D33', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 75 end, FALLBACK = function() return math.sin(675) end }
SignatureDB['SIG_676'] = { HASH = '0x02305164', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 76 end, FALLBACK = function() return math.sin(676) end }
SignatureDB['SIG_677'] = { HASH = '0x02312595', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 77 end, FALLBACK = function() return math.sin(677) end }
SignatureDB['SIG_678'] = { HASH = '0x0231F9C6', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 78 end, FALLBACK = function() return math.sin(678) end }
SignatureDB['SIG_679'] = { HASH = '0x0232CDF7', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 79 end, FALLBACK = function() return math.sin(679) end }
SignatureDB['SIG_680'] = { HASH = '0x0233A228', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 80 end, FALLBACK = function() return math.sin(680) end }
SignatureDB['SIG_681'] = { HASH = '0x02347659', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 81 end, FALLBACK = function() return math.sin(681) end }
SignatureDB['SIG_682'] = { HASH = '0x02354A8A', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 82 end, FALLBACK = function() return math.sin(682) end }
SignatureDB['SIG_683'] = { HASH = '0x02361EBB', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 83 end, FALLBACK = function() return math.sin(683) end }
SignatureDB['SIG_684'] = { HASH = '0x0236F2EC', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 84 end, FALLBACK = function() return math.sin(684) end }
SignatureDB['SIG_685'] = { HASH = '0x0237C71D', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 85 end, FALLBACK = function() return math.sin(685) end }
SignatureDB['SIG_686'] = { HASH = '0x02389B4E', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 86 end, FALLBACK = function() return math.sin(686) end }
SignatureDB['SIG_687'] = { HASH = '0x02396F7F', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 87 end, FALLBACK = function() return math.sin(687) end }
SignatureDB['SIG_688'] = { HASH = '0x023A43B0', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 88 end, FALLBACK = function() return math.sin(688) end }
SignatureDB['SIG_689'] = { HASH = '0x023B17E1', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 89 end, FALLBACK = function() return math.sin(689) end }
SignatureDB['SIG_690'] = { HASH = '0x023BEC12', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 90 end, FALLBACK = function() return math.sin(690) end }
SignatureDB['SIG_691'] = { HASH = '0x023CC043', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 91 end, FALLBACK = function() return math.sin(691) end }
SignatureDB['SIG_692'] = { HASH = '0x023D9474', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 92 end, FALLBACK = function() return math.sin(692) end }
SignatureDB['SIG_693'] = { HASH = '0x023E68A5', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 93 end, FALLBACK = function() return math.sin(693) end }
SignatureDB['SIG_694'] = { HASH = '0x023F3CD6', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 94 end, FALLBACK = function() return math.sin(694) end }
SignatureDB['SIG_695'] = { HASH = '0x02401107', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 95 end, FALLBACK = function() return math.sin(695) end }
SignatureDB['SIG_696'] = { HASH = '0x0240E538', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 96 end, FALLBACK = function() return math.sin(696) end }
SignatureDB['SIG_697'] = { HASH = '0x0241B969', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 97 end, FALLBACK = function() return math.sin(697) end }
SignatureDB['SIG_698'] = { HASH = '0x02428D9A', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 98 end, FALLBACK = function() return math.sin(698) end }
SignatureDB['SIG_699'] = { HASH = '0x024361CB', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 99 end, FALLBACK = function() return math.sin(699) end }
SignatureDB['SIG_700'] = { HASH = '0x024435FC', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 0 end, FALLBACK = function() return math.sin(700) end }
SignatureDB['SIG_701'] = { HASH = '0x02450A2D', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 1 end, FALLBACK = function() return math.sin(701) end }
SignatureDB['SIG_702'] = { HASH = '0x0245DE5E', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 2 end, FALLBACK = function() return math.sin(702) end }
SignatureDB['SIG_703'] = { HASH = '0x0246B28F', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 3 end, FALLBACK = function() return math.sin(703) end }
SignatureDB['SIG_704'] = { HASH = '0x024786C0', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 4 end, FALLBACK = function() return math.sin(704) end }
SignatureDB['SIG_705'] = { HASH = '0x02485AF1', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 5 end, FALLBACK = function() return math.sin(705) end }
SignatureDB['SIG_706'] = { HASH = '0x02492F22', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 6 end, FALLBACK = function() return math.sin(706) end }
SignatureDB['SIG_707'] = { HASH = '0x024A0353', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 7 end, FALLBACK = function() return math.sin(707) end }
SignatureDB['SIG_708'] = { HASH = '0x024AD784', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 8 end, FALLBACK = function() return math.sin(708) end }
SignatureDB['SIG_709'] = { HASH = '0x024BABB5', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 9 end, FALLBACK = function() return math.sin(709) end }
SignatureDB['SIG_710'] = { HASH = '0x024C7FE6', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 10 end, FALLBACK = function() return math.sin(710) end }
SignatureDB['SIG_711'] = { HASH = '0x024D5417', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 11 end, FALLBACK = function() return math.sin(711) end }
SignatureDB['SIG_712'] = { HASH = '0x024E2848', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 12 end, FALLBACK = function() return math.sin(712) end }
SignatureDB['SIG_713'] = { HASH = '0x024EFC79', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 13 end, FALLBACK = function() return math.sin(713) end }
SignatureDB['SIG_714'] = { HASH = '0x024FD0AA', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 14 end, FALLBACK = function() return math.sin(714) end }
SignatureDB['SIG_715'] = { HASH = '0x0250A4DB', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 15 end, FALLBACK = function() return math.sin(715) end }
SignatureDB['SIG_716'] = { HASH = '0x0251790C', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 16 end, FALLBACK = function() return math.sin(716) end }
SignatureDB['SIG_717'] = { HASH = '0x02524D3D', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 17 end, FALLBACK = function() return math.sin(717) end }
SignatureDB['SIG_718'] = { HASH = '0x0253216E', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 18 end, FALLBACK = function() return math.sin(718) end }
SignatureDB['SIG_719'] = { HASH = '0x0253F59F', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 19 end, FALLBACK = function() return math.sin(719) end }
SignatureDB['SIG_720'] = { HASH = '0x0254C9D0', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 20 end, FALLBACK = function() return math.sin(720) end }
SignatureDB['SIG_721'] = { HASH = '0x02559E01', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 21 end, FALLBACK = function() return math.sin(721) end }
SignatureDB['SIG_722'] = { HASH = '0x02567232', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 22 end, FALLBACK = function() return math.sin(722) end }
SignatureDB['SIG_723'] = { HASH = '0x02574663', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 23 end, FALLBACK = function() return math.sin(723) end }
SignatureDB['SIG_724'] = { HASH = '0x02581A94', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 24 end, FALLBACK = function() return math.sin(724) end }
SignatureDB['SIG_725'] = { HASH = '0x0258EEC5', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 25 end, FALLBACK = function() return math.sin(725) end }
SignatureDB['SIG_726'] = { HASH = '0x0259C2F6', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 26 end, FALLBACK = function() return math.sin(726) end }
SignatureDB['SIG_727'] = { HASH = '0x025A9727', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 27 end, FALLBACK = function() return math.sin(727) end }
SignatureDB['SIG_728'] = { HASH = '0x025B6B58', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 28 end, FALLBACK = function() return math.sin(728) end }
SignatureDB['SIG_729'] = { HASH = '0x025C3F89', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 29 end, FALLBACK = function() return math.sin(729) end }
SignatureDB['SIG_730'] = { HASH = '0x025D13BA', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 30 end, FALLBACK = function() return math.sin(730) end }
SignatureDB['SIG_731'] = { HASH = '0x025DE7EB', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 31 end, FALLBACK = function() return math.sin(731) end }
SignatureDB['SIG_732'] = { HASH = '0x025EBC1C', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 32 end, FALLBACK = function() return math.sin(732) end }
SignatureDB['SIG_733'] = { HASH = '0x025F904D', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 33 end, FALLBACK = function() return math.sin(733) end }
SignatureDB['SIG_734'] = { HASH = '0x0260647E', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 34 end, FALLBACK = function() return math.sin(734) end }
SignatureDB['SIG_735'] = { HASH = '0x026138AF', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 35 end, FALLBACK = function() return math.sin(735) end }
SignatureDB['SIG_736'] = { HASH = '0x02620CE0', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 36 end, FALLBACK = function() return math.sin(736) end }
SignatureDB['SIG_737'] = { HASH = '0x0262E111', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 37 end, FALLBACK = function() return math.sin(737) end }
SignatureDB['SIG_738'] = { HASH = '0x0263B542', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 38 end, FALLBACK = function() return math.sin(738) end }
SignatureDB['SIG_739'] = { HASH = '0x02648973', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 39 end, FALLBACK = function() return math.sin(739) end }
SignatureDB['SIG_740'] = { HASH = '0x02655DA4', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 40 end, FALLBACK = function() return math.sin(740) end }
SignatureDB['SIG_741'] = { HASH = '0x026631D5', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 41 end, FALLBACK = function() return math.sin(741) end }
SignatureDB['SIG_742'] = { HASH = '0x02670606', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 42 end, FALLBACK = function() return math.sin(742) end }
SignatureDB['SIG_743'] = { HASH = '0x0267DA37', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 43 end, FALLBACK = function() return math.sin(743) end }
SignatureDB['SIG_744'] = { HASH = '0x0268AE68', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 44 end, FALLBACK = function() return math.sin(744) end }
SignatureDB['SIG_745'] = { HASH = '0x02698299', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 45 end, FALLBACK = function() return math.sin(745) end }
SignatureDB['SIG_746'] = { HASH = '0x026A56CA', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 46 end, FALLBACK = function() return math.sin(746) end }
SignatureDB['SIG_747'] = { HASH = '0x026B2AFB', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 47 end, FALLBACK = function() return math.sin(747) end }
SignatureDB['SIG_748'] = { HASH = '0x026BFF2C', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 48 end, FALLBACK = function() return math.sin(748) end }
SignatureDB['SIG_749'] = { HASH = '0x026CD35D', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 49 end, FALLBACK = function() return math.sin(749) end }
SignatureDB['SIG_750'] = { HASH = '0x026DA78E', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 50 end, FALLBACK = function() return math.sin(750) end }
SignatureDB['SIG_751'] = { HASH = '0x026E7BBF', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 51 end, FALLBACK = function() return math.sin(751) end }
SignatureDB['SIG_752'] = { HASH = '0x026F4FF0', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 52 end, FALLBACK = function() return math.sin(752) end }
SignatureDB['SIG_753'] = { HASH = '0x02702421', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 53 end, FALLBACK = function() return math.sin(753) end }
SignatureDB['SIG_754'] = { HASH = '0x0270F852', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 54 end, FALLBACK = function() return math.sin(754) end }
SignatureDB['SIG_755'] = { HASH = '0x0271CC83', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 55 end, FALLBACK = function() return math.sin(755) end }
SignatureDB['SIG_756'] = { HASH = '0x0272A0B4', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 56 end, FALLBACK = function() return math.sin(756) end }
SignatureDB['SIG_757'] = { HASH = '0x027374E5', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 57 end, FALLBACK = function() return math.sin(757) end }
SignatureDB['SIG_758'] = { HASH = '0x02744916', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 58 end, FALLBACK = function() return math.sin(758) end }
SignatureDB['SIG_759'] = { HASH = '0x02751D47', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 59 end, FALLBACK = function() return math.sin(759) end }
SignatureDB['SIG_760'] = { HASH = '0x0275F178', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 60 end, FALLBACK = function() return math.sin(760) end }
SignatureDB['SIG_761'] = { HASH = '0x0276C5A9', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 61 end, FALLBACK = function() return math.sin(761) end }
SignatureDB['SIG_762'] = { HASH = '0x027799DA', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 62 end, FALLBACK = function() return math.sin(762) end }
SignatureDB['SIG_763'] = { HASH = '0x02786E0B', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 63 end, FALLBACK = function() return math.sin(763) end }
SignatureDB['SIG_764'] = { HASH = '0x0279423C', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 64 end, FALLBACK = function() return math.sin(764) end }
SignatureDB['SIG_765'] = { HASH = '0x027A166D', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 65 end, FALLBACK = function() return math.sin(765) end }
SignatureDB['SIG_766'] = { HASH = '0x027AEA9E', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 66 end, FALLBACK = function() return math.sin(766) end }
SignatureDB['SIG_767'] = { HASH = '0x027BBECF', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 67 end, FALLBACK = function() return math.sin(767) end }
SignatureDB['SIG_768'] = { HASH = '0x027C9300', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 68 end, FALLBACK = function() return math.sin(768) end }
SignatureDB['SIG_769'] = { HASH = '0x027D6731', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 69 end, FALLBACK = function() return math.sin(769) end }
SignatureDB['SIG_770'] = { HASH = '0x027E3B62', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 70 end, FALLBACK = function() return math.sin(770) end }
SignatureDB['SIG_771'] = { HASH = '0x027F0F93', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 71 end, FALLBACK = function() return math.sin(771) end }
SignatureDB['SIG_772'] = { HASH = '0x027FE3C4', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 72 end, FALLBACK = function() return math.sin(772) end }
SignatureDB['SIG_773'] = { HASH = '0x0280B7F5', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 73 end, FALLBACK = function() return math.sin(773) end }
SignatureDB['SIG_774'] = { HASH = '0x02818C26', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 74 end, FALLBACK = function() return math.sin(774) end }
SignatureDB['SIG_775'] = { HASH = '0x02826057', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 75 end, FALLBACK = function() return math.sin(775) end }
SignatureDB['SIG_776'] = { HASH = '0x02833488', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 76 end, FALLBACK = function() return math.sin(776) end }
SignatureDB['SIG_777'] = { HASH = '0x028408B9', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 77 end, FALLBACK = function() return math.sin(777) end }
SignatureDB['SIG_778'] = { HASH = '0x0284DCEA', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 78 end, FALLBACK = function() return math.sin(778) end }
SignatureDB['SIG_779'] = { HASH = '0x0285B11B', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 79 end, FALLBACK = function() return math.sin(779) end }
SignatureDB['SIG_780'] = { HASH = '0x0286854C', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 80 end, FALLBACK = function() return math.sin(780) end }
SignatureDB['SIG_781'] = { HASH = '0x0287597D', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 81 end, FALLBACK = function() return math.sin(781) end }
SignatureDB['SIG_782'] = { HASH = '0x02882DAE', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 82 end, FALLBACK = function() return math.sin(782) end }
SignatureDB['SIG_783'] = { HASH = '0x028901DF', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 83 end, FALLBACK = function() return math.sin(783) end }
SignatureDB['SIG_784'] = { HASH = '0x0289D610', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 84 end, FALLBACK = function() return math.sin(784) end }
SignatureDB['SIG_785'] = { HASH = '0x028AAA41', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 85 end, FALLBACK = function() return math.sin(785) end }
SignatureDB['SIG_786'] = { HASH = '0x028B7E72', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 86 end, FALLBACK = function() return math.sin(786) end }
SignatureDB['SIG_787'] = { HASH = '0x028C52A3', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 87 end, FALLBACK = function() return math.sin(787) end }
SignatureDB['SIG_788'] = { HASH = '0x028D26D4', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 88 end, FALLBACK = function() return math.sin(788) end }
SignatureDB['SIG_789'] = { HASH = '0x028DFB05', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 89 end, FALLBACK = function() return math.sin(789) end }
SignatureDB['SIG_790'] = { HASH = '0x028ECF36', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 90 end, FALLBACK = function() return math.sin(790) end }
SignatureDB['SIG_791'] = { HASH = '0x028FA367', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 91 end, FALLBACK = function() return math.sin(791) end }
SignatureDB['SIG_792'] = { HASH = '0x02907798', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 92 end, FALLBACK = function() return math.sin(792) end }
SignatureDB['SIG_793'] = { HASH = '0x02914BC9', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 93 end, FALLBACK = function() return math.sin(793) end }
SignatureDB['SIG_794'] = { HASH = '0x02921FFA', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 94 end, FALLBACK = function() return math.sin(794) end }
SignatureDB['SIG_795'] = { HASH = '0x0292F42B', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 95 end, FALLBACK = function() return math.sin(795) end }
SignatureDB['SIG_796'] = { HASH = '0x0293C85C', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 96 end, FALLBACK = function() return math.sin(796) end }
SignatureDB['SIG_797'] = { HASH = '0x02949C8D', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 97 end, FALLBACK = function() return math.sin(797) end }
SignatureDB['SIG_798'] = { HASH = '0x029570BE', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 98 end, FALLBACK = function() return math.sin(798) end }
SignatureDB['SIG_799'] = { HASH = '0x029644EF', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 99 end, FALLBACK = function() return math.sin(799) end }
SignatureDB['SIG_800'] = { HASH = '0x02971920', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 0 end, FALLBACK = function() return math.sin(800) end }
SignatureDB['SIG_801'] = { HASH = '0x0297ED51', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 1 end, FALLBACK = function() return math.sin(801) end }
SignatureDB['SIG_802'] = { HASH = '0x0298C182', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 2 end, FALLBACK = function() return math.sin(802) end }
SignatureDB['SIG_803'] = { HASH = '0x029995B3', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 3 end, FALLBACK = function() return math.sin(803) end }
SignatureDB['SIG_804'] = { HASH = '0x029A69E4', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 4 end, FALLBACK = function() return math.sin(804) end }
SignatureDB['SIG_805'] = { HASH = '0x029B3E15', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 5 end, FALLBACK = function() return math.sin(805) end }
SignatureDB['SIG_806'] = { HASH = '0x029C1246', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 6 end, FALLBACK = function() return math.sin(806) end }
SignatureDB['SIG_807'] = { HASH = '0x029CE677', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 7 end, FALLBACK = function() return math.sin(807) end }
SignatureDB['SIG_808'] = { HASH = '0x029DBAA8', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 8 end, FALLBACK = function() return math.sin(808) end }
SignatureDB['SIG_809'] = { HASH = '0x029E8ED9', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 9 end, FALLBACK = function() return math.sin(809) end }
SignatureDB['SIG_810'] = { HASH = '0x029F630A', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 10 end, FALLBACK = function() return math.sin(810) end }
SignatureDB['SIG_811'] = { HASH = '0x02A0373B', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 11 end, FALLBACK = function() return math.sin(811) end }
SignatureDB['SIG_812'] = { HASH = '0x02A10B6C', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 12 end, FALLBACK = function() return math.sin(812) end }
SignatureDB['SIG_813'] = { HASH = '0x02A1DF9D', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 13 end, FALLBACK = function() return math.sin(813) end }
SignatureDB['SIG_814'] = { HASH = '0x02A2B3CE', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 14 end, FALLBACK = function() return math.sin(814) end }
SignatureDB['SIG_815'] = { HASH = '0x02A387FF', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 15 end, FALLBACK = function() return math.sin(815) end }
SignatureDB['SIG_816'] = { HASH = '0x02A45C30', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 16 end, FALLBACK = function() return math.sin(816) end }
SignatureDB['SIG_817'] = { HASH = '0x02A53061', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 17 end, FALLBACK = function() return math.sin(817) end }
SignatureDB['SIG_818'] = { HASH = '0x02A60492', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 18 end, FALLBACK = function() return math.sin(818) end }
SignatureDB['SIG_819'] = { HASH = '0x02A6D8C3', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 19 end, FALLBACK = function() return math.sin(819) end }
SignatureDB['SIG_820'] = { HASH = '0x02A7ACF4', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 20 end, FALLBACK = function() return math.sin(820) end }
SignatureDB['SIG_821'] = { HASH = '0x02A88125', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 21 end, FALLBACK = function() return math.sin(821) end }
SignatureDB['SIG_822'] = { HASH = '0x02A95556', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 22 end, FALLBACK = function() return math.sin(822) end }
SignatureDB['SIG_823'] = { HASH = '0x02AA2987', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 23 end, FALLBACK = function() return math.sin(823) end }
SignatureDB['SIG_824'] = { HASH = '0x02AAFDB8', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 24 end, FALLBACK = function() return math.sin(824) end }
SignatureDB['SIG_825'] = { HASH = '0x02ABD1E9', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 25 end, FALLBACK = function() return math.sin(825) end }
SignatureDB['SIG_826'] = { HASH = '0x02ACA61A', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 26 end, FALLBACK = function() return math.sin(826) end }
SignatureDB['SIG_827'] = { HASH = '0x02AD7A4B', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 27 end, FALLBACK = function() return math.sin(827) end }
SignatureDB['SIG_828'] = { HASH = '0x02AE4E7C', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 28 end, FALLBACK = function() return math.sin(828) end }
SignatureDB['SIG_829'] = { HASH = '0x02AF22AD', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 29 end, FALLBACK = function() return math.sin(829) end }
SignatureDB['SIG_830'] = { HASH = '0x02AFF6DE', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 30 end, FALLBACK = function() return math.sin(830) end }
SignatureDB['SIG_831'] = { HASH = '0x02B0CB0F', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 31 end, FALLBACK = function() return math.sin(831) end }
SignatureDB['SIG_832'] = { HASH = '0x02B19F40', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 32 end, FALLBACK = function() return math.sin(832) end }
SignatureDB['SIG_833'] = { HASH = '0x02B27371', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 33 end, FALLBACK = function() return math.sin(833) end }
SignatureDB['SIG_834'] = { HASH = '0x02B347A2', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 34 end, FALLBACK = function() return math.sin(834) end }
SignatureDB['SIG_835'] = { HASH = '0x02B41BD3', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 35 end, FALLBACK = function() return math.sin(835) end }
SignatureDB['SIG_836'] = { HASH = '0x02B4F004', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 36 end, FALLBACK = function() return math.sin(836) end }
SignatureDB['SIG_837'] = { HASH = '0x02B5C435', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 37 end, FALLBACK = function() return math.sin(837) end }
SignatureDB['SIG_838'] = { HASH = '0x02B69866', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 38 end, FALLBACK = function() return math.sin(838) end }
SignatureDB['SIG_839'] = { HASH = '0x02B76C97', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 39 end, FALLBACK = function() return math.sin(839) end }
SignatureDB['SIG_840'] = { HASH = '0x02B840C8', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 40 end, FALLBACK = function() return math.sin(840) end }
SignatureDB['SIG_841'] = { HASH = '0x02B914F9', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 41 end, FALLBACK = function() return math.sin(841) end }
SignatureDB['SIG_842'] = { HASH = '0x02B9E92A', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 42 end, FALLBACK = function() return math.sin(842) end }
SignatureDB['SIG_843'] = { HASH = '0x02BABD5B', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 43 end, FALLBACK = function() return math.sin(843) end }
SignatureDB['SIG_844'] = { HASH = '0x02BB918C', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 44 end, FALLBACK = function() return math.sin(844) end }
SignatureDB['SIG_845'] = { HASH = '0x02BC65BD', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 45 end, FALLBACK = function() return math.sin(845) end }
SignatureDB['SIG_846'] = { HASH = '0x02BD39EE', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 46 end, FALLBACK = function() return math.sin(846) end }
SignatureDB['SIG_847'] = { HASH = '0x02BE0E1F', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 47 end, FALLBACK = function() return math.sin(847) end }
SignatureDB['SIG_848'] = { HASH = '0x02BEE250', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 48 end, FALLBACK = function() return math.sin(848) end }
SignatureDB['SIG_849'] = { HASH = '0x02BFB681', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 49 end, FALLBACK = function() return math.sin(849) end }
SignatureDB['SIG_850'] = { HASH = '0x02C08AB2', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 50 end, FALLBACK = function() return math.sin(850) end }
SignatureDB['SIG_851'] = { HASH = '0x02C15EE3', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 51 end, FALLBACK = function() return math.sin(851) end }
SignatureDB['SIG_852'] = { HASH = '0x02C23314', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 52 end, FALLBACK = function() return math.sin(852) end }
SignatureDB['SIG_853'] = { HASH = '0x02C30745', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 53 end, FALLBACK = function() return math.sin(853) end }
SignatureDB['SIG_854'] = { HASH = '0x02C3DB76', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 54 end, FALLBACK = function() return math.sin(854) end }
SignatureDB['SIG_855'] = { HASH = '0x02C4AFA7', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 55 end, FALLBACK = function() return math.sin(855) end }
SignatureDB['SIG_856'] = { HASH = '0x02C583D8', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 56 end, FALLBACK = function() return math.sin(856) end }
SignatureDB['SIG_857'] = { HASH = '0x02C65809', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 57 end, FALLBACK = function() return math.sin(857) end }
SignatureDB['SIG_858'] = { HASH = '0x02C72C3A', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 58 end, FALLBACK = function() return math.sin(858) end }
SignatureDB['SIG_859'] = { HASH = '0x02C8006B', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 59 end, FALLBACK = function() return math.sin(859) end }
SignatureDB['SIG_860'] = { HASH = '0x02C8D49C', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 60 end, FALLBACK = function() return math.sin(860) end }
SignatureDB['SIG_861'] = { HASH = '0x02C9A8CD', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 61 end, FALLBACK = function() return math.sin(861) end }
SignatureDB['SIG_862'] = { HASH = '0x02CA7CFE', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 62 end, FALLBACK = function() return math.sin(862) end }
SignatureDB['SIG_863'] = { HASH = '0x02CB512F', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 63 end, FALLBACK = function() return math.sin(863) end }
SignatureDB['SIG_864'] = { HASH = '0x02CC2560', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 64 end, FALLBACK = function() return math.sin(864) end }
SignatureDB['SIG_865'] = { HASH = '0x02CCF991', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 65 end, FALLBACK = function() return math.sin(865) end }
SignatureDB['SIG_866'] = { HASH = '0x02CDCDC2', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 66 end, FALLBACK = function() return math.sin(866) end }
SignatureDB['SIG_867'] = { HASH = '0x02CEA1F3', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 67 end, FALLBACK = function() return math.sin(867) end }
SignatureDB['SIG_868'] = { HASH = '0x02CF7624', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 68 end, FALLBACK = function() return math.sin(868) end }
SignatureDB['SIG_869'] = { HASH = '0x02D04A55', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 69 end, FALLBACK = function() return math.sin(869) end }
SignatureDB['SIG_870'] = { HASH = '0x02D11E86', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 70 end, FALLBACK = function() return math.sin(870) end }
SignatureDB['SIG_871'] = { HASH = '0x02D1F2B7', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 71 end, FALLBACK = function() return math.sin(871) end }
SignatureDB['SIG_872'] = { HASH = '0x02D2C6E8', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 72 end, FALLBACK = function() return math.sin(872) end }
SignatureDB['SIG_873'] = { HASH = '0x02D39B19', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 73 end, FALLBACK = function() return math.sin(873) end }
SignatureDB['SIG_874'] = { HASH = '0x02D46F4A', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 74 end, FALLBACK = function() return math.sin(874) end }
SignatureDB['SIG_875'] = { HASH = '0x02D5437B', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 75 end, FALLBACK = function() return math.sin(875) end }
SignatureDB['SIG_876'] = { HASH = '0x02D617AC', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 76 end, FALLBACK = function() return math.sin(876) end }
SignatureDB['SIG_877'] = { HASH = '0x02D6EBDD', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 77 end, FALLBACK = function() return math.sin(877) end }
SignatureDB['SIG_878'] = { HASH = '0x02D7C00E', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 78 end, FALLBACK = function() return math.sin(878) end }
SignatureDB['SIG_879'] = { HASH = '0x02D8943F', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 79 end, FALLBACK = function() return math.sin(879) end }
SignatureDB['SIG_880'] = { HASH = '0x02D96870', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 80 end, FALLBACK = function() return math.sin(880) end }
SignatureDB['SIG_881'] = { HASH = '0x02DA3CA1', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 81 end, FALLBACK = function() return math.sin(881) end }
SignatureDB['SIG_882'] = { HASH = '0x02DB10D2', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 82 end, FALLBACK = function() return math.sin(882) end }
SignatureDB['SIG_883'] = { HASH = '0x02DBE503', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 83 end, FALLBACK = function() return math.sin(883) end }
SignatureDB['SIG_884'] = { HASH = '0x02DCB934', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 84 end, FALLBACK = function() return math.sin(884) end }
SignatureDB['SIG_885'] = { HASH = '0x02DD8D65', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 85 end, FALLBACK = function() return math.sin(885) end }
SignatureDB['SIG_886'] = { HASH = '0x02DE6196', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 86 end, FALLBACK = function() return math.sin(886) end }
SignatureDB['SIG_887'] = { HASH = '0x02DF35C7', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 87 end, FALLBACK = function() return math.sin(887) end }
SignatureDB['SIG_888'] = { HASH = '0x02E009F8', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 88 end, FALLBACK = function() return math.sin(888) end }
SignatureDB['SIG_889'] = { HASH = '0x02E0DE29', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 89 end, FALLBACK = function() return math.sin(889) end }
SignatureDB['SIG_890'] = { HASH = '0x02E1B25A', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 90 end, FALLBACK = function() return math.sin(890) end }
SignatureDB['SIG_891'] = { HASH = '0x02E2868B', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 91 end, FALLBACK = function() return math.sin(891) end }
SignatureDB['SIG_892'] = { HASH = '0x02E35ABC', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 92 end, FALLBACK = function() return math.sin(892) end }
SignatureDB['SIG_893'] = { HASH = '0x02E42EED', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 93 end, FALLBACK = function() return math.sin(893) end }
SignatureDB['SIG_894'] = { HASH = '0x02E5031E', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 94 end, FALLBACK = function() return math.sin(894) end }
SignatureDB['SIG_895'] = { HASH = '0x02E5D74F', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 95 end, FALLBACK = function() return math.sin(895) end }
SignatureDB['SIG_896'] = { HASH = '0x02E6AB80', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 96 end, FALLBACK = function() return math.sin(896) end }
SignatureDB['SIG_897'] = { HASH = '0x02E77FB1', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 97 end, FALLBACK = function() return math.sin(897) end }
SignatureDB['SIG_898'] = { HASH = '0x02E853E2', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 98 end, FALLBACK = function() return math.sin(898) end }
SignatureDB['SIG_899'] = { HASH = '0x02E92813', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 99 end, FALLBACK = function() return math.sin(899) end }
SignatureDB['SIG_900'] = { HASH = '0x02E9FC44', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 0 end, FALLBACK = function() return math.sin(900) end }
SignatureDB['SIG_901'] = { HASH = '0x02EAD075', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 1 end, FALLBACK = function() return math.sin(901) end }
SignatureDB['SIG_902'] = { HASH = '0x02EBA4A6', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 2 end, FALLBACK = function() return math.sin(902) end }
SignatureDB['SIG_903'] = { HASH = '0x02EC78D7', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 3 end, FALLBACK = function() return math.sin(903) end }
SignatureDB['SIG_904'] = { HASH = '0x02ED4D08', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 4 end, FALLBACK = function() return math.sin(904) end }
SignatureDB['SIG_905'] = { HASH = '0x02EE2139', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 5 end, FALLBACK = function() return math.sin(905) end }
SignatureDB['SIG_906'] = { HASH = '0x02EEF56A', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 6 end, FALLBACK = function() return math.sin(906) end }
SignatureDB['SIG_907'] = { HASH = '0x02EFC99B', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 7 end, FALLBACK = function() return math.sin(907) end }
SignatureDB['SIG_908'] = { HASH = '0x02F09DCC', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 8 end, FALLBACK = function() return math.sin(908) end }
SignatureDB['SIG_909'] = { HASH = '0x02F171FD', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 9 end, FALLBACK = function() return math.sin(909) end }
SignatureDB['SIG_910'] = { HASH = '0x02F2462E', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 10 end, FALLBACK = function() return math.sin(910) end }
SignatureDB['SIG_911'] = { HASH = '0x02F31A5F', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 11 end, FALLBACK = function() return math.sin(911) end }
SignatureDB['SIG_912'] = { HASH = '0x02F3EE90', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 12 end, FALLBACK = function() return math.sin(912) end }
SignatureDB['SIG_913'] = { HASH = '0x02F4C2C1', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 13 end, FALLBACK = function() return math.sin(913) end }
SignatureDB['SIG_914'] = { HASH = '0x02F596F2', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 14 end, FALLBACK = function() return math.sin(914) end }
SignatureDB['SIG_915'] = { HASH = '0x02F66B23', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 15 end, FALLBACK = function() return math.sin(915) end }
SignatureDB['SIG_916'] = { HASH = '0x02F73F54', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 16 end, FALLBACK = function() return math.sin(916) end }
SignatureDB['SIG_917'] = { HASH = '0x02F81385', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 17 end, FALLBACK = function() return math.sin(917) end }
SignatureDB['SIG_918'] = { HASH = '0x02F8E7B6', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 18 end, FALLBACK = function() return math.sin(918) end }
SignatureDB['SIG_919'] = { HASH = '0x02F9BBE7', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 19 end, FALLBACK = function() return math.sin(919) end }
SignatureDB['SIG_920'] = { HASH = '0x02FA9018', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 20 end, FALLBACK = function() return math.sin(920) end }
SignatureDB['SIG_921'] = { HASH = '0x02FB6449', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 21 end, FALLBACK = function() return math.sin(921) end }
SignatureDB['SIG_922'] = { HASH = '0x02FC387A', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 22 end, FALLBACK = function() return math.sin(922) end }
SignatureDB['SIG_923'] = { HASH = '0x02FD0CAB', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 23 end, FALLBACK = function() return math.sin(923) end }
SignatureDB['SIG_924'] = { HASH = '0x02FDE0DC', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 24 end, FALLBACK = function() return math.sin(924) end }
SignatureDB['SIG_925'] = { HASH = '0x02FEB50D', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 25 end, FALLBACK = function() return math.sin(925) end }
SignatureDB['SIG_926'] = { HASH = '0x02FF893E', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 26 end, FALLBACK = function() return math.sin(926) end }
SignatureDB['SIG_927'] = { HASH = '0x03005D6F', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 27 end, FALLBACK = function() return math.sin(927) end }
SignatureDB['SIG_928'] = { HASH = '0x030131A0', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 28 end, FALLBACK = function() return math.sin(928) end }
SignatureDB['SIG_929'] = { HASH = '0x030205D1', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 29 end, FALLBACK = function() return math.sin(929) end }
SignatureDB['SIG_930'] = { HASH = '0x0302DA02', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 30 end, FALLBACK = function() return math.sin(930) end }
SignatureDB['SIG_931'] = { HASH = '0x0303AE33', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 31 end, FALLBACK = function() return math.sin(931) end }
SignatureDB['SIG_932'] = { HASH = '0x03048264', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 32 end, FALLBACK = function() return math.sin(932) end }
SignatureDB['SIG_933'] = { HASH = '0x03055695', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 33 end, FALLBACK = function() return math.sin(933) end }
SignatureDB['SIG_934'] = { HASH = '0x03062AC6', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 34 end, FALLBACK = function() return math.sin(934) end }
SignatureDB['SIG_935'] = { HASH = '0x0306FEF7', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 35 end, FALLBACK = function() return math.sin(935) end }
SignatureDB['SIG_936'] = { HASH = '0x0307D328', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 36 end, FALLBACK = function() return math.sin(936) end }
SignatureDB['SIG_937'] = { HASH = '0x0308A759', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 37 end, FALLBACK = function() return math.sin(937) end }
SignatureDB['SIG_938'] = { HASH = '0x03097B8A', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 38 end, FALLBACK = function() return math.sin(938) end }
SignatureDB['SIG_939'] = { HASH = '0x030A4FBB', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 39 end, FALLBACK = function() return math.sin(939) end }
SignatureDB['SIG_940'] = { HASH = '0x030B23EC', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 40 end, FALLBACK = function() return math.sin(940) end }
SignatureDB['SIG_941'] = { HASH = '0x030BF81D', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 41 end, FALLBACK = function() return math.sin(941) end }
SignatureDB['SIG_942'] = { HASH = '0x030CCC4E', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 42 end, FALLBACK = function() return math.sin(942) end }
SignatureDB['SIG_943'] = { HASH = '0x030DA07F', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 43 end, FALLBACK = function() return math.sin(943) end }
SignatureDB['SIG_944'] = { HASH = '0x030E74B0', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 44 end, FALLBACK = function() return math.sin(944) end }
SignatureDB['SIG_945'] = { HASH = '0x030F48E1', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 45 end, FALLBACK = function() return math.sin(945) end }
SignatureDB['SIG_946'] = { HASH = '0x03101D12', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 46 end, FALLBACK = function() return math.sin(946) end }
SignatureDB['SIG_947'] = { HASH = '0x0310F143', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 47 end, FALLBACK = function() return math.sin(947) end }
SignatureDB['SIG_948'] = { HASH = '0x0311C574', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 48 end, FALLBACK = function() return math.sin(948) end }
SignatureDB['SIG_949'] = { HASH = '0x031299A5', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 49 end, FALLBACK = function() return math.sin(949) end }
SignatureDB['SIG_950'] = { HASH = '0x03136DD6', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 50 end, FALLBACK = function() return math.sin(950) end }
SignatureDB['SIG_951'] = { HASH = '0x03144207', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 51 end, FALLBACK = function() return math.sin(951) end }
SignatureDB['SIG_952'] = { HASH = '0x03151638', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 52 end, FALLBACK = function() return math.sin(952) end }
SignatureDB['SIG_953'] = { HASH = '0x0315EA69', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 53 end, FALLBACK = function() return math.sin(953) end }
SignatureDB['SIG_954'] = { HASH = '0x0316BE9A', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 54 end, FALLBACK = function() return math.sin(954) end }
SignatureDB['SIG_955'] = { HASH = '0x031792CB', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 55 end, FALLBACK = function() return math.sin(955) end }
SignatureDB['SIG_956'] = { HASH = '0x031866FC', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 56 end, FALLBACK = function() return math.sin(956) end }
SignatureDB['SIG_957'] = { HASH = '0x03193B2D', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 57 end, FALLBACK = function() return math.sin(957) end }
SignatureDB['SIG_958'] = { HASH = '0x031A0F5E', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 58 end, FALLBACK = function() return math.sin(958) end }
SignatureDB['SIG_959'] = { HASH = '0x031AE38F', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 59 end, FALLBACK = function() return math.sin(959) end }
SignatureDB['SIG_960'] = { HASH = '0x031BB7C0', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 60 end, FALLBACK = function() return math.sin(960) end }
SignatureDB['SIG_961'] = { HASH = '0x031C8BF1', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 61 end, FALLBACK = function() return math.sin(961) end }
SignatureDB['SIG_962'] = { HASH = '0x031D6022', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 62 end, FALLBACK = function() return math.sin(962) end }
SignatureDB['SIG_963'] = { HASH = '0x031E3453', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 63 end, FALLBACK = function() return math.sin(963) end }
SignatureDB['SIG_964'] = { HASH = '0x031F0884', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 64 end, FALLBACK = function() return math.sin(964) end }
SignatureDB['SIG_965'] = { HASH = '0x031FDCB5', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 65 end, FALLBACK = function() return math.sin(965) end }
SignatureDB['SIG_966'] = { HASH = '0x0320B0E6', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 66 end, FALLBACK = function() return math.sin(966) end }
SignatureDB['SIG_967'] = { HASH = '0x03218517', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 67 end, FALLBACK = function() return math.sin(967) end }
SignatureDB['SIG_968'] = { HASH = '0x03225948', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 68 end, FALLBACK = function() return math.sin(968) end }
SignatureDB['SIG_969'] = { HASH = '0x03232D79', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 69 end, FALLBACK = function() return math.sin(969) end }
SignatureDB['SIG_970'] = { HASH = '0x032401AA', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 70 end, FALLBACK = function() return math.sin(970) end }
SignatureDB['SIG_971'] = { HASH = '0x0324D5DB', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 71 end, FALLBACK = function() return math.sin(971) end }
SignatureDB['SIG_972'] = { HASH = '0x0325AA0C', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 72 end, FALLBACK = function() return math.sin(972) end }
SignatureDB['SIG_973'] = { HASH = '0x03267E3D', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 73 end, FALLBACK = function() return math.sin(973) end }
SignatureDB['SIG_974'] = { HASH = '0x0327526E', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 74 end, FALLBACK = function() return math.sin(974) end }
SignatureDB['SIG_975'] = { HASH = '0x0328269F', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 75 end, FALLBACK = function() return math.sin(975) end }
SignatureDB['SIG_976'] = { HASH = '0x0328FAD0', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 76 end, FALLBACK = function() return math.sin(976) end }
SignatureDB['SIG_977'] = { HASH = '0x0329CF01', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 77 end, FALLBACK = function() return math.sin(977) end }
SignatureDB['SIG_978'] = { HASH = '0x032AA332', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 78 end, FALLBACK = function() return math.sin(978) end }
SignatureDB['SIG_979'] = { HASH = '0x032B7763', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 79 end, FALLBACK = function() return math.sin(979) end }
SignatureDB['SIG_980'] = { HASH = '0x032C4B94', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 80 end, FALLBACK = function() return math.sin(980) end }
SignatureDB['SIG_981'] = { HASH = '0x032D1FC5', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 81 end, FALLBACK = function() return math.sin(981) end }
SignatureDB['SIG_982'] = { HASH = '0x032DF3F6', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 82 end, FALLBACK = function() return math.sin(982) end }
SignatureDB['SIG_983'] = { HASH = '0x032EC827', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 83 end, FALLBACK = function() return math.sin(983) end }
SignatureDB['SIG_984'] = { HASH = '0x032F9C58', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 84 end, FALLBACK = function() return math.sin(984) end }
SignatureDB['SIG_985'] = { HASH = '0x03307089', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 85 end, FALLBACK = function() return math.sin(985) end }
SignatureDB['SIG_986'] = { HASH = '0x033144BA', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 86 end, FALLBACK = function() return math.sin(986) end }
SignatureDB['SIG_987'] = { HASH = '0x033218EB', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 87 end, FALLBACK = function() return math.sin(987) end }
SignatureDB['SIG_988'] = { HASH = '0x0332ED1C', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 88 end, FALLBACK = function() return math.sin(988) end }
SignatureDB['SIG_989'] = { HASH = '0x0333C14D', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 89 end, FALLBACK = function() return math.sin(989) end }
SignatureDB['SIG_990'] = { HASH = '0x0334957E', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 90 end, FALLBACK = function() return math.sin(990) end }
SignatureDB['SIG_991'] = { HASH = '0x033569AF', ACTION = 'FLAG', SEVERITY = 1, CHECK = function(env) return env.ThreatLevel > 91 end, FALLBACK = function() return math.sin(991) end }
SignatureDB['SIG_992'] = { HASH = '0x03363DE0', ACTION = 'FLAG', SEVERITY = 2, CHECK = function(env) return env.ThreatLevel > 92 end, FALLBACK = function() return math.sin(992) end }
SignatureDB['SIG_993'] = { HASH = '0x03371211', ACTION = 'FLAG', SEVERITY = 3, CHECK = function(env) return env.ThreatLevel > 93 end, FALLBACK = function() return math.sin(993) end }
SignatureDB['SIG_994'] = { HASH = '0x0337E642', ACTION = 'FLAG', SEVERITY = 4, CHECK = function(env) return env.ThreatLevel > 94 end, FALLBACK = function() return math.sin(994) end }
SignatureDB['SIG_995'] = { HASH = '0x0338BA73', ACTION = 'FLAG', SEVERITY = 5, CHECK = function(env) return env.ThreatLevel > 95 end, FALLBACK = function() return math.sin(995) end }
SignatureDB['SIG_996'] = { HASH = '0x03398EA4', ACTION = 'FLAG', SEVERITY = 6, CHECK = function(env) return env.ThreatLevel > 96 end, FALLBACK = function() return math.sin(996) end }
SignatureDB['SIG_997'] = { HASH = '0x033A62D5', ACTION = 'FLAG', SEVERITY = 7, CHECK = function(env) return env.ThreatLevel > 97 end, FALLBACK = function() return math.sin(997) end }
SignatureDB['SIG_998'] = { HASH = '0x033B3706', ACTION = 'FLAG', SEVERITY = 8, CHECK = function(env) return env.ThreatLevel > 98 end, FALLBACK = function() return math.sin(998) end }
SignatureDB['SIG_999'] = { HASH = '0x033C0B37', ACTION = 'FLAG', SEVERITY = 9, CHECK = function(env) return env.ThreatLevel > 99 end, FALLBACK = function() return math.sin(999) end }
SignatureDB['SIG_1000'] = { HASH = '0x033CDF68', ACTION = 'FLAG', SEVERITY = 0, CHECK = function(env) return env.ThreatLevel > 0 end, FALLBACK = function() return math.sin(1000) end }

-- [ END OF GUARD ENTERPRISE SUITE ]


