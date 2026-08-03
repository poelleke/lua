local Planks = {}

local running = false
local paused = false
local ShouldContinue = false

local API = require("api")

local Data = require("Data.Data")
local Config = require("Config")
local Functions = require("Data.Functions")

local states = {
    BANKING = 1,
    CLICK_SAWMILL = 2,
    CLEANING_UP = 3,
    CHECKING = 4
}

local currentState = states.CHECKING

local function Banking()
    local material = Data.Items.Materials[Config.PlankType]

    ------------------------------------------------------------------------
    -- Load Last Preset
    ------------------------------------------------------------------------
    if Config.LoadLastPreset then

        if API.DoAction_Object1(0x33, API.OFF_ACT_GeneralObject_route3, {Data.Objects.Bank}, 50) then

            if Functions.SleepUntil(function()

                return Inventory:InvItemcount(material.Log) >= 15

            end, 5, "load preset") then

                currentState  = states.CHECKING
                return

            end

        end

        API.logWarn("Preset failed. Switching to manual banking.")

        Config.LoadLastPreset = false
        Config.Save()

    end

    ------------------------------------------------------------------------
    -- Open Bank
    ------------------------------------------------------------------------
    if not Bank:IsOpen() then

        if not API.DoAction_Object1(0x2e,API.OFF_ACT_GeneralObject_route1,{ Data.Objects.Bank },50)then
            return
        end

        if not Functions.SleepUntil(function()

            --API.logDebug("Open:", Bank:IsOpen(), "PIN:", Bank:IsPINOpen())

            return Bank:IsOpen() or Bank:IsPINOpen()

        end, 5, "bank open") then

            API.logError("Failed to open bank.")
            return
        end

        API.RandomSleep2(1200, 500, 800)
        
    -- Only the module currently banking handles a PIN screen.
        if Bank:IsPINOpen() then
            if not Functions.HandleBankPin(Config) then
                Planks.Stop("Bank PIN handling failed.")
            end
            return
        end

    end

    ------------------------------------------------------------------------
    -- Deposit Inventory
    ------------------------------------------------------------------------
    if not Inventory:IsEmpty() then

    if not Bank:DepositInventory() then

        API.logError("Failed to deposit inventory.")
        return

    end

    if not Functions.SleepUntil(function()

        return Inventory:IsEmpty()

    end, 5, "deposit inventory") then

        API.logError("Failed to deposit inventory.")
        return

    end

    -- Let the bank interface update briefly.
    API.RandomSleep2(1200, 500, 800)
    end

    ------------------------------------------------------------------------
    -- Find Material
    ------------------------------------------------------------------------
    if not material then

        Planks.Stop("Invalid material selected.")
        return

    end

    ------------------------------------------------------------------------
    -- Check Bank
    ------------------------------------------------------------------------
    if not Bank:Contains(material.Log) then

        Planks.Stop(material.Name .. " logs not found in bank.")
        return

    end

    ------------------------------------------------------------------------
    -- Withdraw Logs
    ------------------------------------------------------------------------
    if not Bank:WithdrawAll(material.Log) then

        API.logError("Failed to withdraw logs.")
        return

    end

    if not Functions.SleepUntil(function()

        return Inventory:Contains(material.Log)

    end, 5, "withdraw logs") then

        API.logWarn("Logs did not appear in inventory.")
        return

    end

    -- Let the inventory refresh before closing the bank.
    API.RandomSleep2(1200, 500, 800)

    ------------------------------------------------------------------------
    -- Close Bank
    ------------------------------------------------------------------------
    API.RandomSleep2(400, 150, 250)
    
    API.KeyboardPress2(0x1B, 50, 0)

    if not Functions.SleepUntil(function()

        return not Bank:IsOpen()

    end, 5, "close bank") then

        API.logError("Bank did not close.")
        return

    end

    currentState  = states.CHECKING

end

local function IsOpen()
    return API.Compare2874Status(40, false)
        or API.Compare2874Status(18, false)
end

local function ClickSawmill()
    local material = Data.Items.Materials[Config.PlankType]
    API.logInfo("Script state: Sawmill.")

    if not API.IsPlayerMoving_() and not API.isProcessing() then

        API.DoAction_Object1(
            0xae,
            API.OFF_ACT_GeneralObject_route0,
            { Data.Objects.Sawmill },
            50
        )

        local interface = Functions.SleepUntil(
            IsOpen,
            10,
            "interface to open"
        )

        if interface then
            API.KeyboardPress32(0x20, 0)

            Functions.SleepUntil(
                function()
                    return not IsOpen()
                end,
                10,
                "interface to close"
            )

            return
        end

        API.RandomSleep2(1000, 500, 1000)

        if not API.isProcessing() then
            API.logError("Crafting didn't start. Stopping script.")
            ShouldContinue = false
            return
        end
    end

    currentState = states.CLEANING_UP
end

local function CleaningUp()
    local material = Data.Items.Materials[Config.PlankType]
    if not API.isProcessing() then

        API.logInfo("Script state: Cleaning Up.")

        if Inventory:IsFull()
            or Inventory:InvItemcount(material.Plank) >= 15 then

            API.RandomSleep2(5000, 500, 1000)
            currentState = states.BANKING

        end
    end
end

local function Checking()
    local material = Data.Items.Materials[Config.PlankType]
    ------------------------------------------------------------------------
    -- Empty Inventory
    ------------------------------------------------------------------------
    if Inventory:IsEmpty() then

        API.logInfo("Inventory is empty. Banking.")

        currentState = states.BANKING
        return

    end

    ------------------------------------------------------------------------
    -- Too Many Planks
    ------------------------------------------------------------------------
    if Inventory:InvItemcount(material.Plank) >= 15 then

        API.logInfo("Found planks. Banking.")

        currentState = states.BANKING
        return

    end

    ------------------------------------------------------------------------
    -- Correct Logs
    ------------------------------------------------------------------------
    if Inventory:InvItemcount(material.Log) >= 15 then

        API.logInfo("Found selected logs. Going to sawmill.")

        currentState = states.CLICK_SAWMILL
        return

    end

    ------------------------------------------------------------------------
    -- No Logs / Wrong Logs
    ------------------------------------------------------------------------
    API.logWarn("No selected logs found. Banking for safety.")

    currentState = states.BANKING

end

function Planks.Start(config)
    API.logInfo("Planks.Start()")

    ShouldContinue = true
    running = true
    paused = false
    currentState = states.CHECKING
end

function Planks.Pause()
    paused = true
end

function Planks.Resume()
    paused = false
end

function Planks.IsPaused()
    return paused
end

function Planks.Tick()

    if not running or paused then
        return
    end

    if currentState == states.CHECKING then
        Checking()

    elseif currentState == states.BANKING then
        Banking()

    elseif currentState == states.CLICK_SAWMILL then
        ClickSawmill()

    elseif currentState == states.CLEANING_UP then
        CleaningUp()
    end

    if not ShouldContinue then
        running = false
    end
end

--------------------------------------------------------------------------------
-- Stop
--------------------------------------------------------------------------------
function Planks.Stop(reason)

    running = false
    ShouldContinue = false

    Functions.Stop("Planks", reason)

end

function Planks.IsRunning()
    return running
end

return Planks
