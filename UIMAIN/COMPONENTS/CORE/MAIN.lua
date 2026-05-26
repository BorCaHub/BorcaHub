--[[
    â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
    â•‘                 BorcaHub UI Library  â€¢  Main.lua                     â•‘
    â•‘            UIMain / Components / File / Main.lua                     â•‘
    â•‘                                                                      â•‘
    â•‘  Style   : BorcaHub Premium  (modern, dark, animated)                â•‘
    â•‘  Target  : Universal  (Synapse X, KRNL, Delta, Fluxus, Mobile)       â•‘
    â•‘  Version : 0.0.1                                                     â•‘
    â•‘                                                                      â•‘
    â•‘  v3.0.0 Changelog:                                                   â•‘
    â•‘   + 3 New Themes  : Sakura Â· Cyber Â· Sunset                          â•‘
    â•‘   + 6 New Accents : Gold Â· Silver Â· Emerald Â· Sky Â· Coral Â· Violet   â•‘
    â•‘   + Library:Watermark()    â€” FPS/version overlay                     â•‘
    â•‘   + Library:Banner()       â€” top-screen announcement banner          â•‘
    â•‘   + Library:InputPrompt()  â€” dialog with text input field            â•‘
    â•‘   + Library:SetAccent()    â€” runtime accent color change             â•‘
    â•‘   + Library:Toast()        â€” quick notification shorthand            â•‘
    â•‘   + Sec:AddSeparator()     â€” labeled divider inside sections         â•‘
    â•‘   + Sec:AddText()          â€” informational text block                â•‘
    â•‘   + Sec:AddProgressBar()   â€” updatable progress bar element          â•‘
    â•‘   + Tab:Select()           â€” programmatic tab switching              â•‘
    â•‘   + Win:SetTitle()         â€” runtime window title change             â•‘
    â•‘   * Smoother open animation (spring scale + fade)                    â•‘
    â•‘   * Logo badge pulse glow effect                                     â•‘
    â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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
--  CORE MODULES (3-File Architecture)
-- ====================================================================

local ThemeEngine = nil
local Guard = nil

pcall(function()
    if isfile and readfile then
        ThemeEngine = loadstring(game:HttpGet("https://raw.githubusercontent.com/BorCaHub/BorcaHub/main/UIMAIN/COMPONENTS/CORE/THEME.lua"))()
        Guard       = loadstring(game:HttpGet("https://raw.githubusercontent.com/BorCaHub/BorcaHub/main/UIMAIN/COMPONENTS/CORE/GUARD.lua"))()
    end
end)

-- Fallback for testing environments without readfile
if not ThemeEngine then
    warn("[BorcaHub] ThemeEngine not found via readfile, attempting fallback")
    -- In a real environment, this would handle fallbacks. 
    -- We assume the loader will inject the tables directly if readfile fails.
    ThemeEngine = loadstring(game:HttpGet("https://raw.githubusercontent.com/BorCaHub/BorcaHub/main/UIMAIN/COMPONENTS/CORE/THEME.lua"))()
end
if not Guard then
    Guard = loadstring(game:HttpGet("https://raw.githubusercontent.com/BorCaHub/BorcaHub/main/UIMAIN/COMPONENTS/CORE/GUARD.lua"))()
end

local Themes = ThemeEngine.Themes
local ThemeOrder = ThemeEngine.ThemeOrder
local AccentPresets = ThemeEngine.AccentPresets

-- ====================================================================
--  SCREENGUI
-- ====================================================================

local ScreenGui

local function MountGui()
    -- Cek apakah ScreenGui BorcaHub sudah ada (cegah duplikat)
    local existing = nil
    pcall(function()
        existing = game:GetService("CoreGui"):FindFirstChild("BorcaHub")
    end)
    if not existing then
        pcall(function()
            existing = gethui() and gethui():FindFirstChild("BorcaHub")
        end)
    end
    if not existing then
        pcall(function()
            existing = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("BorcaHub")
        end)
    end
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

-- Cegah duplikat container toast
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
    Version        = "2.0.0",
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
        Text                 = "âœ•",
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
        Text                 = message or "Loadingâ€¦",
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
    local icon          = opt.Icon       or "â—ˆ"
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

    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    --  ROOT FRAME
    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    --  TITLEBAR
    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

    -- Glow removed due to executor bugs
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
        local rs = game:GetService("RunService")
        local frames = 0
        local lastTime = os.clock()
        rs.RenderStepped:Connect(function()
            frames = frames + 1
            if os.clock() - lastTime >= 1 then
                local t = os.date("*t")
                local hour = t.hour % 12
                if hour == 0 then hour = 12 end
                local ampm = t.hour >= 12 and "PM" or "AM"
                StatusInfo.Text = string.format("FPS: %d   |   %02d:%02d %s", frames, hour, t.min, ampm)
                frames = 0
                lastTime = os.clock()
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

    local CloseBtn = MakeCtrl("âœ•", Color3.fromRGB(58, 30, 30), Color3.fromRGB(212, 96, 96), 14)
    CloseBtn.MouseEnter:Connect(function()
        Tween(CloseBtn, { BackgroundColor3 = Color3.fromRGB(107, 32, 32) }, 0.12)
    end)
    CloseBtn.MouseLeave:Connect(function()
        Tween(CloseBtn, { BackgroundColor3 = Color3.fromRGB(58, 30, 30) }, 0.12)
    end)

    local MinBtn = MakeCtrl("â”€", Color3.fromRGB(58, 58, 42), Color3.fromRGB(200, 176, 96), 42)
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
        Text                 = "â˜°",
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

    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    --  BODY
    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    local Body = New("Frame", {
        Name                 = "Body",
        Parent               = WinFrame,
        BackgroundTransparency = 1,
        Position             = UDim2.new(0, 0, 0, 46),
        Size                 = UDim2.new(1, 0, 1, -46),
        ClipsDescendants     = true,
        ZIndex               = 11,
    })


    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    --  SIDEBAR
    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
        Text                 = "âœ¦ Free",  -- default Free, diubah oleh loader
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

    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    --  PAGE CONTAINER
    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    local PageContainer = New("Frame", {
        Name                 = "PageContainer",
        Parent               = Body,
        BackgroundTransparency = 1,
        Position             = UDim2.new(0, SIDEBAR_FULL + 1, 0, 0),
        Size                 = UDim2.new(1, -(SIDEBAR_FULL + 1), 1, 0),
        ClipsDescendants     = true,
        ZIndex               = 12,
    })

    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    --  WINDOW OBJECT
    -- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

    -- â”€â”€ SetUserInfo: dipanggil oleh loader untuk set nama & tier â”€â”€
    function Win:SetUserInfo(name, tier)
        self._userNameLbl.Text = name or LocalPlayer.Name
        if tier == "Premium" then
            self._userTierLbl.Text       = "âœ¦ Premium"
            self._userTierLbl.TextColor3 = T.Gold
        else
            self._userTierLbl.Text       = "âœ¦ Free"
            self._userTierLbl.TextColor3 = T.TextSub
        end
    end

    -- v3.0.0: change window title at runtime
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

    -- â”€â”€ DRAGGING â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

    -- â”€â”€ SIDEBAR TOGGLE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

    -- â”€â”€ MINIMIZE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

    -- â”€â”€ CLOSE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    CloseBtn.MouseButton1Click:Connect(function()
        Tween(WinFrame, { Size = UDim2.new(0, winSize.X.Offset, 0, 0) }, 0.22, Enum.EasingStyle.Quint)
        task.wait(0.24)
        WinFrame.Visible = false
        Win._visible = false
    end)

    -- â”€â”€ TOGGLE KEY â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

    -- â”€â”€ OPEN ANIMATION (v3.0.0 â€” spring scale + fade) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

        -- v3.0.0: programmatically switch to this tab
        function Tab:Select()
            NavBtn:GetPropertyChangedSignal("Visible"):Wait() -- flush
            task.spawn(function()
                NavBtn.MouseButton1Click:Fire()
            end)
            -- manual switch (safe path)
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
                    Text                 = collapsed and "âŒ„" or "âŒƒ",
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
                    CollapseArrow.Text = collapsed and "âŒ„" or "âŒƒ"
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
            --  SEPARATOR  (v3.0.0)
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
                    -- Size lines dynamically after layout resolves
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
            --  INFO TEXT BLOCK  (v3.0.0)
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
            --  PROGRESS BAR  (v3.0.0)
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
                    Text                 = "â€º",
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
            --  DROPDOWN  (single select)
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
                    Text                 = sel or "Selectâ€¦",
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
                    Text                 = "âŒ„",
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
                            ArrowLbl.Text = "âŒ„"
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
                        ArrowLbl.Text = "âŒƒ"
                    else
                        Tween(Menu, { Size = UDim2.new(1, 0, 0, 0) }, 0.15)
                        ArrowLbl.Text = "âŒ„"
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
                    Text                 = "âŒ„",
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
                            Text                 = checked and "âœ“" or "",
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
                        ArrowLbl.Text = "âŒƒ"
                    else
                        Tween(Menu, { Size = UDim2.new(1, 0, 0, 0) }, 0.15)
                        ArrowLbl.Text = "âŒ„"
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
                    PlaceholderText      = xOpt.Placeholder or "Typeâ€¦",
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

                local DecBtn = MakeNumBtn("âˆ’")
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
                    KeyLbl.Text       = "â€¦"
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
                    Text                 = tostring(sOpt.Value or "â€”"),
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
                        Text                 = tostring(item.Value or "â€”"),
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

            -- AddSeparator defined above (v3.0.0 enhanced version with label support)

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
                    Text                 = acOpt.AvatarIcon or "â—‰",
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
                    Text                 = acOpt.Tier or "âœ¦ Premium",
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
                    Text                 = "ðŸ”",
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
                    PlaceholderText      = srOpt.Placeholder or "Searchâ€¦",
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
                    Text                 = "â†º  Refresh",
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
--- @description Creates a real-time updating line chart component
function Sec:AddLineChart(chartOpt)
    chartOpt = chartOpt or {}
    local T = ThemeEngine.Themes[Library.Theme] or ThemeEngine.Themes.Dark
    local name = chartOpt.Name or "Line Chart"
    local data = chartOpt.Data or {0, 0, 0, 0, 0}
    
    local row = New("Frame", {
        Parent               = self.Body,
        BackgroundTransparency = 1,
        Size                 = UDim2.new(1, 0, 0, 180),
        ZIndex               = 17,
        LayoutOrder          = self._order,
    })
    self._order = self._order + 1
    
    local bg = New("Frame", {
        Parent           = row,
        BackgroundColor3 = T.Tertiary,
        Size             = UDim2.new(1, 0, 1, 0),
        ZIndex           = 17,
    })
    New("UICorner", { Parent = bg, CornerRadius = UDim.new(0, 7) })
    
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
    New("UICorner", { Parent = chartArea, CornerRadius = UDim.new(0, 6) })
    
    local points = {}
    local lines = {}
    
    local function redraw()
        for _, p in ipairs(points) do p:Destroy() end
        for _, l in ipairs(lines) do l:Destroy() end
        points = {}
        lines = {}
        
        if #data < 2 then return end
        
        local minVal, maxVal = math.huge, -math.huge
        for _, v in ipairs(data) do
            if v < minVal then minVal = v end
            if v > maxVal then maxVal = v end
        end
        if maxVal == minVal then maxVal = minVal + 1 end
        
        local width = chartArea.AbsoluteSize.X
        local height = chartArea.AbsoluteSize.Y
        local stepX = width / (#data - 1)
        
        local prevPoint = nil
        
        for i, v in ipairs(data) do
            local norm = (v - minVal) / (maxVal - minVal)
            local px = (i - 1) * stepX
            local py = height - (norm * height)
            
            local pt = New("Frame", {
                Parent = chartArea,
                BackgroundColor3 = T.Accent,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0, px, 0, py),
                Size = UDim2.new(0, 6, 0, 6),
                ZIndex = 20,
            })
            New("UICorner", { Parent = pt, CornerRadius = UDim.new(1, 0) })
            table.insert(points, pt)
            
            if prevPoint then
                local dist = math.sqrt((px - prevPoint.X)^2 + (py - prevPoint.Y)^2)
                local angle = math.deg(math.atan2(py - prevPoint.Y, px - prevPoint.X))
                
                local line = New("Frame", {
                    Parent = chartArea,
                    BackgroundColor3 = T.Accent,
                    BorderSizePixel = 0,
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.new(0, (px + prevPoint.X)/2, 0, (py + prevPoint.Y)/2),
                    Size = UDim2.new(0, dist, 0, 2),
                    Rotation = angle,
                    ZIndex = 19,
                })
                table.insert(lines, line)
            end
            prevPoint = {X = px, Y = py}
        end
    end
    
    chartArea:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        Guard.SafeCall(redraw)
    end)
    
    Guard.SafeCall(redraw)
    
    local chartObj = {}
    function chartObj:Update(newData)
        data = newData
        Guard.SafeCall(redraw)
    end
    
    return chartObj
end

-- ====================================================================
--  ADVANCED COMPONENTS: NODE EDITOR (BLUEPRINTS)
-- ====================================================================

--- @function Sec:AddNodeEditor
--- @description Creates a visual node-based logic editor workspace
function Sec:AddNodeEditor(nodeOpt)
    nodeOpt = nodeOpt or {}
    local T = ThemeEngine.Themes[Library.Theme] or ThemeEngine.Themes.Dark
    local name = nodeOpt.Name or "Node Editor"
    
    local row = New("Frame", {
        Parent               = self.Body,
        BackgroundTransparency = 1,
        Size                 = UDim2.new(1, 0, 0, 400),
        ZIndex               = 17,
        LayoutOrder          = self._order,
    })
    self._order = self._order + 1
    
    local bg = New("Frame", {
        Parent           = row,
        BackgroundColor3 = T.Tertiary,
        Size             = UDim2.new(1, 0, 1, 0),
        ZIndex           = 17,
    })
    New("UICorner", { Parent = bg, CornerRadius = UDim.new(0, 7) })
    
    local canvas = New("ScrollingFrame", {
        Parent = bg,
        BackgroundColor3 = T.Background,
        Position = UDim2.new(0, 2, 0, 2),
        Size = UDim2.new(1, -4, 1, -4),
        CanvasSize = UDim2.new(0, 2000, 0, 2000),
        ScrollBarThickness = 4,
        ZIndex = 18,
    })
    New("UICorner", { Parent = canvas, CornerRadius = UDim.new(0, 5) })
    
    -- Node Grid Pattern
    local grid = New("ImageLabel", {
        Parent = canvas,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Image = "rbxassetid://6553888365",
        ImageColor3 = T.Border,
        ImageTransparency = 0.5,
        ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.new(0, 40, 0, 40),
        ZIndex = 18,
    })
    
    local nodes = {}
    local connections = {}
    
    local function CreateNode(title, position)
        local node = New("Frame", {
            Parent = canvas,
            BackgroundColor3 = T.Secondary,
            Position = UDim2.new(0, position.X, 0, position.Y),
            Size = UDim2.new(0, 160, 0, 100),
            ZIndex = 25,
            Active = true,
            Draggable = true,
        })
        New("UICorner", { Parent = node, CornerRadius = UDim.new(0, 6) })
        New("UIStroke", { Parent = node, Color = T.BorderHover, Thickness = 1 })
        
        local header = New("Frame", {
            Parent = node,
            BackgroundColor3 = T.Accent,
            Size = UDim2.new(1, 0, 0, 24),
            ZIndex = 26,
        })
        New("UICorner", { Parent = header, CornerRadius = UDim.new(0, 6) })
        
        New("TextLabel", {
            Parent = header,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -10, 1, 0),
            Position = UDim2.new(0, 10, 0, 0),
            Text = title,
            TextColor3 = Color3.new(1,1,1),
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 27,
        })
        
        local inputPort = New("TextButton", {
            Parent = node,
            BackgroundColor3 = T.Background,
            Position = UDim2.new(0, -6, 0, 40),
            Size = UDim2.new(0, 12, 0, 12),
            Text = "",
            ZIndex = 28,
        })
        New("UICorner", { Parent = inputPort, CornerRadius = UDim.new(1, 0) })
        New("UIStroke", { Parent = inputPort, Color = T.Border, Thickness = 2 })
        
        local outputPort = New("TextButton", {
            Parent = node,
            BackgroundColor3 = T.Accent,
            Position = UDim2.new(1, -6, 0, 40),
            Size = UDim2.new(0, 12, 0, 12),
            Text = "",
            ZIndex = 28,
        })
        New("UICorner", { Parent = outputPort, CornerRadius = UDim.new(1, 0) })
        New("UIStroke", { Parent = outputPort, Color = T.Border, Thickness = 2 })
        
        table.insert(nodes, node)
        return {Node = node, Input = inputPort, Output = outputPort}
    end
    
    local nodeObj = {}
    function nodeObj:AddNode(title, pos)
        return CreateNode(title, pos)
    end
    
    -- Initialize with some default nodes
    CreateNode("Start Event", Vector2.new(50, 100))
    CreateNode("Math: Add", Vector2.new(300, 80))
    CreateNode("Print String", Vector2.new(550, 120))
    
    return nodeObj
end

-- ====================================================================
--  ADVANCED COMPONENTS: FILE TREE EXPLORER
-- ====================================================================

--- @function Sec:AddTreeView
--- @description Creates a collapsible, hierarchical file explorer view
function Sec:AddTreeView(treeOpt)
    treeOpt = treeOpt or {}
    local T = ThemeEngine.Themes[Library.Theme] or ThemeEngine.Themes.Dark
    local name = treeOpt.Name or "Explorer"
    local data = treeOpt.Data or {
        {Name = "Workspace", Type = "Folder", Children = {
            {Name = "Baseplate", Type = "Part"},
            {Name = "SpawnLocation", Type = "Part"},
        }},
        {Name = "Players", Type = "Folder", Children = {}},
    }
    
    local row = New("Frame", {
        Parent               = self.Body,
        BackgroundTransparency = 1,
        Size                 = UDim2.new(1, 0, 0, 240),
        ZIndex               = 17,
        LayoutOrder          = self._order,
    })
    self._order = self._order + 1
    
    local bg = New("Frame", {
        Parent           = row,
        BackgroundColor3 = T.Tertiary,
        Size             = UDim2.new(1, 0, 1, 0),
        ZIndex           = 17,
    })
    New("UICorner", { Parent = bg, CornerRadius = UDim.new(0, 7) })
    
    local scroller = New("ScrollingFrame", {
        Parent = bg,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 5, 0, 5),
        Size = UDim2.new(1, -10, 1, -10),
        ScrollBarThickness = 2,
        ZIndex = 18,
    })
    local layout = New("UIListLayout", {
        Parent = scroller,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
    })
    
    local function RenderItem(item, parentFrame, level)
        local itemBtn = New("TextButton", {
            Parent = parentFrame,
            BackgroundColor3 = T.Secondary,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 22),
            Text = "",
            ZIndex = 19,
        })
        
        local indent = level * 16
        local icon = item.Type == "Folder" and "ðŸ“" or "ðŸ“„"
        
        local lbl = New("TextLabel", {
            Parent = itemBtn,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, indent + 24, 0, 0),
            Size = UDim2.new(1, -(indent + 24), 1, 0),
            Text = item.Name,
            TextColor3 = T.Text,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 20,
        })
        
        local iconLbl = New("TextLabel", {
            Parent = itemBtn,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, indent + 4, 0, 0),
            Size = UDim2.new(0, 16, 1, 0),
            Text = icon,
            TextColor3 = T.Text,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            ZIndex = 20,
        })
        
        if item.Type == "Folder" and item.Children then
            local childrenFrame = New("Frame", {
                Parent = parentFrame,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Visible = false,
            })
            New("UIListLayout", {
                Parent = childrenFrame,
                SortOrder = Enum.SortOrder.LayoutOrder,
            })
            for _, child in ipairs(item.Children) do
                RenderItem(child, childrenFrame, level + 1)
            end
            
            Guard.Connect(itemBtn.MouseButton1Click, function()
                childrenFrame.Visible = not childrenFrame.Visible
                iconLbl.Text = childrenFrame.Visible and "ðŸ“‚" or "ðŸ“"
            end)
        end
    end
    
    for _, rootItem in ipairs(data) do
        RenderItem(rootItem, scroller, 0)
    end
end

return Library â€” TIDAK ada eksekusi standalone !!
--  Loader (Free.lua / Premium.lua) yang akan membuat window sendiri.
-- ====================================================================
-- ====================================================================
--  ADVANCED UI FEATURES (Premium Overhaul)
-- ====================================================================

-- â”€â”€ 1. HIGH-PERFORMANCE PARTICLE SYSTEM â”€â”€
local ParticleSystem = {}
ParticleSystem.__index = ParticleSystem
function ParticleSystem.new(parent, config)
    local self = setmetatable({}, ParticleSystem)
    self.Parent = parent
    self.Config = config or {}
    self.Particles = {}
    self.Amount = self.Config.Amount or 40
    self.Running = true
    
    for i = 1, self.Amount do
        local p = Instance.new("Frame")
        p.BackgroundColor3 = self.Config.Color or Color3.fromRGB(255,255,255)
        p.BackgroundTransparency = math.random(30, 80) / 100
        p.BorderSizePixel = 0
        local size = math.random(2, 6)
        p.Size = UDim2.new(0, size, 0, size)
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = p
        
        p.Position = UDim2.new(math.random(), 0, math.random(), 0)
        p.Parent = self.Parent
        
        table.insert(self.Particles, {
            Gui = p,
            SpeedX = (math.random() - 0.5) * 0.001,
            SpeedY = (math.random() - 0.5) * 0.001,
            OriginX = p.Position.X.Scale,
            OriginY = p.Position.Y.Scale
        })
    end
    
    task.spawn(function()
        local rs = game:GetService("RunService")
        while self.Running and self.Parent.Parent do
            for _, data in ipairs(self.Particles) do
                data.OriginX = data.OriginX + data.SpeedX
                data.OriginY = data.OriginY + data.SpeedY
                
                if data.OriginX > 1 then data.OriginX = 0 elseif data.OriginX < 0 then data.OriginX = 1 end
                if data.OriginY > 1 then data.OriginY = 0 elseif data.OriginY < 0 then data.OriginY = 1 end
                
                data.Gui.Position = UDim2.new(data.OriginX, 0, data.OriginY, 0)
            end
            rs.RenderStepped:Wait()
        end
    end)
    return self
end

function Library:AddAnimatedBackground(Container, T)
    local BgWrapper = Instance.new("Frame")
    BgWrapper.Name = "AnimatedBg"
    BgWrapper.Parent = Container
    BgWrapper.BackgroundTransparency = 1
    BgWrapper.Size = UDim2.new(1, 0, 1, 0)
    BgWrapper.ZIndex = Container.ZIndex - 2
    BgWrapper.ClipsDescendants = true
    
    local Grid = Instance.new("ImageLabel")
    Grid.Parent = BgWrapper
    Grid.BackgroundTransparency = 1
    Grid.Size = UDim2.new(2, 0, 2, 0)
    Grid.Position = UDim2.new(0, 0, 0, 0)
    Grid.Image = "rbxassetid://6553888365"
    Grid.ImageColor3 = T.BorderHover
    Grid.ImageTransparency = 0.85
    Grid.ScaleType = Enum.ScaleType.Tile
    Grid.TileSize = UDim2.new(0, 50, 0, 50)
    Grid.ZIndex = BgWrapper.ZIndex
    
    task.spawn(function()
        local ts = game:GetService("TweenService")
        while Grid.Parent do
            local tween = ts:Create(Grid, TweenInfo.new(3, Enum.EasingStyle.Linear), {Position = UDim2.new(0, -50, 0, -50)})
            tween:Play()
            tween.Completed:Wait()
            Grid.Position = UDim2.new(0, 0, 0, 0)
        end
    end)
    
    ParticleSystem.new(BgWrapper, {
        Amount = 60,
        Color = T.Accent
    })
end

function Library:AddAmbientLighting(WinFrame, T)
    local GlowLayer = Instance.new("Frame")
    GlowLayer.Name = "AmbientLayer"
    GlowLayer.Parent = WinFrame
    GlowLayer.BackgroundTransparency = 1
    GlowLayer.Size = UDim2.new(1, 0, 1, 0)
    GlowLayer.ZIndex = WinFrame.ZIndex - 1
    GlowLayer.ClipsDescendants = false
    
    local corners = {
        { Pos = UDim2.new(0, 0, 0, 0), Anchor = Vector2.new(0.5, 0.5) },
        { Pos = UDim2.new(1, 0, 0, 0), Anchor = Vector2.new(0.5, 0.5) },
        { Pos = UDim2.new(0, 0, 1, 0), Anchor = Vector2.new(0.5, 0.5) },
        { Pos = UDim2.new(1, 0, 1, 0), Anchor = Vector2.new(0.5, 0.5) },
    }
    
    local lights = {}
    for _, cfg in ipairs(corners) do
        local light = Instance.new("ImageLabel")
        light.Parent = GlowLayer
        light.BackgroundTransparency = 1
        light.Position = cfg.Pos
        light.AnchorPoint = cfg.Anchor
        light.Size = UDim2.new(0, 300, 0, 300)
        light.Image = "rbxassetid://6015897843"
        light.ImageColor3 = T.Accent
        light.ImageTransparency = 0.7
        light.ZIndex = GlowLayer.ZIndex
        table.insert(lights, light)
    end
    
    local rs = game:GetService("RunService")
    local uis = game:GetService("UserInputService")
    local ts = game:GetService("TweenService")
    
    task.spawn(function()
        local t = 0
        while GlowLayer.Parent do
            t = t + 0.03
            local pulse = math.sin(t) * 20
            local transPulse = math.sin(t) * 0.1
            
            local mouse = uis:GetMouseLocation()
            local relX = (mouse.X - WinFrame.AbsolutePosition.X) / WinFrame.AbsoluteSize.X
            local relY = (mouse.Y - WinFrame.AbsolutePosition.Y) / WinFrame.AbsoluteSize.Y
            
            for i, light in ipairs(lights) do
                light.Size = UDim2.new(0, 300 + pulse, 0, 300 + pulse)
                light.ImageTransparency = 0.65 + transPulse
                light.ImageColor3 = Library.Theme.Accent 
                
                local def = corners[i].Pos
                local shiftX = (relX - 0.5) * 60
                local shiftY = (relY - 0.5) * 60
                
                ts:Create(light, TweenInfo.new(0.1), {
                    Position = UDim2.new(def.X.Scale, def.X.Offset + shiftX, def.Y.Scale, def.Y.Offset + shiftY)
                }):Play()
            end
            rs.RenderStepped:Wait()
        end
    end)
end

function Library:CreateSpotlight(TargetFrame)
    local Spotlight = Instance.new("ImageLabel")
    Spotlight.Name = "CursorSpotlight"
    Spotlight.Parent = TargetFrame
    Spotlight.BackgroundTransparency = 1
    Spotlight.Size = UDim2.new(0, 400, 0, 400)
    Spotlight.AnchorPoint = Vector2.new(0.5, 0.5)
    Spotlight.Image = "rbxassetid://4996891970"
    Spotlight.ImageColor3 = Color3.fromRGB(255, 255, 255)
    Spotlight.ImageTransparency = 0.95
    Spotlight.ZIndex = 999
    Spotlight.Visible = false
    
    local uis = game:GetService("UserInputService")
    local rs = game:GetService("RunService")
    local ts = game:GetService("TweenService")
    
    TargetFrame.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseMovement then
            Spotlight.Visible = true
            ts:Create(Spotlight, TweenInfo.new(0.3), {ImageTransparency = 0.85}):Play()
        end
    end)
    TargetFrame.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseMovement then
            ts:Create(Spotlight, TweenInfo.new(0.3), {ImageTransparency = 1}):Play()
            task.delay(0.3, function() Spotlight.Visible = false end)
        end
    end)
    
    rs.RenderStepped:Connect(function()
        if Spotlight.Visible then
            local mp = uis:GetMouseLocation()
            ts:Create(Spotlight, TweenInfo.new(0.05), {
                Position = UDim2.new(0, mp.X - TargetFrame.AbsolutePosition.X, 0, mp.Y - TargetFrame.AbsolutePosition.Y)
            }):Play()
        end
    end)
end

-- ====================================================================
--  MODULE 1: WINDOW MANAGER SYSTEM (Docking, Snapping, Resizing, Taskbar)
-- ====================================================================

Library._WindowManager = {
    Windows       = {},
    FocusedWin    = nil,
    MaxZIndex     = 100,
    SnapThreshold = 30,
    MinWinWidth   = 200,
    MinWinHeight  = 150,
    Taskbar       = nil,
    SnapPreview   = nil,
}

local WM = Library._WindowManager

-- â”€â”€ Snap Preview Overlay â”€â”€
function WM:CreateSnapPreview()
    if self.SnapPreview then return end
    self.SnapPreview = New("Frame", {
        Name                   = "BH_SnapPreview",
        Parent                 = ScreenGui,
        BackgroundColor3       = Library.Theme.Accent,
        BackgroundTransparency = 0.7,
        Visible                = false,
        ZIndex                 = 9999,
        BorderSizePixel        = 0,
    })
    Corner(self.SnapPreview, 8)
    Stroke(self.SnapPreview, Library.Theme.Accent, 2)
end

-- â”€â”€ Determine Snap Zone â”€â”€
function WM:GetSnapZone(absX, absY)
    local vpSize = workspace.CurrentCamera.ViewportSize
    local T = self.SnapThreshold
    local w, h = vpSize.X, vpSize.Y
    local halfW, halfH = w * 0.5, h * 0.5

    if absX < T and absY < T then
        return "TopLeft", UDim2.new(0, 4, 0, 4), UDim2.new(0.5, -6, 0.5, -6)
    elseif absX > w - T and absY < T then
        return "TopRight", UDim2.new(0.5, 2, 0, 4), UDim2.new(0.5, -6, 0.5, -6)
    elseif absX < T and absY > h - T then
        return "BottomLeft", UDim2.new(0, 4, 0.5, 2), UDim2.new(0.5, -6, 0.5, -6)
    elseif absX > w - T and absY > h - T then
        return "BottomRight", UDim2.new(0.5, 2, 0.5, 2), UDim2.new(0.5, -6, 0.5, -6)
    elseif absX < T then
        return "Left", UDim2.new(0, 4, 0, 4), UDim2.new(0.5, -6, 1, -8)
    elseif absX > w - T then
        return "Right", UDim2.new(0.5, 2, 0, 4), UDim2.new(0.5, -6, 1, -8)
    elseif absY < T then
        return "Top", UDim2.new(0, 4, 0, 4), UDim2.new(1, -8, 0.5, -6)
    elseif absY > h - T then
        return "Bottom", UDim2.new(0, 4, 0.5, 2), UDim2.new(1, -8, 0.5, -6)
    end
    return nil, nil, nil
end

-- â”€â”€ Show / Hide Snap Preview â”€â”€
function WM:ShowSnapPreview(zone, pos, size)
    if not self.SnapPreview then self:CreateSnapPreview() end
    self.SnapPreview.Position = pos
    self.SnapPreview.Size = size
    self.SnapPreview.Visible = true
    self.SnapPreview.BackgroundColor3 = Library.Theme.Accent
    local sk = self.SnapPreview:FindFirstChildOfClass("UIStroke")
    if sk then sk.Color = Library.Theme.Accent end
    Tween(self.SnapPreview, {BackgroundTransparency = 0.7}, 0.15)
end

function WM:HideSnapPreview()
    if self.SnapPreview then
        self.SnapPreview.Visible = false
    end
end

-- â”€â”€ Apply Snap â”€â”€
function WM:ApplySnap(winFrame, zone, pos, size)
    if not zone then return false end
    winFrame:SetAttribute("PreSnapPos", tostring(winFrame.Position))
    winFrame:SetAttribute("PreSnapSize", tostring(winFrame.Size))
    winFrame:SetAttribute("Snapped", true)
    Tween(winFrame, {Position = pos, Size = size}, 0.25, Enum.EasingStyle.Quint)
    return true
end

-- â”€â”€ Restore from Snap â”€â”€
function WM:RestoreFromSnap(winFrame)
    if winFrame:GetAttribute("Snapped") then
        winFrame:SetAttribute("Snapped", false)
        local oldSize = winFrame:GetAttribute("PreSnapSize")
        if oldSize then
            Tween(winFrame, {Size = UDim2.new(0, 820, 0, 560)}, 0.2, Enum.EasingStyle.Quint)
        end
    end
end

-- â”€â”€ Register Window with Manager â”€â”€
function WM:Register(winFrame, winTitle, winIcon)
    local entry = {
        Frame    = winFrame,
        Title    = winTitle or "Window",
        Icon     = winIcon or "â—ˆ",
        ZIndex   = self.MaxZIndex,
        Minimized = false,
        Maximized = false,
        OrigPos  = winFrame.Position,
        OrigSize = winFrame.Size,
    }
    table.insert(self.Windows, entry)
    self.MaxZIndex = self.MaxZIndex + 10

    winFrame.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            self:Focus(entry)
        end
    end)

    if self.Taskbar then
        self:AddTaskbarIcon(entry)
    end
    return entry
end

-- â”€â”€ Focus a Window â”€â”€
function WM:Focus(entry)
    if self.FocusedWin == entry then return end
    self.MaxZIndex = self.MaxZIndex + 10
    entry.ZIndex = self.MaxZIndex
    entry.Frame.ZIndex = self.MaxZIndex

    for _, child in ipairs(entry.Frame:GetDescendants()) do
        if child:IsA("GuiObject") then
            pcall(function()
                child.ZIndex = child.ZIndex + 1
            end)
        end
    end

    if self.FocusedWin then
        local oldStroke = self.FocusedWin.Frame:FindFirstChildOfClass("UIStroke")
        if oldStroke then
            Tween(oldStroke, {Color = Library.Theme.Border}, 0.1)
        end
    end

    local newStroke = entry.Frame:FindFirstChildOfClass("UIStroke")
    if newStroke then
        Tween(newStroke, {Color = Library.Theme.Accent}, 0.1)
    end

    self.FocusedWin = entry
end

-- â”€â”€ Minimize / Restore â”€â”€
function WM:Minimize(entry)
    entry.Minimized = true
    entry.OrigPos = entry.Frame.Position
    entry.OrigSize = entry.Frame.Size

    if self.Taskbar then
        local iconEntry = self:FindTaskbarIcon(entry)
        if iconEntry then
            local targetPos = UDim2.new(
                0, iconEntry.AbsolutePosition.X,
                1, -50
            )
            Tween(entry.Frame, {
                Size = UDim2.new(0, 46, 0, 46),
                Position = targetPos,
            }, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In)
            task.delay(0.36, function()
                entry.Frame.Visible = false
            end)
        else
            entry.Frame.Visible = false
        end
    else
        Tween(entry.Frame, {Size = UDim2.new(0, 46, 0, 46)}, 0.25, Enum.EasingStyle.Quint)
        task.delay(0.26, function()
            entry.Frame.Visible = false
        end)
    end
end

function WM:Restore(entry)
    entry.Frame.Visible = true
    entry.Minimized = false
    Tween(entry.Frame, {
        Position = entry.OrigPos,
        Size = entry.OrigSize,
    }, 0.3, Enum.EasingStyle.Quint)
    self:Focus(entry)
end

-- â”€â”€ Maximize / Unmaximize â”€â”€
function WM:Maximize(entry)
    if entry.Maximized then
        entry.Maximized = false
        Tween(entry.Frame, {
            Position = entry.OrigPos,
            Size = entry.OrigSize,
        }, 0.25, Enum.EasingStyle.Quint)
    else
        entry.Maximized = true
        entry.OrigPos = entry.Frame.Position
        entry.OrigSize = entry.Frame.Size
        Tween(entry.Frame, {
            Position = UDim2.new(0, 4, 0, 4),
            Size = UDim2.new(1, -8, 1, -58),
        }, 0.25, Enum.EasingStyle.Quint)
    end
end

-- â”€â”€ Resize Handles â”€â”€
function WM:AddResizeHandles(winFrame)
    local handleSize = 6
    local handles = {}

    local dirs = {
        {Name="Top",    Pos=UDim2.new(0,handleSize,0,0),         Size=UDim2.new(1,-handleSize*2,0,handleSize),   CurX=0, CurY=-1},
        {Name="Bottom", Pos=UDim2.new(0,handleSize,1,-handleSize),Size=UDim2.new(1,-handleSize*2,0,handleSize),  CurX=0, CurY=1},
        {Name="Left",   Pos=UDim2.new(0,0,0,handleSize),         Size=UDim2.new(0,handleSize,1,-handleSize*2),   CurX=-1,CurY=0},
        {Name="Right",  Pos=UDim2.new(1,-handleSize,0,handleSize),Size=UDim2.new(0,handleSize,1,-handleSize*2),  CurX=1, CurY=0},
        {Name="TL",     Pos=UDim2.new(0,0,0,0),                   Size=UDim2.new(0,handleSize,0,handleSize),     CurX=-1,CurY=-1},
        {Name="TR",     Pos=UDim2.new(1,-handleSize,0,0),         Size=UDim2.new(0,handleSize,0,handleSize),     CurX=1, CurY=-1},
        {Name="BL",     Pos=UDim2.new(0,0,1,-handleSize),         Size=UDim2.new(0,handleSize,0,handleSize),     CurX=-1,CurY=1},
        {Name="BR",     Pos=UDim2.new(1,-handleSize,1,-handleSize),Size=UDim2.new(0,handleSize,0,handleSize),    CurX=1, CurY=1},
    }

    for _, d in ipairs(dirs) do
        local handle = New("Frame", {
            Name                   = "ResizeHandle_" .. d.Name,
            Parent                 = winFrame,
            BackgroundTransparency = 1,
            Position               = d.Pos,
            Size                   = d.Size,
            ZIndex                 = winFrame.ZIndex + 100,
        })

        handle.MouseEnter:Connect(function()
            handle.BackgroundTransparency = 0.85
            handle.BackgroundColor3 = Library.Theme.Accent
        end)
        handle.MouseLeave:Connect(function()
            handle.BackgroundTransparency = 1
        end)

        local dragging = false
        local startPos, startSize, startMouse

        handle.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                startPos = winFrame.Position
                startSize = winFrame.Size
                startMouse = UserInputService:GetMouseLocation()
            end
        end)

        UserInputService.InputChanged:Connect(function(inp)
            if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
                local mouse = UserInputService:GetMouseLocation()
                local dx = mouse.X - startMouse.X
                local dy = mouse.Y - startMouse.Y

                local newW = startSize.X.Offset
                local newH = startSize.Y.Offset
                local newX = startPos.X.Offset
                local newY = startPos.Y.Offset

                if d.CurX == 1 then
                    newW = math.max(self.MinWinWidth, startSize.X.Offset + dx)
                elseif d.CurX == -1 then
                    local delta = math.min(dx, startSize.X.Offset - self.MinWinWidth)
                    newX = startPos.X.Offset + delta
                    newW = startSize.X.Offset - delta
                end

                if d.CurY == 1 then
                    newH = math.max(self.MinWinHeight, startSize.Y.Offset + dy)
                elseif d.CurY == -1 then
                    local delta = math.min(dy, startSize.Y.Offset - self.MinWinHeight)
                    newY = startPos.Y.Offset + delta
                    newH = startSize.Y.Offset - delta
                end

                winFrame.Size = UDim2.new(startSize.X.Scale, newW, startSize.Y.Scale, newH)
                winFrame.Position = UDim2.new(startPos.X.Scale, newX, startPos.Y.Scale, newY)
            end
        end)

        UserInputService.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)

        table.insert(handles, handle)
    end
    return handles
end

-- â”€â”€ Taskbar / Dock Bar â”€â”€
function Library:CreateTaskbar()
    local T = self.Theme
    local taskbar = New("Frame", {
        Name             = "BH_Taskbar",
        Parent           = ScreenGui,
        BackgroundColor3 = T.Secondary,
        AnchorPoint      = Vector2.new(0.5, 1),
        Position         = UDim2.new(0.5, 0, 1, -8),
        Size             = UDim2.new(0, 400, 0, 50),
        ZIndex           = 9990,
        ClipsDescendants = false,
    })
    Corner(taskbar, 12)
    Stroke(taskbar, T.Border, 1)

    local taskbarInner = New("Frame", {
        Parent                 = taskbar,
        BackgroundTransparency = 1,
        Size                   = UDim2.new(1, 0, 1, 0),
        ZIndex                 = 9991,
    })
    Pad(taskbarInner, 6, 10, 6, 10)
    New("UIListLayout", {
        Parent              = taskbarInner,
        FillDirection       = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment   = Enum.VerticalAlignment.Center,
        Padding             = UDim.new(0, 8),
        SortOrder           = Enum.SortOrder.LayoutOrder,
    })

    -- Shadow under taskbar
    New("ImageLabel", {
        Parent                 = taskbar,
        BackgroundTransparency = 1,
        Position               = UDim2.new(0, -15, 0, -15),
        Size                   = UDim2.new(1, 30, 1, 30),
        ZIndex                 = 9989,
        Image                  = "rbxassetid://6015897843",
        ImageColor3            = Color3.new(0, 0, 0),
        ImageTransparency      = 0.5,
        ScaleType              = Enum.ScaleType.Slice,
        SliceCenter            = Rect.new(49, 49, 450, 450),
    })

    -- Auto-hide logic
    local autoHideEnabled = true
    local taskbarVisible = true

    if autoHideEnabled then
        task.spawn(function()
            while taskbar.Parent do
                local mouse = UserInputService:GetMouseLocation()
                local vpH = workspace.CurrentCamera.ViewportSize.Y
                if mouse.Y > vpH - 70 then
                    if not taskbarVisible then
                        taskbarVisible = true
                        Tween(taskbar, {Position = UDim2.new(0.5, 0, 1, -8)}, 0.3, Enum.EasingStyle.Quint)
                    end
                else
                    if taskbarVisible then
                        taskbarVisible = false
                        Tween(taskbar, {Position = UDim2.new(0.5, 0, 1, 60)}, 0.3, Enum.EasingStyle.Quint)
                    end
                end
                RunService.RenderStepped:Wait()
            end
        end)
    end

    -- Magnification effect
    task.spawn(function()
        while taskbar.Parent do
            local mouse = UserInputService:GetMouseLocation()
            for _, icon in ipairs(taskbarInner:GetChildren()) do
                if icon:IsA("Frame") or icon:IsA("TextButton") then
                    local center = icon.AbsolutePosition + icon.AbsoluteSize * 0.5
                    local dist = math.abs(mouse.X - center.X)
                    local maxDist = 120
                    local scale = 1 + math.max(0, (1 - dist / maxDist)) * 0.4
                    local targetSize = UDim2.new(0, 36 * scale, 0, 36 * scale)
                    icon.Size = targetSize
                end
            end
            RunService.RenderStepped:Wait()
        end
    end)

    WM.Taskbar = taskbar
    WM.TaskbarInner = taskbarInner
    return taskbar
end

-- â”€â”€ Add Icon to Taskbar â”€â”€
function WM:AddTaskbarIcon(entry)
    if not self.TaskbarInner then return end
    local T = Library.Theme
    local icon = New("TextButton", {
        Name             = "TBIcon_" .. entry.Title,
        Parent           = self.TaskbarInner,
        BackgroundColor3 = T.Tertiary,
        Size             = UDim2.new(0, 36, 0, 36),
        Text             = entry.Icon,
        TextColor3       = T.Text,
        TextSize         = 16,
        Font             = Enum.Font.GothamBold,
        ZIndex           = 9992,
        AutoButtonColor  = false,
    })
    Corner(icon, 8)

    local dot = New("Frame", {
        Parent           = icon,
        BackgroundColor3 = T.Accent,
        AnchorPoint      = Vector2.new(0.5, 1),
        Position         = UDim2.new(0.5, 0, 1, 3),
        Size             = UDim2.new(0, 5, 0, 5),
        ZIndex           = 9993,
    })
    Corner(dot, 9999)

    icon.MouseButton1Click:Connect(function()
        if entry.Minimized then
            self:Restore(entry)
        else
            self:Focus(entry)
        end
    end)

    icon.MouseButton2Click:Connect(function()
        self:ShowTaskbarContextMenu(entry, icon)
    end)

    entry._taskbarIcon = icon
end

function WM:FindTaskbarIcon(entry)
    return entry._taskbarIcon
end

-- â”€â”€ Taskbar Context Menu â”€â”€
function WM:ShowTaskbarContextMenu(entry, anchor)
    local T = Library.Theme
    local existing = ScreenGui:FindFirstChild("BH_TaskCtx")
    if existing then existing:Destroy() end

    local menu = New("Frame", {
        Name             = "BH_TaskCtx",
        Parent           = ScreenGui,
        BackgroundColor3 = T.Secondary,
        Position         = UDim2.new(0, anchor.AbsolutePosition.X, 0, anchor.AbsolutePosition.Y - 100),
        Size             = UDim2.new(0, 140, 0, 0),
        AutomaticSize    = Enum.AutomaticSize.Y,
        ZIndex           = 99999,
        ClipsDescendants = true,
    })
    Corner(menu, 8)
    Stroke(menu, T.Border, 1)
    Pad(menu, 4, 4, 4, 4)
    New("UIListLayout", {
        Parent    = menu,
        Padding   = UDim.new(0, 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })

    local items = {
        {Text = "Focus",    Fn = function() self:Focus(entry) end},
        {Text = "Minimize", Fn = function() self:Minimize(entry) end},
        {Text = "Maximize", Fn = function() self:Maximize(entry) end},
        {Text = "Close",    Fn = function() entry.Frame:Destroy() end},
    }

    for idx, item in ipairs(items) do
        local btn = New("TextButton", {
            Parent           = menu,
            BackgroundColor3 = T.Tertiary,
            BackgroundTransparency = 1,
            Size             = UDim2.new(1, 0, 0, 26),
            Text             = item.Text,
            TextColor3       = T.Text,
            TextSize         = 12,
            Font             = Enum.Font.Gotham,
            ZIndex           = 99999,
            AutoButtonColor  = false,
            LayoutOrder      = idx,
        })
        Corner(btn, 4)
        btn.MouseEnter:Connect(function()
            Tween(btn, {BackgroundTransparency = 0, BackgroundColor3 = T.Accent}, 0.1)
        end)
        btn.MouseLeave:Connect(function()
            Tween(btn, {BackgroundTransparency = 1}, 0.1)
        end)
        btn.MouseButton1Click:Connect(function()
            menu:Destroy()
            item.Fn()
        end)
    end

    task.delay(3, function()
        if menu.Parent then menu:Destroy() end
    end)
end

-- â”€â”€ Split Screen â”€â”€
function Library:SplitWindows(entry1, entry2, direction)
    local vpSize = workspace.CurrentCamera.ViewportSize
    direction = direction or "horizontal"

    if direction == "horizontal" then
        Tween(entry1.Frame, {
            Position = UDim2.new(0, 4, 0, 4),
            Size = UDim2.new(0, vpSize.X * 0.5 - 8, 0, vpSize.Y - 58),
        }, 0.3, Enum.EasingStyle.Quint)
        Tween(entry2.Frame, {
            Position = UDim2.new(0, vpSize.X * 0.5 + 4, 0, 4),
            Size = UDim2.new(0, vpSize.X * 0.5 - 8, 0, vpSize.Y - 58),
        }, 0.3, Enum.EasingStyle.Quint)
    else
        Tween(entry1.Frame, {
            Position = UDim2.new(0, 4, 0, 4),
            Size = UDim2.new(0, vpSize.X - 8, 0, vpSize.Y * 0.5 - 32),
        }, 0.3, Enum.EasingStyle.Quint)
        Tween(entry2.Frame, {
            Position = UDim2.new(0, 4, 0, vpSize.Y * 0.5 + 2),
            Size = UDim2.new(0, vpSize.X - 8, 0, vpSize.Y * 0.5 - 32),
        }, 0.3, Enum.EasingStyle.Quint)
    end

    -- Draggable Divider
    local divider = New("Frame", {
        Name                   = "BH_SplitDivider",
        Parent                 = ScreenGui,
        BackgroundColor3       = Library.Theme.Accent,
        BackgroundTransparency = 0.5,
        ZIndex                 = 9998,
    })

    if direction == "horizontal" then
        divider.Position = UDim2.new(0, vpSize.X * 0.5 - 2, 0, 4)
        divider.Size = UDim2.new(0, 4, 0, vpSize.Y - 58)
    else
        divider.Position = UDim2.new(0, 4, 0, vpSize.Y * 0.5 - 2)
        divider.Size = UDim2.new(0, vpSize.X - 8, 0, 4)
    end
    Corner(divider, 2)

    local divDragging = false
    local divStart

    divider.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            divDragging = true
            divStart = UserInputService:GetMouseLocation()
        end
    end)

    UserInputService.InputChanged:Connect(function(inp)
        if divDragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local mouse = UserInputService:GetMouseLocation()
            if direction == "horizontal" then
                local ratio = math.clamp(mouse.X / vpSize.X, 0.2, 0.8)
                local splitX = vpSize.X * ratio
                divider.Position = UDim2.new(0, splitX - 2, 0, 4)
                entry1.Frame.Size = UDim2.new(0, splitX - 8, 0, vpSize.Y - 58)
                entry2.Frame.Position = UDim2.new(0, splitX + 4, 0, 4)
                entry2.Frame.Size = UDim2.new(0, vpSize.X - splitX - 8, 0, vpSize.Y - 58)
            else
                local ratio = math.clamp(mouse.Y / vpSize.Y, 0.2, 0.8)
                local splitY = vpSize.Y * ratio
                divider.Position = UDim2.new(0, 4, 0, splitY - 2)
                entry1.Frame.Size = UDim2.new(0, vpSize.X - 8, 0, splitY - 8)
                entry2.Frame.Position = UDim2.new(0, 4, 0, splitY + 4)
                entry2.Frame.Size = UDim2.new(0, vpSize.X - 8, 0, vpSize.Y - splitY - 32)
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            divDragging = false
        end
    end)
end

-- â”€â”€ Cascade Windows â”€â”€
function Library:CascadeWindows()
    local offsetX, offsetY = 30, 30
    for i, entry in ipairs(WM.Windows) do
        if not entry.Minimized then
            Tween(entry.Frame, {
                Position = UDim2.new(0, 50 + (i - 1) * offsetX, 0, 50 + (i - 1) * offsetY),
                Size = UDim2.new(0, 700, 0, 480),
            }, 0.3, Enum.EasingStyle.Quint)
        end
    end
end

-- â”€â”€ Tile Windows â”€â”€
function Library:TileWindows()
    local visible = {}
    for _, entry in ipairs(WM.Windows) do
        if not entry.Minimized and entry.Frame.Parent then
            table.insert(visible, entry)
        end
    end
    if #visible == 0 then return end

    local vpSize = workspace.CurrentCamera.ViewportSize
    local cols = math.ceil(math.sqrt(#visible))
    local rows = math.ceil(#visible / cols)
    local cellW = (vpSize.X - 8) / cols
    local cellH = (vpSize.Y - 60) / rows

    for idx, entry in ipairs(visible) do
        local col = (idx - 1) % cols
        local row = math.floor((idx - 1) / cols)
        Tween(entry.Frame, {
            Position = UDim2.new(0, 4 + col * cellW, 0, 4 + row * cellH),
            Size = UDim2.new(0, cellW - 4, 0, cellH - 4),
        }, 0.35, Enum.EasingStyle.Quint)
    end
end

-- â”€â”€ Ctrl+Tab Cycle â”€â”€
UserInputService.InputBegan:Connect(function(inp, processed)
    if processed then return end
    if inp.KeyCode == Enum.KeyCode.Tab and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        if #WM.Windows < 2 then return end
        local curIdx = 1
        for i, e in ipairs(WM.Windows) do
            if e == WM.FocusedWin then curIdx = i; break end
        end
        local nextIdx = curIdx % #WM.Windows + 1
        local nextEntry = WM.Windows[nextIdx]
        if nextEntry.Minimized then
            WM:Restore(nextEntry)
        end
        WM:Focus(nextEntry)
    end
end)

-- ====================================================================
--  MODULE 2: CODE EDITOR WITH SYNTAX HIGHLIGHTING
-- ====================================================================

local LuaKeywords = {
    ["local"]=true, ["function"]=true, ["end"]=true, ["if"]=true, ["then"]=true,
    ["else"]=true, ["elseif"]=true, ["for"]=true, ["while"]=true, ["do"]=true,
    ["repeat"]=true, ["until"]=true, ["return"]=true, ["break"]=true, ["continue"]=true,
    ["in"]=true, ["not"]=true, ["and"]=true, ["or"]=true, ["true"]=true, ["false"]=true,
    ["nil"]=true, ["self"]=true,
}

local LuaGlobals = {
    ["game"]=true, ["workspace"]=true, ["script"]=true, ["print"]=true, ["warn"]=true,
    ["error"]=true, ["pcall"]=true, ["xpcall"]=true, ["spawn"]=true, ["delay"]=true,
    ["wait"]=true, ["task"]=true, ["coroutine"]=true, ["math"]=true, ["string"]=true,
    ["table"]=true, ["Instance"]=true, ["Enum"]=true, ["Vector3"]=true, ["Vector2"]=true,
    ["CFrame"]=true, ["Color3"]=true, ["UDim2"]=true, ["UDim"]=true, ["BrickColor"]=true,
    ["Ray"]=true, ["Region3"]=true, ["TweenInfo"]=true, ["NumberSequence"]=true,
    ["ColorSequence"]=true, ["Rect"]=true, ["typeof"]=true, ["type"]=true,
    ["tostring"]=true, ["tonumber"]=true, ["pairs"]=true, ["ipairs"]=true,
    ["next"]=true, ["select"]=true, ["unpack"]=true, ["rawget"]=true, ["rawset"]=true,
    ["setmetatable"]=true, ["getmetatable"]=true, ["require"]=true, ["loadstring"]=true,
}

local SyntaxColors = {
    keyword    = "rgb(198,120,255)",
    string     = "rgb(152,224,118)",
    number     = "rgb(255,180,84)",
    comment    = "rgb(106,115,140)",
    global     = "rgb(102,217,239)",
    func_call  = "rgb(255,230,109)",
    operator   = "rgb(249,38,114)",
    default    = "rgb(220,224,240)",
}

-- â”€â”€ Lua Lexer / Tokenizer â”€â”€
local function LuaTokenize(source)
    local tokens = {}
    local i = 1
    local len = #source

    local function peek(offset)
        return source:sub(i + (offset or 0), i + (offset or 0))
    end

    local function advance(n)
        i = i + (n or 1)
    end

    local function isAlpha(c)
        return c:match("[%a_]") ~= nil
    end

    local function isDigit(c)
        return c:match("%d") ~= nil
    end

    local function isAlNum(c)
        return c:match("[%w_]") ~= nil
    end

    while i <= len do
        local c = peek()

        -- Whitespace
        if c:match("%s") then
            local start = i
            while i <= len and peek():match("%s") do advance() end
            table.insert(tokens, {type="whitespace", value=source:sub(start, i-1)})

        -- Single-line comment
        elseif c == "-" and peek(1) == "-" then
            if peek(2) == "[" and peek(3) == "[" then
                -- Multi-line comment
                local start = i
                advance(4)
                while i <= len do
                    if peek() == "]" and peek(1) == "]" then
                        advance(2)
                        break
                    end
                    advance()
                end
                table.insert(tokens, {type="comment", value=source:sub(start, i-1)})
            else
                local start = i
                while i <= len and peek() ~= "\n" do advance() end
                table.insert(tokens, {type="comment", value=source:sub(start, i-1)})
            end

        -- Strings (double quote)
        elseif c == '"' then
            local start = i
            advance()
            while i <= len do
                local ch = peek()
                if ch == "\\" then
                    advance(2)
                elseif ch == '"' then
                    advance()
                    break
                elseif ch == "\n" then
                    break
                else
                    advance()
                end
            end
            table.insert(tokens, {type="string", value=source:sub(start, i-1)})

        -- Strings (single quote)
        elseif c == "'" then
            local start = i
            advance()
            while i <= len do
                local ch = peek()
                if ch == "\\" then
                    advance(2)
                elseif ch == "'" then
                    advance()
                    break
                elseif ch == "\n" then
                    break
                else
                    advance()
                end
            end
            table.insert(tokens, {type="string", value=source:sub(start, i-1)})

        -- Multi-line strings
        elseif c == "[" and (peek(1) == "[" or peek(1) == "=") then
            local eqCount = 0
            local j = i + 1
            while j <= len and source:sub(j, j) == "=" do
                eqCount = eqCount + 1
                j = j + 1
            end
            if j <= len and source:sub(j, j) == "[" then
                local start = i
                local closing = "]" .. string.rep("=", eqCount) .. "]"
                i = j + 1
                while i <= len do
                    local found = source:find(closing, i, true)
                    if found then
                        i = found + #closing
                        break
                    end
                    advance()
                end
                table.insert(tokens, {type="string", value=source:sub(start, i-1)})
            else
                table.insert(tokens, {type="operator", value=c})
                advance()
            end

        -- Numbers
        elseif isDigit(c) or (c == "." and isDigit(peek(1) or "")) then
            local start = i
            if c == "0" and (peek(1) == "x" or peek(1) == "X") then
                advance(2)
                while i <= len and peek():match("[%da-fA-F]") do advance() end
            else
                while i <= len and (isDigit(peek()) or peek() == ".") do advance() end
                if peek() == "e" or peek() == "E" then
                    advance()
                    if peek() == "+" or peek() == "-" then advance() end
                    while i <= len and isDigit(peek()) do advance() end
                end
            end
            table.insert(tokens, {type="number", value=source:sub(start, i-1)})

        -- Identifiers / Keywords / Globals
        elseif isAlpha(c) then
            local start = i
            while i <= len and isAlNum(peek()) do advance() end
            local word = source:sub(start, i-1)
            if LuaKeywords[word] then
                table.insert(tokens, {type="keyword", value=word})
            elseif LuaGlobals[word] then
                table.insert(tokens, {type="global", value=word})
            else
                -- Check if followed by ( for function call
                local nextNonSpace = i
                while nextNonSpace <= len and source:sub(nextNonSpace, nextNonSpace):match("%s") do
                    nextNonSpace = nextNonSpace + 1
                end
                if nextNonSpace <= len and source:sub(nextNonSpace, nextNonSpace) == "(" then
                    table.insert(tokens, {type="func_call", value=word})
                else
                    table.insert(tokens, {type="identifier", value=word})
                end
            end

        -- Operators
        elseif c:match("[%(%)%{%}%[%]%;%,%+%-%*/%^%%#=<>~%.%:]") then
            table.insert(tokens, {type="operator", value=c})
            advance()

        else
            table.insert(tokens, {type="default", value=c})
            advance()
        end
    end

    return tokens
end

-- â”€â”€ Escape HTML for RichText â”€â”€
local function EscapeRichText(str)
    str = str:gsub("&", "&amp;")
    str = str:gsub("<", "&lt;")
    str = str:gsub(">", "&gt;")
    str = str:gsub('"', "&quot;")
    return str
end

-- â”€â”€ Tokenized Source to RichText â”€â”€
local function TokensToRichText(tokens)
    local parts = {}
    for _, tok in ipairs(tokens) do
        local escaped = EscapeRichText(tok.value)
        local color = SyntaxColors[tok.type] or SyntaxColors.default
        if tok.type == "whitespace" then
            table.insert(parts, escaped)
        else
            table.insert(parts, string.format('<font color="%s">%s</font>', color, escaped))
        end
    end
    return table.concat(parts)
end

-- â”€â”€ Undo/Redo Stack â”€â”€
local UndoRedoStack = {}
UndoRedoStack.__index = UndoRedoStack
function UndoRedoStack.new(maxSize)
    return setmetatable({
        stack = {},
        pointer = 0,
        maxSize = maxSize or 100,
    }, UndoRedoStack)
end

function UndoRedoStack:Push(state)
    -- Remove everything after current pointer
    while #self.stack > self.pointer do
        table.remove(self.stack)
    end
    table.insert(self.stack, state)
    if #self.stack > self.maxSize then
        table.remove(self.stack, 1)
    end
    self.pointer = #self.stack
end

function UndoRedoStack:Undo()
    if self.pointer > 1 then
        self.pointer = self.pointer - 1
        return self.stack[self.pointer]
    end
    return nil
end

function UndoRedoStack:Redo()
    if self.pointer < #self.stack then
        self.pointer = self.pointer + 1
        return self.stack[self.pointer]
    end
    return nil
end

-- â”€â”€ Autocompletion Database â”€â”€
local AutocompleteDB = {
    Services = {
        "Workspace", "Players", "Lighting", "ReplicatedStorage", "ServerStorage",
        "ServerScriptService", "StarterGui", "StarterPack", "StarterPlayer",
        "Teams", "SoundService", "Chat", "TweenService", "UserInputService",
        "RunService", "HttpService", "MarketplaceService", "DataStoreService",
        "PhysicsService", "PathfindingService", "TextService", "GroupService",
    },
    Methods = {
        "FindFirstChild", "WaitForChild", "GetChildren", "GetDescendants",
        "IsA", "Clone", "Destroy", "GetService", "GetPropertyChangedSignal",
        "Connect", "Disconnect", "Fire", "Wait", "Once",
        "TweenPosition", "TweenSize", "SetAttribute", "GetAttribute",
        "FindFirstChildOfClass", "FindFirstChildWhichIsA",
    },
    Properties = {
        "Parent", "Name", "Position", "Size", "Anchored", "CanCollide",
        "Transparency", "BrickColor", "Color", "Material", "Visible",
        "Text", "TextColor3", "BackgroundColor3", "BackgroundTransparency",
        "BorderSizePixel", "ZIndex", "LayoutOrder", "Font", "TextSize",
    },
}

function Library:CreateCodeEditor(opt)
    opt = opt or {}
    local T = self.Theme
    local parent = opt.Parent or ScreenGui
    local edSize = opt.Size or UDim2.new(0, 700, 0, 450)
    local edPos = opt.Position or UDim2.new(0.5, -350, 0.5, -225)
    local defaultCode = opt.DefaultCode or "-- BorcaHub Code Editor\nprint('Hello, World!')\n"
    local onRun = opt.OnRun
    local tabSize = opt.TabSize or 4

    local undoStack = UndoRedoStack.new(200)
    undoStack:Push(defaultCode)

    -- â”€â”€ Main Frame â”€â”€
    local EditorFrame = New("Frame", {
        Name             = "BH_CodeEditor",
        Parent           = parent,
        BackgroundColor3 = Color3.fromRGB(30, 30, 46),
        Position         = edPos,
        Size             = edSize,
        ZIndex           = 500,
        ClipsDescendants = true,
    })
    Corner(EditorFrame, 10)
    Stroke(EditorFrame, Color3.fromRGB(69, 71, 90), 1)

    -- â”€â”€ Toolbar â”€â”€
    local Toolbar = New("Frame", {
        Parent           = EditorFrame,
        BackgroundColor3 = Color3.fromRGB(24, 24, 37),
        Size             = UDim2.new(1, 0, 0, 34),
        ZIndex           = 501,
        BorderSizePixel  = 0,
    })
    Corner(Toolbar, 10)
    New("Frame", {
        Parent           = Toolbar,
        BackgroundColor3 = Color3.fromRGB(24, 24, 37),
        Position         = UDim2.new(0, 0, 0.5, 0),
        Size             = UDim2.new(1, 0, 0.5, 0),
        ZIndex           = 501,
        BorderSizePixel  = 0,
    })
    New("Frame", {
        Parent           = Toolbar,
        BackgroundColor3 = Color3.fromRGB(49, 50, 68),
        Position         = UDim2.new(0, 0, 1, -1),
        Size             = UDim2.new(1, 0, 0, 1),
        ZIndex           = 502,
        BorderSizePixel  = 0,
    })

    local toolbarLayout = New("Frame", {
        Parent                 = Toolbar,
        BackgroundTransparency = 1,
        Position               = UDim2.new(0, 8, 0, 0),
        Size                   = UDim2.new(1, -16, 1, 0),
        ZIndex                 = 502,
    })
    New("UIListLayout", {
        Parent              = toolbarLayout,
        FillDirection       = Enum.FillDirection.Horizontal,
        VerticalAlignment   = Enum.VerticalAlignment.Center,
        Padding             = UDim.new(0, 4),
        SortOrder           = Enum.SortOrder.LayoutOrder,
    })

    local function MakeToolBtn(text, layoutOrder, callback)
        local btn = New("TextButton", {
            Parent           = toolbarLayout,
            BackgroundColor3 = Color3.fromRGB(49, 50, 68),
            Size             = UDim2.new(0, 55, 0, 24),
            Text             = text,
            TextColor3       = Color3.fromRGB(205, 214, 244),
            TextSize         = 11,
            Font             = Enum.Font.GothamBold,
            ZIndex           = 503,
            AutoButtonColor  = false,
            LayoutOrder      = layoutOrder,
        })
        Corner(btn, 5)
        btn.MouseEnter:Connect(function()
            Tween(btn, {BackgroundColor3 = Color3.fromRGB(69, 71, 90)}, 0.1)
        end)
        btn.MouseLeave:Connect(function()
            Tween(btn, {BackgroundColor3 = Color3.fromRGB(49, 50, 68)}, 0.1)
        end)
        btn.MouseButton1Click:Connect(callback)
        return btn
    end

    -- â”€â”€ Body (Line Numbers + Code Area + Minimap) â”€â”€
    local Body = New("Frame", {
        Parent                 = EditorFrame,
        BackgroundTransparency = 1,
        Position               = UDim2.new(0, 0, 0, 34),
        Size                   = UDim2.new(1, 0, 1, -58),
        ZIndex                 = 501,
        ClipsDescendants       = true,
    })

    -- Line Numbers
    local LineNumScroll = New("ScrollingFrame", {
        Parent                     = Body,
        BackgroundColor3           = Color3.fromRGB(24, 24, 37),
        Size                       = UDim2.new(0, 45, 1, 0),
        ScrollBarThickness         = 0,
        ScrollingDirection         = Enum.ScrollingDirection.Y,
        CanvasSize                 = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize        = Enum.AutomaticSize.Y,
        ZIndex                     = 502,
        BorderSizePixel            = 0,
    })

    local LineNumLabel = New("TextLabel", {
        Parent               = LineNumScroll,
        BackgroundTransparency = 1,
        Size                 = UDim2.new(1, 0, 0, 0),
        AutomaticSize        = Enum.AutomaticSize.Y,
        Text                 = "1",
        TextColor3           = Color3.fromRGB(88, 91, 112),
        TextSize             = 14,
        Font                 = Enum.Font.Code,
        TextXAlignment       = Enum.TextXAlignment.Right,
        ZIndex               = 503,
        RichText             = false,
    })
    Pad(LineNumLabel, 4, 8, 4, 4)

    -- Code Container
    local CodeScroll = New("ScrollingFrame", {
        Parent                     = Body,
        BackgroundColor3           = Color3.fromRGB(30, 30, 46),
        Position                   = UDim2.new(0, 46, 0, 0),
        Size                       = UDim2.new(1, -96, 1, 0),
        ScrollBarThickness         = 3,
        ScrollBarImageColor3       = Color3.fromRGB(88, 91, 112),
        ScrollingDirection         = Enum.ScrollingDirection.Y,
        CanvasSize                 = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize        = Enum.AutomaticSize.Y,
        ZIndex                     = 502,
        BorderSizePixel            = 0,
    })

    -- Sync line number scroll with code scroll
    CodeScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        LineNumScroll.CanvasPosition = Vector2.new(0, CodeScroll.CanvasPosition.Y)
    end)

    -- Code TextBox (invisible text, user types here)
    local CodeBox = New("TextBox", {
        Parent               = CodeScroll,
        BackgroundTransparency = 1,
        Size                 = UDim2.new(1, -8, 0, 0),
        AutomaticSize        = Enum.AutomaticSize.Y,
        Text                 = defaultCode,
        TextColor3           = Color3.fromRGB(30, 30, 46),
        TextTransparency     = 1,
        TextSize             = 14,
        Font                 = Enum.Font.Code,
        TextXAlignment       = Enum.TextXAlignment.Left,
        TextYAlignment       = Enum.TextYAlignment.Top,
        ClearTextOnFocus     = false,
        MultiLine            = true,
        TextWrapped          = false,
        ZIndex               = 504,
    })
    Pad(CodeBox, 4, 4, 4, 4)

    -- Syntax Highlighted Overlay
    local HighlightLabel = New("TextLabel", {
        Parent               = CodeScroll,
        BackgroundTransparency = 1,
        Size                 = UDim2.new(1, -8, 0, 0),
        AutomaticSize        = Enum.AutomaticSize.Y,
        Text                 = "",
        TextColor3           = Color3.fromRGB(205, 214, 244),
        TextSize             = 14,
        Font                 = Enum.Font.Code,
        TextXAlignment       = Enum.TextXAlignment.Left,
        TextYAlignment       = Enum.TextYAlignment.Top,
        RichText             = true,
        TextWrapped          = false,
        ZIndex               = 503,
    })
    Pad(HighlightLabel, 4, 4, 4, 4)

    -- Minimap
    local Minimap = New("Frame", {
        Parent           = Body,
        BackgroundColor3 = Color3.fromRGB(24, 24, 37),
        AnchorPoint      = Vector2.new(1, 0),
        Position         = UDim2.new(1, 0, 0, 0),
        Size             = UDim2.new(0, 50, 1, 0),
        ZIndex           = 502,
        ClipsDescendants = true,
        BorderSizePixel  = 0,
    })
    local MinimapCode = New("TextLabel", {
        Parent               = Minimap,
        BackgroundTransparency = 1,
        Size                 = UDim2.new(1, 0, 0, 0),
        AutomaticSize        = Enum.AutomaticSize.Y,
        Text                 = defaultCode,
        TextColor3           = Color3.fromRGB(120, 130, 160),
        TextSize             = 3,
        Font                 = Enum.Font.Code,
        TextXAlignment       = Enum.TextXAlignment.Left,
        TextYAlignment       = Enum.TextYAlignment.Top,
        TextWrapped          = false,
        ZIndex               = 503,
    })

    local MinimapViewport = New("Frame", {
        Parent                 = Minimap,
        BackgroundColor3       = Color3.fromRGB(205, 214, 244),
        BackgroundTransparency = 0.85,
        Size                   = UDim2.new(1, 0, 0, 30),
        ZIndex                 = 504,
        BorderSizePixel        = 0,
    })

    -- â”€â”€ Status Bar â”€â”€
    local StatusBar = New("Frame", {
        Parent           = EditorFrame,
        BackgroundColor3 = Color3.fromRGB(24, 24, 37),
        AnchorPoint      = Vector2.new(0, 1),
        Position         = UDim2.new(0, 0, 1, 0),
        Size             = UDim2.new(1, 0, 0, 24),
        ZIndex           = 501,
        BorderSizePixel  = 0,
    })
    Corner(StatusBar, 10)
    New("Frame", {
        Parent           = StatusBar,
        BackgroundColor3 = Color3.fromRGB(24, 24, 37),
        Size             = UDim2.new(1, 0, 0.5, 0),
        ZIndex           = 501,
        BorderSizePixel  = 0,
    })

    local StatusLabel = New("TextLabel", {
        Parent               = StatusBar,
        BackgroundTransparency = 1,
        Position             = UDim2.new(0, 12, 0, 0),
        Size                 = UDim2.new(1, -24, 1, 0),
        Text                 = "Ln 1, Col 1  |  0 chars  |  Lua",
        TextColor3           = Color3.fromRGB(166, 173, 200),
        TextSize             = 10,
        Font                 = Enum.Font.Code,
        TextXAlignment       = Enum.TextXAlignment.Left,
        ZIndex               = 502,
    })

    -- â”€â”€ Search Bar (initially hidden) â”€â”€
    local SearchBar = New("Frame", {
        Parent           = EditorFrame,
        BackgroundColor3 = Color3.fromRGB(49, 50, 68),
        Position         = UDim2.new(1, -310, 0, 36),
        Size             = UDim2.new(0, 300, 0, 32),
        ZIndex           = 510,
        Visible          = false,
    })
    Corner(SearchBar, 6)
    Stroke(SearchBar, Color3.fromRGB(88, 91, 112), 1)

    local SearchInput = New("TextBox", {
        Parent               = SearchBar,
        BackgroundTransparency = 1,
        Position             = UDim2.new(0, 8, 0, 0),
        Size                 = UDim2.new(1, -60, 1, 0),
        Text                 = "",
        PlaceholderText      = "Find...",
        PlaceholderColor3    = Color3.fromRGB(88, 91, 112),
        TextColor3           = Color3.fromRGB(205, 214, 244),
        TextSize             = 12,
        Font                 = Enum.Font.Code,
        ClearTextOnFocus     = false,
        ZIndex               = 511,
    })

    local SearchClose = New("TextButton", {
        Parent           = SearchBar,
        BackgroundTransparency = 1,
        AnchorPoint      = Vector2.new(1, 0.5),
        Position         = UDim2.new(1, -4, 0.5, 0),
        Size             = UDim2.new(0, 24, 0, 24),
        Text             = "âœ•",
        TextColor3       = Color3.fromRGB(166, 173, 200),
        TextSize         = 12,
        Font             = Enum.Font.GothamBold,
        ZIndex           = 511,
    })
    SearchClose.MouseButton1Click:Connect(function()
        SearchBar.Visible = false
    end)

    -- â”€â”€ Autocompletion Popup â”€â”€
    local AutoPopup = New("Frame", {
        Name             = "AutoPopup",
        Parent           = EditorFrame,
        BackgroundColor3 = Color3.fromRGB(36, 36, 54),
        Size             = UDim2.new(0, 200, 0, 0),
        AutomaticSize    = Enum.AutomaticSize.Y,
        ZIndex           = 520,
        Visible          = false,
        ClipsDescendants = true,
    })
    Corner(AutoPopup, 6)
    Stroke(AutoPopup, Color3.fromRGB(88, 91, 112), 1)

    local AutoPopupLayout = New("UIListLayout", {
        Parent    = AutoPopup,
        Padding   = UDim.new(0, 1),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })

    local function ShowAutocomplete(suggestions, posX, posY)
        for _, child in ipairs(AutoPopup:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        if #suggestions == 0 then
            AutoPopup.Visible = false
            return
        end

        local maxShow = math.min(#suggestions, 8)
        for idx = 1, maxShow do
            local sug = suggestions[idx]
            local btn = New("TextButton", {
                Parent           = AutoPopup,
                BackgroundColor3 = Color3.fromRGB(36, 36, 54),
                BackgroundTransparency = 0,
                Size             = UDim2.new(1, 0, 0, 22),
                Text             = "  " .. sug,
                TextColor3       = Color3.fromRGB(205, 214, 244),
                TextSize         = 12,
                Font             = Enum.Font.Code,
                TextXAlignment   = Enum.TextXAlignment.Left,
                ZIndex           = 521,
                AutoButtonColor  = false,
                LayoutOrder      = idx,
            })
            btn.MouseEnter:Connect(function()
                Tween(btn, {BackgroundColor3 = Color3.fromRGB(69, 71, 90)}, 0.08)
            end)
            btn.MouseLeave:Connect(function()
                Tween(btn, {BackgroundColor3 = Color3.fromRGB(36, 36, 54)}, 0.08)
            end)
            btn.MouseButton1Click:Connect(function()
                -- Insert suggestion
                local text = CodeBox.Text
                local cursorPos = CodeBox.CursorPosition
                if cursorPos > 0 then
                    local before = text:sub(1, cursorPos - 1)
                    local after = text:sub(cursorPos)
                    local wordStart = cursorPos
                    while wordStart > 1 and before:sub(wordStart - 1, wordStart - 1):match("[%w_]") do
                        wordStart = wordStart - 1
                    end
                    CodeBox.Text = before:sub(1, wordStart - 1) .. sug .. after
                end
                AutoPopup.Visible = false
            end)
        end

        AutoPopup.Position = UDim2.new(0, posX, 0, posY)
        AutoPopup.Visible = true
    end

    -- â”€â”€ Update Highlighting â”€â”€
    local function UpdateHighlighting()
        local source = CodeBox.Text
        local tokens = LuaTokenize(source)
        HighlightLabel.Text = TokensToRichText(tokens)

        -- Update line numbers
        local lines = 1
        for _ in source:gmatch("\n") do lines = lines + 1 end
        local nums = {}
        for lnum = 1, lines do
            table.insert(nums, tostring(lnum))
        end
        LineNumLabel.Text = table.concat(nums, "\n")

        -- Update minimap
        MinimapCode.Text = source

        -- Update status bar
        local charCount = #source
        local cursorPos = CodeBox.CursorPosition
        local lineNum = 1
        local colNum = 1
        if cursorPos > 0 then
            local before = source:sub(1, cursorPos - 1)
            for _ in before:gmatch("\n") do lineNum = lineNum + 1 end
            local lastNewline = before:match(".*\n()")
            colNum = lastNewline and (cursorPos - lastNewline + 1) or cursorPos
        end
        StatusLabel.Text = string.format("Ln %d, Col %d  |  %d chars  |  Lua", lineNum, colNum, charCount)
    end

    -- â”€â”€ Toolbar Buttons â”€â”€
    MakeToolBtn("â–¶ Run", 1, function()
        if onRun then onRun(CodeBox.Text) end
    end)
    MakeToolBtn("Clear", 2, function()
        CodeBox.Text = ""
        undoStack:Push("")
        UpdateHighlighting()
    end)
    MakeToolBtn("Copy", 3, function()
        if setclipboard then
            setclipboard(CodeBox.Text)
        end
    end)
    MakeToolBtn("Undo", 4, function()
        local state = undoStack:Undo()
        if state then
            CodeBox.Text = state
            UpdateHighlighting()
        end
    end)
    MakeToolBtn("Redo", 5, function()
        local state = undoStack:Redo()
        if state then
            CodeBox.Text = state
            UpdateHighlighting()
        end
    end)
    MakeToolBtn("ðŸ”", 6, function()
        SearchBar.Visible = not SearchBar.Visible
        if SearchBar.Visible then SearchInput:CaptureFocus() end
    end)

    -- â”€â”€ Event Connections â”€â”€
    local lastText = defaultCode
    CodeBox:GetPropertyChangedSignal("Text"):Connect(function()
        local newText = CodeBox.Text
        if newText ~= lastText then
            undoStack:Push(newText)
            lastText = newText
        end
        UpdateHighlighting()

        -- Autocompletion
        local cursorPos = CodeBox.CursorPosition
        if cursorPos > 0 then
            local before = newText:sub(1, cursorPos - 1)
            local currentWord = before:match("([%w_]+)$") or ""
            if #currentWord >= 2 then
                local suggestions = {}
                local allWords = {}
                for _, list in pairs(AutocompleteDB) do
                    for _, w in ipairs(list) do table.insert(allWords, w) end
                end
                for _, w in ipairs(allWords) do
                    if w:lower():sub(1, #currentWord) == currentWord:lower() then
                        table.insert(suggestions, w)
                    end
                end
                if #suggestions > 0 then
                    ShowAutocomplete(suggestions, 60, 50 + 16 * 2)
                else
                    AutoPopup.Visible = false
                end
            else
                AutoPopup.Visible = false
            end
        end
    end)

    -- Initial highlight
    UpdateHighlighting()

    -- Minimap viewport tracking
    CodeScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        local totalHeight = CodeScroll.CanvasSize.Y.Offset
        if totalHeight <= 0 then return end
        local ratio = CodeScroll.CanvasPosition.Y / totalHeight
        local viewRatio = CodeScroll.AbsoluteSize.Y / totalHeight
        MinimapViewport.Position = UDim2.new(0, 0, ratio, 0)
        MinimapViewport.Size = UDim2.new(1, 0, viewRatio, 0)
    end)

    local editorObj = {
        Frame = EditorFrame,
        TextBox = CodeBox,
        GetText = function() return CodeBox.Text end,
        SetText = function(_, text)
            CodeBox.Text = text
            undoStack:Push(text)
            UpdateHighlighting()
        end,
    }
    return editorObj
end

-- ====================================================================
--  ADVANCED COMPONENTS: CHARTS & VISUALIZATIONS
-- ====================================================================

--- @function Sec:AddLineChart
--- @description Creates a real-time updating line chart component
function Sec:AddLineChart(chartOpt)
    chartOpt = chartOpt or {}
    local T = ThemeEngine.Themes[Library.Theme] or ThemeEngine.Themes.Dark
    local name = chartOpt.Name or "Line Chart"
    local data = chartOpt.Data or {0, 0, 0, 0, 0}
    
    local row = New("Frame", {
        Parent               = self.Body,
        BackgroundTransparency = 1,
        Size                 = UDim2.new(1, 0, 0, 180),
        ZIndex               = 17,
        LayoutOrder          = self._order,
    })
    self._order = self._order + 1
    
    local bg = New("Frame", {
        Parent           = row,
        BackgroundColor3 = T.Tertiary,
        Size             = UDim2.new(1, 0, 1, 0),
        ZIndex           = 17,
    })
    New("UICorner", { Parent = bg, CornerRadius = UDim.new(0, 7) })
    
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
    New("UICorner", { Parent = chartArea, CornerRadius = UDim.new(0, 6) })
    
    local points = {}
    local lines = {}
    
    local function redraw()
        for _, p in ipairs(points) do p:Destroy() end
        for _, l in ipairs(lines) do l:Destroy() end
        points = {}
        lines = {}
        
        if #data < 2 then return end
        
        local minVal, maxVal = math.huge, -math.huge
        for _, v in ipairs(data) do
            if v < minVal then minVal = v end
            if v > maxVal then maxVal = v end
        end
        if maxVal == minVal then maxVal = minVal + 1 end
        
        local width = chartArea.AbsoluteSize.X
        local height = chartArea.AbsoluteSize.Y
        local stepX = width / (#data - 1)
        
        local prevPoint = nil
        
        for i, v in ipairs(data) do
            local norm = (v - minVal) / (maxVal - minVal)
            local px = (i - 1) * stepX
            local py = height - (norm * height)
            
            local pt = New("Frame", {
                Parent = chartArea,
                BackgroundColor3 = T.Accent,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0, px, 0, py),
                Size = UDim2.new(0, 6, 0, 6),
                ZIndex = 20,
            })
            New("UICorner", { Parent = pt, CornerRadius = UDim.new(1, 0) })
            table.insert(points, pt)
            
            if prevPoint then
                local dist = math.sqrt((px - prevPoint.X)^2 + (py - prevPoint.Y)^2)
                local angle = math.deg(math.atan2(py - prevPoint.Y, px - prevPoint.X))
                
                local line = New("Frame", {
                    Parent = chartArea,
                    BackgroundColor3 = T.Accent,
                    BorderSizePixel = 0,
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.new(0, (px + prevPoint.X)/2, 0, (py + prevPoint.Y)/2),
                    Size = UDim2.new(0, dist, 0, 2),
                    Rotation = angle,
                    ZIndex = 19,
                })
                table.insert(lines, line)
            end
            prevPoint = {X = px, Y = py}
        end
    end
    
    chartArea:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        Guard.SafeCall(redraw)
    end)
    
    Guard.SafeCall(redraw)
    
    local chartObj = {}
    function chartObj:Update(newData)
        data = newData
        Guard.SafeCall(redraw)
    end
    
    return chartObj
end

-- ====================================================================
--  ADVANCED COMPONENTS: NODE EDITOR (BLUEPRINTS)
-- ====================================================================

--- @function Sec:AddNodeEditor
--- @description Creates a visual node-based logic editor workspace
function Sec:AddNodeEditor(nodeOpt)
    nodeOpt = nodeOpt or {}
    local T = ThemeEngine.Themes[Library.Theme] or ThemeEngine.Themes.Dark
    local name = nodeOpt.Name or "Node Editor"
    
    local row = New("Frame", {
        Parent               = self.Body,
        BackgroundTransparency = 1,
        Size                 = UDim2.new(1, 0, 0, 400),
        ZIndex               = 17,
        LayoutOrder          = self._order,
    })
    self._order = self._order + 1
    
    local bg = New("Frame", {
        Parent           = row,
        BackgroundColor3 = T.Tertiary,
        Size             = UDim2.new(1, 0, 1, 0),
        ZIndex           = 17,
    })
    New("UICorner", { Parent = bg, CornerRadius = UDim.new(0, 7) })
    
    local canvas = New("ScrollingFrame", {
        Parent = bg,
        BackgroundColor3 = T.Background,
        Position = UDim2.new(0, 2, 0, 2),
        Size = UDim2.new(1, -4, 1, -4),
        CanvasSize = UDim2.new(0, 2000, 0, 2000),
        ScrollBarThickness = 4,
        ZIndex = 18,
    })
    New("UICorner", { Parent = canvas, CornerRadius = UDim.new(0, 5) })
    
    -- Node Grid Pattern
    local grid = New("ImageLabel", {
        Parent = canvas,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Image = "rbxassetid://6553888365",
        ImageColor3 = T.Border,
        ImageTransparency = 0.5,
        ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.new(0, 40, 0, 40),
        ZIndex = 18,
    })
    
    local nodes = {}
    local connections = {}
    
    local function CreateNode(title, position)
        local node = New("Frame", {
            Parent = canvas,
            BackgroundColor3 = T.Secondary,
            Position = UDim2.new(0, position.X, 0, position.Y),
            Size = UDim2.new(0, 160, 0, 100),
            ZIndex = 25,
            Active = true,
            Draggable = true,
        })
        New("UICorner", { Parent = node, CornerRadius = UDim.new(0, 6) })
        New("UIStroke", { Parent = node, Color = T.BorderHover, Thickness = 1 })
        
        local header = New("Frame", {
            Parent = node,
            BackgroundColor3 = T.Accent,
            Size = UDim2.new(1, 0, 0, 24),
            ZIndex = 26,
        })
        New("UICorner", { Parent = header, CornerRadius = UDim.new(0, 6) })
        
        New("TextLabel", {
            Parent = header,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -10, 1, 0),
            Position = UDim2.new(0, 10, 0, 0),
            Text = title,
            TextColor3 = Color3.new(1,1,1),
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 27,
        })
        
        local inputPort = New("TextButton", {
            Parent = node,
            BackgroundColor3 = T.Background,
            Position = UDim2.new(0, -6, 0, 40),
            Size = UDim2.new(0, 12, 0, 12),
            Text = "",
            ZIndex = 28,
        })
        New("UICorner", { Parent = inputPort, CornerRadius = UDim.new(1, 0) })
        New("UIStroke", { Parent = inputPort, Color = T.Border, Thickness = 2 })
        
        local outputPort = New("TextButton", {
            Parent = node,
            BackgroundColor3 = T.Accent,
            Position = UDim2.new(1, -6, 0, 40),
            Size = UDim2.new(0, 12, 0, 12),
            Text = "",
            ZIndex = 28,
        })
        New("UICorner", { Parent = outputPort, CornerRadius = UDim.new(1, 0) })
        New("UIStroke", { Parent = outputPort, Color = T.Border, Thickness = 2 })
        
        table.insert(nodes, node)
        return {Node = node, Input = inputPort, Output = outputPort}
    end
    
    local nodeObj = {}
    function nodeObj:AddNode(title, pos)
        return CreateNode(title, pos)
    end
    
    -- Initialize with some default nodes
    CreateNode("Start Event", Vector2.new(50, 100))
    CreateNode("Math: Add", Vector2.new(300, 80))
    CreateNode("Print String", Vector2.new(550, 120))
    
    return nodeObj
end

-- ====================================================================
--  ADVANCED COMPONENTS: FILE TREE EXPLORER
-- ====================================================================

--- @function Sec:AddTreeView
--- @description Creates a collapsible, hierarchical file explorer view
function Sec:AddTreeView(treeOpt)
    treeOpt = treeOpt or {}
    local T = ThemeEngine.Themes[Library.Theme] or ThemeEngine.Themes.Dark
    local name = treeOpt.Name or "Explorer"
    local data = treeOpt.Data or {
        {Name = "Workspace", Type = "Folder", Children = {
            {Name = "Baseplate", Type = "Part"},
            {Name = "SpawnLocation", Type = "Part"},
        }},
        {Name = "Players", Type = "Folder", Children = {}},
    }
    
    local row = New("Frame", {
        Parent               = self.Body,
        BackgroundTransparency = 1,
        Size                 = UDim2.new(1, 0, 0, 240),
        ZIndex               = 17,
        LayoutOrder          = self._order,
    })
    self._order = self._order + 1
    
    local bg = New("Frame", {
        Parent           = row,
        BackgroundColor3 = T.Tertiary,
        Size             = UDim2.new(1, 0, 1, 0),
        ZIndex           = 17,
    })
    New("UICorner", { Parent = bg, CornerRadius = UDim.new(0, 7) })
    
    local scroller = New("ScrollingFrame", {
        Parent = bg,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 5, 0, 5),
        Size = UDim2.new(1, -10, 1, -10),
        ScrollBarThickness = 2,
        ZIndex = 18,
    })
    local layout = New("UIListLayout", {
        Parent = scroller,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
    })
    
    local function RenderItem(item, parentFrame, level)
        local itemBtn = New("TextButton", {
            Parent = parentFrame,
            BackgroundColor3 = T.Secondary,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 22),
            Text = "",
            ZIndex = 19,
        })
        
        local indent = level * 16
        local icon = item.Type == "Folder" and "ðŸ“" or "ðŸ“„"
        
        local lbl = New("TextLabel", {
            Parent = itemBtn,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, indent + 24, 0, 0),
            Size = UDim2.new(1, -(indent + 24), 1, 0),
            Text = item.Name,
            TextColor3 = T.Text,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 20,
        })
        
        local iconLbl = New("TextLabel", {
            Parent = itemBtn,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, indent + 4, 0, 0),
            Size = UDim2.new(0, 16, 1, 0),
            Text = icon,
            TextColor3 = T.Text,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            ZIndex = 20,
        })
        
        if item.Type == "Folder" and item.Children then
            local childrenFrame = New("Frame", {
                Parent = parentFrame,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Visible = false,
            })
            New("UIListLayout", {
                Parent = childrenFrame,
                SortOrder = Enum.SortOrder.LayoutOrder,
            })
            for _, child in ipairs(item.Children) do
                RenderItem(child, childrenFrame, level + 1)
            end
            
            Guard.Connect(itemBtn.MouseButton1Click, function()
                childrenFrame.Visible = not childrenFrame.Visible
                iconLbl.Text = childrenFrame.Visible and "ðŸ“‚" or "ðŸ“"
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
        local tab = self:CreateTab({ Name = "Settings", Icon = "âœ¦" })

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

-- Quick notification shorthand
function Library:Toast(message, notifType, duration)
    self:Notify({
        Title    = "BorcaHub",
        Content  = message or "",
        Type     = notifType or "Info",
        Duration = duration  or 3,
    })
end

-- Set accent color on the active theme at runtime
function Library:SetAccent(color)
    if typeof(color) ~= "Color3" then return end
    local T = self.Theme
    T.Accent      = color
    T.AccentHover = color:Lerp(Color3.new(0,0,0), 0.12)
    T.AccentDim   = color:Lerp(Color3.new(0,0,0), 0.08)
    T.ToggleOn    = color
    T.Info        = color
end

-- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
--  WATERMARK OVERLAY  (v3.0.0)
--  Shows a small HUD at the corner: hub name, version, FPS counter
-- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
function Library:Watermark(wmOpt)
    wmOpt = wmOpt or {}
    local T        = self.Theme
    local name     = wmOpt.Name    or self.Meta.Name
    local ver      = wmOpt.Version or self.Meta.Version
    local showFps  = wmOpt.ShowFPS ~= false
    local corner   = wmOpt.Corner  or "TopRight"   -- TopRight|TopLeft|BottomRight|BottomLeft

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

    -- Animate in
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

-- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
--  ANNOUNCEMENT BANNER  (v3.0.0)
--  Full-width animated banner at the top of the screen
-- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
function Library:Banner(bnOpt)
    bnOpt = bnOpt or {}
    local T        = self.Theme
    local title    = bnOpt.Title   or "Announcement"
    local message  = bnOpt.Message or bnOpt.Content or ""
    local bType    = bnOpt.Type    or "Info"
    local duration = bnOpt.Duration or nil  -- nil = stays until dismissed
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
        Text                 = "âœ•",
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

    -- Slide in
    Tween(BannerWrap, { Position = UDim2.new(0.5, 0, 0, 8) }, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

    if duration then
        task.delay(duration, function()
            if BannerWrap.Parent then Dismiss() end
        end)
    end

    return { Frame = BannerWrap, Dismiss = Dismiss }
end

-- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
--  INPUT PROMPT  (v3.0.0)
--  Like Confirm but includes a TextBox for user input
-- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
        PlaceholderText      = ipOpt.Placeholder or "Type hereâ€¦",
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

-- ====================================================================
--  !! PENTING: Hanya -- ====================================================================
--  ADVANCED COMPONENTS: CHARTS & VISUALIZATIONS
-- ====================================================================

--- @function Sec:AddLineChart

return Library




