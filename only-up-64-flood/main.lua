-- name: Only Up 64 Flood
-- incompatible: gamemode
-- description: Only Up 64 Flood v1.3\nby \\#ff0000\\DizzyThermal\\#dcdcdc\\\n\nThis mod adds a flood escape gamemode\nto Only Up 64, you must escape the flood and reach the top of the level before everything is flooded.\n\nBased off Flood v2.4.2\nBy \\#ec7731\\Agent X

if unsupported then return end

local ROUND_STATE_INACTIVE = 0
ROUND_STATE_ACTIVE         = 1
local ROUND_COOLDOWN       = 600
POINTS_FOR_WINNING         = 4

local TEX_FLOOD_FLAG = get_texture_info("flood_flag")

local enable_hardmode = false

local IN_LOBBY = true
local random_water_type = true

gGlobalSyncTable.roundState = ROUND_STATE_INACTIVE
gGlobalSyncTable.timer = ROUND_COOLDOWN
gGlobalSyncTable.area = 1
gGlobalSyncTable.waterLevel = -20000
gGlobalSyncTable.speedMultiplier = 1
gGlobalSyncTable.points = {}
gGlobalSyncTable.pointsForWinning = POINTS_FOR_WINNING
gGlobalSyncTable.waterType = FLOOD_WATER
gGlobalSyncTable.hardmode = false

local sFlagIconPrevPos = { x = 0, y = 0 }

local globalTimer = 0
local listedSurvivors = false

-- localize functions to improve performance
local network_player_connected_count,init_single_mario,warp_to_level,play_sound,network_is_server,network_get_player_text_color_string,djui_chat_message_create,network_player_set_description,set_mario_action,obj_get_first_with_behavior_id,vec3f_dist,play_race_fanfare,djui_hud_set_resolution,djui_hud_get_screen_height,djui_hud_get_screen_width,djui_hud_render_rect,djui_hud_set_font,djui_hud_world_pos_to_screen_pos,clampf,math_floor,djui_hud_measure_text,djui_hud_print_text,hud_render_power_meter,hud_get_value,save_file_erase_current_backup_save,save_file_set_using_backup_slot,find_floor_height,spawn_non_sync_object,vec3f_copy,math_random,hud_hide = network_player_connected_count,init_single_mario,warp_to_level,play_sound,network_is_server,network_get_player_text_color_string,djui_chat_message_create,network_player_set_description,set_mario_action,obj_get_first_with_behavior_id,vec3f_dist,play_race_fanfare,djui_hud_set_resolution,djui_hud_get_screen_height,djui_hud_get_screen_width,djui_hud_render_rect,djui_hud_set_font,djui_hud_world_pos_to_screen_pos,clampf,math.floor,djui_hud_measure_text,djui_hud_print_text,hud_render_power_meter,hud_get_value,save_file_erase_current_backup_save,save_file_set_using_backup_slot,find_floor_height,spawn_non_sync_object,vec3f_copy,math.random,hud_hide

-- runs serverside
local function round_start()
    for i = 0, MAX_PLAYERS - 1 do
        if gNetworkPlayers[i].connected then
            gPlayerSyncTable[i].finished = false
            gPlayerSyncTable[i].finishTime = nil
            mario_set_full_health(gMarioStates[i])
        end
    end
    -- Randomize Water Type for everyone
    if random_water_type and network_is_server() then
        type_index = math_random(0, 3)
        gGlobalSyncTable.waterType = type_index
    end

    gGlobalSyncTable.roundState = ROUND_STATE_ACTIVE
    gGlobalSyncTable.timer = 240
    gGlobalSyncTable.pointsForWinning = POINTS_FOR_WINNING
end

-- runs serverside
local function round_end()
    gGlobalSyncTable.roundState = ROUND_STATE_INACTIVE
    gGlobalSyncTable.timer = ROUND_COOLDOWN
    gGlobalSyncTable.waterLevel = -20000
end

local function get_modifiers_string()
    if not cheats
      and not moveset
      and not gGlobalSyncTable.hardmode then
        return ""
    end

    local modifiers = " ("
    if moveset then
        if ou64_moveset then
            modifiers = modifiers .. "ou64 "
        end
        modifiers = modifiers .. "moveset"
    else
        modifiers = modifiers .. "no moveset"
    end
    if gGlobalSyncTable.hardmode then
        modifiers = modifiers .. ", hardmode"
    end
    if cheats then
        modifiers = modifiers .. ", cheats"
    end
    modifiers = modifiers .. ")"
    return modifiers
end

function level_restart()
    round_start()
    init_single_mario(gMarioStates[0])
    mario_set_full_health(gMarioStates[0])
    gLevels[gGlobalSyncTable.area].time = 0

    warp_area = gGlobalSyncTable.area
    if warp_area ~= nil then
        warp_to_level(LEVEL_ONLY_UP_64, gGlobalSyncTable.area, 0)
    end
end

local function server_update()
    if gGlobalSyncTable.roundState == ROUND_STATE_ACTIVE then
        gGlobalSyncTable.waterLevel = gGlobalSyncTable.waterLevel + gLevels[gGlobalSyncTable.area].speed * gGlobalSyncTable.speedMultiplier

        local active = 0
        for i = 0, MAX_PLAYERS - 1 do
            local m = gMarioStates[i]
            if active_player(m) ~= 0 and m.health > 0xff and not gPlayerSyncTable[i].finished then
                active = active + 1
            end
        end

        if active == 0 then
            local dead = 0
            for i = 0, MAX_PLAYERS - 1 do
                if active_player(gMarioStates[i]) ~= 0 and gMarioStates[i].health <= 0xff then
                    dead = dead + 1
                end
            end
            if dead == network_player_connected_count() then
                gGlobalSyncTable.timer = 0
            end

            if gGlobalSyncTable.timer > 0 then
                gGlobalSyncTable.timer = gGlobalSyncTable.timer - 1
            else
                round_end()
                local finished = false
                for i = 0, MAX_PLAYERS - 1 do
                    if active_player(gMarioStates[i]) ~= 0 and gPlayerSyncTable[i].finished then
                        finished = true
                        break
                    end
                end
                if finished then
                    -- move to next area if someone finished
                    local position = 1
                    for k, v in pairs(gMapRotation) do
                        if gGlobalSyncTable.area == v then
                            position = k
                        end
                    end

                    position = position + 1
                    if position > 4 then -- DEBUG -- #(gMapRotation) then
                        position = 1
                    end

                    gGlobalSyncTable.area = gMapRotation[position]
                end
            end
        end
    else
        if network_player_connected_count() > 1 then
            if gGlobalSyncTable.timer > 0 then
                gGlobalSyncTable.timer = gGlobalSyncTable.timer - 1

                if gGlobalSyncTable.timer == 30 or gGlobalSyncTable.timer == 60 or gGlobalSyncTable.timer == 90 then
                    play_sound(SOUND_MENU_CHANGE_SELECT, gMarioStates[0].marioObj.header.gfx.cameraToObject)
                end
            else
                round_start()
            end
        end
    end
end

local function on_start_command(msg)
    chat_message = "/flood \\#00ffff\\start\\#ffff00\\ [random|1-" .. #(gLevels) + 1 .. "]\\#ffffff\\\nSets the level to a random one or a specific one, you can also leave it empty for normal progression."
    if msg == "?" then
        djui_chat_message_create(chat_message)
        return true
    end

    if msg == "random" then
        -- Random Area
        randomIndex = math_random(1, #(gMapRotation))
        gGlobalSyncTable.area = gMapRotation[randomIndex]
    else
        -- Specified Area (i.e., 7)
        local found = false
        for i = 0, #(gLevels) do
            if msg ~= nil and string.find(gLevels[i].name, msg:lower()) then
                gGlobalSyncTable.area = i
                found = true
                break
            end
        end
        if not found and msg ~= nil then
            djui_chat_message_create(chat_message)
            return true
        end
    end

    if gGlobalSyncTable.roundState == ROUND_STATE_ACTIVE then
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
        gGlobalSyncTable.speedMultiplier = speed
        return true
    end

    djui_chat_message_create("/flood \\#00ffff\\speed\\#ffff00\\ [number]\\#ffffff\\\nSets the speed multiplier of the flood")
    return true
end

local function on_hardmode_command()
    enable_hardmode = not enable_hardmode
	if enable_hardmode then
		djui_popup_create("Flood: \n\\#A02200\\Hardmode Enabled", 1)
        gGlobalSyncTable.hardmode = true
        gGlobalSyncTable.speedMultiplier = 2
	else
		djui_popup_create("Flood: \n\\#00C7FF\\Hardmode Disabled", 1)
        gGlobalSyncTable.hardmode = false
        gGlobalSyncTable.speedMultiplier = 1
	end
    return true
end

local function on_type_command(msg)
    chat_message = "/flood type [\\#0070ff\\water\\#ffffff\\|\\#ff1000\\lava\\#ffffff\\|\\#ffe000\\sand\\#ffffff\\|\\#9A8600\\mud\\#ffffff\\|random]\nSets the flood type."
    if msg == "?" then
        djui_chat_message_create(chat_message)
        return true
    end

    random_water_type = false
    if string.find("water", msg) then
        gGlobalSyncTable.waterType = FLOOD_WATER
    elseif string.find("lava", msg) then
        gGlobalSyncTable.waterType = FLOOD_LAVA
    elseif string.find("sand", msg) then
        gGlobalSyncTable.waterType = FLOOD_SAND
    elseif string.find("mud", msg) then
        gGlobalSyncTable.waterType = FLOOD_MUD
    elseif string.find("random", msg) then
        random_water_type = true
    else
        djui_chat_message_create(chat_message)
    end
    return true
end

local function on_reset_all_points_command()
    for i = 0, MAX_PLAYERS - 1 do
        gGlobalSyncTable.points[i] = 0
    end
    return true
end

local function on_set_points(player_index, points)
    local playerIndex = tonumber(player_index)
    local playerPoints = tonumber(points)
    if playerIndex ~= nil and playerPoints ~= nil
      and gNetworkPlayers[playerIndex] ~= nil
      and gNetworkPlayers[playerIndex].connected then
        gGlobalSyncTable.points[network_global_index_from_local(playerIndex)] = playerPoints
    end
    return true
end

local function on_flood_command(msg)
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
    return true
end

gServerSettings.skipIntro = 1
gServerSettings.stayInLevelAfterStar = 2

gLevelValues.entryLevel = LEVEL_LOBBY
gLevelValues.floorLowerLimit = -20000
gLevelValues.floorLowerLimitMisc = -20000 + 1000
gLevelValues.floorLowerLimitShadow = -20000 + 1000.0
gLevelValues.fixCollisionBugs = 1
gLevelValues.fixCollisionBugsRoundedCorners = 0

hud_hide()

hook_event(HOOK_UPDATE, function()
    if gLevels[gGlobalSyncTable.area] ~= nil and gLevels[gGlobalSyncTable.area].time == 2 then
        play_sound(SOUND_GENERAL_RACE_GUN_SHOT, gMarioStates[0].marioObj.header.gfx.cameraToObject)
    end
    if network_is_server() then server_update() end

    gServerSettings.playerInteractions = PLAYER_INTERACTIONS_NONE

    if gGlobalSyncTable.roundState == ROUND_STATE_INACTIVE then
        if not IN_LOBBY then
            warp_to_level(LEVEL_LOBBY, 1, 0) -- DEBUG
            IN_LOBBY = true
            for i = 0, MAX_PLAYERS - 1 do
                gPlayerSyncTable[i].finished = false
            end

            if not listedSurvivors and globalTimer > 5 then
                listedSurvivors = true
                local finished = 0
                local string = "Survivors:"
                for i = 0, MAX_PLAYERS - 1 do
                    if gNetworkPlayers[i].connected and gPlayerSyncTable[i].finished then
                        string = string .. "\n" .. network_get_player_text_color_string(i) .. gNetworkPlayers[i].name
                        finished = finished + 1
                    end
                end
                if finished == 0 then
                    string = string .. "\n\\#ff0000\\None"
                end
                djui_chat_message_create(string)
            end
        end
    elseif gGlobalSyncTable.roundState == ROUND_STATE_ACTIVE then
        if IN_LOBBY then
            listedSurvivors = false
            mario_set_full_health(gMarioStates[0])
            gLevels[gGlobalSyncTable.area].time = 0
            gPlayerSyncTable[0].finished = false

            warp_to_level(LEVEL_ONLY_UP_64, gGlobalSyncTable.area, 0)
            IN_LOBBY = false
        end
    end

    -- stops the star spawn cutscenes from happening
    local m = gMarioStates[0]
    if m.area ~= nil
      and m.area.camera ~= nil
      and (m.area.camera.cutscene == CUTSCENE_STAR_SPAWN
        or m.area.camera.cutscene == CUTSCENE_RED_COIN_STAR_SPAWN) then
        m.area.camera.cutscene = 0
        m.freeze = 0
        disable_time_stop()
    end

    globalTimer = globalTimer + 1
end)

hook_event(HOOK_MARIO_UPDATE, function(m)
    -- DEBUG
    if network_global_index_from_local(m.playerIndex) == 0 and (m.controller.buttonPressed & L_TRIG) ~= 0 then
        on_flood_command("start")
    end

    if not gNetworkPlayers[m.playerIndex].connected then return end

    if m.health > 0xff and not gPlayerSyncTable[m.playerIndex].finished then
        network_player_set_description(gNetworkPlayers[m.playerIndex], "Alive", 75, 255, 75, 255)
    elseif m.health > 0xff then
        network_player_set_description(gNetworkPlayers[m.playerIndex], "Finished", 75, 255, 75, 255)
    else
        network_player_set_description(gNetworkPlayers[m.playerIndex], "Dead", 255, 75, 75, 255)
    end

    if m.playerIndex ~= 0 then return end

    -- action specific modifications
    if not gGlobalSyncTable.hardmode then
        if m.action == ACT_STEEP_JUMP then
            m.action = ACT_JUMP
        end
    end

    -- disable instant warps
    if m.floor ~= nil and (m.floor.type == SURFACE_WARP or (m.floor.type >= SURFACE_PAINTING_WARP_D3 and m.floor.type <= SURFACE_PAINTING_WARP_FC) or (m.floor.type >= SURFACE_INSTANT_WARP_1B and m.floor.type <= SURFACE_INSTANT_WARP_1E)) then
        m.floor.type = SURFACE_DEFAULT
    end

    -- disable insta kills
    if m.floor ~= nil and (m.floor.type == SURFACE_INSTANT_QUICKSAND or m.floor.type == SURFACE_INSTANT_MOVING_QUICKSAND) then
        m.floor.type = SURFACE_BURNING
    end

    -- disable damage in lobby
    if gGlobalSyncTable.roundState == ROUND_STATE_INACTIVE then
        mario_set_full_health(m)
        m.peakHeight = m.pos.y
        return
    end

    -- dialog boxes
    if (m.action == ACT_SPAWN_NO_SPIN_AIRBORNE or m.action == ACT_SPAWN_NO_SPIN_LANDING or m.action == ACT_SPAWN_SPIN_AIRBORNE or m.action == ACT_SPAWN_SPIN_LANDING) and m.pos.y < m.floorHeight + 10 then
        set_mario_action(m, ACT_FREEFALL, 0)
    end

    -- Last Area
    if gNetworkPlayers[0].currAreaIndex == 0 then
        local star = obj_get_first_with_behavior_id(id_bhvFinalStar)
        if star ~= nil
          and obj_check_hitbox_overlap(m.marioObj, star)
          and m.action ~= ACT_JUMBO_STAR_CUTSCENE then
            if not gPlayerSyncTable[0].finished then
                spawn_mist_particles()
                set_mario_action(m, ACT_FREEFALL, 0)
            end
        end

        if m.action == ACT_JUMBO_STAR_CUTSCENE
          and m.actionTimer >= 499 then
            set_mario_spectator(m)
        end
    end

    -- check if the player has reached the end of the level
    goalDistanceCheck = if_then_else(gGlobalSyncTable.area == 0, 350, 600)
    if not gPlayerSyncTable[0].finished
      and (m.pos.y == m.floorHeight or (m.action & ACT_FLAG_ON_POLE) ~= 0)
      and vec3f_dist(m.pos, gLevels[gGlobalSyncTable.area].goalPos) < goalDistanceCheck then
        gPlayerSyncTable[0].finished = true
        gPlayerSyncTable[0].finishTime = string.format("%.3f", gLevels[gGlobalSyncTable.area].time / 30)

        gGlobalSyncTable.points[network_global_index_from_local(0)] = gGlobalSyncTable.points[network_global_index_from_local(0)] + gGlobalSyncTable.pointsForWinning
        if gGlobalSyncTable.pointsForWinning > 1 then
            gGlobalSyncTable.pointsForWinning = gGlobalSyncTable.pointsForWinning - 1
        end

        local string = ""
        if gNetworkPlayers[0].currAreaIndex ~= 0 then
            string = string .. "\\#00ff00\\You escaped the flood!\n"
            -- play_race_fanfare()
        else
            string = string .. "\\#00ff00\\You escaped the \\#ffff00\\final\\#00ff00\\ flood! Congratulations!\n"
            -- play_music(0, SEQUENCE_ARGS(8, SEQ_EVENT_CUTSCENE_VICTORY), 0)
        end
        play_race_fanfare()
        string = string .. "\\#ffffff\\Time: " .. string.format("%.3f", gLevels[gGlobalSyncTable.area].time / 30) .. get_modifiers_string()

        djui_chat_message_create(string)
    end

    -- update spectator if finished, manage other things if not
    if gPlayerSyncTable[0].finished then
        mario_set_full_health(m)
        if network_player_connected_count() > 1
          and m.action ~= ACT_SPECTATOR then
            set_mario_spectator(m)
        end
    else
        if m.pos.y + 40 < gGlobalSyncTable.waterLevel then
            m.health = m.health - 30
        end

        gLevels[gGlobalSyncTable.area].time = gLevels[gGlobalSyncTable.area].time + 1
        if m.health <= 0xFF then
            if network_player_connected_count() > 1
              and m.action ~= ACT_SPECTATOR then
                m.area.camera.cutscene = 0
                set_mario_spectator(m)
            end
        else
            -- Export Camera Settings (while alive)
            if not gPlayerSyncTable[0].finished and m.health > 0xFF then
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
    local water = obj_get_first_with_behavior_id(id_bhvWater)

    if water ~= nil then
        djui_hud_set_resolution(RESOLUTION_DJUI)

        if gLakituState.pos.y < gGlobalSyncTable.waterLevel - 10 then
            switch(water.oAnimState, {
                [FLOOD_WATER] = function()
                    djui_hud_set_adjusted_color(0, 20, 200, 120)
                end,
                [FLOOD_LAVA] = function()
                    djui_hud_set_adjusted_color(200, 0, 0, 220)
                end,
                [FLOOD_SAND] = function()
                    djui_hud_set_adjusted_color(254, 193, 121, 220)
                end,
                [FLOOD_MUD] = function()
                    djui_hud_set_adjusted_color(74, 123, 0, 220)
                end
            })
            djui_hud_render_rect(0, 0, djui_hud_get_screen_width(), djui_hud_get_screen_height())
        end
    end

    djui_hud_set_resolution(RESOLUTION_N64)
    djui_hud_set_font(FONT_TINY)

    local level = gLevels[gGlobalSyncTable.area]
    if level ~= nil and gGlobalSyncTable.area ~= 0 then
        local out = { x = 0, y = 0, z = 0 }
        djui_hud_world_pos_to_screen_pos(level.goalPos, out)
        local dX = clampf(out.x - 5, 0, djui_hud_get_screen_width() - 19.2)
        local dY = clampf(out.y - 20, 0, djui_hud_get_screen_height() - 19.2)

        djui_hud_set_adjusted_color(255, 255, 255, 200)
        djui_hud_render_texture_interpolated(TEX_FLOOD_FLAG, sFlagIconPrevPos.x, sFlagIconPrevPos.y, 0.15, 0.15, dX, dY, 0.15, 0.15)

        sFlagIconPrevPos.x = dX
        sFlagIconPrevPos.y = dY
    end

    local text = if_then_else(gGlobalSyncTable.roundState == ROUND_STATE_INACTIVE, "Type '/flood start' to start a round", "0.000 seconds" .. get_modifiers_string())
    if gNetworkPlayers[0].currAreaSyncValid then
        if gGlobalSyncTable.roundState == ROUND_STATE_INACTIVE then
            text = if_then_else(network_player_connected_count() > 1, "Round starts in " .. tostring(math_floor(gGlobalSyncTable.timer / 30)), "Type '/flood start' to start a round")
        else
            text = tostring(string.format("%.3f", gLevels[gGlobalSyncTable.area].time / 30)) .. " seconds" .. get_modifiers_string()
        end
    end

    local scale = 1
    local width = djui_hud_measure_text(text) * scale
    local x = (djui_hud_get_screen_width() - width) * 0.5

    djui_hud_set_adjusted_color(0, 0, 0, 128)
    djui_hud_render_rect(x - 6, 0, width + 12, 16)
    djui_hud_set_adjusted_color(255, 255, 255, 255)
    djui_hud_print_text(text, x, 0, scale)

    hud_render_power_meter(gMarioStates[0].health, djui_hud_get_screen_width() - 64, 0, 64, 64)

    djui_hud_set_font(FONT_HUD)

    djui_hud_render_texture(gTextures.coin, 5, 5, 1, 1)
    djui_hud_print_text("x", 21, 5, 1)
    djui_hud_print_text(tostring(hud_get_value(HUD_DISPLAY_COINS)), 37, 5, 1)

    if gGlobalSyncTable.speedMultiplier ~= 1 then
        djui_hud_print_text(string.format("%.2fx", gGlobalSyncTable.speedMultiplier), 5, 24, 1)
    end

    if ENABLE_SCOREBOARD or ENABLE_HEIGHT_METER then
        render_flood_hud()
    end
end)

hook_event(HOOK_ON_WARP, function()
    --- @type MarioState
    local m = gMarioStates[0]

    if gLevels[gGlobalSyncTable.area].startPos ~= nil then
        local start = gLevels[gGlobalSyncTable.area].startPos
        vec3f_copy(m.pos, start)
        set_mario_action(m, ACT_SPAWN_SPIN_AIRBORNE, 0)
        m.faceAngle.y = start.a
    end

    for i, ientry in ipairs(flood_coins) do
        if m.area.index == ientry.area then
            for j, jentry in ipairs(ientry.coins) do
                local model = (jentry.shadow and E_MODEL_RED_COIN
                                or E_MODEL_RED_COIN_NO_SHADOW)
                spawn_non_sync_object(
                    id_bhvRedCoin,
                    model,
                    jentry.x, jentry.y, jentry.z,
                    function (obj)
                        obj.oOpacity = 255
                        obj.oFaceAnglePitch = 0
                        obj.oFaceAngleYaw = 0
                        obj.oFaceAngleRoll = 0
                    end
                )
            end
        end
    end
end)

hook_event(HOOK_ON_LEVEL_INIT, function()
    -- reset save
    save_file_erase_current_backup_save()
    save_file_set_using_backup_slot(true)

    if gGlobalSyncTable.roundState == ROUND_STATE_ACTIVE then
        if network_is_server() then
            local start = gLevels[gGlobalSyncTable.area].startPos
            if start ~= nil then
                gGlobalSyncTable.waterLevel = find_floor_height(start.x, start.y, start.z) - 1200
            else
                gGlobalSyncTable.waterLevel = find_floor_height(gMarioStates[0].pos.x, gMarioStates[0].pos.y, gMarioStates[0].pos.z) - 1200
            end
        end

        spawn_non_sync_object(
            id_bhvWater,
            E_MODEL_FLOOD,
            0, gGlobalSyncTable.waterLevel, 0,
            nil
        )
    end

    local pos = gLevels[gGlobalSyncTable.area].goalPos

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
    if network_is_server() and gGlobalSyncTable.roundState == ROUND_STATE_INACTIVE then
        gGlobalSyncTable.timer = ROUND_COOLDOWN
    end
end)

hook_chat_command('flood-scoreboard', '- Toggle Flood Scoreboard', function()
    ENABLE_SCOREBOARD = not ENABLE_SCOREBOARD
    if ENABLE_SCOREBOARD then
        djui_popup_create("Flood: \n\\#00C7FF\\Scoreboard Enabled", 1)
    else
        djui_popup_create("Flood: \n\\#A02200\\Scoreboard Disabled", 1)
    end
    return true
end)

hook_chat_command('flood-height-meter', '- Toggle Flood Height Meter', function()
    ENABLE_HEIGHT_METER = not ENABLE_HEIGHT_METER
    if ENABLE_HEIGHT_METER then
        djui_popup_create("Flood: \n\\#00C7FF\\Height Meter Enabled", 1)
    else
        djui_popup_create("Flood: \n\\#A02200\\Height Meter Disabled", 1)
    end
    return true
end)

if network_is_server() or network_is_moderator() then
    hook_chat_command("flood", "\\#00ffff\\[start|speed|hardmode|type|reset-all-points|set-points]", on_flood_command)
end

for i = 0, MAX_PLAYERS - 1 do
    gPlayerSyncTable[i].finished = false
    gGlobalSyncTable.points[i] = 0
end