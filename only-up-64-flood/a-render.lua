local math_abs,math_max,math_min,string_format,string_match,string_sub = math.abs,math.max,math.min,string.format,string.match,string.sub

function djui_hud_print_colored_text(string, x, y, scale, limit)
    local total_space = 0

    local escaping = false
    local char_idx = 1
    local characters_rendered = 0
    while char_idx <= #string do
        local c = string_sub(string, char_idx, char_idx)
        if c == "\\" then
            if not escaping then
                local char_pointer = char_idx + 1
                while char_pointer < #string and
                        string_sub(string, char_pointer, char_pointer) ~= "\\" do
                    char_pointer = char_pointer + 1
                end
                local substring = string_sub(string, char_idx + 1, char_pointer - 1)
                local hex_match = (string_match(substring, "^#?%x%x%x$") or string_match(substring, "^#?%x%x%x%x%x%x$"))
                if hex_match ~= nil then
                    local r = #hex_match == 7 and string_sub(hex_match, 2, 3) or string_sub(hex_match, 2, 2)
                    local g = #hex_match == 7 and string_sub(hex_match, 4, 5) or string_sub(hex_match, 3, 3)
                    local b = #hex_match == 7 and string_sub(hex_match, 6, 7) or string_sub(hex_match, 4, 4)
                    if #r == 1 then
                        r = r .. r
                        g = g .. g
                        b = b .. b
                    end
                    djui_hud_set_color(
                        tonumber(r, 16),
                        tonumber(g, 16),
                        tonumber(b, 16),
                        255
                    )
                else
                    escaping = true
                end
                char_idx = char_pointer + 1
            elseif escaping then
                escaping = false
            end
        else
            djui_hud_print_text(c, (x + total_space) * scale, y, scale)
            total_space = total_space + djui_hud_measure_text(c)
            characters_rendered = characters_rendered + 1
            if limit ~= nil and characters_rendered >= limit then
                djui_hud_print_text("...", (x + total_space) * scale, y, scale)
                djui_hud_set_color(255, 255, 255, 255)
                return
            end
        char_idx = char_idx + 1
        end
    end

    djui_hud_set_color(255, 255, 255, 255)
end

-- render_player_head - modified from EmilyEmmi's Shine Thief
-- https://discord.com/channels/752682015614173235/755907254318006362/1146275236325625897
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
        local part = PART_ORDER[i]
        if tileY == 2 and part == HAIR then
            part = GLOVES
        end
        local color = network_player_get_override_palette_color(np, part)

        djui_hud_set_color(color.r, color.g, color.b, alpha)
        djui_hud_render_texture_tile(HEAD_HUD, x, y, scaleX, scaleY, (i-1)*16, tileY*16, 16, 16)
    end

    djui_hud_set_color(255, 255, 255, alpha)
    djui_hud_render_texture_tile(HEAD_HUD, x, y, scaleX, scaleY, (#PART_ORDER)*16, tileY*16, 16, 16)

    djui_hud_render_texture_tile(HEAD_HUD, x, y, scaleX, scaleY, (#PART_ORDER+1)*16, tileY*16, 16, 16)
end

function render_flood_scoreboard()
    djui_hud_set_resolution(RESOLUTION_DJUI)

    local anchor_x = 24
    local anchor_y = 24
    local top_height = _G.ou64_top_height

    -- Gather Players
    local server_local_index = network_player_from_global_index(0).localIndex
    local players_running = {}
    for i = 0, MAX_PLAYERS - 1 do
        if gNetworkPlayers[i].connected and
                (gServerSettings.headlessServer == 0 or
                    i ~= server_local_index) and
                gPlayerSyncTable[i].points ~= nil then
            local area_top = _G.ou64_flood_levels[gGlobalSyncTable.area].goal_pos.y
            local area_bottom = _G.ou64_flood_levels[gGlobalSyncTable.area].start_pos.y
            local area_height = area_top - area_bottom
            local percent_done = (gMarioStates[i].pos.y - area_bottom) / area_height * 100.0
            percent_done = math_max(percent_done, 0)
            percent_done = math_min(percent_done, 100)
            if gMarioStates[i].health <= 0xFF then
                percent_done = -1
            elseif gPlayerSyncTable[i].finished then
                percent_done = 10000 - gPlayerSyncTable[i].finish_time
            end
            table.insert(players_running, {
                local_index = i,
                name = gNetworkPlayers[i].name,
                points = gPlayerSyncTable[i].points,
                percent_done = percent_done,
                medal = nil,
                color = { r = 255, g = 255, b = 255 },
            })
        else
            -- TODO: NEEDED?
            gPlayerSyncTable[i].points = 0
        end
    end

    table.sort(players_running, function(p1, p2)
        if p1.points == p2.points then
            return p1.name:upper() > p2.name:upper()
        else
            return p1.points > p2.points
        end
    end)

    place = 1
    last_point = 0
    first = true
    for i, entry in ipairs(players_running) do
        if entry.name ~= "" then
            r, g, b = 255, 255, 255
            medal = nil
            if entry.points > 0 then
                if entry.points ~= last_point then
                    last_point = entry.points
                    if not first then
                        place = place + 1
                    else
                        first = false
                    end
                end
                -- Set Medal
                medal = nil
                if place == 1 then
                    -- 1st - Gold 
                    r, g, b = 255, 217, 0
                    medal = _G.ou64_gold_medal
                elseif place == 2 then
                    -- 2nd - Silver
                    r, g, b = 180, 186, 189
                    medal = _G.ou64_silver_medal
                elseif place == 3 then
                    -- 3rd - Bronze
                    r, g, b = 205, 127, 50
                    medal = _G.ou64_bronze_medal
                else
                    -- 4th+
                    medal = nil
                end
            end
            players_running[i].medal = medal
            players_running[i].color = { r = r, g = g, b = b }
        end
    end

    -- Sort for Scoreboard (including percent_done)
    table.sort(players_running, function(p1, p2)
        if p1.points == p2.points then
            if gGlobalSyncTable.round_state ~= 1 or
                    p1.percent_done == p2.percent_done then
                return p1.name:upper() < p2.name:upper()
            else
                return p1.percent_done > p2.percent_done
            end
        else
            if gGlobalSyncTable.round_state ~= 1 or
                    p1.percent_done == p2.percent_done then
                return p1.points > p2.points
            else
                return p1.percent_done > p2.percent_done
            end
        end
    end)

    -- Background Box
    local player_count = players_running ~= nil and #players_running or 0
    local scoreboard_height = 34 * player_count + 42
    djui_hud_set_adjusted_color(0, 0, 0, 128)
    djui_hud_render_rect(anchor_x, anchor_y, 430, scoreboard_height)

    -- Flood Scoreboard Title
    djui_hud_set_font(FONT_MENU)
    local scoreboard_title = "Only Up "
    local title_length = djui_hud_measure_text(scoreboard_title) / 1.5
    local scoreboard_subtitle = "Flood"
    local subtitle_length = djui_hud_measure_text(scoreboard_subtitle) / 1.5
    local area = "Lobby"
    if gGlobalSyncTable.round_state == 1 then
        local area_index = gGlobalSyncTable.area
        if area_index == 0 then
            area_index = 8
        end
        area = string_format("Area %d", area_index)
    end

    djui_hud_set_adjusted_color(250, 255, 32, 255)
    djui_hud_print_text(scoreboard_title, anchor_x - 8, anchor_y - 20, _G.ou64_run_timer_scale / 1.5)
    djui_hud_set_adjusted_color(0, 131, 255, 255)
    djui_hud_print_text(scoreboard_subtitle, anchor_x - 8 + title_length, anchor_y - 20, _G.ou64_run_timer_scale / 1.5)
    djui_hud_set_adjusted_color(255, 255, 255, 255)
    djui_hud_print_text(string_format(": %s", area), anchor_x - 8 + title_length + subtitle_length, anchor_y - 20, _G.ou64_run_timer_scale / 1.5)

    -- Players Running
    djui_hud_set_adjusted_color(255, 255, 255, 255)
    djui_hud_set_font(FONT_ALIASED)

    local x_pad = 10
    local y_pad = 28
    local icon_pad = 32
    local head_pad = 40

    local y_offset = 0
    for i, entry in ipairs(players_running) do
        local entry_name = entry.name
        if entry_name == string_without_hex(entry.name) then
            local cap_color = network_player_get_override_palette_color(gNetworkPlayers[entry.idx], CAP)
            local cap_r = 127 + cap_color.r // 2
            local cap_g = 127 + cap_color.g // 2
            local cap_b = 127 + cap_color.b // 2
            entry_name = "\\#" .. string_format("%02x", cap_r) .. string_format("%02x", cap_g) .. string_format("%02x", cap_b) .. "\\" .. entry_name
        end

        r, g, b = entry.color.r, entry.color.g, entry.color.b
        local extra_string = "\\#FFFFFF\\ "
        local alpha = if_then_else(gMarioStates[entry.local_index].health <= 0xFF or is_game_paused(), 100, 255)
        local pDone = 0
        if gGlobalSyncTable.round_state == 1 then
            if gPlayerSyncTable[entry.local_index].finished and
                    gPlayerSyncTable[entry.local_index].finish_time ~= nil then
                extra_string = extra_string .. " (" .. gPlayerSyncTable[entry.local_index].finish_time .. "s)"
            elseif gMarioStates[entry.local_index].health > 0xFF then
                pDone = math_max(entry.percent_done, 0)
                pDone = math_min(pDone, 100)
                extra_string = extra_string .. " (" .. string_format("%.1f", pDone) .. "%)"
            end
        end
        djui_hud_set_adjusted_color(255, 255, 255, alpha)
        if entry.medal ~= nil then
            local medal_x_pad = 6
            local medal_y_pad = 4
            djui_hud_render_texture(entry.medal, anchor_x + medal_x_pad, anchor_y + y_pad + medal_y_pad + y_offset, 0.2, 0.2)
        end
        local head_x_pad = 6
        local head_y_pad = 1
        render_player_head(entry.local_index, anchor_x + icon_pad + head_x_pad, anchor_y + y_pad + head_y_pad + y_offset, 1.8, 1.8)
        local points_string = string_format("\\#%02x%02x%02x\\%d pts\\#FFFFFF\\", r, g, b, entry.points)
        djui_hud_print_colored_text(points_string .. " :  " .. entry_name .. extra_string, anchor_x + x_pad - 4 + icon_pad + head_pad, anchor_y + y_pad + y_offset, 1)
        y_offset = y_offset + 34
    end
end

function set_player_descriptions(m)
    if m.health > 0xFF and
            gPlayerSyncTable[m.playerIndex].finished then
        network_player_set_description(gNetworkPlayers[m.playerIndex], "Finished", 75, 255, 75, 255)
    elseif m.health > 0xFF then
        network_player_set_description(gNetworkPlayers[m.playerIndex], "Alive", 75, 255, 75, 255)
    else
        network_player_set_description(gNetworkPlayers[m.playerIndex], "Dead", 255, 75, 75, 255)
    end
end

function debug_render_debug_info()
    if _G.ou64_flood_debug then
        djui_hud_set_resolution(RESOLUTION_DJUI)

        local debug_box_width = 500
        local debug_box_height = 400

        local anchor_x = djui_hud_get_screen_width() - debug_box_width - 64
        local anchor_y = djui_hud_get_screen_height() - debug_box_height - 64
        local x_pad = 32
        local y_pad = 64

        djui_hud_set_adjusted_color(0, 0, 0, 200)
        djui_hud_render_rect(anchor_x, anchor_y, debug_box_width, debug_box_height)

        djui_hud_set_font(FONT_MENU)
        djui_hud_set_adjusted_color(250, 255, 32, 255)
        djui_hud_print_text("Debug Info", anchor_x - 8, anchor_y - 20, _G.ou64_run_timer_scale / 1.5)

        djui_hud_set_font(FONT_ALIASED)
        djui_hud_set_adjusted_color(255, 255, 255, 255)
        djui_hud_print_text("Players:", anchor_x + x_pad - 16, anchor_y + y_pad - 32, 1)

        local server_local_index = network_player_from_global_index(0).localIndex
        local y_offset = 0
        for i = 0, MAX_PLAYERS - 1 do
            local m = gMarioStates[i]
            local np = gNetworkPlayers[i]
            local name = np.name
            if np.connected then
                local space = i > 9 and "  " or " "
                local info = "["
                local comma = ""
                if i == server_local_index then
                    -- Player is Server
                    info = info .. comma .. "\\#EC7731\\Server\\#FFFFFF\\"
                    comma = ", "
                end
                if m.health > 0xFF and
                        gPlayerSyncTable[m.playerIndex].finished then
                    -- Player is Finished
                    info = info .. comma .. "\\#4BFF48\\Finished\\#FFFFFF\\"
                elseif m.health > 0xFF then
                    -- Player is Alive
                    info = info .. comma .. "\\#4BFF48\\Alive\\#FFFFFF\\"
                else
                    -- Player is Dead
                    info = info .. comma .. "\\#FF4B4B\\Dead\\#FFFFFF\\"
                end
                comma = ", "
                info = info == "[" and "" or info .. "]"
                djui_hud_print_colored_text(string_format("[\\#A1A1A1\\%s\\#FFFFFF\\]%s%s\\#FFFFFF\\ %s", i, space, name, info), anchor_x + x_pad, anchor_y + y_pad + y_offset, 1)
                y_offset = y_offset + 32
            end
        end
    end
end
