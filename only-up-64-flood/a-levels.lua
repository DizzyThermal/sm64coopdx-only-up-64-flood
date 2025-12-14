unsupported = true

FLOOD_RANDOM = -1
FLOOD_WATER  = 0
FLOOD_LAVA   = 1
FLOOD_SAND   = 2
FLOOD_MUD    = 3

LEVEL_ONLY_UP_64 = 0x32 -- 50 (Custom Level)
LEVEL_LOBBY = LEVEL_ONLY_UP_64

--- @class FloodLevel
--- @field public name string
--- @field public speed number
--- @field public startPos Vec3f
--- @field public goalPos Vec3f
--- @field public time integer
--- @field public beds table

--- @type FloodLevel[]
gLevels = {}
gMapRotation = {}

-- localize functions to improve performance
local table_insert,djui_popup_create = table.insert,djui_popup_create

local function flood_define_level(name, area, speed, startPos, goalPos)
    gLevels[area] = { name = name, speed = speed, startPos = startPos, goalPos = goalPos, time = 0, beds = {} }
    table_insert(gMapRotation, area)
end
_G.flood_define_level = flood_define_level

-- Load Levels
for mod in pairs(gActiveMods) do
    if gActiveMods[mod].incompatible ~= nil and gActiveMods[mod].incompatible:find("romhack") then
        if gActiveMods[mod].relativePath == "only-up-64" then
            --                 name  area speed start position                                     goal position
            flood_define_level("a1", 1,   3.0,  { x =  5706, y = -16256, z = -5594, a = -0x2000 }, { x =   1325, y = 16779, z =   906, a = -0x4000 })
            flood_define_level("a2", 2,   3.5,  { x =  2880, y = -14954, z =  -638, a =  0x8000 }, { x =  -6218, y = 14823, z = -1013, a =  0x8000 })
            flood_define_level("a3", 3,   4.5,  { x = -5688, y = -16268, z =  1033, a =  0x0000 }, { x =  -5556, y = 15917, z =  3092, a =  0x0000 })
            flood_define_level("a4", 4,   4.0,  { x = -4636, y = -15197, z =  1803, a =  0x6000 }, { x =  -5571, y = 15929, z = -3995, a =  0x4000 })
            flood_define_level("a5", 5,   4.0,  { x = -4448, y = -15151, z = -2662, a =  0x4000 }, { x =   1945, y = 16042, z = -4701, a =  0x4000 })
            flood_define_level("a6", 6,   4.0,  { x = -2698, y = -13998, z = -5864, a = -0x4000 }, { x =  -2966, y = 14527, z = -4003, a =  0x0000 })
            flood_define_level("a7", 7,   5.0,  { x = -2203, y = -15508, z = -4705, a =  0x0000 }, { x =   2103, y = 15664, z =  5906, a =  0x8000 })
            flood_define_level("a8", 0,   5.0,  { x =  2132, y = -16334, z =  5847, a = -0x4000 }, { x =  -2085, y = 13600, z = -1303, a =  0x0000 })
            unsupported = false
            break
        end
    end
end

-- If not Only Up 64 -- unsupported
if unsupported then
    djui_popup_create("\\#ff0000\\Only Up 64 Flood\nis not supported here", 2)
end