--[[
    â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
    â•‘              BorcaHub UI Library  â€¢  Theme.lua                      â•‘
    â•‘         UIMain / Components / File / Theme.lua                      â•‘
    â•‘                                                                      â•‘
    â•‘  Role    : The Visual Engine                                         â•‘
    â•‘  Version : 0.0.1                                                     â•‘
    â•‘                                                                      â•‘
    â•‘  Responsibilities:                                                   â•‘
    â•‘   â€¢ Stores all theme color palettes (13 themes)                      â•‘
    â•‘   â€¢ Accent preset management (14 accents)                            â•‘
    â•‘   â€¢ Neon Glow Engine â€” dynamic UIStroke & shadow recoloring          â•‘
    â•‘   â€¢ Runtime theme switching without re-rendering                     â•‘
    â•‘   â€¢ Transition properties (durations, easing, corner radii)          â•‘
    â•‘   â€¢ Color math utilities (HSV, Hex, interpolation, luminance)        â•‘
    â•‘   â€¢ Logo gradient system                                             â•‘
    â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--]]

-- ====================================================================
--  SERVICES (local cache for performance)
-- ====================================================================
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")

-- ====================================================================
--  MODULE TABLE
-- ====================================================================

--- @class ThemeEngine
--- @description Central visual engine for BorcaHub UI.
---   Manages color palettes, accent presets, glow effects, and
---   provides utility functions for color manipulation.
local ThemeEngine = {}
ThemeEngine.__index = ThemeEngine

-- ====================================================================
--  COLOR MATH UTILITIES
-- ====================================================================

--- @function HSVtoColor3
--- @param h number â€” Hue (0â€“1)
--- @param s number â€” Saturation (0â€“1)
--- @param v number â€” Value/Brightness (0â€“1)
--- @return Color3
--- @description Converts HSV color space to Roblox Color3.
function ThemeEngine.HSVtoColor3(h, s, v)
    return Color3.fromHSV(h, s, v)
end

--- @function Color3toHSV
--- @param c Color3 â€” Input color
--- @return number h, number s, number v
--- @description Extracts HSV components from a Color3.
function ThemeEngine.Color3toHSV(c)
    local h, s, v = Color3.toHSV(c)
    return h, s, v
end

--- @function HexToColor3
--- @param hex string â€” Hex color string (e.g., "#FF00AA" or "FF00AA")
--- @return Color3
--- @description Parses a 6-character hex string into a Color3.
---   Returns white (1,1,1) if the hex string is invalid.
function ThemeEngine.HexToColor3(hex)
    hex = hex:gsub("^#", "")
    if #hex ~= 6 then return Color3.new(1, 1, 1) end
    local r = tonumber(hex:sub(1, 2), 16) or 255
    local g = tonumber(hex:sub(3, 4), 16) or 255
    local b = tonumber(hex:sub(5, 6), 16) or 255
    return Color3.fromRGB(r, g, b)
end

--- @function Color3ToHex
--- @param c Color3 â€” Input color
--- @return string â€” "#RRGGBB" formatted hex string
--- @description Converts a Color3 to a hex string with leading '#'.
function ThemeEngine.Color3ToHex(c)
    return string.format("#%02X%02X%02X",
        math.floor(c.R * 255),
        math.floor(c.G * 255),
        math.floor(c.B * 255)
    )
end

--- @function LerpColor
--- @param a Color3 â€” Start color
--- @param b Color3 â€” End color
--- @param t number â€” Interpolation factor (0â€“1)
--- @return Color3
--- @description Linearly interpolates between two Color3 values.
function ThemeEngine.LerpColor(a, b, t)
    return Color3.new(
        a.R + (b.R - a.R) * t,
        a.G + (b.G - a.G) * t,
        a.B + (b.B - a.B) * t
    )
end

--- @function GetLuminance
--- @param c Color3 â€” Input color
--- @return number â€” Perceived luminance (0â€“1)
--- @description Calculates the perceived luminance of a color
---   using the standard sRGB luminance formula.
---   Useful for determining whether text should be light or dark.
function ThemeEngine.GetLuminance(c)
    return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
end

--- @function IsDarkColor
--- @param c Color3 â€” Input color
--- @return boolean â€” True if the color is perceptually dark
--- @description Returns true if the luminance is below 0.5 threshold.
function ThemeEngine.IsDarkColor(c)
    return ThemeEngine.GetLuminance(c) < 0.5
end

--- @function DarkenColor
--- @param c Color3 â€” Input color
--- @param amount number â€” Darkening factor (0â€“1), default 0.2
--- @return Color3
--- @description Darkens a color by reducing its brightness in HSV space.
function ThemeEngine.DarkenColor(c, amount)
    amount = amount or 0.2
    local h, s, v = Color3.toHSV(c)
    v = math.max(0, v - amount)
    return Color3.fromHSV(h, s, v)
end

--- @function LightenColor
--- @param c Color3 â€” Input color
--- @param amount number â€” Lightening factor (0â€“1), default 0.2
--- @return Color3
--- @description Lightens a color by increasing its brightness in HSV space.
function ThemeEngine.LightenColor(c, amount)
    amount = amount or 0.2
    local h, s, v = Color3.toHSV(c)
    v = math.min(1, v + amount)
    return Color3.fromHSV(h, s, v)
end

--- @function SaturateColor
--- @param c Color3 â€” Input color
--- @param amount number â€” Saturation adjustment (0â€“1), default 0.15
--- @return Color3
--- @description Increases the saturation of a color in HSV space.
function ThemeEngine.SaturateColor(c, amount)
    amount = amount or 0.15
    local h, s, v = Color3.toHSV(c)
    s = math.min(1, s + amount)
    return Color3.fromHSV(h, s, v)
end

--- @function DesaturateColor
--- @param c Color3 â€” Input color
--- @param amount number â€” Desaturation amount (0â€“1), default 0.15
--- @return Color3
--- @description Reduces the saturation of a color in HSV space.
function ThemeEngine.DesaturateColor(c, amount)
    amount = amount or 0.15
    local h, s, v = Color3.toHSV(c)
    s = math.max(0, s - amount)
    return Color3.fromHSV(h, s, v)
end

--- @function ComplementaryColor
--- @param c Color3 â€” Input color
--- @return Color3
--- @description Returns the complementary (opposite hue) color.
function ThemeEngine.ComplementaryColor(c)
    local h, s, v = Color3.toHSV(c)
    h = (h + 0.5) % 1
    return Color3.fromHSV(h, s, v)
end

--- @function GlowColor
--- @param baseColor Color3 â€” The base accent color
--- @param intensity number â€” Glow intensity (0â€“1), default 0.3
--- @return Color3
--- @description Creates a glow-suitable version of a color by
---   lightening it and slightly desaturating for a neon feel.
function ThemeEngine.GlowColor(baseColor, intensity)
    intensity = intensity or 0.3
    local h, s, v = Color3.toHSV(baseColor)
    v = math.min(1, v + intensity * 0.5)
    s = math.max(0, s - intensity * 0.2)
    return Color3.fromHSV(h, s, v)
end

-- ====================================================================
--  THEME PALETTES â€” 13 Complete Themes
--  Each theme contains 21 color properties + extended rendering props
-- ====================================================================

--- @table Themes
--- @description Master dictionary of all available color palettes.
ThemeEngine.Themes = {}

-- â”€â”€ Dark Theme (Default) â”€â”€
ThemeEngine.Themes.Dark = {
    Background   = Color3.fromRGB(11,  12,  16 ),
    Secondary    = Color3.fromRGB(17,  19,  24 ),
    Tertiary     = Color3.fromRGB(24,  27,  34 ),
    Quaternary   = Color3.fromRGB(30,  34,  48 ),
    Border       = Color3.fromRGB(31,  34,  53 ),
    BorderHover  = Color3.fromRGB(55,  60,  88 ),
    Accent       = Color3.fromRGB(91,  140, 255),
    AccentHover  = Color3.fromRGB(61,  110, 224),
    AccentDim    = Color3.fromRGB(91,  140, 255),
    Text         = Color3.fromRGB(232, 234, 246),
    TextSub      = Color3.fromRGB(123, 127, 168),
    TextDim      = Color3.fromRGB(63,  66,  96 ),
    ToggleOn     = Color3.fromRGB(91,  140, 255),
    ToggleOff    = Color3.fromRGB(30,  34,  48 ),
    Knob         = Color3.fromRGB(255, 255, 255),
    Success      = Color3.fromRGB(78,  204, 163),
    Warning      = Color3.fromRGB(240, 180, 41 ),
    Error        = Color3.fromRGB(239, 68,  68 ),
    Info         = Color3.fromRGB(91,  140, 255),
    Gold         = Color3.fromRGB(226, 184, 74 ),
    ScrollBar    = Color3.fromRGB(40,  45,  70 ),
    GlowIntensity   = 0.3,
    NeonStrength     = 0.5,
    StrokeThickness  = 1,
    CornerRadius     = 6,
    TransitionSpeed  = 0.18,
    ShadowOpacity    = 0.4,
}

-- â”€â”€ Light Theme â”€â”€
ThemeEngine.Themes.Light = {
    Background   = Color3.fromRGB(245, 246, 252),
    Secondary    = Color3.fromRGB(232, 234, 246),
    Tertiary     = Color3.fromRGB(218, 221, 240),
    Quaternary   = Color3.fromRGB(204, 208, 232),
    Border       = Color3.fromRGB(195, 200, 230),
    BorderHover  = Color3.fromRGB(160, 170, 215),
    Accent       = Color3.fromRGB(72,  110, 225),
    AccentHover  = Color3.fromRGB(50,  88,  200),
    AccentDim    = Color3.fromRGB(100, 135, 230),
    Text         = Color3.fromRGB(18,  20,  48 ),
    TextSub      = Color3.fromRGB(90,  95,  138),
    TextDim      = Color3.fromRGB(155, 160, 195),
    ToggleOn     = Color3.fromRGB(72,  110, 225),
    ToggleOff    = Color3.fromRGB(195, 200, 230),
    Knob         = Color3.fromRGB(255, 255, 255),
    Success      = Color3.fromRGB(40,  165, 110),
    Warning      = Color3.fromRGB(200, 145, 20 ),
    Error        = Color3.fromRGB(205, 45,  45 ),
    Info         = Color3.fromRGB(72,  110, 225),
    Gold         = Color3.fromRGB(185, 145, 25 ),
    ScrollBar    = Color3.fromRGB(165, 170, 210),
    GlowIntensity   = 0.15,
    NeonStrength     = 0.2,
    StrokeThickness  = 1,
    CornerRadius     = 6,
    TransitionSpeed  = 0.18,
    ShadowOpacity    = 0.15,
}

-- â”€â”€ Mocha Theme â”€â”€
ThemeEngine.Themes.Mocha = {
    Background   = Color3.fromRGB(28,  20,  18 ),
    Secondary    = Color3.fromRGB(38,  28,  24 ),
    Tertiary     = Color3.fromRGB(50,  37,  32 ),
    Quaternary   = Color3.fromRGB(62,  46,  40 ),
    Border       = Color3.fromRGB(72,  52,  44 ),
    BorderHover  = Color3.fromRGB(100, 72,  60 ),
    Accent       = Color3.fromRGB(215, 140, 95 ),
    AccentHover  = Color3.fromRGB(190, 115, 70 ),
    AccentDim    = Color3.fromRGB(175, 115, 80 ),
    Text         = Color3.fromRGB(245, 232, 222),
    TextSub      = Color3.fromRGB(180, 155, 138),
    TextDim      = Color3.fromRGB(115, 95,  82 ),
    ToggleOn     = Color3.fromRGB(215, 140, 95 ),
    ToggleOff    = Color3.fromRGB(72,  52,  44 ),
    Knob         = Color3.fromRGB(255, 245, 238),
    Success      = Color3.fromRGB(95,  188, 115),
    Warning      = Color3.fromRGB(235, 172, 65 ),
    Error        = Color3.fromRGB(218, 78,  78 ),
    Info         = Color3.fromRGB(215, 140, 95 ),
    Gold         = Color3.fromRGB(225, 185, 80 ),
    ScrollBar    = Color3.fromRGB(80,  60,  50 ),
    GlowIntensity   = 0.25,
    NeonStrength     = 0.4,
    StrokeThickness  = 1,
    CornerRadius     = 6,
    TransitionSpeed  = 0.2,
    ShadowOpacity    = 0.45,
}

-- â”€â”€ Aqua Theme â”€â”€
ThemeEngine.Themes.Aqua = {
    Background   = Color3.fromRGB(10,  20,  28 ),
    Secondary    = Color3.fromRGB(15,  30,  42 ),
    Tertiary     = Color3.fromRGB(22,  42,  58 ),
    Quaternary   = Color3.fromRGB(28,  54,  75 ),
    Border       = Color3.fromRGB(35,  62,  85 ),
    BorderHover  = Color3.fromRGB(55,  95,  120),
    Accent       = Color3.fromRGB(55,  195, 215),
    AccentHover  = Color3.fromRGB(35,  170, 192),
    AccentDim    = Color3.fromRGB(45,  165, 185),
    Text         = Color3.fromRGB(220, 245, 250),
    TextSub      = Color3.fromRGB(125, 190, 210),
    TextDim      = Color3.fromRGB(65,  115, 138),
    ToggleOn     = Color3.fromRGB(55,  195, 215),
    ToggleOff    = Color3.fromRGB(35,  62,  85 ),
    Knob         = Color3.fromRGB(235, 252, 255),
    Success      = Color3.fromRGB(65,  205, 128),
    Warning      = Color3.fromRGB(245, 185, 62 ),
    Error        = Color3.fromRGB(228, 72,  72 ),
    Info         = Color3.fromRGB(55,  195, 215),
    Gold         = Color3.fromRGB(230, 192, 75 ),
    ScrollBar    = Color3.fromRGB(40,  75,  95 ),
    GlowIntensity   = 0.35,
    NeonStrength     = 0.6,
    StrokeThickness  = 1,
    CornerRadius     = 6,
    TransitionSpeed  = 0.18,
    ShadowOpacity    = 0.4,
}

-- â”€â”€ Rose Theme â”€â”€
ThemeEngine.Themes.Rose = {
    Background   = Color3.fromRGB(30,  18,  22 ),
    Secondary    = Color3.fromRGB(42,  25,  32 ),
    Tertiary     = Color3.fromRGB(55,  32,  42 ),
    Quaternary   = Color3.fromRGB(68,  40,  55 ),
    Border       = Color3.fromRGB(80,  48,  62 ),
    BorderHover  = Color3.fromRGB(115, 68,  88 ),
    Accent       = Color3.fromRGB(232, 100, 140),
    AccentHover  = Color3.fromRGB(208, 75,  115),
    AccentDim    = Color3.fromRGB(195, 85,  118),
    Text         = Color3.fromRGB(252, 232, 238),
    TextSub      = Color3.fromRGB(192, 148, 165),
    TextDim      = Color3.fromRGB(122, 85,  102),
    ToggleOn     = Color3.fromRGB(232, 100, 140),
    ToggleOff    = Color3.fromRGB(80,  48,  62 ),
    Knob         = Color3.fromRGB(255, 242, 248),
    Success      = Color3.fromRGB(85,  195, 118),
    Warning      = Color3.fromRGB(250, 178, 60 ),
    Error        = Color3.fromRGB(235, 65,  65 ),
    Info         = Color3.fromRGB(232, 100, 140),
    Gold         = Color3.fromRGB(235, 188, 75 ),
    ScrollBar    = Color3.fromRGB(88,  55,  70 ),
    GlowIntensity   = 0.3,
    NeonStrength     = 0.55,
    StrokeThickness  = 1,
    CornerRadius     = 6,
    TransitionSpeed  = 0.18,
    ShadowOpacity    = 0.4,
}

-- â”€â”€ Midnight Theme â”€â”€
ThemeEngine.Themes.Midnight = {
    Background   = Color3.fromRGB(6,   7,   14 ),
    Secondary    = Color3.fromRGB(10,  12,  22 ),
    Tertiary     = Color3.fromRGB(15,  18,  34 ),
    Quaternary   = Color3.fromRGB(20,  24,  46 ),
    Border       = Color3.fromRGB(28,  32,  60 ),
    BorderHover  = Color3.fromRGB(50,  58,  105),
    Accent       = Color3.fromRGB(130, 80,  255),
    AccentHover  = Color3.fromRGB(105, 55,  230),
    AccentDim    = Color3.fromRGB(115, 68,  220),
    Text         = Color3.fromRGB(225, 222, 255),
    TextSub      = Color3.fromRGB(140, 135, 192),
    TextDim      = Color3.fromRGB(72,  68,  108),
    ToggleOn     = Color3.fromRGB(130, 80,  255),
    ToggleOff    = Color3.fromRGB(28,  32,  60 ),
    Knob         = Color3.fromRGB(248, 245, 255),
    Success      = Color3.fromRGB(75,  200, 148),
    Warning      = Color3.fromRGB(242, 180, 58 ),
    Error        = Color3.fromRGB(235, 68,  68 ),
    Info         = Color3.fromRGB(130, 80,  255),
    Gold         = Color3.fromRGB(225, 185, 72 ),
    ScrollBar    = Color3.fromRGB(32,  36,  68 ),
    GlowIntensity   = 0.45,
    NeonStrength     = 0.7,
    StrokeThickness  = 1,
    CornerRadius     = 6,
    TransitionSpeed  = 0.2,
    ShadowOpacity    = 0.5,
}

-- â”€â”€ Neon Theme â”€â”€
ThemeEngine.Themes.Neon = {
    Background   = Color3.fromRGB(5,   8,   10 ),
    Secondary    = Color3.fromRGB(8,   14,  16 ),
    Tertiary     = Color3.fromRGB(12,  20,  22 ),
    Quaternary   = Color3.fromRGB(16,  28,  30 ),
    Border       = Color3.fromRGB(20,  40,  42 ),
    BorderHover  = Color3.fromRGB(30,  65,  68 ),
    Accent       = Color3.fromRGB(0,   255, 180),
    AccentHover  = Color3.fromRGB(0,   225, 158),
    AccentDim    = Color3.fromRGB(0,   200, 155),
    Text         = Color3.fromRGB(210, 255, 248),
    TextSub      = Color3.fromRGB(95,  185, 175),
    TextDim      = Color3.fromRGB(42,  90,  86 ),
    ToggleOn     = Color3.fromRGB(0,   255, 180),
    ToggleOff    = Color3.fromRGB(20,  40,  42 ),
    Knob         = Color3.fromRGB(230, 255, 252),
    Success      = Color3.fromRGB(0,   255, 180),
    Warning      = Color3.fromRGB(255, 215, 0  ),
    Error        = Color3.fromRGB(255, 50,  80 ),
    Info         = Color3.fromRGB(0,   200, 255),
    Gold         = Color3.fromRGB(255, 215, 0  ),
    ScrollBar    = Color3.fromRGB(18,  48,  46 ),
    GlowIntensity   = 0.6,
    NeonStrength     = 0.9,
    StrokeThickness  = 1.5,
    CornerRadius     = 6,
    TransitionSpeed  = 0.15,
    ShadowOpacity    = 0.35,
}

-- â”€â”€ Crimson Theme â”€â”€
ThemeEngine.Themes.Crimson = {
    Background   = Color3.fromRGB(12,  8,   8  ),
    Secondary    = Color3.fromRGB(20,  12,  12 ),
    Tertiary     = Color3.fromRGB(30,  16,  16 ),
    Quaternary   = Color3.fromRGB(40,  22,  22 ),
    Border       = Color3.fromRGB(52,  25,  25 ),
    BorderHover  = Color3.fromRGB(85,  38,  38 ),
    Accent       = Color3.fromRGB(220, 45,  75 ),
    AccentHover  = Color3.fromRGB(195, 25,  55 ),
    AccentDim    = Color3.fromRGB(185, 35,  60 ),
    Text         = Color3.fromRGB(255, 230, 232),
    TextSub      = Color3.fromRGB(188, 140, 143),
    TextDim      = Color3.fromRGB(108, 72,  75 ),
    ToggleOn     = Color3.fromRGB(220, 45,  75 ),
    ToggleOff    = Color3.fromRGB(52,  25,  25 ),
    Knob         = Color3.fromRGB(255, 248, 248),
    Success      = Color3.fromRGB(80,  195, 120),
    Warning      = Color3.fromRGB(245, 182, 55 ),
    Error        = Color3.fromRGB(255, 60,  60 ),
    Info         = Color3.fromRGB(220, 45,  75 ),
    Gold         = Color3.fromRGB(230, 188, 75 ),
    ScrollBar    = Color3.fromRGB(55,  28,  28 ),
    GlowIntensity   = 0.4,
    NeonStrength     = 0.65,
    StrokeThickness  = 1,
    CornerRadius     = 6,
    TransitionSpeed  = 0.18,
    ShadowOpacity    = 0.45,
}

-- â”€â”€ Forest Theme â”€â”€
ThemeEngine.Themes.Forest = {
    Background   = Color3.fromRGB(10,  16,  10 ),
    Secondary    = Color3.fromRGB(14,  24,  14 ),
    Tertiary     = Color3.fromRGB(18,  32,  18 ),
    Quaternary   = Color3.fromRGB(24,  42,  24 ),
    Border       = Color3.fromRGB(30,  55,  30 ),
    BorderHover  = Color3.fromRGB(48,  88,  48 ),
    Accent       = Color3.fromRGB(82,  196, 108),
    AccentHover  = Color3.fromRGB(60,  172, 85 ),
    AccentDim    = Color3.fromRGB(68,  165, 90 ),
    Text         = Color3.fromRGB(215, 245, 215),
    TextSub      = Color3.fromRGB(130, 185, 130),
    TextDim      = Color3.fromRGB(62,  98,  62 ),
    ToggleOn     = Color3.fromRGB(82,  196, 108),
    ToggleOff    = Color3.fromRGB(30,  55,  30 ),
    Knob         = Color3.fromRGB(240, 255, 240),
    Success      = Color3.fromRGB(82,  196, 108),
    Warning      = Color3.fromRGB(242, 182, 58 ),
    Error        = Color3.fromRGB(220, 65,  65 ),
    Info         = Color3.fromRGB(70,  185, 185),
    Gold         = Color3.fromRGB(225, 185, 68 ),
    ScrollBar    = Color3.fromRGB(28,  58,  28 ),
    GlowIntensity   = 0.3,
    NeonStrength     = 0.45,
    StrokeThickness  = 1,
    CornerRadius     = 6,
    TransitionSpeed  = 0.2,
    ShadowOpacity    = 0.4,
}

-- â”€â”€ Ocean Theme â”€â”€
ThemeEngine.Themes.Ocean = {
    Background   = Color3.fromRGB(6,   10,  22 ),
    Secondary    = Color3.fromRGB(9,   16,  34 ),
    Tertiary     = Color3.fromRGB(13,  22,  48 ),
    Quaternary   = Color3.fromRGB(16,  30,  62 ),
    Border       = Color3.fromRGB(20,  38,  78 ),
    BorderHover  = Color3.fromRGB(32,  60,  118),
    Accent       = Color3.fromRGB(48,  148, 242),
    AccentHover  = Color3.fromRGB(28,  122, 218),
    AccentDim    = Color3.fromRGB(38,  132, 225),
    Text         = Color3.fromRGB(218, 235, 255),
    TextSub      = Color3.fromRGB(110, 158, 215),
    TextDim      = Color3.fromRGB(45,  78,  132),
    ToggleOn     = Color3.fromRGB(48,  148, 242),
    ToggleOff    = Color3.fromRGB(20,  38,  78 ),
    Knob         = Color3.fromRGB(235, 245, 255),
    Success      = Color3.fromRGB(68,  205, 145),
    Warning      = Color3.fromRGB(242, 180, 55 ),
    Error        = Color3.fromRGB(225, 65,  65 ),
    Info         = Color3.fromRGB(48,  148, 242),
    Gold         = Color3.fromRGB(225, 185, 70 ),
    ScrollBar    = Color3.fromRGB(18,  42,  85 ),
    GlowIntensity   = 0.35,
    NeonStrength     = 0.55,
    StrokeThickness  = 1,
    CornerRadius     = 6,
    TransitionSpeed  = 0.18,
    ShadowOpacity    = 0.4,
}

-- â”€â”€ Sakura Theme â”€â”€
ThemeEngine.Themes.Sakura = {
    Background   = Color3.fromRGB(22,  14,  18 ),
    Secondary    = Color3.fromRGB(34,  20,  28 ),
    Tertiary     = Color3.fromRGB(48,  28,  38 ),
    Quaternary   = Color3.fromRGB(62,  36,  50 ),
    Border       = Color3.fromRGB(78,  44,  62 ),
    BorderHover  = Color3.fromRGB(115, 65,  92 ),
    Accent       = Color3.fromRGB(255, 160, 192),
    AccentHover  = Color3.fromRGB(235, 130, 165),
    AccentDim    = Color3.fromRGB(220, 140, 170),
    Text         = Color3.fromRGB(255, 240, 245),
    TextSub      = Color3.fromRGB(210, 165, 185),
    TextDim      = Color3.fromRGB(130, 90,  112),
    ToggleOn     = Color3.fromRGB(255, 160, 192),
    ToggleOff    = Color3.fromRGB(78,  44,  62 ),
    Knob         = Color3.fromRGB(255, 248, 252),
    Success      = Color3.fromRGB(108, 210, 150),
    Warning      = Color3.fromRGB(255, 195, 80 ),
    Error        = Color3.fromRGB(240, 72,  88 ),
    Info         = Color3.fromRGB(180, 150, 255),
    Gold         = Color3.fromRGB(245, 200, 88 ),
    ScrollBar    = Color3.fromRGB(90,  52,  72 ),
    GlowIntensity   = 0.35,
    NeonStrength     = 0.5,
    StrokeThickness  = 1,
    CornerRadius     = 6,
    TransitionSpeed  = 0.2,
    ShadowOpacity    = 0.4,
}

-- â”€â”€ Cyber Theme â”€â”€
ThemeEngine.Themes.Cyber = {
    Background   = Color3.fromRGB(4,   6,   4  ),
    Secondary    = Color3.fromRGB(6,   10,  6  ),
    Tertiary     = Color3.fromRGB(10,  16,  10 ),
    Quaternary   = Color3.fromRGB(14,  22,  12 ),
    Border       = Color3.fromRGB(18,  32,  16 ),
    BorderHover  = Color3.fromRGB(28,  55,  24 ),
    Accent       = Color3.fromRGB(178, 255, 50 ),
    AccentHover  = Color3.fromRGB(148, 228, 20 ),
    AccentDim    = Color3.fromRGB(135, 210, 30 ),
    Text         = Color3.fromRGB(210, 255, 200),
    TextSub      = Color3.fromRGB(115, 195, 95 ),
    TextDim      = Color3.fromRGB(48,  92,  38 ),
    ToggleOn     = Color3.fromRGB(178, 255, 50 ),
    ToggleOff    = Color3.fromRGB(18,  32,  16 ),
    Knob         = Color3.fromRGB(230, 255, 220),
    Success      = Color3.fromRGB(178, 255, 50 ),
    Warning      = Color3.fromRGB(255, 210, 0  ),
    Error        = Color3.fromRGB(255, 40,  80 ),
    Info         = Color3.fromRGB(0,   220, 255),
    Gold         = Color3.fromRGB(255, 210, 0  ),
    ScrollBar    = Color3.fromRGB(20,  42,  16 ),
    GlowIntensity   = 0.55,
    NeonStrength     = 0.85,
    StrokeThickness  = 1.5,
    CornerRadius     = 4,
    TransitionSpeed  = 0.12,
    ShadowOpacity    = 0.3,
}

-- â”€â”€ Sunset Theme â”€â”€
ThemeEngine.Themes.Sunset = {
    Background   = Color3.fromRGB(14,  8,   18 ),
    Secondary    = Color3.fromRGB(22,  12,  28 ),
    Tertiary     = Color3.fromRGB(32,  16,  40 ),
    Quaternary   = Color3.fromRGB(42,  20,  54 ),
    Border       = Color3.fromRGB(55,  26,  68 ),
    BorderHover  = Color3.fromRGB(88,  42,  105),
    Accent       = Color3.fromRGB(255, 110, 70 ),
    AccentHover  = Color3.fromRGB(230, 85,  48 ),
    AccentDim    = Color3.fromRGB(220, 95,  58 ),
    Text         = Color3.fromRGB(255, 235, 220),
    TextSub      = Color3.fromRGB(210, 158, 138),
    TextDim      = Color3.fromRGB(115, 72,  88 ),
    ToggleOn     = Color3.fromRGB(255, 110, 70 ),
    ToggleOff    = Color3.fromRGB(55,  26,  68 ),
    Knob         = Color3.fromRGB(255, 248, 242),
    Success      = Color3.fromRGB(88,  210, 148),
    Warning      = Color3.fromRGB(255, 188, 55 ),
    Error        = Color3.fromRGB(238, 55,  75 ),
    Info         = Color3.fromRGB(175, 95,  255),
    Gold         = Color3.fromRGB(255, 195, 70 ),
    ScrollBar    = Color3.fromRGB(62,  30,  78 ),
    GlowIntensity   = 0.4,
    NeonStrength     = 0.6,
    StrokeThickness  = 1,
    CornerRadius     = 6,
    TransitionSpeed  = 0.2,
    ShadowOpacity    = 0.45,
}

-- ====================================================================
--  THEME ORDER & ACCENT PRESETS
-- ====================================================================

ThemeEngine.ThemeOrder = {
    "Dark", "Light", "Mocha", "Aqua", "Rose",
    "Midnight", "Neon", "Crimson", "Forest", "Ocean",
    "Sakura", "Cyber", "Sunset"
}

ThemeEngine.AccentPresets = {
    { Name = "Blue",    Color = Color3.fromRGB(91,  140, 255) },
    { Name = "Purple",  Color = Color3.fromRGB(168, 85,  247) },
    { Name = "Red",     Color = Color3.fromRGB(239, 68,  68 ) },
    { Name = "Teal",    Color = Color3.fromRGB(78,  204, 163) },
    { Name = "Amber",   Color = Color3.fromRGB(240, 180, 41 ) },
    { Name = "Pink",    Color = Color3.fromRGB(244, 114, 182) },
    { Name = "Cyan",    Color = Color3.fromRGB(0,   210, 220) },
    { Name = "Lime",    Color = Color3.fromRGB(132, 204, 22 ) },
    { Name = "Gold",    Color = Color3.fromRGB(255, 185, 30 ) },
    { Name = "Silver",  Color = Color3.fromRGB(175, 185, 210) },
    { Name = "Emerald", Color = Color3.fromRGB(52,  211, 153) },
    { Name = "Sky",     Color = Color3.fromRGB(56,  182, 255) },
    { Name = "Coral",   Color = Color3.fromRGB(255, 105, 97 ) },
    { Name = "Violet",  Color = Color3.fromRGB(139, 92,  246) },
}

-- ====================================================================
--  LOGO GRADIENT SYSTEM
-- ====================================================================

ThemeEngine.LOGO_GRADIENT_A = Color3.fromRGB(91, 140, 255)
ThemeEngine.LOGO_GRADIENT_B = Color3.fromRGB(139, 92, 246)

--- @function ApplyLogoGradient
--- @param frame Instance â€” The GuiObject to apply the gradient to
--- @description Applies the standard BorcaHub logo gradient (blueâ†’purple)
---   at a 135Â° angle to the specified frame.
---
--- FIX: Sebelumnya menggunakan Instance.new() lalu FindFirstChildOfClass()
--- yang tidak reliable. Sekarang langsung assign ke variabel.
function ThemeEngine.ApplyLogoGradient(frame)
    local existing = frame:FindFirstChildOfClass("UIGradient")
    if existing then existing:Destroy() end

    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, ThemeEngine.LOGO_GRADIENT_A),
        ColorSequenceKeypoint.new(1, ThemeEngine.LOGO_GRADIENT_B),
    })
    grad.Rotation = 135
    grad.Parent = frame
end

--- @function UpdateLogoGradientColors
--- @param colorA Color3 â€” New primary gradient color
--- @param colorB Color3 â€” New secondary gradient color
function ThemeEngine.UpdateLogoGradientColors(colorA, colorB)
    ThemeEngine.LOGO_GRADIENT_A = colorA
    ThemeEngine.LOGO_GRADIENT_B = colorB
end

-- ====================================================================
--  NEON GLOW ENGINE
-- ====================================================================

ThemeEngine._GlowEngine = {
    RegisteredElements = {},
    Active             = true,
    PulseSpeed         = 0.02,
    PulseRange         = {0.55, 0.85},
}

local GE = ThemeEngine._GlowEngine

function GE:Register(element, elementType)
    table.insert(self.RegisteredElements, {
        Element  = element,
        Type     = elementType,
        Original = {},
    })
end

function GE:Unregister(element)
    for i = #self.RegisteredElements, 1, -1 do
        if self.RegisteredElements[i].Element == element then
            table.remove(self.RegisteredElements, i)
            break
        end
    end
end

function GE:ApplyThemeGlow(theme)
    local accent   = theme.Accent
    local neonStr  = theme.NeonStrength or 0.5
    local glowColor = ThemeEngine.GlowColor(accent, neonStr)

    for _, entry in ipairs(self.RegisteredElements) do
        local el = entry.Element
        if not el or not el.Parent then continue end

        pcall(function()
            if entry.Type == "stroke" and el:IsA("UIStroke") then
                TweenService:Create(el, TweenInfo.new(0.3), {
                    Color = ThemeEngine.LerpColor(theme.Border, glowColor, neonStr * 0.3)
                }):Play()

            elseif entry.Type == "shadow" and el:IsA("ImageLabel") then
                TweenService:Create(el, TweenInfo.new(0.3), {
                    ImageColor3 = ThemeEngine.LerpColor(Color3.new(0,0,0), accent, neonStr * 0.15),
                    ImageTransparency = theme.ShadowOpacity or 0.4
                }):Play()

            elseif entry.Type == "badge" then
                TweenService:Create(el, TweenInfo.new(0.3), {
                    BackgroundColor3 = accent
                }):Play()

            elseif entry.Type == "separator" and el:IsA("Frame") then
                TweenService:Create(el, TweenInfo.new(0.3), {
                    BackgroundColor3 = ThemeEngine.LerpColor(theme.Border, accent, 0.3)
                }):Play()
            end
        end)
    end
end

function GE:CleanupDead()
    for i = #self.RegisteredElements, 1, -1 do
        local el = self.RegisteredElements[i].Element
        if not el or not el.Parent then
            table.remove(self.RegisteredElements, i)
        end
    end
end

-- ====================================================================
--  DYNAMIC THEME APPLICATION
-- ====================================================================

ThemeEngine._registeredObjects = {}

function ThemeEngine.RegisterForThemeUpdate(obj, property, themeKey)
    table.insert(ThemeEngine._registeredObjects, {
        Object   = obj,
        Property = property,
        ThemeKey = themeKey,
    })
end

function ThemeEngine.ApplyThemeToAll(theme, animated)
    if animated == nil then animated = true end
    local speed = theme.TransitionSpeed or 0.18

    -- Bersihkan referensi mati
    for i = #ThemeEngine._registeredObjects, 1, -1 do
        local entry = ThemeEngine._registeredObjects[i]
        if not entry.Object or not entry.Object.Parent then
            table.remove(ThemeEngine._registeredObjects, i)
        end
    end

    for _, entry in ipairs(ThemeEngine._registeredObjects) do
        local obj         = entry.Object
        local prop        = entry.Property
        local key         = entry.ThemeKey
        local targetColor = theme[key]

        if targetColor and obj and obj.Parent then
            pcall(function()
                if animated then
                    TweenService:Create(obj, TweenInfo.new(speed, Enum.EasingStyle.Quad), {
                        [prop] = targetColor
                    }):Play()
                else
                    obj[prop] = targetColor
                end
            end)
        end
    end

    GE:ApplyThemeGlow(theme)
    GE:CleanupDead()
end

function ThemeEngine.GetThemeByName(name)
    return ThemeEngine.Themes[name]
end

function ThemeEngine.GetThemeIndex(name)
    for i, n in ipairs(ThemeEngine.ThemeOrder) do
        if n == name then return i end
    end
    return 1
end

function ThemeEngine.GetNextTheme(currentName)
    local idx     = ThemeEngine.GetThemeIndex(currentName)
    local nextIdx = (idx % #ThemeEngine.ThemeOrder) + 1
    local name    = ThemeEngine.ThemeOrder[nextIdx]
    return name, ThemeEngine.Themes[name]
end

function ThemeEngine.GetPrevTheme(currentName)
    local idx     = ThemeEngine.GetThemeIndex(currentName)
    local prevIdx = ((idx - 2) % #ThemeEngine.ThemeOrder) + 1
    local name    = ThemeEngine.ThemeOrder[prevIdx]
    return name, ThemeEngine.Themes[name]
end

-- ====================================================================
--  ACCENT OVERRIDE SYSTEM
-- ====================================================================

function ThemeEngine.ApplyAccentOverride(theme, accentColor)
    theme.Accent      = accentColor
    theme.AccentHover = ThemeEngine.DarkenColor(accentColor, 0.12)
    theme.AccentDim   = ThemeEngine.DesaturateColor(accentColor, 0.1)
    theme.ToggleOn    = accentColor
    theme.Info        = accentColor
    return theme
end

function ThemeEngine.FindAccentPreset(name)
    for _, preset in ipairs(ThemeEngine.AccentPresets) do
        if preset.Name:lower() == name:lower() then
            return preset
        end
    end
    return nil
end

-- ====================================================================
--  NEON HEADER SEPARATOR EFFECT
-- ====================================================================

--- @function CreateNeonSeparator
--- @param parent Instance â€” Parent frame for the separator
--- @param theme table â€” Current theme palette
--- @return Instance â€” The separator Frame with animated gradient
---
--- FIX: Ganti RenderStepped:Wait() dengan task.wait() agar tidak
--- membebani render thread untuk animasi yang tidak butuh frame-perfect.
function ThemeEngine.CreateNeonSeparator(parent, theme)
    local sep = Instance.new("Frame")
    sep.Name                 = "NeonSeparator"
    sep.Parent               = parent
    sep.BackgroundColor3     = theme.Accent
    sep.BackgroundTransparency = 0
    sep.Position             = UDim2.new(0, 0, 1, -1)
    sep.Size                 = UDim2.new(1, 0, 0, 1)
    sep.BorderSizePixel      = 0
    sep.ZIndex               = (parent.ZIndex or 10) + 5

    local grad = Instance.new("UIGradient")
    grad.Parent       = sep
    grad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0.9),
        NumberSequenceKeypoint.new(0.3, 0.1),
        NumberSequenceKeypoint.new(0.7, 0.1),
        NumberSequenceKeypoint.new(1,   0.9),
    })
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   theme.Border),
        ColorSequenceKeypoint.new(0.5, theme.Accent),
        ColorSequenceKeypoint.new(1,   theme.Border),
    })

    -- FIX: Ganti RenderStepped:Wait() â†’ task.wait()
    --      agar tidak membebani render pipeline.
    task.spawn(function()
        local offset    = -1
        local direction = 1
        while sep and sep.Parent do
            offset = offset + direction * 0.008
            if offset >= 1 then
                direction = -1
            elseif offset <= -1 then
                direction = 1
            end
            grad.Offset = Vector2.new(offset, 0)
            task.wait()
        end
    end)

    GE:Register(sep, "separator")

    return sep
end

-- ====================================================================
--  TAB NEON UNDERLINE EFFECT
-- ====================================================================

function ThemeEngine.CreateTabNeonGlow(tabButton, theme)
    local glow = Instance.new("ImageLabel")
    glow.Name                 = "TabNeonGlow"
    glow.Parent               = tabButton
    glow.BackgroundTransparency = 1
    glow.AnchorPoint          = Vector2.new(0.5, 1)
    glow.Position             = UDim2.new(0.5, 0, 1, 4)
    glow.Size                 = UDim2.new(0.8, 0, 0, 8)
    glow.Image                = "rbxassetid://6015897843"
    glow.ImageColor3          = theme.Accent
    glow.ImageTransparency    = 0.7
    glow.ZIndex               = tabButton.ZIndex - 1
    glow.ScaleType            = Enum.ScaleType.Slice
    glow.SliceCenter          = Rect.new(49, 49, 450, 450)

    GE:Register(glow, "badge")

    return glow
end

-- ====================================================================
--  VERSION & META
-- ====================================================================

ThemeEngine.Version = "4.0.1"
ThemeEngine.Author  = "BorcaHub"

-- ====================================================================
--  RETURN MODULE
-- ====================================================================
return ThemeEngine

