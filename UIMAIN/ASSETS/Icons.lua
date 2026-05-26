--[[
    â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
    â•‘              BorcaHub  â€¢  UIMain / Assets / Icons.lua        â•‘
    â•‘                                                              â•‘
    â•‘  Centralised icon registry.                                  â•‘
    â•‘  All values are plain Unicode / UTF-8 characters so they     â•‘
    â•‘  render correctly inside Roblox TextLabels on any executor.  â•‘
    â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--]]

local Icons = {}

-- ================================================================
--  NAVIGATION / GENERAL
-- ================================================================
Icons.Home          = "âŒ‚"
Icons.Settings      = "âš™"
Icons.Info          = "â„¹"
Icons.Close         = "âœ•"
Icons.Back          = "â†"
Icons.Forward       = "â†’"
Icons.Up            = "â†‘"
Icons.Down          = "â†“"
Icons.Refresh       = "â†º"
Icons.Search        = "ðŸ”"
Icons.Pin           = "ðŸ“Œ"
Icons.Lock          = "ðŸ”’"
Icons.Unlock        = "ðŸ”“"
Icons.Key           = "ðŸ”‘"
Icons.Star          = "â˜…"
Icons.StarOutline   = "â˜†"
Icons.Check         = "âœ“"
Icons.Cross         = "âœ—"
Icons.Warning       = "âš "
Icons.Error         = "âœ–"
Icons.Success       = "âœ”"
Icons.Question      = "?"
Icons.Dot           = "â€¢"
Icons.Arrow         = "â€º"
Icons.ArrowDouble   = "Â»"

-- ================================================================
--  TAB / CATEGORY ICONS
-- ================================================================
Icons.Combat        = "âš”"
Icons.Aim           = "ðŸŽ¯"
Icons.ESP           = "ðŸ‘"
Icons.Player        = "ðŸ‘¤"
Icons.Players       = "ðŸ‘¥"
Icons.Movement      = "ðŸƒ"
Icons.Fly           = "âœˆ"
Icons.Speed         = "âš¡"
Icons.Teleport      = "â­"
Icons.Misc          = "ðŸ”§"
Icons.Visual        = "ðŸŽ¨"
Icons.World         = "ðŸŒ"
Icons.Farm          = "ðŸŒ¾"
Icons.Script        = "ðŸ“œ"
Icons.Gun           = "ðŸ”«"
Icons.Shield        = "ðŸ›¡"
Icons.Heart         = "â™¥"
Icons.Skull         = "â˜ "
Icons.Fire          = "ðŸ”¥"
Icons.Thunder       = "âš¡"
Icons.Magic         = "âœ¨"
Icons.Radar         = "ðŸ“¡"
Icons.Camera        = "ðŸ“·"
Icons.Map           = "ðŸ—º"
Icons.Compass       = "ðŸ§­"
Icons.Music         = "â™ª"
Icons.Bell          = "ðŸ””"
Icons.BellOff       = "ðŸ”•"
Icons.Folder        = "ðŸ“"
Icons.File          = "ðŸ“„"
Icons.Trash         = "ðŸ—‘"
Icons.Save          = "ðŸ’¾"
Icons.Copy          = "ðŸ“‹"
Icons.Edit          = "âœ"
Icons.Code          = "âŒ¨"
Icons.Terminal      = ">"
Icons.Diamond       = "â—†"
Icons.Circle        = "â—"
Icons.Square        = "â– "
Icons.Triangle      = "â–²"
Icons.Crown         = "â™›"
Icons.Premium       = "ðŸ’Ž"
Icons.Free          = "ðŸ†“"
Icons.Coins         = "ðŸª™"
Icons.Trophy        = "ðŸ†"
Icons.Gift          = "ðŸŽ"

-- ================================================================
--  STATUS / INDICATOR
-- ================================================================
Icons.Online        = "â—"   -- typically rendered in green
Icons.Offline       = "â—‹"   -- typically rendered in red / dim
Icons.Pending       = "â—Œ"
Icons.Active        = "â–¶"
Icons.Paused        = "â€–"
Icons.Stopped       = "â– "

-- ================================================================
--  UTILITY FUNCTION
-- ================================================================

---Get an icon by name; falls back to a safe default if not found.
---@param name  string   Key in the Icons table.
---@param default string? Optional fallback string.
---@return string
function Icons.Get(name, default)
    return Icons[name] or default or "â€¢"
end

---Returns the full icon table (for iteration / debug).
function Icons.All()
    return Icons
end

return Icons

