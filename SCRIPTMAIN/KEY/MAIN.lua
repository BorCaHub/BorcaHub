--[[
    â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
    â•‘            BorcaHub  â€¢  ScriptMain / Key / Main.lua          â•‘
    â•‘  Key Validation System â€” Supabase + Expiry + 1-Player Lock  â•‘
    â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--]]

local HttpService = game:GetService("HttpService")
local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- ================================================================
--  CONFIG
-- ================================================================

local SUPABASE_URL      = "https://wgdnppyhyypaycznxmmq.supabase.co"
local SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndnZG5wcHloeXlwYXljem54bW1xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk0MzI0NjIsImV4cCI6MjA5NTAwODQ2Mn0.rKMqEE_SwDrm71DMdSC3xtxjThaRsYvidVWoWVTmnwc"

local Config = {
    SaveFile     = "BorcaHub_Key.txt",
    CacheFile    = "BorcaHub_KeyCache.txt",
    CacheSeconds = 3600,
}

-- ================================================================
--  STORAGE HELPERS
-- ================================================================

local function SafeWrite(path, content)
    pcall(writefile, path, content)
end

local function SafeRead(path)
    local ok, content = pcall(readfile, path)
    if ok and content and content ~= "" then return content end
    return nil
end

-- ================================================================
--  CACHE
-- ================================================================

local function LoadCache()
    local raw = SafeRead(Config.CacheFile)
    if not raw then return nil end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
    return (ok and data) or nil
end

local function SaveCache(data)
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data)
    if ok then SafeWrite(Config.CacheFile, encoded) end
end

local function CacheValid(cache)
    if not cache or not cache.timestamp then return false end
    -- Juga cek kalau cache punya key yang sama (username match)
    if cache.username and cache.username ~= LocalPlayer.Name then return false end
    return (os.time() - cache.timestamp) < Config.CacheSeconds
end

-- ================================================================
--  REMOTE VALIDATE
-- ================================================================

local function RemoteValidate(key)
    local url  = SUPABASE_URL .. "/rest/v1/rpc/validate_key"
    local body = HttpService:JSONEncode({
        input_key   = key,
        player_name = LocalPlayer.Name,
    })

    local ok, response = pcall(request, {
        Url    = url,
        Method = "POST",
        Headers = {
            ["apikey"]        = SUPABASE_ANON_KEY,
            ["Authorization"] = "Bearer " .. SUPABASE_ANON_KEY,
            ["Content-Type"]  = "application/json",
        },
        Body = body,
    })

    if not ok or not response then
        return { Valid = false, Tier = "None", Message = "Koneksi gagal." }
    end

    if response.StatusCode ~= 200 then
        return { Valid = false, Tier = "None", Message = "Server error: " .. tostring(response.StatusCode) }
    end

    local dok, data = pcall(HttpService.JSONDecode, HttpService, response.Body)
    if not dok or type(data) ~= "table" then
        return { Valid = false, Tier = "None", Message = "Response tidak valid." }
    end

    return {
        Valid     = data.valid == true,
        Tier      = data.tier     or "Free",
        Expiry    = data.expiry   or "N/A",
        Username  = data.username or LocalPlayer.Name,
        Message   = data.message  or (data.valid and "Key valid." or "Key tidak valid."),
    }
end

-- ================================================================
--  KEY PROMPT UI
-- ================================================================

local function ShowKeyPrompt(callback)
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name           = "BorcaHub_KeyPrompt"
    ScreenGui.ResetOnSpawn   = false
    ScreenGui.DisplayOrder   = 9999
    ScreenGui.IgnoreGuiInset = true

    local ok = false
    if not ok then ok = pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end) end
    if not ok then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    -- Overlay
    local Overlay = Instance.new("Frame", ScreenGui)
    Overlay.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
    Overlay.BackgroundTransparency = 0.45
    Overlay.Size                   = UDim2.new(1, 0, 1, 0)
    Overlay.ZIndex                 = 100

    -- Card
    local Card = Instance.new("Frame", Overlay)
    Card.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
    Card.AnchorPoint      = Vector2.new(0.5, 0.5)
    Card.Position         = UDim2.new(0.5, 0, 0.5, 0)
    Card.Size             = UDim2.new(0, 360, 0, 190)
    Card.ZIndex           = 101
    Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 12)
    local stroke = Instance.new("UIStroke", Card)
    stroke.Color     = Color3.fromRGB(108, 138, 255)
    stroke.Thickness = 1.4

    -- Title
    local Title = Instance.new("TextLabel", Card)
    Title.BackgroundTransparency = 1
    Title.Position   = UDim2.new(0, 0, 0, 18)
    Title.Size       = UDim2.new(1, 0, 0, 22)
    Title.Text       = "ðŸ”‘  BorcaHub â€” Key Required"
    Title.TextColor3 = Color3.fromRGB(238, 238, 252)
    Title.TextSize   = 15
    Title.Font       = Enum.Font.GothamBold
    Title.ZIndex     = 102

    -- Subtitle (shows player name)
    local Sub = Instance.new("TextLabel", Card)
    Sub.BackgroundTransparency = 1
    Sub.Position   = UDim2.new(0, 0, 0, 44)
    Sub.Size       = UDim2.new(1, 0, 0, 15)
    Sub.Text       = "Player: " .. LocalPlayer.Name
    Sub.TextColor3 = Color3.fromRGB(108, 138, 255)
    Sub.TextSize   = 11
    Sub.Font       = Enum.Font.Gotham
    Sub.ZIndex     = 102

    -- Input background
    local InBg = Instance.new("Frame", Card)
    InBg.BackgroundColor3 = Color3.fromRGB(30, 30, 43)
    InBg.Position         = UDim2.new(0.06, 0, 0, 72)
    InBg.Size             = UDim2.new(0.88, 0, 0, 34)
    InBg.ZIndex           = 102
    Instance.new("UICorner", InBg).CornerRadius = UDim.new(0, 7)
    local InStroke = Instance.new("UIStroke", InBg)
    InStroke.Color     = Color3.fromRGB(55, 55, 78)
    InStroke.Thickness = 1

    local Input = Instance.new("TextBox", InBg)
    Input.BackgroundTransparency = 1
    Input.Size              = UDim2.new(1, -12, 1, 0)
    Input.Position          = UDim2.new(0, 6, 0, 0)
    Input.PlaceholderText   = "BORCA-XXXX-XXXX-XXXX"
    Input.Text              = ""
    Input.TextColor3        = Color3.fromRGB(238, 238, 252)
    Input.PlaceholderColor3 = Color3.fromRGB(90, 90, 120)
    Input.TextSize          = 13
    Input.Font              = Enum.Font.GothamBold
    Input.ClearTextOnFocus  = false
    Input.ZIndex            = 103

    -- Status
    local Status = Instance.new("TextLabel", Card)
    Status.BackgroundTransparency = 1
    Status.Position       = UDim2.new(0.06, 0, 0, 116)
    Status.Size           = UDim2.new(0.6, 0, 0, 14)
    Status.Text           = ""
    Status.TextColor3     = Color3.fromRGB(255, 80, 80)
    Status.TextSize       = 11
    Status.Font           = Enum.Font.Gotham
    Status.TextXAlignment = Enum.TextXAlignment.Left
    Status.ZIndex         = 102

    -- Expiry label (shown after valid)
    local ExpiryLabel = Instance.new("TextLabel", Card)
    ExpiryLabel.BackgroundTransparency = 1
    ExpiryLabel.Position       = UDim2.new(0.06, 0, 0, 133)
    ExpiryLabel.Size           = UDim2.new(0.88, 0, 0, 13)
    ExpiryLabel.Text           = ""
    ExpiryLabel.TextColor3     = Color3.fromRGB(155, 155, 185)
    ExpiryLabel.TextSize       = 10
    ExpiryLabel.Font           = Enum.Font.Gotham
    ExpiryLabel.TextXAlignment = Enum.TextXAlignment.Left
    ExpiryLabel.ZIndex         = 102

    -- Validate Button
    local Btn = Instance.new("TextButton", Card)
    Btn.BackgroundColor3 = Color3.fromRGB(108, 138, 255)
    Btn.AnchorPoint      = Vector2.new(1, 0)
    Btn.Position         = UDim2.new(0.94, 0, 0, 112)
    Btn.Size             = UDim2.new(0, 76, 0, 24)
    Btn.Text             = "Validate"
    Btn.TextColor3       = Color3.fromRGB(255, 255, 255)
    Btn.TextSize         = 12
    Btn.Font             = Enum.Font.GothamBold
    Btn.AutoButtonColor  = false
    Btn.ZIndex           = 103
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)

    -- Validate logic
    local function DoValidate()
        local key = Input.Text:match("^%s*(.-)%s*$")
        if key == "" then
            Status.Text       = "âš  Masukkan key terlebih dahulu."
            Status.TextColor3 = Color3.fromRGB(255, 183, 64)
            return
        end
        Status.Text       = "Memvalidasiâ€¦"
        Status.TextColor3 = Color3.fromRGB(108, 138, 255)
        ExpiryLabel.Text  = ""
        Btn.Active        = false
        Btn.BackgroundColor3 = Color3.fromRGB(70, 90, 180)

        task.spawn(function()
            local result = RemoteValidate(key)
            if result.Valid then
                Status.Text       = "âœ“ " .. result.Message
                Status.TextColor3 = Color3.fromRGB(72, 199, 116)
                ExpiryLabel.Text  = "Expired: " .. tostring(result.Expiry) .. "  |  Tier: " .. result.Tier
                SafeWrite(Config.SaveFile, key)
                SaveCache({
                    key       = key,
                    result    = result,
                    username  = LocalPlayer.Name,
                    timestamp = os.time(),
                })
                task.wait(1)
                ScreenGui:Destroy()
                callback(result, key)
            else
                Status.Text          = "âœ— " .. result.Message
                Status.TextColor3    = Color3.fromRGB(255, 80, 80)
                Btn.Active           = true
                Btn.BackgroundColor3 = Color3.fromRGB(108, 138, 255)
            end
        end)
    end

    Btn.MouseButton1Click:Connect(DoValidate)
    Input.FocusLost:Connect(function(enter)
        if enter then DoValidate() end
    end)
end

-- ================================================================
--  KEY SYSTEM MODULE
-- ================================================================

local KeySystem = {
    _key    = nil,
    _result = nil,
}

function KeySystem:Validate(forceRecheck)
    -- 1. Cache check
    if not forceRecheck then
        local cache = LoadCache()
        if CacheValid(cache) and cache.result and cache.key then
            self._key    = cache.key
            self._result = cache.result
            print("[KeySystem] Cache valid — Tier:", cache.result.Tier)
        return cache.result
            if result.Valid then
                self._key    = cache.key
                self._result = result
                SaveCache({ key = cache.key, result = result, username = LocalPlayer.Name, timestamp = os.time() })
                print("[KeySystem] Cache valid â€” Tier:", result.Tier, "| Expired:", result.Expiry)
                return result
            else
                warn("[KeySystem] Cache key rejected:", result.Message)
                SafeWrite(Config.CacheFile, "")
            end
        end
    end

    -- 2. Saved key file
    local savedKey = SafeRead(Config.SaveFile)
    if savedKey then
        savedKey = savedKey:match("^%s*(.-)%s*$")
        if savedKey ~= "" then
            local result = RemoteValidate(savedKey)
            if result.Valid then
                self._key    = savedKey
                self._result = result
                SaveCache({ key = savedKey, result = result, username = LocalPlayer.Name, timestamp = os.time() })
                print("[KeySystem] Key file valid â€” Tier:", result.Tier, "| Expired:", result.Expiry)
                return result
            else
                warn("[KeySystem] Key file rejected:", result.Message)
                SafeWrite(Config.SaveFile, "")
                SafeWrite(Config.CacheFile, "")
            end
        end
    end

    -- 3. Prompt
    local resultHolder = {}
    local done = Instance.new("BindableEvent")
    ShowKeyPrompt(function(res, key)
        self._key    = key
        self._result = res
        resultHolder[1] = res
        done:Fire()
    end)
    done.Event:Wait()
    done:Destroy()
    return resultHolder[1] or { Valid = false, Tier = "None", Message = "Tidak ada key." }
end

function KeySystem:GetResult() return self._result end
function KeySystem:GetKey()    return self._key    end
function KeySystem:GetTier()   return self._result and self._result.Tier or "None" end

function KeySystem:Reset()
    SafeWrite(Config.SaveFile, "")
    SafeWrite(Config.CacheFile, "")
    self._key    = nil
    self._result = nil
    print("[KeySystem] Key direset.")
end

return KeySystem

