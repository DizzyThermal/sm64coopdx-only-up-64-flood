moveset = false
cheats = false
ou64_moveset = false

ENABLE_HEIGHT_METER = true
ENABLE_SCOREBOARD = true

local gold_medal = get_texture_info("gold-medal")
local silver_medal = get_texture_info("silver-medal")
local bronze_medal = get_texture_info("bronze-medal")
local medals = {
    gold_medal,
    silver_medal,
    bronze_medal,
}
local height_meter = get_texture_info("height-meter")

for mod in pairs(gActiveMods) do
    if gActiveMods[mod].name:find("Object Spawner") or gActiveMods[mod].name:find("Noclip") then
        cheats = true
    end
    if gActiveMods[mod].name:find("Only Up 64 Plugin") then
        ou64_moveset = true
    end
end

for i in pairs(gActiveMods) do
    if (gActiveMods[i].incompatible ~= nil and gActiveMods[i].incompatible:find("moveset"))
      or gActiveMods[i].name:find("Squishy's Server")
      or (gActiveMods[i].name:find("Pasta") and gActiveMods[i].name:find("Castle"))
      or gActiveMods[i].name:find("Only Up 64 Plugin") then
        moveset = true
    end
end

-- localize functions to improve performance
local is_player_active,table_insert,is_game_paused,djui_hud_set_color,math_max,math_min = is_player_active,table.insert,is_game_paused,djui_hud_set_color,math.max,math.min

rom_hack_cam_set_collisions(false)

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

function render_flood_hud()
    djui_hud_set_font(FONT_NORMAL)
    djui_hud_set_resolution(RESOLUTION_DJUI)

    local players = {}
    for i = 0, MAX_PLAYERS - 1 do
        players[i + 1] = {
            localIndex = i,
            name = "",
            points = 0,
            percent_done = 0.0,
        }
    end

    local j = 0
    for i = 0, MAX_PLAYERS - 1 do
        if gNetworkPlayers[i].connected then
            j = j + 1
            local area_height = gLevels[gGlobalSyncTable.area].goalPos.y - gLevels[gGlobalSyncTable.area].startPos.y
            local percent_done = (gMarioStates[i].pos.y - gLevels[gGlobalSyncTable.area].startPos.y) / area_height * 100.0
            percent_done = math_max(percent_done, 0)
            percent_done = math_min(percent_done, 100)
            if gMarioStates[i].health <= 0xff then
                percent_done = -1
            elseif gPlayerSyncTable[i].finished then
                percent_done = 10000 - gPlayerSyncTable[i].finishTime
            end
            players[network_global_index_from_local(i) + 1] = {
                localIndex = i,
                name = string_without_hex(gNetworkPlayers[i].name),
                points = gGlobalSyncTable.points[network_global_index_from_local(i)],
                percent_done = percent_done,
            }
        else
            gGlobalSyncTable.points[network_global_index_from_local(i)] = 0
        end
    end

    if ENABLE_SCOREBOARD then
        -- Sort by Points (to gather medals and colors)
        table.sort(players, function(p1, p2)
            return p1.points > p2.points
        end)
        place = 1
        lastPoint = 0
        first = true
        for i, p in ipairs(players) do
            if p.name ~= "" then
                r, g, b = 255, 255, 255
                medal = nil
                if p.points > 0 then
                    if p.points ~= lastPoint then
                        lastPoint = p.points
                        if not first then
                            place = place + 1
                        else
                            first = false
                        end
                    end
                    -- Set Medal
                    medal = medals[place]
                    if place == 1 then
                        -- 1st - Gold 
                        r, g, b = 255, 217, 0
                    elseif place == 2 then
                        -- 2nd - Silver
                        r, g, b = 180, 186, 189
                    elseif place == 3 then
                        -- 3rd - Bronze
                        r, g, b = 205, 127, 50
                    else
                        -- 4th+
                        medal = nil
                    end
                end
                players[i].medal = medal
                players[i].color = { r = r, g = g, b = b }
            end
        end

        -- Sort for Scoreboard (including percent_done)
        table.sort(players, function(p1, p2)
            if p1.points == p2.points then
                if gGlobalSyncTable.roundState ~= ROUND_STATE_ACTIVE
                or p1.percent_done == p2.percent_done then
                    return p1.name:upper() < p2.name:upper()
                else
                    return p1.percent_done > p2.percent_done
                end
            else
                if gGlobalSyncTable.roundState ~= ROUND_STATE_ACTIVE
                or p1.percent_done == p2.percent_done then
                    return p1.points > p2.points
                else
                    return p1.percent_done > p2.percent_done
                end
            end
        end)

        -- Scoreboard
        local x = 24
        local xPad = 10
        local width = 316
        local widthPad = 60
        local row_height = 36
        local y = 170
        local yPad = 10
        local height = (j + 2) * row_height
        local iconPad = 32
        local headPad = 40

        djui_hud_set_adjusted_color(0, 0, 0, 128)
        djui_hud_render_rect(x - xPad, y + yPad - 6, width + widthPad + xPad + iconPad, height + yPad + 16)
        djui_hud_set_adjusted_color(255, 255, 255, 255)

        local title_extra = " - Lobby"
        if gGlobalSyncTable.roundState == ROUND_STATE_ACTIVE then
            local area = gGlobalSyncTable.area
            if area == 0 then
                area = 8
            end
            title_extra = " - Area " .. area
        end 
        djui_hud_print_text("Only Up 64 Flood Scoreboard" .. title_extra, x + xPad, y + (2 * yPad), 1)
        djui_hud_print_text("---------------------------------", x, y + (4 * yPad) + 5, 1)

        j = 0
        for i, p in ipairs(players) do
            if p.name ~= "" then
                r, g, b = 255, 255, 255
                if p.color ~= nil then
                    r, g, b = p.color.r, p.color.g, p.color.b
                end

                local extra_string = ""
                local alpha = if_then_else(gMarioStates[p.localIndex].health <= 0xff or is_game_paused(), 100, 255)
                local pDone = 0
                if gGlobalSyncTable.roundState == ROUND_STATE_ACTIVE then
                    if gPlayerSyncTable[p.localIndex].finished
                    and gPlayerSyncTable[p.localIndex].finishTime ~= nil then
                        extra_string = " (" .. gPlayerSyncTable[p.localIndex].finishTime .. "s)"
                    elseif gMarioStates[p.localIndex].health > 0xff then
                        pDone = math_max(p.percent_done, 0)
                        pDone = math_min(pDone, 100)
                        extra_string = " (" .. string.format("%.1f", pDone) .. "%)"
                    end
                end
                djui_hud_set_adjusted_color(255, 255, 255, alpha)
                if p.medal ~= nil then
                    local medalXPad = 6
                    local medalYPad = 4
                    djui_hud_render_texture(p.medal, x + medalXPad, y + yPad + medalYPad + ((j + 2) * row_height), 0.2, 0.2)
                end
                local headXPad = 6
                local headYPad = 1
                render_player_head(p.localIndex, x + iconPad + headXPad, y + yPad + headYPad + ((j + 2) * row_height), 1.8, 1.8)
                djui_hud_set_adjusted_color(r, g, b, alpha)
                djui_hud_print_text(tostring(p.points) .. " pts" .. " : " .. p.name .. extra_string, x + xPad - 4 + iconPad + headPad, y + yPad + ((j + 2) * row_height), 1)
                j = j + 1
            end
        end
    end
    if ENABLE_HEIGHT_METER then
        table.sort(players, function(p1, p2)
            if p1.percent_done == p2.percent_done then
                return p1.name:upper() > p2.name:upper()
            else
                return p1.percent_done < p2.percent_done
            end
        end)

        -- Height Meter
        local heightX = djui_hud_get_screen_width() - 55
        local heightY = 225
        local heightHeight = 388
        local alpha = if_then_else(is_game_paused(), 100, 255)
        r, g, b, a = 255, 255, 255, alpha
        djui_hud_set_adjusted_color(r, g, b, alpha)
        djui_hud_render_texture(height_meter, heightX + 5, heightY, 4.0, 4.0)
        for i, p in ipairs(players) do
            -- Draw Player Head on Height
            if p ~= nil then
                if gNetworkPlayers[p.localIndex].connected then
                    local pDone = 0
                    pDone = math_max(p.percent_done, 0)
                    pDone = math_min(pDone, 100)
                    render_player_head(p.localIndex, heightX, heightY + heightHeight - 10 - (heightHeight * pDone / 100), 2, 2)
                end
            end
        end
    end
end