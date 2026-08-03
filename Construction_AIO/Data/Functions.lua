--=========================================================================--
-- Construction AIO
--
-- Functions.lua
--
-- Central location for all Functions used by the Construction AIO.
--
--=========================================================================--

local API = require("api")
local Data = require("Data.Data")

local Functions = {}
local pauseRequested = false
local stopRequested = false
local sleepStateFailCount = 0

local SURGE_ID = 14233
local DIVE_ID = 23714
local TRAVEL_ABILITY_MIN_DISTANCE = 15
local TRAVEL_ABILITY_STEP = 9
local TRAVEL_ABILITY_DELAY = 650

local function SleepUntilWithoutChecks(conditionFunc, timeout, message, checkLoopy, ...)

    local startTime = os.time()

    while not conditionFunc(...) do
        API.DoRandomEvents()

        if os.difftime(os.time(), startTime) >= timeout then
            print("Stopped waiting for " .. message .. " after " .. timeout .. " seconds.")
            return false
        end

        if checkLoopy and not API.Read_LoopyLoop() then
            print("Script exited - breaking sleep.")
            return false
        end

        API.RandomSleep2(50, 0, 0)
    end

    print("Sleep condition met for " .. message)
    return true

end

local function HasValidGameState()

    if API.GetGameState2() ~= 3 and sleepStateFailCount > 5 then
        print("Not logged in after repeated checks.")
        API.Write_LoopyLoop(false)
        return false
    elseif API.GetGameState2() ~= 3 then
        SleepUntilWithoutChecks(function()
            return API.GetGameState2() == 3
        end, 5, "state change to 3", true)
        print("Not logged in " .. tostring(sleepStateFailCount))
        sleepStateFailCount = sleepStateFailCount + 1
    end

    if not API.Read_LoopyLoop() then
        print("LoopyLoop is false")
        return false
    end

    return true

end

-- Sleeps until a condition succeeds, while preserving the existing Plank
-- module checks for random events, script exit, and game state.
---@param conditionFunc function
---@param timeout number
---@param message string
---@param ... any
---@return boolean
function Functions.SleepUntil(conditionFunc, timeout, message, ...)

    local startTime = os.time()

    while not conditionFunc(...) do
        API.DoRandomEvents()

        if os.difftime(os.time(), startTime) >= timeout then
            print("Stopped waiting for " .. message .. " after " .. timeout .. " seconds.")
            return false
        end

        if not API.Read_LoopyLoop() then
            print("Script exited - breaking sleep.")
            return false
        end

        if not HasValidGameState() then
            print("State checks failed - breaking sleep.")
            return false
        end

        API.RandomSleep2(50, 0, 0)
    end

    print("Sleep condition met for " .. message)
    return true

end

local function IsAbilityReady(abilityId)

    local ability = API.GetABs_id(abilityId)

    return ability
        and ability.id ~= 0
        and ability.enabled
        and ability.cooldown_timer < 1

end

local function GetTravelAbilityTarget(destination)

    local player = API.PlayerCoord()

    if player.z ~= destination.z then
        return nil, 0
    end

    local dx = destination.x - player.x
    local dy = destination.y - player.y
    local distance = math.sqrt(dx * dx + dy * dy)

    if distance <= 1 then
        return nil, distance
    end

    local step = math.min(TRAVEL_ABILITY_STEP, distance - 1)

    return WPOINT.new(
        math.floor(player.x + (dx / distance) * step),
        math.floor(player.y + (dy / distance) * step),
        player.z
    ), distance

end

local function TrySurgeTo(destination, label)

    if not IsAbilityReady(SURGE_ID) then
        return false
    end

    local abilityTarget = GetTravelAbilityTarget(destination)
    if not abilityTarget then
        return false
    end

    if API.DoAction_Surge_Tile(abilityTarget, 1) then
        API.logInfo(string.format(
            "Travel ability: %s naar (%d,%d).",
            label,
            abilityTarget.x,
            abilityTarget.y
        ))
        API.RandomSleep2(TRAVEL_ABILITY_DELAY, 50, 50)
        return true
    end

    API.logDebug("Travel ability: " .. label .. " kon niet gebruikt worden.")
    return false

end

local function TryDiveTo(destination)

    if not IsAbilityReady(DIVE_ID) then
        return false
    end

    local abilityTarget = GetTravelAbilityTarget(destination)
    if not abilityTarget then
        return false
    end

    if API.DoAction_Dive_Tile(abilityTarget) then
        API.logInfo(string.format(
            "Travel ability: Dive naar (%d,%d).",
            abilityTarget.x,
            abilityTarget.y
        ))
        API.RandomSleep2(TRAVEL_ABILITY_DELAY, 50, 50)
        return true
    end

    API.logDebug("Travel ability: Dive kon niet gebruikt worden.")
    return false

end

function Functions.TryTravelMovementAbility(target)

    if not target then
        return false
    end

    local _, initialDistance = GetTravelAbilityTarget(target)
    if initialDistance < TRAVEL_ABILITY_MIN_DISTANCE then
        return false
    end

    local firstSurgeUsed = TrySurgeTo(target, "Surge 1")
    local diveUsed = false
    local secondSurgeUsed = false

    -- Surge changes the player position. Recheck the remaining distance before
    -- using another ability, otherwise a short route can consume Surge + Dive.
    local _, distanceBeforeDive = GetTravelAbilityTarget(target)
    if distanceBeforeDive >= TRAVEL_ABILITY_MIN_DISTANCE then
        diveUsed = TryDiveTo(target)
    end

    local _, distanceBeforeSecondSurge = GetTravelAbilityTarget(target)
    if firstSurgeUsed and distanceBeforeSecondSurge >= TRAVEL_ABILITY_MIN_DISTANCE then
        secondSurgeUsed = TrySurgeTo(target, "Surge 2")
    end

    if not firstSurgeUsed and not diveUsed and not secondSurgeUsed then
        API.logDebug("Travel abilities niet beschikbaar of niet geaccepteerd.")
        return false
    end

    -- Na elke ability is de doeltegel opnieuw bepaald. Hervat nu de route
    -- naar het oorspronkelijke loopdoel vanaf de actuele spelerpositie.
    API.DoAction_Tile(WPOINT.new(target.x, target.y, target.z))
    return true

end

function Functions.RequestPause()
    pauseRequested = true
end

function Functions.RequestStop()
    stopRequested = true
end

function Functions.ConsumePause()
    if pauseRequested then
        pauseRequested = false
        return true
    end

    return false
end

function Functions.ConsumeStop()
    if stopRequested then
        stopRequested = false
        return true
    end

    return false
end

function Functions.HasPendingRequest()
    return pauseRequested or stopRequested
end

--========================================================================--
-- Bank functions
--========================================================================--
function Functions.HandleBankPin(config)
    API.logDebug("=== Bank pin Handler Started ===")

    --API.logDebug("UseBankPin =", tostring(config.UseBankPin))
    --API.logDebug("BankPin    = '" .. tostring(config.BankPin) .. "'")

    if not API.GetInterfaceOpenBySize(759) then
        return true
    end
    API.logInfo("Bank PIN gedetecteerd.")

    if not config.UseBankPin then
        API.logError("Bank PIN gedetecteerd, maar 'Use Bank PIN' staat uit.")
        return false
    end

    if config.BankPin == "" then
        API.logError("Bank PIN gedetecteerd, maar er is geen Bank PIN ingesteld.")
        return false
    end

    if not config.UseBankPin or config.BankPin == "" then
        return false
    end

    API.DoBankPin(config.BankPin)
    --API.logDebug("PIN verzonden:", config.BankPin)

    local timeout = os.clock() + 5

    while os.clock() < timeout do

        if not API.GetInterfaceOpenBySize(759) then
            API.logDebug("Bank PIN ingevoerd.")
            return true
        end

        API.RandomSleep2(200, 300, 100)

    end

    return false

end

--========================================================================--
-- Item reading functions
--========================================================================--
function Functions.GetRealItemAmount(ItemName)

    local Total = 0

    for _, Item in ipairs(Inventory:GetItems()) do
        if Item.name == ItemName then
            Total = Total + Item.amount
        end
    end

    return Total

end

--========================================================================--
-- Building interface functions
--========================================================================--
local PlankIDs = Data.Items.PlankIds
local NailNames = Data.Items.NailNames
local PLANK_BOX_CONTAINER = Data.Items.Containers.PlankBox

function Functions.GetNailAmount()
    local total = 0

    for _, name in ipairs(NailNames) do
        total = total + Functions.GetRealItemAmount(name)
    end

    return total
end

function Functions.GetPlankAmountDetails(ItemName)
    local inventoryAmount = Functions.GetRealItemAmount(ItemName)
    local plankBoxAmount = 0
    local itemID = PlankIDs[ItemName]

    if not itemID then
        return inventoryAmount, plankBoxAmount, inventoryAmount
    end

    -- Container 895 can retain stale data after the Plank box leaves inventory.
    -- Only count that container when the player is actually carrying the box.
    if Functions.GetRealItemAmount("Plank box") <= 0 then
        return inventoryAmount, plankBoxAmount, inventoryAmount
    end

    -- The plank box contents change after each build, so read it again here.
    local boxItems = API.Container_Get_all(PLANK_BOX_CONTAINER)
    if boxItems then
        for _, item in pairs(boxItems) do
            if item.item_id == itemID then
                plankBoxAmount = plankBoxAmount + item.item_stack
            end
        end
    end

    return inventoryAmount, plankBoxAmount, inventoryAmount + plankBoxAmount
end

function Functions.GetPlankAmount(ItemName)
    local _, _, total = Functions.GetPlankAmountDetails(ItemName)
    return total
end

function Functions.ParseRequiredMaterials(Text)

    local Materials = {}

    for Line in Text:gmatch("[^\n]+") do

        local ItemName, Needed = Line:match("(.+):%s*(%d+)")

        if ItemName and Needed then

            table.insert(Materials, {
                Name = ItemName,
                Needed = tonumber(Needed)
            })

        end

    end

    return Materials

end

function Functions.HasRequiredMaterials(Materials)

    local allMaterialsAvailable = true

    for _, Material in ipairs(Materials) do

        local Have

        if Material.Name == "Nails" then
            Have = Functions.GetNailAmount()
        elseif PlankIDs[Material.Name] then
            Have = Functions.GetPlankAmount(Material.Name)
        else
            Have = Functions.GetRealItemAmount(Material.Name)
        end

        API.logDebug(string.format(
            "%s | Nodig: %d | Aanwezig: %d",
            Material.Name, Material.Needed, Have
        ))

        if Have < Material.Needed then
            allMaterialsAvailable = false
        end

    end

    return allMaterialsAvailable

end

function Functions.GetFirstBuildableOption(Builds)

    local preferredMaterials = nil

    for Build = #Builds, 1, -1 do

        API.logDebug("Controle build:", Build)

        local widgets = API.ScanForInterfaceTest2Get(false, Builds[Build].Path)
        local info = widgets and widgets[1]

        if not info or not info.textids then
            API.logDebug("  -> Materialen niet gevonden.")
        else
            local text = info.textids:gsub("<br>", "\n")
            local Materials = Functions.ParseRequiredMaterials(text)

            if not preferredMaterials then
                preferredMaterials = Materials
            end

            API.logDebug("  -> Materialen gevonden:", #Materials)

            if Functions.HasRequiredMaterials(Materials) then
                API.logDebug("  -> Deze build is mogelijk:", Build)
                return Build, Info, Materials
            else
                API.logDebug("  -> Onvoldoende materialen.")
            end
        end

    end

    return nil, nil, preferredMaterials

end

function Functions.SelectBuildOption(Build)

    if not Build then
        return false
    end

    -- The scanned text widget has no clickable id. The build interface supports
    -- keys 1 through 5, which map directly to its five build choices.
    API.logInfo("Selecteer build-optie via sneltoets: " .. tostring(Build))
    return API.KeyboardPress2(0x30 + Build, 60, 100)

end

function Functions.HandleBuildInterface()
    API.logDebug("=== HandleBuildInterface ===")
    local Build, Widget, Materials = Functions.GetFirstBuildableOption(Data.Interfaces.Builds)

    API.logDebug("Build gevonden:", Build)

    if Materials then
        API.logInfo("Benodigde materialen:")
        for _, material in ipairs(Materials) do
            API.logInfo(" - " .. material.Name .. ": " .. material.Needed)
        end
    else
        API.logDebug("Geen materialen teruggekregen.")
    end

    if not Build then
        API.logDebug("HandleBuildInterface -> return false (if not Build then)")
        return false, Materials
    end

    if not Functions.SelectBuildOption(Build) then
        API.logDebug("HandleBuildInterface -> return false (if not Functions.SelectBuildOption(Build) then)")
        return false
    end

    API.RandomSleep2(600, 200, 300)
    API.logDebug("HandleBuildInterface -> return", Build)
    return Build

end


--------------------------------------------------------------------------------
-- Stop Module
--------------------------------------------------------------------------------
function Functions.Stop(moduleName, reason, context)

    API.logError("===================================")
    API.logError("Construction bot gestopt.")
    API.logError("===================================")
    API.logError("Module : " .. tostring(moduleName))

    if context then
        if context.contract then
            API.logError("Contract : " .. tostring(context.contract))
        end

        if context.npc then
            API.logError("NPC      : " .. tostring(context.npc))
        end

        if context.player then
            API.logError("Player   : " .. tostring(context.player.x) .. ", "
                .. tostring(context.player.y) .. ", floor " .. tostring(context.player.z))
        end

        local target = context.repairTarget
        if target then
            API.logError("Doelobject: " .. tostring(target.name)
                .. " | ID: " .. tostring(target.id))
            API.logError("Objectlocatie: " .. tostring(target.x)
                .. ", " .. tostring(target.y)
                .. ", floor " .. tostring(target.floor))
            API.logError(string.format("Afstand bij selectie: %.2f", target.distance))
        elseif context.showRepairTarget then
            API.logError("Doelobject: geen")
        end
    end

    API.logError("Reason : " .. tostring(reason))
    API.logError("===================================")

end

return Functions
