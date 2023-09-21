if unsupported then return end

local highestPlayerIndex = 0
local currCameraIndex = 0

local lLakituStates = {}
for i = 0, MAX_PLAYERS - 1 do
    lLakituStates[i] = {
        playerHeight = -0x8000,
        health = 0,
        pos = {
            x = 0,
            y = 0,
            z = 0,
        },
        focus = {
            x = 0,
            y = 0,
            z = 0,
        },
        yaw = 0,
        posHSpeed = 0,
        posVSpeed = 0,
        focHSpeed = 0,
        focVSpeed = 0,
    }
end

local function get_level_index()
    return if_then_else(game ~= GAME_ONLY_UP_64, gGlobalSyncTable.level, gGlobalSyncTable.area)
end

-- localize functions to improve performance - spectator.lua
local camera_config_get_x_sensitivity,camera_config_get_y_sensitivity,camera_config_is_x_inverted,camera_config_is_y_inverted,is_game_paused,djui_hud_get_raw_mouse_y,clamp,djui_hud_get_raw_mouse_x,vec3f_copy,mario_drop_held_object,set_mario_animation,vec3f_set,vec3f_mul,djui_hud_set_mouse_locked,camera_freeze,maxf,camera_config_is_free_cam_enabled,set_override_near,set_override_fov,camera_unfreeze,camera_config_is_mouse_look_enabled,allocate_mario_action = camera_config_get_x_sensitivity,camera_config_get_y_sensitivity,camera_config_is_x_inverted,camera_config_is_y_inverted,is_game_paused,djui_hud_get_raw_mouse_y,clamp,djui_hud_get_raw_mouse_x,vec3f_copy,mario_drop_held_object,set_mario_animation,vec3f_set,vec3f_mul,djui_hud_set_mouse_locked,camera_freeze,maxf,camera_config_is_free_cam_enabled,set_override_near,set_override_fov,camera_unfreeze,camera_config_is_mouse_look_enabled,allocate_mario_action

local function update_camera_from_packet(data)
    -- Ignore Packet if not Spectating
    if gMarioStates[0].action ~= ACT_SPECTATOR then return end

    -- Copy Player Camera if Highest player
    playerIndex = network_local_index_from_global(data.playerIndex)

    lLakituStates[playerIndex].playerHeight = data.playerHeight
    lLakituStates[playerIndex].health = data.health
    vec3f_set(lLakituStates[playerIndex].pos, data.posX, data.posY, data.posZ)
    vec3f_set(lLakituStates[playerIndex].focus, data.focusX, data.focusY, data.focusZ)
    lLakituStates[playerIndex].yaw = data.yaw
    lLakituStates[playerIndex].posHSpeed = data.posHSpeed
    lLakituStates[playerIndex].posVSpeed = data.posVSpeed
    lLakituStates[playerIndex].focHSpeed = data.focHSpeed
    lLakituStates[playerIndex].focVSpeed = data.focVSpeed
end

--- @param m MarioState
local function update_fp_camera(m)
    if m.playerIndex ~= 0 then return end

    vec3f_copy(gLakituState.pos, lLakituStates[currCameraIndex].pos)
    vec3f_copy(gLakituState.focus, lLakituStates[currCameraIndex].focus)
    gLakituState.yaw = lLakituStates[currCameraIndex].yaw
    gLakituState.posHSpeed = lLakituStates[currCameraIndex].posHSpeed
    gLakituState.posVSpeed = lLakituStates[currCameraIndex].posVSpeed
    gLakituState.focHSpeed = lLakituStates[currCameraIndex].focHSpeed
    gLakituState.focVSpeed = lLakituStates[currCameraIndex].focVSpeed

    print("currCameraIndex: " .. currCameraIndex)
    print("lLakituStates[currCameraIndex].pos.x: " .. lLakituStates[currCameraIndex].pos.x)
    print("lLakituStates[currCameraIndex].playerHeight: " .. lLakituStates[currCameraIndex].playerHeight)
    print("lLakituStates[currCameraIndex].health: " .. lLakituStates[currCameraIndex].health)
end

--- @param m MarioState
function set_mario_spectator(m)
    m.action = ACT_SPECTATOR
    -- First time, find highest player to lock on to
    highestHeight = -0x8000
    highestPlayerIndex = 0
    for i = 0, MAX_PLAYERS - 1 do
        if lLakituStates[i].playerHeight > highestHeight then
            highestHeight = lLakituStates[i].pos.y
            highestPlayerIndex = i
        end
    end

    currCameraIndex = highestPlayerIndex
    print("Spectator mode set")
end

local function player_trackable(i)
    return active_player(gMarioStates[i]) ~= 0
           and gMarioStates[i].health > 0xff
           and not gPlayerSyncTable[i].finished
end

local function increment_camera_counter()
    currCameraIndex = currCameraIndex + 1
    if currCameraIndex >= MAX_PLAYERS then
        currCameraIndex = 0
    end
end

local function find_next_alive_player()
    local startCameraIndex = currCameraIndex
    increment_camera_counter()
    while not player_trackable(currCameraIndex) and startCameraIndex ~= currCameraIndex do
        increment_camera_counter()
    end
end

--- @param m MarioState
local function act_spectator(m)
    mario_drop_held_object(m)
    m.squishTimer = 0

    set_mario_animation(m, MARIO_ANIM_DROWNING_PART2)
    m.marioBodyState.eyeState = MARIO_EYES_DEAD
    m.faceAngle.x = 0
    m.faceAngle.z = 0

    if gPlayerSyncTable[m.playerIndex].finished then
        m.marioObj.header.gfx.node.flags = m.marioObj.header.gfx.node.flags & ~GRAPH_RENDER_ACTIVE
        local goalPos = gLevels[get_level_index()].goalPos
        vec3f_set(m.pos, goalPos.x, goalPos.y + 600, goalPos.z)
        mario_set_full_health(m)
    else
        m.pos.y = gGlobalSyncTable.waterLevel - 70
        vec3f_copy(m.marioObj.header.gfx.pos, m.pos)
        vec3f_copy(m.marioObj.header.gfx.angle, m.faceAngle)
        m.marioObj.header.gfx.angle.y = 0
        m.health = 0xff
        m.healCounter = 0
        m.hurtCounter = 0
    end

    if m.playerIndex ~= 0 then return end

    -- Spectate Next Player
    if (not is_game_paused() and (m.controller.buttonPressed & A_BUTTON) ~= 0) or not player_trackable(currCameraIndex) then
        find_next_alive_player()
    end

    camera_freeze()
    update_fp_camera(m)
end

--- @param m MarioState
local function on_set_mario_action(m)
    if m.action == ACT_VERTICAL_WIND then
        m.vel.y = maxf(m.vel.y, 0)
    end

    if m.playerIndex ~= 0 then return end

    if m.action ~= ACT_SPECTATOR then
        camera_unfreeze()
    end
end

local function update_hud()
    if gMarioStates[0].health <= 0xFF then
        -- Draw Player Health
        djui_hud_set_resolution(RESOLUTION_N64)
        if lLakituStates[currCameraIndex] == nil then
            return
        end
        hud_render_power_meter(lLakituStates[currCameraIndex].health, djui_hud_get_screen_width() - 64, 0, 64, 64)

        -- Draw Player Name
        djui_hud_set_font(FONT_TINY)
        local spectatorText = "[A] " .. string_without_hex(gNetworkPlayers[currCameraIndex].name)
        local scale = 1
        local width = djui_hud_measure_text(spectatorText) * scale
        local height = 16 * scale
        local x = (djui_hud_get_screen_width() - width) * 0.5
        local y = (djui_hud_get_screen_height() - height)

        djui_hud_set_adjusted_color(0, 0, 0, 128)
        djui_hud_render_rect(x - 6, y, width + 12, y + height)
        djui_hud_set_adjusted_color(255, 255, 255, 255)
        djui_hud_print_text(spectatorText, x, y, scale)
    end
end

hook_event(HOOK_ON_HUD_RENDER, update_hud)
hook_event(HOOK_ON_PACKET_RECEIVE, update_camera_from_packet)
hook_event(HOOK_ON_SET_MARIO_ACTION, on_set_mario_action)


ACT_SPECTATOR = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_INVULNERABLE)

---@diagnostic disable-next-line: missing-parameter
hook_mario_action(ACT_SPECTATOR, act_spectator)