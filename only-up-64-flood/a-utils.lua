-- Localizing for performance
local is_player_active,table_insert,is_game_paused,djui_hud_set_color,math_max,math_min = is_player_active,table.insert,is_game_paused,djui_hud_set_color,math.max,math.min

-- Set Flood Description Variables (TODO: Do this every round to update description?)
if _G.ou64_plugin_active and
        _G.ou64_enable_moveset then
    _G.ou64_flood_ou64_moveset = true
end
for i in pairs(gActiveMods) do
    if (gActiveMods[i].incompatible ~= nil and
                gActiveMods[i].incompatible:find("moveset")) or
            gActiveMods[i].name:find("Squishy's Server") or 
            (gActiveMods[i].name:find("Pasta") and
                gActiveMods[i].name:find("Castle")) then
        _G.ou64_flood_moveset = true
    end
    if gActiveMods[i].name:find("Object Spawner") or
            gActiveMods[i].name:find("Noclip") or
            gActiveMods[i].name:find("Cheats") then
        _G.ou64_flood_cheats = true
    end
end

function switch(param, case_table)
    local case = case_table[param]
    if case then return case() end
    local def = case_table['default']
    return def and def() or nil
end

--- @param m MarioState
function active_player(m)
    local np = gNetworkPlayers[m.playerIndex]
    if m.playerIndex == 0 then
        return 1
    end
    if not np.connected then
        return 0
    end
    if np.currCourseNum ~= gNetworkPlayers[0].currCourseNum then
        return 0
    end
    if np.currActNum ~= gNetworkPlayers[0].currActNum then
        return 0
    end
    if np.currLevelNum ~= gNetworkPlayers[0].currLevelNum then
        return 0
    end
    if np.currAreaIndex ~= gNetworkPlayers[0].currAreaIndex then
        return 0
    end
    return is_player_active(m)
end

function if_then_else(cond, if_true, if_false)
    if cond then return if_true end
    return if_false
end

function string_without_hex(name)
    local s = ''
    local inSlash = false
    for i = 1, #name do
        local c = name:sub(i,i)
        if c == '\\' then
            inSlash = not inSlash
        elseif not inSlash then
            s = s .. c
        end
    end
    return s
end

function split(s)
    local result = {}
    for match in (s):gmatch(string.format("[^%s]+", " ")) do
        table_insert(result, match)
    end
    return result
end

function djui_hud_set_adjusted_color(r, g, b, a)
    local multiplier = 1
    if is_game_paused() then multiplier = 0.5 end
    djui_hud_set_color(r * multiplier, g * multiplier, b * multiplier, a)
end

function SEQUENCE_ARGS(priority, seqId)
    return ((priority << 8) | seqId)
end

--- @param m MarioState
function mario_set_full_health(m)
    m.health = 0x880
    m.healCounter = 0
    m.hurtCounter = 0
end

--
-- render_player_head modified from EmilyEmmi's Shine Thief
-- https://discord.com/channels/752682015614173235/755907254318006362/1146275236325625897
--
-- the actual head render function.
--- @param index integer
--- @param x integer
--- @param y integer
--- @param scaleX number
--- @param scaleY number
function render_player_head(index, x, y, scaleX, scaleY)
    local HEAD_HUD = get_texture_info("hud_head_recolor")

    local PART_ORDER = {
        SKIN,
        HAIR,
        CAP,
    }
    local m = gMarioStates[index]
    local np = gNetworkPlayers[index]

    local alpha = if_then_else(m.health <= 0xff or is_game_paused(), 100, 255)
    local tileY = m.character.type
    for i = 1, #(PART_ORDER) do
        local color = {r = 255, g = 255, b = 255}
        local part = PART_ORDER[i]
        if tileY == 2 and part == HAIR then
            part = GLOVES
        end
        local color = network_player_get_palette_color(np, part)

        djui_hud_set_color(color.r, color.g, color.b, alpha)
        djui_hud_render_texture_tile(HEAD_HUD, x, y, scaleX, scaleY, (i-1)*16, tileY*16, 16, 16)
    end

    djui_hud_set_color(255, 255, 255, alpha)
    djui_hud_render_texture_tile(HEAD_HUD, x, y, scaleX, scaleY, (#PART_ORDER)*16, tileY*16, 16, 16)

    djui_hud_render_texture_tile(HEAD_HUD, x, y, scaleX, scaleY, (#PART_ORDER+1)*16, tileY*16, 16, 16)
end
