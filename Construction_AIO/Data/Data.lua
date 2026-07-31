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

    [0] = {
        Name    = "Regular",
        Log     = 1511,
        Plank   = 960,
    },

    [1] = {
        Name    = "Oak",
        Log     = 1521,
        Plank   = 8778,
    },

    [2] = {
        Name    = "Willow",
        Log     = 1519,
        Plank   = 8784,
    },

    [3] = {
        Name    = "Teak",
        Log     = 6333,
        Plank   = 8780,
    },

    [4] = {
        Name    = "Maple",
        Log     = 1517,
        Plank   = 54862,
    },

    [5] = {
        Name    = "Acadia",
        Log     = 40285,
        Plank   = 54864,
    },

    [6] = {
        Name    = "Mahogany",
        Log     = 6332,
        Plank   = 8782,
    },

    [7] = {
        Name    = "Yew",
        Log     = 1515,
        Plank   = 54866,
    },

    [8] = {
        Name    = "Magic",
        Log     = 1513,
        Plank   = 54868,
    },

    [9] = {
        Name    = "Elder",
        Log     = 29556,
        Plank   = 54870,
    },

    [10] = {
        Name    = "Eternal",
        Log     = 58250,
        Plank   = 63190,
    },

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
        plank_box     = 50450,
        contract      = 50916
    }

}

--========================================================================--
-- Objects
--========================================================================--

Data.Objects = {
    Bank = 115427,
    Sawmill = 139148,

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
}

--========================================================================--
-- Door data for contract script
--========================================================================--
Data.DOORS = {
    FatherAereck = {
        name = "Father Aereck",
        object_name = "Church door",
        trigger =   { x = 3242, y = 3212, floor = 0, radius = 20 },
        closed =    { { id = 36999, x = 3239, y = 3210, floor = 0 }, { id = 37002, x = 3239, y = 3209, floor = 0 } },
        open =      { { id = 37000, x = 3240, y = 3210, floor = 0 }, { id = 37003, x = 3240, y = 3209, floor = 0 } }
    },
        Victoria = {
        name = "Victoria",
        object_name = "Door",
        trigger =   { x = 3234, y = 3207, floor = 0, radius = 20 },
        closed =    { { id = 45476, x = 3234, y = 3207, floor = 0 } },
        open =      { { id = 45477, x = 3233, y = 3207, floor = 0 } }
    },
}

--========================================================================--
-- Stair data for contract script
--========================================================================--
Data.STAIRS = {
    Victoria = {
        up = { id = 45483, x = 3231, y = 3209, floor = 0, action = "Climb-up" },
        down = {  id = 45484, x = 3231, y = 3209, floor = 1, action = "Climb-down" }
    },
    ShopkeeperLumbridge = {
        up = { id = 45481, x = 3216, y = 3239, floor = 0, action = "Climb-up" },
        down = { id = 45482, x = 3215, y = 3239, floor = 1, action = "Climb-down" }
    },
}

--========================================================================--
-- NPCs
--========================================================================--
Data.NPCs = {
    Estate_agent = 4247
}

return Data