--[[
    Author:      Valtrex
    Version:     1.0
    Release      Date: 18-05-2024
    Script:      Protean User

    Release Notes:
    - Version 1.00  : Initial release
]]

-- 117926 = workbench, 106599 (might also be 106598) = fletcher, 89768 = range, 89770 = well, 106595 = crafter, 106601 (could also be 106602) = brazier
-- 53128 = Protean Essence
-- 30037 = Protean Plank


local API   = require("api")

local MAX_IDLE_TIME_MINUTES = 15 -- 5 for non jagex accounds

local ID    = {
    Protean = 30037,
    Object   = 117926,
}

local action ={
    --ID = 0x42,--RC Altars
    ID = 0x29,-- portables

}

local function waitUntil(x, timeout)
    local start = os.time()
    while not x() and start + timeout > os.time() do
        API.RandomSleep2(300, 50, 50)
    end
    return start + timeout > os.time()
end

local function getCreationInterfaceSelectedItemID()
    return API.VB_FindPSettinOrder(1170, 0).state
end

local function creationInterfaceOpen()
    return getCreationInterfaceSelectedItemID() ~= -1
end

local function invContains(items)
    local loot = API.InvItemcount_2(items)
    for _, v in ipairs(loot) do
        if v > 0 then
            return true
        end
    end
    return false
end


API.SetDrawTrackedSkills(true)
while API.Read_LoopyLoop() do
    API.SetMaxIdleTime(MAX_IDLE_TIME_MINUTES)
    API.DoRandomEvents()
    if invContains({ID.Protean}) then
        if API.isProcessing() then
            API.RandomSleep2(600, 50, 100)
        else
            API.RandomSleep2(2000, 1500, 2500)
            API.DoAction_Object1(action.ID ,API.OFF_ACT_GeneralObject_route0,{ ID.Object },25)
            API.RandomSleep2(1000, 500, 600)
            print("Waiting for creation interface")
            if waitUntil(creationInterfaceOpen, 5) then
                API.RandomSleep2(1000, 500, 600)
                API.KeyboardPress32(0x20,0) --press Space
                print("Waiting for processing to begin")
                waitUntil(API.isProcessing, 5)
            end
        end
    else
        API.Write_LoopyLoop(false)
        print("No Proteans are found, stopping script!")
    end
end