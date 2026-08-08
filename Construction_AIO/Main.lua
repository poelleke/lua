local SCRIPT_DIR = os.getenv("USERPROFILE") .. "\\MemoryError\\Lua_Scripts\\Construction_AIO"

package.path = package.path
    .. ";" .. SCRIPT_DIR .. "\\?.lua"
    .. ";" .. SCRIPT_DIR .. "\\?\\init.lua"


local API = require("api")
local GUI = require("ConstructionGUI")
local Config = require("Config")
Config.Load()

local Functions = require("Data.Functions")
local ConstructionMaterials = require("Modules.ConstructionMaterials")
local Contracts = require("Modules.Contracts")
local Furniture = require("Modules.Furniture")
local FortConstruction = require("Modules.FortConstruction")

local currentModule = nil


ClearRender()

DrawImGui(function()
    GUI.draw()
end)

    API.TurnOffMrHasselhoff(false)
    API.SetDrawLogs(true)
    API.SetDrawTrackedSkills(true)
    API.ClearLog()

while API.Read_LoopyLoop() do

    API.DoRandomEvents()

    if GUI.StartPressed() then
        API.logInfo("Start pressed")
        if currentModule and currentModule.IsPaused and currentModule.IsPaused() then

            currentModule.Resume()

            if currentModule.IsRunning() then
                GUI.SetStatus("Running")
            else
                currentModule = nil
                GUI.SetStatus("Not Running")
            end

        else

            local activity = GUI.GetActivity()
            API.logInfo("Selected activity: " .. tostring(activity))

            if activity == "Construction Contracts" then

                currentModule = Contracts

            elseif activity == "Construction Materials" then

                currentModule = ConstructionMaterials

            elseif activity == "Build Furniture" then

                currentModule = Furniture

            elseif activity == "Fort Forinthry Construction" then

                currentModule = FortConstruction

            end

            if currentModule then
                currentModule.Start(Config)

                if currentModule.IsRunning() then
                    GUI.SetStatus("Running")
                else
                    currentModule = nil
                    GUI.SetStatus("Not Running")
                end
            end

        end

    end

    if GUI.PausePressed() then

        API.logInfo("Pause pressed")

        if currentModule then
            API.logDebug("Module exists")

            if currentModule.Pause then
                API.logDebug("Pause function exists")
                currentModule.Pause()
                GUI.SetStatus("Paused")
            else
                API.logDebug("Pause function is NIL")
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

    if currentModule then
        if currentModule.IsRunning() then
            currentModule.Tick()
        end

        -- Also clean up when Start, Resume, or Tick stopped the module.
        if not currentModule.IsRunning() then
            currentModule = nil
            GUI.SetStatus("Not Running")
        end
    end

    API.RandomSleep2(100, 100, 100)

end
