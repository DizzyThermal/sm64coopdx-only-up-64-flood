-- Localizing for performance
local djui_hud_set_color,is_game_paused,is_player_active,math_floor,math_max,math_min,string_format,table_insert = djui_hud_set_color,is_game_paused,is_player_active,math.floor,math.max,math.min,string.format,table.insert

-- Set Flood Description Variables (TODO: Do this every round to update description?)
if ou64_plugin_active and
        _G.ou64_plugin_api.settings.enable_moveset then
    ou64_flood_ou64_moveset = true
end
for i in pairs(gActiveMods) do
    if (gActiveMods[i].incompatible ~= nil and
                gActiveMods[i].incompatible:find("moveset")) or
            gActiveMods[i].name:find("Squishy's Server") or 
            (gActiveMods[i].name:find("Pasta") and
                gActiveMods[i].name:find("Castle")) then
        ou64_flood_moveset = true
    end
    if gActiveMods[i].name:find("Object Spawner") or
            gActiveMods[i].name:find("Noclip") or
            gActiveMods[i].name:find("Cheats") then
        ou64_flood_cheats = true
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
    for match in (s):gmatch(string_format("[^%s]+", " ")) do
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

function get_player_states()
    local active_count = 0
    local dead_count = 0
    local finished_count = 0
    local player_count = 0
    for i = 0, MAX_PLAYERS - 1 do
        if gNetworkPlayers[i].connected and
                (gServerSettings.headlessServer == 0 or
                    i ~= server_local_index) then
            local m = gMarioStates[i]
            player_count = player_count + 1
            if gPlayerSyncTable[i].finished and
                        m.health > 0xFF then
                -- Player Finished
                finished_count = finished_count + 1
            elseif m.health > 0xFF then
                -- Player Active
                active_count = active_count + 1
            elseif m.health <= 0xFF then
                -- Player is Dead
                dead_count = dead_count + 1
            end
        end
    end

    return {
        active = active_count,
        dead = dead_count,
        finished = finished_count,
        total = player_count,
    }
end

function players_all_dead()
    player_states = get_player_states()
    return player_states.dead == player_states.total
end

function players_all_inactive()
    player_states = get_player_states()
    return player_states.active == 0
end

function format_msec(total_msec)
    local total_seconds = math_floor(total_msec / 1000)
    local millis = total_msec % 1000
    local seconds = total_seconds % 60
    local total_minutes = math_floor(total_seconds / 60)
    local minutes = total_minutes % 60
    local hours = math_floor(total_minutes / 60)

    if hours > 0 then
        return string_format("%d:%02d:%02d.%03d", hours, minutes, seconds, millis)
    elseif minutes > 0 then
        return string_format("%d:%02d.%03d", minutes, seconds, millis)
    else
        return string_format("%d.%03d", seconds, millis)
    end
end
