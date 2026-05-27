--[[
    ╔══════════════════════════════════════════════════════════════════════╗
    ║                 BorcaHub UI Library  •  Main.lua                     ║
    ║            UIMain / Components / File / Main.lua                     ║
    ║                                                                      ║
    ║  Style   : BorcaHub Premium  (modern, dark, animated)                ║
    ║  Target  : Universal  (Synapse X, KRNL, Delta, Fluxus, Mobile)       ║
    ║  Version : 3.0.0                                                     ║
    ╚══════════════════════════════════════════════════════════════════════╝
--]]

-- ====================================================================
--  SERVICES
-- ====================================================================
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TextService       = game:GetService("TextService")
local HttpService       = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

-- ====================================================================
--  INTERNAL UTILITIES
-- ====================================================================

local function New(class, props, children)
    local inst = Instance.new(class)
    if props then
        for k, v in pairs(props) do
            inst[k] = v
        end
    end
    if children then
        for _, child in ipairs(children) do
            child.Parent = inst
        end
    end
    return inst
end

local function Tween(inst, goals, duration, style, direction)
    local ti = TweenInfo.new(
        duration  or 0.18,
        style     or Enum.EasingStyle.Quad,
        direction or Enum.EasingDirection.Out
    )
    local t = TweenService:Create(inst, ti, goals)
    t:Play()
    return t
end

local function Corner(parent, radius)
    return New("UICorner", { Parent = parent, CornerRadius = UDim.new(0, radius or 6) })
end

local function Pad(parent, top, right, bottom, left)
    return New("UIPadding", {
        Parent        = parent,
        PaddingTop    = UDim.new(0, top    or 8),
        PaddingRight  = UDim.new(0, right  or 8),
        PaddingBottom = UDim.new(0, bottom or 8),
        PaddingLeft   = UDim.new(0, left   or 8),
    })
end

local function Stroke(parent, color, thickness)
    return New("UIStroke", {
        Parent    = parent,
        Color     = color     or Color3.fromRGB(55, 55, 75),
        Thickness = thickness or 1,
    })
end

local function SnapValue(val, min, max, inc)
    local snapped = math.round(val / inc) * inc
    return math.clamp(snapped, min, max)
end

local function Lerp(a, b, t) return a + (b - a) * t end

local function HSVtoColor3(h, s, v)
    return Color3.fromHSV(h, s, v)
end

local function Color3toHSV(c)
    local h, s, v = Color3.toHSV(c)
    return h, s, v
end

local function HexToColor3(hex)
    hex = hex:gsub("^#", "")
    if #hex ~= 6 then return Color3.new(1, 1, 1) end
    local r = tonumber(hex:sub(1,2), 16) or 255
    local g = tonumber(hex:sub(3,4), 16) or 255
    local b = tonumber(hex:sub(5,6), 16) or 255
    return Color3.fromRGB(r, g, b)
end

local function Color3ToHex(c)
    return string.format("#%02X%02X%02X",
        math.floor(c.R * 255),
        math.floor(c.G * 255),
        math.floor(c.B * 255)
    )
end

local function ShallowCopy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

local _idCounter = 0
local function UID()
    _idCounter += 1
    return "bh_" .. tostring(_idCounter)
end

-- ====================================================================
--  CORE MODULES INITIALIZATION (GitHub Fetch)
-- ====================================================================

local ThemeEngine = nil
local Guard = {}

local function SafeLoad(path)
    -- Try global first
    if _G.SafeLoad then
        local fn = _G.SafeLoad(path)
        if fn then return fn end
    end

    -- Try local file first (resilient local execution fallback)
    local localPaths = {
        path,
        "BorcaHub/" .. path,
        "C:/Users/SPIDER X/Downloads/BorcaHub/" .. path
    }
    for _, lpath in ipairs(localPaths) do
        local ok, content = pcall(function()
            if isfile and isfile(lpath) then
                return readfile(lpath)
            end
        end)
        if ok and content and #content > 10 then
            local fn, loadErr = loadstring(content)
            if fn then
                return fn
            end
        end
    end

    -- Try multiple raw GitHub/jsDelivr URL variations
    local urlVariations = {
        "https://raw.githubusercontent.com/BorCaHub/BorcaHub/main/" .. path:gsub(" ", "%%20"),
        "https://cdn.jsdelivr.net/gh/BorCaHub/BorcaHub@main/" .. path:gsub(" ", "%%20"),
        "https://raw.githubusercontent.com/BorCaHub/BorcaHub/master/" .. path:gsub(" ", "%%20"),
        "https://cdn.jsdelivr.net/gh/BorCaHub/BorcaHub@master/" .. path:gsub(" ", "%%20")
    }

    for _, url in ipairs(urlVariations) do
        local ok, source = pcall(function()
            return game:HttpGet(url)
        end)
        if ok and source and #source > 10 and not source:find("404: Not Found") then
            local fn, loadErr = loadstring(source)
            if fn then
                return fn
            end
        end
    end

    return nil
end

local themeFn = SafeLoad("UIMAIN/COMPONENTS/CORE/THEME.lua")
if themeFn then
    local ok, res = pcall(themeFn)
    if ok and res then ThemeEngine = res end
end

local guardFn = SafeLoad("UIMAIN/COMPONENTS/CORE/GUARD.lua")
if guardFn then
    local ok, res = pcall(guardFn)
    if ok and res then Guard = res end
end

if not ThemeEngine then
    error("[BorcaHub] Critical Error: Failed to fetch Theme components. Please check your internet connection!")
end

local Themes = ThemeEngine.Themes
local ThemeOrder = ThemeEngine.ThemeOrder
local AccentPresets = ThemeEngine.AccentPresets

-- ====================================================================
--  SCREENGUI
-- ====================================================================

local ScreenGui

local function MountGui()
    local gui = New("ScreenGui", {
        Name           = "BorcaHub",
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder   = 999,
        IgnoreGuiInset = true,
    })

    local ok = false

    if not ok then
        ok = pcall(function()
            if syn and syn.protect_gui then syn.protect_gui(gui) end
            gui.Parent = game:GetService("CoreGui")
        end)
    end

    if not ok then
        ok = pcall(function()
            gui.Parent = gethui()
        end)
    end

    if not ok then
        ok = pcall(function()
            gui.Parent = game:GetService("CoreGui")
        end)
    end

    if not ok then
        gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    return gui
end

ScreenGui = MountGui()

-- ====================================================================
--  NOTIFICATION TOAST CONTAINER
-- ====================================================================

local ToastContainer = ScreenGui:FindFirstChild("BorcaHub_Toasts")
if not ToastContainer then
    ToastContainer = New("Frame", {
        Name                 = "BorcaHub_Toasts",
        Parent               = ScreenGui,
        BackgroundTransparency = 1,
        AnchorPoint          = Vector2.new(1, 1),
        Position             = UDim2.new(1, -16, 1, -16),
        Size                 = UDim2.new(0, 300, 1, -32),
        ZIndex               = 990,
    })
    New("UIListLayout", {
        Parent            = ToastContainer,
        SortOrder         = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        Padding           = UDim.new(0, 8),
    })
end

-- ====================================================================
--  TOOLTIP CONTAINER
-- ====================================================================

local TooltipFrame = ScreenGui:FindFirstChild("BorcaHub_Tooltip")
if not TooltipFrame then
    TooltipFrame = New("Frame", {
        Name                 = "BorcaHub_Tooltip",
        Parent               = ScreenGui,
        BackgroundColor3     = Color3.fromRGB(20, 22, 30),
        Visible              = false,
        Size                 = UDim2.new(0, 0, 0, 0),
        AutomaticSize        = Enum.AutomaticSize.XY,
        ZIndex               = 998,
        ClipsDescendants     = false,
    })
    Corner(TooltipFrame, 5)
    Stroke(TooltipFrame, Color3.fromRGB(55, 60, 90), 1)
    Pad(TooltipFrame, 5, 10, 5, 10)
end

local TooltipLabel = TooltipFrame:FindFirstChildOfClass("TextLabel")
if not TooltipLabel then
    TooltipLabel = New("TextLabel", {
        Parent               = TooltipFrame,
        BackgroundTransparency = 1,
        Size                 = UDim2.new(0, 0, 0, 0),
        AutomaticSize        = Enum.AutomaticSize.XY,
        Text                 = "",
        TextColor3           = Color3.fromRGB(215, 218, 240),
        TextSize             = 11,
        Font                 = Enum.Font.Gotham,
        ZIndex               = 999,
        TextWrapped          = true,
        RichText             = true,
    })
end

local _tooltipVisible = false
RunService.RenderStepped:Connect(function()
    if not _tooltipVisible then return end
    local mp = UserInputService:GetMouseLocation()
    TooltipFrame.Position = UDim2.new(0, mp.X + 12, 0, mp.Y + 16)
end)

-- ====================================================================
--  CONTEXT MENU CONTAINER
-- ====================================================================

local ContextMenu = ScreenGui:FindFirstChild("BorcaHub_CtxMenu")
if not ContextMenu then
    ContextMenu = New("Frame", {
        Name                 = "BorcaHub_CtxMenu",
        Parent               = ScreenGui,
        BackgroundTransparency = 1,
        Size                 = UDim2.new(0, 0, 0, 0),
        ZIndex               = 997,
        Visible              = false,
    })
end

-- ====================================================================
--  LIBRARY TABLE
-- ====================================================================

local Library = {
    Flags          = {},
    Theme          = Themes.Dark,
    _themeIdx      = 1,
    _windows       = {},
    _keybinds      = {},
    _notifHistory  = {},
    _tooltipConns  = {},
    _scale         = 1,
    _accentColor   = nil,
    Version        = "3.0.0",
}

Library.__index = Library

-- ====================================================================
--  TOOLTIP HELPER
-- ====================================================================

function Library:AttachTooltip(obj, text)
    if not text or text == "" then return end

    local enterConn = obj.MouseEnter:Connect(function()
        TooltipLabel.Text = text
        TooltipFrame.Visible = true
        _tooltipVisible = true
    end)

    local leaveConn = obj.MouseLeave:Connect(function()
        TooltipFrame.Visible = false
        _tooltipVisible = false
    end)

    table.insert(self._tooltipConns, enterConn)
    table.insert(self._tooltipConns, leaveConn)
end

-- ====================================================================
--  RIPPLE EFFECT
-- ====================================================================

local function Ripple(parent, x, y, color)
    if parent.AbsoluteSize.X == 0 then return end   
    color = color or Color3.fromRGB(255, 255, 255)
    local s = math.max(parent.AbsoluteSize.X, parent.AbsoluteSize.Y) * 2
    local dot = New("Frame", {
        Parent               = parent,
        BackgroundColor3     = color,
        BackgroundTransparency = 0.82,
        AnchorPoint          = Vector2.new(0.5, 0.5),
        Position             = UDim2.new(0, x - parent.AbsolutePosition.X, 0, y - parent.AbsolutePosition.Y),
        Size                 = UDim2.new(0, 0, 0, 0),
        ZIndex               = parent.ZIndex + 50,
        ClipsDescendants     = false,
    })
    Corner(dot, 9999)
    parent.ClipsDescendants = true

    Tween(dot, { Size = UDim2.new(0, s, 0, s), BackgroundTransparency = 1 }, 0.5, Enum.EasingStyle.Quart)
    task.delay(0.52, function()
        if dot.Parent then dot:Destroy() end
    end)
end

-- ====================================================================
--  NOTIFICATION SYSTEM
-- ====================================================================

function Library:Notify(opt)
    opt = opt or {}

    local title    = opt.Title    or "BorcaHub"
    local content  = opt.Content  or ""
    local duration = opt.Duration or 4
    local nType    = opt.Type     or "Info"
    local icon     = opt.Icon     or nil
    local T        = self.Theme
    local accent   = T[nType] or T.Info

    table.insert(self._notifHistory, {
        Title   = title,
        Content = content,
        Type    = nType,
        Time    = os.time(),
    })
    if #self._notifHistory > 50 then
        table.remove(self._notifHistory, 1)
    end

    local Wrapper = New("Frame", {
        Name                   = "Toast_" .. UID(),
        Parent                 = ToastContainer,
        BackgroundTransparency = 1,
        Size                   = UDim2.new(1, 0, 0, 0),
        AutomaticSize          = Enum.AutomaticSize.Y,
        ZIndex                 = 991,
    })

    local Card = New("Frame", {
        Name             = "Card",
        Parent           = Wrapper,
        BackgroundColor3 = T.Secondary,
        Size             = UDim2.new(1, 0, 0, 0),
        AutomaticSize    = Enum.AutomaticSize.Y,
        ZIndex           = 992,
        ClipsDescendants = false,
    })
    Corner(Card, 11)
    Stroke(Card, T.Border, 1)

    local Bar = New("Frame", {
        Parent           = Card,
        BackgroundColor3 = accent,
        Size             = UDim2.new(0, 3, 1, 0),
        BorderSizePixel  = 0,
        ZIndex           = 993,
    })
    Corner(Bar, 2)

    local Inner = New("Frame", {
        Parent                 = Card,
        BackgroundTransparency = 1,
        Position               = UDim2.new(0, 14, 0, 0),
        Size                   = UDim2.new(1, -26, 0, 0),
        AutomaticSize          = Enum.AutomaticSize.Y,
        ZIndex                 = 993,
    })
    Pad(Inner, 10, 4, 10, 2)
    New("UIListLayout", {
        Parent    = Inner,
        Padding   = UDim.new(0, 3),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })

    local TRow = New("Frame", {
        Parent                 = Inner,
        BackgroundTransparency = 1,
        Size                   = UDim2.new(1, 0, 0, 15),
        ZIndex                 = 994,
        LayoutOrder            = 1,
    })
    New("UIListLayout", {
        Parent            = TRow,
        FillDirection     = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding           = UDim.new(0, 5),
    })

    local Badge = New("TextLabel", {
        Parent               = TRow,
        BackgroundColor3     = accent,
        BackgroundTransparency = 0,
        Size                 = UDim2.new(0, 0, 0, 13),
        AutomaticSize        = Enum.AutomaticSize.X,
        Text                 = " " .. nType:upper() .. " ",
        TextColor3           = Color3.new(1, 1, 1),
        TextSize             = 9,
        Font                 = Enum.Font.GothamBold,
        ZIndex               = 995,
    })
    Corner(Badge, 3)

    if icon then
        New("TextLabel", {
            Parent               = TRow,
            BackgroundTransparency = 1,
            Size                 = UDim2.new(0, 14, 0, 14),
            Text                 = icon,
            TextColor3           = accent,
            TextSize             = 12,
            Font                 = Enum.Font.Gotham,
            ZIndex               = 995,
        })
    end

    New("TextLabel", {
        Parent               = TRow,
        BackgroundTransparency = 1,
        Size                 = UDim2.new(1, 0, 1, 0),
        Text                 = title,
        TextColor3           = T.Text,
        TextSize             = 12,
        Font                 = Enum.Font.GothamBold,
        TextXAlignment       = Enum.TextXAlignment.Left,
        ZIndex               = 995,
    })

    if content ~= "" then
        New("TextLabel", {
            Parent               = Inner,
            BackgroundTransparency = 1,
            Size                 = UDim2.new(1, 0, 0, 0),
            AutomaticSize        = Enum.AutomaticSize.Y,
            Text                 = content,
            TextColor3           = T.TextSub,
            TextSize             = 11,
            Font                 = Enum.Font.Gotham,
            TextXAlignment       = Enum.TextXAlignment.Left,
            TextWrapped          = true,
            ZIndex               = 994,
            LayoutOrder          = 2,
        })
    end

    local PBar = New("Frame", {
        Parent           = Card,
        BackgroundColor3 = accent,
        AnchorPoint      = Vector2.new(0, 1),
        Position         = UDim2.new(0, 0, 1, 0),
        Size             = UDim2.new(1, 0, 0, 2),
        BorderSizePixel  = 0,
        ZIndex           = 996,
    })
    Corner(PBar, 2)

    local CloseBtn = New("TextButton", {
        Parent               = Card,
        BackgroundTransparency = 1,
        AnchorPoint          = Vector2.new(1, 0),
        Position             = UDim2.new(1, -4, 0, 4),
        Size                 = UDim2.new(0, 16, 0, 16),
        Text                 = "✕",
        TextColor3           = T.TextDim,
        TextSize             = 10,
        Font                 = Enum.Font.GothamBold,
        ZIndex               = 997,
        AutoButtonColor      = false,
    })

    Card.Position = UDim2.new(1, 20, 0, 0)
    Tween(Card, { Position = UDim2.new(0, 0, 0, 0) }, 0.22, Enum.EasingStyle.Quint)

    local function Dismiss()
        Tween(Card, { Position = UDim2.new(1, 25, 0, 0) }, 0.18, Enum.EasingStyle.Quint)
        task.wait(0.2)
        if Wrapper.Parent then Wrapper:Destroy() end
    end

    CloseBtn.MouseButton1Click:Connect(Dismiss)

    local CardBtn = New("TextButton", {
        Parent               = Card,
        BackgroundTransparency = 1,
        Size                 = UDim2.new(1, 0, 1, 0),
        Text                 = "",
        ZIndex               = Card.ZIndex - 1,
        AutoButtonColor      = false,
    })
    CardBtn.MouseButton1Click:Connect(Dismiss)

    task.spawn(function()
        task.wait(0.05)
        Tween(PBar, { Size = UDim2.new(0, 0, 0, 2) }, duration, Enum.EasingStyle.Linear)
        task.wait(duration)
        Dismiss()
    end)
end

-- ====================================================================
--  MODAL / CONFIRM DIALOG
-- ====================================================================

function Library:Confirm(opt)
    opt = opt or {}
    local T = self.Theme

    local Overlay = New("Frame", {
        Name                 = "ConfirmOverlay",
        Parent               = ScreenGui,
        BackgroundColor3     = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.5,
        Size                 = UDim2.new(1, 0, 1, 0),
        ZIndex               = 970,
    })

    local Dialog = New("Frame", {
        Parent               = Overlay,
        BackgroundColor3     = T.Secondary,
        AnchorPoint          = Vector2.new(0.5, 0.5),
        Position             = UDim2.new(0.5, 0, 0.5, 0),
        Size                 = UDim2.new(0, 340, 0, 0),
        AutomaticSize        = Enum.AutomaticSize.Y,
        ZIndex               = 971,
    })
    Corner(Dialog, 11)
    Stroke(Dialog, T.Border, 1)

    local DInner = New("Frame", {
        Parent               = Dialog,
        BackgroundTransparency = 1,
        Size                 = UDim2.new(1, 0, 0, 0),
        AutomaticSize        = Enum.AutomaticSize.Y,
        ZIndex               = 972,
    })
    Pad(DInner, 20, 20, 20, 20)
    New("UIListLayout", {
        Parent    = DInner,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding   = UDim.new(0, 12),
    })

    New("TextLabel", {
        Parent               = DInner,
        BackgroundTransparency = 1,
        Size                 = UDim2.new(1, 0, 0, 18),
        Text                 = opt.Title or "Confirm",
        TextColor3           = T.Text,
        TextSize             = 15,
        Font                 = Enum.Font.GothamBold,
        TextXAlignment       = Enum.TextXAlignment.Left,
        ZIndex               = 973,
        LayoutOrder          = 1,
    })

    New("TextLabel", {
        Parent               = DInner,
        BackgroundTransparency = 1,
        Size                 = UDim2.new(1, 0, 0, 0),
        AutomaticSize        = Enum.AutomaticSize.Y,
        Text                 = opt.Message or "Are you sure?",
        TextColor3           = T.TextSub,
        TextSize             = 13,
        Font                 = Enum.Font.Gotham,
        TextXAlignment       = Enum.TextXAlignment.Left,
        TextWrapped          = true,
        ZIndex               = 973,
        LayoutOrder          = 2,
    })

    local BRow = New("Frame", {
        Parent               = DInner,
        BackgroundTransparency = 1,
        Size                 = UDim2.new(1, 0, 0, 34),
        ZIndex               = 973,
        LayoutOrder          = 3,
    })
    New("UIListLayout", {
        Parent              = BRow,
        FillDirection       = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment   = Enum.VerticalAlignment.Center,
        Padding             = UDim.new(0, 8),
    })

    local CancelBtn = New("TextButton", {
        Parent               = BRow,
        BackgroundColor3     = T.Tertiary,
        Size                 = UDim2.new(0, 90, 0, 30),
        Text                 = opt.CancelText or "Cancel",
        TextColor3           = T.TextSub,
        TextSize             = 12,
        Font                 = Enum.Font.Gotham,
        ZIndex               = 974,
        AutoButtonColor      = false,
    })
    Corner(CancelBtn, 7)
    Stroke(CancelBtn, T.Border, 1)

    local ConfirmBtn = New("TextButton", {
        Parent               = BRow,
        BackgroundColor3     = T.Error,
        Size                 = UDim2.new(0, 90, 0, 30),
        Text                 = opt.ConfirmText or "Confirm",
        TextColor3           = Color3.new(1, 1, 1),
        TextSize             = 12,
        Font                 = Enum.Font.GothamBold,
        ZIndex               = 974,
        AutoButtonColor      = false,
    })
    Corner(ConfirmBtn, 7)

    Dialog.BackgroundTransparency = 1
    Tween(Dialog, { BackgroundTransparency = 0 }, 0.2)
    Overlay.BackgroundTransparency = 1
    Tween(Overlay, { BackgroundTransparency = 0.5 }, 0.2)

    local function Close()
        Tween(Overlay, { BackgroundTransparency = 1 }, 0.18)
        task.wait(0.2)
        if Overlay.Parent then Overlay:Destroy() end
    end

    CancelBtn.MouseButton1Click:Connect(function()
        Close()
        if opt.OnCancel then task.spawn(opt.OnCancel) end
    end)

    ConfirmBtn.MouseButton1Click:Connect(function()
        Close()
        if opt.OnConfirm then task.spawn(opt.OnConfirm) end
    end)

    Overlay.MouseButton1Click:Connect(function()
        Close()
        if opt.OnCancel then task.spawn(opt.OnCancel) end
    end)
end

-- ====================================================================
--  LOADING SPINNER OVERLAY
-- ====================================================================

function Library:ShowLoading(message)
    local T = self.Theme

    local Overlay = New("Frame", {
        Parent               = ScreenGui,
        BackgroundColor3     = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.4,
        Size                 = UDim2.new(1, 0, 1, 0),
        ZIndex               = 960,
    })

    local Card = New("Frame", {
        Parent               = Overlay,
        BackgroundColor3     = T.Secondary,
        AnchorPoint          = Vector2.new(0.5, 0.5),
        Position             = UDim2.new(0.5, 0, 0.5, 0),
        Size                 = UDim2.new(0, 240, 0, 100),
        ZIndex               = 961,
    })
    Corner(Card, 11)
    Stroke(Card, T.Border, 1)

    local SpinFrame = New("Frame", {
        Parent               = Card,
        BackgroundTransparency = 1,
        AnchorPoint          = Vector2.new(0.5, 0),
        Position             = UDim2.new(0.5, 0, 0, 18),
        Size                 = UDim2.new(0, 28, 0, 28),
        ZIndex               = 962,
    })

    local SpinArc = New("ImageLabel", {
        Parent               = SpinFrame,
        BackgroundTransparency = 1,
        Size                 = UDim2.new(1, 0, 1, 0),
        Image                = "rbxassetid://4965945816",
        ImageColor3          = T.Accent,
        ZIndex               = 963,
    })

    New("TextLabel", {
        Parent               = Card,
        BackgroundTransparency = 1,
        AnchorPoint          = Vector2.new(0.5, 0),
        Position             = UDim2.new(0.5, 0, 0, 58),
        Size                 = UDim2.new(0.85, 0, 0, 16),
        Text                 = message or "Loading...",
        TextColor3           = T.TextSub,
        TextSize             = 12,
        Font                 = Enum.Font.Gotham,
        ZIndex               = 963,
    })

    local spinning = true
    task.spawn(function()
        local angle = 0
        while spinning and Overlay.Parent do
            angle = (angle + 4) % 360
            SpinArc.Rotation = angle
            RunService.RenderStepped:Wait()
        end
    end)

    return function()
        spinning = false
        Tween(Overlay, { BackgroundTransparency = 1 }, 0.18)
        task.wait(0.2)
        if Overlay.Parent then Overlay:Destroy() end
    end
end

-- ====================================================================
--  CREATE WINDOW
-- ====================================================================

function Library:CreateWindow(opt)
    opt = opt or {}

    local title         = opt.Title      or "BorcaHub"
    local subtitle      = opt.SubTitle   or ""
    local icon          = opt.Icon       or "◈"
    local winSize       = opt.Size       or UDim2.new(0, 820, 0, 560)
    local winPos        = opt.Position   or UDim2.new(0.5, -410, 0.5, -280)
    local themeName     = opt.Theme      or "Dark"
    local toggleKey     = opt.ToggleKey  or Enum.KeyCode.RightShift
    local showUserInfo  = opt.ShowUserInfo ~= false

    if Themes[themeName] then
        self.Theme = Themes[themeName]
        for i, n in ipairs(ThemeOrder) do
            if n == themeName then self._themeIdx = i; break end
        end
    end
    local T = self.Theme

    local WinFrame = New("Frame", {
        Name             = "BorcaHub_Win",
        Parent           = ScreenGui,
        BackgroundColor3 = T.Background,
        Position         = winPos,
        Size             = winSize,
        BorderSizePixel  = 0,
        ClipsDescendants = false,
        ZIndex           = 10,
    })
    Corner(WinFrame, 14)
    Stroke(WinFrame, T.Border, 1)

    New("ImageLabel", {
        Name                = "Shadow",
        Parent              = WinFrame,
        BackgroundTransparency = 1,
        Position            = UDim2.new(0, -30, 0, -30),
        Size                = UDim2.new(1, 60, 1, 60),
        ZIndex              = WinFrame.ZIndex - 1,
        Image               = "rbxassetid://6015897843",
        ImageColor3         = Color3.new(0, 0, 0),
        ImageTransparency   = 0.4,
        ScaleType           = Enum.ScaleType.Slice,
        SliceCenter         = Rect.new(49, 49, 450, 450),
    })

    -- TITLEBAR
    local TitleBar = New("Frame", {
        Name             = "TitleBar",
        Parent           = WinFrame,
        BackgroundColor3 = T.Secondary,
        Size             = UDim2.new(1, 0, 0, 46),
        BorderSizePixel  = 0,
        ZIndex           = 12,
    })
    Corner(TitleBar, 14)

    New("Frame", {
        Parent           = TitleBar,
        BackgroundColor3 = T.Secondary,
        Position         = UDim2.new(0, 0, 0.5, 0),
        Size             = UDim2.new(1, 0, 0.5, 0),
        BorderSizePixel  = 0,
        ZIndex           = 12,
    })

    New("Frame", {
        Parent           = TitleBar,
        BackgroundColor3 = T.Border,
        Position         = UDim2.new(0, 0, 1, -1),
        Size             = UDim2.new(1, 0, 0, 1),
        BorderSizePixel  = 0,
        ZIndex           = 13,
    })

    local LogoBadge = New("Frame", {
        Parent           = TitleBar,
        BackgroundColor3 = T.Accent,
        AnchorPoint      = Vector2.new(0, 0.5),
        Position         = UDim2.new(0, 12, 0.5, 0),
        Size             = UDim2.new(0, 28, 0, 28),
        ZIndex           = 14,
    })
    Corner(LogoBadge, 8)
    ThemeEngine.ApplyLogoGradient(LogoBadge)

    New("TextLabel", {
        Parent               = LogoBadge,
        BackgroundTransparency = 1,
        Size                 = UDim2.new(1, 0, 1, 0),
        Text                 = icon,
        TextColor3           = Color3.new(1, 1, 1),
        TextSize             = 13,
        Font                 = Enum.Font.GothamBold,
        ZIndex               = 15,
    })

    local TitleStack = New("Frame", {
        Parent               = TitleBar,
        BackgroundTransparency = 1,
        AnchorPoint          = Vector2.new(0, 0.5),
        Position             = UDim2.new(0, 48, 0.5, 0),
        Size                 = UDim2.new(0.35, 0, 0, 32),
        ZIndex               = 14,
    })
    New("UIListLayout", {
        Parent            = TitleStack,
        SortOrder         = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding           = UDim.new(0, 1),
    })
    New("TextLabel", {
        Parent               = TitleStack,
        BackgroundTransparency = 1,
        Size                 = UDim2.new(1, 0, 0, 16),
        Text                 = title,
        TextColor3           = T.Text,
        TextSize             = 13,
        Font                 = Enum.Font.GothamBold,
        TextXAlignment       = Enum.TextXAlignment.Left,
        ZIndex               = 14,
        LayoutOrder          = 1,
    })
    if subtitle ~= "" then
        New("TextLabel", {
            Parent               = TitleStack,
            BackgroundTransparency = 1,
            Size                 = UDim2.new(1, 0, 0, 12),
            Text                 = subtitle,
            TextColor3           = T.TextDim,
            TextSize             = 10,
            Font                 = Enum.Font.Gotham,
            TextXAlignment       = Enum.TextXAlignment.Left,
            ZIndex               = 14,
            LayoutOrder          = 2,
        })
    end

    local StatusInfo = New("TextLabel", {
        Parent               = TitleBar,
        BackgroundTransparency = 1,
        AnchorPoint          = Vector2.new(0.5, 0.5),
        Position             = UDim2.new(0.5, 0, 0.5, 0),
        Size                 = UDim2.new(0, 200, 1, 0),
        Text                 = "FPS: --  |  --:--",
        TextColor3           = T.TextSub,
        TextSize             = 11,
        Font                 = Enum.Font.Gotham,
        ZIndex               = 14,
    })

    task.spawn(function()
        local frames = 0
        local lastTime = os.clock()
        local conn

        conn = RunService.RenderStepped:Connect(function()
            if not WinFrame or not WinFrame.Parent then
                conn:Disconnect()
                return
            end

        frames = frames + 1
        local now = os.clock()

        if now - lastTime >= 1 then
            lastTime = now  -- set DULU sebelum reset frames
            local t = os.date("*t")
            local hour = t.hour % 12
            if hour == 0 then hour = 12 end
            local ampm = t.hour >= 12 and "PM" or "AM"
            StatusInfo.Text = string.format("FPS: %d   |   %02d:%02d %s", frames, hour, t.min, ampm)
            frames = 0
            end
        end)
    end)

    local function MakeCtrl(glyph, bgColor, textColor, xOff)
        local btn = New("TextButton", {
            Parent           = TitleBar,
            BackgroundColor3 = bgColor,
            AnchorPoint      = Vector2.new(1, 0.5),
            Position         = UDim2.new(1, -xOff, 0.5, 0),
            Size             = UDim2.new(0, 22, 0, 22),
            Text             = "",
            ZIndex           = 16,
            AutoButtonColor  = false,
        })
        Corner(btn, 11)
        New("TextLabel", {
            Parent               = btn,
            BackgroundTransparency = 1,
            Size                 = UDim2.new(1, 0, 1, 0),
            Text                 = glyph,
            TextColor3           = textColor,
            TextSize             = 10,
            Font                 = Enum.Font.GothamBold,
            ZIndex               = 17,
        })
        return btn
    end

    local CloseBtn = MakeCtrl("✕", Color3.fromRGB(58, 30, 30), Color3.fromRGB(212, 96, 96), 14)
    CloseBtn.MouseEnter:Connect(function()
        Tween(CloseBtn, { BackgroundColor3 = Color3.fromRGB(107, 32, 32) }, 0.12)
    end)
    CloseBtn.MouseLeave:Connect(function()
        Tween(CloseBtn, { BackgroundColor3 = Color3.fromRGB(58, 30, 30) }, 0.12)
    end)

    local MinBtn = MakeCtrl("─", Color3.fromRGB(58, 58, 42), Color3.fromRGB(200, 176, 96), 42)
    MinBtn.MouseEnter:Connect(function()
        Tween(MinBtn, { BackgroundColor3 = Color3.fromRGB(85, 85, 32) }, 0.12)
    end)
    MinBtn.MouseLeave:Connect(function()
        Tween(MinBtn, { BackgroundColor3 = Color3.fromRGB(58, 58, 42) }, 0.12)
    end)

    New("Frame", {
        Name             = "TBDivider",
        Parent           = TitleBar,
        BackgroundColor3 = T.Border,
        AnchorPoint      = Vector2.new(1, 0.5),
        Position         = UDim2.new(1, -70, 0.5, 0),
        Size             = UDim2.new(0, 1, 0, 18),
        BorderSizePixel  = 0,
        ZIndex           = 16,
    })

    local SBToggleBtn = New("TextButton", {
        Parent               = TitleBar,
        BackgroundColor3     = T.Accent,
        BackgroundTransparency = 0.87,
        AnchorPoint          = Vector2.new(1, 0.5),
        Position             = UDim2.new(1, -90, 0.5, 0),
        Size                 = UDim2.new(0, 26, 0, 26),
        Text                 = "☰",
        TextColor3           = T.Accent,
        TextSize             = 14,
        Font                 = Enum.Font.GothamBold,
        ZIndex               = 16,
        AutoButtonColor      = false,
    })
    Corner(SBToggleBtn, 6)
    SBToggleBtn.MouseEnter:Connect(function()
        if not SBToggleBtn:GetAttribute("active") then
            Tween(SBToggleBtn, { BackgroundTransparency = 0.75, TextColor3 = T.Text }, 0.1)
        end
    end)
    SBToggleBtn.MouseLeave:Connect(function()
        if not SBToggleBtn:GetAttribute("active") then
            Tween(SBToggleBtn, { BackgroundTransparency = 1, TextColor3 = T.TextDim }, 0.1)
        end
    end)

    -- BODY
    local Body = New("Frame", {
        Name                 = "Body",
        Parent               = WinFrame,
        BackgroundTransparency = 1,
        Position             = UDim2.new(0, 0, 0, 46),
        Size                 = UDim2.new(1, 0, 1, -46),
        ClipsDescendants     = true,
        ZIndex               = 11,
    })

    -- SIDEBAR
    local SIDEBAR_FULL  = 170
    local SIDEBAR_SLIM  = 46
    local sidebarSlim   = false

    local Sidebar = New("Frame", {
        Name             = "Sidebar",
        Parent           = Body,
        BackgroundColor3 = T.Secondary,
        Size             = UDim2.new(0, SIDEBAR_FULL, 1, 0),
        BorderSizePixel  = 0,
        ZIndex           = 12,
        ClipsDescendants = true,
    })

    local SBFootHeight = showUserInfo and 44 or 0
    local NavScroll = New("ScrollingFrame", {
        Parent               = Sidebar,
        BackgroundTransparency = 1,
        Position             = UDim2.new(0, 0, 0, 0),
        Size                 = UDim2.new(1, 0, 1, -SBFootHeight),
        BorderSizePixel      = 0,
        ScrollBarThickness   = 2,
        ScrollBarImageColor3 = T.ScrollBar,
        CanvasSize           = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize  = Enum.AutomaticSize.Y,
        ZIndex               = 13,
        ClipsDescendants     = true,
    })
    Pad(NavScroll, 6, 6, 6, 6)
    New("UIListLayout", {
        Parent    = NavScroll,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding   = UDim.new(0, 2),
    })

    local SBFoot = New("Frame", {
        Parent           = Sidebar,
        BackgroundColor3 = T.Secondary,
        AnchorPoint      = Vector2.new(0, 1),
        Position         = UDim2.new(0, 0, 1, 0),
        Size             = UDim2.new(1, 0, 0, 44),
        BorderSizePixel  = 0,
        ZIndex           = 13,
        Visible          = showUserInfo,
    })
    New("Frame", {
        Parent           = SBFoot,
        BackgroundColor3 = T.Border,
        Position         = UDim2.new(0, 0, 0, 0),
        Size             = UDim2.new(1, 0, 0, 1),
        ZIndex           = 13,
    })

    local UserRow = New("Frame", {
        Parent               = SBFoot,
        BackgroundTransparency = 1,
        Position             = UDim2.new(0, 8, 0, 8),
        Size                 = UDim2.new(1, -16, 0, 28),
        ZIndex               = 14,
    })
    New("UIListLayout", {
        Parent            = UserRow,
        FillDirection     = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding           = UDim.new(0, 8),
    })

    local AvatarFrame = New("Frame", {
        Parent           = UserRow,
        BackgroundColor3 = T.Secondary,
        Size             = UDim2.new(0, 26, 0, 26),
        ZIndex           = 14,
    })
    Corner(AvatarFrame, 13)
    Stroke(AvatarFrame, T.Border, 1)

    local userId = LocalPlayer.UserId
    local thumbType = Enum.ThumbnailType.HeadShot
    local thumbSize = Enum.ThumbnailSize.Size48x48
    local avatarUrl = ""
    pcall(function()
        avatarUrl = Players:GetUserThumbnailAsync(userId, thumbType, thumbSize)
    end)

    local AvatarImage = New("ImageLabel", {
        Parent                 = AvatarFrame,
        BackgroundTransparency = 1,
        Size                   = UDim2.new(1, 0, 1, 0),
        Image                  = avatarUrl,
        ZIndex                 = 15,
    })
    Corner(AvatarImage, 13)

    local UserInfoCol = New("Frame", {
        Parent               = UserRow,
        BackgroundTransparency = 1,
        Size                 = UDim2.new(1, -34, 1, 0),
        ZIndex               = 14,
    })
    New("UIListLayout", {
        Parent            = UserInfoCol,
        SortOrder         = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding           = UDim.new(0, 1),
    })

    local UserNameLbl = New("TextLabel", {
        Parent               = UserInfoCol,
        BackgroundTransparency = 1,
        Size                 = UDim2.new(1, 0, 0, 13),
        Text                 = LocalPlayer.Name,
        TextColor3           = T.TextSub,
        TextSize             = 11,
        Font                 = Enum.Font.Gotham,
        TextXAlignment       = Enum.TextXAlignment.Left,
        ZIndex               = 14,
        TextTruncate         = Enum.TextTruncate.AtEnd,
        LayoutOrder          = 1,
    })

    local UserTierLbl = New("TextLabel", {
        Parent               = UserInfoCol,
        BackgroundTransparency = 1,
        Size                 = UDim2.new(1, 0, 0, 12),
        Text                 = "✦ Free",
        TextColor3           = T.TextSub,
        TextSize             = 10,
        Font                 = Enum.Font.GothamBold,
        TextXAlignment       = Enum.TextXAlignment.Left,
        ZIndex               = 14,
        LayoutOrder          = 2,
    })

    local SBDivider = New("Frame", {
        Name             = "SBDivider",
        Parent           = Body,
        BackgroundColor3 = T.Border,
        Position         = UDim2.new(0, SIDEBAR_FULL, 0, 0),
        Size             = UDim2.new(0, 1, 1, 0),
        ZIndex           = 13,
    })

    -- PAGE CONTAINER
    local PageContainer = New("Frame", {
        Name                 = "PageContainer",
        Parent               = Body,
        BackgroundTransparency = 1,
        Position             = UDim2.new(0, SIDEBAR_FULL + 1, 0, 0),
        Size                 = UDim2.new(1, -(SIDEBAR_FULL + 1), 1, 0),
        ClipsDescendants     = true,
        ZIndex               = 12,
    })

    -- WINDOW OBJECT
    local Win = {
        Frame         = WinFrame,
        TitleBar      = TitleBar,
        Body          = Body,
        Sidebar       = Sidebar,
        NavScroll     = NavScroll,
        PageContainer = PageContainer,
        Theme         = T,
        _tabs         = {},
        _activeTab    = nil,
        _visible      = true,
        _minimized    = false,
        _origSize     = winSize,
        _origPos      = winPos,
        _userTierLbl  = UserTierLbl,
        _userNameLbl  = UserNameLbl,
        _toggleKey    = toggleKey,
    }

    function Win:SetUserInfo(name, tier)
        self._userNameLbl.Text = name or LocalPlayer.Name
        if tier == "Premium" then
            self._userTierLbl.Text       = "✦ Premium"
            self._userTierLbl.TextColor3 = T.Gold
        else
            self._userTierLbl.Text       = "✦ Free"
            self._userTierLbl.TextColor3 = T.TextSub
        end
    end

    function Win:SetTitle(newTitle, newSubtitle)
        local titleLbl = TitleStack:FindFirstChild("TextLabel") or
            TitleStack:GetChildren()[1]
        if titleLbl and titleLbl:IsA("TextLabel") then
            titleLbl.Text = newTitle or title
        end
        if newSubtitle ~= nil then
            local subLbl = TitleStack:GetChildren()[2]
            if subLbl and subLbl:IsA("TextLabel") then
                subLbl.Text = newSubtitle
                subLbl.Visible = newSubtitle ~= ""
            end
        end
    end

    -- DRAGGING
    do
        local dragging, dragInput, startPos, startMouse

        TitleBar.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
                dragging   = true
                startPos   = WinFrame.Position
                startMouse = inp.Position
                inp.Changed:Connect(function()
                    if inp.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)

        TitleBar.InputChanged:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseMovement
            or inp.UserInputType == Enum.UserInputType.Touch then
                dragInput = inp
            end
        end)

        UserInputService.InputChanged:Connect(function(inp)
            if inp == dragInput and dragging then
                local d = inp.Position - startMouse
                WinFrame.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + d.X,
                    startPos.Y.Scale, startPos.Y.Offset + d.Y
                )
            end
        end)
    end

    -- SIDEBAR TOGGLE
    local function ToggleSidebar()
        sidebarSlim = not sidebarSlim
        local w = sidebarSlim and SIDEBAR_SLIM or SIDEBAR_FULL

        Tween(Sidebar,       { Size     = UDim2.new(0, w, 1, 0)       }, 0.2, Enum.EasingStyle.Quint)
        Tween(SBDivider,     { Position = UDim2.new(0, w, 0, 0)       }, 0.2, Enum.EasingStyle.Quint)
        Tween(PageContainer, {
            Position = UDim2.new(0, w + 1, 0, 0),
            Size     = UDim2.new(1, -(w + 1), 1, 0),
        }, 0.2, Enum.EasingStyle.Quint)

        if sidebarSlim then
            SBToggleBtn:SetAttribute("active", false)
            Tween(SBToggleBtn, { BackgroundTransparency = 1, TextColor3 = T.TextDim }, 0.15)
        else
            SBToggleBtn:SetAttribute("active", true)
            Tween(SBToggleBtn, { BackgroundTransparency = 0.87, TextColor3 = T.Accent }, 0.15)
        end

        for _, tab in ipairs(Win._tabs) do
            if tab._navNameLbl then
                tab._navNameLbl.Visible = not sidebarSlim
            end
        end

        UserInfoCol.Visible  = not sidebarSlim
        UserNameLbl.Visible  = not sidebarSlim
        UserTierLbl.Visible  = not sidebarSlim
    end

    SBToggleBtn.MouseButton1Click:Connect(ToggleSidebar)

    -- MINIMIZE
    local lastWidth = winSize.X.Offset
    local LogoText = nil
    for _, child in ipairs(LogoBadge:GetChildren()) do
        if child:IsA("TextLabel") then LogoText = child break end
    end

    local clickTime = 0
    local clickPos = Vector3.new()
    TitleBar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            clickTime = tick()
            clickPos = inp.Position
        end
    end)

    TitleBar.InputEnded:Connect(function(inp)
        if (inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch) then
            if Win._minimized and tick() - clickTime < 0.3 and (inp.Position - clickPos).Magnitude < 10 then
                Win._minimized = false
                Tween(WinFrame, { Size = UDim2.new(0, lastWidth, 0, winSize.Y.Offset) }, 0.22, Enum.EasingStyle.Quint)
                Tween(LogoBadge, { Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) }, 0.22, Enum.EasingStyle.Quint)
                if LogoText then LogoText.Text = icon end
                local Shadow = WinFrame:FindFirstChild("Shadow")
                if Shadow then
                    Tween(Shadow, { Size = UDim2.new(1, 60, 1, 60), Position = UDim2.new(0, -30, 0, -30), ImageTransparency = 0.4 }, 0.22, Enum.EasingStyle.Quint)
                end
                TitleBar.ClipsDescendants = false
                for _, child in ipairs(TitleBar:GetChildren()) do
                    if child ~= LogoBadge and child:IsA("GuiObject") then
                        child.Visible = true
                    end
                end
            end
        end
    end)

    MinBtn.MouseButton1Click:Connect(function()
        if not Win._minimized then
            Win._minimized = true
            lastWidth = WinFrame.AbsoluteSize.X
            TitleBar.ClipsDescendants = true
            for _, child in ipairs(TitleBar:GetChildren()) do
                if child ~= LogoBadge and child:IsA("GuiObject") then
                    child.Visible = false
                end
            end
            LogoBadge.AnchorPoint = Vector2.new(0.5, 0.5)
            Tween(LogoBadge, { Position = UDim2.new(0.5, 0, 0.5, 0) }, 0.22, Enum.EasingStyle.Quint)
            if LogoText then LogoText.Text = "B" end
            local Shadow = WinFrame:FindFirstChild("Shadow")
            if Shadow then
                Tween(Shadow, { Size = UDim2.new(1, 30, 1, 30), Position = UDim2.new(0, -15, 0, -15), ImageTransparency = 0.5 }, 0.22, Enum.EasingStyle.Quint)
            end
            Tween(WinFrame, { Size = UDim2.new(0, 46, 0, 46) }, 0.22, Enum.EasingStyle.Quint)
        end
    end)

    -- CLOSE
    CloseBtn.MouseButton1Click:Connect(function()
        Tween(WinFrame, { Size = UDim2.new(0, winSize.X.Offset, 0, 0) }, 0.22, Enum.EasingStyle.Quint)
        task.wait(0.24)
        WinFrame.Visible = false
        Win._visible = false
        for _, conn in ipairs(self._tooltipConns) do
            pcall(function() conn:Disconnect() end)
        end
        self._tooltipConns = {}
    end)

    -- TOGGLE KEY
    table.insert(self._keybinds, {
        Key = toggleKey,
        Cb  = function()
            Win._visible = not Win._visible
            WinFrame.Visible = Win._visible
            if Win._visible and not Win._minimized then
                WinFrame.Size = UDim2.new(0, winSize.X.Offset, 0, 0)
                Tween(WinFrame, { Size = winSize }, 0.22, Enum.EasingStyle.Quint)
            end
        end,
    })

    UserInputService.InputBegan:Connect(function(inp, gpe)
        if gpe then return end
        for _, kb in ipairs(self._keybinds) do
            if inp.KeyCode == kb.Key then
                task.spawn(kb.Cb)
            end
        end
    end)

    -- OPEN ANIMATION
    WinFrame.Size = UDim2.new(0, winSize.X.Offset * 0.92, 0, winSize.Y.Offset * 0.92)
    WinFrame.BackgroundTransparency = 1
    WinFrame.Position = UDim2.new(
        winPos.X.Scale, winPos.X.Offset + winSize.X.Offset * 0.04,
        winPos.Y.Scale, winPos.Y.Offset + winSize.Y.Offset * 0.04
    )
    Tween(WinFrame, {
        Size                 = winSize,
        BackgroundTransparency = 0,
        Position             = winPos,
    }, 0.36, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

    -- ================================================================
    --  CREATE TAB
    -- ================================================================

    function Win:CreateTab(tabOpt)
        tabOpt = tabOpt or {}
        local tabName   = tabOpt.Name  or "Tab"
        local tabIcon   = tabOpt.Icon  or ""
        local tabBadge  = tabOpt.Badge or nil
        local T         = Library.Theme

        local NavBtn = New("TextButton", {
            Name                   = "Nav_" .. tabName,
            Parent                 = NavScroll,
            BackgroundColor3       = T.Accent,
            BackgroundTransparency = 1,
            Size                   = UDim2.new(1, 0, 0, 34),
            Text                   = "",
            ZIndex                 = 14,
            AutoButtonColor        = false,
        })
        Corner(NavBtn, 7)

        local ActiveBar = New("Frame", {
            Parent           = NavBtn,
            BackgroundColor3 = T.Accent,
            AnchorPoint      = Vector2.new(0, 0.5),
            Position         = UDim2.new(0, 0, 0.5, 0),
            Size             = UDim2.new(0, 3, 0, 0),
            BorderSizePixel  = 0,
            ZIndex           = 15,
        })
        Corner(ActiveBar, 2)

        local NavInner = New("Frame", {
            Parent               = NavBtn,
            BackgroundTransparency = 1,
            Position             = UDim2.new(0, 8, 0, 0),
            Size                 = UDim2.new(1, -8, 1, 0),
            ZIndex               = 15,
        })
        New("UIListLayout", {
            Parent            = NavInner,
            FillDirection     = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding           = UDim.new(0, 9),
        })

        local NavIconLbl
        if tabIcon ~= "" then
            NavIconLbl = New("TextLabel", {
                Parent               = NavInner,
                BackgroundTransparency = 1,
                Size                 = UDim2.new(0, 18, 1, 0),
                Text                 = tabIcon,
                TextColor3           = T.TextSub,
                TextSize             = 16,
                Font                 = Enum.Font.Gotham,
                ZIndex               = 15,
            })
        end

        local NavNameLbl = New("TextLabel", {
            Parent               = NavInner,
            BackgroundTransparency = 1,
            Size                 = UDim2.new(1, 0, 1, 0),
            Text                 = tabName,
            TextColor3           = T.TextSub,
            TextSize             = 12,
            Font                 = Enum.Font.Gotham,
            TextXAlignment       = Enum.TextXAlignment.Left,
            ZIndex               = 15,
        })

        local NavBadgeLbl
        if tabBadge then
            NavBadgeLbl = New("TextLabel", {
                Parent               = NavBtn,
                BackgroundColor3     = T.Accent,
                BackgroundTransparency = 0,
                AnchorPoint          = Vector2.new(1, 0.5),
                Position             = UDim2.new(1, -8, 0.5, 0),
                Size                 = UDim2.new(0, 0, 0, 14),
                AutomaticSize        = Enum.AutomaticSize.X,
                Text                 = " " .. tabBadge .. " ",
                TextColor3           = Color3.new(1, 1, 1),
                TextSize             = 9,
                Font                 = Enum.Font.GothamBold,
                ZIndex               = 16,
            })
            Corner(NavBadgeLbl, 4)
        end

        local Page = New("ScrollingFrame", {
            Name                   = "Page_" .. tabName,
            Parent                 = PageContainer,
            BackgroundTransparency = 1,
            Size                   = UDim2.new(1, 0, 1, 0),
            BorderSizePixel        = 0,
            ScrollBarThickness     = 3,
            ScrollBarImageColor3   = T.ScrollBar,
            ScrollBarImageTransparency = 0.3,
            Visible                = false,
            ZIndex                 = 13,
            CanvasSize             = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize    = Enum.AutomaticSize.Y,
            ScrollingDirection     = Enum.ScrollingDirection.Y,
        })

        local PageInner = New("Frame", {
            Parent               = Page,
            BackgroundTransparency = 1,
            Size                 = UDim2.new(1, 0, 0, 0),
            AutomaticSize        = Enum.AutomaticSize.Y,
            ZIndex               = 13,
        })
        New("UIListLayout", {
            Parent    = PageInner,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding   = UDim.new(0, 10),
        })
        Pad(PageInner, 12, 12, 14, 12)

        local Tab = {
            Page        = Page,
            PageInner   = PageInner,
            NavBtn      = NavBtn,
            _order      = 0,
            _navNameLbl = NavNameLbl,
            _navIconLbl = NavIconLbl,
            _badgeLbl   = NavBadgeLbl,
            _activeBar  = ActiveBar,
        }
        table.insert(Win._tabs, Tab)

        if #Win._tabs == 1 then
            Page.Visible = true
            Win._activeTab = Tab
            NavBtn.BackgroundTransparency = 0.9
            Tween(ActiveBar, { Size = UDim2.new(0, 3, 0.55, 0) }, 0.15)
            NavNameLbl.TextColor3 = T.Accent
            NavNameLbl.Font = Enum.Font.GothamBold
            if NavIconLbl then NavIconLbl.TextColor3 = T.Accent end
        end

        function Tab:SetBadge(text)
            if self._badgeLbl then
                self._badgeLbl.Text = " " .. tostring(text) .. " "
                self._badgeLbl.Visible = true
            end
        end
        function Tab:ClearBadge()
            if self._badgeLbl then
                self._badgeLbl.Visible = false
            end
        end

        function Tab:Select()
            if Win._activeTab == Tab then return end
            if Win._activeTab then
                local old = Win._activeTab
                old.Page.Visible = false
                Tween(old.NavBtn, { BackgroundTransparency = 1 }, 0.15)
                if old._activeBar then
                    Tween(old._activeBar, { Size = UDim2.new(0, 3, 0, 0) }, 0.15)
                end
                if old._navNameLbl then
                    old._navNameLbl.TextColor3 = T.TextSub
                    old._navNameLbl.Font = Enum.Font.Gotham
                end
                if old._navIconLbl then
                    old._navIconLbl.TextColor3 = T.TextSub
                end
            end
            Win._activeTab = Tab
            Page.Visible = true
            Tween(NavBtn, { BackgroundTransparency = 0.9 }, 0.15)
            Tween(ActiveBar, { Size = UDim2.new(0, 3, 0.55, 0) }, 0.15)
            NavNameLbl.TextColor3 = T.Accent
            NavNameLbl.Font = Enum.Font.GothamBold
            if NavIconLbl then NavIconLbl.TextColor3 = T.Accent end
        end

        NavBtn.MouseButton1Click:Connect(function()
            if Win._activeTab == Tab then return end
            if Win._activeTab then
                local old = Win._activeTab
                old.Page.Visible = false
                Tween(old.NavBtn, { BackgroundTransparency = 1 }, 0.15)
                if old._activeBar then
                    Tween(old._activeBar, { Size = UDim2.new(0, 3, 0, 0) }, 0.15)
                end
                if old._navNameLbl then
                    old._navNameLbl.TextColor3 = T.TextSub
                    old._navNameLbl.Font = Enum.Font.Gotham
                end
                if old._navIconLbl then
                    old._navIconLbl.TextColor3 = T.TextSub
                end
            end
            Win._activeTab = Tab
            Page.Visible = true
            Tween(NavBtn, { BackgroundTransparency = 0.9 }, 0.15)
            Tween(ActiveBar, { Size = UDim2.new(0, 3, 0.55, 0) }, 0.15)
            NavNameLbl.TextColor3 = T.Accent
            NavNameLbl.Font = Enum.Font.GothamBold
            if NavIconLbl then NavIconLbl.TextColor3 = T.Accent end
        end)

        NavBtn.MouseEnter:Connect(function()
            if Win._activeTab ~= Tab then
                Tween(NavBtn, { BackgroundTransparency = 0.88 }, 0.1)
                NavNameLbl.TextColor3 = T.Text
            end
        end)
        NavBtn.MouseLeave:Connect(function()
            if Win._activeTab ~= Tab then
                Tween(NavBtn, { BackgroundTransparency = 1 }, 0.1)
                NavNameLbl.TextColor3 = T.TextSub
            end
        end)

        -- ===========================================================
        --  CREATE SECTION
        -- ===========================================================

        function Tab:CreateSection(secName, secOpt)
            secOpt = secOpt or {}
            local T           = Library.Theme
            local collapsible = secOpt.Collapsible or false
            local collapsed   = secOpt.Collapsed   or false

            local SecWrap = New("Frame", {
                Parent               = PageInner,
                BackgroundTransparency = 1,
                Size                 = UDim2.new(1, 0, 0, 0),
                AutomaticSize        = Enum.AutomaticSize.Y,
                ZIndex               = 14,
                LayoutOrder          = Tab._order,
            })
            Tab._order += 1

            local SecFrame = New("Frame", {
                Parent           = SecWrap,
                BackgroundColor3 = T.Secondary,
                Size             = UDim2.new(1, 0, 0, 0),
                AutomaticSize    = Enum.AutomaticSize.Y,
                BorderSizePixel  = 0,
                ZIndex           = 14,
            })
            Corner(SecFrame, 11)
            Stroke(SecFrame, T.Border, 1)

            local SecHeader = New("Frame", {
                Parent           = SecFrame,
                BackgroundColor3 = T.Tertiary,
                Size             = UDim2.new(1, 0, 0, 34),
                BorderSizePixel  = 0,
                ZIndex           = 15,
            })
            Corner(SecHeader, 11)
            New("Frame", {
                Parent           = SecHeader,
                BackgroundColor3 = T.Tertiary,
                Position         = UDim2.new(0, 0, 0.5, 0),
                Size             = UDim2.new(1, 0, 0.5, 0),
                BorderSizePixel  = 0,
                ZIndex           = 15,
            })

            New("Frame", {
                Parent           = SecHeader,
                BackgroundColor3 = T.Accent,
                Position         = UDim2.new(0, 13, 0.2, 0),
                Size             = UDim2.new(0, 3, 0.6, 0),
                BorderSizePixel  = 0,
                ZIndex           = 16,
            })

            New("TextLabel", {
                Parent               = SecHeader,
                BackgroundTransparency = 1,
                Position             = UDim2.new(0, 22, 0, 0),
                Size                 = UDim2.new(0.8, 0, 1, 0),
                Text                 = secName or "Section",
                TextColor3           = T.Text,
                TextSize             = 13,
                Font                 = Enum.Font.GothamBold,
                TextXAlignment       = Enum.TextXAlignment.Left,
                ZIndex               = 16,
            })

            local CollapseArrow
            if collapsible then
                CollapseArrow = New("TextLabel", {
                    Parent               = SecHeader,
                    BackgroundTransparency = 1,
                    AnchorPoint          = Vector2.new(1, 0.5),
                    Position             = UDim2.new(1, -12, 0.5, 0),
                    Size                 = UDim2.new(0, 14, 0, 14),
                    Text                 = collapsed and "⌄" or "⌃",
                    TextColor3           = T.TextDim,
                    TextSize             = 13,
                    Font                 = Enum.Font.GothamBold,
                    ZIndex               = 16,
                })
            end

            local SecBody = New("Frame", {
                Parent               = SecFrame,
                BackgroundTransparency = 1,
                Position             = UDim2.new(0, 0, 0, 34),
                Size                 = UDim2.new(1, 0, 0, 0),
                AutomaticSize        = Enum.AutomaticSize.Y,
                ZIndex               = 15,
                Visible              = not collapsed,
            })
            New("UIListLayout", {
                Parent    = SecBody,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding   = UDim.new(0, 0),
            })
            Pad(SecBody, 8, 13, 10, 13)

            if collapsible and CollapseArrow then
                local headerBtn = New("TextButton", {
                    Parent               = SecHeader,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, 0, 1, 0),
                    Text                 = "",
                    ZIndex               = 17,
                    AutoButtonColor      = false,
                })
                headerBtn.MouseButton1Click:Connect(function()
                    collapsed = not collapsed
                    SecBody.Visible = not collapsed
                    CollapseArrow.Text = collapsed and "⌄" or "⌃"
                end)
            end

            local Sec = { Frame = SecFrame, Body = SecBody, _order = 0 }

            -- =======================================================
            --  INTERNAL ROW BUILDERS
            -- =======================================================

            local function BaseRow(h, autoY)
                local row = New("Frame", {
                    Parent               = SecBody,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, 0, 0, h or 38),
                    ZIndex               = 16,
                    LayoutOrder          = Sec._order,
                    AutomaticSize        = autoY and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
                })
                Sec._order += 1
                return row
            end

            local function RowBg(parent)
                local bg = New("Frame", {
                    Parent           = parent,
                    BackgroundColor3 = T.Tertiary,
                    Size             = UDim2.new(1, 0, 1, 0),
                    ZIndex           = 17,
                })
                Corner(bg, 7)
                return bg
            end

            local function RowLabel(parent, text, xOff, wScale)
                return New("TextLabel", {
                    Parent               = parent,
                    BackgroundTransparency = 1,
                    Position             = UDim2.new(0, xOff or 10, 0, 0),
                    Size                 = UDim2.new(wScale or 0.6, 0, 1, 0),
                    Text                 = text,
                    TextColor3           = T.Text,
                    TextSize             = 12,
                    Font                 = Enum.Font.Gotham,
                    TextXAlignment       = Enum.TextXAlignment.Left,
                    ZIndex               = 18,
                })
            end

            local function SubLabel(parent, text)
                if not text or text == "" then return end
                New("TextLabel", {
                    Parent               = parent,
                    BackgroundTransparency = 1,
                    Position             = UDim2.new(0, 10, 0.55, 0),
                    Size                 = UDim2.new(0.7, 0, 0.42, 0),
                    Text                 = text,
                    TextColor3           = T.TextSub,
                    TextSize             = 11,
                    Font                 = Enum.Font.Gotham,
                    TextXAlignment       = Enum.TextXAlignment.Left,
                    ZIndex               = 18,
                })
            end

            -- ========================================================
            --  SEPARATOR
            -- ========================================================
            function Sec:AddSeparator(sOpt)
                sOpt = sOpt or {}
                local label = sOpt.Label or sOpt.Name or nil

                local row = New("Frame", {
                    Parent               = SecBody,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, 0, 0, label and 20 or 12),
                    ZIndex               = 17,
                    LayoutOrder          = Sec._order,
                })
                Sec._order += 1

                if label then
                    local leftLine = New("Frame", {
                        Parent           = row,
                        BackgroundColor3 = T.Border,
                        AnchorPoint      = Vector2.new(0, 0.5),
                        Position         = UDim2.new(0, 0, 0.5, 0),
                        Size             = UDim2.new(0, 0, 0, 1),
                        ZIndex           = 17,
                    })
                    local lbl = New("TextLabel", {
                        Parent               = row,
                        BackgroundTransparency = 1,
                        AnchorPoint          = Vector2.new(0.5, 0.5),
                        Position             = UDim2.new(0.5, 0, 0.5, 0),
                        Size                 = UDim2.new(0, 0, 0, 14),
                        AutomaticSize        = Enum.AutomaticSize.X,
                        Text                 = "  " .. label .. "  ",
                        TextColor3           = T.TextDim,
                        TextSize             = 10,
                        Font                 = Enum.Font.GothamBold,
                        ZIndex               = 18,
                    })
                    local rightLine = New("Frame", {
                        Parent           = row,
                        BackgroundColor3 = T.Border,
                        AnchorPoint      = Vector2.new(1, 0.5),
                        Position         = UDim2.new(1, 0, 0.5, 0),
                        Size             = UDim2.new(0, 0, 0, 1),
                        ZIndex           = 17,
                    })
                    task.defer(function()
                        if not lbl.Parent then return end
                        local lw = lbl.AbsoluteSize.X
                        local rw = row.AbsoluteSize.X
                        local half = (rw - lw) / 2
                        leftLine.Size  = UDim2.new(0, half - 4, 0, 1)
                        rightLine.Size = UDim2.new(0, half - 4, 0, 1)
                    end)
                else
                    New("Frame", {
                        Parent           = row,
                        BackgroundColor3 = T.Border,
                        AnchorPoint      = Vector2.new(0, 0.5),
                        Position         = UDim2.new(0, 0, 0.5, 0),
                        Size             = UDim2.new(1, 0, 0, 1),
                        ZIndex           = 17,
                    })
                end

                return { Frame = row }
            end

            -- ========================================================
            --  INFO TEXT BLOCK
            -- ========================================================
            function Sec:AddText(tOpt)
                tOpt = tOpt or {}
                local text    = tOpt.Text    or tOpt.Name or ""
                local subText = tOpt.Sub     or tOpt.Description or nil
                local icon    = tOpt.Icon    or nil
                local color   = tOpt.Color   or T.TextSub

                local row = New("Frame", {
                    Parent               = SecBody,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, 0, 0, 0),
                    AutomaticSize        = Enum.AutomaticSize.Y,
                    ZIndex               = 17,
                    LayoutOrder          = Sec._order,
                })
                Sec._order += 1

                local bg = New("Frame", {
                    Parent           = row,
                    BackgroundColor3 = T.Tertiary,
                    BackgroundTransparency = 0.4,
                    Size             = UDim2.new(1, 0, 0, 0),
                    AutomaticSize    = Enum.AutomaticSize.Y,
                    ZIndex           = 17,
                })
                Corner(bg, 7)
                Pad(bg, 8, 12, 8, 12)
                New("UIListLayout", {
                    Parent    = bg,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding   = UDim.new(0, 3),
                })

                local topRow = New("Frame", {
                    Parent               = bg,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, 0, 0, 0),
                    AutomaticSize        = Enum.AutomaticSize.Y,
                    ZIndex               = 18,
                    LayoutOrder          = 1,
                })
                New("UIListLayout", {
                    Parent            = topRow,
                    FillDirection     = Enum.FillDirection.Horizontal,
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                    Padding           = UDim.new(0, 6),
                })

                if icon then
                    New("TextLabel", {
                        Parent               = topRow,
                        BackgroundTransparency = 1,
                        Size                 = UDim2.new(0, 16, 0, 16),
                        Text                 = icon,
                        TextColor3           = color,
                        TextSize             = 14,
                        Font                 = Enum.Font.Gotham,
                        ZIndex               = 18,
                    })
                end

                local mainLbl = New("TextLabel", {
                    Parent               = topRow,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, icon and -22 or 0, 0, 0),
                    AutomaticSize        = Enum.AutomaticSize.Y,
                    Text                 = text,
                    TextColor3           = color,
                    TextSize             = 12,
                    Font                 = Enum.Font.Gotham,
                    TextXAlignment       = Enum.TextXAlignment.Left,
                    TextWrapped          = true,
                    ZIndex               = 18,
                })

                if subText then
                    New("TextLabel", {
                        Parent               = bg,
                        BackgroundTransparency = 1,
                        Size                 = UDim2.new(1, 0, 0, 0),
                        AutomaticSize        = Enum.AutomaticSize.Y,
                        Text                 = subText,
                        TextColor3           = T.TextDim,
                        TextSize             = 10,
                        Font                 = Enum.Font.Gotham,
                        TextXAlignment       = Enum.TextXAlignment.Left,
                        TextWrapped          = true,
                        ZIndex               = 18,
                        LayoutOrder          = 2,
                    })
                end

                return {
                    Frame  = row,
                    SetText = function(_, v)
                        mainLbl.Text = v
                    end,
                }
            end

            -- ========================================================
            --  PROGRESS BAR
            -- ========================================================
            function Sec:AddProgressBar(pOpt)
                pOpt = pOpt or {}
                local val     = math.clamp(pOpt.Default or 0, 0, 100)
                local suffix  = pOpt.Suffix   or "%"
                local showVal = pOpt.ShowValue ~= false
                local color   = pOpt.Color    or T.Accent

                local row = New("Frame", {
                    Parent               = SecBody,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, 0, 0, 54),
                    ZIndex               = 17,
                    LayoutOrder          = Sec._order,
                })
                Sec._order += 1

                local bg = New("Frame", {
                    Parent           = row,
                    BackgroundColor3 = T.Tertiary,
                    Size             = UDim2.new(1, 0, 1, 0),
                    ZIndex           = 17,
                })
                Corner(bg, 7)
                Pad(bg, 8, 12, 8, 12)
                New("UIListLayout", {
                    Parent    = bg,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding   = UDim.new(0, 6),
                })

                local topRow = New("Frame", {
                    Parent               = bg,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, 0, 0, 15),
                    ZIndex               = 18,
                    LayoutOrder          = 1,
                })
                New("TextLabel", {
                    Parent               = topRow,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(0.65, 0, 1, 0),
                    Text                 = pOpt.Name or "Progress",
                    TextColor3           = T.Text,
                    TextSize             = 12,
                    Font                 = Enum.Font.Gotham,
                    TextXAlignment       = Enum.TextXAlignment.Left,
                    ZIndex               = 18,
                })
                local ValLbl = New("TextLabel", {
                    Parent               = topRow,
                    BackgroundTransparency = 1,
                    Position             = UDim2.new(0.65, 0, 0, 0),
                    Size                 = UDim2.new(0.35, 0, 1, 0),
                    Text                 = showVal and (tostring(val) .. suffix) or "",
                    TextColor3           = color,
                    TextSize             = 11,
                    Font                 = Enum.Font.GothamBold,
                    TextXAlignment       = Enum.TextXAlignment.Right,
                    ZIndex               = 18,
                    Visible              = showVal,
                })

                local Track = New("Frame", {
                    Parent           = bg,
                    BackgroundColor3 = T.Quaternary,
                    Size             = UDim2.new(1, 0, 0, 8),
                    ZIndex           = 18,
                    LayoutOrder      = 2,
                })
                Corner(Track, 4)

                local Fill = New("Frame", {
                    Parent           = Track,
                    BackgroundColor3 = color,
                    Size             = UDim2.new(val / 100, 0, 1, 0),
                    ZIndex           = 19,
                })
                Corner(Fill, 4)
                New("UIGradient", {
                    Parent   = Fill,
                    Color    = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
                        ColorSequenceKeypoint.new(1, Color3.new(0.75,0.75,0.75)),
                    }),
                    Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0.1),
                        NumberSequenceKeypoint.new(1, 0),
                    }),
                })

                local function Apply(v, animate)
                    val = math.clamp(v, 0, 100)
                    if animate ~= false then
                        Tween(Fill, { Size = UDim2.new(val / 100, 0, 1, 0) }, 0.25, Enum.EasingStyle.Quint)
                    else
                        Fill.Size = UDim2.new(val / 100, 0, 1, 0)
                    end
                    if showVal then
                        ValLbl.Text = tostring(math.round(val)) .. suffix
                    end
                    if pOpt.Flag then Library.Flags[pOpt.Flag] = val end
                    task.spawn(pOpt.Callback or function() end, val)
                end

                if pOpt.Flag then Library.Flags[pOpt.Flag] = val end

                return {
                    Frame  = row,
                    Set    = function(_, v, animate) Apply(v, animate) end,
                    Get    = function(_)              return val end,
                }
            end

            -- ========================================================
            --  BUTTON
            -- ========================================================
            function Sec:AddButton(bOpt)
                bOpt = bOpt or {}
                local h   = bOpt.Description and 50 or 38
                local row = BaseRow(h)
                local bg  = RowBg(row)

                RowLabel(bg, bOpt.Name or "Button", 10, bOpt.Description and 0.7 or 0.82)
                if bOpt.Description then SubLabel(bg, bOpt.Description) end

                New("TextLabel", {
                    Parent               = bg,
                    BackgroundTransparency = 1,
                    AnchorPoint          = Vector2.new(1, 0.5),
                    Position             = UDim2.new(1, -10, 0.5, 0),
                    Size                 = UDim2.new(0, 14, 0, 14),
                    Text                 = "›",
                    TextColor3           = T.Accent,
                    TextSize             = 18,
                    Font                 = Enum.Font.GothamBold,
                    ZIndex               = 18,
                })

                if bOpt.Badge then
                    local bb = New("TextLabel", {
                        Parent               = bg,
                        BackgroundColor3     = T.Accent,
                        BackgroundTransparency = 0,
                        AnchorPoint          = Vector2.new(1, 0.5),
                        Position             = UDim2.new(1, -24, 0.5, 0),
                        Size                 = UDim2.new(0, 0, 0, 14),
                        AutomaticSize        = Enum.AutomaticSize.X,
                        Text                 = " " .. bOpt.Badge .. " ",
                        TextColor3           = Color3.new(1, 1, 1),
                        TextSize             = 9,
                        Font                 = Enum.Font.GothamBold,
                        ZIndex               = 19,
                    })
                    Corner(bb, 4)
                end

                local clickBtn = New("TextButton", {
                    Parent               = bg,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, 0, 1, 0),
                    Text                 = "",
                    ZIndex               = 20,
                    AutoButtonColor      = false,
                })

                clickBtn.MouseEnter:Connect(function()
                    Tween(bg, { BackgroundColor3 = T.BorderHover }, 0.1)
                end)
                clickBtn.MouseLeave:Connect(function()
                    Tween(bg, { BackgroundColor3 = T.Tertiary }, 0.1)
                end)
                clickBtn.MouseButton1Down:Connect(function(x, y)
                    Tween(bg, { BackgroundColor3 = T.Quaternary }, 0.06)
                    Ripple(bg, x, y, T.Accent)
                end)
                clickBtn.MouseButton1Up:Connect(function()
                    Tween(bg, { BackgroundColor3 = T.BorderHover }, 0.1)
                    task.spawn(bOpt.Callback or function() end)
                end)

                if bOpt.Tooltip then Library:AttachTooltip(bg, bOpt.Tooltip) end

                return { Frame = row }
            end

            -- ========================================================
            --  TOGGLE
            -- ========================================================
            function Sec:AddToggle(tOpt)
                tOpt = tOpt or {}
                local h     = tOpt.Description and 50 or 38
                local row   = BaseRow(h)
                local bg    = RowBg(row)
                local state = tOpt.Default or false

                RowLabel(bg, tOpt.Name or "Toggle", 10, 0.6)
                if tOpt.Description then SubLabel(bg, tOpt.Description) end

                local SwBg = New("Frame", {
                    Parent           = bg,
                    BackgroundColor3 = state and T.ToggleOn or T.ToggleOff,
                    AnchorPoint      = Vector2.new(1, 0.5),
                    Position         = UDim2.new(1, -10, 0.5, 0),
                    Size             = UDim2.new(0, 38, 0, 21),
                    ZIndex           = 18,
                })
                Corner(SwBg, 11)
                Stroke(SwBg, state and T.ToggleOn or T.Border, 1)

                local SwKnob = New("Frame", {
                    Parent           = SwBg,
                    BackgroundColor3 = T.Knob,
                    AnchorPoint      = Vector2.new(0, 0.5),
                    Position         = state
                        and UDim2.new(1, -17, 0.5, 0)
                        or  UDim2.new(0,   2, 0.5, 0),
                    Size             = UDim2.new(0, 15, 0, 15),
                    ZIndex           = 19,
                })
                Corner(SwKnob, 8)
                New("UIStroke", {
                    Parent          = SwKnob,
                    Color           = Color3.fromRGB(0,0,0),
                    Thickness       = 0.5,
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                    Transparency    = 0.6,
                })

                local function Apply(v, noCallback)
                    state = v
                    Tween(SwBg, { BackgroundColor3 = v and T.ToggleOn or T.ToggleOff }, 0.18)
                    Tween(SwKnob, {
                        Position = v
                            and UDim2.new(1, -17, 0.5, 0)
                            or  UDim2.new(0,   2, 0.5, 0),
                    }, 0.18)
                    local sk = SwBg:FindFirstChildOfClass("UIStroke")
                    if sk then Tween(sk, { Color = v and T.ToggleOn or T.Border }, 0.18) end
                    if tOpt.Flag then Library.Flags[tOpt.Flag] = v end
                    if not noCallback then
                        task.spawn(tOpt.Callback or function() end, v)
                    end
                end

                if tOpt.Flag then Library.Flags[tOpt.Flag] = state end

                local clickBtn = New("TextButton", {
                    Parent               = bg,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, 0, 1, 0),
                    Text                 = "",
                    ZIndex               = 20,
                    AutoButtonColor      = false,
                })
                clickBtn.MouseButton1Click:Connect(function() Apply(not state) end)
                clickBtn.MouseEnter:Connect(function() Tween(bg, { BackgroundColor3 = T.BorderHover }, 0.1) end)
                clickBtn.MouseLeave:Connect(function() Tween(bg, { BackgroundColor3 = T.Tertiary }, 0.1) end)

                if tOpt.Tooltip then Library:AttachTooltip(bg, tOpt.Tooltip) end

                return {
                    Set = function(_, v, noCallback) Apply(v, noCallback) end,
                    Get = function(_)                return state end,
                }
            end

            -- ========================================================
            --  SLIDER
            -- ========================================================
            function Sec:AddSlider(sOpt)
                sOpt = sOpt or {}
                local min    = sOpt.Min       or 0
                local max    = sOpt.Max       or 100
                local inc    = sOpt.Increment or 1
                local suffix = sOpt.Suffix    or ""
                local val    = math.clamp(sOpt.Default or min, min, max)

                local row = BaseRow(58)
                local bg  = New("Frame", {
                    Parent           = row,
                    BackgroundColor3 = T.Tertiary,
                    Size             = UDim2.new(1, 0, 1, 0),
                    ZIndex           = 17,
                })
                Corner(bg, 7)
                Pad(bg, 8, 12, 8, 12)
                New("UIListLayout", {
                    Parent    = bg,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding   = UDim.new(0, 6),
                })

                local topRow = New("Frame", {
                    Parent               = bg,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, 0, 0, 15),
                    ZIndex               = 18,
                    LayoutOrder          = 1,
                })
                New("TextLabel", {
                    Parent               = topRow,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(0.65, 0, 1, 0),
                    Text                 = sOpt.Name or "Slider",
                    TextColor3           = T.Text,
                    TextSize             = 12,
                    Font                 = Enum.Font.Gotham,
                    TextXAlignment       = Enum.TextXAlignment.Left,
                    ZIndex               = 18,
                })
                local ValLbl = New("TextLabel", {
                    Parent               = topRow,
                    BackgroundTransparency = 1,
                    Position             = UDim2.new(0.65, 0, 0, 0),
                    Size                 = UDim2.new(0.35, 0, 1, 0),
                    Text                 = tostring(val) .. suffix,
                    TextColor3           = T.Accent,
                    TextSize             = 11,
                    Font                 = Enum.Font.GothamBold,
                    TextXAlignment       = Enum.TextXAlignment.Right,
                    ZIndex               = 18,
                })

                local Track = New("Frame", {
                    Parent           = bg,
                    BackgroundColor3 = T.Quaternary,
                    Size             = UDim2.new(1, 0, 0, 4),
                    ZIndex           = 18,
                    LayoutOrder      = 2,
                })
                Corner(Track, 2)

                local Fill = New("Frame", {
                    Parent           = Track,
                    BackgroundColor3 = T.Accent,
                    Size             = UDim2.new((val - min) / (max - min), 0, 1, 0),
                    ZIndex           = 19,
                })
                Corner(Fill, 2)

                local Knob = New("Frame", {
                    Parent           = Track,
                    BackgroundColor3 = T.Accent,
                    AnchorPoint      = Vector2.new(0.5, 0.5),
                    Position         = UDim2.new((val - min) / (max - min), 0, 0.5, 0),
                    Size             = UDim2.new(0, 14, 0, 14),
                    ZIndex           = 20,
                })
                Corner(Knob, 7)
                New("UIStroke", { Parent = Knob, Color = T.Accent, Thickness = 1, Transparency = 0.5 })

                local function ApplySlider(raw)
                    val = SnapValue(raw, min, max, inc)
                    local a = (val - min) / (max - min)
                    Tween(Fill,  { Size     = UDim2.new(a, 0, 1, 0)   }, 0.05)
                    Tween(Knob,  { Position = UDim2.new(a, 0, 0.5, 0) }, 0.05)
                    ValLbl.Text = tostring(val) .. suffix
                    if sOpt.Flag then Library.Flags[sOpt.Flag] = val end
                    task.spawn(sOpt.Callback or function() end, val)
                end

                if sOpt.Flag then Library.Flags[sOpt.Flag] = val end

                local sliding = false

                local HitBox = New("TextButton", {
                    Parent               = Track,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, 0, 1, 22),
                    Position             = UDim2.new(0, 0, 0, -11),
                    Text                 = "",
                    ZIndex               = 21,
                    AutoButtonColor      = false,
                })

                local function GetAlpha(sx)
                    local ax = Track.AbsolutePosition.X
                    local aw = Track.AbsoluteSize.X
                    return math.clamp((sx - ax) / aw, 0, 1)
                end

                HitBox.InputBegan:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1
                    or inp.UserInputType == Enum.UserInputType.Touch then
                        sliding = true
                        ApplySlider(min + (max - min) * GetAlpha(inp.Position.X))
                    end
                end)
                HitBox.InputEnded:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1
                    or inp.UserInputType == Enum.UserInputType.Touch then
                        sliding = false
                    end
                end)
                UserInputService.InputChanged:Connect(function(inp)
                    if sliding and (
                        inp.UserInputType == Enum.UserInputType.MouseMovement or
                        inp.UserInputType == Enum.UserInputType.Touch
                    ) then
                        ApplySlider(min + (max - min) * GetAlpha(inp.Position.X))
                    end
                end)
                UserInputService.InputEnded:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                        sliding = false
                    end
                end)

                if sOpt.Tooltip then Library:AttachTooltip(bg, sOpt.Tooltip) end

                return {
                    Set = function(_, v) ApplySlider(v) end,
                    Get = function(_)    return val end,
                }
            end

            -- ========================================================
            --  DROPDOWN (single select)
            -- ========================================================
            function Sec:AddDropdown(dOpt)
                dOpt = dOpt or {}
                local items  = dOpt.Items   or {}
                local sel    = dOpt.Default or nil
                local isOpen = false

                local row = BaseRow(38)
                local bg  = New("Frame", {
                    Parent           = row,
                    BackgroundColor3 = T.Tertiary,
                    Size             = UDim2.new(1, 0, 1, 0),
                    ZIndex           = 17,
                    ClipsDescendants = false,
                })
                Corner(bg, 7)

                RowLabel(bg, dOpt.Name or "Dropdown", 10, 0.45)

                local SelLbl = New("TextLabel", {
                    Parent               = bg,
                    BackgroundTransparency = 1,
                    Position             = UDim2.new(0.45, 0, 0, 0),
                    Size                 = UDim2.new(0.42, 0, 1, 0),
                    Text                 = sel or "Select...",
                    TextColor3           = T.TextSub,
                    TextSize             = 11,
                    Font                 = Enum.Font.Gotham,
                    TextXAlignment       = Enum.TextXAlignment.Right,
                    ZIndex               = 18,
                    TextTruncate         = Enum.TextTruncate.AtEnd,
                })

                local ArrowLbl = New("TextLabel", {
                    Parent               = bg,
                    BackgroundTransparency = 1,
                    AnchorPoint          = Vector2.new(1, 0.5),
                    Position             = UDim2.new(1, -10, 0.5, 0),
                    Size                 = UDim2.new(0, 12, 0, 12),
                    Text                 = "⌄",
                    TextColor3           = T.TextSub,
                    TextSize             = 13,
                    Font                 = Enum.Font.GothamBold,
                    ZIndex               = 18,
                })

                local Menu = New("Frame", {
                    Parent           = bg,
                    BackgroundColor3 = T.Secondary,
                    Position         = UDim2.new(0, 0, 1, 5),
                    Size             = UDim2.new(1, 0, 0, 0),
                    ZIndex           = 55,
                    Visible          = false,
                    ClipsDescendants = true,
                })
                Corner(Menu, 7)
                Stroke(Menu, T.Border, 1)

                local MInner = New("Frame", {
                    Parent               = Menu,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, 0, 0, 0),
                    AutomaticSize        = Enum.AutomaticSize.Y,
                    ZIndex               = 56,
                })
                New("UIListLayout", {
                    Parent    = MInner,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding   = UDim.new(0, 2),
                })
                Pad(MInner, 4, 4, 4, 4)

                local function BuildItems()
                    for _, c in ipairs(MInner:GetChildren()) do
                        if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
                    end
                    for _, name in ipairs(items) do
                        local isCur = (name == sel)
                        local btn = New("TextButton", {
                            Parent               = MInner,
                            BackgroundColor3     = isCur and T.Accent or T.Tertiary,
                            BackgroundTransparency = isCur and 0 or 1,
                            Size                 = UDim2.new(1, 0, 0, 28),
                            Text                 = name,
                            TextColor3           = isCur and Color3.new(1,1,1) or T.TextSub,
                            TextSize             = 11,
                            Font                 = isCur and Enum.Font.GothamBold or Enum.Font.Gotham,
                            ZIndex               = 57,
                            AutoButtonColor      = false,
                        })
                        Corner(btn, 5)
                        btn.MouseEnter:Connect(function()
                            if name ~= sel then
                                btn.BackgroundTransparency = 0
                                btn.TextColor3 = T.Text
                            end
                        end)
                        btn.MouseLeave:Connect(function()
                            if name ~= sel then
                                btn.BackgroundTransparency = 1
                                btn.TextColor3 = T.TextSub
                            end
                        end)
                        btn.MouseButton1Click:Connect(function()
                            sel = name
                            SelLbl.Text = name
                            SelLbl.TextColor3 = T.Text
                            if dOpt.Flag then Library.Flags[dOpt.Flag] = name end
                            task.spawn(dOpt.Callback or function() end, name)
                            isOpen = false
                            Tween(Menu, { Size = UDim2.new(1, 0, 0, 0) }, 0.15)
                            ArrowLbl.Text = "⌄"
                            task.delay(0.16, function() if Menu.Parent then Menu.Visible = false end end)
                            BuildItems()
                        end)
                    end
                end
                BuildItems()

                local function Toggle()
                    isOpen = not isOpen
                    if isOpen then
                        Menu.Visible = true
                        local h = math.min(#items * 32 + 8, 168)
                        Tween(Menu, { Size = UDim2.new(1, 0, 0, h) }, 0.18)
                        ArrowLbl.Text = "⌃"
                    else
                        Tween(Menu, { Size = UDim2.new(1, 0, 0, 0) }, 0.15)
                        ArrowLbl.Text = "⌄"
                        task.delay(0.16, function() if Menu.Parent then Menu.Visible = false end end)
                    end
                end

                local clickBtn = New("TextButton", {
                    Parent               = bg,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, 0, 1, 0),
                    Text                 = "",
                    ZIndex               = 20,
                    AutoButtonColor      = false,
                })
                clickBtn.MouseButton1Click:Connect(Toggle)
                clickBtn.MouseEnter:Connect(function() Tween(bg, { BackgroundColor3 = T.BorderHover }, 0.1) end)
                clickBtn.MouseLeave:Connect(function() Tween(bg, { BackgroundColor3 = T.Tertiary }, 0.1) end)

                if dOpt.Flag then Library.Flags[dOpt.Flag] = sel end

                return {
                    Set     = function(_, v)
                        sel = v
                        SelLbl.Text = v
                        SelLbl.TextColor3 = T.Text
                        if dOpt.Flag then Library.Flags[dOpt.Flag] = v end
                        task.spawn(dOpt.Callback or function() end, v)
                        BuildItems()
                    end,
                    Get     = function(_)    return sel end,
                    Refresh = function(_, t)
                        items = t
                        BuildItems()
                    end,
                }
            end

            -- ========================================================
            --  MULTI-SELECT DROPDOWN
            -- ========================================================
            function Sec:AddMultiDropdown(dOpt)
                dOpt = dOpt or {}
                local items    = dOpt.Items    or {}
                local selected = {}
                if dOpt.Defaults then
                    for _, v in ipairs(dOpt.Defaults) do selected[v] = true end
                end
                local isOpen = false

                local row = BaseRow(38)
                local bg  = New("Frame", {
                    Parent           = row,
                    BackgroundColor3 = T.Tertiary,
                    Size             = UDim2.new(1, 0, 1, 0),
                    ZIndex           = 17,
                    ClipsDescendants = false,
                })
                Corner(bg, 7)

                RowLabel(bg, dOpt.Name or "MultiSelect", 10, 0.4)

                local CountLbl = New("TextLabel", {
                    Parent               = bg,
                    BackgroundTransparency = 1,
                    Position             = UDim2.new(0.4, 0, 0, 0),
                    Size                 = UDim2.new(0.48, 0, 1, 0),
                    Text                 = "0 selected",
                    TextColor3           = T.TextSub,
                    TextSize             = 11,
                    Font                 = Enum.Font.Gotham,
                    TextXAlignment       = Enum.TextXAlignment.Right,
                    ZIndex               = 18,
                })

                local ArrowLbl = New("TextLabel", {
                    Parent               = bg,
                    BackgroundTransparency = 1,
                    AnchorPoint          = Vector2.new(1, 0.5),
                    Position             = UDim2.new(1, -10, 0.5, 0),
                    Size                 = UDim2.new(0, 12, 0, 12),
                    Text                 = "⌄",
                    TextColor3           = T.TextSub,
                    TextSize             = 13,
                    Font                 = Enum.Font.GothamBold,
                    ZIndex               = 18,
                })

                local Menu = New("Frame", {
                    Parent           = bg,
                    BackgroundColor3 = T.Secondary,
                    Position         = UDim2.new(0, 0, 1, 5),
                    Size             = UDim2.new(1, 0, 0, 0),
                    ZIndex           = 55,
                    Visible          = false,
                    ClipsDescendants = true,
                })
                Corner(Menu, 7)
                Stroke(Menu, T.Border, 1)

                local MInner = New("Frame", {
                    Parent               = Menu,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, 0, 0, 0),
                    AutomaticSize        = Enum.AutomaticSize.Y,
                    ZIndex               = 56,
                })
                New("UIListLayout", {
                    Parent    = MInner,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding   = UDim.new(0, 2),
                })
                Pad(MInner, 4, 4, 4, 4)

                local function UpdateCount()
                    local n = 0
                    for _ in pairs(selected) do n += 1 end
                    CountLbl.Text = n == 0 and "None" or tostring(n) .. " selected"
                    CountLbl.TextColor3 = n > 0 and T.Text or T.TextSub
                    if dOpt.Flag then
                        local arr = {}
                        for k in pairs(selected) do table.insert(arr, k) end
                        Library.Flags[dOpt.Flag] = arr
                    end
                    task.spawn(dOpt.Callback or function() end, selected)
                end

                local function BuildItems()
                    for _, c in ipairs(MInner:GetChildren()) do
                        if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
                    end
                    for _, name in ipairs(items) do
                        local checked = selected[name] == true

                        local itemRow = New("TextButton", {
                            Parent               = MInner,
                            BackgroundColor3     = T.Tertiary,
                            BackgroundTransparency = checked and 0 or 1,
                            Size                 = UDim2.new(1, 0, 0, 28),
                            Text                 = "",
                            ZIndex               = 57,
                            AutoButtonColor      = false,
                        })
                        Corner(itemRow, 5)

                        local CheckBox = New("Frame", {
                            Parent           = itemRow,
                            BackgroundColor3 = checked and T.Accent or T.Background,
                            AnchorPoint      = Vector2.new(0, 0.5),
                            Position         = UDim2.new(0, 8, 0.5, 0),
                            Size             = UDim2.new(0, 14, 0, 14),
                            ZIndex           = 58,
                        })
                        Corner(CheckBox, 3)
                        Stroke(CheckBox, checked and T.Accent or T.Border, 1)

                        local CheckMark = New("TextLabel", {
                            Parent               = CheckBox,
                            BackgroundTransparency = 1,
                            Size                 = UDim2.new(1, 0, 1, 0),
                            Text                 = checked and "✔" or "",
                            TextColor3           = Color3.new(1, 1, 1),
                            TextSize             = 9,
                            Font                 = Enum.Font.GothamBold,
                            ZIndex               = 59,
                        })

                        New("TextLabel", {
                            Parent               = itemRow,
                            BackgroundTransparency = 1,
                            Position             = UDim2.new(0, 30, 0, 0),
                            Size                 = UDim2.new(1, -30, 1, 0),
                            Text                 = name,
                            TextColor3           = checked and T.Text or T.TextSub,
                            TextSize             = 11,
                            Font                 = checked and Enum.Font.GothamBold or Enum.Font.Gotham,
                            TextXAlignment       = Enum.TextXAlignment.Left,
                            ZIndex               = 58,
                        })

                        itemRow.MouseButton1Click:Connect(function()
                            if selected[name] then
                                selected[name] = nil
                            else
                                selected[name] = true
                            end
                            BuildItems()
                            UpdateCount()
                        end)
                        itemRow.MouseEnter:Connect(function()
                            itemRow.BackgroundTransparency = 0
                        end)
                        itemRow.MouseLeave:Connect(function()
                            itemRow.BackgroundTransparency = selected[name] and 0 or 1
                        end)
                    end
                end
                BuildItems()
                UpdateCount()

                local function Toggle()
                    isOpen = not isOpen
                    if isOpen then
                        Menu.Visible = true
                        local h = math.min(#items * 32 + 8, 168)
                        Tween(Menu, { Size = UDim2.new(1, 0, 0, h) }, 0.18)
                        ArrowLbl.Text = "⌃"
                    else
                        Tween(Menu, { Size = UDim2.new(1, 0, 0, 0) }, 0.15)
                        ArrowLbl.Text = "⌄"
                        task.delay(0.16, function() if Menu.Parent then Menu.Visible = false end end)
                    end
                end

                local clickBtn = New("TextButton", {
                    Parent               = bg,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, 0, 1, 0),
                    Text                 = "",
                    ZIndex               = 20,
                    AutoButtonColor      = false,
                })
                clickBtn.MouseButton1Click:Connect(Toggle)
                clickBtn.MouseEnter:Connect(function() Tween(bg, { BackgroundColor3 = T.BorderHover }, 0.1) end)
                clickBtn.MouseLeave:Connect(function() Tween(bg, { BackgroundColor3 = T.Tertiary }, 0.1) end)

                return {
                    GetSelected = function(_) return selected end,
                    SetSelected = function(_, tbl)
                        selected = {}
                        for _, v in ipairs(tbl) do selected[v] = true end
                        BuildItems()
                        UpdateCount()
                    end,
                    Refresh = function(_, t)
                        items = t
                        BuildItems()
                    end,
                }
            end

            -- ========================================================
            --  RADIO GROUP
            -- ========================================================
            function Sec:AddRadioGroup(rOpt)
                rOpt = rOpt or {}
                local options  = rOpt.Options  or {}
                local selected = rOpt.Default  or (options[1] or nil)

                local h   = #options * 34 + 10
                local row = BaseRow(h, false)
                local bg  = RowBg(row)
                Pad(bg, 8, 12, 8, 12)
                New("UIListLayout", {
                    Parent    = bg,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding   = UDim.new(0, 4),
                })

                New("TextLabel", {
                    Parent               = bg,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, 0, 0, 14),
                    Text                 = rOpt.Name or "Radio",
                    TextColor3           = T.Text,
                    TextSize             = 12,
                    Font                 = Enum.Font.Gotham,
                    TextXAlignment       = Enum.TextXAlignment.Left,
                    ZIndex               = 18,
                    LayoutOrder          = 0,
                })

                local dotRefs = {}

                local function SelectOption(opt)
                    selected = opt
                    for optName, dots in pairs(dotRefs) do
                        local isThis = (optName == opt)
                        Tween(dots.outer, { BackgroundColor3 = isThis and T.Accent or T.Background }, 0.15)
                        Tween(dots.inner, { BackgroundTransparency = isThis and 0 or 1 }, 0.15)
                        dots.lbl.TextColor3 = isThis and T.Text or T.TextSub
                        dots.lbl.Font       = isThis and Enum.Font.GothamBold or Enum.Font.Gotham
                    end
                    if rOpt.Flag then Library.Flags[rOpt.Flag] = opt end
                    task.spawn(rOpt.Callback or function() end, opt)
                end

                for idx, optName in ipairs(options) do
                    local isThis = (optName == selected)
                    local optRow = New("TextButton", {
                        Parent               = bg,
                        BackgroundTransparency = 1,
                        Size                 = UDim2.new(1, 0, 0, 28),
                        Text                 = "",
                        ZIndex               = 18,
                        AutoButtonColor      = false,
                        LayoutOrder          = idx,
                    })

                    local outerDot = New("Frame", {
                        Parent           = optRow,
                        BackgroundColor3 = isThis and T.Accent or T.Background,
                        AnchorPoint      = Vector2.new(0, 0.5),
                        Position         = UDim2.new(0, 0, 0.5, 0),
                        Size             = UDim2.new(0, 16, 0, 16),
                        ZIndex           = 19,
                    })
                    Corner(outerDot, 8)
                    Stroke(outerDot, isThis and T.Accent or T.Border, 1)

                    local innerDot = New("Frame", {
                        Parent               = outerDot,
                        BackgroundColor3     = Color3.new(1, 1, 1),
                        BackgroundTransparency = isThis and 0 or 1,
                        AnchorPoint          = Vector2.new(0.5, 0.5),
                        Position             = UDim2.new(0.5, 0, 0.5, 0),
                        Size                 = UDim2.new(0, 7, 0, 7),
                        ZIndex               = 20,
                    })
                    Corner(innerDot, 5)

                    local optLbl = New("TextLabel", {
                        Parent               = optRow,
                        BackgroundTransparency = 1,
                        Position             = UDim2.new(0, 24, 0, 0),
                        Size                 = UDim2.new(1, -24, 1, 0),
                        Text                 = optName,
                        TextColor3           = isThis and T.Text or T.TextSub,
                        TextSize             = 11,
                        Font                 = isThis and Enum.Font.GothamBold or Enum.Font.Gotham,
                        TextXAlignment       = Enum.TextXAlignment.Left,
                        ZIndex               = 19,
                    })

                    dotRefs[optName] = { outer = outerDot, inner = innerDot, lbl = optLbl }

                    optRow.MouseButton1Click:Connect(function()
                        SelectOption(optName)
                    end)
                    optRow.MouseEnter:Connect(function()
                        optLbl.TextColor3 = T.Text
                    end)
                    optRow.MouseLeave:Connect(function()
                        if selected ~= optName then
                            optLbl.TextColor3 = T.TextSub
                        end
                    end)
                end

                if rOpt.Flag then Library.Flags[rOpt.Flag] = selected end

                return {
                    Set = function(_, v) SelectOption(v) end,
                    Get = function(_)    return selected end,
                }
            end

            -- ========================================================
            --  TEXTBOX
            -- ========================================================
            function Sec:AddTextBox(xOpt)
                xOpt = xOpt or {}
                local row = BaseRow(38)
                local bg  = RowBg(row)

                RowLabel(bg, xOpt.Name or "TextBox", 10, 0.42)

                local InBg = New("Frame", {
                    Parent           = bg,
                    BackgroundColor3 = T.Tertiary,
                    AnchorPoint      = Vector2.new(1, 0.5),
                    Position         = UDim2.new(1, -10, 0.5, 0),
                    Size             = UDim2.new(0.55, 0, 0, 24),
                    ZIndex           = 18,
                })
                Corner(InBg, 7)
                local inStroke = Stroke(InBg, T.Border, 1)

                local Input = New("TextBox", {
                    Parent               = InBg,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, 0, 1, 0),
                    Text                 = xOpt.Default or "",
                    PlaceholderText      = xOpt.Placeholder or "Type...",
                    TextColor3           = T.Text,
                    PlaceholderColor3    = T.TextDim,
                    TextSize             = 11,
                    Font                 = Enum.Font.Code,
                    ClearTextOnFocus     = xOpt.ClearOnFocus ~= false,
                    ZIndex               = 19,
                })
                Pad(Input, 0, 7, 0, 7)

                Input.Focused:Connect(function()
                    Tween(InBg, { BackgroundColor3 = T.Quaternary }, 0.1)
                    Tween(inStroke, { Color = T.Accent }, 0.1)
                end)
                Input.FocusLost:Connect(function(enter)
                    Tween(InBg, { BackgroundColor3 = T.Tertiary }, 0.1)
                    Tween(inStroke, { Color = T.Border }, 0.1)
                    if xOpt.Flag then Library.Flags[xOpt.Flag] = Input.Text end
                    task.spawn(xOpt.Callback or function() end, Input.Text, enter)
                end)

                if xOpt.Flag then Library.Flags[xOpt.Flag] = xOpt.Default or "" end

                return {
                    Set = function(_, v)
                        Input.Text = v
                        if xOpt.Flag then Library.Flags[xOpt.Flag] = v end
                    end,
                    Get = function(_) return Input.Text end,
                }
            end

            -- ========================================================
            --  NUMBER INPUT
            -- ========================================================
            function Sec:AddNumberInput(nOpt)
                nOpt = nOpt or {}
                local minV = nOpt.Min or -math.huge
                local maxV = nOpt.Max or  math.huge
                local val  = nOpt.Default or 0

                local row = BaseRow(38)
                local bg  = RowBg(row)

                RowLabel(bg, nOpt.Name or "Number", 10, 0.5)

                local CtrlRow = New("Frame", {
                    Parent               = bg,
                    BackgroundTransparency = 1,
                    AnchorPoint          = Vector2.new(1, 0.5),
                    Position             = UDim2.new(1, -10, 0.5, 0),
                    Size                 = UDim2.new(0, 110, 0, 26),
                    ZIndex               = 18,
                })
                New("UIListLayout", {
                    Parent            = CtrlRow,
                    FillDirection     = Enum.FillDirection.Horizontal,
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                    Padding           = UDim.new(0, 2),
                })

                local function MakeNumBtn(txt)
                    local b = New("TextButton", {
                        Parent           = CtrlRow,
                        BackgroundColor3 = T.Quaternary,
                        Size             = UDim2.new(0, 26, 0, 26),
                        Text             = txt,
                        TextColor3       = T.Text,
                        TextSize         = 14,
                        Font             = Enum.Font.GothamBold,
                        ZIndex           = 19,
                        AutoButtonColor  = false,
                    })
                    Corner(b, 6)
                    b.MouseEnter:Connect(function()
                        Tween(b, { BackgroundColor3 = T.Accent }, 0.1)
                    end)
                    b.MouseLeave:Connect(function()
                        Tween(b, { BackgroundColor3 = T.Quaternary }, 0.1)
                    end)
                    return b
                end

                local DecBtn = MakeNumBtn("−")
                local InBg   = New("Frame", {
                    Parent           = CtrlRow,
                    BackgroundColor3 = T.Background,
                    Size             = UDim2.new(0, 56, 0, 26),
                    ZIndex           = 19,
                })
                Corner(InBg, 6)
                Stroke(InBg, T.Border, 1)

                local ValInput = New("TextBox", {
                    Parent               = InBg,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, 0, 1, 0),
                    Text                 = tostring(val),
                    TextColor3           = T.Accent,
                    TextSize             = 12,
                    Font                 = Enum.Font.GothamBold,
                    ZIndex               = 20,
                    ClearTextOnFocus     = false,
                })

                local IncBtn = MakeNumBtn("+")

                local function Apply(v)
                    v = math.clamp(v, minV, maxV)
                    val = v
                    ValInput.Text = tostring(v)
                    if nOpt.Flag then Library.Flags[nOpt.Flag] = v end
                    task.spawn(nOpt.Callback or function() end, v)
                end

                DecBtn.MouseButton1Click:Connect(function()
                    Apply(val - (nOpt.Step or 1))
                end)
                IncBtn.MouseButton1Click:Connect(function()
                    Apply(val + (nOpt.Step or 1))
                end)
                ValInput.FocusLost:Connect(function()
                    Apply(tonumber(ValInput.Text) or val)
                end)

                if nOpt.Flag then Library.Flags[nOpt.Flag] = val end

                return {
                    Set = function(_, v) Apply(v) end,
                    Get = function(_)    return val end,
                }
            end

            -- ========================================================
            --  KEYBIND
            -- ========================================================
            function Sec:AddKeybind(kOpt)
                kOpt = kOpt or {}
                local row       = BaseRow(38)
                local bg        = RowBg(row)
                local boundKey  = kOpt.Default or Enum.KeyCode.Unknown
                local listening = false

                RowLabel(bg, kOpt.Name or "Keybind", 10, 0.55)

                local KeyBg = New("Frame", {
                    Parent           = bg,
                    BackgroundColor3 = T.Tertiary,
                    AnchorPoint      = Vector2.new(1, 0.5),
                    Position         = UDim2.new(1, -10, 0.5, 0),
                    Size             = UDim2.new(0, 82, 0, 24),
                    ZIndex           = 18,
                })
                Corner(KeyBg, 5)
                Stroke(KeyBg, T.Border, 1)

                local KeyLbl = New("TextButton", {
                    Parent               = KeyBg,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, 0, 1, 0),
                    Text                 = boundKey.Name,
                    TextColor3           = T.Accent,
                    TextSize             = 11,
                    Font                 = Enum.Font.GothamBold,
                    ZIndex               = 19,
                    AutoButtonColor      = false,
                })

                KeyLbl.MouseButton1Click:Connect(function()
                    if listening then return end
                    listening = true
                    KeyLbl.Text       = "…"
                    KeyLbl.TextColor3 = T.Warning

                    local c
                    c = UserInputService.InputBegan:Connect(function(inp, gpe)
                        if gpe then return end
                        if inp.UserInputType == Enum.UserInputType.Keyboard then
                            boundKey           = inp.KeyCode
                            KeyLbl.Text        = boundKey.Name
                            KeyLbl.TextColor3  = T.Accent
                            listening          = false
                            if kOpt.Flag then Library.Flags[kOpt.Flag] = boundKey end
                            c:Disconnect()
                        end
                    end)
                end)

                UserInputService.InputBegan:Connect(function(inp, gpe)
                    if gpe or listening then return end
                    if inp.KeyCode == boundKey then
                        task.spawn(kOpt.Callback or function() end, boundKey)
                    end
                end)

                bg.MouseEnter:Connect(function() Tween(bg, { BackgroundColor3 = T.BorderHover }, 0.1) end)
                bg.MouseLeave:Connect(function() Tween(bg, { BackgroundColor3 = T.Tertiary }, 0.1) end)

                if kOpt.Flag then Library.Flags[kOpt.Flag] = boundKey end

                return {
                    Set = function(_, key)
                        boundKey    = key
                        KeyLbl.Text = key.Name
                        if kOpt.Flag then Library.Flags[kOpt.Flag] = key end
                    end,
                    Get = function(_) return boundKey end,
                }
            end

            -- ========================================================
            --  LABEL
            -- ========================================================
            function Sec:AddLabel(lOpt)
                local text = type(lOpt) == "string" and lOpt or (lOpt and lOpt.Text or "Label")
                local row  = BaseRow(28)

                local lbl = New("TextLabel", {
                    Parent               = row,
                    BackgroundTransparency = 1,
                    Position             = UDim2.new(0, 10, 0, 0),
                    Size                 = UDim2.new(1, -10, 1, 0),
                    Text                 = text,
                    TextColor3           = T.TextSub,
                    TextSize             = 12,
                    Font                 = Enum.Font.Gotham,
                    TextXAlignment       = Enum.TextXAlignment.Left,
                    TextWrapped          = true,
                    RichText             = true,
                    ZIndex               = 17,
                })

                return {
                    Set = function(_, v) lbl.Text = v end,
                    Get = function(_)   return lbl.Text end,
                }
            end

            -- ========================================================
            --  ALERT BOX
            -- ========================================================
            function Sec:AddAlert(aOpt)
                aOpt = aOpt or {}
                local text    = aOpt.Text or ""
                local atype   = aOpt.Type or "Info"
                local colorMap = {
                    Info    = T.Info,
                    Warning = T.Warning,
                    Error   = T.Error,
                    Tip     = T.Warning,
                    Success = T.Success,
                }
                local accent = colorMap[atype] or T.Info

                local row = BaseRow(0, true)
                local bg  = New("Frame", {
                    Parent           = row,
                    BackgroundColor3 = accent:Lerp(T.Background, 0.88),
                    Size             = UDim2.new(1, 0, 0, 0),
                    AutomaticSize    = Enum.AutomaticSize.Y,
                    ZIndex           = 17,
                })
                Corner(bg, 7)

                New("Frame", {
                    Parent           = bg,
                    BackgroundColor3 = accent,
                    Size             = UDim2.new(0, 3, 1, 0),
                    ZIndex           = 18,
                })

                local lbl = New("TextLabel", {
                    Parent               = bg,
                    BackgroundTransparency = 1,
                    Position             = UDim2.new(0, 12, 0, 0),
                    Size                 = UDim2.new(1, -16, 0, 0),
                    AutomaticSize        = Enum.AutomaticSize.Y,
                    Text                 = text,
                    TextColor3           = accent:Lerp(Color3.new(1,1,1), 0.15),
                    TextSize             = 12,
                    Font                 = Enum.Font.Gotham,
                    TextXAlignment       = Enum.TextXAlignment.Left,
                    TextWrapped          = true,
                    RichText             = true,
                    ZIndex               = 18,
                })
                Pad(lbl, 8, 4, 8, 0)

                return {
                    Set = function(_, v) lbl.Text = v end,
                }
            end

            -- ========================================================
            --  STAT ROW
            -- ========================================================
            function Sec:AddStat(sOpt)
                sOpt = sOpt or {}
                local row = BaseRow(32)

                New("TextLabel", {
                    Parent               = row,
                    BackgroundTransparency = 1,
                    Position             = UDim2.new(0, 10, 0, 0),
                    Size                 = UDim2.new(0.55, 0, 1, 0),
                    Text                 = sOpt.Name or "Stat",
                    TextColor3           = T.TextSub,
                    TextSize             = 12,
                    Font                 = Enum.Font.Gotham,
                    TextXAlignment       = Enum.TextXAlignment.Left,
                    ZIndex               = 17,
                })

                local valLbl = New("TextLabel", {
                    Parent               = row,
                    BackgroundTransparency = 1,
                    Position             = UDim2.new(0.55, 0, 0, 0),
                    Size                 = UDim2.new(0.42, 0, 1, 0),
                    Text                 = tostring(sOpt.Value or "—"),
                    TextColor3           = sOpt.Color or T.Accent,
                    TextSize             = 12,
                    Font                 = Enum.Font.GothamBold,
                    TextXAlignment       = Enum.TextXAlignment.Right,
                    ZIndex               = 17,
                })

                return {
                    Set = function(_, v) valLbl.Text = tostring(v) end,
                    Get = function(_)    return valLbl.Text end,
                }
            end

            -- ========================================================
            --  STAT GRID
            -- ========================================================
            function Sec:AddStatGrid(items)
                items = items or {}
                local rows   = math.ceil(#items / 2)
                local h      = rows * 60 + (rows - 1) * 8
                local row    = BaseRow(h, false)

                local grid = New("Frame", {
                    Parent               = row,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, 0, 1, 0),
                    ZIndex               = 17,
                })
                New("UIGridLayout", {
                    Parent        = grid,
                    CellSize      = UDim2.new(0.5, -4, 0, 60),
                    CellPadding   = UDim2.new(0, 8, 0, 8),
                    FillDirection = Enum.FillDirection.Horizontal,
                    SortOrder     = Enum.SortOrder.LayoutOrder,
                })

                local refs = {}
                for i, item in ipairs(items) do
                    local box = New("Frame", {
                        Parent           = grid,
                        BackgroundColor3 = T.Tertiary,
                        ZIndex           = 17,
                        LayoutOrder      = i,
                    })
                    Corner(box, 7)
                    Stroke(box, T.Border, 1)
                    Pad(box, 9, 11, 9, 11)
                    New("UIListLayout", {
                        Parent    = box,
                        SortOrder = Enum.SortOrder.LayoutOrder,
                        Padding   = UDim.new(0, 2),
                    })

                    local numLbl = New("TextLabel", {
                        Parent               = box,
                        BackgroundTransparency = 1,
                        Size                 = UDim2.new(1, 0, 0, 22),
                        Text                 = tostring(item.Value or "—"),
                        TextColor3           = T.Accent,
                        TextSize             = 18,
                        Font                 = Enum.Font.GothamBold,
                        TextXAlignment       = Enum.TextXAlignment.Left,
                        ZIndex               = 18,
                        LayoutOrder          = 1,
                    })
                    New("TextLabel", {
                        Parent               = box,
                        BackgroundTransparency = 1,
                        Size                 = UDim2.new(1, 0, 0, 12),
                        Text                 = (item.Name or ""):upper(),
                        TextColor3           = T.TextSub,
                        TextSize             = 10,
                        Font                 = Enum.Font.Gotham,
                        TextXAlignment       = Enum.TextXAlignment.Left,
                        ZIndex               = 18,
                        LayoutOrder          = 2,
                    })

                    refs[i] = { numLbl = numLbl, item = item }
                end

                return {
                    Set = function(_, idx, v)
                        if refs[idx] then
                            refs[idx].numLbl.Text = tostring(v)
                        end
                    end,
                }
            end

            -- ========================================================
            --  BADGE / STATUS CHIP
            -- ========================================================
            function Sec:AddChip(cOpt)
                cOpt = cOpt or {}
                local row = BaseRow(30)

                New("TextLabel", {
                    Parent               = row,
                    BackgroundTransparency = 1,
                    Position             = UDim2.new(0, 10, 0, 0),
                    Size                 = UDim2.new(0.55, 0, 1, 0),
                    Text                 = cOpt.Name or "Status",
                    TextColor3           = T.TextSub,
                    TextSize             = 12,
                    Font                 = Enum.Font.Gotham,
                    TextXAlignment       = Enum.TextXAlignment.Left,
                    ZIndex               = 17,
                })

                local ChipBg = New("Frame", {
                    Parent           = row,
                    BackgroundColor3 = (cOpt.Color or T.Accent):Lerp(Color3.new(0,0,0), 0.82),
                    AnchorPoint      = Vector2.new(1, 0.5),
                    Position         = UDim2.new(1, -10, 0.5, 0),
                    Size             = UDim2.new(0, 0, 0, 18),
                    AutomaticSize    = Enum.AutomaticSize.X,
                    ZIndex           = 17,
                })
                Corner(ChipBg, 5)
                Stroke(ChipBg, cOpt.Color or T.Accent, 1)

                local ChipLbl = New("TextLabel", {
                    Parent               = ChipBg,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(0, 0, 1, 0),
                    AutomaticSize        = Enum.AutomaticSize.X,
                    Text                 = " " .. (cOpt.Value or "OK") .. " ",
                    TextColor3           = cOpt.Color or T.Accent,
                    TextSize             = 10,
                    Font                 = Enum.Font.GothamBold,
                    ZIndex               = 18,
                })

                return {
                    Set = function(_, v, col)
                        ChipLbl.Text = " " .. tostring(v) .. " "
                        if col then
                            ChipBg.BackgroundColor3 = col:Lerp(Color3.new(0,0,0), 0.82)
                            ChipLbl.TextColor3 = col
                            local sk = ChipBg:FindFirstChildOfClass("UIStroke")
                            if sk then sk.Color = col end
                        end
                    end,
                    Get = function(_) return ChipLbl.Text:match("^%s*(.-)%s*$") end,
                }
            end

            -- ========================================================
            --  LINK LABEL
            -- ========================================================
            function Sec:AddLink(lOpt)
                lOpt = lOpt or {}
                local row = BaseRow(32)

                New("TextLabel", {
                    Parent               = row,
                    BackgroundTransparency = 1,
                    Position             = UDim2.new(0, 10, 0, 0),
                    Size                 = UDim2.new(0.5, 0, 1, 0),
                    Text                 = lOpt.Name or "Link",
                    TextColor3           = T.TextSub,
                    TextSize             = 12,
                    Font                 = Enum.Font.Gotham,
                    TextXAlignment       = Enum.TextXAlignment.Left,
                    ZIndex               = 17,
                })

                local LinkBtn = New("TextButton", {
                    Parent               = row,
                    BackgroundTransparency = 1,
                    AnchorPoint          = Vector2.new(1, 0.5),
                    Position             = UDim2.new(1, -10, 0.5, 0),
                    Size                 = UDim2.new(0.48, 0, 0, 18),
                    Text                 = lOpt.Url or lOpt.Label or "Open",
                    TextColor3           = T.Accent,
                    TextSize             = 11,
                    Font                 = Enum.Font.GothamBold,
                    TextXAlignment       = Enum.TextXAlignment.Right,
                    ZIndex               = 17,
                    AutoButtonColor      = false,
                    TextTruncate         = Enum.TextTruncate.AtEnd,
                })

                LinkBtn.MouseEnter:Connect(function()
                    Tween(LinkBtn, { TextColor3 = T.AccentHover }, 0.1)
                end)
                LinkBtn.MouseLeave:Connect(function()
                    Tween(LinkBtn, { TextColor3 = T.Accent }, 0.1)
                end)
                LinkBtn.MouseButton1Click:Connect(function()
                    if lOpt.OnClick then
                        task.spawn(lOpt.OnClick)
                    elseif lOpt.Url then
                        pcall(function() setclipboard(lOpt.Url) end)
                        Library:Notify({ Title = "Link", Content = "Copied to clipboard.", Type = "Info" })
                    end
                end)
            end

            -- ========================================================
            --  DIVIDER WITH TEXT
            -- ========================================================
            function Sec:AddDivider(text)
                local row = BaseRow(20)
                New("Frame", {
                    Parent           = row,
                    BackgroundColor3 = T.Border,
                    AnchorPoint      = Vector2.new(0, 0.5),
                    Position         = UDim2.new(0, 0, 0.5, 0),
                    Size             = UDim2.new(1, 0, 0, 1),
                    ZIndex           = 17,
                })
                if text and text ~= "" then
                    New("TextLabel", {
                        Parent           = row,
                        BackgroundColor3 = T.Secondary,
                        AnchorPoint      = Vector2.new(0.5, 0.5),
                        Position         = UDim2.new(0.5, 0, 0.5, 0),
                        Size             = UDim2.new(0, 0, 0, 14),
                        AutomaticSize    = Enum.AutomaticSize.X,
                        Text             = "  " .. text .. "  ",
                        TextColor3       = T.TextDim,
                        TextSize         = 10,
                        Font             = Enum.Font.Gotham,
                        ZIndex           = 18,
                    })
                end
            end

            -- ========================================================
            --  COLOR PICKER
            -- ========================================================
            function Sec:AddColorPicker(cpOpt)
                cpOpt = cpOpt or {}
                local col    = cpOpt.Default or Color3.new(1, 0.314, 0.314)
                local isOpen = false

                local row = BaseRow(38)
                local bg  = RowBg(row)

                RowLabel(bg, cpOpt.Name or "Color", 10, 0.65)

                local Preview = New("Frame", {
                    Parent           = bg,
                    BackgroundColor3 = col,
                    AnchorPoint      = Vector2.new(1, 0.5),
                    Position         = UDim2.new(1, -10, 0.5, 0),
                    Size             = UDim2.new(0, 24, 0, 24),
                    ZIndex           = 18,
                })
                Corner(Preview, 7)
                Stroke(Preview, T.Border, 1)

                local Panel = New("Frame", {
                    Parent           = bg,
                    BackgroundColor3 = T.Secondary,
                    Position         = UDim2.new(0, 0, 1, 5),
                    Size             = UDim2.new(1, 0, 0, 0),
                    ZIndex           = 60,
                    Visible          = false,
                    ClipsDescendants = true,
                })
                Corner(Panel, 8)
                Stroke(Panel, T.Border, 1)

                local PInner = New("Frame", {
                    Parent               = Panel,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, 0, 0, 0),
                    AutomaticSize        = Enum.AutomaticSize.Y,
                    ZIndex               = 61,
                })
                New("UIListLayout", {
                    Parent    = PInner,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding   = UDim.new(0, 5),
                })
                Pad(PInner, 10, 10, 10, 10)

                local vals   = { math.floor(col.R*255), math.floor(col.G*255), math.floor(col.B*255) }
                local chData = {
                    { "R", Color3.fromRGB(215, 68, 68)  },
                    { "G", Color3.fromRGB(68, 200, 100) },
                    { "B", Color3.fromRGB(68, 120, 220) },
                }
                local fillRefs = {}

                local function UpdateColor()
                    col = Color3.fromRGB(vals[1], vals[2], vals[3])
                    Preview.BackgroundColor3 = col
                    if cpOpt.Flag then Library.Flags[cpOpt.Flag] = col end
                    task.spawn(cpOpt.Callback or function() end, col)
                end

                for i, ch in ipairs(chData) do
                    local chRow = New("Frame", {
                        Parent               = PInner,
                        BackgroundTransparency = 1,
                        Size                 = UDim2.new(1, 0, 0, 20),
                        ZIndex               = 62,
                        LayoutOrder          = i,
                    })
                    New("TextLabel", {
                        Parent               = chRow,
                        BackgroundTransparency = 1,
                        Size                 = UDim2.new(0, 14, 1, 0),
                        Text                 = ch[1],
                        TextColor3           = ch[2],
                        TextSize             = 11,
                        Font                 = Enum.Font.GothamBold,
                        ZIndex               = 62,
                    })
                    local track = New("Frame", {
                        Parent           = chRow,
                        BackgroundColor3 = T.Background,
                        Position         = UDim2.new(0, 18, 0.2, 0),
                        Size             = UDim2.new(0.72, -18, 0.6, 0),
                        ZIndex           = 62,
                    })
                    Corner(track, 3)

                    local fill = New("Frame", {
                        Parent           = track,
                        BackgroundColor3 = ch[2],
                        Size             = UDim2.new(vals[i]/255, 0, 1, 0),
                        ZIndex           = 63,
                    })
                    Corner(fill, 3)
                    fillRefs[i] = fill

                    local numLbl = New("TextLabel", {
                        Parent               = chRow,
                        BackgroundTransparency = 1,
                        AnchorPoint          = Vector2.new(1, 0.5),
                        Position             = UDim2.new(1, 0, 0.5, 0),
                        Size                 = UDim2.new(0, 28, 1, 0),
                        Text                 = tostring(vals[i]),
                        TextColor3           = T.TextSub,
                        TextSize             = 10,
                        Font                 = Enum.Font.GothamBold,
                        TextXAlignment       = Enum.TextXAlignment.Right,
                        ZIndex               = 62,
                    })

                    local slid = false
                    local function applyC(sx)
                        local a = math.clamp((sx - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
                        vals[i] = math.floor(a * 255)
                        Tween(fill, { Size = UDim2.new(a, 0, 1, 0) }, 0.04)
                        numLbl.Text = tostring(vals[i])
                        UpdateColor()
                    end

                    local hb = New("TextButton", {
                        Parent               = track,
                        BackgroundTransparency = 1,
                        Size                 = UDim2.new(1, 0, 1, 18),
                        Position             = UDim2.new(0, 0, 0, -9),
                        Text                 = "",
                        ZIndex               = 64,
                        AutoButtonColor      = false,
                    })
                    hb.InputBegan:Connect(function(inp)
                        if inp.UserInputType == Enum.UserInputType.MouseButton1
                        or inp.UserInputType == Enum.UserInputType.Touch then
                            slid = true
                            applyC(inp.Position.X)
                        end
                    end)
                    hb.InputEnded:Connect(function(inp)
                        if inp.UserInputType == Enum.UserInputType.MouseButton1
                        or inp.UserInputType == Enum.UserInputType.Touch then
                            slid = false
                        end
                    end)
                    UserInputService.InputChanged:Connect(function(inp)
                        if slid and (inp.UserInputType == Enum.UserInputType.MouseMovement
                            or inp.UserInputType == Enum.UserInputType.Touch) then
                            applyC(inp.Position.X)
                        end
                    end)
                    UserInputService.InputEnded:Connect(function(inp)
                        if inp.UserInputType == Enum.UserInputType.MouseButton1 then slid = false end
                    end)
                end

                -- Hex row
                local hexRow = New("Frame", {
                    Parent               = PInner,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, 0, 0, 22),
                    ZIndex               = 62,
                    LayoutOrder          = 4,
                })
                New("TextLabel", {
                    Parent               = hexRow,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(0, 30, 1, 0),
                    Text                 = "Hex",
                    TextColor3           = T.TextDim,
                    TextSize             = 10,
                    Font                 = Enum.Font.Gotham,
                    ZIndex               = 62,
                })
                local HexInput = New("TextBox", {
                    Parent           = hexRow,
                    BackgroundColor3 = T.Background,
                    Position         = UDim2.new(0, 34, 0, 1),
                    Size             = UDim2.new(1, -34, 0, 20),
                    Text             = Color3ToHex(col),
                    TextColor3       = T.Accent,
                    TextSize         = 10,
                    Font             = Enum.Font.Code,
                    ZIndex           = 63,
                    ClearTextOnFocus = false,
                })
                Corner(HexInput, 4)
                Pad(HexInput, 0, 5, 0, 5)
                HexInput.FocusLost:Connect(function()
                    local ok2, c2 = pcall(HexToColor3, HexInput.Text)
                    if ok2 and c2 then
                        vals[1] = math.floor(c2.R * 255)
                        vals[2] = math.floor(c2.G * 255)
                        vals[3] = math.floor(c2.B * 255)
                        for i, fill in ipairs(fillRefs) do
                            Tween(fill, { Size = UDim2.new(vals[i]/255, 0, 1, 0) }, 0.1)
                        end
                        UpdateColor()
                    end
                    HexInput.Text = Color3ToHex(col)
                end)

                -- Swatch presets
                local SwatchRow = New("Frame", {
                    Parent               = PInner,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, 0, 0, 26),
                    ZIndex               = 62,
                    LayoutOrder          = 5,
                })
                New("UIListLayout", {
                    Parent            = SwatchRow,
                    FillDirection     = Enum.FillDirection.Horizontal,
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                    Padding           = UDim.new(0, 6),
                })

                for _, preset in ipairs(AccentPresets) do
                    local sw = New("TextButton", {
                        Parent           = SwatchRow,
                        BackgroundColor3 = preset.Color,
                        Size             = UDim2.new(0, 26, 0, 26),
                        Text             = "",
                        ZIndex           = 63,
                        AutoButtonColor  = false,
                    })
                    Corner(sw, 7)
                    Stroke(sw, Color3.fromRGB(255,255,255), 1)
                    local sk = sw:FindFirstChildOfClass("UIStroke")
                    if sk then sk.Transparency = 0.8 end

                    sw.MouseButton1Click:Connect(function()
                        vals[1] = math.floor(preset.Color.R * 255)
                        vals[2] = math.floor(preset.Color.G * 255)
                        vals[3] = math.floor(preset.Color.B * 255)
                        for i, fill in ipairs(fillRefs) do
                            Tween(fill, { Size = UDim2.new(vals[i]/255, 0, 1, 0) }, 0.1)
                        end
                        HexInput.Text = Color3ToHex(preset.Color)
                        UpdateColor()
                    end)
                    sw.MouseEnter:Connect(function()
                        Tween(sw, { Size = UDim2.new(0, 28, 0, 28) }, 0.1)
                    end)
                    sw.MouseLeave:Connect(function()
                        Tween(sw, { Size = UDim2.new(0, 26, 0, 26) }, 0.1)
                    end)
                end

                local clickBtn = New("TextButton", {
                    Parent               = bg,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, 0, 1, 0),
                    Text                 = "",
                    ZIndex               = 20,
                    AutoButtonColor      = false,
                })
                clickBtn.MouseButton1Click:Connect(function()
                    isOpen = not isOpen
                    if isOpen then
                        Panel.Visible = true
                        local h = 10 + (#chData * 25) + 32 + 22 + 26
                        Tween(Panel, { Size = UDim2.new(1, 0, 0, h) }, 0.2)
                    else
                        Tween(Panel, { Size = UDim2.new(1, 0, 0, 0) }, 0.18)
                        task.delay(0.2, function() if Panel.Parent then Panel.Visible = false end end)
                    end
                end)
                clickBtn.MouseEnter:Connect(function() Tween(bg, { BackgroundColor3 = T.BorderHover }, 0.1) end)
                clickBtn.MouseLeave:Connect(function() Tween(bg, { BackgroundColor3 = T.Tertiary }, 0.1) end)

                if cpOpt.Flag then Library.Flags[cpOpt.Flag] = col end

                return {
                    Set = function(_, c)
                        col = c
                        vals[1] = math.floor(c.R * 255)
                        vals[2] = math.floor(c.G * 255)
                        vals[3] = math.floor(c.B * 255)
                        Preview.BackgroundColor3 = c
                        HexInput.Text = Color3ToHex(c)
                        for i, fill in ipairs(fillRefs) do
                            Tween(fill, { Size = UDim2.new(vals[i]/255, 0, 1, 0) }, 0.1)
                        end
                        if cpOpt.Flag then Library.Flags[cpOpt.Flag] = c end
                    end,
                    Get = function(_) return col end,
                }
            end

            -- ========================================================
            --  PROFILE / ACCOUNT CARD
            -- ========================================================
            function Sec:AddProfileCard(acOpt)
                acOpt = acOpt or {}
                local row  = BaseRow(110, true)
                local card = New("Frame", {
                    Parent           = row,
                    BackgroundColor3 = T.Quaternary,
                    Size             = UDim2.new(1, 0, 0, 100),
                    ZIndex           = 17,
                })
                Corner(card, 11)
                Stroke(card, T.Border, 1)

                local header = New("Frame", {
                    Parent           = card,
                    BackgroundColor3 = T.Accent,
                    Size             = UDim2.new(1, 0, 0, 32),
                    ZIndex           = 18,
                })
                Corner(header, 11)
                ThemeEngine.ApplyLogoGradient(header)

                New("Frame", {
                    Parent           = header,
                    BackgroundColor3 = T.Accent,
                    Position         = UDim2.new(0, 0, 0.5, 0),
                    Size             = UDim2.new(1, 0, 0.5, 0),
                    ZIndex           = 18,
                })

                local av = New("Frame", {
                    Parent           = card,
                    BackgroundColor3 = T.Secondary,
                    AnchorPoint      = Vector2.new(0, 0),
                    Position         = UDim2.new(0, 12, 0, 14),
                    Size             = UDim2.new(0, 36, 0, 36),
                    ZIndex           = 20,
                })
                Corner(av, 18)
                Stroke(av, T.Accent, 2)
                New("TextLabel", {
                    Parent               = av,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, 0, 1, 0),
                    Text                 = acOpt.AvatarIcon or "◉",
                    TextColor3           = T.Accent,
                    TextSize             = 16,
                    Font                 = Enum.Font.Gotham,
                    ZIndex               = 21,
                })

                New("TextLabel", {
                    Parent               = card,
                    BackgroundTransparency = 1,
                    Position             = UDim2.new(0, 56, 0, 36),
                    Size                 = UDim2.new(0.75, 0, 0, 16),
                    Text                 = acOpt.Name or LocalPlayer.Name,
                    TextColor3           = T.Text,
                    TextSize             = 14,
                    Font                 = Enum.Font.GothamBold,
                    TextXAlignment       = Enum.TextXAlignment.Left,
                    ZIndex               = 19,
                })
                New("TextLabel", {
                    Parent               = card,
                    BackgroundTransparency = 1,
                    Position             = UDim2.new(0, 56, 0, 54),
                    Size                 = UDim2.new(0.75, 0, 0, 13),
                    Text                 = acOpt.Tier or "✦ Premium",
                    TextColor3           = T.Gold,
                    TextSize             = 11,
                    Font                 = Enum.Font.GothamBold,
                    TextXAlignment       = Enum.TextXAlignment.Left,
                    ZIndex               = 19,
                })

                if acOpt.Expiry then
                    New("TextLabel", {
                        Parent               = card,
                        BackgroundTransparency = 1,
                        Position             = UDim2.new(0, 56, 0, 68),
                        Size                 = UDim2.new(0.75, 0, 0, 12),
                        Text                 = "Expires: " .. tostring(acOpt.Expiry),
                        TextColor3           = T.TextDim,
                        TextSize             = 10,
                        Font                 = Enum.Font.Gotham,
                        TextXAlignment       = Enum.TextXAlignment.Left,
                        ZIndex               = 19,
                    })
                end
            end

            -- ========================================================
            --  ACCENT COLOR PICKER
            -- ========================================================
            function Sec:AddAccentPicker(apOpt)
                apOpt = apOpt or {}
                local row = BaseRow(50)
                local bg  = RowBg(row)
                Pad(bg, 8, 10, 8, 10)
                New("UIListLayout", {
                    Parent    = bg,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding   = UDim.new(0, 7),
                })

                New("TextLabel", {
                    Parent               = bg,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, 0, 0, 13),
                    Text                 = apOpt.Name or "Accent Color",
                    TextColor3           = T.Text,
                    TextSize             = 12,
                    Font                 = Enum.Font.Gotham,
                    TextXAlignment       = Enum.TextXAlignment.Left,
                    ZIndex               = 17,
                    LayoutOrder          = 1,
                })

                local swatchRow = New("Frame", {
                    Parent               = bg,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, 0, 0, 26),
                    ZIndex               = 17,
                    LayoutOrder          = 2,
                })
                New("UIListLayout", {
                    Parent            = swatchRow,
                    FillDirection     = Enum.FillDirection.Horizontal,
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                    Padding           = UDim.new(0, 6),
                })

                local chosenStroke
                for _, preset in ipairs(AccentPresets) do
                    local sw = New("TextButton", {
                        Parent           = swatchRow,
                        BackgroundColor3 = preset.Color,
                        Size             = UDim2.new(0, 26, 0, 26),
                        Text             = "",
                        ZIndex           = 18,
                        AutoButtonColor  = false,
                    })
                    Corner(sw, 7)
                    local swStroke = Stroke(sw, Color3.new(1,1,1), 2)
                    swStroke.Transparency = 0.8

                    sw.MouseButton1Click:Connect(function()
                        if chosenStroke then chosenStroke.Transparency = 0.8 end
                        swStroke.Transparency = 0
                        chosenStroke = swStroke

                        Library.Theme.Accent      = preset.Color
                        Library.Theme.ToggleOn    = preset.Color
                        Library.Theme.AccentHover = preset.Color:Lerp(Color3.new(0,0,0), 0.15)
                        Library.Theme.AccentDim   = preset.Color:Lerp(Color3.new(0,0,0), 0.2)

                        if apOpt.Flag then Library.Flags[apOpt.Flag] = preset.Color end
                        task.spawn(apOpt.Callback or function() end, preset.Color)

                        Library:Notify({
                            Title    = "Accent",
                            Content  = "Changed to " .. preset.Name,
                            Type     = "Info",
                            Duration = 2,
                        })
                    end)
                    sw.MouseEnter:Connect(function()
                        Tween(sw, { Size = UDim2.new(0, 28, 0, 28) }, 0.08)
                    end)
                    sw.MouseLeave:Connect(function()
                        Tween(sw, { Size = UDim2.new(0, 26, 0, 26) }, 0.08)
                    end)
                end
            end

            -- ========================================================
            --  SEARCH BAR
            -- ========================================================
            function Sec:AddSearchBar(srOpt)
                srOpt = srOpt or {}

                local row = BaseRow(34)
                local InBg = New("Frame", {
                    Parent           = row,
                    BackgroundColor3 = T.Tertiary,
                    Size             = UDim2.new(1, 0, 0, 30),
                    ZIndex           = 17,
                })
                Corner(InBg, 8)
                Stroke(InBg, T.Border, 1)

                New("TextLabel", {
                    Parent               = InBg,
                    BackgroundTransparency = 1,
                    AnchorPoint          = Vector2.new(0, 0.5),
                    Position             = UDim2.new(0, 8, 0.5, 0),
                    Size                 = UDim2.new(0, 14, 0, 14),
                    Text                 = "🔍",
                    TextSize             = 11,
                    Font                 = Enum.Font.Gotham,
                    ZIndex               = 18,
                })

                local Input = New("TextBox", {
                    Parent               = InBg,
                    BackgroundTransparency = 1,
                    Position             = UDim2.new(0, 26, 0, 0),
                    Size                 = UDim2.new(1, -26, 1, 0),
                    Text                 = "",
                    PlaceholderText      = srOpt.Placeholder or "Search...",
                    TextColor3           = T.Text,
                    PlaceholderColor3    = T.TextDim,
                    TextSize             = 11,
                    Font                 = Enum.Font.Gotham,
                    ClearTextOnFocus     = false,
                    ZIndex               = 18,
                })

                Input.Focused:Connect(function()
                    Tween(InBg, { BackgroundColor3 = T.Quaternary }, 0.1)
                    local sk = InBg:FindFirstChildOfClass("UIStroke")
                    if sk then Tween(sk, { Color = T.Accent }, 0.1) end
                end)
                Input.FocusLost:Connect(function()
                    Tween(InBg, { BackgroundColor3 = T.Tertiary }, 0.1)
                    local sk = InBg:FindFirstChildOfClass("UIStroke")
                    if sk then Tween(sk, { Color = T.Border }, 0.1) end
                end)

                Input:GetPropertyChangedSignal("Text"):Connect(function()
                    local query = Input.Text:lower()
                    if srOpt.OnSearch then
                        task.spawn(srOpt.OnSearch, query)
                    end
                    for _, child in ipairs(SecBody:GetChildren()) do
                        if child:IsA("Frame") and child ~= row then
                            local lbl = child:FindFirstChild("Label", true)
                                or child:FindFirstChildWhichIsA("TextLabel", true)
                            if lbl then
                                local match = query == "" or lbl.Text:lower():find(query, 1, true)
                                child.Visible = match ~= nil
                            end
                        end
                    end
                end)

                return {
                    Get   = function(_) return Input.Text end,
                    Clear = function(_) Input.Text = "" end,
                }
            end

            -- ========================================================
            --  NOTIFICATION HISTORY
            -- ========================================================
            function Sec:AddNotifHistory()
                local row = BaseRow(120, true)
                local bg  = New("Frame", {
                    Parent           = row,
                    BackgroundColor3 = T.Tertiary,
                    Size             = UDim2.new(1, 0, 0, 0),
                    AutomaticSize    = Enum.AutomaticSize.Y,
                    ZIndex           = 17,
                })
                Corner(bg, 7)
                Pad(bg, 6, 8, 6, 8)
                New("UIListLayout", {
                    Parent    = bg,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding   = UDim.new(0, 3),
                })

                local function RefreshHistory()
                    for _, c in ipairs(bg:GetChildren()) do
                        if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
                    end

                    local history = Library._notifHistory
                    local start   = math.max(1, #history - 7)

                    for i = start, #history do
                        local n = history[i]
                        local accent = Library.Theme[n.Type] or Library.Theme.Info

                        local item = New("Frame", {
                            Parent               = bg,
                            BackgroundTransparency = 1,
                            Size                 = UDim2.new(1, 0, 0, 26),
                            ZIndex               = 18,
                            LayoutOrder          = i,
                        })
                        New("Frame", {
                            Parent           = item,
                            BackgroundColor3 = accent,
                            Size             = UDim2.new(0, 2, 0.6, 0),
                            AnchorPoint      = Vector2.new(0, 0.5),
                            Position         = UDim2.new(0, 0, 0.5, 0),
                            ZIndex           = 19,
                        })
                        New("TextLabel", {
                            Parent               = item,
                            BackgroundTransparency = 1,
                            Position             = UDim2.new(0, 8, 0, 0),
                            Size                 = UDim2.new(0.55, 0, 0.55, 0),
                            Text                 = n.Title,
                            TextColor3           = Library.Theme.Text,
                            TextSize             = 10,
                            Font                 = Enum.Font.GothamBold,
                            TextXAlignment       = Enum.TextXAlignment.Left,
                            ZIndex               = 19,
                        })
                        New("TextLabel", {
                            Parent               = item,
                            BackgroundTransparency = 1,
                            Position             = UDim2.new(0, 8, 0.48, 0),
                            Size                 = UDim2.new(0.75, 0, 0.5, 0),
                            Text                 = n.Content,
                            TextColor3           = Library.Theme.TextSub,
                            TextSize             = 9,
                            Font                 = Enum.Font.Gotham,
                            TextXAlignment       = Enum.TextXAlignment.Left,
                            ZIndex               = 19,
                            TextTruncate         = Enum.TextTruncate.AtEnd,
                        })
                    end

                    if #history == 0 then
                        New("TextLabel", {
                            Parent               = bg,
                            BackgroundTransparency = 1,
                            Size                 = UDim2.new(1, 0, 0, 28),
                            Text                 = "No notifications yet.",
                            TextColor3           = T.TextDim,
                            TextSize             = 11,
                            Font                 = Enum.Font.Gotham,
                            ZIndex               = 18,
                        })
                    end
                end

                RefreshHistory()

                local RefBtn = New("TextButton", {
                    Parent               = bg,
                    BackgroundColor3     = T.Quaternary,
                    Size                 = UDim2.new(1, 0, 0, 22),
                    Text                 = "↺  Refresh",
                    TextColor3           = T.TextSub,
                    TextSize             = 10,
                    Font                 = Enum.Font.Gotham,
                    ZIndex               = 18,
                    AutoButtonColor      = false,
                    LayoutOrder          = 99,
                })
                Corner(RefBtn, 5)
                RefBtn.MouseButton1Click:Connect(RefreshHistory)
                RefBtn.MouseEnter:Connect(function()
                    Tween(RefBtn, { BackgroundColor3 = T.BorderHover }, 0.1)
                end)
                RefBtn.MouseLeave:Connect(function()
                    Tween(RefBtn, { BackgroundColor3 = T.Quaternary }, 0.1)
                end)
            end

            -- ========================================================
            --  LINE CHART  (FIX: was using self.Body / self._order)
            -- ========================================================
            function Sec:AddLineChart(chartOpt)
                chartOpt = chartOpt or {}
                local name = chartOpt.Name or "Line Chart"
                local data = chartOpt.Data or {0, 0, 0, 0, 0}

                local row = New("Frame", {
                    Parent               = SecBody,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, 0, 0, 180),
                    ZIndex               = 17,
                    LayoutOrder          = Sec._order,
                })
                Sec._order += 1

                local bg = New("Frame", {
                    Parent           = row,
                    BackgroundColor3 = T.Tertiary,
                    Size             = UDim2.new(1, 0, 1, 0),
                    ZIndex           = 17,
                })
                Corner(bg, 7)

                New("TextLabel", {
                    Parent               = bg,
                    BackgroundTransparency = 1,
                    Position             = UDim2.new(0, 10, 0, 8),
                    Size                 = UDim2.new(1, -20, 0, 16),
                    Text                 = name,
                    TextColor3           = T.Text,
                    TextSize             = 12,
                    Font                 = Enum.Font.GothamBold,
                    TextXAlignment       = Enum.TextXAlignment.Left,
                    ZIndex               = 18,
                })

                local chartArea = New("Frame", {
                    Parent           = bg,
                    BackgroundColor3 = T.Secondary,
                    Position         = UDim2.new(0, 10, 0, 32),
                    Size             = UDim2.new(1, -20, 1, -42),
                    ZIndex           = 18,
                    ClipsDescendants = true,
                })
                Corner(chartArea, 6)

                local points = {}
                local lines = {}

                local function redraw()
                    for _, p in ipairs(points) do pcall(function() p:Destroy() end) end
                    for _, l in ipairs(lines)  do pcall(function() l:Destroy() end) end
                    points = {}
                    lines  = {}

                    if #data < 2 then return end

                    local minVal, maxVal = math.huge, -math.huge
                    for _, v in ipairs(data) do
                        if v < minVal then minVal = v end
                        if v > maxVal then maxVal = v end
                    end
                    if maxVal == minVal then maxVal = minVal + 1 end

                    local width  = chartArea.AbsoluteSize.X
                    local height = chartArea.AbsoluteSize.Y
                    local stepX  = width / (#data - 1)
                    local prevPt = nil

                    for i, v in ipairs(data) do
                        local norm = (v - minVal) / (maxVal - minVal)
                        local px   = (i - 1) * stepX
                        local py   = height - (norm * height)

                        local pt = New("Frame", {
                            Parent           = chartArea,
                            BackgroundColor3 = T.Accent,
                            AnchorPoint      = Vector2.new(0.5, 0.5),
                            Position         = UDim2.new(0, px, 0, py),
                            Size             = UDim2.new(0, 6, 0, 6),
                            ZIndex           = 20,
                        })
                        Corner(pt, 3)
                        table.insert(points, pt)

                        if prevPt then
                            local dist  = math.sqrt((px - prevPt.X)^2 + (py - prevPt.Y)^2)
                            local angle = math.deg(math.atan2(py - prevPt.Y, px - prevPt.X))
                            local ln    = New("Frame", {
                                Parent           = chartArea,
                                BackgroundColor3 = T.Accent,
                                BorderSizePixel  = 0,
                                AnchorPoint      = Vector2.new(0.5, 0.5),
                                Position         = UDim2.new(0, (px + prevPt.X) / 2, 0, (py + prevPt.Y) / 2),
                                Size             = UDim2.new(0, dist, 0, 2),
                                Rotation         = angle,
                                ZIndex           = 19,
                            })
                            table.insert(lines, ln)
                        end
                        prevPt = { X = px, Y = py }
                    end
                end

                chartArea:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
                    pcall(redraw)
                end)
                pcall(redraw)

                local chartObj = {}
                function chartObj:Update(newData)
                    data = newData
                    pcall(redraw)
                end
                return chartObj
            end

            -- ========================================================
            --  NODE EDITOR  (FIX: was using self.Body / self._order)
            -- ========================================================
            function Sec:AddNodeEditor(nodeOpt)
                nodeOpt = nodeOpt or {}
                local name = nodeOpt.Name or "Node Editor"

                local row = New("Frame", {
                    Parent               = SecBody,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, 0, 0, 400),
                    ZIndex               = 17,
                    LayoutOrder          = Sec._order,
                })
                Sec._order += 1

                local bg = New("Frame", {
                    Parent           = row,
                    BackgroundColor3 = T.Tertiary,
                    Size             = UDim2.new(1, 0, 1, 0),
                    ZIndex           = 17,
                })
                Corner(bg, 7)

                local canvas = New("ScrollingFrame", {
                    Parent           = bg,
                    BackgroundColor3 = T.Background,
                    Position         = UDim2.new(0, 2, 0, 2),
                    Size             = UDim2.new(1, -4, 1, -4),
                    CanvasSize       = UDim2.new(0, 2000, 0, 2000),
                    ScrollBarThickness = 4,
                    ZIndex           = 18,
                })
                Corner(canvas, 5)

                New("ImageLabel", {
                    Parent             = canvas,
                    BackgroundTransparency = 1,
                    Size               = UDim2.new(1, 0, 1, 0),
                    Image              = "rbxassetid://6553888365",
                    ImageColor3        = T.Border,
                    ImageTransparency  = 0.5,
                    ScaleType          = Enum.ScaleType.Tile,
                    TileSize           = UDim2.new(0, 40, 0, 40),
                    ZIndex             = 18,
                })

                local function CreateNode(nodeTitle, position)
                    local node = New("Frame", {
                        Parent           = canvas,
                        BackgroundColor3 = T.Secondary,
                        Position         = UDim2.new(0, position.X, 0, position.Y),
                        Size             = UDim2.new(0, 160, 0, 100),
                        ZIndex           = 25,
                        Active           = true,
                        Draggable        = true,
                    })
                    Corner(node, 6)
                    Stroke(node, T.BorderHover, 1)

                    local header = New("Frame", {
                        Parent           = node,
                        BackgroundColor3 = T.Accent,
                        Size             = UDim2.new(1, 0, 0, 24),
                        ZIndex           = 26,
                    })
                    Corner(header, 6)
                    New("Frame", {
                        Parent           = header,
                        BackgroundColor3 = T.Accent,
                        Position         = UDim2.new(0, 0, 0.5, 0),
                        Size             = UDim2.new(1, 0, 0.5, 0),
                        ZIndex           = 26,
                    })

                    New("TextLabel", {
                        Parent               = header,
                        BackgroundTransparency = 1,
                        Size                 = UDim2.new(1, -10, 1, 0),
                        Position             = UDim2.new(0, 10, 0, 0),
                        Text                 = nodeTitle,
                        TextColor3           = Color3.new(1,1,1),
                        Font                 = Enum.Font.GothamBold,
                        TextSize             = 12,
                        TextXAlignment       = Enum.TextXAlignment.Left,
                        ZIndex               = 27,
                    })

                    local inputPort = New("TextButton", {
                        Parent           = node,
                        BackgroundColor3 = T.Background,
                        Position         = UDim2.new(0, -6, 0, 40),
                        Size             = UDim2.new(0, 12, 0, 12),
                        Text             = "",
                        ZIndex           = 28,
                    })
                    Corner(inputPort, 6)
                    Stroke(inputPort, T.Border, 2)

                    local outputPort = New("TextButton", {
                        Parent           = node,
                        BackgroundColor3 = T.Accent,
                        Position         = UDim2.new(1, -6, 0, 40),
                        Size             = UDim2.new(0, 12, 0, 12),
                        Text             = "",
                        ZIndex           = 28,
                    })
                    Corner(outputPort, 6)
                    Stroke(outputPort, T.Border, 2)

                    return { Node = node, Input = inputPort, Output = outputPort }
                end

                CreateNode("Start Event",  Vector2.new(50,  100))
                CreateNode("Math: Add",    Vector2.new(300, 80))
                CreateNode("Print String", Vector2.new(550, 120))

                local nodeObj = {}
                function nodeObj:AddNode(titleStr, pos)
                    return CreateNode(titleStr, pos)
                end
                return nodeObj
            end

            -- ========================================================
            --  TREE VIEW  (FIX: was using self.Body / self._order + Guard.Connect)
            -- ========================================================
            function Sec:AddTreeView(treeOpt)
                treeOpt = treeOpt or {}
                local name = treeOpt.Name or "Explorer"
                local data = treeOpt.Data or {
                    { Name = "Workspace", Type = "Folder", Children = {
                        { Name = "Baseplate",     Type = "Part" },
                        { Name = "SpawnLocation", Type = "Part" },
                    }},
                    { Name = "Players", Type = "Folder", Children = {} },
                }

                local row = New("Frame", {
                    Parent               = SecBody,
                    BackgroundTransparency = 1,
                    Size                 = UDim2.new(1, 0, 0, 240),
                    ZIndex               = 17,
                    LayoutOrder          = Sec._order,
                })
                Sec._order += 1

                local bg = New("Frame", {
                    Parent           = row,
                    BackgroundColor3 = T.Tertiary,
                    Size             = UDim2.new(1, 0, 1, 0),
                    ZIndex           = 17,
                })
                Corner(bg, 7)

                local scroller = New("ScrollingFrame", {
                    Parent             = bg,
                    BackgroundTransparency = 1,
                    Position           = UDim2.new(0, 5, 0, 5),
                    Size               = UDim2.new(1, -10, 1, -10),
                    ScrollBarThickness = 2,
                    CanvasSize         = UDim2.new(0, 0, 0, 0),
                    AutomaticCanvasSize = Enum.AutomaticSize.Y,
                    ZIndex             = 18,
                })
                New("UIListLayout", {
                    Parent    = scroller,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding   = UDim.new(0, 2),
                })

                local function RenderItem(item, parentFrame, level)
                    local itemBtn = New("TextButton", {
                        Parent                 = parentFrame,
                        BackgroundColor3       = T.Secondary,
                        BackgroundTransparency = 1,
                        Size                   = UDim2.new(1, 0, 0, 22),
                        Text                   = "",
                        ZIndex                 = 19,
                        AutoButtonColor        = false,
                    })

                    local indent  = level * 16
                    local iconStr = item.Type == "Folder" and "📁" or "📄"

                    New("TextLabel", {
                        Parent               = itemBtn,
                        BackgroundTransparency = 1,
                        Position             = UDim2.new(0, indent + 24, 0, 0),
                        Size                 = UDim2.new(1, -(indent + 24), 1, 0),
                        Text                 = item.Name,
                        TextColor3           = T.Text,
                        Font                 = Enum.Font.Gotham,
                        TextSize             = 12,
                        TextXAlignment       = Enum.TextXAlignment.Left,
                        ZIndex               = 20,
                    })

                    local iconLbl = New("TextLabel", {
                        Parent               = itemBtn,
                        BackgroundTransparency = 1,
                        Position             = UDim2.new(0, indent + 4, 0, 0),
                        Size                 = UDim2.new(0, 16, 1, 0),
                        Text                 = iconStr,
                        TextColor3           = T.Text,
                        Font                 = Enum.Font.Gotham,
                        TextSize             = 12,
                        ZIndex               = 20,
                    })

                    if item.Type == "Folder" and item.Children then
                        local childrenFrame = New("Frame", {
                            Parent            = parentFrame,
                            BackgroundTransparency = 1,
                            Size              = UDim2.new(1, 0, 0, 0),
                            AutomaticSize     = Enum.AutomaticSize.Y,
                            Visible           = false,
                            ZIndex            = 19,
                        })
                        New("UIListLayout", {
                            Parent    = childrenFrame,
                            SortOrder = Enum.SortOrder.LayoutOrder,
                        })
                        for _, child in ipairs(item.Children) do
                            RenderItem(child, childrenFrame, level + 1)
                        end

                        -- FIX: was Guard.Connect — use direct :Connect
                        itemBtn.MouseButton1Click:Connect(function()
                            childrenFrame.Visible = not childrenFrame.Visible
                            iconLbl.Text = childrenFrame.Visible and "📂" or "📁"
                        end)
                    end
                end

                for _, rootItem in ipairs(data) do
                    RenderItem(rootItem, scroller, 0)
                end
            end

            return Sec

        end -- CreateSection

        return Tab
    end -- CreateTab

    -- ==================================================================
    --  SETTINGS TAB
    -- ==================================================================

    function Win:AddSettingsTab()
        local T   = Library.Theme
        local tab = self:CreateTab({ Name = "Settings", Icon = "✦" })

        local AppSec = tab:CreateSection("Appearance")

        AppSec:AddAccentPicker({
            Name     = "Accent Color",
            Callback = function() end,
        })

        AppSec:AddDropdown({
            Name     = "Theme",
            Items    = ThemeOrder,
            Default  = "Dark",
            Flag     = "Theme",
            Callback = function(v)
                Library:SetTheme(v)
            end,
        })

        AppSec:AddSlider({
            Name      = "Background Transparency",
            Min       = 0, Max = 95, Default = 0,
            Increment = 5, Suffix = "%",
            Flag      = "BgTransparency",
            Callback  = function(v)
                local t = v / 100
                Tween(WinFrame, { BackgroundTransparency = t }, 0.15)
            end,
        })

        AppSec:AddSlider({
            Name      = "DPI Scale",
            Min       = 80, Max = 120, Default = 100,
            Increment = 5, Suffix = "%",
            Flag      = "DPIScale",
            Callback  = function(v)
                Library._scale = v / 100
            end,
        })

        local BehSec = tab:CreateSection("Behavior")

        BehSec:AddToggle({
            Name     = "Show Floating Toggle",
            Default  = false,
            Flag     = "ShowFloatBtn",
            Callback = function(v) end,
        })

        local KbSec = tab:CreateSection("Keybinds")

        KbSec:AddKeybind({
            Name     = "Toggle UI",
            Default  = self._toggleKey or Enum.KeyCode.RightShift,
            Flag     = "KeyToggleUI",
            Callback = function() end,
        })

        KbSec:AddKeybind({
            Name     = "Minimize UI",
            Default  = Enum.KeyCode.RightAlt,
            Flag     = "KeyMinimize",
            Callback = function()
                self._minimized = not self._minimized
                if self._minimized then
                    Tween(WinFrame, { Size = UDim2.new(0, WinFrame.AbsoluteSize.X, 0, 46) }, 0.22, Enum.EasingStyle.Quint)
                else
                    Tween(WinFrame, { Size = winSize }, 0.22, Enum.EasingStyle.Quint)
                end
            end,
        })
    end

    -- ==================================================================
    --  FLOATING TOGGLE BUTTON
    -- ==================================================================
    function Win:AddFloatingToggle(ftOpt)
        ftOpt = ftOpt or {}
        local T = Library.Theme

        local FBtn = New("TextButton", {
            Name             = "BorcaHub_FloatBtn",
            Parent           = ScreenGui,
            BackgroundColor3 = T.Accent,
            AnchorPoint      = Vector2.new(0, 1),
            Position         = ftOpt.Position or UDim2.new(0, 8, 1, -8),
            Size             = UDim2.new(0, 36, 0, 36),
            Text             = ftOpt.Icon or icon,
            TextColor3       = Color3.new(1, 1, 1),
            TextSize         = 15,
            Font             = Enum.Font.GothamBold,
            ZIndex           = 500,
            AutoButtonColor  = false,
        })
        Corner(FBtn, 10)
        ThemeEngine.ApplyLogoGradient(FBtn)

        FBtn.MouseEnter:Connect(function()
            Tween(FBtn, { Size = UDim2.new(0, 40, 0, 40) }, 0.12)
        end)
        FBtn.MouseLeave:Connect(function()
            Tween(FBtn, { Size = UDim2.new(0, 36, 0, 36) }, 0.12)
        end)
        FBtn.MouseButton1Click:Connect(function()
            Win._visible = not Win._visible
            WinFrame.Visible = Win._visible
            if Win._visible and not Win._minimized then
                WinFrame.Size = UDim2.new(0, Win._origSize.X.Offset, 0, 0)
                Tween(WinFrame, { Size = Win._origSize }, 0.22, Enum.EasingStyle.Quint)
            end
            Ripple(FBtn, FBtn.AbsolutePosition.X + 18, FBtn.AbsolutePosition.Y + 18, T.Accent)
        end)

        return FBtn
    end

    table.insert(self._windows, Win)
    return Win

end -- CreateWindow

-- ====================================================================
--  PUBLIC HELPERS
-- ====================================================================

function Library:GetFlag(name)
    return self.Flags[name]
end

function Library:SetFlag(name, value)
    self.Flags[name] = value
end

function Library:RegisterKeybind(key, cb)
    table.insert(self._keybinds, { Key = key, Cb = cb })
end

function Library:SetTheme(name)
    if Themes[name] then
        self.Theme = Themes[name]
        for i, n in ipairs(ThemeOrder) do
            if n == name then self._themeIdx = i; break end
        end
    end
end

function Library:GetThemes()
    return ThemeOrder
end

function Library:GetAccentPresets()
    return AccentPresets
end

function Library:ClearNotifHistory()
    self._notifHistory = {}
end

function Library:GetNotifHistory()
    return ShallowCopy(self._notifHistory)
end

function Library:ThemeExists(name)
    return Themes[name] ~= nil
end

-- ====================================================================
--  v3.0.0 PUBLIC HELPERS
-- ====================================================================

function Library:Toast(message, notifType, duration)
    self:Notify({
        Title    = "BorcaHub",
        Content  = message or "",
        Type     = notifType or "Info",
        Duration = duration  or 3,
    })
end

function Library:SetAccent(color)
    if typeof(color) ~= "Color3" then return end
    local T = self.Theme
    T.Accent      = color
    T.AccentHover = color:Lerp(Color3.new(0,0,0), 0.12)
    T.AccentDim   = color:Lerp(Color3.new(0,0,0), 0.08)
    T.ToggleOn    = color
    T.Info        = color
end

-- ====================================================================
--  WATERMARK OVERLAY
-- ====================================================================
function Library:Watermark(wmOpt)
    wmOpt = wmOpt or {}
    local T        = self.Theme
    local name     = wmOpt.Name    or self.Meta.Name
    local ver      = wmOpt.Version or self.Meta.Version
    local showFps  = wmOpt.ShowFPS ~= false
    local corner   = wmOpt.Corner  or "TopRight"

    local anchorX = (corner == "TopRight" or corner == "BottomRight") and 1 or 0
    local anchorY = (corner == "BottomLeft" or corner == "BottomRight") and 1 or 0
    local posX    = anchorX == 1 and UDim.new(1, -8) or UDim.new(0, 8)
    local posY    = anchorY == 1 and UDim.new(1, -8) or UDim.new(0, 8)

    local WM = New("Frame", {
        Name             = "BorcaHub_Watermark",
        Parent           = ScreenGui,
        BackgroundColor3 = T.Secondary,
        AnchorPoint      = Vector2.new(anchorX, anchorY),
        Position         = UDim2.new(posX.Scale, posX.Offset, posY.Scale, posY.Offset),
        Size             = UDim2.new(0, 0, 0, 26),
        AutomaticSize    = Enum.AutomaticSize.X,
        ZIndex           = 900,
    })
    Corner(WM, 7)
    Stroke(WM, T.Border, 1)
    Pad(WM, 5, 10, 5, 10)

    New("UIListLayout", {
        Parent            = WM,
        FillDirection     = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding           = UDim.new(0, 6),
    })

    local badge = New("TextLabel", {
        Parent               = WM,
        BackgroundColor3     = T.Accent,
        BackgroundTransparency = 0,
        Size                 = UDim2.new(0, 0, 0, 16),
        AutomaticSize        = Enum.AutomaticSize.X,
        Text                 = " " .. (wmOpt.Label or "BH") .. " ",
        TextColor3           = Color3.new(1,1,1),
        TextSize             = 10,
        Font                 = Enum.Font.GothamBold,
        ZIndex               = 901,
    })
    Corner(badge, 4)
    ThemeEngine.ApplyLogoGradient(badge)

    local nameLbl = New("TextLabel", {
        Parent               = WM,
        BackgroundTransparency = 1,
        Size                 = UDim2.new(0, 0, 1, 0),
        AutomaticSize        = Enum.AutomaticSize.X,
        Text                 = name .. "  v" .. ver,
        TextColor3           = T.TextSub,
        TextSize             = 11,
        Font                 = Enum.Font.Gotham,
        ZIndex               = 901,
    })

    local FpsLbl
    if showFps then
        New("Frame", {
            Parent           = WM,
            BackgroundColor3 = T.Border,
            Size             = UDim2.new(0, 1, 0.7, 0),
            ZIndex           = 901,
        })
        FpsLbl = New("TextLabel", {
            Parent               = WM,
            BackgroundTransparency = 1,
            Size                 = UDim2.new(0, 0, 1, 0),
            AutomaticSize        = Enum.AutomaticSize.X,
            Text                 = "-- FPS",
            TextColor3           = T.TextSub,
            TextSize             = 11,
            Font                 = Enum.Font.GothamBold,
            ZIndex               = 901,
        })

        local fpsBuffer, fpsIdx = {}, 1
        for i = 1, 12 do fpsBuffer[i] = 60 end
        task.spawn(function()
            local lastTime = os.clock()
            while FpsLbl and FpsLbl.Parent do
                RunService.RenderStepped:Wait()
                local now = os.clock()
                local fps = 1 / math.max(now - lastTime, 0.001)
                lastTime = now
                fpsBuffer[fpsIdx] = fps
                fpsIdx = (fpsIdx % 12) + 1
                local avg = 0
                for _, v in ipairs(fpsBuffer) do avg += v end
                avg = math.floor(avg / 12)
                FpsLbl.Text = tostring(avg) .. " FPS"
                local fpColor = avg >= 55 and T.Success or (avg >= 30 and T.Warning or T.Error)
                FpsLbl.TextColor3 = fpColor
                task.wait(0.25)
            end
        end)
    end

    WM.BackgroundTransparency = 1
    Tween(WM, { BackgroundTransparency = 0 }, 0.3, Enum.EasingStyle.Quint)

    return {
        Frame    = WM,
        SetName  = function(_, v) nameLbl.Text = v end,
        Destroy  = function()
            Tween(WM, { BackgroundTransparency = 1 }, 0.2)
            task.delay(0.22, function() if WM.Parent then WM:Destroy() end end)
        end,
    }
end

-- ====================================================================
--  ANNOUNCEMENT BANNER
-- ====================================================================
function Library:Banner(bnOpt)
    bnOpt = bnOpt or {}
    local T        = self.Theme
    local title    = bnOpt.Title   or "Announcement"
    local message  = bnOpt.Message or bnOpt.Content or ""
    local bType    = bnOpt.Type    or "Info"
    local duration = bnOpt.Duration or nil
    local accent   = T[bType] or T.Info

    local BannerWrap = New("Frame", {
        Name             = "BorcaHub_Banner",
        Parent           = ScreenGui,
        BackgroundColor3 = T.Secondary,
        AnchorPoint      = Vector2.new(0.5, 0),
        Position         = UDim2.new(0.5, 0, 0, -70),
        Size             = UDim2.new(0.7, 0, 0, 0),
        AutomaticSize    = Enum.AutomaticSize.Y,
        ZIndex           = 950,
        ClipsDescendants = false,
    })
    Corner(BannerWrap, 10)
    Stroke(BannerWrap, accent, 1)

    local AccentBar = New("Frame", {
        Parent           = BannerWrap,
        BackgroundColor3 = accent,
        Size             = UDim2.new(1, 0, 0, 3),
        BorderSizePixel  = 0,
        ZIndex           = 951,
    })
    Corner(AccentBar, 2)

    local Inner = New("Frame", {
        Parent               = BannerWrap,
        BackgroundTransparency = 1,
        Position             = UDim2.new(0, 0, 0, 3),
        Size                 = UDim2.new(1, 0, 0, 0),
        AutomaticSize        = Enum.AutomaticSize.Y,
        ZIndex               = 951,
    })
    Pad(Inner, 10, 44, 10, 16)
    New("UIListLayout", {
        Parent    = Inner,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding   = UDim.new(0, 4),
    })

    New("TextLabel", {
        Parent               = Inner,
        BackgroundTransparency = 1,
        Size                 = UDim2.new(1, 0, 0, 16),
        Text                 = title,
        TextColor3           = T.Text,
        TextSize             = 13,
        Font                 = Enum.Font.GothamBold,
        TextXAlignment       = Enum.TextXAlignment.Left,
        ZIndex               = 952,
        LayoutOrder          = 1,
    })

    if message ~= "" then
        New("TextLabel", {
            Parent               = Inner,
            BackgroundTransparency = 1,
            Size                 = UDim2.new(1, 0, 0, 0),
            AutomaticSize        = Enum.AutomaticSize.Y,
            Text                 = message,
            TextColor3           = T.TextSub,
            TextSize             = 12,
            Font                 = Enum.Font.Gotham,
            TextXAlignment       = Enum.TextXAlignment.Left,
            TextWrapped          = true,
            ZIndex               = 952,
            LayoutOrder          = 2,
        })
    end

    local DismissBtn = New("TextButton", {
        Parent               = BannerWrap,
        BackgroundTransparency = 1,
        AnchorPoint          = Vector2.new(1, 0),
        Position             = UDim2.new(1, -8, 0, 8),
        Size                 = UDim2.new(0, 20, 0, 20),
        Text                 = "✕",
        TextColor3           = T.TextDim,
        TextSize             = 11,
        Font                 = Enum.Font.GothamBold,
        ZIndex               = 953,
        AutoButtonColor      = false,
    })
    Corner(DismissBtn, 4)
    DismissBtn.MouseEnter:Connect(function()
        Tween(DismissBtn, { TextColor3 = T.Text }, 0.1)
    end)
    DismissBtn.MouseLeave:Connect(function()
        Tween(DismissBtn, { TextColor3 = T.TextDim }, 0.1)
    end)

    local function Dismiss()
        Tween(BannerWrap, { Position = UDim2.new(0.5, 0, 0, -80) }, 0.22, Enum.EasingStyle.Quint)
        task.wait(0.24)
        if BannerWrap.Parent then BannerWrap:Destroy() end
    end
    DismissBtn.MouseButton1Click:Connect(Dismiss)

    Tween(BannerWrap, { Position = UDim2.new(0.5, 0, 0, 8) }, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

    if duration then
        task.delay(duration, function()
            if BannerWrap.Parent then Dismiss() end
        end)
    end

    return { Frame = BannerWrap, Dismiss = Dismiss }
end

-- ====================================================================
--  INPUT PROMPT
-- ====================================================================
function Library:InputPrompt(ipOpt)
    ipOpt = ipOpt or {}
    local T = self.Theme

    local Overlay = New("Frame", {
        Name                 = "InputOverlay",
        Parent               = ScreenGui,
        BackgroundColor3     = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.5,
        Size                 = UDim2.new(1, 0, 1, 0),
        ZIndex               = 970,
    })

    local Dialog = New("Frame", {
        Parent               = Overlay,
        BackgroundColor3     = T.Secondary,
        AnchorPoint          = Vector2.new(0.5, 0.5),
        Position             = UDim2.new(0.5, 0, 0.5, 0),
        Size                 = UDim2.new(0, 360, 0, 0),
        AutomaticSize        = Enum.AutomaticSize.Y,
        ZIndex               = 971,
    })
    Corner(Dialog, 12)
    Stroke(Dialog, T.Border, 1)

    local DInner = New("Frame", {
        Parent               = Dialog,
        BackgroundTransparency = 1,
        Size                 = UDim2.new(1, 0, 0, 0),
        AutomaticSize        = Enum.AutomaticSize.Y,
        ZIndex               = 972,
    })
    Pad(DInner, 22, 22, 22, 22)
    New("UIListLayout", {
        Parent    = DInner,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding   = UDim.new(0, 12),
    })

    New("TextLabel", {
        Parent               = DInner,
        BackgroundTransparency = 1,
        Size                 = UDim2.new(1, 0, 0, 18),
        Text                 = ipOpt.Title or "Enter Value",
        TextColor3           = T.Text,
        TextSize             = 15,
        Font                 = Enum.Font.GothamBold,
        TextXAlignment       = Enum.TextXAlignment.Left,
        ZIndex               = 973,
        LayoutOrder          = 1,
    })

    if ipOpt.Message then
        New("TextLabel", {
            Parent               = DInner,
            BackgroundTransparency = 1,
            Size                 = UDim2.new(1, 0, 0, 0),
            AutomaticSize        = Enum.AutomaticSize.Y,
            Text                 = ipOpt.Message,
            TextColor3           = T.TextSub,
            TextSize             = 12,
            Font                 = Enum.Font.Gotham,
            TextXAlignment       = Enum.TextXAlignment.Left,
            TextWrapped          = true,
            ZIndex               = 973,
            LayoutOrder          = 2,
        })
    end

    local InputBg = New("Frame", {
        Parent           = DInner,
        BackgroundColor3 = T.Tertiary,
        Size             = UDim2.new(1, 0, 0, 38),
        ZIndex           = 973,
        LayoutOrder      = 3,
    })
    Corner(InputBg, 8)
    Stroke(InputBg, T.Border, 1)

    local TB = New("TextBox", {
        Parent               = InputBg,
        BackgroundTransparency = 1,
        Position             = UDim2.new(0, 12, 0, 0),
        Size                 = UDim2.new(1, -24, 1, 0),
        Text                 = ipOpt.Default or "",
        PlaceholderText      = ipOpt.Placeholder or "Type here...",
        PlaceholderColor3    = T.TextDim,
        TextColor3           = T.Text,
        TextSize             = 13,
        Font                 = Enum.Font.Gotham,
        ClearTextOnFocus     = ipOpt.ClearOnFocus ~= false,
        ZIndex               = 974,
    })

    TB.Focused:Connect(function()
        Tween(InputBg, { BackgroundColor3 = T.Quaternary }, 0.1)
        local s = InputBg:FindFirstChildOfClass("UIStroke")
        if s then Tween(s, { Color = T.Accent }, 0.1) end
    end)
    TB.FocusLost:Connect(function()
        Tween(InputBg, { BackgroundColor3 = T.Tertiary }, 0.1)
        local s = InputBg:FindFirstChildOfClass("UIStroke")
        if s then Tween(s, { Color = T.Border }, 0.1) end
    end)

    local BRow = New("Frame", {
        Parent               = DInner,
        BackgroundTransparency = 1,
        Size                 = UDim2.new(1, 0, 0, 34),
        ZIndex               = 973,
        LayoutOrder          = 4,
    })
    New("UIListLayout", {
        Parent              = BRow,
        FillDirection       = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment   = Enum.VerticalAlignment.Center,
        Padding             = UDim.new(0, 8),
    })

    local CancelBtn = New("TextButton", {
        Parent               = BRow,
        BackgroundColor3     = T.Tertiary,
        Size                 = UDim2.new(0, 90, 0, 30),
        Text                 = ipOpt.CancelText or "Cancel",
        TextColor3           = T.TextSub,
        TextSize             = 12,
        Font                 = Enum.Font.Gotham,
        ZIndex               = 974,
        AutoButtonColor      = false,
    })
    Corner(CancelBtn, 7)
    Stroke(CancelBtn, T.Border, 1)

    local ConfirmBtn = New("TextButton", {
        Parent               = BRow,
        BackgroundColor3     = T.Accent,
        Size                 = UDim2.new(0, 90, 0, 30),
        Text                 = ipOpt.ConfirmText or "Confirm",
        TextColor3           = Color3.new(1, 1, 1),
        TextSize             = 12,
        Font                 = Enum.Font.GothamBold,
        ZIndex               = 974,
        AutoButtonColor      = false,
    })
    Corner(ConfirmBtn, 7)

    for _, btn in ipairs({ CancelBtn, ConfirmBtn }) do
        btn.MouseEnter:Connect(function()
            Tween(btn, { BackgroundColor3 = T.BorderHover }, 0.1)
        end)
        btn.MouseLeave:Connect(function()
            local c = btn == ConfirmBtn and T.Accent or T.Tertiary
            Tween(btn, { BackgroundColor3 = c }, 0.1)
        end)
    end

    Dialog.BackgroundTransparency = 1
    Tween(Dialog, { BackgroundTransparency = 0 }, 0.2)
    Overlay.BackgroundTransparency = 1
    Tween(Overlay, { BackgroundTransparency = 0.5 }, 0.2)

    local function Close()
        Tween(Overlay, { BackgroundTransparency = 1 }, 0.18)
        task.wait(0.2)
        if Overlay.Parent then Overlay:Destroy() end
    end

    CancelBtn.MouseButton1Click:Connect(function()
        Close()
        if ipOpt.OnCancel then task.spawn(ipOpt.OnCancel) end
    end)

    ConfirmBtn.MouseButton1Click:Connect(function()
        local val = TB.Text
        Close()
        if ipOpt.OnConfirm then task.spawn(ipOpt.OnConfirm, val) end
    end)

    TB.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            local val = TB.Text
            Close()
            if ipOpt.OnConfirm then task.spawn(ipOpt.OnConfirm, val) end
        end
    end)

    Overlay.MouseButton1Click:Connect(function()
        Close()
        if ipOpt.OnCancel then task.spawn(ipOpt.OnCancel) end
    end)

    task.defer(function() TB:CaptureFocus() end)
end

-- ====================================================================
--  VERSION INFO
-- ====================================================================

Library.Meta = {
    Name        = "BorcaHub UI Library",
    Version     = "3.0.0",
    Author      = "BorcaHub",
    Description = "Modern, animated UI library for Roblox script hubs.",
    GitHub      = "github.com/BorCaHub/BorcaHub",
    Discord     = "discord.gg/borcahub",
    Website     = nil,
}

return Library
