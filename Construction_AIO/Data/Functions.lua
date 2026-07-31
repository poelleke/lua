--=========================================================================--
-- Construction AIO
--
-- Functions.lua
--
-- Central location for all Functions used by the Construction AIO.
--
--=========================================================================--

local API = require("api")
local Interfaces = require("Data.Interfaces")

local Functions = {}

--========================================================================--
-- Bank functions
--========================================================================--
function Functions.HandleBankPin(config)

    --print("UseBankPin =", tostring(config.UseBankPin))
    --print("BankPin    = '" .. tostring(config.BankPin) .. "'")

    if not Interfaces.IsBankPinOpen() then
        return true
    end
    print("Bank PIN gedetecteerd.")

    if not config.UseBankPin then
        print("Bank PIN gedetecteerd, maar 'Use Bank PIN' staat uit.")
        return false
    end

    if config.BankPin == "" then
        print("Bank PIN gedetecteerd, maar er is geen Bank PIN ingesteld.")
        return false
    end

    if not config.UseBankPin or config.BankPin == "" then
        return false
    end

    API.DoBankPin(config.BankPin)
    --print("PIN verzonden:", config.BankPin)

    local timeout = os.clock() + 5

    while os.clock() < timeout do

        if not Interfaces.IsBankPinOpen() then
            print("Bank PIN ingevoerd.")
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

    for _, Material in ipairs(Materials) do

        local Have = 0

        if Data.Items.Nails[Material.Name] then

            Have = Functions.GetRealItemAmount(Data.Items.Nails[Material.Name])

        elseif Data.Items.Materials[Material.Name] then

            Have = Functions.GetRealItemAmount(Data.Items.Materials[Material.Name])

        elseif Data.Items.Bars[Material.Name] then

            Have = Functions.GetRealItemAmount(Data.Items.Bars[Material.Name])

        else

            return false
        end

        if Have < Material.Needed then
            return false
        end

    end

    return true

end


--------------------------------------------------------------------------------
-- Stop Module
--------------------------------------------------------------------------------
function Functions.Stop(moduleName, reason)

    print("===================================")
    print("Construction bot gestopt.")
    print("===================================")
    print("Module : " .. tostring(moduleName))
    print("Reason : " .. tostring(reason))
    print("===================================")

end

return Functions
