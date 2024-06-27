--[[
Beach event 2024 
script by Valtrex

When using spotlight and its happy hour you can set your preference at line 39
change: local Spotlight_HappyHour = "Hunter" to your choice

For Dungeoneering Hole:
local Spotlight_HappyHour = "Dung" For Dungeoneering Hole
For Bodybuilding"
local Spotlight_HappyHour = "Strength"
For Sandcastle building:
local Spotlight_HappyHour = "Construction"
For Hook-a-duck:
local Spotlight_HappyHour = "Hunter"
For Coconut shy:
local Spotlight_HappyHour = "Ranged"
for Barbecues:
local Spotlight_HappyHour = "Cooking"
For Palm Tree Farming:
local Spotlight_HappyHour = "Farming"
]]


print("Beach Event!")

local API = require("api")

local scriptPaused = true
local Spotlight = false
local InCombat = false

local ActivitySelected = "None"--DO NOT CHANGE THIS
local Spotlight_HappyHour = "Hunter" -- change this for HappyHour spotlight activity

local fail = 0

local FightClawdie
local Clawdia = 0

local Anim = {
    Enter_Hole = 27005,
    Hole = 32865,
    Exit_Hole = 23051,
    Bodybulding = 26551,
    BBQ = 6784,
    Duck = 29210,
    Coconut = 26586,
    Crul = 26552,
    Lunge = 26553,
    Fly = 26554,
    Raise = 26549,
    Dig = 830,

}

local ITEM_IDS = {
    TROPICAL_TROUT = 35106,
    PINATA = 53329,
    COCONUT = 35102,
    ICECREAM = 35049,
}

local OBJECT_IDS = {
    COCONUT_SKY = 97336,
    BARBEQUE_GRILL = 97275,
    DUNGEONEERING_HOLE = 114121,
    HOOK_A_DUCK = 104332,
    BODYBUILDING = 97379,
    PALM_TREE = { 117506, 117510 },
    PILEOFCOCONUTS = 97332,
}

local NPC_IDS = {
    FISHING_SPOT = 21157,
    WELLINGTON = 21150,
    CLAWDIA = 21156,
    GRETA = 21333,
    PINATA = 29225
}

local SANDCASTLE_NPCS = {
    WIZARDS = {
        id = 21164,
        sandcastleObjectId = { 97416, 97417, 97418, 97419 },
    },
    LUMBRIDGE = {
        id = 21167,
        sandcastleObjectId = { 97424, 97425, 97426, 97427 },
    },
    PYRAMID = {
        id = 21166,
        sandcastleObjectId = { 109550, 109551, 109552, 109553 },
    },
    EXCHANGE = {
        id = 21165,
        sandcastleObjectId = { 97420, 97421, 97422, 97423 },
    }
}

local ActivityA = API.CreateIG_answer()
local Activity = {
    { label = "Spotlight"},
    { label = "Dungeoneering Hole"},
    { label = "Bodybuilding"},
    { label = "Sandcastle building"},
    { label = "Hook-a-duck"},
    { label = "Coconut shy"},
    { label = "Barbecues"},
    { label = "Palm Tree Farming"},
    { label = "Rock Pools"},
}

local function setupOptions()

    btnStop = API.CreateIG_answer()
    btnStop.box_start = FFPOINT.new(110, 130, 0)
    btnStop.box_name = " STOP "
    btnStop.box_size = FFPOINT.new(90, 50, 0)
    btnStop.colour = ImColor.new(255, 255, 255)
    btnStop.string_value = "STOP"

    btnStart = API.CreateIG_answer()
    btnStart.box_start = FFPOINT.new(10, 130, 0)
    btnStart.box_name = " START "
    btnStart.box_size = FFPOINT.new(90, 50, 0)
    btnStart.colour = ImColor.new(0, 0, 255)
    btnStart.string_value = "START"

    IG_Text = API.CreateIG_answer()
    IG_Text.box_name = "TEXT"
    IG_Text.box_start = FFPOINT.new(20, 59, 0)
    IG_Text.colour = ImColor.new(255, 255, 255);
    IG_Text.string_value = "Beach Event - by Valtrex"

    IG_Back = API.CreateIG_answer()
    IG_Back.box_name = "back"
    IG_Back.box_start = FFPOINT.new(5, 44, 0)
    IG_Back.box_size = FFPOINT.new(210, 190, 0)
    IG_Back.colour = ImColor.new(15, 13, 18, 255)
    IG_Back.string_value = ""

    Fight = API.CreateIG_answer()
    Fight.box_ticked = false
    Fight.box_name = "Fight Clawdie"
    Fight.box_start = FFPOINT.new(10, 104, 0);
    Fight.colour = ImColor.new(0, 255, 0);
    Fight.tooltip_text = "Fight Clawdie, when it spawns"

    ActivityA.box_name = "###ACTIVITIE"
    ActivityA.box_start = FFPOINT.new(10, 74, 0)
    ActivityA.box_size = FFPOINT.new(240, 0, 0)
    ActivityA.stringsArr = { }
    ActivityA.tooltip_text = "Select an activity to do."

    table.insert(ActivityA.stringsArr, "Select an activity")
    for i, v in ipairs(Activity) do
        table.insert(ActivityA.stringsArr, v.label)
    end

    API.DrawSquareFilled(IG_Back)
    API.DrawTextAt(IG_Text)
    API.DrawBox(btnStart)
    API.DrawBox(btnStop)
    API.DrawCheckbox(Fight)
    API.DrawComboBox(ActivityA, false)
end

--[ 
-- 294 == 100% Temp
--  37 == 0%
--]
local function getBeachTemperature()
    local i = API.ScanForInterfaceTest2Get(false, { { 1642,0,-1,-1,0 }, { 1642,1,-1,0,0 }, { 1642,8,-1,1,0 } })
    if #i > 0 then
        return API.Mem_Read_int(i[1].memloc + 0x7c)
    end
end

local function getSpotlight()
    local i = API.ScanForInterfaceTest2Get(false, { { 1642,0,-1,-1,0 }, { 1642,3,-1,0,0 }, { 1642,5,-1,3,0 } })
    if #i > 0 then
        return string.match(i[1].textids,"<br>(.*)")
    end
end

function BodybuldingInterface()
    return API.VB_FindPSettinOrder(779, 1).state == 2473
  end

local function findNPC(npcid, distance)
    local distance = distance or 10
    return #API.GetAllObjArrayInteract({npcid}, distance, {1}) > 0
end

local function Dung()
    if not (API.ReadPlayerAnim() == Anim.Enter_Hole) and not (API.ReadPlayerAnim() == Anim.Hole) and not (API.ReadPlayerAnim() == Anim.Exit_Hole) and not API.ReadPlayerMovin2() then
        if API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, { OBJECT_IDS.DUNGEONEERING_HOLE }, 50) then
            print("Get Back in that Hole!")
            API.RandomSleep2(1500, 750, 1500)
        end
    end
end

local function Bodybulding()
    if not API.ReadPlayerMovin2() and BodybuldingInterface() then
        if API.FindNPCbyName("Ivan", 50).Anim == Anim.Crul then
            if not (API.ReadPlayerAnim() == Anim.Crul) then
                    print("Found anim: Crul")
                    API.KeyboardPress2(0x31, 60, 100)
            end
        elseif API.FindNPCbyName("Ivan", 50).Anim == Anim.Lunge then
            if not (API.ReadPlayerAnim() == Anim.Lunge) then
                    print("Found anim: Lunge")
                    API.KeyboardPress2(0x32, 60, 100)
            end
        elseif API.FindNPCbyName("Ivan", 50).Anim == Anim.Fly then
            if (API.ReadPlayerAnim() == Anim.Fly) then
                    print("Found anim: Fly")
                    API.KeyboardPress2(0x33, 60, 100)
            end
        elseif API.FindNPCbyName("Ivan", 50).Anim == Anim.Raise then
            if not (API.ReadPlayerAnim() == Anim.Raise) then
                    print("Found anim: Raise")
                    API.KeyboardPress2(0x34, 60, 100)
            end
        end
    else
        API.RandomSleep2(1200, 1000, 1500)
        print("Not on the platform!")
        if API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, { OBJECT_IDS.BODYBUILDING }, 50) then
            API.RandomSleep2(1500, 1000, 2000)
        end
    end
end

local function SandCastle()
    if  not API.ReadPlayerMovin2() and (not API.CheckAnim(100)) then
        API.RandomSleep2(650, 500, 900)
        if findNPC(SANDCASTLE_NPCS.WIZARDS.id, 15) then 
            if API.GetAllObjArray1({SANDCASTLE_NPCS.WIZARDS.sandcastleObjectId},100,{12}) then
                    API.DoAction_Object_valid1(0x29, API.OFF_ACT_GeneralObject_route0, SANDCASTLE_NPCS.WIZARDS.sandcastleObjectId, 50,true)
            end
        elseif findNPC(SANDCASTLE_NPCS.LUMBRIDGE.id, 15) then
            if API.GetAllObjArray1({SANDCASTLE_NPCS.LUMBRIDGE.sandcastleObjectId},100,{12}) then
                    API.DoAction_Object_valid1(0x29, API.OFF_ACT_GeneralObject_route0, SANDCASTLE_NPCS.LUMBRIDGE.sandcastleObjectId, 50,true)
            end
        elseif findNPC(SANDCASTLE_NPCS.PYRAMID.id, 15) then
            if API.GetAllObjArray1({SANDCASTLE_NPCS.PYRAMID.sandcastleObjectId},100,{12}) then
                    API.DoAction_Object_valid1(0x29, API.OFF_ACT_GeneralObject_route0, SANDCASTLE_NPCS.PYRAMID.sandcastleObjectId, 50,true)
            end
        elseif findNPC(SANDCASTLE_NPCS.EXCHANGE.id, 15) then
            if API.GetAllObjArray1({SANDCASTLE_NPCS.EXCHANGE.sandcastleObjectId},100,{12}) then
                    API.DoAction_Object_valid1(0x29, API.OFF_ACT_GeneralObject_route0, SANDCASTLE_NPCS.EXCHANGE.sandcastleObjectId, 50,true)
            end
        end
    end
end

local function HookADuck()
    if not API.ReadPlayerMovin2() and (not API.CheckAnim(100)) then
        if API.DoAction_Object1(0x40, API.OFF_ACT_GeneralObject_route0, { OBJECT_IDS.HOOK_A_DUCK }, 50) then
            print("Go catch dat ducky!")
        end
    end
end

local function CoconutSky()
    if not API.ReadPlayerMovin2() and (not API.CheckAnim(100)) then
        if API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, { OBJECT_IDS.COCONUT_SKY }, 50) then
            print("Trow that coconut!")
        end
    end
end

local function BBQ()
    if not API.ReadPlayerMovin2() and (not API.CheckAnim(100)) then
        if API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, { OBJECT_IDS.BARBEQUE_GRILL }, 50) then
            print("Get that fish cooked!")
        end
    end
end

local function PalmTree()
    if  not API.ReadPlayerMovin2() and (not API.CheckAnim(100)) then
        if (API.InvFull_()) and API.InvItemFound1(ITEM_IDS.COCONUT) then
            API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, { OBJECT_IDS.PILEOFCOCONUTS }, 50)
            print("Inventory full, Deposit coconuts.")
        else
            if API.GetAllObjArray1({ 117500, 117502, 117504, 117506, 117508, 117510 },100,{12}) then
                API.DoAction_Object_valid1(0x29, API.OFF_ACT_GeneralObject_route0, { 117500, 117502, 117504, 117506, 117508, 117510 }, 50,true)
                print("Back to chopping tree's.")
            end
        end
    end
end

local function RockPool()
    if  not API.ReadPlayerMovin2() and (not API.CheckAnim(100)) then
        if (API.InvFull_()) and API.InvItemFound1(ITEM_IDS.TROPICAL_TROUT) then
            API.DoAction_NPC(0x29,API.OFF_ACT_InteractNPC_route,{  NPC_IDS.WELLINGTON },50)
            print("Inventory full, Deposit fish.")
        else
            API.DoAction_NPC(0x29,API.OFF_ACT_InteractNPC_route,{  NPC_IDS.FISHING_SPOT },50)
            print("Back to Fishing.")
        end
    end
end

function CheckGameMessageClawdia()
    local chatTexts = ChatGetMessages()
    if chatTexts then
        for k, v in pairs(chatTexts) do
            if k > 2 then break end
            if string.find(v.text, "<col=FFFF00>A creature appears in the centre of the crater causing a change in the weather. Take it down to bring back summer!") then
                InCombat = true
                print("Found message that Clawdia spawns!")
                return true
            end
        end
    end
    return false
end

local function brainFreeze()
    local brainFreezeInterface = { { 1189, 2, -1, -1, 0 }, { 1189, 3, -1, 2, 0 } }
    local brainFreeze = API.ScanForInterfaceTest2Get(false, brainFreezeInterface)
    if #brainFreeze > 0 then
        print('Cant eat more ice creams, exiting')
        API.Write_LoopyLoop(false)
    end
end

local function eatIcecream()
    if API.InvItemFound1(ITEM_IDS.ICECREAM) then
        API.DoAction_Inventory1(ITEM_IDS.ICECREAM, 0, 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(1200, 0, 200)
        fail = fail +1
        print("It's to hot to work, time for an ice cream.")
    end
    --brainFreeze()
end

local function isHappyHour()
    local spot = getSpotlight()
    if spot == nil or spot == '' then return false end
    return string.find(spot, 'Happy Hour - Everything!')
end

API.SetDrawTrackedSkills(true)
setupOptions()
while API.Read_LoopyLoop() do
    if btnStop.return_click then
        API.Write_LoopyLoop(false)
    end
    API.RandomSleep2(500,500,500)
    if scriptPaused == true then
        if btnStart.return_click then
            btnStart.return_click = false
            IG_Back.remove = true
            btnStart.remove = true
            IG_Text.remove = true
            btnStop.remove = true
            ActivityA.remove = true
            Fight.remove = true

            FightClawdie = Fight.box_ticked
            
            scriptPaused = false
            
            if (ActivityA.return_click) then
                ActivityA.return_click = false
            end

            if (ActivityA.string_value == "Spotlight") then
                ActivitySelected = "nil" print("Spotlight selected")
                Spotlight = true
            elseif (ActivityA.string_value == "Dungeoneering Hole") then
                ActivitySelected = "Dung" print("Dungeoneering hole selected")
            elseif (ActivityA.string_value == "Bodybuilding") then
                ActivitySelected = "Strength" print("Bodybuilding selected")
            elseif (ActivityA.string_value == "Sandcastle building") then
                ActivitySelected = "Construction" print("Sandcastle building selected")
            elseif (ActivityA.string_value == "Hook-a-duck") then
                ActivitySelected = "Hunter" print("Hook-a-duck selected")
            elseif (ActivityA.string_value == "Coconut shy") then
                ActivitySelected = "Ranged" print("Coconut shy selected")
            elseif (ActivityA.string_value == "Barbecues") then
                ActivitySelected = "Cooking" print("Barbecues selected")
            elseif (ActivityA.string_value == "Palm Tree Farming") then
                ActivitySelected = "Farming" print("Palm Tree Farming selected")
            elseif (ActivityA.string_value == "Rock Pools") then
                ActivitySelected = "Fishing" print("Rock Pools selected")
            end

            if ActivitySelected == "None" then
                API.Write_LoopyLoop(false)
                print("Please select a activity from the dropdown menu!")
            end
            
        end
        goto continue
    end

    API.SetMaxIdleTime(5)
    API.DoRandomEvents()

    if fail > 4 then
        API.Write_LoopyLoop(false)
        return
    end
    
    if Spotlight ==  true then
        if getSpotlight() == "Dungeoneering Hole" then
            ActivitySelected = "Dung"
        elseif getSpotlight() == "Body Building" then
            ActivitySelected = "Strength"
        elseif getSpotlight() == "Sandcastle Building" then
            ActivitySelected = "Construction"
        elseif getSpotlight() == "Hook a Duck" then
            ActivitySelected = "Hunter"
        elseif getSpotlight() == "Coconut Shy" then
            ActivitySelected = "Ranged"
        elseif getSpotlight() == "Barbecues" then
            ActivitySelected = "Cooking"
        elseif getSpotlight() == "Palm Tree Farming" then
            ActivitySelected = "Farming"
        elseif getSpotlight() == "Rock Pools" then
            ActivitySelected = "Fishing"
        elseif getSpotlight() == "Happy Hour - Everything!" then
            ActivitySelected = Spotlight_HappyHour
        end
    end

    if FightClawdie then
        CheckGameMessageClawdia()
    end

    if InCombat == false then
        if not isHappyHour() then
            if getBeachTemperature() >= 294 then
                eatIcecream()
            end
            fail = 0
            if ActivitySelected == "Dung" then
                Dung()
            elseif ActivitySelected == "Strength" then
                Bodybulding()
            elseif ActivitySelected == "Construction" then
                SandCastle()
            elseif ActivitySelected == "Hunter" then
                HookADuck()
            elseif ActivitySelected == "Ranged" then
                CoconutSky()
            elseif ActivitySelected == "Cooking" then
                BBQ()
            elseif ActivitySelected == "Farming" then
                PalmTree()
            elseif ActivitySelected == "Fishing" then
                RockPool()
            end
        end
    elseif InCombat == true then
        if Clawdia == 0 then
            API.DoAction_NPC(0x2a, API.OFF_ACT_AttackNPC_route, { NPC_IDS.CLAWDIA }, 50)
            print("Attacking Clawdia")
            Clawdia = 1
        end
        API.RandomSleep2(2500,4500,3500)
        if not API.GetInCombBit() then
            InCombat = false
            Clawdia = 0
            print("not in combat anymore, time to work.")
        end
    end

    ::continue::
    API.RandomSleep2(250, 500, 350)
end
