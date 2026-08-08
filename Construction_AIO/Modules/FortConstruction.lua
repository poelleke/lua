local FortConstruction = {}

local API = require("api")
local Data = require("Data.Data")
local Functions = require("Data.Functions")

local running = false
local paused = false
local currentConfig = nil

local states = {
    CHECKING_EXISTING_HOTSPOT = 1,
    CHECKING_MATERIALS = 2,
    BANKING = 3,
    BUILD_FROM_SCRATCH_BANKING = 4,
    BUILD_FROM_SCRATCH_PLANNING = 5,
    BUILD_FROM_SCRATCH_OPENING_STATION = 6,
    BUILD_FROM_SCRATCH_WAITING_FOR_INTERFACE = 7,
    BUILD_FROM_SCRATCH_WAITING_FOR_PROCESS = 8,
    OPENING_BLUEPRINTS = 9,
    WAITING_FOR_BLUEPRINTS = 10,
    SELECTING_BLUEPRINT = 11,
    CONFIRMING_BLUEPRINT = 12,
    WAITING_FOR_BLUEPRINT_RESULT = 13,
    TRAVELLING_TO_BUILDING = 14,
    FINDING_HOTSPOT = 15,
    CLICKING_HOTSPOT = 16,
    MONITORING_HOTSPOT = 17,
    RETURNING_TO_BANK = 18
}

local currentState = states.CHECKING_MATERIALS
local interfaceChecks = 0
local currentHotspot = nil
local activeBuilding = nil
local blueprintResultChecks = 0
local materialPlan = nil
local productionJob = nil
local productionInterfaceChecks = 0

local MAX_UNNOTED_FORT_MATERIALS = 15

-- Cabin / Side gate routing
local FORT_SIDE_MAX_X = 3335
local CABIN_SIDE_MIN_X = 3336
local SIDE_GATE_ID = 125443
local SIDE_GATE_NAME = "Side gate"
local SIDE_GATE_ACTION = "Pass through"
local SIDE_GATE_X = 3336
local SIDE_GATE_Y = 3550
local MAX_WALK_STEP = 25
local GATE_INTERACT_DISTANCE = 25
local ETERNAL_REINFORCEMENT_BLUEPRINT_ID = 109

local verifiedBlueprints = {
    ["Workshop"] = {
        [1] = 1,
        [2] = 2,
        [3] = 9
    },
    ["Town Hall"] = {
        [1] = 13,
        [2] = 17,
        [3] = 21
    },
    ["Chapel"] = {
        [1] = 25,
        [2] = 29,
        [3] = 33
    },
    ["Command Centre"] = {
        [1] = 37,
        [2] = 41,
        [3] = 45
    },
    ["Kitchen"] = {
        [1] = 49,
        [2] = 53,
        [3] = 57
    },
    ["Guardhouse"] = {
        [1] = 61,
        [2] = 65,
        [3] = 69
    },
    ["Grove Cabin"] = {
        [1] = 73,
        [2] = 77,
        [3] = 81
    },
    ["Ranger's Workroom"] = {
        [1] = 85,
        [2] = 59,
        [3] = 93
    },
    ["Botanist's Workbench"] = {
        [1] = 97,
        [2] = 101,
        [3] = 105
    },

}

local function IsBlueprintInterfaceOpen()
    return API.Compare2874Status(40, false)
end

local function HasActiveBlueprintDialog()
    return API.Dialog_compare_sayd(
        "You've already got another building blueprint in progress."
    )
end

local function IsHotspotInBuildingArea(hotspot, area)
    return hotspot.x >= area.x1
        and hotspot.x <= area.x2
        and hotspot.y >= area.y1
        and hotspot.y <= area.y2
end

local function FindHotspots(objectId)
    -- Fort hotspots can be farther away than the currently visible building.
    -- Use the same explicit 150-tile search radius as the verified legacy
    -- Fort reference instead of an unbounded object scan.
    local results = API.GetAllObjArray1({ objectId }, 150, { 0 })

    local hotspots = {}

    for _, hotspot in pairs(results) do
        if hotspot and hotspot.CalcX and hotspot.CalcY then
            table.insert(hotspots, {
                id = objectId,
                x = hotspot.CalcX,
                y = hotspot.CalcY,
                floor = 0
            })
        end
    end

    return hotspots
end

local function FindHotspotInBuildingArea(objectId, buildingArea)
    for _, hotspot in ipairs(FindHotspots(objectId)) do
        if IsHotspotInBuildingArea(hotspot, buildingArea) then
            return hotspot
        end
    end

    return nil
end

local function FindBestHotspot(buildingArea)
    local optimal = FindHotspotInBuildingArea(Data.Objects.FortOptimalConstructionHotspot, buildingArea)
    if optimal then
        return optimal, "Optimal Construction hotspot"
    end

    local standard = FindHotspotInBuildingArea(Data.Objects.FortConstructionHotspot, buildingArea)
    if standard then
        return standard, "Construction hotspot"
    end

    return nil
end

local function GetBuildingForHotspot(hotspot)
    for buildingName, area in pairs(Data.FortAreas) do
        if IsHotspotInBuildingArea(hotspot, area) then
            return buildingName
        end
    end

    return nil
end

local function FindExistingFortHotspot()
    local hotspotTypes = {
        { id = Data.Objects.FortOptimalConstructionHotspot, name = "Optimal Construction hotspot" },
        { id = Data.Objects.FortConstructionHotspot, name = "Construction hotspot" }
    }

    for _, hotspotType in ipairs(hotspotTypes) do
        for _, hotspot in ipairs(FindHotspots(hotspotType.id)) do
            local buildingName = GetBuildingForHotspot(hotspot)

            API.logDebug("Fort start hotspot scan: " .. hotspotType.name
                .. " | ID: " .. tostring(hotspot.id)
                .. " | (" .. tostring(hotspot.x) .. "," .. tostring(hotspot.y) .. ")"
                .. " | building: " .. tostring(buildingName or "outside configured Fort areas"))

            if buildingName then
                return hotspot, hotspotType.name, buildingName
            end
        end
    end

    return nil
end

-- Eternal reinforcement has no fixed building area. When that activity is
-- selected, the hotspot's real coordinates are authoritative.
local function FindAnyFortHotspot()
    local hotspotTypes = {
        { id = Data.Objects.FortOptimalConstructionHotspot, name = "Optimal Construction hotspot" },
        { id = Data.Objects.FortConstructionHotspot, name = "Construction hotspot" }
    }

    for _, hotspotType in ipairs(hotspotTypes) do
        local hotspots = FindHotspots(hotspotType.id)
        if #hotspots > 0 then
            local hotspot = hotspots[1]
            return hotspot, hotspotType.name, GetBuildingForHotspot(hotspot)
        end
    end

    return nil
end

local function IsEternalSelected()
    return (currentConfig.FortForinthryBuilding or 0) == 9
end

local function IsDifferentHotspot(first, second)
    return not first
        or not second
        or first.id ~= second.id
        or first.x ~= second.x
        or first.y ~= second.y
        or first.floor ~= second.floor
end

local function IsPlayerInArea(area)
    local player = API.PlayerCoord()

    return player
        and player.x >= area.x1
        and player.x <= area.x2
        and player.y >= area.y1
        and player.y <= area.y2
end

local function GetSideFromX(x)
    if x == nil then
        return nil
    end

    if x <= FORT_SIDE_MAX_X then
        return "fort"
    end

    if x >= CABIN_SIDE_MIN_X then
        return "cabin"
    end

    return nil
end

local function GetPlayerSide()
    local player = API.PlayerCoord()
    if not player then
        return nil
    end

    return GetSideFromX(player.x)
end

local function GetHotspotSide(hotspot)
    if not hotspot then
        return nil
    end

    return GetSideFromX(hotspot.x)
end

local function GetBuildingSide(buildingName)
    if buildingName == "Grove Cabin" then
        return "cabin"
    end

    return "fort"
end

local function WalkTowardsPoint(targetX, targetY, label)
    local player = API.PlayerCoord()
    if not player then
        return false
    end

    local dx = targetX - player.x
    local dy = targetY - player.y
    local distance = math.sqrt(dx * dx + dy * dy)

    if distance <= 1 then
        return true
    end

    -- Do not start a new route while another movement or processing action is active.
    if API.IsPlayerMoving_() or API.isProcessing() then
        return false
    end

    local step = math.min(MAX_WALK_STEP, distance)
    local walkX = math.floor(player.x + (dx / distance) * step)
    local walkY = math.floor(player.y + (dy / distance) * step)

    API.logInfo((label or "Fort travel")
        .. ": player (" .. tostring(player.x) .. "," .. tostring(player.y) .. ")"
        .. " | target (" .. tostring(targetX) .. "," .. tostring(targetY) .. ")"
        .. " | distance " .. string.format("%.1f", distance)
        .. " | walking to (" .. tostring(walkX) .. "," .. tostring(walkY) .. ").")

    API.DoAction_Tile(WPOINT.new(walkX, walkY, player.z))

    -- Important: block here until this walking action is actually finished.
    -- IsPlayerMoving_() can briefly report false while route-walking, which caused
    -- repeated DoAction_Tile calls and a full action queue.
    API.WaitUntilMovingEnds()

    return false
end

local function EnsurePlayerSide(targetSide)
    local player = API.PlayerCoord()
    if not player then
        return false
    end

    local currentSide = GetPlayerSide()
    if currentSide == targetSide then
        return true
    end

    local dx = SIDE_GATE_X - player.x
    local dy = SIDE_GATE_Y - player.y
    local distance = math.sqrt(dx * dx + dy * dy)

    if distance > GATE_INTERACT_DISTANCE then
        if not API.IsPlayerMoving_() then
            WalkTowardsPoint(SIDE_GATE_X, SIDE_GATE_Y, "Fort gate travel")
        end
        return false
    end

    if API.IsPlayerMoving_() or API.isProcessing() then
        return false
    end

    API.logInfo("Fort gate: using " .. SIDE_GATE_NAME .. " -> " .. SIDE_GATE_ACTION
        .. " | current side: " .. tostring(currentSide)
        .. " | target side: " .. tostring(targetSide) .. ".")

    local success, result = pcall(function()
        return Interact:Object(SIDE_GATE_NAME, SIDE_GATE_ACTION, nil, 50)
    end)

    if not success or result == false then
        FortConstruction.Stop("Could not use the Side gate while travelling between the Fort and Grove Cabin.")
        return false
    end

    if not Functions.SleepUntil(function()
        return GetPlayerSide() == targetSide
    end, 6, "Fort Side gate transition to " .. targetSide) then
        API.logWarn("Fort gate: Side gate action was sent, but the player has not reached the "
            .. targetSide .. " side yet. Retrying.")
        return false
    end

    local after = API.PlayerCoord()
    API.logInfo("Fort gate: transition complete"
        .. (after and (" | player (" .. tostring(after.x) .. "," .. tostring(after.y) .. ")") or "")
        .. " | side: " .. targetSide .. ".")

    return true
end

local function EnsureFortServiceSide()
    return EnsurePlayerSide("fort")
end

local function WalkToBuildingArea(area)
    if IsPlayerInArea(area) then
        return true
    end

    local targetX = math.floor((area.x1 + area.x2) / 2)
    local targetY = math.floor((area.y1 + area.y2) / 2)

    return WalkTowardsPoint(targetX, targetY, "Fort travel: building area")
end

local function GetSelection()
    local buildingIndex = (currentConfig.FortForinthryBuilding or 0) + 1
    local tier = (currentConfig.FortForinthryTier or 0) + 1
    local buildings = {
        "Workshop",
        "Town Hall",
        "Chapel",
        "Command Centre",
        "Kitchen",
        "Guardhouse",
        "Grove Cabin",
        "Ranger's Workroom",
        "Botanist's Workbench",
        "Eternal reinforcement"
    }

    local building = buildings[buildingIndex]
    if not building then
        return nil, nil, nil, "Invalid Fort building selected."
    end

    if building == "Eternal reinforcement" then
        return building, nil, {
            id = ETERNAL_REINFORCEMENT_BLUEPRINT_ID,
            isEternal = true
        }
    end

    local blueprint = Data.FortBlueprints[building]
        and Data.FortBlueprints[building][tier]
    local blueprintId = verifiedBlueprints[building]
        and verifiedBlueprints[building][tier]

    if not blueprint then
        return nil, nil, nil, "No material data exists for the selected Fort blueprint."
    end

    if not blueprintId then
        return nil, nil, nil,
            "The blueprint ID for " .. building .. " Tier " .. tostring(tier)
            .. " has not been verified yet."
    end

    return building, tier, {
        data = blueprint,
        id = blueprintId
    }
end

local function HasRequiredMaterials(selection, logCounts)
    local frameMaterial = Data.Items.FrameMaterials[selection.data.materialIndex]
    if not frameMaterial then
        return false, "No frame material mapping exists for the selected blueprint."
    end

    local frameCount = Inventory:InvItemcount(frameMaterial.Output)
    local stoneCount = Inventory:InvItemcount(Data.Items.Stone.StoneWallSegment)

    if logCounts ~= false then
        API.logInfo(frameMaterial.Name .. " | required: " .. tostring(selection.data.frameCount)
            .. " | inventory: " .. tostring(frameCount))
        API.logInfo("Stone wall segment | required: " .. tostring(selection.data.stoneWallSegments)
            .. " | inventory: " .. tostring(stoneCount))
    end

    if frameCount < selection.data.frameCount or stoneCount < selection.data.stoneWallSegments then
        return false
    end

    return true
end

local function OpenFortBank()
    if Bank:IsOpen() then
        return true
    end

    -- All banking is intentionally done from the Workshop side.
    -- This prevents the generic Fort bank object search from selecting the
    -- Chapel bank when arriving from the Grove Cabin Side gate.
    if not EnsureFortServiceSide() then
        return false
    end

    local workshopArea = Data.FortAreas["Workshop"]
    if not workshopArea then
        FortConstruction.Stop("Workshop Fort area is missing; cannot route to the Fort bank.")
        return false
    end

    if not IsPlayerInArea(workshopArea) then
        WalkToBuildingArea(workshopArea)
        return false
    end

    -- Do not start the bank-open timeout while the character is still
    -- finishing a movement/pathing action.
    if API.IsPlayerMoving_() or API.isProcessing() then
        return false
    end

    local player = API.PlayerCoord()
    API.logInfo("Fort bank: Workshop reached"
        .. (player and (" | player (" .. tostring(player.x) .. "," .. tostring(player.y) .. ")") or "")
        .. ". Opening bank.")

    API.DoAction_Object1(0x2e, API.OFF_ACT_GeneralObject_route1, { Data.Objects.FortBank }, 50)

    if not Functions.SleepUntil(function()
        return Bank:IsOpen() or Bank:IsPINOpen()
    end, 10, "Fort bank open at Workshop") then
        FortConstruction.Stop("Failed to open the Fort bank at the Workshop.")
        return false
    end

    if Bank:IsPINOpen() then
        if not Functions.HandleBankPin(currentConfig) then
            FortConstruction.Stop("Fort bank PIN handling failed.")
            return false
        end

        if not Functions.SleepUntil(function()
            return Bank:IsOpen()
        end, 8, "Fort bank after PIN") then
            FortConstruction.Stop("Fort bank did not open after entering the PIN.")
            return false
        end
    end

    return Bank:IsOpen()
end

local function DepositCurrentInventory()
    if Inventory:IsEmpty() then
        return true
    end

    API.logInfo("Build from scratch: depositing current inventory before planning.")
    if not Bank:DepositInventory() then
        FortConstruction.Stop("Failed to deposit inventory while preparing Fort materials.")
        return false
    end

    if not Functions.SleepUntil(function()
        return Inventory:IsEmpty()
    end, 5, "Build from scratch inventory deposit") then
        FortConstruction.Stop("Inventory did not empty while preparing Fort materials.")
        return false
    end

    return true
end

local function GetBankAmount(itemId)
    if not itemId or itemId <= 0 then
        return 0
    end

    local amount = Bank:GetItemAmount(itemId)
    return tonumber(amount) or 0
end

local function BuildMaterialPlan(selection)
    local materialIndex = selection.data.materialIndex
    local woodMaterial = Data.Items.Materials[materialIndex]
    local refinedMaterial = Data.Items.RefinedMaterials[materialIndex]
    local frameMaterial = Data.Items.FrameMaterials[materialIndex]

    if not woodMaterial then
        return nil, "No wood material mapping exists for material index " .. tostring(materialIndex) .. "."
    end

    if not refinedMaterial then
        return nil, "No refined plank mapping exists for material index " .. tostring(materialIndex) .. "."
    end

    if not frameMaterial then
        return nil, "No frame material mapping exists for material index " .. tostring(materialIndex) .. "."
    end

    local frameRequired = tonumber(selection.data.frameCount) or 0
    local stoneRequired = tonumber(selection.data.stoneWallSegments) or 0

    local frameAvailable = GetBankAmount(frameMaterial.Output)
    local refinedAvailable = GetBankAmount(refinedMaterial.Output)
    local plankAvailable = GetBankAmount(woodMaterial.Plank)
    local logAvailable = GetBankAmount(woodMaterial.Log)
    local stoneAvailable = GetBankAmount(Data.Items.Stone.StoneWallSegment)
    local limestoneAvailable = GetBankAmount(Data.Items.Stone.Limestone)

    local missingFrames = math.max(0, frameRequired - frameAvailable)
    local refinedRequired = missingFrames * (tonumber(frameMaterial.Required) or 3)
    local missingRefined = math.max(0, refinedRequired - refinedAvailable)
    local planksRequired = missingRefined * (tonumber(refinedMaterial.Required) or 4)
    local missingPlanks = math.max(0, planksRequired - plankAvailable)
    local logsRequired = missingPlanks
    local missingLogs = math.max(0, logsRequired - logAvailable)

    local missingStone = math.max(0, stoneRequired - stoneAvailable)
    local limestoneRequired = missingStone * 4
    local missingLimestone = math.max(0, limestoneRequired - limestoneAvailable)

    return {
        materialIndex = materialIndex,
        wood = woodMaterial,
        refined = refinedMaterial,
        frame = frameMaterial,
        frames = {
            required = frameRequired,
            available = frameAvailable,
            missing = missingFrames
        },
        refinedPlanks = {
            required = refinedRequired,
            available = refinedAvailable,
            missing = missingRefined
        },
        planks = {
            required = planksRequired,
            available = plankAvailable,
            missing = missingPlanks
        },
        logs = {
            required = logsRequired,
            available = logAvailable,
            missing = missingLogs
        },
        stoneSegments = {
            required = stoneRequired,
            available = stoneAvailable,
            missing = missingStone
        },
        limestone = {
            required = limestoneRequired,
            available = limestoneAvailable,
            missing = missingLimestone
        }
    }
end

local function LogMaterialPlan(plan)
    API.logInfo("=== Fort Build from scratch material plan ===")
    API.logInfo(plan.frame.Name .. " | required: " .. tostring(plan.frames.required)
        .. " | bank: " .. tostring(plan.frames.available)
        .. " | missing: " .. tostring(plan.frames.missing))
    API.logInfo(plan.refined.Name .. " | required for missing frames: " .. tostring(plan.refinedPlanks.required)
        .. " | bank: " .. tostring(plan.refinedPlanks.available)
        .. " | missing: " .. tostring(plan.refinedPlanks.missing))
    API.logInfo(plan.wood.Name .. " planks | required for missing refined planks: " .. tostring(plan.planks.required)
        .. " | bank: " .. tostring(plan.planks.available)
        .. " | missing: " .. tostring(plan.planks.missing))
    API.logInfo(plan.wood.Name .. " logs | required for missing planks: " .. tostring(plan.logs.required)
        .. " | bank: " .. tostring(plan.logs.available)
        .. " | missing: " .. tostring(plan.logs.missing))
    API.logInfo("Stone wall segments | required: " .. tostring(plan.stoneSegments.required)
        .. " | bank: " .. tostring(plan.stoneSegments.available)
        .. " | missing: " .. tostring(plan.stoneSegments.missing))
    API.logInfo("Limestone | required for missing Stone wall segments: " .. tostring(plan.limestone.required)
        .. " | bank: " .. tostring(plan.limestone.available)
        .. " | missing: " .. tostring(plan.limestone.missing))
end

local function GetNextProductionJob(plan)
    if plan.logs.missing > 0 then
        return nil, plan.wood.Name .. " logs are short by " .. tostring(plan.logs.missing) .. "."
    end

    if plan.limestone.missing > 0 then
        return nil, "Limestone is short by " .. tostring(plan.limestone.missing) .. "."
    end

    -- Always work from the lowest unfinished step upwards. After every batch
    -- the inventory is deposited and the complete plan is recalculated.
    if plan.planks.missing > 0 then
        return {
            name = plan.wood.Name .. " planks",
            input = plan.wood.Log,
            output = plan.wood.Plank,
            requiredPerOutput = 1,
            outputNeeded = plan.planks.missing,
            stationName = "Sawmill",
            stationAction = "Process planks"
        }
    end

    if plan.refinedPlanks.missing > 0 then
        return {
            name = plan.refined.Name,
            input = plan.wood.Plank,
            output = plan.refined.Output,
            requiredPerOutput = tonumber(plan.refined.Required) or 4,
            outputNeeded = plan.refinedPlanks.missing,
            materialIndex = plan.materialIndex,
            usePlankBox = true,
            stationName = "Sawmill",
            stationAction = "Process planks"
        }
    end

    if plan.frames.missing > 0 then
        return {
            name = plan.frame.Name,
            input = plan.refined.Output,
            output = plan.frame.Output,
            requiredPerOutput = tonumber(plan.frame.Required) or 3,
            outputNeeded = plan.frames.missing,
            stationName = "Woodworking bench",
            stationAction = "Construct frames"
        }
    end

    if plan.stoneSegments.missing > 0 then
        return {
            name = "Stone wall segments",
            input = Data.Items.Stone.Limestone,
            output = Data.Items.Stone.StoneWallSegment,
            requiredPerOutput = 4,
            outputNeeded = plan.stoneSegments.missing,
            stationName = "Stonecutter",
            stationAction = "Cut stone"
        }
    end

    return false
end

local function WithdrawProductionBatch(job)

    ------------------------------------------------------------------------
    -- Refined planks:
    -- If a Plank box is available, take it, fill it, then fill the
    -- remaining inventory slots with the selected plank type.
    ------------------------------------------------------------------------
    if job.usePlankBox then

        if Bank:Contains(Data.Items.misc.plank_box) then
            API.logInfo(
                "Build from scratch: Plank box found in bank. Withdrawing it for "
                .. job.name .. "."
            )

            if not Bank:Withdraw(Data.Items.misc.plank_box, 1) then
                FortConstruction.Stop(
                    "Build from scratch: failed to withdraw the Plank box."
                )
                return false
            end

            if not Functions.SleepUntil(function()
                return Functions.HasPlankBox()
            end, 5, "Build from scratch withdraw Plank box") then
                FortConstruction.Stop(
                    "Build from scratch: Plank box did not appear in inventory."
                )
                return false
            end

            API.logInfo(
                "Build from scratch: filling Plank box with "
                .. tostring(job.input) .. "."
            )

            if not Functions.FillPlankBoxFromBank(job.input, 6) then
                FortConstruction.Stop(
                    "Build from scratch: failed to fill the Plank box for "
                    .. job.name .. "."
                )
                return false
            end

            API.logInfo(string.format(
                "Build from scratch: Plank box full | Item: %d | Amount: %d/%d",
                job.input,
                Functions.GetPlankBoxAmount(job.input),
                Data.Items.Containers.PlankBoxCapacityPerType
            ))
        else
            API.logInfo(
                "Build from scratch: no Plank box found in bank. Using inventory only."
            )
        end

        --------------------------------------------------------------------
        -- After the Plank box is handled, always fill remaining inventory.
        --------------------------------------------------------------------
        local inventoryFilled, inventoryAfter =
            Functions.FillInventoryFromBank(job.input, 6)

        if not inventoryFilled then
            FortConstruction.Stop(
                "Build from scratch: failed to fill inventory with planks for "
                .. job.name .. "."
            )
            return false
        end

        API.logInfo(string.format(
            "Build from scratch: refined-plank materials ready | Inventory: %d | Plank box: %d | Total: %d",
            inventoryAfter,
            Functions.GetPlankBoxAmount(job.input),
            inventoryAfter + Functions.GetPlankBoxAmount(job.input)
        ))

    ------------------------------------------------------------------------
    -- All other material production:
    -- Keep the existing normal batch withdrawal.
    ------------------------------------------------------------------------
    else

        local perOutput = math.max(1, tonumber(job.requiredPerOutput) or 1)
        local maxOutputsPerInventory = math.max(
            1,
            math.floor(28 / perOutput)
        )

        local batchOutputs = math.min(
            job.outputNeeded,
            maxOutputsPerInventory
        )

        local inputAmount = batchOutputs * perOutput
        local bankAmount = GetBankAmount(job.input)

        if bankAmount < inputAmount then
            FortConstruction.Stop(
                job.name
                .. " needs "
                .. tostring(inputAmount)
                .. " input items for the next batch, but only "
                .. tostring(bankAmount)
                .. " are in the bank."
            )
            return false
        end

        API.logInfo(
            "Build from scratch: withdrawing "
            .. tostring(inputAmount)
            .. " input items for "
            .. tostring(batchOutputs)
            .. " "
            .. job.name
            .. "."
        )

        if not Bank:Withdraw(job.input, inputAmount) then
            FortConstruction.Stop(
                "Failed to withdraw input material for " .. job.name .. "."
            )
            return false
        end

        if not Functions.SleepUntil(function()
            return Inventory:InvItemcount(job.input) >= inputAmount
        end, 5, "Build from scratch production withdrawal") then
            FortConstruction.Stop(
                "Input material for "
                .. job.name
                .. " did not appear in inventory."
            )
            return false
        end
    end

    ------------------------------------------------------------------------
    -- Close bank after either withdrawal method.
    ------------------------------------------------------------------------
    API.KeyboardPress2(0x1B, 50, 0)

    if not Functions.SleepUntil(function()
        return not Bank:IsOpen()
    end, 5, "Build from scratch bank close") then
        FortConstruction.Stop(
            "Fort bank did not close before material production."
        )
        return false
    end

    return true
end

local function OpenProductionStation(job)
    if not Interact or not Interact.Object then
        FortConstruction.Stop("Interact:Object is unavailable for the Fort production station.")
        return false
    end

    API.logInfo("Build from scratch: opening " .. job.stationName .. " -> " .. job.stationAction .. ".")
    local success, result = pcall(function()
        return Interact:Object(job.stationName, job.stationAction, nil, 50)
    end)

    if not success or result == false then
        FortConstruction.Stop("Could not use the Fort " .. job.stationName .. ".")
        return false
    end

    return true
end

local function IsProductionInterfaceOpen()
    return API.Compare2874Status(40, false)
end

local function BankMaterials(selection)
    local frameMaterial = Data.Items.FrameMaterials[selection.data.materialIndex]
    local frameId = frameMaterial.Output
    local stoneId = Data.Items.Stone.StoneWallSegment

    local frameCount = tonumber(selection.data.frameCount) or 0
    local stoneCount = tonumber(selection.data.stoneWallSegments) or 0
    local totalMaterials = frameCount + stoneCount
    local useNotes = totalMaterials > MAX_UNNOTED_FORT_MATERIALS

    if not OpenFortBank() then
        return
    end

    if not Inventory:IsEmpty() then
        API.logInfo("Fort bank: depositing current inventory.")
        if not Bank:DepositInventory() then
            FortConstruction.Stop("Failed to deposit inventory at the Fort bank.")
            return
        end

        if not Functions.SleepUntil(function()
            return Inventory:IsEmpty()
        end, 5, "Fort inventory deposit") then
            FortConstruction.Stop("Inventory did not empty at the Fort bank.")
            return
        end
    end

    local frameBankBefore = GetBankAmount(frameId)
    local stoneBankBefore = GetBankAmount(stoneId)

    if frameBankBefore < frameCount then
        FortConstruction.Stop(frameMaterial.Name .. " does not have the required amount in the Fort bank.")
        return
    end

    if stoneBankBefore < stoneCount then
        FortConstruction.Stop("Stone wall segments do not have the required amount in the Fort bank.")
        return
    end

    API.logInfo("Fort bank: final materials total = " .. tostring(totalMaterials)
        .. " | max unnoted = " .. tostring(MAX_UNNOTED_FORT_MATERIALS)
        .. " | withdrawal mode = " .. (useNotes and "NOTED" or "UNNOTED") .. ".")

    if Bank:IsNoteModeEnabled() ~= useNotes then
        API.logInfo("Fort bank: setting note mode to " .. tostring(useNotes) .. ".")
        if not Bank:SetNoteMode(useNotes) then
            FortConstruction.Stop("Failed to change the Fort bank note withdrawal mode.")
            return
        end

        if not Functions.SleepUntil(function()
            return Bank:IsNoteModeEnabled() == useNotes
        end, 5, "Fort bank note mode") then
            FortConstruction.Stop("Fort bank note withdrawal mode did not change.")
            return
        end
    end

    API.logInfo("Fort bank: withdrawing exactly " .. tostring(frameCount)
        .. " " .. frameMaterial.Name .. " and "
        .. tostring(stoneCount) .. " Stone wall segments"
        .. (useNotes and " as notes." or " unnoted."))

    if not Bank:Withdraw(frameId, frameCount)
        or not Bank:Withdraw(stoneId, stoneCount) then

        -- Never leave the bank in note mode after an error.
        if Bank:IsNoteModeEnabled() then
            Bank:SetNoteMode(false)
        end

        FortConstruction.Stop("Failed to withdraw the required Fort construction materials.")
        return
    end

    if useNotes then
        -- Noted items use different inventory IDs, so verify the withdrawal
        -- by checking that the requested amounts left the bank.
        if not Functions.SleepUntil(function()
            local frameBankAfter = GetBankAmount(frameId)
            local stoneBankAfter = GetBankAmount(stoneId)

            return frameBankAfter <= (frameBankBefore - frameCount)
                and stoneBankAfter <= (stoneBankBefore - stoneCount)
        end, 5, "Fort noted material withdrawal") then

            if Bank:IsNoteModeEnabled() then
                Bank:SetNoteMode(false)
            end

            FortConstruction.Stop("The Fort bank did not withdraw all noted construction materials.")
            return
        end
    else
        if not Functions.SleepUntil(function()
            return Inventory:InvItemcount(frameId) >= frameCount
                and Inventory:InvItemcount(stoneId) >= stoneCount
        end, 5, "Fort material withdrawal") then
            FortConstruction.Stop("The Fort bank did not provide all required construction materials.")
            return
        end
    end

    -- Always restore normal withdrawal mode for every later banking action.
    if Bank:IsNoteModeEnabled() then
        API.logInfo("Fort bank: restoring withdrawal mode to unnoted.")
        if not Bank:SetNoteMode(false) then
            FortConstruction.Stop("Failed to restore the Fort bank to unnoted withdrawal mode.")
            return
        end

        if not Functions.SleepUntil(function()
            return not Bank:IsNoteModeEnabled()
        end, 5, "Fort bank restore unnoted mode") then
            FortConstruction.Stop("Fort bank did not return to unnoted withdrawal mode.")
            return
        end
    end

    API.KeyboardPress2(0x1B, 50, 0)
    if not Functions.SleepUntil(function()
        return not Bank:IsOpen()
    end, 5, "Fort bank close") then
        FortConstruction.Stop("Fort bank did not close.")
        return
    end

    if useNotes then
        API.logInfo("Fort bank: noted materials ready. Continuing directly to blueprint selection.")
        currentState = states.OPENING_BLUEPRINTS
    else
        API.logInfo("Fort bank: materials ready. Rechecking inventory.")
        currentState = states.CHECKING_EXISTING_HOTSPOT
    end
end

function FortConstruction.Start(config)
    currentConfig = config
    running = true
    paused = false
    currentState = states.CHECKING_EXISTING_HOTSPOT
    interfaceChecks = 0
    currentHotspot = nil
    activeBuilding = nil
    blueprintResultChecks = 0
    materialPlan = nil
    productionJob = nil
    productionInterfaceChecks = 0
    lastWalkClickAt = 0

    API.logInfo("Fort Forinthry Construction started.")
    API.logInfo("FortConstruction version: ETERNAL_01")
end

function FortConstruction.Pause()
    paused = true
end

function FortConstruction.Resume()
    paused = false
end

function FortConstruction.IsPaused()
    return paused
end

function FortConstruction.Tick()
    if not running or paused then
        return
    end

    if currentState == states.CHECKING_EXISTING_HOTSPOT then
        -- Startup flow:
        -- 1. Determine the player's current side. Unknown location = stop.
        -- 2. Search for an existing Fort hotspot.
        -- 3. If found, use the hotspot's REAL coordinates to determine its side
        --    and travel to it, using the Side gate only when player/hotspot sides differ.
        -- 4. If no hotspot exists, continue with material/production preparation.
        local player = API.PlayerCoord()
        local playerSide = player and GetSideFromX(player.x) or nil

        if not player or not playerSide then
            FortConstruction.Stop("Player location could not be determined for Fort construction startup.")
            return
        end

        local hotspot, hotspotName, hotspotBuilding = FindExistingFortHotspot()

        -- Eternal reinforcement is not tied to one configured building area.
        -- If the normal area-based scan did not accept a hotspot, accept any
        -- active Fort construction hotspot and use its real coordinates.
        if not hotspot and IsEternalSelected() then
            hotspot, hotspotName, hotspotBuilding = FindAnyFortHotspot()
        end

        if hotspot then
            local hotspotSide = GetHotspotSide(hotspot)
            if not hotspotSide then
                FortConstruction.Stop("Existing Fort hotspot location could not be determined.")
                return
            end

            API.logInfo("Existing Fort construction found: " .. hotspotName
                .. " in " .. hotspotBuilding
                .. " | ID: " .. tostring(hotspot.id)
                .. " | (" .. tostring(hotspot.x) .. "," .. tostring(hotspot.y) .. ")"
                .. " | player side: " .. playerSide
                .. " | hotspot side: " .. hotspotSide .. ".")

            currentHotspot = hotspot
            activeBuilding = hotspotBuilding
            currentState = states.TRAVELLING_TO_BUILDING
        else
            API.logInfo("No active Fort construction hotspot found. Continuing to production/material preparation.")
            currentState = states.CHECKING_MATERIALS
        end

        API.RandomSleep2(650, 450, 800)
        return
    end

    local building, tier, selection, selectionError = GetSelection()
    if not selection then
        FortConstruction.Stop(selectionError)
        return
    end

    local targetBuilding = activeBuilding or building
    local buildingArea = Data.FortAreas[targetBuilding]

    if currentState == states.CHECKING_MATERIALS then
        -- Bank, blueprint table and Fort material stations are all on the Fort side.
        -- If the script was started at Grove Cabin (or just finished a cabin build),
        -- return through the Side gate before continuing the normal preparation flow.
        if not EnsureFortServiceSide() then
            return
        end

        if selection.isEternal then
            API.logInfo("Fort target: Eternal reinforcement | no material banking required.")
            currentState = states.OPENING_BLUEPRINTS
            return
        end

        API.logInfo("Fort target: " .. building .. " Tier " .. tostring(tier))

        local available, materialError = HasRequiredMaterials(selection)
        if not available then
            if currentConfig.FortForinthryBuildFromScratch == true then
                API.logWarn("Required Fort construction materials are missing. Build from scratch is enabled.")
                currentState = states.BUILD_FROM_SCRATCH_BANKING
            else
                API.logWarn("Required Fort construction materials are missing. Banking before blueprint selection.")
                currentState = states.BANKING
            end
            return
        end

        currentState = states.OPENING_BLUEPRINTS

    elseif currentState == states.BANKING then
        if not EnsureFortServiceSide() then
            return
        end

        BankMaterials(selection)

    elseif currentState == states.BUILD_FROM_SCRATCH_BANKING then
        if not EnsureFortServiceSide() then
            return
        end

        if not OpenFortBank() then
            return
        end

        if not DepositCurrentInventory() then
            return
        end

        currentState = states.BUILD_FROM_SCRATCH_PLANNING

    elseif currentState == states.BUILD_FROM_SCRATCH_PLANNING then
        if not Bank:IsOpen() then
            currentState = states.BUILD_FROM_SCRATCH_BANKING
            return
        end

        local plan, planError = BuildMaterialPlan(selection)
        if not plan then
            FortConstruction.Stop(planError)
            return
        end

        materialPlan = plan
        LogMaterialPlan(materialPlan)

        local nextJob, jobError = GetNextProductionJob(materialPlan)
        if nextJob == nil then
            FortConstruction.Stop("Build from scratch cannot continue: " .. tostring(jobError))
            return
        end

        if nextJob == false then
            API.logInfo("Build from scratch: all final Fort materials are available. Withdrawing blueprint materials.")
            productionJob = nil
            BankMaterials(selection)
            return
        end

        productionJob = nextJob
        API.logInfo("Build from scratch: next production step is " .. productionJob.name
            .. " | still needed: " .. tostring(productionJob.outputNeeded) .. ".")

        if not WithdrawProductionBatch(productionJob) then
            return
        end

        productionInterfaceChecks = 0
        currentState = states.BUILD_FROM_SCRATCH_OPENING_STATION

    elseif currentState == states.BUILD_FROM_SCRATCH_OPENING_STATION then
        if not EnsureFortServiceSide() then
            return
        end

        if API.IsPlayerMoving_() or API.isProcessing() then
            return
        end

        if not OpenProductionStation(productionJob) then
            return
        end

        productionInterfaceChecks = 0
        currentState = states.BUILD_FROM_SCRATCH_WAITING_FOR_INTERFACE

    elseif currentState == states.BUILD_FROM_SCRATCH_WAITING_FOR_INTERFACE then
        productionInterfaceChecks = productionInterfaceChecks + 1

        if IsProductionInterfaceOpen() then
            if productionJob.usePlankBox then
                API.logInfo(
                    "Build from scratch: production interface opened. Selecting "
                    .. productionJob.name .. "."
                )

                if not Functions.SelectRefinedPlankOption(
                    productionJob.materialIndex,
                    productionJob.name
                ) then
                    FortConstruction.Stop(
                        "Failed to select refined plank option for "
                        .. productionJob.name .. "."
                    )
                    return
                end

                API.RandomSleep2(300, 150, 150)

                API.logInfo(
                    "Build from scratch: refined plank option selected. Pressing Space to Construct "
                    .. productionJob.name .. "."
                )

                API.KeyboardPress33(32, 0, 50, 100)
            else
                API.logInfo(
                    "Build from scratch: production interface opened. Pressing Space for "
                    .. productionJob.name .. "."
                )

                API.KeyboardPress32(0x20, 0)
            end

            if not Functions.SleepUntil(function()
                return API.isProcessing()
            end, 5, "Build from scratch processing") then
                FortConstruction.Stop("Production did not start for " .. productionJob.name .. ".")
                return
            end

            currentState = states.BUILD_FROM_SCRATCH_WAITING_FOR_PROCESS
        elseif productionInterfaceChecks >= 12 then
            FortConstruction.Stop("Production interface did not open for " .. productionJob.name .. ".")
        end

    elseif currentState == states.BUILD_FROM_SCRATCH_WAITING_FOR_PROCESS then
        if API.isProcessing() then
            return
        end

        API.logInfo("Build from scratch: production batch finished for " .. productionJob.name
            .. ". Returning to the bank and recalculating shortages.")
        API.RandomSleep2(1200, 500, 800)
        currentState = states.BUILD_FROM_SCRATCH_BANKING

    elseif currentState == states.OPENING_BLUEPRINTS then
        if not EnsureFortServiceSide() then
            return
        end

        API.logInfo("Opening Fort Forinthry blueprints table.")
        API.DoAction_Object1(0xae, API.OFF_ACT_GeneralObject_route0, { Data.Objects.FortBlueprints }, 50)
        interfaceChecks = 0
        currentState = states.WAITING_FOR_BLUEPRINTS

    elseif currentState == states.WAITING_FOR_BLUEPRINTS then
        interfaceChecks = interfaceChecks + 1

        if HasActiveBlueprintDialog() then
            FortConstruction.Stop(
                "An existing Fort building blueprint is active, but no construction hotspot was found to resume it."
            )
            return
        elseif IsBlueprintInterfaceOpen() then
            API.logInfo("Fort blueprints interface opened.")
            currentState = states.SELECTING_BLUEPRINT
        elseif interfaceChecks >= 12 then
            FortConstruction.Stop("Fort blueprints interface did not open.")
        end

    elseif currentState == states.SELECTING_BLUEPRINT then
        if selection.isEternal then
            API.logInfo("Selecting Eternal reinforcement blueprint: " .. tostring(selection.id))
        else
            API.logInfo("Selecting " .. building .. " Tier " .. tostring(tier)
                .. " blueprint: " .. tostring(selection.id))
        end

        API.DoAction_Interface(
            0xffffffff,
            0xffffffff,
            1,
            1371,
            22,
            selection.id,
            API.OFF_ACT_GeneralInterface_route
        )

        currentState = states.CONFIRMING_BLUEPRINT

    elseif currentState == states.CONFIRMING_BLUEPRINT then
        API.logInfo("Confirming selected Fort blueprint.")

        API.DoAction_Interface(
            0xffffffff,
            0xffffffff,
            0,
            1370,
            30,
            -1,
            API.OFF_ACT_GeneralInterface_Choose_option
        )

        currentHotspot = nil
        activeBuilding = selection.isEternal and nil or building
        blueprintResultChecks = 0
        currentState = states.WAITING_FOR_BLUEPRINT_RESULT

    elseif currentState == states.WAITING_FOR_BLUEPRINT_RESULT then
        blueprintResultChecks = blueprintResultChecks + 1

        if selection.isEternal then
            local hotspot, hotspotName, hotspotBuilding = FindAnyFortHotspot()
            if hotspot then
                API.logInfo("Eternal reinforcement hotspot found: " .. hotspotName
                    .. " | ID: " .. tostring(hotspot.id)
                    .. " | (" .. tostring(hotspot.x) .. "," .. tostring(hotspot.y) .. ")"
                    .. " | building: " .. tostring(hotspotBuilding or "unmapped") .. ".")
                currentHotspot = hotspot
                activeBuilding = hotspotBuilding
                currentState = states.TRAVELLING_TO_BUILDING
                return
            end

            if blueprintResultChecks >= 20 then
                FortConstruction.Stop("Eternal reinforcement blueprint was confirmed, but no Fort construction hotspot appeared.")
            end
            return
        end

        if HasActiveBlueprintDialog() then
            FortConstruction.Stop(
                "An existing Fort building blueprint is active, but no construction hotspot was found to resume it."
            )
            return
        end

        if blueprintResultChecks >= 5 then
            currentState = states.TRAVELLING_TO_BUILDING
        end

    elseif currentState == states.TRAVELLING_TO_BUILDING then
        -- If startup/resume already found a hotspot, its actual coordinates are
        -- authoritative. Do not route based on the selected building area first.
        if currentHotspot then
            local player = API.PlayerCoord()
            local playerSide = player and GetSideFromX(player.x) or nil
            local hotspotSide = GetHotspotSide(currentHotspot)

            if not player or not playerSide then
                FortConstruction.Stop("Player location could not be determined while travelling to an existing hotspot.")
                return
            end

            if not hotspotSide then
                FortConstruction.Stop("Existing Fort hotspot location could not be determined while travelling.")
                return
            end

            if playerSide ~= hotspotSide then
                if not EnsurePlayerSide(hotspotSide) then
                    return
                end

                -- Re-read player coordinates on the next tick after crossing the gate.
                return
            end

            local dx = currentHotspot.x - player.x
            local dy = currentHotspot.y - player.y
            local distance = math.sqrt(dx * dx + dy * dy)

            if distance <= MAX_WALK_STEP then
                API.logInfo("Fort travel: existing hotspot reached interaction range"
                    .. " | player (" .. tostring(player.x) .. "," .. tostring(player.y) .. ")"
                    .. " | hotspot (" .. tostring(currentHotspot.x) .. "," .. tostring(currentHotspot.y) .. ").")
                currentState = states.CLICKING_HOTSPOT
            elseif not API.IsPlayerMoving_() then
                WalkTowardsPoint(currentHotspot.x, currentHotspot.y, "Fort travel: existing hotspot")
            end
        else
            if selection.isEternal then
                -- Eternal should never route to a fixed building area. Wait for
                -- the generated hotspot instead.
                currentState = states.WAITING_FOR_BLUEPRINT_RESULT
                return
            end

            if not buildingArea then
                FortConstruction.Stop("No Fort area exists for " .. targetBuilding .. ".")
                return
            end

            -- New blueprint flow: no hotspot existed at startup. Route to the
            -- selected building as before; Grove Cabin may require the Side gate.
            local targetSide = GetBuildingSide(targetBuilding)

            if not EnsurePlayerSide(targetSide) then
                return
            end

            if IsPlayerInArea(buildingArea) then
                API.logInfo("Fort travel: " .. targetBuilding .. " area reached"
                    .. " | side: " .. targetSide .. ".")
                currentState = states.FINDING_HOTSPOT
            elseif not API.IsPlayerMoving_() then
                WalkToBuildingArea(buildingArea)
            end
        end

    elseif currentState == states.FINDING_HOTSPOT then
        if not buildingArea then
            FortConstruction.Stop("No Fort area exists for " .. targetBuilding .. ".")
            return
        end

        local hotspot, hotspotName = FindBestHotspot(buildingArea)
        if not hotspot then
            FortConstruction.Stop("No Fort construction hotspot was found after blueprint confirmation.")
            return
        end

        API.logInfo("Fort hotspot found: " .. hotspotName
            .. " | ID: " .. tostring(hotspot.id)
            .. " | (" .. tostring(hotspot.x) .. "," .. tostring(hotspot.y) .. ")")

        currentHotspot = hotspot
        currentState = states.CLICKING_HOTSPOT

    elseif currentState == states.CLICKING_HOTSPOT then
        API.logInfo("Sending Build action to Fort hotspot at ("
            .. tostring(currentHotspot.x) .. "," .. tostring(currentHotspot.y) .. ").")
        API.DoAction_Object2(
            0x29,
            API.OFF_ACT_GeneralObject_route0,
            { currentHotspot.id },
            30,
            WPOINT.new(currentHotspot.x, currentHotspot.y, currentHotspot.floor)
        )

        -- Match the Fort reference flow: let the player reach the clicked
        -- hotspot before scanning for its next position.
        API.RandomSleep2(600, 800, 1000)
        API.WaitUntilMovingEnds()
        API.logInfo("Fort Build action sent. Monitoring hotspot movement.")
        currentState = states.MONITORING_HOTSPOT

    elseif currentState == states.MONITORING_HOTSPOT then
        local hotspot, hotspotName
        if selection.isEternal then
            hotspot, hotspotName = FindAnyFortHotspot()
        else
            if not buildingArea then
                FortConstruction.Stop("No Fort area exists for " .. targetBuilding .. ".")
                return
            end
            hotspot, hotspotName = FindBestHotspot(buildingArea)
        end

        if not hotspot then
            API.logInfo("No Fort construction hotspot remains. Preparing the GUI-selected blueprint.")
            currentHotspot = nil
            activeBuilding = nil
            currentState = states.CHECKING_MATERIALS
        else
            if IsDifferentHotspot(currentHotspot, hotspot) then
                API.logInfo("Fort hotspot moved: " .. hotspotName
                    .. " | ID: " .. tostring(hotspot.id)
                    .. " | (" .. tostring(hotspot.x) .. "," .. tostring(hotspot.y) .. ").")
                currentHotspot = hotspot

                if selection.isEternal then
                    activeBuilding = GetBuildingForHotspot(hotspot)
                    currentState = states.TRAVELLING_TO_BUILDING
                else
                    currentState = states.CLICKING_HOTSPOT
                end
            end
        end

    elseif currentState == states.RETURNING_TO_BANK then
        API.logInfo("No optimal Fort hotspots remain. Returning to the Workshop bank for the next build.")

        if not OpenFortBank() then
            return
        end

        currentState = states.BANKING
    end

    API.RandomSleep2(650, 450, 800)
end

function FortConstruction.Stop(reason)
    running = false
    paused = false
    Functions.Stop("Fort Forinthry Construction", reason)
end

function FortConstruction.IsRunning()
    return running
end

return FortConstruction
