local ConstructionMaterials = {}

local running = false
local paused = false

local API = require("api")
local Data = require("Data.Data")
local Config = require("Config")
local Functions = require("Data.Functions")

local states = {
    CHECKING = 1,
    BANKING = 2,
    USING_SAWMILL = 3,
    WAITING_FOR_PROCESS = 4
}

local currentState = states.CHECKING

local function TransitionPause(label, base, minimum, maximum)
    API.logDebug("Transition pause: " .. label)
    API.RandomSleep2(base, minimum, maximum)
end

local function IsInArea(area)
    local player = API.PlayerCoord()

    return player
        and player.x >= area.x1
        and player.x <= area.x2
        and player.y >= area.y1
        and player.y <= area.y2
end

local function ResolveSawmillLocation()
    local inHome = IsInArea(Data.TownAreas["Home"])
    local inFort = IsInArea(Data.TownAreas["Fort Forinthry"])

    if Config.ConstructionMaterialType == 0 then
        if inFort then
            if not Config.PlanksAtFortForinthry then
                Config.PlanksAtFortForinthry = true
                Config.Save()
                API.logInfo("Fort Forinthry detected. Enabled the Fort plank toggle automatically.")
            end
            return true
        end

        if inHome then
            if Config.PlanksAtFortForinthry then
                Config.PlanksAtFortForinthry = false
                Config.Save()
                API.logInfo("Home detected. Disabled the Fort plank toggle automatically.")
            end
            return true
        end

        return false, "Plank production must start in Home or Fort Forinthry."
    end

    if Config.ConstructionMaterialType == 1 then
        if inFort then
            return true
        end

        return false, "Refined planks must start in Fort Forinthry."
    end

    if Config.ConstructionMaterialType == 2 then
        if inFort then
            return true
        end

        return false, "Frames must start in Fort Forinthry."
    end

    if Config.ConstructionMaterialType == 3 then
        if inFort then
            return true
        end

        return false, "Stone cutting must start in Fort Forinthry."
    end

    return true
end

local function GetRecipe()
    if Config.ConstructionMaterialType == 0 then
        local material = Data.Items.Materials[Config.PlankType]

        if not material then
            return nil, "Invalid plank type selected."
        end

        return {
            name = material.Name .. " plank",
            input = material.Log,
            output = material.Plank,
            required = 1,
            fort = Config.PlanksAtFortForinthry == true,
            stationName = "Sawmill",
            stationAction = "Process planks"
        }
    end

    if Config.ConstructionMaterialType == 1 then
        local material = Data.Items.RefinedMaterials[Config.RefinedPlankType]

        if not material then
            return nil, "Invalid refined plank type selected."
        end

        local inputName
        if material.Name == "Refined planks" then
            inputName = "Plank"
        else
            inputName = material.Name:gsub("^Refined ", ""):gsub(" planks$", " plank")
        end

        return {
            name = material.Name,
            input = material.Input,
            inputName = inputName,
            output = material.Output,
            required = material.Required,
            fort = true,
            usesPlankBox = true,
            stationName = "Sawmill",
            stationAction = "Process planks"
        }
    end

    if Config.ConstructionMaterialType == 2 then
        local material = Data.Items.FrameMaterials[Config.FrameType]

        if not material then
            return nil, "Invalid frame type selected."
        end

        return {
            name = material.Name,
            input = material.Input,
            output = material.Output,
            required = material.Required,
            fort = true,
            stationName = "Woodworking bench",
            stationAction = "Construct frames"
        }
    end

    if Config.ConstructionMaterialType == 3 then
        return {
            name = "Stone wall segment",
            input = Data.Items.Stone.Limestone,
            required = 4,
            fort = true,
            stationName = "Stonecutter",
            stationAction = "Cut stone"
        }
    end

    return nil, "This material type is not implemented yet. Select Planks, Refined planks, Frames, or Stone cutter."
end

local function IsCraftingInterfaceOpen()
    return API.Compare2874Status(40, false)
end

local function GetRecipeInputCounts(recipe)
    if recipe.usesPlankBox then
        return Functions.GetPlankItemAmountDetails(recipe.input)
    end

    local inventoryAmount = Inventory:InvItemcount(recipe.input)
    return inventoryAmount, 0, inventoryAmount
end

local function LogRecipeInputCounts(recipe, prefix)
    local inventoryAmount, plankBoxAmount, total = GetRecipeInputCounts(recipe)

    API.logInfo(string.format(
        "%s%s | Inventory: %d | Plank box: %d | Total: %d",
        prefix or "",
        recipe.inputName or recipe.name,
        inventoryAmount,
        plankBoxAmount,
        total
    ))

    return total
end

local function GetBankObject(recipe)
    if recipe.fort then
        return Data.Objects.FortBank
    end

    return Data.Objects.Bank
end

local function StopForInvalidRecipe(reason)
    ConstructionMaterials.Stop(reason)
end

local function Banking(recipe)
    local bankObject = GetBankObject(recipe)

    TransitionPause("before banking", 900, 250, 450)

    ------------------------------------------------------------------------
    -- LOAD LAST PRESET
    --
    -- If a Plank box is already in the inventory, Load last preset is not
    -- allowed for Refined planks. Disable the toggle, warn the user, and
    -- immediately continue into the normal manual banking flow below.
    --
    -- If there is no Plank box in the inventory, load the preset normally
    -- and continue to production once the selected planks are in inventory.
    ------------------------------------------------------------------------
    if Config.LoadLastPreset then
        if recipe.usesPlankBox and Functions.HasPlankBox() then
            Config.LoadLastPreset = false
            Config.Save()
            API.logWarn("Can't use load last preset with a plank box.")
            API.logInfo("Load last preset disabled. Continuing with manual banking.")
            -- Do not return: fall through directly into MANUAL BANKING below.
        else
            API.logInfo("Loading last preset.")
            API.DoAction_Object1(0x33, API.OFF_ACT_GeneralObject_route3, { bankObject }, 50)

            local presetLoaded = Functions.SleepUntil(function()
                return Inventory:InvItemcount(recipe.input) >= recipe.required
            end, 6, "preset inventory")

            if not presetLoaded then
                ConstructionMaterials.Stop("Last preset did not load enough of the selected input material.")
                return
            end

            API.logInfo(string.format(
                "Load last preset: inventory ready | %s: %d",
                recipe.inputName or recipe.name,
                Inventory:InvItemcount(recipe.input)
            ))

            TransitionPause("after preset", 1200, 350, 600)
            currentState = states.CHECKING
            return
        end
    end

    ------------------------------------------------------------------------
    -- MANUAL BANKING
    --
    -- No preset: manage materials ourselves. For Refined planks, take a
    -- Plank box from the bank when one is available and fill it. Otherwise
    -- continue with inventory only.
    ------------------------------------------------------------------------
    if not Bank:IsOpen() then
        if not API.DoAction_Object1(0x2e, API.OFF_ACT_GeneralObject_route1, { bankObject }, 50) then
            return
        end

        if not Functions.SleepUntil(function()
            return Bank:IsOpen() or Bank:IsPINOpen()
        end, 5, "bank open") then
            ConstructionMaterials.Stop("Failed to open the selected bank.")
            return
        end
    end

    if Bank:IsPINOpen() then
        if not Functions.HandleBankPin(Config) then
            ConstructionMaterials.Stop("Bank PIN handling failed.")
        end
        return
    end

    if not Inventory:IsEmpty() then
        if not Bank:DepositInventory() then
            ConstructionMaterials.Stop("Failed to deposit inventory.")
            return
        end

        if not Functions.SleepUntil(function()
            return Inventory:IsEmpty()
        end, 5, "deposit inventory") then
            ConstructionMaterials.Stop("Inventory did not empty at the bank.")
            return
        end
    end

    if recipe.usesPlankBox and Bank:Contains(Data.Items.misc.plank_box) then
        API.logInfo("Manual banking: Plank box found in bank. Withdrawing it.")

        if not Bank:Withdraw(Data.Items.misc.plank_box, 1) then
            ConstructionMaterials.Stop("Failed to withdraw the Plank box.")
            return
        end

        if not Functions.SleepUntil(function()
            return Functions.HasPlankBox()
        end, 5, "withdraw Plank box") then
            ConstructionMaterials.Stop("Plank box did not appear in inventory.")
            return
        end

        API.logInfo("Manual banking: filling Plank box from bank.")

        if not Functions.FillPlankBoxFromBank(recipe.input, 6) then
            local boxAmount = Functions.GetPlankBoxAmount(recipe.input)
            ConstructionMaterials.Stop(string.format(
                "Plank box was not filled. %s in box: %d/%d.",
                recipe.inputName or recipe.name,
                boxAmount,
                Data.Items.Containers.PlankBoxCapacityPerType
            ))
            return
        end

        API.logInfo(string.format(
            "Manual banking: Plank box full | %s: %d/%d",
            recipe.inputName or recipe.name,
            Functions.GetPlankBoxAmount(recipe.input),
            Data.Items.Containers.PlankBoxCapacityPerType
        ))
    elseif recipe.usesPlankBox then
        API.logInfo("Manual banking: no Plank box found in bank. Filling inventory with planks only.")
    end

    -- Always fill the remaining inventory with the selected input material.
    -- Do not use WithdrawAll here: explicitly withdraw the number of free slots.
    API.logInfo("Manual banking: filling remaining inventory slots with " .. (recipe.inputName or recipe.name) .. ".")

    local inventoryFilled, inventoryAfter = Functions.FillInventoryFromBank(recipe.input, 6)
    if not inventoryFilled then
        ConstructionMaterials.Stop("Failed to fill the inventory with loose planks after filling the Plank box.")
        return
    end

    API.logInfo(string.format(
        "Manual banking: inventory filled | %s inventory: %d | Plank box: %d",
        recipe.inputName or recipe.name,
        inventoryAfter,
        recipe.usesPlankBox and Functions.GetPlankBoxAmount(recipe.input) or 0
    ))

    if not Functions.SleepUntil(function()
        local _, _, total = GetRecipeInputCounts(recipe)
        return total >= recipe.required
    end, 5, "materials available after banking") then
        ConstructionMaterials.Stop("Input material did not appear in inventory or Plank box.")
        return
    end

    LogRecipeInputCounts(recipe, "Materials ready: ")

    API.KeyboardPress2(0x1B, 50, 0)
    if not Functions.SleepUntil(function()
        return not Bank:IsOpen()
    end, 5, "close bank") then
        ConstructionMaterials.Stop("Bank did not close.")
        return
    end

    TransitionPause("after banking", 1600, 500, 800)
    currentState = states.CHECKING
end

local function OpenFortStation(recipe)
    if not Interact or not Interact.Object then
        ConstructionMaterials.Stop("Interact:Object is unavailable for the Fort production station.")
        return false
    end

    API.logInfo("Opening Fort " .. recipe.stationName .. ": " .. recipe.stationAction .. ".")
    local success, result = pcall(function()
        return Interact:Object(recipe.stationName, recipe.stationAction, nil, 50)
    end)

    if not success or result == false then
        ConstructionMaterials.Stop("Could not use the Fort " .. recipe.stationName .. ".")
        return false
    end

    return true
end

local function OpenHomeSawmill()
    API.logInfo("Opening Home sawmill.")
    return API.DoAction_Object1(
        0xae,
        API.OFF_ACT_GeneralObject_route0,
        { Data.Objects.Sawmill },
        50
    )
end

local function UseSawmill(recipe)
    if API.IsPlayerMoving_() or API.isProcessing() then
        return
    end

    TransitionPause("before sawmill", 900, 250, 450)
    local opened = recipe.fort and OpenFortStation(recipe) or OpenHomeSawmill()
    if not opened then
        return
    end

    if not Functions.SleepUntil(IsCraftingInterfaceOpen, 10, "production interface") then
        ConstructionMaterials.Stop("Production interface did not open.")
        return
    end

    if recipe.usesPlankBox then
        LogRecipeInputCounts(recipe, "Production interface: ")

        if not Functions.SelectRefinedPlankOption(Config.RefinedPlankType, recipe.name) then
            ConstructionMaterials.Stop("Failed to select the refined plank option from the GUI selection.")
            return
        end

        API.logInfo("Refined plank option selected. Pressing Space to Construct " .. recipe.name .. ".")
        API.RandomSleep2(300, 150, 150)
        API.KeyboardPress32(0x20, 0)
    else
        API.logInfo("Production interface opened. Pressing Space to start " .. recipe.name .. ".")
        API.KeyboardPress32(0x20, 0)
    end

    if not Functions.SleepUntil(function()
        return API.isProcessing()
    end, 5, "production processing") then
        ConstructionMaterials.Stop("Production did not start after selecting the production option.")
        return
    end

    currentState = states.WAITING_FOR_PROCESS
end

local function WaitingForProcess(recipe)
    if API.isProcessing() then
        return
    end

    -- Refined planks: once production has stopped, bank immediately when
    -- the inventory is full of produced refined planks. Do not walk back
    -- to the Sawmill for another production cycle first.
    if recipe.usesPlankBox
        and recipe.output
        and Inventory:IsFull()
        and Inventory:InvItemcount(recipe.output) > 0 then

        API.logInfo(string.format(
            "Production finished. Inventory is full with %s (%d). Banking.",
            recipe.name,
            Inventory:InvItemcount(recipe.output)
        ))

        TransitionPause("after full refined plank inventory", 1500, 500, 800)
        currentState = states.BANKING
        return
    end

    API.logInfo("Production finished. Rechecking inventory.")
    TransitionPause("after production", 1500, 500, 800)
    currentState = states.CHECKING
end

local function Checking(recipe)
    local inventoryAmount, plankBoxAmount, inputCount = GetRecipeInputCounts(recipe)

    if recipe.usesPlankBox then
        API.logInfo(string.format(
            "%s | required: %d | inventory: %d | Plank box: %d | total: %d",
            recipe.name,
            recipe.required,
            inventoryAmount,
            plankBoxAmount,
            inputCount
        ))
    else
        API.logInfo(recipe.name .. " | required: " .. recipe.required .. " | inventory: " .. inputCount)
    end

    if inputCount >= recipe.required then
        currentState = states.USING_SAWMILL
    else
        API.logWarn("Selected input material is missing or insufficient. Banking before production.")
        currentState = states.BANKING
    end
end

function ConstructionMaterials.Start()
    local locationOk, locationReason = ResolveSawmillLocation()
    if not locationOk then
        ConstructionMaterials.Stop(locationReason)
        return
    end

    local recipe, reason = GetRecipe()
    if not recipe then
        ConstructionMaterials.Stop(reason)
        return
    end

    API.logInfo("Construction Materials started: " .. recipe.name)
    API.logInfo("ConstructionMaterials version: SHARED_HELPERS_02")
    running = true
    paused = false
    currentState = states.CHECKING
end

function ConstructionMaterials.Pause()
    paused = true
end

function ConstructionMaterials.Resume()
    paused = false
end

function ConstructionMaterials.IsPaused()
    return paused
end

function ConstructionMaterials.Tick()
    if not running or paused then
        return
    end

    local locationOk, locationReason = ResolveSawmillLocation()
    if not locationOk then
        ConstructionMaterials.Stop(locationReason)
        return
    end

    local recipe, reason = GetRecipe()
    if not recipe then
        ConstructionMaterials.Stop(reason)
        return
    end

    if currentState == states.CHECKING then
        Checking(recipe)
    elseif currentState == states.BANKING then
        Banking(recipe)
    elseif currentState == states.USING_SAWMILL then
        UseSawmill(recipe)
    elseif currentState == states.WAITING_FOR_PROCESS then
        WaitingForProcess(recipe)
    end
end

function ConstructionMaterials.Stop(reason)
    running = false
    paused = false
    Functions.Stop("Construction Materials", reason)
end

function ConstructionMaterials.IsRunning()
    return running
end

return ConstructionMaterials
