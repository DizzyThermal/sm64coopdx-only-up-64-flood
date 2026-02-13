-- name: \\#FAFF20\\Only Up \\#0083FF\\Flood
-- pauseable: false
-- incompatible: gamemode
-- description: \\#FAFF20\\Only Up 64 \\#0083FF\\Flood\\#FFF\\ v1.5.0\nBy \\#E01F2D\\DizzyThermal\\#FFF\\\n\nThis mod adds flood gamemode to\nOnly Up 64!\n\nReach the top and escape the area before everything is flooded.\n\nBased off Flood v2.4.2\nBy \\#EC7731\\Agent X

-- Localizing for performance
local network_player_connected_count,init_single_mario,warp_to_level,play_sound,network_is_server,network_get_player_text_color_string,djui_chat_message_create,network_player_set_description,set_mario_action,obj_get_first_with_behavior_id,vec3f_dist,play_race_fanfare,djui_hud_set_resolution,djui_hud_get_screen_height,djui_hud_get_screen_width,djui_hud_render_rect,djui_hud_set_font,djui_hud_world_pos_to_screen_pos,clampf,math_floor,djui_hud_measure_text,djui_hud_print_text,hud_render_power_meter,hud_get_value,save_file_erase_current_backup_save,save_file_set_using_backup_slot,find_floor_height,spawn_non_sync_object,vec3f_copy,math_random,hud_hide = network_player_connected_count,init_single_mario,warp_to_level,play_sound,network_is_server,network_get_player_text_color_string,djui_chat_message_create,network_player_set_description,set_mario_action,obj_get_first_with_behavior_id,vec3f_dist,play_race_fanfare,djui_hud_set_resolution,djui_hud_get_screen_height,djui_hud_get_screen_width,djui_hud_render_rect,djui_hud_set_font,djui_hud_world_pos_to_screen_pos,clampf,math.floor,djui_hud_measure_text,djui_hud_print_text,hud_render_power_meter,hud_get_value,save_file_erase_current_backup_save,save_file_set_using_backup_slot,find_floor_height,spawn_non_sync_object,vec3f_copy,math.random,hud_hide

-- runs serverside
local function round_start()
    for i = 0, MAX_PLAYERS - 1 do
        if gNetworkPlayers[i].connected then
            local m = gMarioStates[i]
            gPlayerSyncTable[i].finished = false
            gPlayerSyncTable[i].finish_time = 0
            init_single_mario(m)
            mario_set_full_health(m)
        end
    end
    -- Randomize Water Type for everyone
    if network_is_server() and 
            _G.ou64_flood_random_type and
            _G.ou64_flood_types then
        local type_index = 2
        while type_index == 2 do
            type_index = math_random(0, 3)
        end
        gGlobalSyncTable.water_type = type_index
    end

    gGlobalSyncTable.round_state = 1
    gGlobalSyncTable.timer = 240
    gGlobalSyncTable.points_for_winning = _G.ou64_flood_points_for_winning
end

-- runs serverside
local function round_end()
    gGlobalSyncTable.round_state = 0
    gGlobalSyncTable.timer = _G.ou64_flood_round_cooldown
    gGlobalSyncTable.water_level = _G.ou64_flood_start_level
end

local function get_modifiers_string()
    local modifiers = " ("
    if _G.ou64_enable_moveset then
        modifiers = modifiers .. "ou64 moveset"
    else
        modifiers = modifiers .. "no moveset"
    end
    if gGlobalSyncTable.hardmode then
        modifiers = modifiers .. ", hardmode"
    end
    if _G.ou64_flood_cheats then
        modifiers = modifiers .. ", cheats"
    end
    modifiers = modifiers .. ")"
    return modifiers
end

function level_restart()
    round_start()
    init_single_mario(gMarioStates[0])
    mario_set_full_health(gMarioStates[0])
    gPlayerSyncTable[0].time = 0

    if gGlobalSyncTable.area ~= nil then
        warp_to_level(_G.ou64_level_id, gGlobalSyncTable.area, 0)
    end
end

local function server_update()
    local server_local_index = network_player_from_global_index(0).localIndex

    if gGlobalSyncTable.round_state == 1 then
        -- ROUND ACTIVE

        -- Raise Water Level
        gGlobalSyncTable.water_level = gGlobalSyncTable.water_level + _G.ou64_flood_levels[gGlobalSyncTable.area].speed * gGlobalSyncTable.speed_multiplier

        -- Determine Player States
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

        -- If Everyone is Dead, End Round
        if dead_count == player_count then
            active_count = 0
            gGlobalSyncTable.timer = 0
        end

        -- If No Active Runners, Start Round Cooldown
        if active_count == 0 then
            -- Round Over, No Active Players
            if gGlobalSyncTable.timer > 0 then
                gGlobalSyncTable.timer = gGlobalSyncTable.timer - 1
            else
                round_end()
                if finished_count > 0 then
                    -- Someone Finished, Move to Next Area
                    local position = 1
                    for k, v in pairs(_G.ou64_map_rotation) do
                        if gGlobalSyncTable.area == v then
                            position = k
                        end
                    end

                    position = position + 1
                    if position > #(_G.ou64_map_rotation) then
                        position = 1
                    end

                    gGlobalSyncTable.area = _G.ou64_map_rotation[position]
                    _G.ou64_flood_area = gGlobalSyncTable.area
                end
            end

        end
    else
        -- ROUND INACTIVE
        if network_player_connected_count() > 1 then
            if gGlobalSyncTable.timer > 0 then
                gGlobalSyncTable.timer = gGlobalSyncTable.timer - 1

                -- 3, 2, 1 Countdown
                if gGlobalSyncTable.timer == 30 or
                        gGlobalSyncTable.timer == 60 or
                        gGlobalSyncTable.timer == 90 then
                    play_sound(SOUND_MENU_CHANGE_SELECT, gMarioStates[0].marioObj.header.gfx.cameraToObject)
                end
            else
                -- START ROUND
                round_start()
            end
        end
    end
end

local function on_start_command(msg)
    chat_message = "/flood \\#00ffff\\start\\#ffff00\\ [random|1-" .. #(_G.ou64_flood_levels) + 1 .. "]\\#ffffff\\\nSets the level to a random one or a specific one, you can also leave it empty for normal progression."
    if msg == "?" then
        djui_chat_message_create(chat_message)
        return true
    end

    if msg == "random" then
        -- Random Area
        random_index = math_random(1, #(_G.ou64_map_rotation))
        gGlobalSyncTable.area = _G.ou64_map_rotation[random_index]
        _G.ou64_flood_area = gGlobalSyncTable.area
    else
        -- Specified Area (i.e., 7)
        local found = false
        for i = 0, #(_G.ou64_flood_levels) do
            if msg ~= nil and
                    string.find(_G.ou64_flood_levels[i].name, msg:lower()) then
                gGlobalSyncTable.area = i
                _G.ou64_flood_area = i
                found = true
                break
            end
        end
        if not found and
                msg ~= nil then
            djui_chat_message_create(chat_message)
            return true
        end
    end

    if gGlobalSyncTable.round_state == 1 then
        network_send(true, { restart = true })
        level_restart()
    else
        round_start()
    end
    return true
end

local function on_speed_command(msg)
    local speed = tonumber(msg)
    if speed ~= nil then
        speed = clampf(speed, 0, 10)
        djui_chat_message_create("Water speed set to " .. speed)
        gGlobalSyncTable.speed_multiplier = speed
        return true
    end

    djui_chat_message_create("/flood \\#00ffff\\speed\\#ffff00\\ [number]\\#ffffff\\\nSets the speed multiplier of the flood")
    return true
end

local function on_hardmode_command()
    gGlobalSyncTable.hardmode = not gGlobalSyncTable.hardmode
	if gGlobalSyncTable.hardmode then
		djui_popup_create("Flood: \n\\#A02200\\Hardmode Enabled", 1)
        gGlobalSyncTable.speed_multiplier = 2
	else
		djui_popup_create("Flood: \n\\#00C7FF\\Hardmode Disabled", 1)
        gGlobalSyncTable.speed_multiplier = 1
	end
    return true
end

local function on_type_command(msg)
    --chat_message = "/flood type [\\#0070ff\\water\\#ffffff\\|\\#ff1000\\lava\\#ffffff\\|\\#ffe000\\sand\\#ffffff\\|\\#9A8600\\mud\\#ffffff\\|random]\nSets the flood type."
    chat_message = "/flood type [\\#0070ff\\water\\#ffffff\\|\\#ff1000\\lava\\#ffffff\\|\\#ffffff\\|\\#9A8600\\mud\\#ffffff\\|random]\nSets the flood type."
    if msg == "?" then
        djui_chat_message_create(chat_message)
        return true
    end

    _G.ou64_flood_random_type = false
    if string.find("water", msg) then
        gGlobalSyncTable.water_type = _G.ou64_flood_types.water
    elseif string.find("lava", msg) then
        gGlobalSyncTable.water_type = _G.ou64_flood_types.lava
    --elseif string.find("sand", msg) then
    --    gGlobalSyncTable.water_type = _G.ou64_flood_types.sand
    elseif string.find("mud", msg) then
        gGlobalSyncTable.water_type = _G.ou64_flood_types.mud
    elseif string.find("random", msg) then
        _G.ou64_flood_random_type = true
    else
        djui_chat_message_create(chat_message)
    end
    return true
end

local function on_reset_all_points_command()
    for i = 0, MAX_PLAYERS - 1 do
        gPlayerSyncTable[i].points = 0
    end
    return true
end

local function on_set_points(player_index, points)
    local playerIndex = tonumber(player_index)
    local playerPoints = tonumber(points)

    if playerIndex ~= nil and
            playerPoints ~= nil and
            gNetworkPlayers[playerIndex] ~= nil and
            gNetworkPlayers[playerIndex].connected then
        gPlayerSyncTable[i].points = playerPoints
    end

    return true
end

local function on_flood_command(msg)
    if network_is_server() or
            network_is_moderator() then
        local args = split(msg)
        if args[1] == "start" then
            return on_start_command(args[2])
        elseif args[1] == "speed" then
            return on_speed_command(args[2])
        elseif args[1] == "hardmode" then
            return on_hardmode_command()
        elseif args[1] == "type" then
            return on_type_command(args[2])
        elseif args[1] == "reset-all-points" then
            return on_reset_all_points_command()
        elseif args[1] == "set-points" then
            chat_message = "/flood \\#00ffff\\set-points \\#ffff00\\[player-id] [points]\\#ffffff\\\nSets a players points."
            if args[2] == "?" or #(args) < 3 then
                djui_chat_message_create(chat_message)
                return true
            end
            return on_set_points(args[2], args[3])
        end

        djui_chat_message_create("/flood \\#00ffff\\[start|speed|hardmode|type|reset-all-points|set-points]")
    end
    return true
end

hook_event(HOOK_UPDATE, function()
    if _G.ou64_flood_levels == nil or
            _G.ou64_flood_levels[gGlobalSyncTable.area] == nil then
        return
    end
    if _G.ou64_flood_levels[gGlobalSyncTable.area] ~= nil and
            gGlobalSyncTable.round_state == 1 and
            not _G.ou64_flood_in_lobby and 
            gPlayerSyncTable[0].time == 2 then
        play_sound(SOUND_GENERAL_RACE_GUN_SHOT, gMarioStates[0].marioObj.header.gfx.cameraToObject)
    end
    if network_is_server() then
        server_update()
    end

    gServerSettings.playerInteractions = PLAYER_INTERACTIONS_NONE

    if gGlobalSyncTable.round_state == 0 and
                not _G.ou64_flood_in_lobby then
        -- Warp to Lobby
        _G.ou64_flood_in_lobby = true
        warp_to_level(_G.ou64_level_id, 1, 0)

        if not _G.ou64_listed_survivors and
                _G.ou64_global_timer > 5 then
            _G.ou64_listed_survivors = true
            local finished = 0
            local string = "Survivors:"
            for i = 0, MAX_PLAYERS - 1 do
                if gNetworkPlayers[i].connected and
                        gPlayerSyncTable[i].finished then
                    local name = gNetworkPlayers[i].name
                    if name == string_without_hex(name) then
                        name = network_get_player_text_color_string(i) .. name
                    end
                    string = string .. "\n  " .. name .. "\\#FFFFFF\\  "
                    finished = finished + 1
                end
            end
            if finished == 0 then
                string = string .. "\n  \\#FF0000\\None  "
            end
            djui_chat_message_create(string)
        end
    elseif gGlobalSyncTable.round_state == 1 then
        if _G.ou64_flood_in_lobby then
            _G.ou64_listed_survivors = false
            mario_set_full_health(gMarioStates[0])

            if network_is_server() then
                for i = 0, MAX_PLAYERS - 1 do
                    gPlayerSyncTable[i].time = 0
                    gPlayerSyncTable[i].finished = false
                end
            end

            _G.ou64_flood_in_lobby = false
            warp_to_level(_G.ou64_level_id, gGlobalSyncTable.area, 0)
        end
    end

    -- stops the star spawn cutscenes from happening
    local m = gMarioStates[0]
    if m.area ~= nil and
            m.area.camera ~= nil and
            (m.area.camera.cutscene == CUTSCENE_STAR_SPAWN
                or m.area.camera.cutscene == CUTSCENE_RED_COIN_STAR_SPAWN) then
        m.area.camera.cutscene = 0
        m.freeze = 0
        disable_time_stop()
    end

    _G.ou64_global_timer = _G.ou64_global_timer + 1

    -- HACK: Unreachable Code to Sort Only Up 64 over Only Up 64 Plugin
    if true and false then
        djui_popup_create("ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData\
    ExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraDataExtraData")
    end
end)

hook_event(HOOK_MARIO_UPDATE, function(m)
    if not gNetworkPlayers[m.playerIndex].connected or
            _G.ou64_flood_levels == nil or
            _G.ou64_flood_levels[gGlobalSyncTable.area] == nil then
        return
    end

    -- All Players
    set_player_descriptions(m)
    -- End All Players
    if m.playerIndex ~= 0 then return end

    -- Remove Steep Slopes (Unless Hardmode is Enabled)
    if not gGlobalSyncTable.hardmode and
            m.action == ACT_STEEP_JUMP then
        m.action = ACT_JUMP
    end

    -- Disable Warps
    if m.floor ~= nil and 
            (m.floor.type == SURFACE_WARP or 
                (m.floor.type >= SURFACE_PAINTING_WARP_D3 and 
                    m.floor.type <= SURFACE_PAINTING_WARP_FC) or
                (m.floor.type >= SURFACE_INSTANT_WARP_1B and
                    m.floor.type <= SURFACE_INSTANT_WARP_1E)) then
        m.floor.type = SURFACE_DEFAULT
    end

    -- Disable Damage in Lobby
    if gGlobalSyncTable.round_state == 0 and
            _G.ou64_flood_in_lobby then
        mario_set_full_health(m)
        m.peakHeight = m.pos.y
        return
    end

    -- Check if reached end of the level
    goal_distance_check = if_then_else(gGlobalSyncTable.area == 0, 365, 400)
    if not gPlayerSyncTable[0].finished and
            vec3f_dist(m.pos, _G.ou64_flood_levels[gGlobalSyncTable.area].goal_pos) < goal_distance_check then
        gPlayerSyncTable[0].finish_time = string.format("%.3f", gPlayerSyncTable[0].time / 30)
        gPlayerSyncTable[0].finished = true
        gPlayerSyncTable[0].points = gPlayerSyncTable[0].points + gGlobalSyncTable.points_for_winning

        if gGlobalSyncTable.points_for_winning > 1 then
            gGlobalSyncTable.points_for_winning = gGlobalSyncTable.points_for_winning - 1
        end

        local string = ""
        if gNetworkPlayers[0].currAreaIndex ~= 0 then
            string = string .. "\\#00ff00\\You escaped the flood!\n"
            play_race_fanfare()
        else
            string = string .. "\\#00ff00\\You escaped the \\#ffff00\\final\\#00ff00\\ flood! Congratulations!\n"
            play_music(0, SEQUENCE_ARGS(8, SEQ_EVENT_CUTSCENE_VICTORY), 0)
        end
        play_race_fanfare()
        string = string .. "\\#ffffff\\Time: " .. string.format("%.3f", gPlayerSyncTable[0].time / 30) .. get_modifiers_string()

        djui_chat_message_create(string)
    end

    if gPlayerSyncTable[0].finished then
        -- Enter Spectate Mode
        mario_set_full_health(m)
        if m.action ~= ACT_SPECTATOR then
            m.area.camera.cutscene = 0
            set_mario_spectator(m)
        end
    else
        -- Player Still Running
        gPlayerSyncTable[0].time = gPlayerSyncTable[0].time + 1

        -- Damage Player if in Flood
        if m.pos.y + 40 < gGlobalSyncTable.water_level then
            m.health = m.health - 30
        end

        if m.health <= 0xFF then
            if m.action ~= ACT_SPECTATOR then
                m.area.camera.cutscene = 0
                set_mario_spectator(m)
            end
        else
            -- Export Camera Settings (while alive)
            if not gPlayerSyncTable[0].finished and
                    m.health > 0xFF then
                network_send(true, {
                    playerIndex = network_global_index_from_local(0),
                    playerHeight = m.pos.y,
                    health = m.health,
                    posX = gLakituState.pos.x,
                    posY = gLakituState.pos.y,
                    posZ = gLakituState.pos.z,
                    focusX = gLakituState.focus.x,
                    focusY = gLakituState.focus.y,
                    focusZ = gLakituState.focus.z,
                    yaw = gLakituState.yaw,
                    posHSpeed = gLakituState.posHSpeed,
                    posVSpeed = gLakituState.posVSpeed,
                    focHSpeed = gLakituState.focHSpeed,
                    focVSpeed = gLakituState.focVSpeed,
                })
            end
        end
    end
end)

hook_event(HOOK_ON_HUD_RENDER, function()
    if _G.ou64_flood_levels == nil or
            _G.ou64_flood_levels[gGlobalSyncTable.area] == nil then
        return
    end
    local water = obj_get_first_with_behavior_id(id_bhvWater)

    if water ~= nil then
        djui_hud_set_resolution(RESOLUTION_DJUI)

        if gLakituState.pos.y < gGlobalSyncTable.water_level - 10 then
            switch(water.oAnimState, {
                [_G.ou64_flood_types.water] = function()
                    djui_hud_set_adjusted_color(0, 20, 200, 120)
                end,
                [_G.ou64_flood_types.lava] = function()
                    djui_hud_set_adjusted_color(200, 0, 0, 220)
                end,
                --[_G.ou64_flood_types.sand] = function()
                --    djui_hud_set_adjusted_color(254, 193, 121, 220)
                --end,
                [_G.ou64_flood_types.mud] = function()
                    djui_hud_set_adjusted_color(74, 123, 0, 220)
                end
            })
            djui_hud_render_rect(0, 0, djui_hud_get_screen_width(), djui_hud_get_screen_height())
        end
    end

    djui_hud_set_resolution(RESOLUTION_N64)
    djui_hud_set_font(FONT_TINY)

    local level = _G.ou64_flood_levels[gGlobalSyncTable.area]
    if level ~= nil and
            gGlobalSyncTable.area ~= 0 then
        local out = { x = 0, y = 0, z = 0 }
        djui_hud_world_pos_to_screen_pos(level.goal_pos, out)
        local dX = clampf(out.x - 5, 0, djui_hud_get_screen_width() - 19.2)
        local dY = clampf(out.y - 20, 0, djui_hud_get_screen_height() - 19.2)

        djui_hud_set_adjusted_color(255, 255, 255, 200)
        djui_hud_render_texture_interpolated(_G.flood_flag_texture, _G.flag_prev_pos.x, _G.flag_prev_pos.y, 0.15, 0.15, dX, dY, 0.15, 0.15)

        _G.flag_prev_pos.x = dX
        _G.flag_prev_pos.y = dY
    end

    local text = if_then_else(gGlobalSyncTable.round_state == 0, "Type '/flood start' to start a round", "0.000 seconds" .. get_modifiers_string())
    if gNetworkPlayers[0].currAreaSyncValid then
        if gGlobalSyncTable.round_state == 0 then
            text = if_then_else(network_player_connected_count() > 1, "Round starts in " .. tostring(math_floor(gGlobalSyncTable.timer / 30)), "Type '/flood start' to start a round")
        else
            text = tostring(string.format("%.3f", gPlayerSyncTable[0].time / 30)) .. " seconds" .. get_modifiers_string()
        end
    end

    local scale = 1
    local width = djui_hud_measure_text(text) * scale
    local x = (djui_hud_get_screen_width() - width) * 0.5

    djui_hud_set_adjusted_color(0, 0, 0, 128)
    djui_hud_render_rect(x - 6, 0, width + 12, 16)
    djui_hud_set_adjusted_color(255, 255, 255, 255)
    djui_hud_print_text(text, x, 0, scale)

    hud_render_power_meter(gMarioStates[0].health, djui_hud_get_screen_width() - 70, 0, 64, 64)

    djui_hud_set_font(FONT_HUD)

    if gGlobalSyncTable.speed_multiplier ~= 1 then
        djui_hud_print_text(string.format("%.2fx", gGlobalSyncTable.speed_multiplier), 5, 24, 1)
    end

    if _G.ou64_flood_enable_scoreboard then
        render_flood_scoreboard()
    end

    if _G.ou64_flood_debug then
        debug_render_debug_info()
    end
end)

hook_event(HOOK_ON_WARP, function()
    --- @type MarioState
    local m = gMarioStates[0]

    if _G.ou64_flood_levels ~= nil and 
            _G.ou64_flood_levels[gGlobalSyncTable.area] ~= nil and
            _G.ou64_flood_levels[gGlobalSyncTable.area].start_pos ~= nil then
        local start_area = gGlobalSyncTable.round_state == 0 and 1 or gGlobalSyncTable.area
        local start = _G.ou64_flood_levels[start_area].start_pos
        vec3f_copy(m.pos, start)
        set_mario_action(m, ACT_SPAWN_SPIN_AIRBORNE, 0)
        m.faceAngle.y = start.a
    end

    if gGlobalSyncTable.round_state == 1 and 
            _G.ou64_flood_coins ~= nil and
            #_G.ou64_flood_coins > 0 then
        for i, coin in ipairs(_G.ou64_flood_coins[m.area.index]) do
            local model = coin.shadow and E_MODEL_RED_COIN or E_MODEL_RED_COIN_NO_SHADOW
            spawn_non_sync_object(
                id_bhvRedCoin,
                model,
                coin.x, coin.y, coin.z,
                function (obj)
                    obj.oOpacity = 255
                    obj.oFaceAnglePitch = 0
                    obj.oFaceAngleYaw = 0
                    obj.oFaceAngleRoll = 0
                end
            )
        end
    end
end)

hook_event(HOOK_ON_LEVEL_INIT, function()
    -- reset save
    save_file_erase_current_backup_save()
    save_file_set_using_backup_slot(true)

    if gGlobalSyncTable.round_state == 1 then
        if network_is_server() then
            local start = _G.ou64_flood_levels[gGlobalSyncTable.area].start_pos
            if start ~= nil then
                gGlobalSyncTable.water_level = find_floor_height(start.x, start.y, start.z) - 1200
            else
                gGlobalSyncTable.water_level = find_floor_height(gMarioStates[0].pos.x, gMarioStates[0].pos.y, gMarioStates[0].pos.z) - 1200
            end
        end

        spawn_non_sync_object(
            id_bhvWater,
            E_MODEL_FLOOD,
            0, gGlobalSyncTable.water_level, 0,
            nil
        )
    end

    if _G.ou64_flood_levels == nil or
            _G.ou64_flood_levels[gGlobalSyncTable.area] == nil then
        return
    end
    local pos = _G.ou64_flood_levels[gGlobalSyncTable.area].goal_pos
    if pos == nil then return end

    if gNetworkPlayers[0].currAreaIndex == 0 then
        spawn_non_sync_object(
            id_bhvFinalStar,
            E_MODEL_STAR,
            pos.x, pos.y, pos.z,
            nil
        )
    else
        spawn_non_sync_object(
            id_bhvFloodFlag,
            E_MODEL_KOOPA_FLAG,
            pos.x, pos.y, pos.z,
            --- @param o Object
            function(o)
                o.oFaceAnglePitch = 0
                o.oFaceAngleYaw = pos.a
                o.oFaceAngleRoll = 0
            end
        )
    end
end)

hook_event(HOOK_ON_PLAYER_CONNECTED, function()
    if network_is_server() and
            gGlobalSyncTable.round_state == 0 then
        gGlobalSyncTable.timer = _G.ou64_flood_round_cooldown
    end
end)

hook_chat_command('flood-scoreboard', '- Toggle Flood Scoreboard', function()
    _G.ou64_flood_enable_scoreboard = not _G.ou64_flood_enable_scoreboard
    if _G.ou64_flood_enable_scoreboard then
        djui_popup_create("Flood: \n\\#00C7FF\\Scoreboard Enabled", 1)
    else
        djui_popup_create("Flood: \n\\#A02200\\Scoreboard Disabled", 1)
    end
    return true
end)

hook_chat_command("flood", "\\#00ffff\\[start|speed|hardmode|type|reset-all-points|set-points]", on_flood_command)

if network_is_server() then
    for i = 0, MAX_PLAYERS - 1 do
        gPlayerSyncTable[i].points = 0
        gPlayerSyncTable[i].finished = false
    end
end
