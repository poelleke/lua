--[[
    Script: Runecrafter
    Description: Crafting runes through Abyssal dimension.

    Author: Valtrex
    Version: 1.0
    Release Date: 02-04-2024

    Release Notes:
    - Version 1.0 : Initial release

    You will need:
    - wildy sword on abilitybar or edgevillage lodestone on abilitybar for teleporting back to the bank.
    - Nexus Mod relic power
    - bank uses: "load last preset"

    TODO:
    - Powerburst
    - Familiar
    - Soul Rune
    - Law Rune
    - outer ring navigation and skill lvl req:
      - Chopping away the tendrils using a hatchet with 30 Woodcutting
      - Chopping away the tendrils using a hatchet with 30 Woodcutting
      - Mining through the rock using a pickaxe with 30 Mining
      - Distracting the eyes with 30 Thieving
      - Squeezing through the gap with 30 Agility
      - Burning away the boil using a tinderbox with 30 Firemaking
      - Going through the passage
    - demonic skull

]]


local API = require("api")

local skill          = "RUNECRAFTING"
local version        = "1.0"
local selectedAltar  = nil
local selectedPortal = nil
local selectedArea   = nil
LOCATIONS            = nil
local scriptPaused   = true
local afk            = os.time()
local needNexusMod
local needDemonicSkull

local aioSelect = API.CreateIG_answer()
local aioOptions = {
    {
        label = "Air rune",
        ALTARIDID = 2478,
        PORTALID = 7139,
        AREAID = { x = 2841, y = 4830, z = 0 }
    },
    {
        label = "Mind rune",
        ALTARIDID = 2479,
        PORTALID = 7140,
        AREAID = { x = 2784, y = 4843, z = 0 }
    },
    {
        label = "water rune",
        ALTARIDID = 2480,
        PORTALID = 7137,
        AREAID = { x = 3493, y = 4832, z = 0 }
    },
    {
        label = "Earth rune",
        ALTARIDID = 2481,
        PORTALID = 7130,
        AREAID = { x = 2657, y = 4830, z = 0 }
    },
    {
        label = "Fire rune",
        ALTARIDID = 2482,
        PORTALID = 7129,
        AREAID = { x = 2577, y = 4846, z = 0 }
    },
    {
        label = "Body rune",
        ALTARIDID = 2483,
        PORTALID = 7131,
        AREAID = { x = 2520, y = 4846, z = 0 }
    },
    {
        label = "Cosmic rune",
        ALTARIDID = 2484,
        PORTALID = 7132,
        AREAID = { x = 2142, y = 4844, z = 0 }
    },
    {
        label = "Chaos rune",
        ALTARIDID = 2487,
        PORTALID = 7134,
        AREAID = { x = 2270, y = 4844, z = 0 }
    },
    {
        label = "Nature rune",
        ALTARIDID = 2486,
        PORTALID = 7133,
        AREAID = { x = 2400, y = 4835, z = 0 }
    },
    {
        label = "Death rune",
        ALTARIDID = 2488,
        PORTALID = 7136,
        AREAID = { x = 2208, y = 4829, z = 0 }
    },
    {
        label = "Blood rune",
        ALTARIDID = 30624,
        PORTALID = 7141,
        AREAID = { x = 2466, y = 4897, z = 0 }
    },
}

local LODESTONES     = {
    ["Edgeville"] = 16,
}

local TELEPORTS      = {
    ["Edgeville Lodestone"] = 31870,
}

local ID             = {
    CRAFTING_ANIMATION = 23250,
    WILDY_SWORD = { 37904, 37905, 37906, 37907, 41376, 41377 },
    POUCHE = { 5509, 5510, 5512, 5514, 24205 },
    WILDY_WALL = { 65076, 65078, 65077, 65080, 65079, 65082, 65081, 65084, 65083, 65087, 65086, 65085, 65105, 65096, 65088, 65102, 65090, 65089, 65092, 65091, 65094, 65093, 65101, 65095, 65103, 65104, 65100, 65099, 65098, 65097, 1440, 1442, 1441, 1444, 1443},
    BANK = { 42377, 42378 },
    BANK_NPC = 2759,
    ESSENCE = {7936,18178},
    MAGE = 2257,
}

local AREA           = {
    EDGEVILLE_LODESTONE = { x = 3067, y = 3505, z = 0 },
    WILDY = { x= 3103, y = 3523,  z = 0 },
    ABBY = { x = 3040, y = 4843, z = 0 }
}

local function setupOptions()

    btnStop = API.CreateIG_answer()
    btnStop.box_start = FFPOINT.new(200, 125, 0)
    btnStop.box_name = " STOP "
    btnStop.box_size = FFPOINT.new(90, 50, 0)
    btnStop.colour = ImColor.new(255, 255, 255)
    btnStop.string_value = "STOP"

    btnStart = API.CreateIG_answer()
    btnStart.box_start = FFPOINT.new(90, 125, 0)
    btnStart.box_name = " START "
    btnStart.box_size = FFPOINT.new(90, 50, 0)
    btnStart.colour = ImColor.new(0, 0, 255)
    btnStart.string_value = "START"
    btnStart.radius = 1.0

    IG_Text = API.CreateIG_answer()
    IG_Text.box_name = "TEXT"
    IG_Text.box_start = FFPOINT.new(50, 15, 0)
    IG_Text.colour = ImColor.new(255, 255, 255);
    IG_Text.string_value = "AIO Runecrafter - (v" .. version .. ") by Valtrex"

    IG_Back = API.CreateIG_answer()
    IG_Back.box_name = "back";
    IG_Back.box_start = FFPOINT.new(0, 0, 0)
    IG_Back.box_size = FFPOINT.new(370, 175, 0)
    IG_Back.colour = ImColor.new(15, 13, 18, 255)
    IG_Back.string_value = ""

    tickJagexAcc = API.CreateIG_answer();
    tickJagexAcc.box_ticked = true
    tickJagexAcc.box_name = "Jagex Account"
    tickJagexAcc.box_start = FFPOINT.new(50, 60, 0);
    tickJagexAcc.colour = ImColor.new(0, 255, 0);
    tickJagexAcc.tooltip_text = "Sets idle timeout to 15 minutes for Jagex accounts"

    tickNexusMod = API.CreateIG_answer();
    tickNexusMod.box_ticked = true
    tickNexusMod.box_name = "Nexus Mod relic power"
    tickNexusMod.box_start = FFPOINT.new(50, 80, 0);
    tickNexusMod.colour = ImColor.new(0, 255, 0);
    tickNexusMod.tooltip_text = "Arrive at the centre of the Abyss when entering."

    aioSelect.box_name = "AIO"
    aioSelect.box_start = FFPOINT.new(50, 30, 0)
    aioSelect.box_size = FFPOINT.new(250, 0, 0)
    aioSelect.stringsArr = { }
    aioSelect.tooltip_text =
    "Select the rune to craft"
    
    table.insert(aioSelect.stringsArr, "Select an option")
    for i, v in ipairs(aioOptions) do
        table.insert(aioSelect.stringsArr, v.label)
    end

    API.DrawSquareFilled(IG_Back)
    API.DrawTextAt(IG_Text)
    API.DrawBox(btnStart)
    API.DrawBox(btnStop)
    API.DrawCheckbox(tickNexusMod)
    API.DrawCheckbox(tickJagexAcc)
    API.DrawComboBox(aioSelect, false)
end

setupOptions()
API.ScriptRuntimeString()
API.GetTrackedSkills()

local function idleCheck()
    local timeDiff = os.difftime(os.time(), afk)
    local randomTime = math.random((MAX_IDLE_TIME_MINUTES * 60) * 0.6, (MAX_IDLE_TIME_MINUTES * 60) * 0.9)

    if timeDiff > randomTime then
        API.PIdle2()
        afk = os.time()
    end
end

local function walkToTile(tile)
    API.DoAction_Tile(tile)
    lastTile = tile
    API.RandomSleep2(200, 150, 150)
    API.WaitUntilMovingEnds()
end

local function isAtLocation(location, distance)
    local distance = distance or 20
    return API.PInArea(location.x, distance, location.y, distance, location.z)
end

local function isTeleportOptionsUp()
    local vb2874 = API.VB_FindPSettinOrder(2874, -1)
    return (vb2874.state == 13) or (vb2874.stateAlt == 13)
end

local function isLodestoneInterfaceUp()
    return #API.ScanForInterfaceTest2Get(true, { { 1092, 1, -1, -1, 0 }, { 1092, 54, -1, 1, 0 } }) > 0
end

local function getABS_id(id, name)
    for i = 0, 4, 1 do
        local ab = API.GetAB_id(i, id)
        if ab.id == id then
            return ab
        end
    end
    return false
end

local function teleportToLodestone(name)
    local id = LODESTONES[name]
    if isLodestoneInterfaceUp() then
        API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1092, id, -1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(1600, 800, 800)
    else
        API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1465, 18, -1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(300, 300, 300)
    end
end

local function teleportToDestination(destination, isLodestone)
    local str = isLodestone and " Lodestone" or " Teleport"
    local destinationStr = destination .. str
    local id = TELEPORTS[destinationStr]
    local hasLodestone = LODESTONES[destination] ~= nil
    local teleportAbility = (id ~= nil) and getABS_id(id, destinationStr) or API.GetABs_name1(destinationStr)
    if teleportAbility.enabled then
        API.DoAction_Ability_Direct(teleportAbility, 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(1200, 300, 300)
        return true
    elseif isLodestone or hasLodestone then
        teleportToLodestone(destination)
    end
    return false
end

local function teleportToEdgeville()
    local ws = API.GetABs_name1("Wilderness sword")
    if ws.enabled and ws.action == "Edgeville" then
        API.DoAction_Ability_Direct(ws, 1, API.OFF_ACT_GeneralInterface_route)
    else
        teleportToDestination("Edgeville", true)
    end
end

local function Walk()        
    if isAtLocation(AREA.EDGEVILLE_LODESTONE, 33) then
        API.RandomSleep2(2500, 150, 150)
        API.WaitUntilMovingandAnimEnds()
        if API.InvFull_() then
            API.RandomSleep2(200, 150, 150)
            API.WaitUntilMovingandAnimEnds()
            local tile = WPOINT.new(3103 + math.random(-2, 2), 3517 + math.random(-2, 2), 0)
            walkToTile(tile)
            API.RandomSleep2(500, 150, 150)
            API.WaitUntilMovingandAnimEnds()
            if p.y < 3521 then
                API.DoAction_Object1(0xb5, API.OFF_ACT_GeneralObject_route0, { 65084 },20)
                API.RandomSleep2(500, 150, 150)
                API.WaitUntilMovingandAnimEnds()
            end            
        else
            API.RandomSleep2(2500, 650, 500)
            API.WaitUntilMovingandAnimEnds()
            API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route4, { ID.BANK_NPC }, 50)
        end
    elseif p.y > 3521 and isAtLocation(AREA.WILDY, 35) then
        if API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route, { ID.MAGE }, 25) then
            API.RandomSleep2(500, 650, 500)
            API.WaitUntilMovingandAnimEnds()
        else
            local tile = WPOINT.new(3103 + math.random(-2, 2), 3550 + math.random(-2, 2), 0)
            walkToTile(tile)
            API.RandomSleep2(500, 150, 150)
            API.WaitUntilMovingandAnimEnds()
        end
    elseif isAtLocation(AREA.ABBY, 15) then
        API.RandomSleep2(500, 650, 500)
        API.DoAction_Object1(0x29,0,{ selectedPortal },50);
        API.RandomSleep2(500, 650, 500)
        API.WaitUntilMovingandAnimEnds()
    elseif isAtLocation(selectedArea, 15) then
        if API.InvFull_() then
            API.RandomSleep2(250, 650, 500)
            API.DoAction_Object1(0x42,0,{ selectedAltar },15);
            API.RandomSleep2(250, 650, 500)
            API.WaitUntilMovingandAnimEnds()
        else 
            teleportToEdgeville()
            print("Done! Teleporting back for LoopyLoop!")
            API.RandomSleep2(250, 650, 500)
            API.WaitUntilMovingandAnimEnds()
        end
    else
        teleportToEdgeville()
        print("Unknown area Teleport back to Edgeville!")
        API.RandomSleep2(250, 650, 500)
        API.WaitUntilMovingandAnimEnds()
    end
end

while API.Read_LoopyLoop() do
 ---------------- UI
    if scriptPaused then
        if btnStop.return_click then
            API.Write_LoopyLoop(false)
        end
        if btnStart.return_click then
            IG_Back.remove = true
            btnStart.remove = true
            IG_Text.remove = true
            btnStop.remove = true
            aioSelect.remove = true
            tickJagexAcc.remove = true
            tickNexusMod.remove = true

            needNexusMod = not tickNexusMod.box_ticked
            MAX_IDLE_TIME_MINUTES = (tickJagexAcc.box_ticked == 1) and 5 or 15
            scriptPaused = false
            startTime = os.time()

            if (aioSelect.return_click) then
                aioSelect.return_click = false
                for i, v in ipairs(aioOptions) do
                    if (aioSelect.string_value == v.label) then
                        selectedAltar = v.ALTARIDID
                        selectedPortal = v.PORTALID
                        selectedArea = v.AREAID 
                    end
                end
            end
        
            if selectedAltar == nil then
                API.Write_LoopyLoop(false)
                print("Please select a Rune type from the dropdown menu!")
            end
            if not tickNexusMod.box_ticked then
                API.Write_LoopyLoop(false)
                print("You need Nexus Mod relic to use this script.")
                print("Outer ring is not working yet!.")
            end
        end
        goto continue
    end    
 -------------END UI 
    API.SetDrawTrackedSkills(true)
    p = API.PlayerCoordfloat()
    idleCheck()
    API.DoRandomEvents()

    Walk()

    API.RandomSleep2(500,500,500)

    ::continue::
    API.RandomSleep2(500, 650, 500)
end