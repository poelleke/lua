--[[
    Author:      Valtrex
    Version:     1.61
    Release      Date: 02-04-2024
    Script:      Runecrafter
    Description: crafting runes via the abyss and necrotic runes in the City of Um. 

    All you have to do is set up your preset. The scripts use the load last preset
    For the abyss it uses the Wildy Sword or Edgevilage Teleport back for banking. 
    For necrotic runes it uses the City of um loadstone or Tome of um (2) to go the smity area. it also uses the brachlet to teleport to Haunt on the Hill.
    In addition, it has support for all summoning familiars that are used in runecrafting and renews them when time is almost up.

    Release Notes:
    - Version 1.00  : Initial release.
    - Version 1.10  : Updated procesbar, added startup check and added Powerburst.
    - Version 1.20  : Added Summoning support!
    - Version 1.30  : Outer ring support.
    - Version 1.31  : Support for al familiars choose them from a dropdown menu.
    - Version 1.40  : Demonic skull support (not fully tested)
    - Version 1.50  : Add soul altar, the option to use surge/ dive when entering the wilde, Support for Bankpin, also made some changes to the UI. it can be pause now and when changing somting and when you restart it it wil do you change
    - Version 1.51  : Fixed an error with powerburst and soul altar and fixed a typo causing every altar to be an unknown location except soul altar
    - Version 1.52  : - Add Dead's xp tracker and removed de xp from the procesbar. (thanks to higgins for the updated version)
                      - used deads log to show difrend types of prints (Debug, info, warnings and error's)
                      - Repositioned the procesbar.
                      - Start UI removed, because we now have load last script.
    - Version 1.60  : Add necrotic runes
    - Version 1.60  : Fixed an issu when banking and not loading a full inventory


    You will need:
    - War's Retreat Teleport on actionbar when using a familiar
    - bank uses: "load last preset"

    When doing abyss runes:
    - wildy sword on abilitybar or edgevillage lodestone on abilitybar for teleporting.
    When doing necrotic runes:
    - Tome of um (2) on abilitybar or City of Um lodestone on abilitybar for teleporting.
    - Passing bracelet on abilitybar, when using the Haunt on the Hill teleport

]]

local API               = require("api")
local UTILS             = require("utils")

-----------------User Settings------------------
local Bankpin           = xxxx-- Your Bankpin
local Showlogs          = false-- Show log's
-----------------User Settings------------------

local skill             = "RUNECRAFTING"
startXp = API.GetSkillXP(skill)
local version           = "1.61"
local selectedAltar     = nil
local selectedPortal    = nil
local selectedArea      = nil
local selectedRune      = nil
local selectedFamiliar  = nil
local SelectedAB        = nil
LOCATIONS               = nil
local scriptPaused      = true
local firstRun          = true
local Areacheck         = true
local Soul              = false
local Necro             = false
local Trips             = 0
local Runes             = 0
local fail              = 0
local runecount         = 0
local Soulcound         = 0
local SoulRun           = 0
local familiarrenew     = 0
local banking           = 0
local startTime, afk    = os.time(), os.time()
local errors            = {}
local needNexusMod
local PouchProtector
local needDemonicSkull
local SurgeDiveAbillity

local aioSelectR = API.CreateIG_answer()
local aioRune = {
    { label = "Air rune",    ALTARIDID = 2478,   PORTALID = 7139, AREAID = { x = 2841, y = 4830, z = 0 }, RUNEID = 556 },
    { label = "Mind rune",   ALTARIDID = 2479,   PORTALID = 7140, AREAID = { x = 2784, y = 4843, z = 0 }, RUNEID = 558 },
    { label = "water rune",  ALTARIDID = 2480,   PORTALID = 7137, AREAID = { x = 3493, y = 4832, z = 0 }, RUNEID = 555 },
    { label = "Earth rune",  ALTARIDID = 2481,   PORTALID = 7130, AREAID = { x = 2657, y = 4830, z = 0 }, RUNEID = 557 },
    { label = "Fire rune",   ALTARIDID = 2482,   PORTALID = 7129, AREAID = { x = 2577, y = 4846, z = 0 }, RUNEID = 554 },
    { label = "Body rune",   ALTARIDID = 2483,   PORTALID = 7131, AREAID = { x = 2520, y = 4846, z = 0 }, RUNEID = 559 },
    { label = "Cosmic rune", ALTARIDID = 2484,   PORTALID = 7132, AREAID = { x = 2142, y = 4844, z = 0 }, RUNEID = 564 },
    { label = "Chaos rune",  ALTARIDID = 2487,   PORTALID = 7134, AREAID = { x = 2270, y = 4844, z = 0 }, RUNEID = 562 },
    { label = "Nature rune", ALTARIDID = 2486,   PORTALID = 7133, AREAID = { x = 2400, y = 4835, z = 0 }, RUNEID = 561 },
    { label = "Law rune",    ALTARIDID = 2485,   PORTALID = 7135, AREAID = { x = 2464, y = 4819, z = 0 }, RUNEID = 563 },
    { label = "Death rune",  ALTARIDID = 2488,   PORTALID = 7136, AREAID = { x = 2208, y = 4829, z = 0 }, RUNEID = 560 },
    { label = "Blood rune",  ALTARIDID = 30624,  PORTALID = 7141, AREAID = { x = 2466, y = 4897, z = 0 }, RUNEID = 565 },
    { label = "Soul rune",   ALTARIDID = 109429, PORTALID = 7138, AREAID = { x = 1953, y = 6679, z = 0 }, RUNEID = 566 },
    { label = "(Necro) Spirit rune", ALTARIDID = 127380, PORTALID = 127378, AREAID = { x = 1953, y = 6679, z = 0 }, RUNEID = 55337 },
    { label = "(Necro) Bone rune",   ALTARIDID = 127381, PORTALID = 127378, AREAID = { x = 1953, y = 6679, z = 0 }, RUNEID = 55338 },
    { label = "(Necro) Flesh rune",  ALTARIDID = 127382, PORTALID = 127378, AREAID = { x = 1953, y = 6679, z = 0 }, RUNEID = 55339 },
    { label = "(Necro) Miasma rune", ALTARIDID = 127383, PORTALID = 127378, AREAID = { x = 1953, y = 6679, z = 0 }, RUNEID = 55340 },
}

local aioSelectF = API.CreateIG_answer()
local aioFamiliar = {
    { name = "Abyssal parasite", FAMILIARID = 12035, ABNAME = API.GetABs_name1("Abyssal parasite pouch") },
    { name = "Abyssal lurker",   FAMILIARID = 12037, ABNAME = API.GetABs_name1("Abyssal lurker pouch") },
    { name = "Abyssal titan",    FAMILIARID = 12796, ABNAME = API.GetABs_name1("Abyssal titan pouch") },
}

local LODESTONES     = {
    ["Edgeville"]    = 16,
    ["City of UM"]   = 36,
}

local TELEPORTS      = {
    ["Edgeville Lodestone"]  = 31870,
    ["City of Um Lodestone"] = 30939,
}

local ID_Items             = {
    PASSING_BRACLET = { 56416 },
    IMPURE_ESSENCE  = { 55667 },
    ANIMA_STONE     = { 54019, 54018},
    ESSENCE         = { 7936,  18178},
    POWERBURST      = { 49069, 49067, 49065, 49063 },
    POUCHE          = { 5509,  5510,  5512,  5514,  24205 },
    WILDY_SWORD     = { 37904, 37905, 37906, 37907, 41376, 41377 },

}

local ID_NPC             = {
    MAGE           = 2257,
}

local ID_Object             = {
    DARK_PORTAL    =   127376,
    CHARGER        =   109428,
    ALTAR_OF_WAR   =   114748,
    SMALL_OBELISK  =   29954,
    WILDY_WALL     = { 65076, 65078, 65077, 65080, 65079, 65082, 65081, 65084,
                       65083, 65087, 65085, 65105, 65096, 65088, 65102, 65090,
                       65089, 65092, 65091, 65094, 65093, 65101, 65095, 65103,
                       65104, 65100, 65099, 65098, 65097, 1440,  1442,  1441,
                       1444,  1443 },--65086

}

local ID_Abby             = {
    ROCK           = 7158,
    EYES           = 7168,
    GAP            = 7164,
    BOIL           = 7165,
    PASSAGE        = 7154,
    TENDRILS       = 7161,
}

local ID_Bank             = {
    BANK_NPC       = 2759,
    BANK_UM        = 127271,
    WAR_BANK       = 114750,
}

local AREA           = {
    EDGEVILLE_LODESTONE     = { x = 3067, y = 3505,  z = 0 },
    EDGEVILLE_BANK          = { x = 3094, y = 3493,  z = 0 },
    EDGEVILLE               = { x = 3087, y = 3503,  z = 0 },
    WILDY                   = { x = 3099, y = 3523,  z = 0 },
    ABBY                    = { x = 3040, y = 4843,  z = 0 },
    WARETREAT               = { x = 3294, y = 10127, z = 0 },
    SMALL_OBELISK           = { x = 3128, y = 3515,  z = 0 },
    DEATHS_OFFICE           = { x = 414,  y = 674,   z = 0 },
    UM_Smithy               = { x = 1149, y = 1804,  z = 1 },
    UM_HauntHill            = { x = 1164, y = 1838,  z = 1 },
    UM_Portal               = { x = 1164, y = 1822,  z = 1 },
    UM_Lodestone            = { x = 1084, y = 1768,  z = 1 },
    Necromantic_Rune_Temple = { x = 1313, y = 1952,  z = 1 },
}
-----------------------UI-----------------------
local function setupOptions()

    btnStop = API.CreateIG_answer()
    btnStop.box_start = FFPOINT.new(235, 169, 0)
    btnStop.box_name = " STOP "
    btnStop.box_size = FFPOINT.new(90, 50, 0)
    btnStop.colour = ImColor.new(255, 255, 255)
    btnStop.string_value = "STOP"

    btnStart = API.CreateIG_answer()
    btnStart.box_start = FFPOINT.new(50, 169, 0)
    btnStart.box_name = " START "
    btnStart.box_size = FFPOINT.new(90, 50, 0)
    btnStart.colour = ImColor.new(0, 0, 255)
    btnStart.string_value = "START"

    IG_Text = API.CreateIG_answer()
    IG_Text.box_name = "TEXT"
    IG_Text.box_start = FFPOINT.new(55, 59, 0)
    IG_Text.colour = ImColor.new(255, 255, 255);
    IG_Text.string_value = "AIO Runecrafter - (v" .. version .. ") by Valtrex"

    IG_Back = API.CreateIG_answer()
    IG_Back.box_name = "back"
    IG_Back.box_start = FFPOINT.new(5, 44, 0)
    IG_Back.box_size = FFPOINT.new(370, 219, 0)
    IG_Back.colour = ImColor.new(15, 13, 18, 255)
    IG_Back.string_value = ""

    tickJagexAcc = API.CreateIG_answer()
    tickJagexAcc.box_ticked = true
    tickJagexAcc.box_name = "Jagex Account"
    tickJagexAcc.box_start = FFPOINT.new(10, 104, 0);
    tickJagexAcc.colour = ImColor.new(0, 255, 0);
    tickJagexAcc.tooltip_text = "Sets idle timeout to 15 minutes for Jagex accounts"

    tickNexusMod = API.CreateIG_answer()
    tickNexusMod.box_ticked = true
    tickNexusMod.box_name = "Nexus Mod relic"
    tickNexusMod.box_start = FFPOINT.new(10, 124, 0);
    tickNexusMod.colour = ImColor.new(0, 255, 0);
    tickNexusMod.tooltip_text = "Arrive at the centre of the Abyss when entering."

    tickPouchProtector = API.CreateIG_answer()
    tickPouchProtector.box_ticked = true
    tickPouchProtector.box_name = "Pouch Protector relic"
    tickPouchProtector.box_start = FFPOINT.new(10, 144, 0);
    tickPouchProtector.colour = ImColor.new(0, 255, 0);
    tickPouchProtector.tooltip_text = "Runecrafting pouches will no longer degrade when used"

    aioSelectR.box_name = "###RUNE"
    aioSelectR.box_start = FFPOINT.new(10, 74, 0)
    aioSelectR.box_size = FFPOINT.new(240, 0, 0)
    aioSelectR.stringsArr = { }
    aioSelectR.tooltip_text = "Select an rune to craft."

    table.insert(aioSelectR.stringsArr, "Select an Rune")
    for i, v in ipairs(aioRune) do
        table.insert(aioSelectR.stringsArr, v.label)
    end

    tickSkull = API.CreateIG_answer()
    tickSkull.box_name = "Use Demonic skull"
    tickSkull.box_start = FFPOINT.new(195, 104, 0);
    tickSkull.colour = ImColor.new(0, 255, 0);
    tickSkull.tooltip_text = "Use this for pvp Protection."

    tickdive = API.CreateIG_answer()
    tickdive.box_name = "Use Surge/ Dive"
    tickdive.box_start = FFPOINT.new(195, 124, 0);
    tickdive.colour = ImColor.new(0, 255, 0);
    tickdive.tooltip_text = "Make use of the surge and dive abillity."

    tickEmpty = API.CreateIG_answer()
    tickEmpty.box_name = "For Testing"
    tickEmpty.box_start = FFPOINT.new(195, 144, 0);
    tickEmpty.colour = ImColor.new(0, 255, 0);
    tickEmpty.tooltip_text = "This is for testing."

    aioSelectF.box_name = "###FAMILIAR"
    aioSelectF.box_start = FFPOINT.new(195, 74, 0)
    aioSelectF.box_size = FFPOINT.new(240, 0, 0)
    aioSelectF.stringsArr = { }
    aioSelectF.tooltip_text = "Select an familiar to use."

    table.insert(aioSelectF.stringsArr, "Don't use Familiar")
    for i, vf in ipairs(aioFamiliar) do
        table.insert(aioSelectF.stringsArr, vf.name)
    end

    API.DrawSquareFilled(IG_Back)
    API.DrawTextAt(IG_Text)
    API.DrawBox(btnStart)
    API.DrawBox(btnStop)
    API.DrawCheckbox(tickNexusMod)
    API.DrawCheckbox(tickJagexAcc)
    API.DrawCheckbox(tickPouchProtector)
    API.DrawComboBox(aioSelectR, false)
    API.DrawCheckbox(tickSkull)
    API.DrawCheckbox(tickdive)
    API.DrawComboBox(aioSelectF, false)
end

local function round(val, decimal)
    if decimal then
        return math.floor((val * 10 ^ decimal) + 0.5) / (10 ^ decimal)
    else
        return math.floor(val + 0.5)
    end
end

function formatNumber(num)
    if num >= 1e6 then
        return string.format("%.1fM", num / 1e6)
    elseif num >= 1e3 then
        return string.format("%.1fK", num / 1e3)
    else
        return tostring(num)
    end
end

local function printProgressReport(final)
    local elapsedMinutes = (os.time() - startTime) / 60
    local TripsPH = round((Trips * 60) / elapsedMinutes)
    local RunesPH = round((Runes * 60) / elapsedMinutes)
    IGP.string_value = "Trips: " .. formatNumber(Trips) .. " | Trips/H: " .. formatNumber(TripsPH) .. " | Runes: " .. formatNumber(Runes) .. " | Runes/H: " .. formatNumber(RunesPH)
end

local function setupGUI()
    IGP = API.CreateIG_answer()
    IGP.box_start = FFPOINT.new(1, 31, 0)
    IGP.box_name = "PROGRESSBAR"
    IGP.colour = ImColor.new(120, 4, 23);
    IGP.string_value = "Abbys Runecrafter AIO"
end

local function drawGUI()
    DrawProgressBar(IGP)
end
-----------------------UI-----------------------
--------------------FUNCTIONS-------------------
local function invContains(items)
    local loot = API.InvItemcount_2(items)
    for _, v in ipairs(loot) do
        if v > 0 then
            return true
        end
    end
    return false
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

local function isAtLocation(location, distance)
    local distance = distance or 20
    return API.PInArea(location.x, distance, location.y, distance, location.z)
end

local function sleep()
    API.RandomSleep2(250, 0, 0)
    API.WaitUntilMovingEnds()
end

local function Logout()
    API.logDebug("Info: Logging out!")
    API.logInfo("Logging out!")
    API.DoAction_Logout_mini()
    API.RandomSleep2(1000, 150, 150)
    API.DoAction_Interface(0x24,0xffffffff,1,1433,68,-1,3808);
    API.Write_LoopyLoop(false)
end

local BankpinInterface = {
    InterfaceComp5.new(759,5,-1,-1,0),
}

local function isBankpinInterfacePresent()
    local result = API.ScanForInterfaceTest2Get(true, BankpinInterface)
    if #result > 0 then
        API.logDebug("Info: Bankpin interface found!")
        API.logInfo("Bankpin interface found!")
    end
end

local function Bank()
    banking = 1
    sleep()
    if fail > 3 then
        API.logError("couldn't bank properly.")
        API.Write_LoopyLoop(false)
        return
    end
    if Necro == true then
        sleep()
        API.DoAction_Object1(0x33, API.OFF_ACT_GeneralObject_route3, { ID_Bank.BANK_UM }, 50)
        API.logDebug("Use bank: City of Um!")
    else
        sleep()
        API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route4, { ID_Bank.BANK_NPC }, 50)
        API.logDebug("Use bank: Edgeville!")
    end

    if API.InvItemcount_1(55667) >= 16  or API.InvItemcount_1(7936) >= 16 or API.InvItemcount_1(18178) >= 16 then
        API.logDebug("Found 16 or more essence!")
        banking = 0
        fail = 0
    end
    if API.Invfreecount_() > 5 then
        API.logError("Didn't get a full inventory!")
        fail = fail + 1
        return
    end
end
--------------------FUNCTIONS-------------------
--------------------TELEPORTS-------------------
local function isLodestoneInterfaceUp()
    return (#API.ScanForInterfaceTest2Get(true, { { 1092, 1, -1, -1, 0 }, { 1092, 54, -1, 1, 0 } }) > 0) or API.Compare2874Status(30)
end

local function isTeleportOptionsUp()
    local vb2874 = API.VB_FindPSettinOrder(2874, -1)
    return (vb2874.state == 13) or (vb2874.stateAlt == 13)
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
        API.logDebug("Info: Use wilderness sword teleport")
        API.logInfo("Use wilderness sword teleport.")
        API.DoAction_Ability_Direct(ws, 1, API.OFF_ACT_GeneralInterface_route)
    else
        teleportToDestination("Edgeville", true)
    end
end

local function teleportToHauntHill()
    local hh = API.GetABs_name1("Passing bracelet")
    if #hh.name > 0 then
        local opts = API.ScanForInterfaceTest2Get(true, { { 720,2,-1,-1,0 }, { 720,16,-1,2,0 }, { 720,9,-1,16,0 } })
        if isTeleportOptionsUp() then
                API.KeyboardPress2(0x32, 60, 100)
                API.RandomSleep2(1000, 1000, 1000)
                API.logDebug("Info: Use Haunt on the Hill teleport")
                API.logInfo("Use Haunt on the Hill teleport.")
       else
            if hh.enabled then
                API.DoAction_Ability_Direct(hh, 7, API.OFF_ACT_GeneralInterface_route)
                API.RandomSleep2(1000, 1000, 1000)
                API.logDebug("pressing 2 key button.")
                API.KeyboardPress2(0x32, 60, 100)
                API.RandomSleep2(1000, 1000, 1000)
            end
        end
    end
    return false
end

local function TeleportWarRetreat()
    if API.GetABs_name1("War's Retreat Teleport") ~= 0 and API.GetABs_name1("War's Retreat Teleport").enabled then
        API.logDebug("Info: Teleport to War's Retreat")
        API.logInfo("Teleport to War's Retreat.")
        API.DoAction_Ability_Direct(API.GetABs_name1("War's Retreat Teleport"), 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(2000,1000,2000)
        API.WaitUntilMovingEnds()
    else
        teleportToDestination("War's Retreat")
    end
end

local function teleportToUM()
    local um = API.GetABs_name1("Tome of Um") or API.GetABs_name1("Tome of Um 2")
    if um.enabled and um.action == "Um Smithy" then
        API.logDebug("Info: Use Tome of Um teleport")
        API.logInfo("Use Tome of Um teleport.")
        API.DoAction_Ability_Direct(um, 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(2000,1000,2000)
        API.WaitUntilMovingEnds()
    else
        teleportToDestination("City of UM", true)
    end
end
--------------------TELEPORTS-------------------
--------------------POWERBURST------------------
local function canUsePowerburst()
    local debuffs = API.DeBuffbar_GetAllIDs()
    local powerburstCoolldown = false
    for _, a in ipairs(debuffs) do
        if a.id == 48960 then
            powerburstCoolldown = true
        end
    end
    return not powerburstCoolldown
end

local function findPowerburst()
    local powerbursts = API.CheckInvStuff3(ID_Items.POWERBURST)
    local foundIdx = -1
    for i, value in ipairs(powerbursts) do
        if tostring(value) == '1' then
            foundIdx = i
            break
        end
    end
    if foundIdx ~= -1 then
        local foundId = ID_Items.POWERBURST[foundIdx]
        if foundId >= 49063 and foundId <= 49069 then
            return foundId
        else
            return nil
        end
    else
        return nil
    end
end
--------------------POWERBURST------------------
--------------------SUMMONING-------------------
local function hasfamiliar()
    API.logDebug("Info: Check if has familliar!")
    return API.Buffbar_GetIDstatus(26095).id > 0
end

local function OpenInventoryIfNeeded()
    if not API.VB_FindPSett(3039).SumOfstate == 1 then
        API.DoAction_Interface(0xc2,0xffffffff,1,1432,5,1,API.OFF_ACT_GeneralInterface_route);
    end
end

local function renewSummoningPoints()
    API.DoAction_Object1(0x3d,API.OFF_ACT_GeneralObject_route0,{ID_Object.ALTAR_OF_WAR} ,50)
    API.RandomSleep2(600,0,0)
    API.WaitUntilMovingEnds()
    API.RandomSleep2(1200,0,0)
end

local function checkForVanishesMessage()
    local chatTexts = ChatGetMessages()
    if chatTexts then
        for k, v in pairs(chatTexts) do
            if k > 2 then break end
            if string.find(v.text, "<col=EB2F2F>You have 1 minute before your familiar vanishes.") then
                API.logDebug("Info: 1 minute left!")
                API.logInfo("Familiar has 1 minute left!")
                return true
            end
            if string.find(v.text, "<col=EB2F2F>You have 30 seconds before your familliar vanishes.") then
                API.logDebug("Info: 30 seconds left!")
                API.logInfo("Familiar has 30 seconds left!")
                return true
            end
        end
    end
    return false
end

local function checkForswordMessage()
    local chatTexts = ChatGetMessages()
    if chatTexts then
        for k, v in pairs(chatTexts) do
            if k > 2 then break end
            if string.find(v.text, "The effects of your Wilderness sword teleport you closer to the abyssal rift.") then
                API.logDebug("Info: A shortcut is taken")
                API.logInfo("A shortcut is taken")
                return true
            end
        end
    end
    return false
end

local function RenewFamiliar()
    if fail > 3 then
        API.logError("couldn't renew familiar.")
        API.Write_LoopyLoop(false)
        return
    end
    if isAtLocation(AREA.WARETREAT, 50) then 
        if API.GetSummoningPoints_() < 400 then
            API.logDebug("Info: Renew summoning points.")
            API.logInfo("Renewing summoning points.")
            renewSummoningPoints() 
        else
            API.RandomSleep2(600,100,300)
            API.logDebug("Doaction: Open bank.")
            API.DoAction_Object1(0x2e, API.OFF_ACT_GeneralObject_route1, {ID_Bank.WAR_BANK}, 50)
            API.RandomSleep2(1000, 500, 1000)
            if API.Invfreecount_() < 2 then
                API.logDebug("Info: Summoning: make more room in your invt.")
                API.KeyboardPress2(0x33,0,50)
                API.RandomSleep2(1000, 500, 1000)
            else
                API.DoAction_Bank(selectedFamiliar, 1, API.OFF_ACT_GeneralInterface_route)
                API.RandomSleep2(1000, 500, 1000)        
                API.KeyboardPress2(0x1B, 50, 150)
                API.RandomSleep2(1000, 500, 1000)
            end 
        end
        if API.InvStackSize(selectedFamiliar) < 1 then
            API.logError("didn't find any pouches")
            fail = fail + 1
            return
        end
        if API.DoAction_Inventory2({ selectedFamiliar }, 0, 1, API.OFF_ACT_GeneralInterface_route) or API.DoAction_Ability_Direct(SelectedAB, 1, API.OFF_ACT_GeneralInterface_route) then
            familiarrenew = 0
            API.RandomSleep2(600,100,300)
            API.WaitUntilMovingEnds()
            OpenInventoryIfNeeded()
            API.RandomSleep2(600,100,300)
            if Necro == true then
                teleportToUM()
                API.logDebug("Teleport back to: City of Um!")
            else
                teleportToEdgeville()
                API.logDebug("Teleport back to: Edgeville!")
            end
        end
        if API.CheckFamiliar() then
            fail = 0
        end
    else
        TeleportWarRetreat()
    end
end

local function familiar()
    if selectedFamiliar then
        API.logDebug("Info: Familliar check 01")
        if not hasfamiliar() or checkForVanishesMessage() then
            API.logDebug("Info: Familliar check 02")
            RenewFamiliar()
        end
    end
end
--------------------SUMMONING-------------------
--------------------SOUL ALTAR------------------
--HELM = 0, CAPE = 1, AMULET = 2, WEAPON = 3, BODY =  4, OFFHAND = 5, BOTTOM = 6, GLOVES = 7, BOOTS = 8, RING = 9, AMMO = 10, AURA = 11 POCKET = 17
local function RuneCounters()
    if API.EquipSlotEq1(0, 32357) and API.EquipSlotEq1(4, 32581) and API.EquipSlotEq1(6, 32582) and API.EquipSlotEq1(7, 32360) and API.EquipSlotEq1(8, 32361) then
        API.logDebug("Found:  Infinity ethereal outfit")
        runecount = runecount + 12;
        API.logDebug("Deposit body: You deposit " .. runecount .. " essence into the charger")
    end
    if API.EquipSlotEq1(0, 32347) and API.EquipSlotEq1(4, 32348) and API.EquipSlotEq1(6, 32349) and API.EquipSlotEq1(7, 32350) and API.EquipSlotEq1(8, 32351) then
        API.logDebug("Found:  Blood ethereal outfit")
        runecount = runecount + 6;
        API.logDebug("Deposit body: You deposit " .. runecount .. " essence into the charger")
    end
    if API.EquipSlotEq1(0, 32352) and API.EquipSlotEq1(4, 32353) and API.EquipSlotEq1(6, 32354) and API.EquipSlotEq1(7, 32355) and API.EquipSlotEq1(8, 32356) then
        API.logDebug("Found:  Death ethereal outfit")
        runecount = runecount + 6;
        API.logDebug("Deposit body: You deposit " .. runecount .. " essence into the charger")
    end
    if API.EquipSlotEq1(0, 32342) and API.EquipSlotEq1(4, 32343) and API.EquipSlotEq1(6, 32344) and API.EquipSlotEq1(7, 32345) and API.EquipSlotEq1(8, 32346) then
        API.logDebug("Found:  Law ethereal outfit")
        runecount = runecount + 6;
        API.logDebug("Deposit body: You deposit " .. runecount .. " essence into the charger")
    end
    if API.CheckInvStuff0(24205) then
        API.logDebug("Found: Massive pouch")
        runecount = runecount + 18;
        API.logDebug("Deposit Massive pouch: You deposit " .. runecount .. " essence into the charger")
    end
    if API.CheckInvStuff0(5514) then
        API.logDebug("Found: Giant pouch")
        runecount = runecount + 12;
        API.logDebug("Deposit Giant pouch: You deposit " .. runecount .. " essence into the charger")
    end
    if API.CheckInvStuff0(5512) then
        API.logDebug("Found: Large pouch")
        runecount = runecount + 9;
        API.logDebug("Deposit Large pouch: You deposit " .. runecount .. " essence into the charger")
    end
    if API.CheckInvStuff0(5510) then
        API.logDebug("Found: Medium pouch")
        runecount = runecount + 6;
        API.logDebug("Deposit Medium pouch: You deposit " .. runecount .. " essence into the charger")
    end
    if API.CheckInvStuff0(5509) then
        API.logDebug("Found: Small pouch")
        runecount = runecount + 3;
        API.logDebug("Deposit Small pouch: You deposit " .. runecount .. " essence into the charger")
    end
    if (aioSelectF.string_value == "Abyssal parasite") then
        API.logDebug("Found: Abyssal parasite")
        runecount = runecount + 7;
        API.logDebug("Deposit Abyssal parasite: You deposit " .. runecount .. " essence into the charger")
    end
    if (aioSelectF.string_value == "Abyssal lurker") then
        API.logDebug("Found: Abyssal lurker")
        runecount = runecount + 12;
        API.logDebug("Deposit Abyssal lurker: You deposit " .. runecount .. " essence into the charger")
    end
    if (aioSelectF.string_value == "Abyssal titan") then
        API.logDebug("Found: Abyssal titan")
        runecount = runecount + 20;
        API.logDebug("Deposit Abyssal titan: You deposit " .. runecount .. " essence into the charger")
    end
end
--------------------SOUL ALTAR------------------
-----------------------PVP----------------------
local function hasTarget()
    if API.GetInCombBit() then
        API.logWarn("getting attacked")
        return true
    end
    return false
end

local WildernissInterface = {
    InterfaceComp5.new(382,14,-1,-1,0),
    InterfaceComp5.new(382,15,-1,14,0),
    InterfaceComp5.new(382,17,-1,15,0),
}

local function isWildernissInterfacePresent()
    local result = API.ScanForInterfaceTest2Get(true, WildernissInterface)
    if #result > 0 then
        API.logDebug("Info: Wildy interface seen!")
        API.logInfo("Found wilderniss warning interface!")
        API.DoAction_Interface(0xffffffff,0xffffffff,0,382,13,-1,2912);
        API.RandomSleep2(3000, 500, 1000)
        API.DoAction_Interface(0xffffffff,0xffffffff,0,382,8,-1,2912);

    end
end

local function Goback()
    API.logWarn("Running back and logging out, been PKed!")
    API.DoAction_Tile(WPOINT.new(3096 + math.random(-6, 6), 3517 + math.random(-2, 2), 0))
    sleep()
    Logout()
end
-----------------------PVP----------------------
---------------------CHECKS---------------------
local function check(condition, errorMessage)
    local result = condition
    if type(condition) == "function" then
        result = condition()
    end
    if not result then
        table.insert(errors, errorMessage)
    end
end

local function invCheck()
    if invContains(ID_Items.POUCHE) then
        local PouchCheck = not PouchProtector
        check(PouchCheck, "It's recomended to use the Pouch Protector relic, the scrips does not repair it for you!")
    end

    local hasRequiredLevel = API.XPLevelTable(API.GetSkillXP("WOODCUTTING")) >= 30 or API.XPLevelTable(API.GetSkillXP("MINING")) >= 30 or API.XPLevelTable(API.GetSkillXP("THIEVING")) >= 30 or API.XPLevelTable(API.GetSkillXP("AGILITY")) >= 30 or API.XPLevelTable(API.GetSkillXP("FIREMAKING")) >= 30
    check(hasRequiredLevel, "You need at least Level 30 in Woodcuting, Mining, Thieving, Agility or Firemaking")

    if selectedFamiliar then
        local warCheck = API.GetABs_name1("War's Retreat Teleport").enabled
        check(warCheck, "You need to have War's Retreat Teleport on your action bar")
    end

    firstRun = false
    return #errors == 0
end
---------------------CHECKS---------------------
--------------------MAIN CODE-------------------
local function Walk()
    if isAtLocation(AREA.EDGEVILLE_LODESTONE, 10) or  isAtLocation(AREA.EDGEVILLE_BANK, 10) or  isAtLocation(AREA.EDGEVILLE, 10) then
        sleep()
        if banking == 0 and invContains(ID_Items.ESSENCE) then
            if p.y < 3521 then
                API.DoAction_Object1(0xb5, API.OFF_ACT_GeneralObject_route0, { 5076, 65078, 65077, 65080, 65079, 65082, 65081, 65084, 65083, 65087, 65085, 65105, 65096, 65088, 65102, 65090, 65089, 65092, 65091, 65094, 65093, 65101, 65095, 65103, 65104, 65100, 65099, 65098, 65097, 1440, 1442, 1441, 1444, 1443 },65)
                API.logDebug("Doaction: Wildy wall")
                sleep()
                if needDemonicSkull and isBankpinInterfacePresent() then
                    API.RandomSleep2(5000, 500, 1000)
                end
                API.RandomSleep2(500, 150, 150)
                if needDemonicSkull and isWildernissInterfacePresent() then
                    API.logDebug("Found wildy warning! (Demonic Skull)")
                    API.RandomSleep2(500, 150, 150)
                    API.WaitUntilMovingEnds()
                end
            end
        else
            API.RandomSleep2(500, 0, 0)
            API.WaitUntilMovingEnds()
            Bank()
        end
    elseif isAtLocation(AREA.WILDY, 50) and not SurgeDiveAbillity then
        sleep()
        if API.PInArea(3089, 50, 3523, 1) then
            API.DoAction_Tile(WPOINT.new(3103 + math.random(-4, 4), 3550 + math.random(-4, 4), 0))
            API.logDebug("Walk to Mage of Zamorak")
            API.RandomSleep2(250, 500, 600)
        else
            if p.y < 3521 then
                API.DoAction_Object1(0xb5, API.OFF_ACT_GeneralObject_route0, { 5076, 65078, 65077, 65080, 65079, 65082, 65081, 65084, 65083, 65087, 65085, 65105, 65096, 65088, 65102, 65090, 65089, 65092, 65091, 65094, 65093, 65101, 65095, 65103, 65104, 65100, 65099, 65098, 65097, 1440, 1442, 1441, 1444, 1443 },65)
                API.logDebug("Doaction: Wildy wall (Safty Check)")
                sleep()
            end
        end
        if API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route, { ID_NPC.MAGE }, 50) then
            API.logDebug("Doaction: Mage of Zamorak")
            sleep()
        end
    elseif isAtLocation(AREA.WILDY, 50) and SurgeDiveAbillity then
        sleep()
        if API.PInArea(3089, 50, 3523, 1) then
            API.RandomSleep2(1500, 1000, 1500)
            if SurgeDiveAbillity then
                API.DoAction_Ability("Surge", 1, API.OFF_ACT_GeneralInterface_route)
                API.logDebug("Doaction: Surge 1")
                API.RandomSleep2(500, 500, 1000)
                API.DoAction_Tile(WPOINT.new(3103 + math.random(-4, 4), 3550 + math.random(-4, 4), 0))
                UTILS.countTicks(2)
                API.DoAction_Surge_Tile(WPOINT.new(3103 + math.random(-4, 4), 3550 + math.random(-4, 4), 0), 0)
                API.logDebug("Doaction: Surge 2")
                API.RandomSleep2(680, 500, 1000)
                API.DoAction_Dive_Tile(WPOINT.new(3104 + math.random(-2, 2), 3556 + math.random(-2, 2), 0))
                API.logDebug("Doaction: Dive")
                sleep()
                API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route, { ID_NPC.MAGE }, 50)
            else
                API.RandomSleep2(3000, 500, 1000)
                API.DoAction_Tile(WPOINT.new(3103 + math.random(-4, 4), 3550 + math.random(-4, 4), 0))
                API.logDebug("Walk to Mage of Zamorak")
                API.RandomSleep2(250, 500, 600)
            end
        else
            API.RandomSleep2(1500, 500, 1000)
            if p.y < 3521 then
                API.DoAction_Object1(0xb5, API.OFF_ACT_GeneralObject_route0, { 5076, 65078, 65077, 65080, 65079, 65082, 65081, 65084, 65083, 65087, 65085, 65105, 65096, 65088, 65102, 65090, 65089, 65092, 65091, 65094, 65093, 65101, 65095, 65103, 65104, 65100, 65099, 65098, 65097, 1440, 1442, 1441, 1444, 1443 },65)
                API.logDebug("Doaction: Wildy wall (Safty Check)")
                sleep()
            end
        end
---------------------Inner circle 
    elseif not needNexusMod and isAtLocation(AREA.ABBY, 50) then
        if checkForswordMessage() then
            API.RandomSleep2(500, 650, 500)
            API.DoAction_Object1(0x29,API.OFF_ACT_GeneralObject_route0,{ selectedPortal },50);
            API.logDebug("Doaction: Shordcut (Inner circle)")
            sleep()
        elseif API.DoAction_Object1(0x3a,API.OFF_ACT_GeneralObject_route0,{ ID_Abby.GAP },10) then
            API.logDebug("Doaction: Gab (Inner circle)")
            API.RandomSleep2(8000, 1000, 1500)
            API.DoAction_Object1(0x29,API.OFF_ACT_GeneralObject_route0,{ selectedPortal },50);
            sleep()
        elseif API.DoAction_Object1(0x3a,API.OFF_ACT_GeneralObject_route0,{ ID_Abby.TENDRILS },10) and API.XPLevelTable(API.GetSkillXP("WOODCUTTING")) >= 30 then
            API.logDebug("Doaction: Tendrils (Inner circle)")
            API.RandomSleep2(8000, 1000, 1500)
            API.DoAction_Object1(0x29,API.OFF_ACT_GeneralObject_route0,{ selectedPortal },50);
            sleep()
        elseif API.DoAction_Object1(0x3a,API.OFF_ACT_GeneralObject_route0,{ ID_Abby.ROCK },10) and API.XPLevelTable(API.GetSkillXP("MINING")) >= 30 then
            API.logDebug("Doaction: Rock (Inner circle)")
            API.RandomSleep2(8000, 1000, 1500)
            API.DoAction_Object1(0x29,API.OFF_ACT_GeneralObject_route0,{ selectedPortal },50);
            sleep()
        elseif API.DoAction_Object1(0x3a,API.OFF_ACT_GeneralObject_route0,{ ID_Abby.EYES },10) and API.XPLevelTable(API.GetSkillXP("THIEVING")) >= 30 then
            API.logDebug("Doaction: Eye's (Inner circle)")
            API.RandomSleep2(8000, 1000, 1500)
            API.DoAction_Object1(0x29,API.OFF_ACT_GeneralObject_route0,{ selectedPortal },50);
            sleep()
        elseif API.DoAction_Object1(0x3a,API.OFF_ACT_GeneralObject_route0,{ ID_Abby.PASSAGE },10) and API.XPLevelTable(API.GetSkillXP("AGILITY")) >= 30 then
            API.logDebug("Doaction: Passage (Inner circle)")
            API.RandomSleep2(8000, 1000, 1500)
            API.DoAction_Object1(0x29,API.OFF_ACT_GeneralObject_route0,{ selectedPortal },50);
            sleep()
        elseif API.DoAction_Object1(0x3a,API.OFF_ACT_GeneralObject_route0,{ ID_Abby.BOIL },10) and API.XPLevelTable(API.GetSkillXP("FIREMAKING")) >= 30 then
            API.logDebug("Doaction: Boil (Inner circle)")
            API.RandomSleep2(8000, 1000, 1500)
            API.DoAction_Object1(0x29,API.OFF_ACT_GeneralObject_route0,{ selectedPortal },50);
            sleep()
        else
            teleportToEdgeville()
            API.RandomSleep2(500, 650, 500)
            API.Write_LoopyLoop(false)
            API.logError("CANT FIND A WAY TO ENTER THE INNER CIRCLE!")
        end
---------------------Inner circle 
    elseif needNexusMod and isAtLocation(AREA.ABBY, 15) then
        API.RandomSleep2(500, 650, 500)
        API.DoAction_Object1(0x29,0,{ selectedPortal },50);
        API.logDebug("Doaction: Clicking on:" .. selectedPortal .."")
        API.logInfo("Enter rift.")
        sleep()
---------------------Soulrune
elseif Soul == true  and isAtLocation(selectedArea, 25) then
    if runecount < 100 then
        if invContains(ID_Items.ESSENCE) then
            if API.DoAction_Object1(0x29,API.OFF_ACT_GeneralObject_route0,{ ID_Object.CHARGER },50) then
                runecount = runecount + API.InvItemcount_1(7936)
                API.logDebug("Deposit Inv.: You deposit " .. runecount .. " essence into the charger")
                API.RandomSleep2(1000, 50, 100)
                RuneCounters()                
                API.RandomSleep2(300, 50, 100)
                API.logDebug("Charger: You deposit " .. runecount .. " essence into the charger")
                API.logInfo("Charger: You deposit " .. runecount .. " essence into the charger")
            end
        API.RandomSleep2(2500, 500, 1000)
        elseif runecount < 100 then
            teleportToEdgeville()
            API.logDebug("Not enough essence, time to bank!")
            API.logInfo("Not enough essence, time to bank!")
            sleep()   
        end
    end
    if runecount == 100 or runecount > 100 and Soulcound == 0 then
        API.RandomSleep2(1000, 500, 1000)
        if not API.isProcessing() then
            API.RandomSleep2(300, 50, 100)
            if API.DoAction_Object1(0x29,API.OFF_ACT_GeneralObject_route1,{ ID_Object.CHARGER },50) then
                API.RandomSleep2(750, 500, 1000)
                Soulcound = 1
                API.logDebug("Soulcounter set to: " .. Soulcound .. "")
                API.RandomSleep2(3000, 500, 1000)
                if not API.isProcessing() and Soulcound == 1 and SoulRun == 3 then
                    SoulRun = SoulRun + 1
                    API.logDebug("Total Soulrun: " .. SoulRun .. ". Need to be 4 before crafting runes!")
                end
            end
        end
        if not API.isProcessing() and Soulcound == 1 and SoulRun < 3 then
            API.logDebug("Info: Done chargering, time For the next run!")
            SoulRun = SoulRun + 1
            runecount = 0
            API.logDebug("Total Soulrun: " .. SoulRun .. ". Need to be 4 before crafting runes!")
            API.logDebug("Reset Runecounter to: " .. runecount .. "")
            teleportToEdgeville()
            sleep()
        end
        if not API.isProcessing() and Soulcound == 1 and SoulRun == 4 or SoulRun > 4 then
            API.logDebug("Total Soulrun: " .. SoulRun .. ". you can now craft soul runes!")
            API.logDebug("Info: Done chargering, time to craft some runes!")
            if canUsePowerburst() and findPowerburst() then
                API.DoAction_Inventory2({ 49069, 49067, 49065, 49063 }, 0, 1, API.OFF_ACT_GeneralInterface_route)
                sleep()
                API.RandomSleep2(1000, 500, 1000)
                API.DoAction_Object1(0x42,API.OFF_ACT_GeneralObject_route0,{ selectedAltar },15)
            else
                sleep()
                API.DoAction_Object1(0x42,API.OFF_ACT_GeneralObject_route0,{ selectedAltar },15)
            end
            sleep()
            runecount = 0
            Soulcound = 0
            SoulRun = 0
            API.logDebug("Soulcounter set to: " .. Soulcound .. "")
            API.logDebug("Reset Runecounter to: " .. runecount .. "")
            API.logDebug("Reset SoulRun to: " .. runecount .. "")
            API.RandomSleep2(250, 500, 600)
            Trips = Trips + API.InvItemcount_1(selectedRune)
            Runes = Runes + API.InvStackSize(selectedRune)
            API.RandomSleep2(3000, 500, 1000)
            teleportToEdgeville()
            API.logDebug("Soul done! Teleporting back for LoopyLoop!")
            API.logInfo("Soul done! Teleporting back!")
            sleep()
        else
            API.RandomSleep(15000)
            API.logDebug("Still charging, please wait")
        end
    end
---------------------Soulrune
elseif isAtLocation(selectedArea, 25) and Soul == false then
    if invContains(ID_Items.ESSENCE) then
        sleep()
        if canUsePowerburst() and findPowerburst() then
            API.logDebug("Use Powerburst")
            return API.DoAction_Inventory2({ 49069, 49067, 49065, 49063 }, 0, 1, API.OFF_ACT_GeneralInterface_route)
        end
        sleep()
        if API.DoAction_Object1(0x42,API.OFF_ACT_GeneralObject_route0,{ selectedAltar },15) then
            API.logDebug("Doaction: Clicking on:" .. selectedAltar .."")
            API.logInfo("Crafting Runes")
        end
        sleep()
    else
        Trips = Trips + API.InvItemcount_1(selectedRune)
        Runes = Runes + API.InvStackSize(selectedRune)
        API.DoRandomEvents()
        sleep()
        teleportToEdgeville()
        API.logDebug("Info: Done! Teleporting back for LoopyLoop!")
        API.logInfo("Done! Teleporting back!")
        sleep()
    end
elseif isAtLocation(AREA.DEATHS_OFFICE, 50) then
        Logout()
        API.logError("LOGGED OUT BECAUSE, YOU DIED!")
    else
            API.RandomSleep2(2500, 150, 150)
            sleep()
            teleportToEdgeville()
            API.logDebug("Info: Unknown area Teleport to Edgeville!")
            API.logInfo("Unknown area Teleport to Edgeville!")
            sleep()
    end
end

local function WalkNecro()
    if isAtLocation(AREA.UM_Lodestone, 25) then
        API.logDebug("Location found: Um lodestone.")
        API.RandomSleep2(1000, 150, 150)
        API.DoAction_Tile(WPOINT.new(1146 + math.random(-4, 4), 1800 + math.random(-4, 4), 1))
        sleep()
    elseif isAtLocation(AREA.UM_Smithy, 15) then
        API.logDebug("Location found: Um Smithy.")
        sleep()
        if banking == 0 and invContains(ID_Items.IMPURE_ESSENCE) then
            if invContains(ID_Items.PASSING_BRACLET) or API.EquipSlotEq1(7, 56416) then
                API.logDebug("Item found: Passing Braclet.")
                teleportToHauntHill()
            end
        else
            sleep()
            Bank()
            sleep()
        end
    elseif isAtLocation(AREA.UM_HauntHill, 5) then
        API.logDebug("Location found: Haunt Hill.")
        if SurgeDiveAbillity then
            API.DoAction_Object1(0x39, API.OFF_ACT_GeneralObject_route0, {ID_Object.DARK_PORTAL}, 50)
            API.RandomSleep2(500, 150, 150)
            API.DoAction_Ability("Surge", 1, API.OFF_ACT_GeneralInterface_route)
            API.RandomSleep2(500, 150, 150)
            API.DoAction_Object1(0x39, API.OFF_ACT_GeneralObject_route0, {ID_Object.DARK_PORTAL}, 50)
            sleep()
        else
            API.DoAction_Object1(0x39, API.OFF_ACT_GeneralObject_route0, {ID_Object.DARK_PORTAL}, 50)
            sleep()
        end
    elseif isAtLocation(AREA.UM_Portal, 10) then
        API.logDebug("Location found: Dark Portal.")
        sleep()
        API.DoAction_Object1(0x39, API.OFF_ACT_GeneralObject_route0, {ID_Object.DARK_PORTAL}, 50)
        sleep()
    elseif isAtLocation(AREA.Necromantic_Rune_Temple, 50) then
        API.logDebug("Location found: Necromantic Rune Temple.")
        if SurgeDiveAbillity and API.PInArea(1313, 5, 1952, 5, 1) then
            API.DoAction_Object1(0x29,API.OFF_ACT_GeneralObject_route0,{ selectedAltar },50)
            API.RandomSleep2(150, 250, 300)
            API.DoAction_Ability("Surge", 1, API.OFF_ACT_GeneralInterface_route)
        end
        sleep()
        if invContains(ID_Items.IMPURE_ESSENCE) then
            sleep()
            if canUsePowerburst() and findPowerburst() then
                API.logDebug("Use Powerburst")
                return API.DoAction_Inventory2({ 49069, 49067, 49065, 49063 }, 0, 1, API.OFF_ACT_GeneralInterface_route)
            end
            sleep()
            if API.DoAction_Object1(0x29,API.OFF_ACT_GeneralObject_route0,{ selectedAltar },50) then
                API.logDebug("Doaction: Clicking on:" .. selectedAltar .."")
                API.logInfo("Crafting Runes")
            end
            sleep()
        else
            Trips = Trips + API.InvItemcount_1(selectedRune)
            Runes = Runes + API.InvStackSize(selectedRune)
            API.DoRandomEvents()
            sleep()
            teleportToUM()
            API.logDebug("Info: Done! Teleporting back for LoopyLoop!")
            API.logInfo("Done! Teleporting back!")
            sleep()
        end
    else
        sleep()
        teleportToUM()
        API.logDebug("Info: Unknown area Teleport to Um Smithy!")
        API.logInfo("Unknown area Teleport to Um Smithy!!")
        sleep()
    end
end
--------------------MAIN CODE-------------------
local function gameStateChecks()
    local gameState = API.GetGameState2()
    if (gameState ~= 3) then
        API.logError('Not ingame with state:', gameState)
        API.Write_LoopyLoop(false)
        return
    end
    if not API.PlayerLoggedIn() then
        API.logError('Not Logged In')
        API.Write_LoopyLoop(false)
        return;
    end
end

setupOptions()
API.SetDrawLogs(Showlogs)
API.SetDrawTrackedSkills(true)
setupGUI()

-----------------------LOOP---------------------
while API.Read_LoopyLoop() do
    gameStateChecks()
---------------- UI
    if btnStop.return_click then
        API.Write_LoopyLoop(false)
        API.SetDrawLogs(false)
    end
    if scriptPaused == false  then
        if btnStart.return_click then
            btnStart.return_click = false
            btnStart.box_name = " START "
            scriptPaused = true
            Soul = false
            print("Script paused!")
            API.logDebug("Info: Script paused!")
        end
    end
    if scriptPaused == true then
        if btnStart.return_click then
            drawGUI()
            btnStart.return_click = false
            btnStart.box_name = " PAUSE "
            IG_Back.remove = true
            btnStart.remove = true
            IG_Text.remove = true
            btnStop.remove = true
            tickJagexAcc.remove = true
            tickNexusMod.remove = true
            tickPouchProtector.remove = true
            aioSelectR.remove = true
            tickSkull.remove = true            
            tickdive.remove = true
            tickEmpty.remove = true
            aioSelectF.remove = true

            SurgeDiveAbillity = tickdive.box_ticked
            needNexusMod = tickNexusMod.box_ticked
            PouchProtector = not tickPouchProtector.box_ticked
            needDemonicSkull = tickSkull.box_ticked
            MAX_IDLE_TIME_MINUTES = (tickJagexAcc.box_ticked == 1) and 5 or 15
            scriptPaused = false
            print("Script started!")
            API.logDebug("Info: Script started!")
            if firstRun then
                startTime = os.time()
            end

            if (aioSelectR.return_click) then
                aioSelectR.return_click = false
                for i, v in ipairs(aioRune) do
                    if (aioSelectR.string_value == v.label) then
                        selectedAltar = v.ALTARIDID
                        selectedPortal = v.PORTALID
                        selectedArea = v.AREAID
                        selectedRune = v.RUNEID
                    end
                end
            end

            if (aioSelectF.return_click) then
                aioSelectF.return_click = false
                for i, vf in ipairs(aioFamiliar) do
                    if (aioSelectF.string_value == vf.name) then
                        selectedFamiliar = vf.FAMILIARID
                        SelectedAB = vf.ABNAME
                    end
                end
            end

            if selectedFamiliar then
                API.logDebug("Info: Familliar selected!")
            else
                API.logDebug("Info: No familliar selected!")
            end

            if selectedAltar == nil then
                API.Write_LoopyLoop(false)
                print("Please select a Rune type from the dropdown menu!")
                API.logError("Please select a Rune type from the dropdown menu!")
            end
            if (aioSelectR.string_value == "Soul rune") then
                Soul = true
            elseif (aioSelectR.string_value == "(Necro) Spirit rune") or (aioSelectR.string_value == "(Necro) Bone rune") or (aioSelectR.string_value == "(Necro) Flesh rune") or (aioSelectR.string_value == "(Necro) Miasma rune") then
                Necro = true
            end
        end
        goto continue
    end
-------------END UI 
    if firstRun and not invCheck() then
        print("!!! Startup Check Failed !!!")
        API.logError("!!! Startup Check Failed !!!")
        if #errors > 0 then
            print("Errors:")
            API.logError("Errors:")
            for _, errorMsg in ipairs(errors) do
                print("- " .. errorMsg)
                API.logError("- " .. errorMsg)
            end
        end
        API.Write_LoopyLoop(false)
        break
    end
    if selectedFamiliar then
        if checkForVanishesMessage() then
            familiarrenew = 1
        end
    end

    if selectedFamiliar then
        if familiarrenew == 1 then
            RenewFamiliar()
        end
    end

    p = API.PlayerCoordfloat()
    API.SetMaxIdleTime(MAX_IDLE_TIME_MINUTES)
    API.DoRandomEvents()

    if isBankpinInterfacePresent() then
        API.DoBankPin(Bankpin)
    end

    familiar()

    if needDemonicSkull and isAtLocation(AREA.WILDY) then
        API.logDebug("Info: Checking for getting PKed!")
        if hasTarget() then
            API.logDebug("Info: Targed found, Go Back!")
            Goback()
        end
    end

    API.RandomSleep2(500, 150, 150)
    API.WaitUntilMovingEnds()

    if selectedFamiliar and isAtLocation(AREA.WARETREAT, 50) then
        API.logDebug("Waiting until a familiar is summond!")
    else
        if isBankpinInterfacePresent() then
            API.DoBankPin(Bankpin)
        else
            if Necro == true then
                API.logDebug("Necro rune selected!")
                WalkNecro()
            else
                Walk()
                API.logDebug("Normal rune selected!")
            end
        end
    end

    API.RandomSleep2(500,500,500)

    ::continue::
    printProgressReport()
    API.RandomSleep2(500, 650, 500)
end
-----------------------LOOP---------------------
