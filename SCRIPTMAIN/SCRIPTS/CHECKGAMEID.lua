--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║         BorcaHub  •  ScriptMain / Scripts / CheckGameID.lua  ║
    ║                                                              ║
    ║  Validates the current PlaceId against a whitelist of        ║
    ║  supported games and returns metadata used by loaders and    ║
    ║  the UI (title, script category, allowed tiers, etc.).       ║
    ╚══════════════════════════════════════════════════════════════╝
--]]

-- ================================================================
--  SUPPORTED GAME REGISTRY
-- ================================================================
-- Structure per entry:
--   PlaceId (number)  →  {
--       Name      = "Display name shown in UI",
--       Short     = "Short tag used in script paths",
--       Tiers     = { "Free", "Premium" },   -- which tiers are supported
--       Version   = "script version string",
--       Note      = "optional note / warning shown to user",
--   }
-- ================================================================

local SupportedGames = {

    [0] = {
        Name    = "Universal",
        Short   = "Universal",
        Tiers   = { "Free", "Premium" },
        Version = "1.0.0",
        Note    = nil,
    },

    [286090429] = {
        Name    = "Arsenal",
        Short   = "Arsenal",
        Tiers   = { "Free", "Premium" },
        Version = "1.0.0",
        Note    = nil,
    },

    [17625359962] = {
        Name    = "RIVALS",
        Short   = "RIVALS",
        Tiers   = { "Premium" },
        Version = "1.0.0",
        Note    = nil,
    },

    [142823291] = {
        Name    = "Murder Mystery 2",
        Short   = "mm2",
        Tiers   = { "Free", "Premium" },
        Version = "1.0.0",
        Note    = nil,
    }

}  -- ← WAJIB ADA INI!
-- ================================================================
--  MODULE
-- ================================================================

local CheckGameID = {}

---Returns the current PlaceId.
function CheckGameID.GetPlaceId()
    return game.PlaceId
end

---Returns the game entry for a given PlaceId, or nil if unsupported.
---Falls back to the Universal entry (key 0) when useUniversalFallback is true.
---@param placeId            number
---@param useUniversalFallback boolean?
---@return table|nil
function CheckGameID.GetGame(placeId, useUniversalFallback)
    local entry = SupportedGames[placeId]
    if not entry and useUniversalFallback then
        entry = SupportedGames[0]
    end
    return entry
end

---Checks whether the current PlaceId is supported for the given tier.
---@param tier  string  "Free" | "Premium"
---@return boolean  supported
---@return table|nil  gameData
---@return string     message
function CheckGameID.Check(tier)
    local placeId = game.PlaceId
    local entry   = SupportedGames[placeId]

    -- Unknown game — fall back to Universal
    if not entry then
        local universal = SupportedGames[0]
        local tierAllowed = false
        for _, t in ipairs(universal.Tiers) do
            if t == tier then tierAllowed = true break end
        end
        if tierAllowed then
            return true, universal,
                string.format("[CheckGameID] Game %d not in registry — running Universal mode.", placeId)
        else
            return false, nil,
                string.format("[CheckGameID] Game %d unsupported for tier '%s'.", placeId, tier)
        end
    end

    -- Check tier
    local tierAllowed = false
    for _, t in ipairs(entry.Tiers) do
        if t == tier then tierAllowed = true break end
    end

    if not tierAllowed then
        return false, entry,
            string.format("[CheckGameID] '%s' does not support tier '%s'.", entry.Name, tier)
    end

    local msg = string.format("[CheckGameID] Supported game detected: %s (v%s)", entry.Name, entry.Version)
    if entry.Note then
        msg = msg .. " — " .. entry.Note
    end
    return true, entry, msg
end

---Returns the full supported game registry (read-only copy).
function CheckGameID.GetRegistry()
    return SupportedGames
end

---Pretty-prints supported game list to the output console (debug helper).
function CheckGameID.PrintSupported()
    print("[CheckGameID] Supported games:")
    for id, data in pairs(SupportedGames) do
        if id ~= 0 then
            print(string.format("  • %-25s  ID: %-14d  Tiers: %s",
                data.Name, id, table.concat(data.Tiers, ", ")
            ))
        end
    end
end

return CheckGameID
