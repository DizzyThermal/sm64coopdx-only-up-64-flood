-- Models
E_MODEL_FLOOD = smlua_model_util_get_id("flood_geo")

-- Textures
_G.ou64_gold_medal = get_texture_info("gold_medal")
_G.ou64_silver_medal = get_texture_info("silver_medal")
_G.ou64_bronze_medal = get_texture_info("bronze_medal")
_G.flood_flag_texture = get_texture_info("flood_flag")

-- Flood Types (Water/Lava/Sand/Mud)
_G.ou64_flood_types = {
    water = 0,
    lava = 1,
    sand = 2,
    mud = 3,
}

-- State Variables
_G.flag_prev_pos = { x = 0, y = 0 }
_G.ou64_flood_area = 1
_G.ou64_flood_cheats = false
_G.ou64_flood_coins = nil
_G.ou64_flood_enable_scoreboard = true
_G.ou64_flood_in_lobby = true
_G.ou64_flood_moveset = false
_G.ou64_flood_ou64_moveset = false
_G.ou64_flood_points_for_winning = 4
_G.ou64_flood_random_type = true
_G.ou64_flood_round_cooldown = 600
_G.ou64_flood_start_level = -20000
_G.ou64_flood_type = _G.ou64_flood_types.water
_G.ou64_global_timer = 0
_G.ou64_listed_survivors = false

-- Sync Table Variables
gGlobalSyncTable.area = _G.ou64_flood_area
gGlobalSyncTable.hardmode = false
gGlobalSyncTable.points_for_winning = _G.ou64_flood_points_for_winning
gGlobalSyncTable.round_state = 0
gGlobalSyncTable.speed_multiplier = 1
gGlobalSyncTable.timer = _G.ou64_flood_round_cooldown
gGlobalSyncTable.water_level = _G.ou64_flood_start_level
gGlobalSyncTable.water_type = _G.ou64_flood_types.water

gPlayerSyncTable[0].points = 0
gPlayerSyncTable[0].time = 0

-- Other Settings
gServerSettings.skipIntro = 1
gServerSettings.stayInLevelAfterStar = 2

hud_hide()

-- Debug Variables
_G.ou64_flood_debug = false

--
-- Add Only Up 64 Areas
--
_G.ou64_flood_levels = {
    [1] = {
        name = "a1", speed = 3.0,
        start_pos = { x =  5706, y = -16256, z = -5594, a = -0x2000 },
        goal_pos = { x =   1350, y = 16782, z =   906, a = -0x4000 },
    },
    [2] = {
        name = "a2", speed = 3.5,
        start_pos = { x =  2880, y = -14954, z =  -638, a =  0x8000 },
        goal_pos = { x =  -6165, y = 14780, z = -1129, a =  0x8000 },
    },
    [3] = {
        name = "a3", speed = 4.5,
        start_pos = { x = -5688, y = -16268, z =  1033, a =  0x0000 },
        goal_pos = { x =  -5550, y = 16232, z =  2789, a =  0x0000 },
    },
    [4] = {
        name = "a4", speed = 4.0,
        start_pos = { x = -4636, y = -15197, z =  1803, a =  0x6000 },
        goal_pos = { x =  -5162, y = 15980, z = -3834, a =  0x4000 },
    },
    [5] = {
        name = "a5", speed = 4.0,
        start_pos = { x = -4448, y = -15151, z = -2662, a =  0x4000 },
        goal_pos = { x =   146, y = 16390, z = -4563, a =  0x4000 },
    },
    [6] = {
        name = "a6", speed = 4.0,
        start_pos = { x = -2698, y = -13998, z = -5864, a = -0x4000 },
        goal_pos = { x =  -2697, y = 16045, z = -5832, a =  0x0000 },
    },
    [7] = {
        name = "a7", speed = 5.0,
        start_pos = { x = -2203, y = -15508, z = -4705, a =  0x0000 },
        goal_pos = { x =   2103, y = 15660, z =  5906, a =  0x8000 },
    },
    [0] = {
        name = "a8", speed = 5.0,
        start_pos = { x =  2132, y = -16334, z =  5847, a = -0x4000 },
        goal_pos = { x =  -2085, y = 13600, z = -1303, a =  0x0000 },
    },
}
_G.ou64_map_rotation = { 1, 2, 3, 4, 5, 6, 7, 0 }

--
-- Add Flood Red Coins
--
_G.ou64_flood_coins = {
    [1] = {
        { x = -3113, y = -12287, z = 1565, shadow = true },
        { x = -4071, y = -11821, z =  868, shadow = true },
        { x = -1466, y =  -4101, z =  240, shadow = true },
        { x = -1677, y =   -494, z = 3928, shadow = true },
    },
    [2] = {
        { x = -6303, y = -12056, z = -1492, shadow = true  },
        { x =  2763, y =  -7391, z = -2530, shadow = true  },
        { x =   142, y =   4839, z =  3478, shadow = false },
        { x = -4326, y =  10957, z =  1952, shadow = true  },
    },
    [3] = {
        { x = -1197, y = -12849, z =  6076, shadow = true  },
        { x =  2661, y =  -2638, z = -5825, shadow = false },
        { x =  -345, y =     73, z = -1257, shadow = true  },
        { x =  1542, y =   5594, z =  6155, shadow = true  },
    },
    [4] = {
        { x = -2734, y = -11568, z =   871, shadow = true },
        { x = -4178, y =  -9529, z = -1195, shadow = true },
        { x = -2936, y =  -6120, z = -1837, shadow = true },
        { x =  3092, y =  -2576, z =  2342, shadow = true },
    },
    [5] = {
        { x = -170, y = -12341, z = -1973, shadow = true },
        { x = 1569, y = -10634, z = -1623, shadow = true },
        { x = 5642, y =  -6985, z =   819, shadow = true },
        { x = 5777, y =  -5059, z =  4136, shadow = true },
        { x = 4515, y =    -20, z = -3258, shadow = true },
    },
    [6] = {
        { x = -4247, y = -9620, z = -1656, shadow = true },
        { x = -4464, y = -9135, z =   567, shadow = true },
        { x =  -992, y = -6474, z =  5365, shadow = true },
        { x =  6320, y = -3671, z =   410, shadow = true },
        { x = -4157, y =  4354, z =  3987, shadow = true },
        { x = -1797, y = 12831, z =  2381, shadow = true },
    },
    [7] = {
        { x = -2786, y = -14329, z = -3318, shadow = true },
        { x = -1490, y = -11735, z = -4346, shadow = true },
        { x = -1990, y =  -7580, z = -5642, shadow = true },
        { x =  -731, y =  -4418, z = -5755, shadow = true },
        { x = -1255, y =   1487, z = -2010, shadow = true },
        { x = -1118, y =   5994, z =  5506, shadow = true },
    },
    [0] = {
        { x =   254, y = -12028, z =  3578, shadow = true },
        { x =   159, y = -10724, z =  1445, shadow = true },
        { x = -2383, y =  -7167, z =   145, shadow = true },
        { x =   132, y =  -3857, z =  3574, shadow = true },
        { x = -2542, y =    225, z =  2811, shadow = true },
        { x = -2515, y =   8582, z = -1160, shadow = true },
    },
}
