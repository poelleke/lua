-- Title: Construction Test build
-- Author: <Valtrex>
-- Description: <>
-- Version: V 0.0 <Closed Testing!>
-- Category: Construction
-- Date : 2026-05-15

--[[ TODO plan
Fase 1 – Basis - Done 27-07-26
✅ Contract lezen.
✅ Naar de juiste stad teleporteren.
✅ Naar het gebouw lopen.
✅ Alle Repair-hotspots vinden en repareren.
✅ Contract inleveren.

✅ Fase 2 – Meerdere verdiepingen:
- Tabel aan vullen met alle waardes.

✅ Fase 3 – Deuren:
- Tabel aan vullen met alle waardes.



🔄 Optimaliseren/ known Bugs:
- build interface slimmer maken door te kiezen op basis van wat beschikbaar is en max level en niet vanuit gaan van de laatste optie.

Release Notes:
- Version 1.00  : Initial release.
]]

local API = require("api")
local Interfaces = require("Data.Interfaces")
local Data = require("Data.Data")

local M = {}

local running = false
local paused = false

----------------------------------------------------
-- USER CONFIGURATION:
----------------------------------------------------
local BankPin = "1993" -- USE: "1234" if you want to set a pin

----------------------------------------------------
-- STATES
----------------------------------------------------
local STATE_START             = 0
local STATE_CHECK_CONTRACT    = 1
local STATE_OPEN_INTERFACE    = 2
local STATE_SYNC_CONTRACT     = 3
local STATE_TRAVEL            = 4
local STATE_BUILD             = 5
local STATE_RETURN_HOME       = 6
local STATE_HANDIN            = 7
local STATE_BANK              = 8
local STATE_STOP              = 9

local CurrentState = STATE_START
local Config = nil

----------------------------------------------------
-- CACHE
----------------------------------------------------
local RepairAttempts = 0
local StopReason = ""
local lastContract = ""
local lastInventory = nil
local lastTaskCount = -1
local DoorHandled = false
local CurrentContract = {
    location = nil,
    npc = nil,
    townArea = nil,
    buildingArea = nil,
    repairTarget = nil,
    door = nil,
}

----------------------------------------------------
-- CONSTANTEN
----------------------------------------------------
local inter_location = Interfaces.Location
local inter_npc      = Interfaces.NPC
local inter_build    = Interfaces.Build
local TASK_ROUTES    = Interfaces.TaskRoutes

local SPRITE_COMPLETE   = 13165
local SPRITE_INCOMPLETE = 13166

local NPC = Data.NPC
local Objects = Data.Objects

-- Database met alle Item ID's van de wiki voor Construction Contracts
local Items     = Data.Items
--[[local constructionItems = {
    planks = {
        regular  = 960,
        oak      = 8778,
        teak     = 8780,
        mahogany = 8782,
        eternal  = 63190
    },
    nails = {
        bronze  = 4819,
        iron    = 4820,
        steel   = 1539,
        black   = 4821,
        mithril = 4822,
        adamant = 4823,
        rune    = 4824
    },
    bars = {
        iron    = 2351,
        steel   = 2353,
        mithril = 2359,
        adamant = 2361,
        rune    = 2363
    },
    misc = {
        white_candle  = 36,
        bolt_of_cloth = 8790,
        plank_box     = 50450,
        contract      = 50916
    }
}]]

local HOTSPOTS = Data.HOTSPOTS

-- Alle geldige locaties van de wiki
local townAreas = {--x1 west, Y1 zuid, X2 oost, Y2 noord
    ["Edgeville"]   = { x1 = 3064,  y1 = 3482,  x2 = 3103, y2 = 3519 },
    ["Draynor"]     = { x1 = 3072,  y1 = 3234,  x2 = 3118, y2 = 3303 },
    ["Varrock"]     = { x1 = 3137,  y1 = 3373,  x2 = 3291, y2 = 3520 },
    ["Lumbridge"]   = { x1 = 3192,  y1 = 3189,  x2 = 3254, y2 = 3269 },
    ["Home"]        = { x1 = 2934,  y1 = 3216,  x2 = 2953, y2 = 3232 },
    
}
-- Database met GEBOUW-BOXEN (Area-systeem)
local buildingAreas  = {
    ["Ned"]             = { x1 = xxxx, y1 = xxxx, x2 = xxxx, y2 = xxxx },--Nog testen
    ["Aggie"]           = { x1 = xxxx, y1 = xxxx, x2 = xxxx, y2 = xxxx },--Nog testen
    ["Wise old man"]    = { x1 = xxxx, y1 = xxxx, x2 = xxxx, y2 = xxxx },--Nog testen
    ["Bob's Axes"]      = { x1 = 3227, y1 = 3201, x2 = 3234, y2 = 3206 },--Goed
    ["Father Aereck"]   = { x1 = 3242, y1 = 3204, x2 = 3250, y2 = 3216 },--Goed
    ["Victoria"]        = { x1 = 3229, y1 = 3206, x2 = 3234, y2 = 3210 },--Goed
    ["The bartender"]   = { x1 = xxxx, y1 = xxxx, x2 = xxxx, y2 = xxxx },--Nog testen
    ["Charos"]          = { x1 = xxxx, y1 = xxxx, x2 = xxxx, y2 = xxxx },--Nog testen
    ["The shopkeeper"]  = {
        ["Edgeville"]   = { x1 = 3076, y1 = 3507, x2 = 3085, y2 = 3514 },--Goed
        ["Lumbridge"]   = { x1 = 3211, y1 = 3239, x2 = 3219, y2 = 3244 },--Goed
        ["Varrock"]     = { x1 = 3213, y1 = 3410, x2 = 3221, y2 = 3421 } --Goed
    }
}

local DOORS     = Data.DOORS
local STAIRS    = Data.STAIRS
--[[local DOORS = {
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

local STAIRS = {
    Victoria = {
        up = { id = 45483, x = 3231, y = 3209, floor = 0, action = "Climb-up" },
        down = {  id = 45484, x = 3231, y = 3209, floor = 1, action = "Climb-down" }
    },
    ShopkeeperLumbridge = {
        up = { id = 45481, x = 3216, y = 3239, floor = 0, action = "Climb-up" },
        down = { id = 45482, x = 3215, y = 3239, floor = 1, action = "Climb-down" }
    },
}]]

local lodestones = {
    ["Edgeville"] = 15,
    ["Draynor"]   = 14,
    ["Lumbridge"] = 17,
    ["Varrock"]   = 21
}

----------------------------------------------------
-- Main initialization
----------------------------------------------------

API.SetDrawLogs(true)

----------------------------------------------------
-- TASKS
----------------------------------------------------
local function CheckContract()
    local scan_loc = API.ScanForInterfaceTest2Get(false, inter_location)
    local scan_npc = API.ScanForInterfaceTest2Get(false, inter_npc)
    
    if scan_loc and scan_loc[1] and scan_loc[1].textids and scan_npc and scan_npc[1] and scan_npc[1].textids then
        local foundLocation = scan_loc[1].textids
        local foundNPC = scan_npc[1].textids
        
        if townAreas [foundLocation] then
            local area = nil
            
            if foundNPC == "The shopkeeper" then
                if buildingAreas [foundNPC] and buildingAreas [foundNPC][foundLocation] then
                    area = buildingAreas [foundNPC][foundLocation]
                end
            else
                if buildingAreas [foundNPC] then
                    area = buildingAreas [foundNPC]
                end
            end
            
            if area then
                --print("Contract valid! Location: " .. foundLocation .. " | Contractee: " .. foundNPC .. " -> Area: Linksonder("..area.x1..","..area.y1..") Rechtsboven("..area.x2..","..area.y2..")")
                return true, foundLocation, foundNPC, area
            end
        end
    end
    
    return false, nil, nil, nil
end
-- Hulpfunctie om te kijken hoeveel taken klaar zijn
local function GetCompletedTasks()

    local completed = 0
    local total = #TASK_ROUTES
    local states = {}

    for i, route in ipairs(TASK_ROUTES) do

        local scan = API.ScanForInterfaceTest2Get(false, route)

        if scan and scan[1] then

            local sprite = API.Mem_Read_int(scan[1].memloc + API.I_slides)

            states[i] = sprite

            if sprite == SPRITE_COMPLETE then
                completed = completed + 1
            end

        else
            states[i] = nil
        end

    end

    return completed, total, states

end

local function IsPlayerInArea(area)

    local pos = API.PlayerCoord()

    --print("PlayerCoord: " .. pos.x .. "," .. pos.y .. "," .. pos.z)
    --print("Area: " .. area.x1 .. "," .. area.y1 .. " -> " .. area.x2 .. "," .. area.y2)

    if not pos or not area then
        return false
    end

    return pos.x >= area.x1
       and pos.x <= area.x2
       and pos.y >= area.y1
       and pos.y <= area.y2

end

local function GetRandomPointInArea(area)

    return {
        x = math.random(area.x1, area.x2),
        y = math.random(area.y1, area.y2),
        z = 0
    }

end

local function IsPlayerMoving()
    return API.ReadPlayerMovin()
end

local function WalkToPoint(x, y, z)

    print(string.format(
        "WalkToPoint: Klik op (%d, %d, %d).",
        x,
        y,
        z
    ))

    API.DoAction_Tile(WPOINT.new(x, y, z))

    return true

end

local function IsDoorInNextWalk(door)

    local pos = API.PlayerCoord()

    local dx = CurrentContract.walkTarget.x - pos.x
    local dy = CurrentContract.walkTarget.y - pos.y

    local distance = math.sqrt(dx * dx + dy * dy)

    local step = 30        -- maximale stapgrootte van WalkToArea()

    if distance < step then
        step = distance
    end

    local nx = dx / distance
    local ny = dy / distance

    local walkX = pos.x + nx * step
    local walkY = pos.y + ny * step

    for _, closedDoor in ipairs(door.closed) do

        local ddx = closedDoor.x - walkX
        local ddy = closedDoor.y - walkY

        if math.sqrt(ddx * ddx + ddy * ddy) <= 5 then
            return true
        end

    end

    return false

end

local function WalkToArea(area)

    if IsPlayerInArea(area) then
        print("WalkToArea: Speler is al in de building area.")
        return true
    end

    local pos = API.PlayerCoord()

    print(string.format(
        "WalkToArea: Van (%d,%d) naar (%d,%d)",
        pos.x,
        pos.y,
        CurrentContract.walkTarget.x,
        CurrentContract.walkTarget.y
    ))

    local dx = CurrentContract.walkTarget.x - pos.x
    local dy = CurrentContract.walkTarget.y - pos.y

    local distance = math.sqrt(dx * dx + dy * dy)
    local step = math.random(28, 35)

    if distance > step then

        local nx = dx / distance
        local ny = dy / distance

        local walkX = math.floor(pos.x + nx * step)
        local walkY = math.floor(pos.y + ny * step)

        print(string.format(
            "WalkToArea: Afstand %.1f | Stap %d | Tussenpunt (%d,%d)",
            distance,
            step,
            walkX,
            walkY
        ))

        WalkToPoint(walkX, walkY, pos.z)

    else

        print(string.format(
            "WalkToArea: Afstand %.1f | Stap %d | Eindpunt (%d,%d)",
            distance,
            step,
            CurrentContract.walkTarget.x,
            CurrentContract.walkTarget.y
        ))

        WalkToPoint(
            CurrentContract.walkTarget.x,
            CurrentContract.walkTarget.y,
            pos.z
        )

    end
    return false
end

----------------------------------------------------
-- State
----------------------------------------------------

local function OpenLodestoneInterface()

    if API.Compare2874Status(30, false) then
        return true
    end

    print("OpenLodestoneInterface: Opening interface.")

    API.DoAction_Interface(
        0xffffffff,
        0xffffffff,
        1,
        1465,
        33,
        -1,
        API.OFF_ACT_GeneralInterface_route
    )

    local timeout = os.clock() + 5

    while os.clock() < timeout do

        if API.Compare2874Status(30, false) then
            print("OpenLodestoneInterface: Interface geopend.")
            return true
        end

        API.RandomSleep2(1000,1000,1000)

    end

    print("OpenLodestoneInterface: Timeout.")
    return false

end

local function ClickLodestone(location)

    local id = lodestones[location]

    if not id then
        print("ClickLodestone: Onbekende locatie: "..tostring(location))
        return false
    end

    print("ClickLodestone: "..location)

    API.DoAction_Interface(
        0xffffffff,
        0xffffffff,
        1,
        1092,
        id,
        -1,
        API.OFF_ACT_GeneralInterface_route
    )

    return true

end

local function WaitForTeleport(area)

    print("WaitForTeleport: Wachten op teleport.")

    local timeout = os.clock() + 15

    while os.clock() < timeout do

        if IsPlayerInArea(area) then

            print("WaitForTeleport: Area bereikt.")

            -- Geef de RS3-client de tijd om alles te laden.
            API.RandomSleep2(2500, 5000, 1000)

            print("WaitForTeleport: Teleport voltooid.")
            return true

        end

        API.RandomSleep2(1000, 1000, 1000)

    end

    print("WaitForTeleport: Timeout.")
    return false

end

local function TeleportToTown(location)

    print("TeleportToTown: "..location)

    if not OpenLodestoneInterface() then
        return false
    end

    API.RandomSleep2(3500, 2500, 4000)

    if not ClickLodestone(location) then
        return false
    end

    return WaitForTeleport(townAreas[location])

end

local function InDoorTrigger()

    if not CurrentContract.door then
        return false
    end

    local player = API.PlayerCoord()
    local trigger = CurrentContract.door.trigger

    if player.z ~= trigger.floor then
        return false
    end

    local dx = player.x - trigger.x
    local dy = player.y - trigger.y
    local distance = math.sqrt(dx * dx + dy * dy)

    print(string.format(
        "DoorTrigger | Speler: (%d,%d,%d) | Trigger: (%d,%d,%d) | Afstand: %.2f | Radius: %d",
        player.x,
        player.y,
        player.z,
        trigger.x,
        trigger.y,
        trigger.floor,
        distance,
        trigger.radius
    ))

    if distance <= trigger.radius then
        print("DoorTrigger | Binnen trigger.")
        return true
    end

    return false

end

local function IsDoorOpen(door)

    local objects = API.FindObject_string({door.object_name}, 50)

    if not objects or #objects == 0 then
        return false
    end

    for _, obj in ipairs(objects) do
        for _, openDoor in ipairs(door.open) do

            if obj.Id == openDoor.id
            and math.floor(obj.TileX / 512) == openDoor.x
            and math.floor(obj.TileY / 512) == openDoor.y
            and obj.Floor == openDoor.floor then

                return true

            end
        end
    end

    return false

end

local function HandleDoor(door)

    print("Controleer deur: " .. door.name)

    -- Staat de deur al open?
    if IsDoorOpen(door) then
        print(door.name .. ": deur staat al open.")
        API.RandomSleep2(2000, 1000, 1000)
        return true
    end

    local objects = API.FindObject_string({door.object_name}, 50)

    if not objects or #objects == 0 then
        print("Geen deur gevonden: " .. door.name)
        return false
    end

    -- Zoek gesloten deur
    for _, obj in ipairs(objects) do
        for _, closedDoor in ipairs(door.closed) do

            if obj.Id == closedDoor.id
            and math.floor(obj.TileX / 512) == closedDoor.x
            and math.floor(obj.TileY / 512) == closedDoor.y
            and obj.Floor == closedDoor.floor then

                print(door.name .. ": gesloten deur gevonden.")

                local p = API.PlayerCoord()
                print("Player: " .. p.x .. "," .. p.y .. "," .. p.z)
                print("Klik deur: " .. closedDoor.id)

                API.DoAction_Object2( 0x31, API.OFF_ACT_GeneralObject_route0, { closedDoor.id }, 50, WPOINT.new( closedDoor.x, closedDoor.y, closedDoor.floor ) )

                -- Ruim de tijd geven om naar de deur te lopen en deze te openen
                API.RandomSleep2(4000, 1500, 1500)

                -- Opnieuw controleren
                if IsDoorOpen(door) then
                    print(door.name .. ": deur succesvol geopend.")
                    API.RandomSleep2(2000, 1000, 1000)
                    return true
                end

                print(door.name .. ": deur is nog niet open.")
                return false

            end
        end
    end

    print(door.name .. ": geen passende deurstatus gevonden.")
    return false

end

local function HandleStairs()

    print("=== HandleStairs gestart ===")

    if not CurrentContract.stairs then
        print("Geen trapgegevens beschikbaar.")
        return false
    end

    local player = API.PlayerCoord()
    local stair = nil
    local targetFloor = nil

    if player.z == 0 then
        stair = CurrentContract.stairs.up
        targetFloor = 1
    else
        stair = CurrentContract.stairs.down
        targetFloor = 0
    end

    print("Trap: " .. stair.action)

    local objects = API.FindObject_string({ "Stairs" }, 30)

    if not objects or #objects == 0 then
        print("Geen trap gevonden.")
        return false
    end

    for _, obj in ipairs(objects) do

        if obj.Id == stair.id
        and math.floor(obj.TileX / 512) == stair.x
        and math.floor(obj.TileY / 512) == stair.y
        and obj.Floor == stair.floor then

            print("Trap gevonden.")
            print("Klik trap: " .. stair.id)

            API.DoAction_Object2(
                0x31,
                API.OFF_ACT_GeneralObject_route0,
                { stair.id },
                50,
                WPOINT.new(stair.x, stair.y, stair.floor)
            )

            API.RandomSleep2(4000, 1500, 1500)

            if API.PlayerCoord().z == targetFloor then
                print("Trap succesvol gebruikt.")
                return true
            end

            print("Verdieping niet veranderd.")
            return false

        end

    end

    print("Juiste trap niet gevonden.")
    return false

end

local function PressBuildHotkey()--TODO afmaken

    print("Probeer build via toetsenbord.")

    -- TODO:
    -- Keyboard "1" t/m "5" sturen afhankelijk van Construction level.

    return false

end

local function ClickBuildButtonFallback()--TODO afmaken

    print("Probeer build via DoAction_Interface.")

    -- TODO:
    -- DoAction_Interface uitvoeren.

    return false

end


local function HasError()
    local chats = API.GatherEvents_chat_check()

    if chats then
        for _, v in ipairs(chats) do
            local text = tostring(v.text or "")

            if text ~= "" then

                if string.find(text, "do not have the materials") then
                    print("Build error: onvoldoende materialen.")
                    return "NO_MATERIALS"

                elseif string.find(text, "You do not currently have a construction contract.") then
                    print("Contract error: geen actief contract.")
                    return "NO_CONTRACT"

                end
            end
        end
    end

    return nil
end

local function HandleRepairTimeout()

    print("DEBUG RepairAttempts = " .. tostring(RepairAttempts))

    local err = HasError()

    if err == "NO_MATERIALS" then
        print("Materialen op.")
        RepairAttempts = 0
        return "bank"
    end

    if RepairAttempts == 0 then
        RepairAttempts = 1
        print("Poging 1: Build via toetsenbord.")
        return "hotkey"
    end

    if RepairAttempts == 1 then
        RepairAttempts = 2
        print("Poging 2: Build via DoAction_Interface.")
        return "fallback"
    end

    StopReason = "Build is na twee herstelpogingen niet gestart."
    return "stop"

end

local function WaitForBuildInterface(timeout)

    timeout = timeout or 3

    local endTime = os.clock() + timeout

    while os.clock() < endTime do

        if API.GetInterfaceOpenBySize(1306) then
            return true
        end

        API.RandomSleep2(500, 500, 500)

    end

    return false

end

local function FindRepairObject()

    local objects = API.FindObject_string(HOTSPOTS, 20)

    if not objects or #objects == 0 then
        return nil
    end

    return API.Math_SortAODist(objects)
end

local function ClickBuildButton()

    local level = API.XPLevelTable(API.GetSkillXP("CONSTRUCTION"))

    print("Construction level: " .. tostring(level))

    -- Optie 5
    if level >= 100 then
        print("Build optie 5")
        API.RandomSleep2(1000, 500, 350)
        API.KeyboardPress2(0x35, 60, 100)
        return true

    -- Optie 4
    elseif level >= 70 then
        print("Build optie 4")

        -- TODO: DoAction voor optie 4
        return true

    -- Optie 3
    elseif level >= 60 then
        print("Build optie 3")

        -- TODO: DoAction voor optie 3
        return true

    -- Optie 2
    elseif level >= 50 then
        print("Build optie 2")

        -- TODO: DoAction voor optie 2
        return true

    -- Optie 1
    elseif level >= 40 then
        print("Build optie 1")

        -- TODO: DoAction voor optie 1
        return true
    end

    print("Construction level te laag om te bouwen.")
    return false
end

local function RepairObjectStillExists()

    if not CurrentContract.repairTarget then
        return false
    end

    local objects = API.FindObject_string(HOTSPOTS, 10)

    if not objects then
        return false
    end

    for _, obj in ipairs(objects) do

        if obj.Id == CurrentContract.repairTarget.id
        and math.floor(obj.TileX / 512) == CurrentContract.repairTarget.x
        and math.floor(obj.TileY / 512) == CurrentContract.repairTarget.y
        and obj.Floor == CurrentContract.repairTarget.floor then

            return true

        end

    end

    return false

end

local function WaitForRepair(timeout)

    timeout = timeout or 20

    local endTime = os.clock() + timeout
    local started = false

    while os.clock() < endTime do

        local exists = RepairObjectStillExists()

        if not started then

            if exists then
                started = true
                print("Repair started.")
            end

        else

            if not exists then
                print("Repair finished.")
                return true
            end

        end

        API.RandomSleep2(100, 50, 50)

    end

    return false

end

local function FindClosestRepairObject()

    local playerFloor = API.PlayerCoord().z
    local objects = API.FindObject_string(HOTSPOTS, 30)

    if not objects or #objects == 0 then
        return nil
    end

    local closest = nil

    for _, obj in ipairs(objects) do

        if obj.Floor == playerFloor then

            if not closest or obj.Distance < closest.Distance then
                closest = obj
            end

        end

    end

    return closest

end

local function RepairFloor()

    local obj = FindClosestRepairObject()

    if not obj then
        print("Geen repair object gevonden op deze verdieping.")
        return "done"
    end

    CurrentContract.repairTarget = {
        name = obj.Name,
        id = obj.Id,
        distance = obj.Distance,
        floor = obj.Floor,
        x = math.floor(obj.TileX / 512),
        y = math.floor(obj.TileY / 512)
    }

    print(string.format(
        "Repair object: %s | afstand: %.2f | verdieping: %d",
        obj.Name,
        obj.Distance,
        obj.Floor
    ))

    API.GatherEvents_chat_check()

    API.DoAction_Object_Direct(
        0x29,
        API.OFF_ACT_GeneralObject_route0,
        obj
    )

    local timeout = os.clock() + 15

    while os.clock() < timeout do

        if not API.ReadPlayerMovin() then
            break
        end

        API.RandomSleep2(200, 100, 100)

    end

    API.RandomSleep2(800, 400, 400)

    if not WaitForBuildInterface(10) then
        StopReason = "Build interface opende niet."
        return "stop"
    end

    print("Build interface geopend.")

    API.RandomSleep2(500, 200, 200)

    if not ClickBuildButton() then
        StopReason = "Normale Build-knop kon niet worden gebruikt."
        return "stop"
    end

    while true do

        API.RandomSleep2(600, 200, 300)

        if WaitForRepair() then
            API.RandomSleep2(300, 150, 150)
            RepairAttempts = 0
            CurrentContract.repairTarget = nil
            return "success"
        end

        print("Repair timeout.")

        local result = HandleRepairTimeout()

        if result == "hotkey" then
            PressBuildHotkey()

        elseif result == "fallback" then
            ClickBuildButtonFallback()

        elseif result == "bank" then
            return "bank"

        elseif result == "stop" then
            return "stop"
        end

    end

end

local function TeleportHome()

    print("Gebruik House Teleport.")

    API.DoAction_Ability_Direct(
        API.GetABs_name1("House Teleport"),
        1,
        API.OFF_ACT_GeneralInterface_route
    )

    return WaitForTeleport(townAreas["Home"])

end

local function HandInContract()

    local npc = API.FindNPCbyName("Estate agent", 15)

    print("NPC object: " .. tostring(npc))

    if not npc then
        print("Estate agent niet gevonden.")
        return false
    end

    print("Praat met Estate agent.")

    API.DoAction_NPC( 0x29, API.OFF_ACT_InteractNPC_route3, { NPC.Estate_agent }, 50 )
    API.RandomSleep2(2500,1500,1500)

    local timeout = os.clock() + 5

    while os.clock() < timeout do

        if API.DoDialog_Option("I want a new contract.") then
            print("Nieuw contract aangevraagd.")
            API.RandomSleep2(4000, 2000, 2000)
            return true
        end
        API.RandomSleep2(1200, 800, 800)
    end

    print("Geen contractoptie gevonden. Script wordt gestopt.")
    StopReason = "Geen contractoptie gevonden."
    CurrentState = STATE_STOP
    return false
end

---------BANKING
local function HandleBankPin()

    if not API.GetInterfaceOpenBySize(759) then
        return true
    end

    print("Bank PIN gedetecteerd.")

    if not BankPin then

        StopReason = "Bank PIN vereist, maar niet ingesteld."
        CurrentState = STATE_STOP
        return false

    end

    API.DoBankPin(BankPin)

    local timeout = os.clock() + 5

    while os.clock() < timeout do

        if not API.GetInterfaceOpenBySize(759) then
            print("Bank PIN ingevoerd.")
            return true
        end

        API.RandomSleep2(200, 300, 100)

    end

    StopReason = "Bank PIN ontbreekt of is onjuist."
    CurrentState = STATE_STOP

    return false

end

local function LoadLastPreset()
    print("Load last preset.")
    API.DoAction_Object1(0x33, API.OFF_ACT_GeneralObject_route3, {OBJECT.Bank_Chest}, 50)
    API.RandomSleep2(800, 1200, 300)
    return true
end

local function Bank()

    if not LoadLastPreset() then
        return false
    end

    if not HandleBankPin() then
        return false
    end

    if Inventory:GetItemAmount(Items.misc.plank_box) == 0 then
        print("Geen plank box gevonden.")
        return true
    end

    print("Plank box gevonden.")

    API.DoAction_Object1(0x33, API.OFF_ACT_GeneralObject_route1, {OBJECT.Bank_Chest}, 50)

    local timeout = os.clock() + 5

    while os.clock() < timeout do

        if API.BankOpen2() then
            print("Bank geopend.")
            break
        end

        API.RandomSleep2(200, 300, 100)

    end

    if not API.BankOpen2() then

        print("Bank kon niet worden geopend.")

        StopReason = "Bank kon niet worden geopend."
        CurrentState = STATE_STOP

        return false

    end

    print("Plank box vullen.")

    API.DoAction_Bank_Inv(Items.misc.plank_box, 8, API.OFF_ACT_GeneralInterface_route2)

    API.RandomSleep2(1200, 1500, 300)

    print("Bank sluiten.")

    API.KeyboardPress32(0x1B, 100)

    API.RandomSleep2(400, 600, 100)

    return true

end

----------------------------------------------------
-- MAIN LOOP
----------------------------------------------------
function M.Tick()

    if not running or paused then
        return
    end
    if CurrentState == STATE_START then
        print("Script gestart.")
        CurrentState = STATE_CHECK_CONTRACT

    elseif CurrentState == STATE_CHECK_CONTRACT then
        if Inventory:GetItemAmount(Items.misc.contract) > 0 then
            print("Contract gevonden.")
            CurrentState = STATE_OPEN_INTERFACE
        else
            print("Geen contract.")
            CurrentState = STATE_STOP
        end

    elseif CurrentState == STATE_OPEN_INTERFACE then

        if not API.InventoryInterfaceCheckvarbit() then
            StopReason = "Inventory is niet geopend. Open de inventory voordat je het script start."
            CurrentState = STATE_STOP

        elseif CheckContract() then

            print("Interface geopend.")
            CurrentState = STATE_SYNC_CONTRACT

        else

            local err = HasError()

            if err == "NO_CONTRACT" then
                print("Contract voltooid. Terug naar Home.")
                CurrentState = STATE_RETURN_HOME

            else
                print("Klik contract")
                API.DoAction_Inventory1(
                    Items.misc.contract,
                    0,
                    1,
                    API.OFF_ACT_GeneralInterface_route
                )
                API.RandomSleep2(1300, 1100, 1200)
            end

        end

    elseif CurrentState == STATE_SYNC_CONTRACT then
        local ok, location, npc, area = CheckContract()
        if not ok then
            print("Geen geldig contract gevonden.")
            CurrentState = STATE_STOP
            return
        end

        DoorHandled = false
        CurrentContract.location = location
        CurrentContract.npc = npc
        CurrentContract.townArea = townAreas[location]
        CurrentContract.buildingArea = area
        CurrentContract.walkTarget = GetRandomPointInArea(area)
        print(string.format( "Nieuw walk target: (%d,%d)", CurrentContract.walkTarget.x, CurrentContract.walkTarget.y ))
        CurrentContract.door = nil
        CurrentContract.stairs = nil

        if npc == "Father Aereck" then
            CurrentContract.door = DOORS.FatherAereck
        elseif npc == "Victoria" then
            CurrentContract.door = DOORS.Victoria
            CurrentContract.stairs = STAIRS.Victoria
        elseif npc == "The shopkeeper" and location == "Lumbridge" then
            CurrentContract.stairs = STAIRS.ShopkeeperLumbridge
        end

        local completed, total = GetCompletedTasks()

        print("Taken voltooid: " .. completed .. "/" .. total)

        if completed == total then
            CurrentState = STATE_RETURN_HOME
        else
            CurrentState = STATE_TRAVEL
        end

    elseif CurrentState == STATE_TRAVEL then

        -----------------------------------------------------------------
        -- Niet in de juiste stad -> teleporteren
        -----------------------------------------------------------------
        if not IsPlayerInArea(CurrentContract.townArea) then

            print("STATE_TRAVEL: Player is outside town, teleporting.")

            TeleportToTown(CurrentContract.location)

            API.RandomSleep2(5000, 1500, 1500)

        -----------------------------------------------------------------
        -- Al in het gebouw -> bouwen
        -----------------------------------------------------------------
        elseif IsPlayerInArea(CurrentContract.buildingArea) then

            print("STATE_TRAVEL: Building reached.")

            CurrentState = STATE_BUILD

            API.RandomSleep2(1000, 500, 500)

        -----------------------------------------------------------------
        -- Nog onderweg
        -----------------------------------------------------------------
        else

            -- Nog aan het lopen? Dan niets doen.
            if API.ReadPlayerMovin() then

                print("STATE_TRAVEL: Walking...")

                API.RandomSleep2(1000, 500, 500)

            else

                -- Eerst eventuele deur afhandelen
                print("Door: " .. tostring(CurrentContract.door and CurrentContract.door.name) .. " | Handled: " .. tostring(DoorHandled))

                if CurrentContract.door and not DoorHandled then

                    if IsDoorInNextWalk(CurrentContract.door) then

                        print("STATE_TRAVEL: Door within range.")

                        if HandleDoor(CurrentContract.door) then
                            DoorHandled = true
                        end

                    else

                        print("STATE_TRAVEL: Walking towards building.")

                        WalkToArea(CurrentContract.buildingArea)

                    end

                else

                    print("STATE_TRAVEL: Walking towards building.")

                    WalkToArea(CurrentContract.buildingArea)

                end

            end

        end

    elseif CurrentState == STATE_BUILD then

        print("STATE_BUILD: Zoeken naar reparaties.")

        local result = RepairFloor()

        if result == "success" then
            print("STATE_BUILD: Reparatie voltooid.")

    elseif result == "done" then

        local completed, total = GetCompletedTasks()

        print("STATE_BUILD: Geen reparaties meer gevonden.")
        print("Taken voltooid: " .. completed .. "/" .. total)

        if completed == total then

            print("STATE_BUILD: Contract voltooid.")
            CurrentState = STATE_RETURN_HOME

        else

        print("STATE_BUILD: Trap gebruiken.")

        local ok = HandleStairs()

        print("HandleStairs resultaat: " .. tostring(ok))

        if ok then
            print("STATE_BUILD: Nieuwe verdieping bereikt.")
        else
            StopReason = "Trap kon niet gebruikt worden."
            CurrentState = STATE_STOP
        end

    end

        elseif result == "bank" then
            CurrentState = STATE_BANK

        elseif result == "stop" then
            CurrentState = STATE_STOP

        else
            StopReason = "Onbekende build-uitkomst: " .. tostring(result)
            CurrentState = STATE_STOP
        end

elseif CurrentState == STATE_RETURN_HOME then

    if IsPlayerInArea(townAreas["Home"]) then

        print("Terug in Home.")
        CurrentState = STATE_HANDIN

    elseif TeleportHome() then

        CurrentState = STATE_HANDIN

    else

        StopReason = "Kon niet naar Home teleporteren."
        CurrentState = STATE_STOP

    end

    elseif CurrentState == STATE_HANDIN then
        if HandInContract() then
            CurrentState = STATE_BANK
        end

    elseif CurrentState == STATE_BANK then

        if Bank() then
            CurrentState = STATE_OPEN_INTERFACE
        end



    
    
    elseif CurrentState == STATE_STOP then

        local player = API.PlayerCoord()

        print("===================================")
        print("Construction bot gestopt.")
        print("===================================")
        print("Contract : " .. tostring(CurrentContract.location))
        print("NPC      : " .. tostring(CurrentContract.npc))
        print("Player   : " .. tostring(player.x) .. ", "
            .. tostring(player.y) .. ", floor " .. tostring(player.z))

        if CurrentContract.repairTarget then
            local target = CurrentContract.repairTarget

            print("Doelobject: " .. tostring(target.name)
                .. " | ID: " .. tostring(target.id))

            print("Objectlocatie: " .. tostring(target.x)
                .. ", " .. tostring(target.y)
                .. ", floor " .. tostring(target.floor))

            print(string.format("Afstand bij selectie: %.2f", target.distance))
        else
            print("Doelobject: geen")
        end

        print("Repair attempts : " .. tostring(RepairAttempts))
        print("Reden           : " .. tostring(StopReason))
        print("===================================")

        API.Write_LoopyLoop(false)
    end
    API.RandomSleep2(800, 400, 400)

end

function M.Start(config)
    Config = config
    running = true
    paused = false
    CurrentState = STATE_START

end

function M.Pause()

    paused = true

end

function M.Resume()

    paused = false

end

function M.Stop(reason)

    running = false
    paused = false
    StopReason = reason or ""

end

function M.IsRunning()

    return running

end

function M.IsPaused()

    return paused

end

return M