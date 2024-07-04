--[[
Beach event 2024 
script by Valtrex

When using spotlight and its happy hour you can set your preference at line 36
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
for Barbeques:
local Spotlight_HappyHour = "Cooking"
For Palm Tree Farming:
local Spotlight_HappyHour = "Farming"
]]


print("Beach Event!")

local API   = require("api")
local UTILS = require("utils")

local scriptPaused  = true
local canDeployShip = false

local Spotlight = false

local ActivitySelected = "None"--DO NOT CHANGE THIS
local Spotlight_HappyHour    = "Hunter" -- change this for HappyHour spotlight activity
local SetRoyalBattleShipMode = "Attack" --Can be set to: Attack or Strength or Defence

local fail = 0

local FightClawdie
local UseCocktail
local UseBattleShip

local Anim = {
    Enter_Hole  = 27005,
    Hole        = 32865,
    Exit_Hole   = 23051,
    Bodybulding = 26551,
    BBQ         = 6784,
    Duck        = 29210,
    Coconut     = 26586,
    Crul        = 26552,
    Lunge       = 26553,
    Fly         = 26554,
    Raise       = 26549,
    Dig         = 830,

}

local ITEM_IDS = {
    TROPICAL_TROUT = 35106,
    PINATA         = 53329,
    COCONUT        = 35102,
    ICECREAM       = 35049,
    INV_SHIPS      = 33769,
    INV_SHIP_KIT   = 33768
}

local OBJECT_IDS = {
    COCONUT_SKY        = 97336,
    BARBEQUE_GRILL     = 97275,
    DUNGEONEERING_HOLE = 114121,
    HOOK_A_DUCK        = 104332,
    BODYBUILDING       = 97379,
    PILEOFCOCONUTS     = 97332,
    PALM_TREE          = { 117506, 117510 },
}

local NPC_IDS = {
    FISHING_SPOT = 21157,
    WELLINGTON   = 21150,
    CLAWDIA      = 21156,
    GRETA        = 21333,
    PINATA       = 29225,
}

local ID_COCKTAIL = {
    Lemon_sour            = 35054,
    Pineappletini         = 35053,
    Pink_fizz             = 35051,
    Purple_Lumbridge      = 35052,
    Fishermans_Friend     = 51732,
    Georges_Peach_Delight = 51733,
    A_Hole_in_One         = 51729,
    Palmer_Farmer         = 51731,
    Ugly_Duckling         = 51730,
}

local SANDCASTLE_NPCS = {
    WIZARDS =   { id = 21164, sandcastleObjectId = { 97416, 97417, 97418, 97419 }, },
    LUMBRIDGE = { id = 21167, sandcastleObjectId = { 97424, 97425, 97426, 97427 }, },
    PYRAMID =   { id = 21166, sandcastleObjectId = { 109550, 109551, 109552, 109553 }, },
    EXCHANGE =  { id = 21165, sandcastleObjectId = { 97420, 97421, 97422, 97423 }, }
}

local ActivityA = API.CreateIG_answer()
local Activity = {
    { label = "Spotlight"},
    { label = "Dungeoneering Hole"},
    { label = "Bodybuilding"},
    { label = "Sandcastle building"},
    { label = "Hook-a-duck"},
    { label = "Coconut shy"},
    { label = "Barbeques"},
    { label = "Palm Tree Farming"},
    { label = "Rock Pools"},
    { label = "Summer Piñata"},
}

local function setupOptions()

    btnStop = API.CreateIG_answer()
    btnStop.box_start    = FFPOINT.new(110, 196, 0)
    btnStop.box_name     = " STOP "
    btnStop.box_size     = FFPOINT.new(90, 50, 0)
    btnStop.colour       = ImColor.new(255, 255, 255)
    btnStop.string_value = "STOP"

    btnStart = API.CreateIG_answer()
    btnStart.box_start    = FFPOINT.new(10, 196, 0)
    btnStart.box_name     = "START "
    btnStart.box_size     = FFPOINT.new(90, 50, 0)
    btnStart.colour       = ImColor.new(0, 0, 255)
    btnStart.string_value = "START"

    IG_Text = API.CreateIG_answer()
    IG_Text.box_name     = "TEXT"
    IG_Text.box_start    = FFPOINT.new(20, 59, 0)
    IG_Text.colour       = ImColor.new(255, 255, 255);
    IG_Text.string_value = "Beach Event - by Valtrex"

    IG_Back = API.CreateIG_answer()
    IG_Back.box_name     = "back"
    IG_Back.box_start    = FFPOINT.new(5, 44, 0)
    IG_Back.box_size     = FFPOINT.new(210, 250, 0)
    IG_Back.colour       = ImColor.new(15, 13, 18, 255)
    IG_Back.string_value = ""
    
    Fight              = API.CreateIG_answer()
    Fight.box_ticked   = true
    Fight.box_name     = "Fight Clawdie"
    Fight.box_start    = FFPOINT.new(10, 124, 0);
    Fight.colour       = ImColor.new(0, 255, 0);
    Fight.tooltip_text = "Fight Clawdie, when it spawns."

    Cocktail = API.CreateIG_answer()
    Cocktail.box_ticked   = false
    Cocktail.box_name     = "Use Cocktail"
    Cocktail.box_start    = FFPOINT.new(10, 144, 0);
    Cocktail.colour       = ImColor.new(0, 255, 0);
    Cocktail.tooltip_text = "Driks cocktail when skilling."

    Ship = API.CreateIG_answer()
    Ship.box_ticked   = false
    Ship.box_name     = "Royal battleship"
    Ship.box_start    = FFPOINT.new(10, 164, 0);
    Ship.colour       = ImColor.new(0, 255, 0);
    Ship.tooltip_text = "make and use the Royal battleship."

    ActivityA.box_name     = "###ACTIVITIE"
    ActivityA.box_start    = FFPOINT.new(10, 74, 0)
    ActivityA.box_size     = FFPOINT.new(240, 0, 0)
    ActivityA.stringsArr   = { }
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
    API.DrawCheckbox(Cocktail)
    API.DrawCheckbox(Ship)
    API.DrawComboBox(ActivityA, false)
end

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

local function BodybuldingInterface()
    return API.VB_FindPSettinOrder(779, 1).state == 2473
end

local function findNPC(npcid, distance)
    local distance = distance or 10
    return #API.GetAllObjArrayInteract({npcid}, distance, {1}) > 0
end

local function isHeatWave()
    local now = os.date("!*t")
    local wday, hour = now.wday, now.hour
    return (wday == 6 and hour >= 12) or (wday == 7) or (wday == 1) or (wday == 2 and hour < 12)
end

local function isHappyHour()
    if getSpotlight() == "nil" or getSpotlight() == "" then return false end
    return getSpotlight() == "Happy Hour - Everything!"
end

local function eatIcecream()
    if not isHeatWave() then
        API.logDebug("Heatwave = false")
        if not isHappyHour() then
            API.logDebug("Happyhour = false")
            if getBeachTemperature() >= 294 then
                if API.InvItemFound1(ITEM_IDS.ICECREAM) then
                    API.DoAction_Inventory1(ITEM_IDS.ICECREAM, 0, 1, API.OFF_ACT_GeneralInterface_route)
                    API.RandomSleep2(1200, 0, 200)
                    fail = fail +1
                    API.logInfo("It's to hot to work, time for an ice cream.")
                end
                if API.VB_FindPSettinOrder(2874, 1).state == 12 then
                    API.logInfo('Cant eat more ice creams, exiting')
                    API.logError('Cant eat more ice creams, exiting')
                    API.Write_LoopyLoop(false)
                end
            end
        end
    end
end

local function clawdia()
    if FightClawdie then
        if #API.ReadAllObjectsArray({ 1 }, { NPC_IDS.CLAWDIA }, {}) == 0 then return false end
        if API.ReadLpInteracting().Id ~= NPC_IDS.CLAWDIA then
            if not API.LocalPlayer_IsInCombat_() then
                if API.DoAction_NPC(0x2a, API.OFF_ACT_AttackNPC_route, { NPC_IDS.CLAWDIA }, 50) then
                    API.RandomSleep2(400, 0, 200)
                    API.WaitUntilMovingEnds()
                    API.RandomSleep2(400, 0, 200)
                    return true
                end
            end
        end
        return true
    end
end

local function checkIfShipExpired()
    local chatEvents = API.GatherEvents_chat_check()
    for i = 1, #chatEvents, 1 do
        local chatLine = chatEvents[i]
        if chatLine.text:find('Construction XP') then
            API.logInfo('ship is dead')
            canDeployShip = true
        elseif chatLine.text:find('You may only have one follower') then
            API.logInfo('ship is already deployed')
            canDeployShip = false
        end
    end
end

local function checkForShip()
    if API.CheckFamiliar() then
        canDeployShip = false
    else
        canDeployShip = false
    end
end

local function isShipInterfaceOpen()
    local shipInterface = { { 751, 37, -1, -1, 0 } }
    return #API.ScanForInterfaceTest2Get(true, shipInterface) > 0
end

local function isKitInterfaceOpen()
    local kitInterface = { { 1370,0,-1,-1,0 } }
    local kitInterfaces = API.ScanForInterfaceTest2Get(true,kitInterface)
    if #kitInterfaces > 0 then
        if kitInterfaces[1].xs > 0 then return true else return false end
    else return false end
end

local function deployShip()
    if API.isProcessing() or API.CheckAnim(50) and getBeachTemperature() < 294 then return end
    local shipStackCount = API.InvStackSize(ITEM_IDS.INV_SHIPS)
    if shipStackCount == 0 then
        if API.InvStackSize(ITEM_IDS.INV_SHIP_KIT) > 0 then
            API.DoAction_Inventory1(ITEM_IDS.INV_SHIP_KIT, 0, 1, API.OFF_ACT_GeneralInterface_route)
            API.RandomSleep2(500,750,250)
            if UTILS.SleepUntil(isKitInterfaceOpen,500,'kits') then
                API.RandomSleep2(500,750,250)
                API.DoAction_Interface(0xffffffff,0xffffffff,0,1370,30,-1,API.OFF_ACT_GeneralInterface_Choose_option)
                UTILS.countTicks(4)
            end
            return
        end
    end
    if canDeployShip and shipStackCount > 0 then
        API.DoAction_Inventory1(ITEM_IDS.INV_SHIPS, 0, 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(500,750,250)
        if UTILS.SleepUntil(isShipInterfaceOpen, 1000, 'ship interface') then
            API.RandomSleep2(500,750,250)
            API.logDebug("interface is open")
            if SetRoyalBattleShipMode == "Attack" then
                if API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 751, 50, -1, API.OFF_ACT_GeneralInterface_Choose_option) then
                    canDeployShip = false
                end
            elseif SetRoyalBattleShipMode == "Defence" then
                if API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 751, 58, -1, API.OFF_ACT_GeneralInterface_Choose_option) then
                    canDeployShip = false
                end
            elseif SetRoyalBattleShipMode == "Strength" then
                if API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 751, 66, -1, API.OFF_ACT_GeneralIntersface_Choose_option) then
                    canDeployShip = false
                end
            end
        end
        if API.InvStackSize(ITEM_IDS.INV_SHIPS) < shipStackCount then
            canDeployShip = false
        end
    end
end

local function Dung()
    if UseCocktail then
        if not isHappyHour() then
            if API.InvItemcount_2(ID_COCKTAIL.A_Hole_in_One) then
                if not (API.Buffbar_GetIDstatus(ID_COCKTAIL.A_Hole_in_One, false).id > 0) and not (API.Buffbar_GetIDstatus(ID_COCKTAIL.Lemon_sour, false).id > 0) then
                    API.logInfo("You drink a Hole in One beach cocktail.")
                    API.RandomSleep2(300, 200, 400)
                    return API.DoAction_Inventory2( ID_COCKTAIL.A_Hole_in_One, 0, 1, API.OFF_ACT_GeneralInterface_route)
                end
            elseif API.InvItemcount_2(ID_COCKTAIL.Lemon_sour) then
                if not (API.Buffbar_GetIDstatus(ID_COCKTAIL.A_Hole_in_One, false).id > 0) and not (API.Buffbar_GetIDstatus(ID_COCKTAIL.Lemon_sour, false).id > 0) then
                    API.logInfo("Drink Lemon sour beach cocktail")
                    API.RandomSleep2(300, 200, 400)
                    return API.DoAction_Inventory2( ID_COCKTAIL.Lemon_sour, 0, 1, API.OFF_ACT_GeneralInterface_route)
                end
            end
        else
            if API.InvItemcount_2(ID_COCKTAIL.Lemon_sour) then
                if not (API.Buffbar_GetIDstatus(ID_COCKTAIL.A_Hole_in_One, false).id > 0) and not (API.Buffbar_GetIDstatus(ID_COCKTAIL.Lemon_sour, false).id > 0) then
                    API.logInfo("Drink Lemon sour beach cocktail")
                    API.RandomSleep2(300, 200, 400)
                    return API.DoAction_Inventory2( ID_COCKTAIL.Lemon_sour, 0, 1, API.OFF_ACT_GeneralInterface_route)
                end
            elseif API.InvItemcount_2(ID_COCKTAIL.A_Hole_in_One) then
                if not (API.Buffbar_GetIDstatus(ID_COCKTAIL.A_Hole_in_One, false).id > 0) and not (API.Buffbar_GetIDstatus(ID_COCKTAIL.Lemon_sour, false).id > 0) then
                    API.logInfo("You drink a Hole in One beach cocktail.")
                    API.RandomSleep2(300, 200, 400)
                    return API.DoAction_Inventory2( ID_COCKTAIL.A_Hole_in_One, 0, 1, API.OFF_ACT_GeneralInterface_route)
                end
            end
        end
    end
    if UseBattleShip then
        deployShip()
    end
    API.RandomSleep2(500,250,600)
    if not API.isProcessing() then
        if canDeployShip == false then
            if not (API.ReadPlayerAnim() == Anim.Enter_Hole) and not (API.ReadPlayerAnim() == Anim.Hole) and not (API.ReadPlayerAnim() == Anim.Exit_Hole) and not API.ReadPlayerMovin2() then
                if API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, { OBJECT_IDS.DUNGEONEERING_HOLE }, 50) then
                    API.logInfo("Get Back in that Hole!")
                end
            end
        end
    end
end

local function Bodybulding()
    if UseCocktail then
        if not (API.Buffbar_GetIDstatus(ID_COCKTAIL.Pink_fizz, false).id > 0) then
            if API.InvItemcount_2(ID_COCKTAIL.Pink_fizz) then
                API.logInfo("You drink a Pink fizz beach cocktail.")
                API.RandomSleep2(300, 200, 400)
                return API.DoAction_Inventory2( ID_COCKTAIL.Pink_fizz, 0, 1, API.OFF_ACT_GeneralInterface_route)
            end
        end
    end
    if UseBattleShip then
        deployShip()
    end
    if not API.isProcessing() then
        if not canDeployShip then
            if not API.ReadPlayerMovin2() and BodybuldingInterface() then
                if API.FindNPCbyName("Ivan", 50).Anim == Anim.Crul then
                    if not (API.ReadPlayerAnim() == Anim.Crul) then
                            API.logDebug("Found anim: Crul")
                            API.KeyboardPress2(0x31, 60, 100)
                    end
                elseif API.FindNPCbyName("Ivan", 50).Anim == Anim.Lunge then
                    if not (API.ReadPlayerAnim() == Anim.Lunge) then
                            API.logDebug("Found anim: Lunge")
                            API.KeyboardPress2(0x32, 60, 100)
                    end
                elseif API.FindNPCbyName("Ivan", 50).Anim == Anim.Fly then
                    if (API.ReadPlayerAnim() == Anim.Fly) then
                            API.logDebug("Found anim: Fly")
                            API.KeyboardPress2(0x33, 60, 100)
                    end
                elseif API.FindNPCbyName("Ivan", 50).Anim == Anim.Raise then
                    if not (API.ReadPlayerAnim() == Anim.Raise) then
                            API.logDebug("Found anim: Raise")
                            API.KeyboardPress2(0x34, 60, 100)
                    end
                end
            else
                API.logDebug("Not on the platform!")
                if API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, { OBJECT_IDS.BODYBUILDING }, 50) then
                    API.RandomSleep2(1500, 1000, 2000)
                end
            end
        end
    end
end

local function SandCastle()
    if UseCocktail then
        if not isHappyHour() then
            if API.InvItemcount_2(ID_COCKTAIL.Georges_Peach_Delight) then
                if not (API.Buffbar_GetIDstatus(ID_COCKTAIL.Georges_Peach_Delight, false).id > 0) then
                    API.logInfo("You drink a George's Peach Delight beach cocktail.")
                    API.RandomSleep2(300, 200, 400)
                    return API.DoAction_Inventory2( ID_COCKTAIL.Georges_Peach_Delight, 0, 1, API.OFF_ACT_GeneralInterface_route)
                end
            elseif API.InvItemcount_2(ID_COCKTAIL.Purple_Lumbridge) then
                if not (API.Buffbar_GetIDstatus(ID_COCKTAIL.Purple_Lumbridge, false).id > 0) then
                    API.logInfo("You drink a Purple Lumbridge beach cocktail.")
                    API.RandomSleep2(300, 200, 400)
                    return API.DoAction_Inventory2( ID_COCKTAIL.Purple_Lumbridge, 0, 1, API.OFF_ACT_GeneralInterface_route)
                end
            end
        else
            if API.InvItemcount_2(ID_COCKTAIL.Purple_Lumbridge) then
                if not (API.Buffbar_GetIDstatus(ID_COCKTAIL.Purple_Lumbridge, false).id > 0) then
                    API.logInfo("You drink a Purple Lumbridge beach cocktail.")
                    API.RandomSleep2(300, 200, 400)
                    return API.DoAction_Inventory2( ID_COCKTAIL.Purple_Lumbridge, 0, 1, API.OFF_ACT_GeneralInterface_route)
                end
            elseif API.InvItemcount_2(ID_COCKTAIL.Georges_Peach_Delight) then
                if not (API.Buffbar_GetIDstatus(ID_COCKTAIL.Georges_Peach_Delight, false).id > 0) then
                    API.logInfo("You drink a George's Peach Delight beach cocktail.")
                    API.RandomSleep2(300, 200, 400)
                    return API.DoAction_Inventory2( ID_COCKTAIL.Georges_Peach_Delight, 0, 1, API.OFF_ACT_GeneralInterface_route)
                end
            end
        end
    end
    if UseBattleShip then
        deployShip()
    end
    if not API.isProcessing() then
        if canDeployShip == false then
            if  not API.ReadPlayerMovin2() and (not API.CheckAnim(100)) then
                if findNPC(SANDCASTLE_NPCS.WIZARDS.id, 100) then
                    if API.GetAllObjArray1({SANDCASTLE_NPCS.WIZARDS.sandcastleObjectId},100,{12}) then
                            API.DoAction_Object_valid1(0x29, API.OFF_ACT_GeneralObject_route0, SANDCASTLE_NPCS.WIZARDS.sandcastleObjectId, 50,true)
                    end
                elseif findNPC(SANDCASTLE_NPCS.LUMBRIDGE.id, 100) then
                    if API.GetAllObjArray1({SANDCASTLE_NPCS.LUMBRIDGE.sandcastleObjectId},100,{12}) then
                            API.DoAction_Object_valid1(0x29, API.OFF_ACT_GeneralObject_route0, SANDCASTLE_NPCS.LUMBRIDGE.sandcastleObjectId, 50,true)
                    end
                elseif findNPC(SANDCASTLE_NPCS.PYRAMID.id, 100) then
                    if API.GetAllObjArray1({SANDCASTLE_NPCS.PYRAMID.sandcastleObjectId},100,{12}) then
                            API.DoAction_Object_valid1(0x29, API.OFF_ACT_GeneralObject_route0, SANDCASTLE_NPCS.PYRAMID.sandcastleObjectId, 50,true)
                    end
                elseif findNPC(SANDCASTLE_NPCS.EXCHANGE.id, 100) then
                    if API.GetAllObjArray1({SANDCASTLE_NPCS.EXCHANGE.sandcastleObjectId},100,{12}) then
                            API.DoAction_Object_valid1(0x29, API.OFF_ACT_GeneralObject_route0, SANDCASTLE_NPCS.EXCHANGE.sandcastleObjectId, 50,true)
                    end
                end
            end
        end
    end
end

local function HookADuck()
    if UseCocktail then
        if not isHappyHour() then
            if API.InvItemcount_2(ID_COCKTAIL.Ugly_Duckling) then
                if not (API.Buffbar_GetIDstatus(ID_COCKTAIL.Ugly_Duckling, false).id > 0) then
                    API.logInfo("You drink a The Ugly Duckling beach cocktail.")
                    API.RandomSleep2(300, 200, 400)
                    return API.DoAction_Inventory2( ID_COCKTAIL.Ugly_Duckling, 0, 1, API.OFF_ACT_GeneralInterface_route)
                end
            elseif API.InvItemcount_2(CID_COCKTAIL.Pineappletini) then
                if not (API.Buffbar_GetIDstatus(ID_COCKTAIL.Pineappletini, false).id > 0) then
                    API.logInfo("Drink Pineappletini beach cocktail")
                    API.RandomSleep2(300, 200, 400)
                    return API.DoAction_Inventory2( ID_COCKTAIL.Pineappletini, 0, 1, API.OFF_ACT_GeneralInterface_route)
                end
            end
        else
            if API.InvItemcount_2(CID_COCKTAIL.Pineappletini) then
                if not (API.Buffbar_GetIDstatus(ID_COCKTAIL.Pineappletini, false).id > 0) then
                    API.logInfo("Drink Pineappletini beach cocktail")
                    API.RandomSleep2(300, 200, 400)
                    return API.DoAction_Inventory2( ID_COCKTAIL.Pineappletini, 0, 1, API.OFF_ACT_GeneralInterface_route)
                end
            elseif API.InvItemcount_2(ID_COCKTAIL.Ugly_Duckling) then
                if not (API.Buffbar_GetIDstatus(ID_COCKTAIL.Ugly_Duckling, false).id > 0) then
                    API.logInfo("You drink a The Ugly Duckling beach cocktail.")
                    API.RandomSleep2(300, 200, 400)
                    return API.DoAction_Inventory2( ID_COCKTAIL.Ugly_Duckling, 0, 1, API.OFF_ACT_GeneralInterface_route)
                end
            end
        end
    end
    if UseBattleShip then
        deployShip()
    end
    if not API.isProcessing() then
        if canDeployShip == false then
            if not API.ReadPlayerMovin2() and (not API.CheckAnim(100)) then
                if API.DoAction_Object1(0x40, API.OFF_ACT_GeneralObject_route0, { OBJECT_IDS.HOOK_A_DUCK }, 50) then
                    API.logInfo("Go catch dat ducky!")
                end
            end
        end
    end
end

local function CoconutSky()
    if UseCocktail then
        if API.InvItemcount_2(ID_COCKTAIL.Pink_fizz) then
            if not (API.Buffbar_GetIDstatus(ID_COCKTAIL.Pink_fizz, false).id > 0) then
                API.logInfo("You drink a Pink fizz beach cocktail.")
                API.RandomSleep2(300, 200, 400)
                return API.DoAction_Inventory2( ID_COCKTAIL.Pink_fizz, 0, 1, API.OFF_ACT_GeneralInterface_route)
            end
        end
    end
    if UseBattleShip then
        deployShip()
    end
    if not API.isProcessing() then
        if not API.ReadPlayerMovin2() and (not API.CheckAnim(100)) then
            if API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, { OBJECT_IDS.COCONUT_SKY }, 50) then
                API.logInfo("Trow that coconut!")
            end
        end
    end
end

local function BBQ()
    if UseCocktail then
        if API.InvItemcount_2(ID_COCKTAIL.Purple_Lumbridge) then
            if not (API.Buffbar_GetIDstatus(ID_COCKTAIL.Purple_Lumbridge, false).id > 0) then
                API.logInfo("You drink a Purple Lumbridge beach cocktail.")
                API.RandomSleep2(300, 200, 400)
                return API.DoAction_Inventory2( ID_COCKTAIL.Purple_Lumbridge, 0, 1, API.OFF_ACT_GeneralInterface_route)
            end
        end
    end
    if UseBattleShip then
        deployShip()
    end
    if not API.isProcessing() then
        if canDeployShip == false then
            if not API.ReadPlayerMovin2() and (not API.CheckAnim(100)) then
                if API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, { OBJECT_IDS.BARBEQUE_GRILL }, 50) then
                    API.logInfo("Get that fish cooked!")
                end
            end
        end
    end
end

local function PalmTree()
    if UseCocktail then
        if not isHappyHour() then
            if API.InvItemcount_2(ID_COCKTAIL.Palmer_Farmer) then
                if not (API.Buffbar_GetIDstatus(ID_COCKTAIL.Palmer_Farmer, false).id > 0) then
                    API.logInfo("You drink a The Palmer Farmer beach cocktail.")
                    API.RandomSleep2(300, 200, 400)
                    return API.DoAction_Inventory2( ID_COCKTAIL.Palmer_Farmer, 0, 1, API.OFF_ACT_GeneralInterface_route)
                end
            elseif API.InvItemcount_2(CID_COCKTAIL.Pineappletini) then
                if not (API.Buffbar_GetIDstatus(ID_COCKTAIL.Pineappletini, false).id > 0) then
                    API.logInfo("Drink Pineappletini beach cocktail")
                    API.RandomSleep2(300, 200, 400)
                    return API.DoAction_Inventory2( ID_COCKTAIL.Pineappletini, 0, 1, API.OFF_ACT_GeneralInterface_route)
                end
            end
        else
            if API.InvItemcount_2(CID_COCKTAIL.Pineappletini) then
                if not (API.Buffbar_GetIDstatus(ID_COCKTAIL.Pineappletini, false).id > 0) then
                    API.logInfo("Drink Pineappletini beach cocktail")
                    API.RandomSleep2(300, 200, 400)
                    return API.DoAction_Inventory2( ID_COCKTAIL.Pineappletini, 0, 1, API.OFF_ACT_GeneralInterface_route)
                end
            elseif API.InvItemcount_2(ID_COCKTAIL.Palmer_Farmer) then
                if not (API.Buffbar_GetIDstatus(ID_COCKTAIL.Palmer_Farmer, false).id > 0) then
                    API.logInfo("You drink a The Palmer Farmer beach cocktail.")
                    API.RandomSleep2(300, 200, 400)
                    return API.DoAction_Inventory2( ID_COCKTAIL.Palmer_Farmer, 0, 1, API.OFF_ACT_GeneralInterface_route)
                end
            end
        end
    end
    if UseBattleShip then
        deployShip()
    end
    if not API.isProcessing() then
        if canDeployShip == false then
            if not API.ReadPlayerMovin2() and (not API.CheckAnim(100)) then
                if (API.InvFull_()) and API.InvItemFound1(ITEM_IDS.COCONUT) then
                    API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, { OBJECT_IDS.PILEOFCOCONUTS }, 50)
                    API.logInfo("Inventory full, Deposit coconuts.")
                else
                    if API.GetAllObjArray1({ 117500, 117502, 117504, 117506, 117508, 117510 },100,{12}) then
                        API.DoAction_Object_valid1(0x29, API.OFF_ACT_GeneralObject_route0, { 117500, 117502, 117504, 117506, 117508, 117510 }, 50,true)
                        API.logInfo("Back to chopping tree's.")
                    end
                end
            end
        end
    end
end

local function RockPool()
    if UseCocktail then
        if not isHappyHour() then
            if API.InvItemcount_2(ID_COCKTAIL.Fishermans_Friend) then
                if not (API.Buffbar_GetIDstatus(ID_COCKTAIL.Fishermans_Friend, false).id > 0) then
                    API.logInfo("You drink a Fisherman's Friend beach cocktail.")
                    API.RandomSleep2(300, 200, 400)
                    return API.DoAction_Inventory2( ID_COCKTAIL.Fishermans_Friend, 0, 1, API.OFF_ACT_GeneralInterface_route)
                end
            elseif API.InvItemcount_2(CID_COCKTAIL.Pineappletini) then
                if not (API.Buffbar_GetIDstatus(ID_COCKTAIL.Pineappletini, false).id > 0) then
                    API.logInfo("Drink Pineappletini beach cocktail")
                    API.RandomSleep2(300, 200, 400)
                    return API.DoAction_Inventory2( ID_COCKTAIL.Pineappletini, 0, 1, API.OFF_ACT_GeneralInterface_route)
                end
            end
        else
            if API.InvItemcount_2(CID_COCKTAIL.Pineappletini) then
                if not (API.Buffbar_GetIDstatus(ID_COCKTAIL.Pineappletini, false).id > 0) then
                    API.logInfo("Drink Pineappletini beach cocktail")
                    API.RandomSleep2(300, 200, 400)
                    return API.DoAction_Inventory2( ID_COCKTAIL.Pineappletini, 0, 1, API.OFF_ACT_GeneralInterface_route)
                end
            elseif API.InvItemcount_2(ID_COCKTAIL.Fishermans_Friend) then
                if not (API.Buffbar_GetIDstatus(ID_COCKTAIL.Fishermans_Friend, false).id > 0) then
                    API.logInfo("You drink a Fisherman's Friend beach cocktail.")
                    API.RandomSleep2(300, 200, 400)
                    return API.DoAction_Inventory2( ID_COCKTAIL.Fishermans_Friend, 0, 1, API.OFF_ACT_GeneralInterface_route)
                end
            end
        end
    end
    if UseBattleShip then
        deployShip()
    end
    if not API.isProcessing() then
        if canDeployShip == false then
            if not API.ReadPlayerMovin2() and (not API.CheckAnim(100)) then
                if (API.InvFull_()) and API.InvItemFound1(ITEM_IDS.TROPICAL_TROUT) then
                    API.DoAction_NPC(0x29,API.OFF_ACT_InteractNPC_route,{  NPC_IDS.WELLINGTON },50)
                    API.logInfo("Inventory full, Deposit fish.")
                else
                    API.DoAction_NPC(0x29,API.OFF_ACT_InteractNPC_route,{  NPC_IDS.FISHING_SPOT },50)
                    API.logInfo("Back to Fishing.")
                end
            end
        end
    end
end

local function SummerPinata()
    if not API.ReadPlayerMovin2() and (not API.CheckAnim(50)) then
        if findNPC(NPC_IDS.PINATA, 5) then
            API.logInfo("attack Summer piñata.")
            API.DoAction_NPC(0x2a,API.OFF_ACT_AttackNPC_route,{ NPC_IDS.PINATA },5)
        elseif not findNPC(NPC_IDS.PINATA, 5) then
            API.RandomSleep2(1500, 500, 1000)
            if API.InvItemFound1(ITEM_IDS.PINATA) then
                if API.DoAction_Inventory1(ITEM_IDS.PINATA,0,1,API.OFF_ACT_GeneralInterface_route) then
                    API.logInfo("Deploy Summer piñata.")
                    API.RandomSleep2(1500, 500, 1000)
                end
            else
                API.Write_LoopyLoop(false)
            end
        end
    end
end

API.SetDrawTrackedSkills(true)
API.SetDrawLogs(true)
setupOptions()

while API.Read_LoopyLoop() do
    if btnStop.return_click then
        API.Write_LoopyLoop(false)
    end
    if scriptPaused == true then
        if btnStart.return_click then
            btnStart.return_click = false
            IG_Back.remove = true
            btnStart.remove = true
            IG_Text.remove = true
            btnStop.remove = true
            ActivityA.remove = true
            Fight.remove = true
            Cocktail.remove = true
            Ship.remove = true

            FightClawdie = Fight.box_ticked
            UseCocktail = Cocktail.box_ticked
            UseBattleShip = Ship.box_ticked
            
            scriptPaused = false
            
            if (ActivityA.return_click) then
                ActivityA.return_click = false
            end

            if (ActivityA.string_value == "Spotlight") then
                ActivitySelected = "nil" API.logDebug("Spotlight selected")
                Spotlight = true
                
            elseif (ActivityA.string_value == "Dungeoneering Hole") then  ActivitySelected = "Dung" API.logDebug("Dungeoneering hole selected")
            elseif (ActivityA.string_value == "Bodybuilding") then        ActivitySelected = "Strength" API.logDebug("Bodybuilding selected")
            elseif (ActivityA.string_value == "Sandcastle building") then ActivitySelected = "Construction" API.logDebug("Sandcastle building selected")
            elseif (ActivityA.string_value == "Hook-a-duck") then         ActivitySelected = "Hunter" API.logDebug("Hook-a-duck selected")
            elseif (ActivityA.string_value == "Coconut shy") then         ActivitySelected = "Ranged" API.logDebug("Coconut shy selected")
            elseif (ActivityA.string_value == "Barbeques") then           ActivitySelected = "Cooking" API.logDebug("Barbeques selected")
            elseif (ActivityA.string_value == "Palm Tree Farming") then   ActivitySelected = "Farming" API.logDebug("Palm Tree Farming selected")
            elseif (ActivityA.string_value == "Rock Pools") then          ActivitySelected = "Fishing" API.logDebug("Rock Pools selected")
            elseif (ActivityA.string_value == "Summer Piñata") then       ActivitySelected = "Piñata" API.logDebug("Summer Piñata selected")
            end

            if ActivitySelected == "None" then
                API.Write_LoopyLoop(false)
                API.logError("Please select a activity from the dropdown menu!")
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
        if getSpotlight() == "Dungeoneering Hole" then           ActivitySelected = "Dung"
        elseif getSpotlight() == "Body Building" then            ActivitySelected = "Strength"
        elseif getSpotlight() == "Sandcastle Building" then      ActivitySelected = "Construction"
        elseif getSpotlight() == "Hook a Duck" then              ActivitySelected = "Hunter"
        elseif getSpotlight() == "Coconut Shy" then              ActivitySelected = "Ranged"
        elseif getSpotlight() == "Barbeques" then                ActivitySelected = "Cooking"
        elseif getSpotlight() == "Palm Tree Farming" then        ActivitySelected = "Farming"
        elseif getSpotlight() == "Rock Pools" then               ActivitySelected = "Fishing"
        elseif getSpotlight() == "Happy Hour - Everything!" then ActivitySelected = Spotlight_HappyHour
        end
    end

    if UseBattleShip then
        checkIfShipExpired()
        checkForShip()
    end

    eatIcecream()

    if not clawdia() then
        if ActivitySelected == "Dung" then              Dung()
        elseif ActivitySelected == "Strength" then      Bodybulding()
        elseif ActivitySelected == "Construction" then  SandCastle()
        elseif ActivitySelected == "Hunter" then        HookADuck()
        elseif ActivitySelected == "Ranged" then        CoconutSky()
        elseif ActivitySelected == "Cooking" then       BBQ()
        elseif ActivitySelected == "Farming" then       PalmTree()
        elseif ActivitySelected == "Fishing" then       RockPool()
        elseif ActivitySelected == "Piñata" then        SummerPinata()
        end
    end

    ::continue::
    API.RandomSleep2(800, 0, 0)
end
