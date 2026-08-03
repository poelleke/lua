local ConstructionGUI = {}

local API = require("api")
local Config = require("Config")
local Contracts = require("Modules.Contracts")
local Functions = require("Data.Functions")
local Data = require("Data.Data")

--========================================================================--
-- Variables
--========================================================================--
local Version = "1"
ConstructionGUI.open = true
local startRequested = false
local exitRequested = false
local hidePlayerName = false
local hideBankPin = true

local activityList = {
    "Construction Contracts",
    "Build Furniture",
    "Make Planks"
}

local plankTypes = {
    "Plank",
    "Oak plank",
    "Willow plank",
    "Teak plank",
    "Maple plank",
    "Acadia plank",
    "Mahogany plank",
    "Yew plank",
    "Magic plank",
    "Elder plank",
    "Eternal plank"
}

local furnitureModes = Data.Furniture.Modes
local furniturePlankTypes = Data.Furniture.PlankTypes

local function BuildFurnitureSearch()

    local material = furniturePlankTypes[Config.FurniturePlankType + 1]
    local mode = furnitureModes[Config.FurnitureMode + 1]

    if not material or not mode then
        return ""
    end

    if material == "Wooden" then
        if mode == "Chair" then
            return "Crude wooden chair"
        end

        return material .. " " .. mode:lower()
    end

    if material == "Eternal" and mode == "Bench" then
        return "Eternal table"
    end

    return material .. " " .. mode:lower()

end

local Status = {
    NOT_RUNNING = "Not Running",
    RUNNING = "Running",
    PAUSED = "Paused",
    STOPPING = "Stopping"
}

local status = Status.NOT_RUNNING

--------------------------------------------------------------------------------
-- Theme
--------------------------------------------------------------------------------
local THEME = {
    -- Background
    bg      = {0.08, 0.07, 0.06},
    -- Panels / child windows
    panel   = {0.24, 0.18, 0.13},
    -- Light wood colour
    light   = {0.55, 0.40, 0.22},
    -- Accent (title bar, hover, selection)
    accent  = {0.52, 0.36, 0.18},
    -- Dark accent (active)
    accent2 = {0.26, 0.18, 0.10},
}

--========================================================================--
-- Data
--========================================================================--

local player = {
    name = "",
    construction = 0,
    xp = 0,
    status = Status.NOT_RUNNING
}

local function UpdatePlayerInformation()

    player.name = tostring(API.GetLocalPlayerName())
    player.construction = API.GetSkillsTableSkill(23)
    player.xp = API.GetSkillXP("CONSTRUCTION")

end

--========================================================================--
-- Helper Functions
--========================================================================--
local function BeginSection(title, height)

    ImGui.PushStyleColor(ImGuiCol.ChildBg,
        0.18, 0.14, 0.10, 0.90)

    ImGui.PushStyleColor(ImGuiCol.Border,
        0.42, 0.30, 0.16, 0.75)

    ImGui.PushStyleVar(ImGuiStyleVar.ChildRounding, 8)
    
    ImGui.BeginChild(
        title,
        -1,
        height,
        true,
        ImGuiWindowFlags.NoScrollbar
    )

    ImGui.PushStyleColor(ImGuiCol.Text,
        0.93, 0.83, 0.63, 1.00)

    local textWidth = ImGui.CalcTextSize(title)
    local availWidth = ImGui.GetContentRegionAvail()

    ImGui.SetCursorPosX((availWidth - textWidth) * 0.5)

    ImGui.Text(title)

    ImGui.PopStyleColor()

    ImGui.Separator()

    ImGui.Dummy(0, 8)

    ImGui.SetCursorPosX(12)
    ImGui.BeginGroup()

end

local function EndSection()

    ImGui.EndGroup()

    ImGui.EndChild()

    ImGui.PopStyleVar(1)
    ImGui.PopStyleColor(2)

end

local function FormatNumber(number)

    local formatted = tostring(number)

    while true do
        local k
        formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then
            break
        end
    end

    return formatted

end
--========================================================================--
-- Player Information
--========================================================================--

local function DrawPlayerInformation()

    BeginSection("Player Information", 150)

    local valueX = 120

    ImGui.Text("Name")
    ImGui.SameLine(valueX)

    if hidePlayerName then
        ImGui.Text("Player name is hidden")
    else
        ImGui.Text(player.name)
    end

    ImGui.Text("Construction")
    ImGui.SameLine(valueX)
    ImGui.Text(tostring(player.construction))

    ImGui.Text("XP")
    ImGui.SameLine(valueX)
    ImGui.Text(FormatNumber(player.xp))

    ImGui.Text("Status")
    ImGui.SameLine(valueX)
    ImGui.Text(player.status)

    ImGui.Dummy(0, 8)

    local changed, value = ImGui.Checkbox("Hide player name", hidePlayerName)
    if changed then
        hidePlayerName = value
    end

    EndSection()

    ImGui.Dummy(0, 6)

end

--========================================================================--
-- General Settings
--========================================================================--

local function DrawGeneralSettings()

    BeginSection("General Settings", 160)

    local changed

    changed, Config.UseBankPin = ImGui.Checkbox("Use Bank PIN", Config.UseBankPin)

    if changed then
        Config.Save()
    end

    if Config.UseBankPin then

        ImGui.SameLine()

        changed, hideBankPin = ImGui.Checkbox("Hide PIN", hideBankPin)

        ImGui.Dummy(0, 5)

        ImGui.AlignTextToFramePadding()
        ImGui.Text("PIN:")
        ImGui.SameLine()

        ImGui.PushItemWidth(45)

        if hideBankPin then

            changed, Config.BankPin = ImGui.InputTextWithHint(
                "##BankPin",
                "1234",
                Config.BankPin,
                ImGuiInputTextFlags.Password
            )

        else

            changed, Config.BankPin = ImGui.InputTextWithHint(
                "##BankPin",
                "1234",
                Config.BankPin
            )

        end

        ImGui.PopItemWidth()

        if changed then
            Config.BankPin = Config.BankPin:gsub("%D", "")

            if #Config.BankPin > 4 then
                Config.BankPin = Config.BankPin:sub(1, 4)
            end
        end

    else

        hideBankPin = true

    end

    ImGui.Dummy(0, 8)

    ImGui.Text("Activity")

    ImGui.PushItemWidth(-1)

    changed, Config.ActivityIndex = ImGui.Combo(
        
        "##Activity",
        Config.ActivityIndex,
        activityList
    )
    

    if changed then
        Config.Save()
    end

    ImGui.PopItemWidth()

    EndSection()

end

--========================================================================--
-- Activity Settings
--========================================================================--


local function DrawConstructionContracts()
    local stats = Contracts.GetStats()
    local changed

    ImGui.Text("Contract settings")
    ImGui.Separator()

    changed, Config.ContractsUseTravelAbilities = ImGui.Checkbox(
        "Use Surge / Dive while travelling",
        Config.ContractsUseTravelAbilities
    )

    if changed then
        Config.Save()
    end

    ImGui.Dummy(0, 4)

    ImGui.Text("Information:")
    ImGui.Separator()
    ImGui.Text(string.format("Contracts p/h: %.1f", stats.contractsPerHour))
    ImGui.Text("Contracts done: " .. stats.contractsDone)
    ImGui.Text("Contract credits earned: " .. stats.creditsEarned)

end

local function DrawBuildFurniture()

    local changed

    ImGui.Text("Furniture settings")
    ImGui.Separator()

    changed, Config.FurnitureUseStorage = ImGui.Checkbox(
        "Store built items in Furniture storage",
        Config.FurnitureUseStorage
    )

    if changed then
        Config.Save()
    end

    changed, Config.FurnitureUseCustomSearch = ImGui.Checkbox(
        "Free furniture choice",
        Config.FurnitureUseCustomSearch
    )

    if changed then
        Config.Save()
    end

    ImGui.Dummy(0, 4)

    if Config.FurnitureUseCustomSearch then

        ImGui.Text("Furniture name")
        ImGui.PushItemWidth(-1)

        changed, Config.FurnitureSearch = ImGui.InputTextWithHint(
            "##FurnitureSearch",
            "For example: Eternal long table",
            Config.FurnitureSearch
        )

        ImGui.PopItemWidth()

        if changed then
            Config.Save()
        end

    else

        if Config.FurniturePlankType < 0
            or Config.FurniturePlankType >= #furniturePlankTypes then
            Config.FurniturePlankType = 0
        end

        ImGui.Text("Plank type")
        ImGui.PushItemWidth(-1)
        changed, Config.FurniturePlankType = ImGui.Combo(
            "##FurniturePlankType",
            Config.FurniturePlankType,
            furniturePlankTypes
        )
        ImGui.PopItemWidth()

        if changed then
            Config.FurnitureSearch = BuildFurnitureSearch()
            Config.Save()
        end

        ImGui.Text("Furniture type")
        ImGui.PushItemWidth(-1)
        changed, Config.FurnitureMode = ImGui.Combo(
            "##FurnitureMode",
            Config.FurnitureMode,
            furnitureModes
        )
        ImGui.PopItemWidth()

        if changed then
            Config.FurnitureSearch = BuildFurnitureSearch()
            Config.Save()
        end

        Config.FurnitureSearch = BuildFurnitureSearch()
        ImGui.Text("Will build: " .. Config.FurnitureSearch)

    end

    ImGui.Text("Exact Furniture search.")

end

local function DrawMakePlanks()

    local changed

    ImGui.Text("Plank Type")

    ImGui.PushItemWidth(-1)

    changed, Config.PlankType = ImGui.Combo(
        "##PlankType",
        Config.PlankType,
        plankTypes
    )

    ImGui.PopItemWidth()

    if changed then
        Config.Save()
    end

    changed, Config.LoadLastPreset = ImGui.Checkbox(
        "Load last preset",
        Config.LoadLastPreset
    )

    if changed then
        Config.Save()
    end

end

local function DrawActivitySettings()

    local sectionHeight = 200

    if Config.ActivityIndex == 1 then
        sectionHeight = 290
    end

    BeginSection("Activity Settings and info", sectionHeight)

    if Config.ActivityIndex == 0 then
        DrawConstructionContracts()

    elseif Config.ActivityIndex == 1 then
        DrawBuildFurniture()

    elseif Config.ActivityIndex == 2 then
        DrawMakePlanks()
    end

    EndSection()

end


--========================================================================--
-- Footer
--========================================================================--

local function DrawFooter()

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    local buttonWidth = 155
    local buttonHeight = 42

    ImGui.PushStyleColor(ImGuiCol.Button,        0.39, 0.27, 0.14, 1.00)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.50, 0.35, 0.18, 1.00)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive,  0.30, 0.20, 0.10, 1.00)

    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 6)

    ImGui.SetCursorPosX(30)
    --API.logDebug("Status:", tostring(status))
    if status == Status.NOT_RUNNING then

        if ImGui.Button("Start", buttonWidth, buttonHeight) then
            startRequested = true
        end

        ImGui.SameLine()

        if ImGui.Button("Exit", buttonWidth, buttonHeight) then
            exitRequested = true
        end

    elseif status == Status.RUNNING then
        

        if ImGui.Button("Pause", buttonWidth, buttonHeight) then
            Functions.RequestPause()
        end

        ImGui.SameLine()

        if ImGui.Button("Stop", buttonWidth, buttonHeight) then
            Functions.RequestStop()
        end
    
    elseif status == Status.PAUSED then

        if ImGui.Button("Resume", buttonWidth, buttonHeight) then
            startRequested = true
        end

        ImGui.SameLine()

        if ImGui.Button("Stop", buttonWidth, buttonHeight) then
            Functions.RequestStop()
        end

    end
    ImGui.PopStyleVar(1)
    ImGui.PopStyleColor(3)

end

--========================================================================--
-- Main Draw
--========================================================================--

function ConstructionGUI.draw()

    ImGui.PushStyleColor(ImGuiCol.WindowBg,
    THEME.bg[1], THEME.bg[2], THEME.bg[3], 0.98)

    ImGui.PushStyleColor(ImGuiCol.TitleBg,
        THEME.panel[1], THEME.panel[2], THEME.panel[3], 1.00)

    ImGui.PushStyleColor(ImGuiCol.TitleBgActive,
        THEME.accent[1], THEME.accent[2], THEME.accent[3], 1.00)

    ImGui.PushStyleColor(ImGuiCol.Separator,
        THEME.light[1], THEME.light[2], THEME.light[3], 0.40)

    ImGui.PushStyleColor(ImGuiCol.FrameBg,
        THEME.light[1], THEME.light[2], THEME.light[3], 0.45)

    ImGui.PushStyleColor(ImGuiCol.FrameBgHovered,
        THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.75)

    ImGui.PushStyleColor(ImGuiCol.FrameBgActive,
        THEME.accent2[1], THEME.accent2[2], THEME.accent2[3], 1.00)

    ImGui.PushStyleColor(ImGuiCol.Button,
        THEME.panel[1], THEME.panel[2], THEME.panel[3], 1.00)

    --ImGui.PushStyleColor(ImGuiCol.ButtonHovered,
        --THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.85)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered,
        0.58, 0.40, 0.20, 1.00)

    ImGui.PushStyleColor(ImGuiCol.ButtonActive,
        THEME.accent2[1], THEME.accent2[2], THEME.accent2[3], 1.00)
    
    ImGui.PushStyleColor(ImGuiCol.Border,
        0.18, 0.12, 0.07, 1.00)

    ImGui.PushStyleColor(ImGuiCol.Header,
        THEME.panel[1], THEME.panel[2], THEME.panel[3], 0.90)

    ImGui.PushStyleColor(ImGuiCol.HeaderHovered,
        THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.80)

    ImGui.PushStyleColor(ImGuiCol.HeaderActive,
        THEME.accent2[1], THEME.accent2[2], THEME.accent2[3], 1.00)

    ImGui.PushStyleColor(ImGuiCol.CheckMark,
        0.92, 0.80, 0.46, 1.00)

    ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 1.0, 1.0, 1.0)

    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 12, 10)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 8, 6)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 8)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 8)

    local showGeneralSettings = status ~= Status.RUNNING
    local windowHeight = 710

    if Config.ActivityIndex == 1 then
        windowHeight = 800
    end

    if not showGeneralSettings then
        -- General Settings is 160 pixels high, plus its separating spacing.
        windowHeight = windowHeight - 166
    end

    ImGui.SetNextWindowSize(375, windowHeight, ImGuiCond.Always)

    --local flags = ImGuiWindowFlags.NoResize | ImGuiWindowFlags.NoCollapse
    local flags = ImGuiWindowFlags.NoResize
    local visible = ImGui.Begin("Construction AIO |  V".. Version .. "##ConstructionAIO", flags)

    if visible then

    UpdatePlayerInformation()

    ImGui.PushStyleColor(ImGuiCol.Text, 0.93, 0.82, 0.58, 1.00)

    ImGui.SetCursorPosX(115)
    
    ImGui.PushStyleColor(ImGuiCol.Text, 0.82, 0.72, 0.52, 1.00)
    ImGui.SetCursorPosX(145)
    ImGui.Text("by Valtrex")
    ImGui.PopStyleColor()

    ImGui.PopStyleColor()

    ImGui.Separator()
    ImGui.Dummy(0, 6)

    DrawPlayerInformation()
    if showGeneralSettings then
        DrawGeneralSettings()
    end
    DrawActivitySettings()
    DrawFooter()

    end

    ImGui.PopStyleVar(4)
    ImGui.PopStyleColor(16)

    ImGui.End()

end

function ConstructionGUI.StartPressed()

    if startRequested then
        startRequested = false
        return true
    end

    return false

end

function ConstructionGUI.StopPressed()

    if Functions.ConsumeStop() then
        return true
    end

    return false

end

function ConstructionGUI.ExitPressed()

    if exitRequested then
        exitRequested = false
        return true
    end

    return false

end

function ConstructionGUI.PausePressed()

    if Functions.ConsumePause() then
        return true
    end

    return false

end

function ConstructionGUI.GetActivity()

    return activityList[Config.ActivityIndex + 1]

end

function ConstructionGUI.GetStatus()

    return player.status

end

function ConstructionGUI.SetStatus(newStatus)

    player.status = newStatus
    status = newStatus

end

function ConstructionGUI.UseBankPin()
    return Config.UseBankPin
end

function ConstructionGUI.GetBankPin()
    return Config.BankPin
end

return ConstructionGUI
