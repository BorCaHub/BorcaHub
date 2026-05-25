--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║              BorcaHub  •  UIMain / Assets / Icons.lua        ║
    ║                                                              ║
    ║  Centralised icon registry.                                  ║
    ║  All values are plain Unicode / UTF-8 characters so they     ║
    ║  render correctly inside Roblox TextLabels on any executor.  ║
    ╚══════════════════════════════════════════════════════════════╝
--]]

local Icons = {}

-- ================================================================
--  NAVIGATION / GENERAL
-- ================================================================
Icons.Home          = "⌂"
Icons.Settings      = "⚙"
Icons.Info          = "ℹ"
Icons.Close         = "✕"
Icons.Back          = "←"
Icons.Forward       = "→"
Icons.Up            = "↑"
Icons.Down          = "↓"
Icons.Refresh       = "↺"
Icons.Search        = "🔍"
Icons.Pin           = "📌"
Icons.Lock          = "🔒"
Icons.Unlock        = "🔓"
Icons.Key           = "🔑"
Icons.Star          = "★"
Icons.StarOutline   = "☆"
Icons.Check         = "✓"
Icons.Cross         = "✗"
Icons.Warning       = "⚠"
Icons.Error         = "✖"
Icons.Success       = "✔"
Icons.Question      = "?"
Icons.Dot           = "•"
Icons.Arrow         = "›"
Icons.ArrowDouble   = "»"

-- ================================================================
--  TAB / CATEGORY ICONS
-- ================================================================
Icons.Combat        = "⚔"
Icons.Aim           = "🎯"
Icons.ESP           = "👁"
Icons.Player        = "👤"
Icons.Players       = "👥"
Icons.Movement      = "🏃"
Icons.Fly           = "✈"
Icons.Speed         = "⚡"
Icons.Teleport      = "⭐"
Icons.Misc          = "🔧"
Icons.Visual        = "🎨"
Icons.World         = "🌐"
Icons.Farm          = "🌾"
Icons.Script        = "📜"
Icons.Gun           = "🔫"
Icons.Shield        = "🛡"
Icons.Heart         = "♥"
Icons.Skull         = "☠"
Icons.Fire          = "🔥"
Icons.Thunder       = "⚡"
Icons.Magic         = "✨"
Icons.Radar         = "📡"
Icons.Camera        = "📷"
Icons.Map           = "🗺"
Icons.Compass       = "🧭"
Icons.Music         = "♪"
Icons.Bell          = "🔔"
Icons.BellOff       = "🔕"
Icons.Folder        = "📁"
Icons.File          = "📄"
Icons.Trash         = "🗑"
Icons.Save          = "💾"
Icons.Copy          = "📋"
Icons.Edit          = "✏"
Icons.Code          = "⌨"
Icons.Terminal      = ">"
Icons.Diamond       = "◆"
Icons.Circle        = "●"
Icons.Square        = "■"
Icons.Triangle      = "▲"
Icons.Crown         = "♛"
Icons.Premium       = "💎"
Icons.Free          = "🆓"
Icons.Coins         = "🪙"
Icons.Trophy        = "🏆"
Icons.Gift          = "🎁"

-- ================================================================
--  STATUS / INDICATOR
-- ================================================================
Icons.Online        = "●"   -- typically rendered in green
Icons.Offline       = "○"   -- typically rendered in red / dim
Icons.Pending       = "◌"
Icons.Active        = "▶"
Icons.Paused        = "‖"
Icons.Stopped       = "■"

-- ================================================================
--  UTILITY FUNCTION
-- ================================================================

---Get an icon by name; falls back to a safe default if not found.
---@param name  string   Key in the Icons table.
---@param default string? Optional fallback string.
---@return string
function Icons.Get(name, default)
    return Icons[name] or default or "•"
end

---Returns the full icon table (for iteration / debug).
function Icons.All()
    return Icons
end

return Icons
