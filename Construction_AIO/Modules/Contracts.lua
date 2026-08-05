
local API = require("api")
local Data = require("Data.Data")
local Functions = require("Data.Functions")
local Config = require("Config")

local M = {}

local running = false
local paused = false

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
local ContractStats = {
    startedAt = nil,
    contractsDone = 0,
    creditsEarned = 0
}

----------------------------------------------------
-- CACHE
----------------------------------------------------
local StopReason = ""
local DoorHandled = false
local AwaitingCompletionUpdate = false
local CurrentContract = {
    location = nil,
    npc = nil,
    townArea = nil,
    buildingArea = nil,
    repairTarget = nil,
    door = nil,
    accessDoors = nil,
    accessRoute = nil,
    accessDoorsHandled = {},
    routeRepairIndex = 1,
    stairAttemptsWithoutRepair = 0,
    entrance = nil,
    repairPriorities = nil,
    repairPhase = nil,
    repairDeadline = nil,
    repairHardDeadline = nil,
    repairNextAt = nil,
    walkTargetAttempts = 0,
    walkTargetLastAttemptAt = nil,
    missingBuildMaterials = nil,
    exteriorRepairRule = nil,
    exteriorRepairPending = false,
    masterTeleportExteriorCheckPending = false,
    masterTeleportExteriorCheckAt = nil,
}

----------------------------------------------------
-- CONSTANTS
----------------------------------------------------
local inter_location = Data.Interfaces.Location
local inter_npc      = Data.Interfaces.NPC
local TASK_ROUTES    = Data.Interfaces.TaskRoutes
local NPCs           = Data.NPCs
local Objects        = Data.Objects
local Items          = Data.Items
local HOTSPOTS       = Data.HOTSPOTS
local townAreas      = Data.TownAreas
local buildingAreas  = Data.BuildingAreas
local DOORS          = Data.DOORS
local ACCESS_DOORS   = Data.ACCESS_DOORS
local ACCESS_ROUTES  = Data.ACCESS_ROUTES
local REPAIR_PRIORITIES = Data.REPAIR_PRIORITIES
local EXTERIOR_REPAIR_RULES = Data.EXTERIOR_REPAIR_RULES
local STAIRS         = Data.STAIRS
local ENTRANCES      = Data.ENTRANCES

local WALK_TARGET_RADIUS = 5
local WALK_TARGET_CANDIDATES = 20
local WALK_TARGET_MAX_ATTEMPTS = 2
local WALK_TARGET_RETRY_DELAY = 1.25

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
                --API.logDebug("Contract valid! Location: " .. foundLocation .. " | Contractee: " .. foundNPC .. " -> Area: Linksonder("..area.x1..","..area.y1..") Rechtsboven("..area.x2..","..area.y2..")")
                return true, foundLocation, foundNPC, area
            end
        end
    end
    
    return false, nil, nil, nil
end
-- Helper function to count completed tasks
local function GetCompletedTasks()

    local completed = 0
    local total = #TASK_ROUTES
    local states = {}

    for i, route in ipairs(TASK_ROUTES) do

        local scan = API.ScanForInterfaceTest2Get(false, route)

        if scan and scan[1] then

            local sprite = API.Mem_Read_int(scan[1].memloc + API.I_slides)

            states[i] = sprite

            if sprite == Data.Interfaces.CompleteSprite then
                completed = completed + 1
            end

        else
            states[i] = nil
        end

    end

    return completed, total, states

end

-- Keep longer waits interruptible for the GUI controls.
local function WaitForControl(seconds)
    local deadline = os.clock() + seconds

    while os.clock() < deadline do
        if Functions.HasPendingRequest() then
            return false
        end

        local remaining = math.max(0.05, deadline - os.clock())
        local delay = math.max(50, math.min(100, math.floor(remaining * 1000)))
        API.RandomSleep2(delay, 50, 50)
    end

    return not Functions.HasPendingRequest()
end

local function WaitForCompletionUpdate(timeout)

    local endTime = os.clock() + (timeout or 6)
    local completed, total = GetCompletedTasks()

    while completed < total and os.clock() < endTime do
        if Functions.HasPendingRequest() then
            return completed, total
        end
        API.logDebug("Waiting for contract update: " .. completed .. "/" .. total)
        if not WaitForControl(0.5) then
            return completed, total
        end
        completed, total = GetCompletedTasks()
    end

    return completed, total

end

local function IsPlayerInArea(area)

    local pos = API.PlayerCoord()

    API.logDebug("PlayerCoord: " .. pos.x .. "," .. pos.y .. "," .. pos.z)
    API.logDebug("Area: " .. area.x1 .. "," .. area.y1 .. " -> " .. area.x2 .. "," .. area.y2)

    if not pos or not area then
        return false
    end

    return pos.x >= area.x1
       and pos.x <= area.x2
       and pos.y >= area.y1
       and pos.y <= area.y2

end

local function GetRandomPointInArea(area, inset)

    inset = inset or 0

    local centerX = math.floor((area.x1 + area.x2) / 2)
    local centerY = math.floor((area.y1 + area.y2) / 2)
    local minX = math.max(area.x1 + inset, centerX - WALK_TARGET_RADIUS)
    local maxX = math.min(area.x2 - inset, centerX + WALK_TARGET_RADIUS)
    local minY = math.max(area.y1 + inset, centerY - WALK_TARGET_RADIUS)
    local maxY = math.min(area.y2 - inset, centerY + WALK_TARGET_RADIUS)

    for _ = 1, WALK_TARGET_CANDIDATES do
        local x = math.random(minX, maxX)
        local y = math.random(minY, maxY)
        local tile = WPOINT.new(x, y, 0)

        if not API.CheckTileforObjects1(tile) then
            API.logDebug(string.format(
                "Walk target selected: (%d,%d) around area centre (%d,%d).",
                x,
                y,
                centerX,
                centerY
            ))

            return { x = x, y = y, z = 0 }
        end
    end

    API.logWarn(string.format(
        "Walk target: no object-free tile found around (%d,%d); using centre.",
        centerX,
        centerY
    ))

    return {
        x = centerX,
        y = centerY,
        z = 0
    }

end

local function GetRandomEntrancePoint(entrance)

    local point = entrance.outside[math.random(1, #entrance.outside)]

    return { x = point.x, y = point.y, z = point.floor }

end

local function IsPlayerNearPoint(point, radius)

    local player = API.PlayerCoord()
    local dx = player.x - point.x
    local dy = player.y - point.y

    return player.z == point.z and math.sqrt(dx * dx + dy * dy) <= (radius or 1)

end

local function IsPlayerNearDoor(door, radius)

    local player = API.PlayerCoord()

    for _, closedDoor in ipairs(door.closed or {}) do
        if closedDoor.floor == player.z then
            local dx = player.x - closedDoor.x
            local dy = player.y - closedDoor.y

            if math.sqrt(dx * dx + dy * dy) <= radius then
                return true
            end
        end
    end

    return false

end

local function IsPlayerMoving()
    local animation = API.ReadPlayerAnim() or 0
    return API.ReadPlayerMovin() or animation > 0
end

local function WalkToPoint(x, y, z)

    API.logDebug(string.format( "WalkToPoint: Clicking (%d, %d, %d).", x, y, z ))

    API.DoAction_Tile(WPOINT.new(x, y, z))

    return true

end

local function IsDoorInNextWalk(door)

    local pos = API.PlayerCoord()

    local dx = CurrentContract.walkTarget.x - pos.x
    local dy = CurrentContract.walkTarget.y - pos.y

    local distance = math.sqrt(dx * dx + dy * dy)

    local step = 30        -- maximum WalkToArea() step size

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

local function WalkToArea(area, allowTravelAbility, ignoreAreaReached)

    if not ignoreAreaReached and IsPlayerInArea(area) then
        API.logInfo("WalkToArea: Player is already in the building area.")
        return true
    end

    local pos = API.PlayerCoord()

    --API.logDebug(string.format( "WalkToArea: From (%d,%d) to (%d,%d)", pos.x, pos.y, CurrentContract.walkTarget.x, CurrentContract.walkTarget.y ))

    local dx = CurrentContract.walkTarget.x - pos.x
    local dy = CurrentContract.walkTarget.y - pos.y

    local distance = math.sqrt(dx * dx + dy * dy)
    local step = math.random(25, 30)

    --[[if distance > step then

        local nx = dx / distance
        local ny = dy / distance

        local walkX = math.floor(pos.x + nx * step)
        local walkY = math.floor(pos.y + ny * step)

        API.logDebug(string.format( "WalkToArea: Distance %.1f | Step %d | Midpoint (%d,%d)", distance, step, walkX, walkY ))

        if allowTravelAbility
            and Config.ContractsUseTravelAbilities ~= false
            and Functions.TryTravelMovementAbility({ x = walkX, y = walkY, z = pos.z }) then
            return false
        end

        WalkToPoint(walkX, walkY, pos.z )

    else]]
    
    if distance > step then

        local nx = dx / distance
        local ny = dy / distance

        -- Eerst het normale tussenpunt richting het doel berekenen
        local walkX = pos.x + nx * step
        local walkY = pos.y + ny * step

        -- Willekeurige afwijking links/rechts van de rechte route
        local offset = math.random(-5, 5)

        -- Vector loodrecht op de looprichting
        local px = -ny
        local py = nx

        walkX = math.floor(walkX + px * offset)
        walkY = math.floor(walkY + py * offset)

        API.logDebug(string.format(
            "WalkToArea: Distance %.1f | Step %d | Offset %d | Midpoint (%d,%d)",
            distance,
            step,
            offset,
            walkX,
            walkY
        ))

        if allowTravelAbility
            and Config.ContractsUseTravelAbilities ~= false
            and Functions.TryTravelMovementAbility({
                x = walkX,
                y = walkY,
                z = pos.z
            }) then
            return false
        end

        WalkToPoint(walkX, walkY, pos.z)

    else

        API.logDebug(string.format( "WalkToArea: Distance %.1f | Step %d | Endpoint (%d,%d)", distance, step, CurrentContract.walkTarget.x, CurrentContract.walkTarget.y ))

        if allowTravelAbility
            and Config.ContractsUseTravelAbilities ~= false
            and Functions.TryTravelMovementAbility(CurrentContract.walkTarget) then
            return false
        end

        local now = os.clock()

        if CurrentContract.walkTargetLastAttemptAt
            and now - CurrentContract.walkTargetLastAttemptAt < WALK_TARGET_RETRY_DELAY then
            return false
        end

        if CurrentContract.walkTargetAttempts >= WALK_TARGET_MAX_ATTEMPTS then
            local oldTarget = CurrentContract.walkTarget

            CurrentContract.walkTarget = GetRandomPointInArea(area)
            CurrentContract.walkTargetAttempts = 0
            CurrentContract.walkTargetLastAttemptAt = nil

            API.logWarn(string.format(
                "Walk target unreachable after %d attempts: (%d,%d) -> new target (%d,%d).",
                WALK_TARGET_MAX_ATTEMPTS,
                oldTarget.x,
                oldTarget.y,
                CurrentContract.walkTarget.x,
                CurrentContract.walkTarget.y
            ))

            return false
        end

        CurrentContract.walkTargetAttempts = CurrentContract.walkTargetAttempts + 1
        CurrentContract.walkTargetLastAttemptAt = now

        API.logDebug(string.format(
            "Walk target attempt %d/%d.",
            CurrentContract.walkTargetAttempts,
            WALK_TARGET_MAX_ATTEMPTS
        ))

        WalkToPoint( CurrentContract.walkTarget.x, CurrentContract.walkTarget.y, pos.z )

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

    API.logInfo("Open LodestoneInterface: Opening interface.")

    API.DoAction_Interface( 0xffffffff, 0xffffffff, 1, 1465, 33, -1, API.OFF_ACT_GeneralInterface_route )

    local timeout = os.clock() + 5

    while os.clock() < timeout do

        if API.Compare2874Status(30, false) then
            API.logInfo("OpenLodestoneInterface: Interface opened.")
            return true
        end

        if not WaitForControl(0.75) then
            return false
        end

    end

    API.logError("OpenLodestoneInterface: Timeout.")
    return false

end

local function ClickLodestone(location)

    local id = Data.Lodestones[location]

    if not id then
        API.logError("ClickLodestone: Unknown location: "..tostring(location))
        return false
    end

    API.logInfo("ClickLodestone: "..location)

    API.DoAction_Interface( 0xffffffff, 0xffffffff, 1, 1092, id, -1, API.OFF_ACT_GeneralInterface_route )

    return true

end

local function WaitForTeleport(area)

    API.logInfo("WaitForTeleport: Waiting for teleport.")

    local timeout = os.clock() + 15

    while os.clock() < timeout do

        if IsPlayerInArea(area) then

            API.logInfo("WaitForTeleport: Area reached.")

            -- Give the RS3 client time to load everything.
            if not WaitForControl(2.5) then
                return false
            end

            API.logInfo("WaitForTeleport: Teleport complete.")
            return true

        end

        if not WaitForControl(1) then
            return false
        end

    end

    API.logError("WaitForTeleport: Timeout.")
    return false

end

local MASTER_CONSTRUCTOR_MENU = Data.Interfaces.MASTER_CONSTRUCTOR_MENU

local function HasFullMasterConstructorOutfit()

    return API.EquipSlotEq1(0, 51017)
       and API.EquipSlotEq1(4, 51018)
       and API.EquipSlotEq1(7, 51020)
       and API.EquipSlotEq1(6, 51019)
       and API.EquipSlotEq1(8, 51021)

end

local function IsMasterConstructorMenuOpen()

    local result = API.ScanForInterfaceTest2Get(
        false,
        MASTER_CONSTRUCTOR_MENU
    )

    if not result or #result == 0 then
        return false
    end

    local text = tostring(result[1].textids or "")

    return text:find("Select an option", 1, true) ~= nil

end

local function WaitForMasterConstructorMenu(seconds)

    local deadline = os.clock() + seconds

    while os.clock() < deadline do
        if IsMasterConstructorMenuOpen() then
            return true
        end

        if Functions.HasPendingRequest() then
            return false
        end

        API.RandomSleep2(50, 25, 25)
    end

    return IsMasterConstructorMenuOpen()

end

local function WaitForMasterConstructorMenuToClose(seconds)

    local deadline = os.clock() + seconds

    while os.clock() < deadline do
        if not IsMasterConstructorMenuOpen() then
            return true
        end

        if Functions.HasPendingRequest() then
            return false
        end

        API.RandomSleep2(50, 25, 25)
    end

    return not IsMasterConstructorMenuOpen()

end

local function OpenMasterConstructorTeleportMenu()

    if not HasFullMasterConstructorOutfit() then
        API.logDebug("Full Master constructor's outfit is not equipped.")
        return false
    end

    local ability = API.GetABs_name1("Master constructor's hat")

    if not ability then
        API.logDebug("Master constructor's hat is not available on the ability bar.")
        return false
    end

    API.logInfo("Opening Master constructor teleport menu.")

    local activated = API.DoAction_Ability_Direct(
        ability,
        1,
        API.OFF_ACT_GeneralInterface_route
    )

    if activated == false then
        API.logWarn("Master constructor's hat ability could not be activated.")
        return false
    end

    if not WaitForMasterConstructorMenu(3) then
        API.logWarn("Master constructor teleport menu did not open.")
        return false
    end

    return true

end

local function TryMasterConstructorContractTeleport(area)

    if not area then
        API.logWarn("No building area available for the contract teleport.")
        return false
    end

    if not OpenMasterConstructorTeleportMenu() then
        return false
    end

    API.logInfo("Selecting Master constructor teleport: Construction contract.")

    -- Option 2: Construction contract.
    API.KeyboardPress2(0x32, 60, 100)

    if not WaitForMasterConstructorMenuToClose(2) then
        API.logWarn("Construction contract option was not processed.")
        return false
    end

    return WaitForTeleport(area)

end

local function TryMasterConstructorEstateAgentTeleport(area)

    if not area then
        API.logWarn("No Home area available for the estate agent teleport.")
        return false
    end

    if not OpenMasterConstructorTeleportMenu() then
        return false
    end

    API.logInfo("Selecting Master constructor teleport: Estate agents.")

    -- Option 4: Estate agents.
    API.KeyboardPress2(0x34, 60, 100)

    -- Estate agents replaces the choices in the same menu instead of
    -- closing it. Wait for the destination choices before selecting one.
    if not WaitForControl(0.8) then
        return false
    end

    if not WaitForMasterConstructorMenu(3) then
        API.logWarn("Estate agent destination menu did not open.")
        return false
    end

    API.logInfo("Selecting estate agent: Rimmington.")

    -- Option 1: Rimmington estate agent.
    API.KeyboardPress2(0x31, 60, 100)

    if not WaitForMasterConstructorMenuToClose(2) then
        API.logWarn("Rimmington estate agent option was not processed.")
        return false
    end

    return WaitForTeleport(area)

end

local function IsPointInsideBuildingArea(x, y, area)

    return area
        and x >= area.x1
        and x <= area.x2
        and y >= area.y1
        and y <= area.y2

end

local function FindExteriorRepairObject()

    local rule = CurrentContract.exteriorRepairRule
    if not rule or not CurrentContract.buildingArea then
        return nil
    end

    local objects = API.FindObject_string({ rule.hotspot }, 30)
    if not objects then
        return nil
    end

    for _, obj in ipairs(objects) do
        local x = math.floor(obj.TileX / 512)
        local y = math.floor(obj.TileY / 512)

        if obj.Name == rule.hotspot
        and obj.Floor == rule.floor
        and not IsPointInsideBuildingArea(x, y, CurrentContract.buildingArea) then
            return obj
        end
    end

    return nil

end

local function TeleportToTown(location)

    API.logInfo("TeleportToTown: "..location)

    -- The outfit teleport goes directly to the active contract's build area.
    if TryMasterConstructorContractTeleport(CurrentContract.buildingArea) then
        -- Wait briefly for nearby exterior repair hotspots to load before
        -- deciding whether the front door can be skipped.
        DoorHandled = true
        CurrentContract.masterTeleportExteriorCheckPending = true
        CurrentContract.masterTeleportExteriorCheckAt = os.clock() + 0.8
        return true
    end

    API.logInfo("Falling back to lodestone teleport.")

    if not OpenLodestoneInterface() then
        return false
    end

    if not WaitForControl(1) then
        return false
    end

    if not ClickLodestone(location) then
        return false
    end

    return WaitForTeleport(townAreas[location])

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

    API.logDebug("Checking door: " .. door.name)

    -- Is the door already open?
    if IsDoorOpen(door) then
        API.logDebug(door.name .. ": door is already open.")
        if not WaitForControl(0.3) then
            return false
        end
        return true
    end

    local objects = API.FindObject_string({door.object_name}, 50)

    if not objects or #objects == 0 then
        API.logError("No door found: " .. door.name)
        return false
    end

    -- Find closed door
    for _, obj in ipairs(objects) do
        for _, closedDoor in ipairs(door.closed) do

            if obj.Id == closedDoor.id
            and math.floor(obj.TileX / 512) == closedDoor.x
            and math.floor(obj.TileY / 512) == closedDoor.y
            and obj.Floor == closedDoor.floor then

                API.logDebug(door.name .. ": closed door found.")

                local p = API.PlayerCoord()
                API.logDebug("Player: " .. p.x .. "," .. p.y .. "," .. p.z)
                API.logDebug("Clicking door: " .. closedDoor.id)

                API.DoAction_Object2( 0x31, API.OFF_ACT_GeneralObject_route0, { closedDoor.id }, 50, WPOINT.new( closedDoor.x, closedDoor.y, closedDoor.floor ) )

                -- Allow enough time to walk to and open the door.
                if not WaitForControl(4) then
                    return false
                end

                -- Check again
                if IsDoorOpen(door) then
                    API.logDebug(door.name .. ": door opened successfully.")
                    if not WaitForControl(0.4) then
                        return false
                    end
                    return true
                end

                API.logDebug(door.name .. ": door is not open yet.")
                return false

            end
        end
    end

    API.logError(door.name .. ": no matching door status found.")
    return false

end

local function HandleStairs()

    API.logDebug("=== HandleStairs started ===")

    if not CurrentContract.stairs then
        API.logError("No stair data available.")
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

    API.logDebug("Stairs: " .. stair.action)

    API.logDebug("Clicking stairs: " .. stair.id)

    API.DoAction_Object2(
        0x34,
        API.OFF_ACT_GeneralObject_route0,
        { stair.id },
        50,
        WPOINT.new(stair.x, stair.y, stair.floor)
    )

    local startDeadline = os.clock() + 8
    local hardDeadline = os.clock() + 20
    local movementStarted = false
    local lastMovingAt = nil

    while os.clock() < hardDeadline do
        if API.PlayerCoord().z == targetFloor then
            API.logDebug("Stairs used successfully.")
            return true
        end

        if IsPlayerMoving() then
            if not movementStarted then
                movementStarted = true
                API.logDebug("Stairs: player is moving.")
            end
            lastMovingAt = os.clock()

        elseif not movementStarted and os.clock() >= startDeadline then
            break

        elseif movementStarted
        and lastMovingAt
        and os.clock() - lastMovingAt >= 3 then
            break
        end

        if not WaitForControl(0.2) then
            return false
        end
    end

    API.logError("Floor did not change.")
    return false

end

local function ReadContractChat()
    local chats = API.GatherEvents_chat_check()
    local result = nil

    if chats then
        for _, v in ipairs(chats) do
            local text = tostring(v.text or "")

            if text ~= "" then

                local credits = text:match("You gain (%d+) contract credits%.")
                if credits then
                    ContractStats.creditsEarned = ContractStats.creditsEarned + tonumber(credits)
                    API.logInfo("Contract credits earned: " .. credits)
                end

                if string.find(text, "do not have the materials") then
                    API.logError("Build error: insufficient materials.")
                    result = result or "NO_MATERIALS"

                elseif string.find(text, "Contract completed%. Speak to the estate agent to get a new one%.") then
                    API.logDebug("Contract completed via chat message.")
                    result = result or "CONTRACT_COMPLETED"

                elseif string.find(text, "You do not currently have a construction contract.") then
                    API.logError("Contract error: no active contract.")
                    result = result or "NO_CONTRACT"

                end
            end
        end
    end

    return result
end

local function HasError()
    return ReadContractChat()
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

local function IsPriorityRepairObject(obj)

    if not CurrentContract.repairPriorities then
        return false
    end

    for _, priority in ipairs(CurrentContract.repairPriorities) do
        if obj.Id == priority.id
        and math.floor(obj.TileX / 512) == priority.x
        and math.floor(obj.TileY / 512) == priority.y
        and obj.Floor == priority.floor then
            return true
        end
    end

    return nil

end

local function FindPriorityRepairObject()

    if not CurrentContract.repairPriorities then
        return nil
    end

    local playerFloor = API.PlayerCoord().z
    local objects = API.FindObject_string(HOTSPOTS, 30)
    if not objects then
        return nil
    end

    for _, obj in ipairs(objects) do
        if obj.Floor == playerFloor and IsPriorityRepairObject(obj) then
            API.logDebug("Priority repair object: " .. obj.Name)
            return obj
        end
    end

    return nil

end

local function GetRepairPriorities(location, npc)

    for _, rule in ipairs(REPAIR_PRIORITIES or {}) do
        if rule.location == location and rule.npc == npc then
            return rule.hotspots
        end
    end

    return nil

end

local function GetRoomAtPosition(route, position)

    for _, roomName in ipairs(route.roomOrder) do
        local areas = route.rooms[roomName]

        for _, area in ipairs(areas) do
            if position.z == area.floor
            and position.x >= area.x1
            and position.x <= area.x2
            and position.y >= area.y1
            and position.y <= area.y2 then
                return roomName
            end
        end
    end

    return nil

end

local function FindClosestRepairObjectInRoom(route, roomName)

    local playerFloor = API.PlayerCoord().z
    local objects = API.FindObject_string(HOTSPOTS, 30)
    local closest = nil

    if not objects then
        return nil
    end

    for _, obj in ipairs(objects) do
        local position = {
            x = math.floor(obj.TileX / 512),
            y = math.floor(obj.TileY / 512),
            z = obj.Floor
        }

        if obj.Floor == playerFloor
        and GetRoomAtPosition(route, position) == roomName
        and (not closest or obj.Distance < closest.Distance) then
            closest = obj
        end
    end

    return closest

end

local function FindNextRouteRepairObject()

    local route = CurrentContract.accessRoute
    if not route or not route.repairOrder then
        return FindClosestRepairObject()
    end

    local playerRoom = GetRoomAtPosition(route, API.PlayerCoord())

    -- The bartender route only describes rooms on floor 1.
    -- Scan the ground floor normally without applying the upstairs room order.
    if not playerRoom then
        return FindClosestRepairObject()
    end

    if playerRoom == "hall" then
        local hallRepair = FindClosestRepairObjectInRoom(route, "hall")
        if hallRepair then
            return hallRepair
        end
    end

    while CurrentContract.routeRepairIndex <= #route.repairOrder do
        local roomName = route.repairOrder[CurrentContract.routeRepairIndex]
        local repair = FindClosestRepairObjectInRoom(route, roomName)

        if repair then
            API.logDebug("Bartender route room: " .. roomName)
            return repair
        end

        API.logDebug("Bartender route room complete: " .. roomName)
        CurrentContract.routeRepairIndex = CurrentContract.routeRepairIndex + 1
    end

    return nil

end

local function GetDoorPath(route, startRoom, targetRoom)

    local queue = { startRoom }
    local visited = { [startRoom] = true }
    local previous = {}
    local head = 1

    while queue[head] do
        local room = queue[head]
        head = head + 1

        if room == targetRoom then
            break
        end

        for _, door in ipairs(route.doors) do
            local nextRoom = nil

            if door.from == room then
                nextRoom = door.to
            elseif door.to == room then
                nextRoom = door.from
            end

            if nextRoom and not visited[nextRoom] then
                visited[nextRoom] = true
                previous[nextRoom] = { room = room, door = door }
                table.insert(queue, nextRoom)
            end
        end
    end

    if not visited[targetRoom] then
        return nil
    end

    local path = {}
    local room = targetRoom

    while room ~= startRoom do
        local step = previous[room]
        table.insert(path, 1, step.door)
        room = step.room
    end

    return path

end

local function WaitForRouteMovement(timeout)

    local endTime = os.clock() + (timeout or 10)
    local movementStarted = false
    local startDeadline = os.clock() + 2

    while os.clock() < endTime do
        if IsPlayerMoving() then
            movementStarted = true
        elseif movementStarted or os.clock() >= startDeadline then
            return true
        end

        API.RandomSleep2(200, 100, 100)
    end

    return not IsPlayerMoving()

end

local function IsRouteDoorOpen(door)

    local objects = API.FindObject_string({ "Door" }, 50)

    if not objects then
        return false
    end

    for _, obj in ipairs(objects) do
        if obj.Id == door.open.id
        and math.floor(obj.TileX / 512) == door.open.x
        and math.floor(obj.TileY / 512) == door.open.y then
            return true
        end
    end

    return false

end

local function OpenRouteDoorBeforeRepair(obj)

    local route = CurrentContract.accessRoute
    if not route then
        return false
    end

    local player = API.PlayerCoord()
    local target = {
        x = math.floor(obj.TileX / 512),
        y = math.floor(obj.TileY / 512),
        z = obj.Floor
    }
    local startRoom = GetRoomAtPosition(route, player)
    local targetRoom = GetRoomAtPosition(route, target)

    if not startRoom or not targetRoom or startRoom == targetRoom then
        return false
    end

    local path = GetDoorPath(route, startRoom, targetRoom)
    if not path then
        API.logError("No door route found: " .. startRoom .. " -> " .. targetRoom)
        return false
    end

    for _, door in ipairs(path) do
        if not IsRouteDoorOpen(door) then
            API.logDebug(string.format(
                "Door route: %s -> %s | opening door %d at (%d,%d,%d)",
                startRoom, targetRoom, door.closed.id, door.closed.x, door.closed.y, door.closed.floor
            ))

            API.DoAction_Object2(
                door.action,
                API.OFF_ACT_GeneralObject_route0,
                { door.closed.id },
                50,
                WPOINT.new(door.closed.x, door.closed.y, door.closed.floor)
            )

            WaitForRouteMovement(10)
            return true
        end
    end

    return false

end

local function OpenAccessDoorBeforeRepair(obj, forceBeforeStairs)

    if not CurrentContract.accessDoors then
        return false
    end

    local player = API.PlayerCoord()

    -- A nearby hotspot is already directly reachable. Opening a door first
    -- could place it directly in the route to that hotspot.
    if not forceBeforeStairs
    and obj.Floor == player.z
    and obj.Distance <= 2 then
        API.logDebug("Skipping access door: repair object is already reachable.")
        return false
    end

    for _, door in ipairs(CurrentContract.accessDoors) do

        local doorKey = string.format("%d:%d:%d:%d", door.id, door.x, door.y, door.floor)

        if not CurrentContract.accessDoorsHandled[doorKey]
        and player.z == door.floor then

            local closedDoorFound = false
            local objects = API.FindObject_string({ "Door" }, 50)

            if objects then
                for _, object in ipairs(objects) do
                    if object.Id == door.id
                    and math.floor(object.TileX / 512) == door.x
                    and math.floor(object.TileY / 512) == door.y
                    and object.Floor == door.floor then
                        closedDoorFound = true
                        break
                    end
                end
            end

            if not closedDoorFound then
                CurrentContract.accessDoorsHandled[doorKey] = true
                return false
            end

            API.logDebug(string.format(
                forceBeforeStairs
                    and "Opening stair access door first: %d at (%d,%d,%d)"
                    or "Opening access door first: %d at (%d,%d,%d)",
                door.id, door.x, door.y, door.floor
            ))

            API.DoAction_Object2(
                door.action,
                API.OFF_ACT_GeneralObject_route0,
                { door.id },
                50,
                WPOINT.new(door.x, door.y, door.floor)
            )

            CurrentContract.accessDoorsHandled[doorKey] = true
            API.RandomSleep2(1200, 500, 500)
            return true

        end

    end

    return false

end

local function RepairFloor()

    local now = os.clock()

    if CurrentContract.repairPhase == "wait_for_stop" then
        if not API.ReadPlayerMovin() then
            CurrentContract.repairPhase = "wait_interface_delay"
        CurrentContract.repairNextAt = now + 0.8
        elseif now > CurrentContract.repairDeadline then
            StopReason = "Build object could not be reached."
            CurrentContract.repairPhase = nil
            return "stop"
        end
        return "pending"
    end

    if CurrentContract.repairPhase == "wait_interface_delay" then
        if now >= CurrentContract.repairNextAt then
            CurrentContract.repairPhase = "wait_interface"
            CurrentContract.repairDeadline = now + 5-- was 10
        end
        return "pending"
    end

    if CurrentContract.repairPhase == "wait_interface" then
        if API.GetInterfaceOpenBySize(1306) then
            API.logInfo("Build interface opened.")
            CurrentContract.repairPhase = "select_build"
            CurrentContract.repairNextAt = now + 0.5
        elseif now > CurrentContract.repairDeadline then
            StopReason = "Build interface did not open."
            CurrentContract.repairPhase = nil
            return "stop"
        end
        return "pending"
    end

    if CurrentContract.repairPhase == "select_build" then
        if now < CurrentContract.repairNextAt then
            return "pending"
        end

        local selectedBuild, missingBuildMaterials = Functions.HandleBuildInterface()
        if not selectedBuild then
            CurrentContract.missingBuildMaterials = missingBuildMaterials
            CurrentContract.repairPhase = nil
            return "bank"
        end

        API.logInfo("Repair started.")
        CurrentContract.repairPhase = "wait_repair"
        CurrentContract.repairDeadline = now + 20
        CurrentContract.repairHardDeadline = now + 45
        CurrentContract.repairNextAt = now + 0.6
        return "pending"
    end

    if CurrentContract.repairPhase == "wait_repair" then
        if now >= CurrentContract.repairNextAt and not RepairObjectStillExists() then
            API.logInfo("Repair finished.")

            if CurrentContract.repairTarget
            and CurrentContract.repairTarget.isExteriorPriority then
                CurrentContract.exteriorRepairPending = false
                API.logInfo("Exterior Bench space complete; continuing the normal contract route.")
            end

            CurrentContract.repairTarget = nil
            CurrentContract.repairPhase = nil
            CurrentContract.repairHardDeadline = nil
            return "success"
        elseif now > CurrentContract.repairDeadline
            or now > CurrentContract.repairHardDeadline then
            CurrentContract.repairPhase = nil
            CurrentContract.repairHardDeadline = nil
            if HasError() == "NO_MATERIALS" then
                return "bank"
            end
            StopReason = "Repair did not complete after the selected build option."
            return "stop"
        end
        return "pending"
    end

    local exteriorPriority = nil
    if CurrentContract.exteriorRepairPending then
        exteriorPriority = FindExteriorRepairObject()
    end

    local obj = exteriorPriority or FindPriorityRepairObject() or FindNextRouteRepairObject()

    if not obj then
        API.logInfo("No repair object found on this floor.")
        return "done"
    end

    if OpenRouteDoorBeforeRepair(obj)
        or (not IsPriorityRepairObject(obj) and OpenAccessDoorBeforeRepair(obj)) then
        return "access"
    end

    CurrentContract.repairTarget = {
        name = obj.Name,
        id = obj.Id,
        distance = obj.Distance,
        floor = obj.Floor,
        x = math.floor(obj.TileX / 512),
        y = math.floor(obj.TileY / 512),
        isExteriorPriority = exteriorPriority ~= nil
    }

    API.logDebug(string.format(
        "Repair object: %s | distance: %.2f | floor: %d",
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
    CurrentContract.repairPhase = "wait_for_stop"
    CurrentContract.repairDeadline = now + 15
    return "pending"

end

local function TeleportHome()

    local homeArea = townAreas["Home"]

    if TryMasterConstructorEstateAgentTeleport(homeArea) then
        return true
    end

    API.logInfo("Falling back to House Teleport.")

    API.DoAction_Ability_Direct(
        API.GetABs_name1("House Teleport"),
        1,
        API.OFF_ACT_GeneralInterface_route
    )

    return WaitForTeleport(homeArea)

end

local function HandInContract()

    local npc = API.FindNPCbyName("Estate agent", 15)

    API.logDebug("NPC object: " .. tostring(npc))

    if not npc then
        API.logError("Estate agent not found.")
        return false
    end

    API.logInfo("Talking to Estate agent.")

    API.DoAction_NPC( 0x29, API.OFF_ACT_InteractNPC_route3, { NPCs.Estate_agent }, 50 )
    if not WaitForControl(2.5) then
        return false
    end

    local timeout = os.clock() + 5

    while os.clock() < timeout do

        if Functions.HasPendingRequest() then
            return false
        end

        if API.DoDialog_Option("I want a new contract.") then
            API.logInfo("New contract requested.")
            if not WaitForControl(4) then
                return false
            end
            ReadContractChat()
            return true
        end
        if not WaitForControl(1.2) then
            return false
        end
    end

    if Functions.HasPendingRequest() then
        return false
    end

    API.logError("No contract option found. Stopping script.")
    StopReason = "No contract option found."
    CurrentState = STATE_STOP
    return false
end

local function LoadLastPreset()
    API.logInfo("Load last preset.")
    API.DoAction_Object1(0x33, API.OFF_ACT_GeneralObject_route3, {Objects.Bank}, 50)
    API.logInfo("Waiting for preset and inventory to load.")

    if not WaitForControl(4.0) then
        return false
    end

    if API.GetInterfaceOpenBySize(759) and not Functions.HandleBankPin(Config) then
        StopReason = "Bank PIN handling failed."
        CurrentState = STATE_STOP
        return false
    end

    return true
end

local function Bank()

    if not IsPlayerInArea(townAreas["Home"]) then
        API.logInfo("STATE_BANK: Not at Home; teleporting to Home first.")

        if not TeleportHome() then
            StopReason = "Could not teleport to Home for banking."
            CurrentState = STATE_STOP
            return false
        end
    end

    if not IsPlayerInArea(townAreas["Home"]) then
        StopReason = "Bank action cancelled: player is not at Home."
        CurrentState = STATE_STOP
        return false
    end

    API.logInfo("STATE_BANK: Home reached; processing preset and bank.")

    if not LoadLastPreset() then
        return false
    end

    local plankBoxAmount = Functions.GetRealItemAmount("Plank box")

    if plankBoxAmount == 0 then
        API.logWarn("No Plank box found.")
    else
        API.logInfo("Plank box found: " .. plankBoxAmount)

        API.DoAction_Object1(0x33, API.OFF_ACT_GeneralObject_route1, {Objects.Bank}, 50)

        local timeout = os.clock() + 5

        while os.clock() < timeout do

            if Functions.HasPendingRequest() then
                return false
            end

            if API.BankOpen2() then
                API.logInfo("Bank opened.")
                break
            end

            if API.GetInterfaceOpenBySize(759) then
                if not Functions.HandleBankPin(Config) then
                    StopReason = "Bank PIN handling failed."
                    CurrentState = STATE_STOP
                    return false
                end

                timeout = os.clock() + 5
            end

            if not WaitForControl(0.2) then
                return false
            end

        end

        if Functions.HasPendingRequest() then
            return false
        end

        if not API.BankOpen2() then

            API.logError("Bank could not be opened.")

            StopReason = "Bank could not be opened."
            CurrentState = STATE_STOP

            return false

        end

        API.logInfo("Filling Plank box.")

        API.DoAction_Bank_Inv(Items.misc.plank_box, 8, API.OFF_ACT_GeneralInterface_route2)

        if not WaitForControl(1.2) then
            return false
        end

        API.logInfo("Closing bank.")

        API.KeyboardPress2(	0x1B, 60, 100)

        if not WaitForControl(0.4) then
            return false
        end
    end

    if CurrentContract.missingBuildMaterials then
        API.logInfo("Checking materials after loading preset.")

        if not Functions.HasRequiredMaterials(CurrentContract.missingBuildMaterials) then
            StopReason = "Preset still contains insufficient materials for the selected build options."
            CurrentState = STATE_STOP
            return false
        end

        API.logInfo("Preset materials are sufficient; resuming contract.")
        CurrentContract.missingBuildMaterials = nil
    end

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
        API.logInfo("Script started.")
        CurrentState = STATE_CHECK_CONTRACT

    elseif CurrentState == STATE_CHECK_CONTRACT then
        if Inventory:GetItemAmount(Items.misc.contract) > 0 then
            API.logInfo("Contract found.")
            CurrentState = STATE_OPEN_INTERFACE
        else
            API.logError("No contract.")
            CurrentState = STATE_STOP
        end

    elseif CurrentState == STATE_OPEN_INTERFACE then

        if not API.InventoryInterfaceCheckvarbit() then
            StopReason = "Inventory is not open. Open the inventory before starting the script."
            CurrentState = STATE_STOP

        elseif CheckContract() then

            API.logInfo("Interface opened.")
            CurrentState = STATE_SYNC_CONTRACT

        else

            local err = HasError()

            if err == "NO_CONTRACT" then
                API.logInfo("Contract complete. Returning Home.")
                CurrentState = STATE_RETURN_HOME

            else
                API.logInfo("Clicking contract.")
                API.DoAction_Inventory1(
                    Items.misc.contract,
                    0,
                    1,
                    API.OFF_ACT_GeneralInterface_route
                )
                WaitForControl(1.3)
            end

        end

    elseif CurrentState == STATE_SYNC_CONTRACT then
        local ok, location, npc, area = CheckContract()
        if not ok then
            API.logError("No valid contract found.")
            CurrentState = STATE_STOP
            return
        end

        -- When a script starts inside the contract area, do not route back out
        -- to the front door. Coming from outside keeps the door mandatory.
        DoorHandled = IsPlayerInArea(area)
        CurrentContract.location = location
        CurrentContract.npc = npc
        CurrentContract.townArea = townAreas[location]
        CurrentContract.buildingArea = area
        CurrentContract.walkTarget = GetRandomPointInArea(area)
        CurrentContract.door = nil
        CurrentContract.stairs = nil
        CurrentContract.accessDoors = nil
        CurrentContract.accessRoute = nil
        CurrentContract.accessDoorsHandled = {}
        CurrentContract.routeRepairIndex = 1
        CurrentContract.stairAttemptsWithoutRepair = 0
        CurrentContract.entrance = ENTRANCES[npc]
        CurrentContract.repairPriorities = GetRepairPriorities(location, npc)
        CurrentContract.repairPhase = nil
        CurrentContract.repairDeadline = nil
        CurrentContract.repairHardDeadline = nil
        CurrentContract.repairNextAt = nil
        CurrentContract.walkTargetAttempts = 0
        CurrentContract.walkTargetLastAttemptAt = nil
        CurrentContract.missingBuildMaterials = nil
        CurrentContract.exteriorRepairRule = EXTERIOR_REPAIR_RULES[npc]
        CurrentContract.exteriorRepairPending = false
        CurrentContract.masterTeleportExteriorCheckPending = false
        CurrentContract.masterTeleportExteriorCheckAt = nil

        if npc == "Father Aereck" then
            CurrentContract.door = DOORS.FatherAereck
        elseif npc == "Victoria" then
            CurrentContract.door = DOORS.Victoria
            CurrentContract.stairs = STAIRS.Victoria
        elseif npc == "Bob's Axes" then
            CurrentContract.stairs = STAIRS.Bob_Axes
        elseif npc == "The shopkeeper" and location == "Lumbridge" then
            CurrentContract.stairs = STAIRS.ShopkeeperLumbridge
            CurrentContract.accessDoors = ACCESS_DOORS.ShopkeeperLumbridge
        elseif npc == "The shopkeeper" and location == "Varrock" then
            CurrentContract.stairs = STAIRS.ShopkeeperVarrock
            CurrentContract.accessDoors = ACCESS_DOORS.ShopkeeperVarrock
        elseif npc == "The shopkeeper" and location == "Edgeville" then
            CurrentContract.stairs = STAIRS.Shopkeeperedgevillage
        elseif npc == "The bartender" then
            CurrentContract.stairs = STAIRS.Bartender
            CurrentContract.accessRoute = ACCESS_ROUTES.Bartender
        elseif npc == "Ned" then
            CurrentContract.stairs = STAIRS.NED
            CurrentContract.door = DOORS.NED
        elseif npc == "Wise old man" then
            CurrentContract.stairs = STAIRS.WiseOldMan
            CurrentContract.door = DOORS.WiseOldMan
        elseif npc == "Aggie" then
            CurrentContract.stairs = STAIRS.Aggie
            CurrentContract.door = DOORS.Aggie
        elseif npc == "Charos" then
            CurrentContract.stairs = STAIRS.Charos
            CurrentContract.door = DOORS.Charos
            CurrentContract.accessDoors = ACCESS_DOORS.Charos
        end

        if CurrentContract.entrance then
            CurrentContract.walkTarget = GetRandomEntrancePoint(CurrentContract.entrance)
            API.logDebug(string.format(
                "Front door walk target: (%d,%d)",
                CurrentContract.walkTarget.x,
                CurrentContract.walkTarget.y
            ))
        else
            API.logDebug(string.format(
                "New walk target: (%d,%d)",
                CurrentContract.walkTarget.x,
                CurrentContract.walkTarget.y
            ))
        end

        local completed, total = GetCompletedTasks()

        API.logDebug("Tasks completed: " .. completed .. "/" .. total)

        if completed == total then
            CurrentState = STATE_RETURN_HOME
        else
            CurrentState = STATE_TRAVEL
        end

    elseif CurrentState == STATE_TRAVEL then

        -----------------------------------------------------------------
        -- Not in the correct town -> teleport
        -----------------------------------------------------------------
        if not IsPlayerInArea(CurrentContract.townArea) then

            API.logInfo("STATE_TRAVEL: Player is outside town, teleporting.")

            TeleportToTown(CurrentContract.location)

            WaitForControl(0.5)

        elseif CurrentContract.masterTeleportExteriorCheckPending then

            if os.clock() < CurrentContract.masterTeleportExteriorCheckAt then
                API.logDebug("STATE_TRAVEL: Waiting for exterior repair hotspots to load.")
                WaitForControl(0.2)
                return
            end

            CurrentContract.masterTeleportExteriorCheckPending = false
            CurrentContract.masterTeleportExteriorCheckAt = nil

            local exteriorRepair = FindExteriorRepairObject()
            if exteriorRepair then
                CurrentContract.exteriorRepairPending = true
                DoorHandled = false
                API.logInfo(
                    "STATE_TRAVEL: Exterior Bench space found after outfit teleport; opening front door first."
                )
            else
                DoorHandled = true
                API.logDebug("STATE_TRAVEL: No exterior priority repair found; front door skipped after outfit teleport.")
            end

            return

        elseif CurrentContract.entrance
        and CurrentContract.door
        and not DoorHandled then

            if API.ReadPlayerMovin() then
                API.logInfo("STATE_TRAVEL: Walking to front door.")
                WaitForControl(0.5)

            elseif IsPlayerNearPoint(CurrentContract.walkTarget, 2)
            or IsPlayerNearDoor(CurrentContract.door, 4) then
                API.logInfo("STATE_TRAVEL: Front door reached.")

                if HandleDoor(CurrentContract.door) then
                    DoorHandled = true
                    API.logInfo("STATE_TRAVEL: Door open; going directly to repairs.")
                    CurrentState = STATE_BUILD
                end

                else
                API.logInfo("STATE_TRAVEL: Walking to front door.")
                -- DoorHandled remains mandatory after an ability, so a longer
                -- approach may still use travel abilities without skipping it.
                WalkToArea(CurrentContract.buildingArea, true, true)
            end

        -----------------------------------------------------------------
        -- The player is inside, or no front door is required.
        -----------------------------------------------------------------
        elseif IsPlayerInArea(CurrentContract.buildingArea) then

            API.logInfo("STATE_TRAVEL: Building reached.")

            CurrentState = STATE_BUILD

            WaitForControl(0.5)

        elseif CurrentContract.entrance
        and not IsPlayerNearPoint(CurrentContract.walkTarget, 2) then

            if API.ReadPlayerMovin() then
                API.logInfo("STATE_TRAVEL: Walking inside building.")
                WaitForControl(0.5)
            else
                API.logInfo("STATE_TRAVEL: Walking inside building.")
                WalkToPoint(
                    CurrentContract.walkTarget.x,
                    CurrentContract.walkTarget.y,
                    CurrentContract.walkTarget.z
                )
            end

        -----------------------------------------------------------------
        -- Still travelling
        -----------------------------------------------------------------
        else

            -- Still walking? Do nothing.
            if API.ReadPlayerMovin() then

                API.logInfo("STATE_TRAVEL: Walking...")

                WaitForControl(0.5)

            else

                -- Handle a possible door first.
                API.logDebug("Door: " .. tostring(CurrentContract.door and CurrentContract.door.name) .. " | Handled: " .. tostring(DoorHandled))

                if CurrentContract.door and not DoorHandled then

                    if IsDoorInNextWalk(CurrentContract.door) then

                        API.logInfo("STATE_TRAVEL: Door within range.")

                        if HandleDoor(CurrentContract.door) then
                            DoorHandled = true
                        end

                    else

                        API.logInfo("STATE_TRAVEL: Walking towards building.")

                        WalkToArea(CurrentContract.buildingArea, true)

                    end

                else

                    API.logInfo("STATE_TRAVEL: Walking towards building.")

                    WalkToArea(CurrentContract.buildingArea, true)

                end

            end

        end

    elseif CurrentState == STATE_BUILD then

        if IsPlayerMoving() then
            if CurrentContract.repairPhase == "wait_repair" then
                CurrentContract.repairDeadline = os.clock() + 20
            end
            API.logDebug("STATE_BUILD: Waiting for player movement and animation to finish.")
            WaitForControl(0.4)
        else

        API.logInfo("STATE_BUILD: Searching for repairs.")

        local result = RepairFloor()

        if result == "success" then
            API.logInfo("STATE_BUILD: Repair complete.")
            AwaitingCompletionUpdate = true
            CurrentContract.stairAttemptsWithoutRepair = 0

        elseif result == "access" then
            API.logInfo("STATE_BUILD: Access door opened; searching for repairs again.")

        elseif result == "interrupted" then
            API.logInfo("STATE_BUILD: Waiting interrupted by Pause/Stop.")

        elseif result == "pending" then
            -- The repair flow waits without blocking; Main can process Pause/Stop.

    elseif result == "done" then

        if HasError() == "CONTRACT_COMPLETED" then
            API.logInfo("STATE_BUILD: Contract complete.")
            ContractStats.contractsDone = ContractStats.contractsDone + 1
            AwaitingCompletionUpdate = false
            CurrentState = STATE_RETURN_HOME

        else

        local completed, total

        if AwaitingCompletionUpdate then
            completed, total = WaitForCompletionUpdate(2)
            AwaitingCompletionUpdate = false
        else
            completed, total = GetCompletedTasks()
        end

        API.logInfo("STATE_BUILD: No more repairs found.")
        API.logInfo("STATE_BUILD: Tasks completed: " .. completed .. "/" .. total)

        if completed == total then

            API.logInfo("STATE_BUILD: Contract complete.")
            CurrentState = STATE_RETURN_HOME

        else

        local player = API.PlayerCoord()
        if OpenAccessDoorBeforeRepair({ Floor = player.z, Distance = math.huge }, true) then
            API.logInfo("STATE_BUILD: Stair access door opened; searching for repairs again.")
            return
        end

        if CurrentContract.stairAttemptsWithoutRepair >= 2 then
            StopReason = "No repairs found after two floor changes."
            CurrentState = STATE_STOP
            return
        end

        API.logInfo("STATE_BUILD: Using stairs.")

        local ok = HandleStairs()

        if Functions.HasPendingRequest() then
            return
        end

        API.logDebug("HandleStairs result: " .. tostring(ok))

        if ok then
            CurrentContract.stairAttemptsWithoutRepair = CurrentContract.stairAttemptsWithoutRepair + 1
            API.logDebug("Floor changes without repairs: " .. CurrentContract.stairAttemptsWithoutRepair .. "/2")
            API.logInfo("STATE_BUILD: New floor reached.")
        else
            StopReason = "Could not use stairs."
            CurrentState = STATE_STOP
        end

    end

        end

        elseif result == "bank" then
            CurrentState = STATE_BANK
            API.logDebug("STATE changed to BANK")

        elseif result == "stop" then
            CurrentState = STATE_STOP

        else
            StopReason = "Unknown build result: " .. tostring(result)
            CurrentState = STATE_STOP
        end

        end

    elseif CurrentState == STATE_RETURN_HOME then

        if Functions.HasPendingRequest() then
            return
        end

    if IsPlayerInArea(townAreas["Home"]) then

        API.logInfo("Back at Home.")
        CurrentState = STATE_HANDIN

    else
        local teleported = TeleportHome()

        if Functions.HasPendingRequest() then
            return
        elseif teleported then
            CurrentState = STATE_HANDIN
        else
            StopReason = "Could not teleport to Home."
            CurrentState = STATE_STOP
        end

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

        Functions.Stop("Contracts", StopReason, {
            contract = CurrentContract.location,
            npc = CurrentContract.npc,
            player = API.PlayerCoord(),
            repairTarget = CurrentContract.repairTarget,
            showRepairTarget = true
        })

        API.Write_LoopyLoop(false)
    end

    WaitForControl(0.25)

end

function M.Start(config)
    Config = config
    running = true
    paused = false
    CurrentState = STATE_START
    ContractStats.startedAt = os.time()
    ContractStats.contractsDone = 0
    ContractStats.creditsEarned = 0

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

function M.GetStats()

    local elapsed = 0
    if ContractStats.startedAt then
        elapsed = math.max(os.time() - ContractStats.startedAt, 1)
    end

    local perHour = 0
    if elapsed > 0 then
        perHour = ContractStats.contractsDone * 3600 / elapsed
    end

    return {
        contractsPerHour = perHour,
        contractsDone = ContractStats.contractsDone,
        creditsEarned = ContractStats.creditsEarned
    }

end

return M
