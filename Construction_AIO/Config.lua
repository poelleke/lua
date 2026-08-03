local Config = {}

-- Configuration file
Config.Directory = os.getenv("USERPROFILE") .. "\\MemoryError\\Lua_Scripts\\configs\\"
Config.File = Config.Directory .. "Construction_AIO.cfg"

-- Settings
Config.UseBankPin = false
Config.BankPin = ""

Config.ActivityIndex = 0
Config.ContractsUseTravelAbilities = true

Config.PlankType = 0
Config.LoadLastPreset = true

Config.FurnitureSearch = ""
Config.FurnitureUseCustomSearch = false
Config.FurniturePlankType = 0
Config.FurnitureMode = 0
Config.FurnitureUseStorage = false

-- Saves the complete Config table
function Config.Save()

    os.execute('mkdir "' .. Config.Directory .. '" >nul 2>&1')

    local file = io.open(Config.File, "w")
    if not file then
        return false
    end

    for key, value in pairs(Config) do
        if type(value) ~= "function" then
            file:write(key .. "=" .. tostring(value) .. "\n")
        end
    end

    file:close()
    return true

end

-- Loads the complete Config table
function Config.Load()

    local file = io.open(Config.File, "r")
    if not file then
        return false
    end

    for line in file:lines() do

        local key, value = line:match("^(.-)=(.*)$")

        if key then

            if value == "true" then
                value = true
            elseif value == "false" then
                value = false
            else
                local number = tonumber(value)
                if number ~= nil then
                    value = number
                end
            end

            Config[key] = value

        end

    end

    file:close()
    return true

end

return Config
