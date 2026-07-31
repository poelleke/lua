local SCRIPT_DIR = os.getenv("USERPROFILE") .. "\\MemoryError\\Lua_Scripts\\Construction_AIO"

package.path = package.path
    .. ";" .. SCRIPT_DIR .. "\\?.lua"
    .. ";" .. SCRIPT_DIR .. "\\?\\init.lua"


local API = require("api")
local GUI = require("ConstructionGUI")
local Config = require("Config")
Config.Load()

local Functions = require("Data.Functions")
local Planks = require("Modules.Planks")
local Contracts = require("Modules.Contracts")

local currentModule = nil


ClearRender()

DrawImGui(function()
    GUI.draw()
end)

while API.Read_LoopyLoop() do

    if GUI.StartPressed() then
        print("Start pressed")
        if currentModule and currentModule.IsPaused and currentModule.IsPaused() then

            currentModule.Resume()
            GUI.SetStatus("Running")

        else

            local activity = GUI.GetActivity()
            print("Geselecteerde activiteit: " .. tostring(activity))

            if activity == "Construction Contracts" then

                currentModule = Contracts

            elseif activity == "Make Planks" then

                currentModule = Planks

            end

            if currentModule then
                currentModule.Start(Config)
                GUI.SetStatus("Running")
            end

        end

    end

    if GUI.PausePressed() then

        print("Pause pressed")

        if currentModule then
            print("Module exists")

            if currentModule.Pause then
                print("Pause function exists")
                currentModule.Pause()
                GUI.SetStatus("Paused")
            else
                print("Pause function is NIL")
            end
        end

    end

    if GUI.StopPressed() then

        if currentModule then
            currentModule.Stop("Stopped by user")
            currentModule = nil
        end

        GUI.SetStatus("Not Running")

    end

    if GUI.ExitPressed() then
        API.Write_LoopyLoop(false)
        break
    end

    if currentModule and currentModule.IsRunning() then

        if Functions.HandleBankPin(Config) then
            currentModule.Tick()

            -- Controleer of de module zichzelf heeft gestopt
            if not currentModule.IsRunning() then
                currentModule = nil
                GUI.SetStatus("Not Running")
            end

        else
            currentModule.Stop("Bank PIN handling failed.")
            currentModule = nil
            GUI.SetStatus("Not Running")
        end

    end

    API.RandomSleep2(100, 100, 100)

end