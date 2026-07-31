local Config = {}

-- Configuratiebestand
Config.Directory = os.getenv("USERPROFILE") .. "\\MemoryError\\Lua_Scripts\\configs\\"
Config.File = Config.Directory .. "Construction_AIO.cfg"

-- Instellingen
Config.UseBankPin = false
Config.BankPin = ""

Config.ActivityIndex = 0

Config.PlankType = 0
Config.LoadLastPreset = true

-- Slaat de volledige Config-tabel op
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

-- Laadt de volledige Config-tabel
function Config.Load()

    local number = tonumber(value)

    if number ~= nil then
        value = number
    elseif value == "true" then
        value = true
    elseif value == "false" then
        value = false
    end

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
            end

            Config[key] = value

        end

    end

    file:close()
    return true

end

return Config