-- Title: Test prints Buildinterface
-- Author: <Valtrex>
-- Description: <Making planks in Rimingtong>
-- Version: <Beta>
-- Category: Construction
-- Date : 2026-05-15
-- nails 1539
local API = require("api")

local Builds = {
    [1] = { Path = {{1306,0,-1,0},{1306,51,-1,0},{1306,52,-1,0},{1306,1,-1,0},{1306,5,-1,0},{1306,5,3,0}} },
    [2] = { Path = {{1306,0,-1,0},{1306,51,-1,0},{1306,52,-1,0},{1306,8,-1,0},{1306,12,-1,0},{1306,12,3,0}} },
    [3] = { Path = {{1306,0,-1,0},{1306,51,-1,0},{1306,52,-1,0},{1306,15,-1,0},{1306,19,-1,0},{1306,19,3,0}} },
    [4] = { Path = {{1306,0,-1,0},{1306,51,-1,0},{1306,52,-1,0},{1306,22,-1,0},{1306,26,-1,0},{1306,26,3,0}} },
    [5] = { Path = {{1306,0,-1,0},{1306,51,-1,0},{1306,52,-1,0},{1306,29,-1,0},{1306,33,-1,0},{1306,33,3,0}} }
}

local function GetRealItemAmount(ItemName)

    local Total = 0

    for _, Item in ipairs(Inventory:GetItems()) do
        if Item.name == ItemName then
            Total = Total + Item.amount
        end
    end

    return Total

end

local function GetNailAmount()

    return
        GetRealItemAmount("Bronze nails") +
        GetRealItemAmount("Iron nails") +
        GetRealItemAmount("Steel nails") +
        GetRealItemAmount("Black nails") +
        GetRealItemAmount("Mithril nails") +
        GetRealItemAmount("Adamantite nails") +
        GetRealItemAmount("Rune nails")

end


local PlankIDs = {
    ["Plank"] = 960,
    ["Oak plank"] = 8778,
    ["Teak plank"] = 8780,
    ["Mahogany plank"] = 8782,
    ["Acadia plank"] = 54860,
    ["Elder plank"] = 54862,
    ["Crystal plank"] = 54864,
    ["Teak frame"] = 54866,
    ["Mahogany frame"] = 54868,
    ["Magic plank"] = 54870,
    ["Eternal plank"] = 63190
}

local function GetContainerItemAmount(ContainerID, ItemID)

    local Total = 0

    local Items = API.Container_Get_all(ContainerID)

    for _, Item in pairs(Items) do
        if Item.item_id == ItemID then
            Total = Total + Item.item_stack
        end
    end

    return Total

end

local PlankBox = API.Container_Get_all(895)

local function GetContainerItemAmount(Container, ItemID)

    local Total = 0

    for _, Item in pairs(Container) do
        if Item.item_id == ItemID then
            Total = Total + Item.item_stack
        end
    end

    return Total

end

local function GetPlankAmount(ItemName)

    local InventoryAmount = GetRealItemAmount(ItemName)

    local ItemID = PlankIDs[ItemName]

    local BoxAmount = 0

    if ItemID then
        BoxAmount = GetContainerItemAmount(PlankBox, ItemID)
    end

    print(string.format(
        "%s | Inventory: %d | Plank Box: %d | Totaal: %d",
        ItemName,
        InventoryAmount,
        BoxAmount,
        InventoryAmount + BoxAmount
    ))

    return InventoryAmount + BoxAmount

end

local Tested = false

API.Write_LoopyLoop(true)

while API.Read_LoopyLoop() do

    if not Tested then

        Tested = true

        for Build = 5,1,-1 do

            print("")
            print("===================================================")
            print("Checking Build " .. Build)
            print("===================================================")

            local Result = API.ScanForInterfaceTest2Get(false, Builds[Build].Path)

            if Result and #Result > 0 then

                local Widget = Result[1]
                local Text = (Widget.textids or ""):gsub("<br>", "\n")

                print("")
                print("Materialen:")
                print(Text)
                print("")

                local CanBuild = true
                local MaterialCount = 0

                for Line in Text:gmatch("[^\n]+") do

                    local ItemName, Needed = Line:match("(.+):%s*(%d+)")

                    if ItemName and Needed then
                        MaterialCount = MaterialCount + 1

                        Needed = tonumber(Needed)

                        local Have

                        if ItemName == "Nails" then

                            Have = GetNailAmount()

                        elseif PlankIDs[ItemName] then

                            Have = GetPlankAmount(ItemName)

                        else

                            Have = GetRealItemAmount(ItemName)

                        end

                        print(ItemName ..
                            " | Nodig: " .. Needed ..
                            " | Aanwezig: " .. Have)

                        if Have >= Needed then
                            print("✓ OK")
                        else
                            print("✗ TE WEINIG")
                            CanBuild = false
                        end

                        print("")

                    end

                end

                if MaterialCount == 0 then

                    print(">>> Geen materialen gevonden (build interface waarschijnlijk niet geopend).")

                elseif CanBuild then

                    print("")
                    print(">>> BUILD " .. Build .. " GESELECTEERD")
                    print(">>> TEST GESLAAGD")

                    break

                else

                    print("")
                    print(">>> Build " .. Build .. " afgekeurd.")

                    if Build > 1 then
                        print(">>> Verder naar Build " .. (Build - 1) .. "...")
                    else
                        print(">>> Geen enkele build mogelijk.")
                    end

                end

            else

                print(">>> Interface niet gevonden.")

            end

        end

        API.Write_LoopyLoop(false)

    end

    API.RandomSleep2(100,100,100)

end