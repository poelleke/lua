--=========================================================================--
-- Construction AIO
--
-- Data.lua
--
-- Central location for all RuneScape data used by the Construction AIO.
--
-- Sources:
-- https://runescape.wiki/
-- https://mejrs.github.io/
--
--=========================================================================--

local Data = {}

--========================================================================--
-- Items
--========================================================================--

Data.Items = {

------------------------------------------------------------------------
-- Materials: log's and plank's
------------------------------------------------------------------------
Materials = {
    [0]  = { Name = "Regular",  Log = 1511,   Plank = 960,   },
    [1]  = { Name = "Oak",      Log = 1521,   Plank = 8778,  },
    [2]  = { Name = "Willow",   Log = 1519,   Plank = 8784,  },
    [3]  = { Name = "Teak",     Log = 6333,   Plank = 8780,  },
    [4]  = { Name = "Maple",    Log = 1517,   Plank = 54862, },
    [5]  = { Name = "Acadia",   Log = 40285,  Plank = 54864, },
    [6]  = { Name = "Mahogany", Log = 6332,   Plank = 8782,  },
    [7]  = { Name = "Yew",      Log = 1515,   Plank = 54866, },
    [8]  = { Name = "Magic",    Log = 1513,   Plank = 54868, },
    [9]  = { Name = "Elder",    Log = 29556,  Plank = 54870, },
    [10] = { Name = "Eternal",  Log = 58250,  Plank = 63190, },
},

    ------------------------------------------------------------------------
    -- Nails
    ------------------------------------------------------------------------
    Nails = {
        bronze  = 4819,
        iron    = 4820,
        steel   = 1539,
        black   = 4821,
        mithril = 4822,
        adamant = 4823,
        rune    = 4824
    },

    ------------------------------------------------------------------------
    -- Bars
    ------------------------------------------------------------------------
    Bars = {
        bronze  = 4819,
        iron    = 4820,
        steel   = 1539,
        mithril = 4822,
        adamant = 4823,
        rune    = 4824
    },

    ------------------------------------------------------------------------
    -- Stone
    ------------------------------------------------------------------------
    Stone = {

        Limestone       = 0,
        LimestoneBrick  = 0,
        MarbleBlock     = 0,
        MagicStone      = 0,

    },

    ------------------------------------------------------------------------
    -- Misc
    ------------------------------------------------------------------------
    misc = {
        white_candle  = 36,
        bolt_of_cloth = 8790,
        plank_box     = 51022,
        contract      = 50916
    },

    PlankIds = {
        ["Plank"]          = 960,
        ["Oak plank"]      = 8778,
        ["Teak plank"]     = 8780,
        ["Mahogany plank"] = 8782,
        ["Acadia plank"]   = 54860,
        ["Elder plank"]    = 54862,
        ["Crystal plank"]  = 54864,
        ["Teak frame"]     = 54866,
        ["Mahogany frame"] = 54868,
        ["Magic plank"]    = 54870,
        ["Eternal plank"]  = 63190
    },

    NailNames = {
        "Bronze nails", "Iron nails", "Steel nails", "Black nails",
        "Mithril nails", "Adamantite nails", "Rune nails"
    },

    Containers = {
        PlankBox = 895
    }

}

--========================================================================--
-- Travel data
--========================================================================--
Data.Lodestones = {
    ["Edgeville"] = 15,
    ["Draynor"]   = 14,
    ["Lumbridge"] = 17,
    ["Varrock"]   = 21
}

--========================================================================--
-- Objects
--========================================================================--
Data.Objects = {
    Bank = 115427,
    Sawmill = 139148,
    FurnitureWorkbench = 139147,
    FurnitureStorage = 139146,

}

--========================================================================--
-- Furniture Construction
--========================================================================--
Data.Furniture = {
    GreenMaterialSprite = 13165,
    RedMaterialSprite = 13166,

    PlankTypes = { "Wooden", "Oak", "Teak", "Mahogany", "Eternal" },
    Modes = { "Chair", "Bench", "Round table", "Long table" },

    Recipes = {
        Wooden = {
            ["Chair"]       = { { name = "Plank", needed = 2 }, { name = "Steel nails", needed = 2 } },
            ["Bench"]       = { { name = "Plank", needed = 4 }, { name = "Steel nails", needed = 4 } },
            ["Round table"] = { { name = "Plank", needed = 6 }, { name = "Steel nails", needed = 6 } },
            ["Long table"]  = { { name = "Plank", needed = 8 }, { name = "Steel nails", needed = 8 } }
        },
        Oak = {
            ["Chair"]       = { { name = "Oak plank", needed = 2 } },
            ["Bench"]       = { { name = "Oak plank", needed = 4 } },
            ["Round table"] = { { name = "Oak plank", needed = 6 } },
            ["Long table"]  = { { name = "Oak plank", needed = 8 } }
        },
        Teak = {
            ["Chair"]       = { { name = "Teak plank", needed = 2 } },
            ["Bench"]       = { { name = "Teak plank", needed = 4 } },
            ["Round table"] = { { name = "Teak plank", needed = 6 } },
            ["Long table"]  = { { name = "Teak plank", needed = 8 } }
        },
        Mahogany = {
            ["Chair"]       = { { name = "Mahogany plank", needed = 2 } },
            ["Bench"]       = { { name = "Mahogany plank", needed = 4 } },
            ["Round table"] = { { name = "Mahogany plank", needed = 6 } },
            ["Long table"]  = { { name = "Mahogany plank", needed = 8 } }
        },
        Eternal = {
            ["Chair"]       = { { name = "Eternal plank", needed = 2 } },
            ["Bench"]       = { { name = "Eternal plank", needed = 4 } },
            ["Round table"] = { { name = "Eternal plank", needed = 6 } },
            ["Long table"]  = { { name = "Eternal plank", needed = 8 } }
        }
    }
}

--========================================================================--
-- Hotspot data for contract script
--========================================================================--
Data.HOTSPOTS = {
    "Shelf space",
    "Drawers space",
    "Bookcase space",
    "Table space",
    "Counter space",
    "Wardrobe space",
    "Chair space",
    "Sink space",
    "Bed space",
    "Shelf space",
    "Stove space",
    "Lighting space",
    "Portrait space",
    "Chest space",
    "Bench space",
    "Wheel space",
    "Stool space",
    "Pew space",
    "Votary space",
    "Desk space",
    "Organ space",
    "Ladder space",
    "Altar space",
    "Stand space",
    "Shelves space",
}

--========================================================================--
-- Door data for contract script
--========================================================================--
Data.DOORS = {
    FatherAereck = {
        name = "Father Aereck",
        object_name = "Church door",
        trigger =   { x = 3242, y = 3212, floor = 0, radius = 35 },
        closed =    { { id = 36999, x = 3239, y = 3210, floor = 0 }, { id = 37002, x = 3239, y = 3209, floor = 0 } },
        open =      { { id = 37000, x = 3240, y = 3210, floor = 0 }, { id = 37003, x = 3240, y = 3209, floor = 0 } }
    },
        Victoria = {
        name = "Victoria",
        object_name = "Door",
        trigger =   { x = 3234, y = 3207, floor = 0, radius = 35 },
        closed =    { { id = 45476, x = 3234, y = 3207, floor = 0 } },
        open =      { { id = 45477, x = 3233, y = 3207, floor = 0 } }
    },
        NED = {
        name = "Ned",
        object_name = "Door",
        trigger =   { x = 3103, y = 3257, floor = 0, radius = 35 },
        closed =    { { id = 1239, x = 3103, y = 3257, floor = 0 } },
        open =      { { id = 1240, x = 3102, y = 3257, floor = 0 } }
    },
        WiseOldMan = {
        name = "Wise old man",
        object_name = "Door",
        trigger =   { x = 3088, y = 3250, floor = 0, radius = 35 },
        closed =    { { id = 1239, x = 3088, y = 3250, floor = 0 } },
        open =      { { id = 1240, x = 3088, y = 3251, floor = 0 } }
    },
        Aggie = {
        name = "Aggie",
        object_name = "Door",
        trigger =   { x = 3088, y = 3259, floor = 0, radius = 35 },
        closed =    { { id = 1239, x = 3088, y = 3259, floor = 0 } },
        open =      { { id = 1240, x = 3087, y = 3259, floor = 0 } }
    },
        Charos = {
        name = "Charos",
        object_name = "Door",
        trigger =   { x = 3243, y = 3450, floor = 0, radius = 35 },
        closed =    { { id = 24376, x = 3243, y = 3450, floor = 0 } },
        open =      { { id = 24375, x = 3242, y = 3450, floor = 0 } }
    }
}

--========================================================================--
-- Exterior approach points for contract buildings with a front door
--========================================================================--
Data.ENTRANCES = {
    ["Father Aereck"] = {
        outside = {
            { x = 3238, y = 3210, floor = 0 },
            { x = 3238, y = 3209, floor = 0 }
        },
        insideMargin = 1
    },
    ["Ned"] = {
        outside = {
            { x = 3104, y = 3257, floor = 0 }
        },
        insideMargin = 1
    },
    ["Aggie"] = {
        outside = {
            { x = 3091, y = 3260, floor = 0 }
        },
        insideMargin = 1
    },
    ["Wise old man"] = {
        outside = {
            { x = 3088, y = 3248, floor = 0 }
        },
        insideMargin = 1
    },
    ["Victoria"] = {
        outside = {
            { x = 3235, y = 3207, floor = 0 }
        },
        insideMargin = 1
    },
    ["Charos"] = {
        outside = {
            { x = 3246, y = 3450, floor = 0 }
        },
        insideMargin = 1
    }
}

--========================================================================--
-- Interior access doors for contract buildings
--========================================================================--
Data.ACCESS_DOORS = {
    ShopkeeperVarrock   = { { id = 24376, x = 3217, y = 3413, floor = 1, action = 0x31 } },
    ShopkeeperLumbridge = { { id = 45476, x = 3215, y = 3242, floor = 1, action = 0x31 } },
    Charos              = { { id = 24376, x = 3238, y = 3450, floor = 0, action = 0x31 } }
}

-- Hotspots die vóór een toegangsdeur moeten worden gebouwd.
Data.REPAIR_PRIORITIES = {
    {
        location = "Lumbridge",
        npc = "The shopkeeper",
        hotspots = {
            { id = 118242, x = 3214, y = 3243, floor = 1, name = "Shelf space" }
        }
    }
}

--========================================================================--
-- Interior room routes for contract buildings
--========================================================================--
Data.ACCESS_ROUTES = {
    Bartender = {
        roomOrder = {
            "right_room",
            "left_room",
            "middle_room",
            "balcony",
            "last_room",
            "hall"
        },
        repairOrder = {
            "left_room",
            "right_room",
            "middle_room",
            "balcony",
            "last_room"
        },
        rooms = {
            hall = {
                { x1 = 3223, y1 = 3393, x2 = 3233, y2 = 3397, floor = 1 }
            },
            right_room = {
                { x1 = 3229, y1 = 3397, x2 = 3233, y2 = 3401, floor = 1 },
                { x1 = 3231, y1 = 3401, x2 = 3233, y2 = 3403, floor = 1 }
            },
            left_room = {
                { x1 = 3218, y1 = 3393, x2 = 3223, y2 = 3397, floor = 1 }
            },
            middle_room = {
                { x1 = 3224, y1 = 3397, x2 = 3229, y2 = 3400, floor = 1 },
                { x1 = 3226, y1 = 3400, x2 = 3229, y2 = 3401, floor = 1 }
            },
            balcony = {
                { x1 = 3226, y1 = 3401, x2 = 3231, y2 = 3403, floor = 1 },
                { x1 = 3224, y1 = 3400, x2 = 3226, y2 = 3403, floor = 1 }
            },
            last_room = {
                { x1 = 3218, y1 = 3397, x2 = 3224, y2 = 3404, floor = 1 }
            }
        },
        doors = {
            {
                closed = { id = 24376, x = 3230, y = 3397, floor = 1 },
                open = { id = 24375, x = 3230, y = 3396, floor = 1 },
                action = 0x31, from = "hall", to = "right_room"
            },
            {
                closed = { id = 24376, x = 3223, y = 3395, floor = 1 },
                open = { id = 24375, x = 3223, y = 3395, floor = 1 },
                action = 0x31, from = "hall", to = "left_room"
            },
            {
                closed = { id = 24376, x = 3226, y = 3397, floor = 1 },
                open = { id = 24375, x = 3226, y = 3396, floor = 1 },
                action = 0x31, from = "hall", to = "middle_room"
            },
            {
                closed = { id = 24376, x = 3227, y = 3401, floor = 1 },
                open = { id = 24375, x = 3227, y = 3400, floor = 1 },
                action = 0x31, from = "middle_room", to = "balcony"
            },
            {
                closed = { id = 24376, x = 3224, y = 3401, floor = 1 },
                open = { id = 24375, x = 3223, y = 3401, floor = 1 },
                action = 0x31, from = "balcony", to = "last_room"
            }
        }
    }
}

--========================================================================--
-- Stair data for contract script
--========================================================================--
Data.STAIRS = {
    Victoria = {
        up = { id = 45483, x = 3231, y = 3209, floor = 0, action = "Climb-up" },
        down = {  id = 45484, x = 3231, y = 3209, floor = 1, action = "Climb-down" }
    },
    Bob_Axes = {
        up = { id = 45483, x = 3231, y = 3205, floor = 0, action = "Climb-up" },
        down = { id = 45484, x = 3231, y = 3205, floor = 1, action = "Climb-down" }
    },
    ShopkeeperLumbridge = {
        up = { id = 45481, x = 3216, y = 3239, floor = 0, action = "Climb-up" },
        down = { id = 45482, x = 3215, y = 3239, floor = 1, action = "Climb-down" }
    },
    ShopkeeperVarrock = {
        up = { id = 24354, x = 3214, y = 3410, floor = 0, action = "Climb-up" },
        down = { id = 24355, x = 3214, y = 3410, floor = 1, action = "Climb-down" }
    },
    Shopkeeperedgevillage = {
        up = { id = 26982, x = 3082, y = 3513, floor = 0, action = "Climb-up" },
        down = { id = 26983, x = 3082, y = 3513, floor = 1, action = "Climb-down" }
    },
    Bartender = {
        up = { id = 24356, x = 3228, y = 3394, floor = 0, action = "Climb-up" },
        down = { id = 37117, x = 3229, y = 3394, floor = 1, action = "Climb-down" }
    },
    NED = {
        up = { id = 2347, x = 3101, y = 3255, floor = 0, action = "Climb-up" },
        down = { id = 2348, x = 3101, y = 3255, floor = 1, action = "Climb-down" }
    },
    WiseOldMan = {
        up = { id = 2347, x = 3092, y = 3251, floor = 0, action = "Climb-up" },
        down = { id = 2348, x = 3092, y = 3251, floor = 1, action = "Climb-down" }
    },
    Aggie = {
        up = { id = 2347, x = 3085, y = 3262, floor = 0, action = "Climb-up" },
        down = { id = 2348, x = 3085, y = 3262, floor = 1, action = "Climb-down" }
    },
    Charos = {
        up = { id = 31615, x = 3238, y = 3448, floor = 0, action = "Climb-up" },
        down = { id = 31616, x = 3238, y = 3448, floor = 1, action = "Climb-down" }
    }
}

--========================================================================--
-- NPCs
--========================================================================--
Data.NPCs = {
    Estate_agent = 4247
}

--========================================================================--
-- Area's
--========================================================================--
Data.TownAreas = {--x1 west, Y1 zuid, X2 oost, Y2 noord
    ["Edgeville"]   = { x1 = 3064,  y1 = 3482,  x2 = 3103, y2 = 3519 },
    ["Draynor"]     = { x1 = 3072,  y1 = 3234,  x2 = 3118, y2 = 3303 },
    ["Varrock"]     = { x1 = 3137,  y1 = 3373,  x2 = 3291, y2 = 3520 },
    ["Lumbridge"]   = { x1 = 3192,  y1 = 3189,  x2 = 3254, y2 = 3269 },
    ["Home"]        = { x1 = 2934,  y1 = 3216,  x2 = 2953, y2 = 3232 },
    
}
-- Database met GEBOUW-BOXEN (Area-systeem)
Data.BuildingAreas  = {
    ["Ned"]             = { x1 = 3097, y1 = 3255, x2 = 3103, y2 = 3261 },--Tweifelachtig
    ["Aggie"]           = { x1 = 3081, y1 = 3258, x2 = 3088, y2 = 3263 },--testen
    ["Wise old man"]    = { x1 = 3087, y1 = 3251, x2 = 3095, y2 = 3255 },--X2 3255 inplaats van 3256, X1:3086 door bench?
    ["Bob's Axes"]      = { x1 = 3227, y1 = 3201, x2 = 3234, y2 = 3206 },
    ["Father Aereck"]   = { x1 = 3242, y1 = 3204, x2 = 3250, y2 = 3216 },
    ["Victoria"]        = { x1 = 3229, y1 = 3206, x2 = 3234, y2 = 3210 },
    ["The bartender"]   = { x1 = 3215, y1 = 3393, x2 = 3233, y2 = 3405 },
    ["Charos"]          = { x1 = 3238, y1 = 3447, x2 = 3242, y2 = 3454 },--1 title kleiner rondom het huis als test
    ["The shopkeeper"]  = {
        ["Edgeville"]   = { x1 = 3077, y1 = 3507, x2 = 3085, y2 = 3514 },
        ["Lumbridge"]   = { x1 = 3211, y1 = 3239, x2 = 3219, y2 = 3244 },
        ["Varrock"]     = { x1 = 3213, y1 = 3410, x2 = 3221, y2 = 3421 }
    }
}

--========================================================================--
-- Interface data
--========================================================================--
Data.Interfaces = {
    CompleteSprite = 13165,
    Location = { {736,0,-1,0}, {736,2,-1,0}, {736,3,-1,0}, {736,14,-1,0} },
    NPC      = { {736,0,-1,0}, {736,2,-1,0}, {736,3,-1,0}, {736,4,-1,0} },
    Build    = { {1306,0,-1,0}, {1306,53,-1,0}, {1306,53,14,0} },
    Builds   = {
        [1] = { Path = {{1306,0,-1,0},{1306,51,-1,0},{1306,52,-1,0},{1306,1,-1,0},{1306,5,-1,0},{1306,5,3,0}} },
        [2] = { Path = {{1306,0,-1,0},{1306,51,-1,0},{1306,52,-1,0},{1306,8,-1,0},{1306,12,-1,0},{1306,12,3,0}} },
        [3] = { Path = {{1306,0,-1,0},{1306,51,-1,0},{1306,52,-1,0},{1306,15,-1,0},{1306,19,-1,0},{1306,19,3,0}} },
        [4] = { Path = {{1306,0,-1,0},{1306,51,-1,0},{1306,52,-1,0},{1306,22,-1,0},{1306,26,-1,0},{1306,26,3,0}} },
        [5] = { Path = {{1306,0,-1,0},{1306,51,-1,0},{1306,52,-1,0},{1306,29,-1,0},{1306,33,-1,0},{1306,33,3,0}} }
    },
    TaskRoutes = {
        { {736,0,-1,0}, {736,2,-1,0}, {736,5,-1,0}, {736,6,-1,0}, {736,12,-1,0} },
        { {736,0,-1,0}, {736,2,-1,0}, {736,5,-1,0}, {736,7,-1,0}, {736,16,-1,0} },
        { {736,0,-1,0}, {736,2,-1,0}, {736,5,-1,0}, {736,8,-1,0}, {736,18,-1,0} },
        { {736,0,-1,0}, {736,2,-1,0}, {736,5,-1,0}, {736,9,-1,0}, {736,20,-1,0} },
        { {736,0,-1,0}, {736,2,-1,0}, {736,5,-1,0}, {736,10,-1,0}, {736,22,-1,0} }
    },
    Furniture = {
        MainId = 1516,
        StorageId = 1518,
        NoResultsPath = {
            { 1516, 6, -1, 0 }, { 1516, 8, -1, 0 }, { 1516, 11, -1, 0 },
            { 1516, 24, -1, 0 }, { 1516, 25, -1, 0 }, { 1516, 25, 0, 0 }
        },
        SelectedPath = {
            { 1516, 6, -1, 0 }, { 1516, 8, -1, 0 }, { 1516, 12, -1, 0 },
            { 1516, 13, -1, 0 }
        },
        ResultRootPath = {
            { 1516, 6, -1, 0 }, { 1516, 8, -1, 0 }, { 1516, 11, -1, 0 },
            { 1516, 24, -1, 0 }, { 1516, 25, -1, 0 }
        },
        MaterialRootPath = {
            { 1516, 6, -1, 0 }, { 1516, 8, -1, 0 }, { 1516, 12, -1, 0 },
            { 1516, 17, -1, 0 }, { 1516, 22, -1, 0 }
        }
    }
}

return Data
