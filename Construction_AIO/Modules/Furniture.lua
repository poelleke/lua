--========================================================================--
-- Construction AIO - Furniture Construction
--
-- Build loop: open workbench, search, select, verify materials, press Space,
-- then refill the plank box before loading the preset for the next batch.
-- Furniture storage deliberately follows in a later step.
--========================================================================--

local Furniture = {}

local API = require("api")
local Config = require("Config")
local Data = require("Data.Data")
local Functions = require("Data.Functions")

local STATE_OPEN_WORKBENCH = "OPEN_WORKBENCH"
local STATE_WAIT_INTERFACE = "WAIT_INTERFACE"
local STATE_ENTER_SEARCH = "ENTER_SEARCH"
local STATE_CLEAR_SEARCH = "CLEAR_SEARCH"
local STATE_REENTER_SEARCH = "REENTER_SEARCH"
local STATE_TYPE_SEARCH = "TYPE_SEARCH"
local STATE_SUBMIT_SEARCH = "SUBMIT_SEARCH"
local STATE_WAIT_RESULTS = "WAIT_RESULTS"
local STATE_WAIT_SELECTED = "WAIT_SELECTED"
local STATE_VERIFY_MATERIALS = "VERIFY_MATERIALS"
local STATE_CONSTRUCT = "CONSTRUCT"
local STATE_WAIT_PROCESSING_START = "WAIT_PROCESSING_START"
local STATE_WAIT_PROCESSING_FINISH = "WAIT_PROCESSING_FINISH"
local STATE_STORAGE_OPEN = "STORAGE_OPEN"
local STATE_STORAGE_WAIT_OPEN = "STORAGE_WAIT_OPEN"
local STATE_STORAGE_STORE_ITEMS = "STORAGE_STORE_ITEMS"
local STATE_STORAGE_CLOSE = "STORAGE_CLOSE"
local STATE_STORAGE_WAIT_CLOSE = "STORAGE_WAIT_CLOSE"
local STATE_BANK_LOAD_PRESET = "BANK_LOAD_PRESET"
local STATE_BANK_WAIT_PRESET = "BANK_WAIT_PRESET"
local STATE_BANK_CHECK_PLANK_BOX = "BANK_CHECK_PLANK_BOX"
local STATE_BANK_OPEN = "BANK_OPEN"
local STATE_BANK_WAIT_OPEN = "BANK_WAIT_OPEN"
local STATE_BANK_FILL_PLANK_BOX = "BANK_FILL_PLANK_BOX"
local STATE_BANK_CLOSE = "BANK_CLOSE"
local STATE_BANK_WAIT_CLOSE = "BANK_WAIT_CLOSE"

local RESULT_SCAN_LIMIT = 600
local INTERFACE_SETTLE_DELAY = 1.0
local SEARCH_INPUT_DELAY = 0.7
local SEARCH_SUBMIT_DELAY = 1.0
local SEARCH_RESULT_DELAY = 1.5
local SELECT_RESULT_DELAY = 1.0
local CONSTRUCT_DELAY = 0.0
local PROCESSING_START_TIMEOUT = 8.0
local PRESET_SETTLE_DELAY = 2.5
local BANK_OPEN_TIMEOUT = 8.0
local PLANK_BOX_FILL_DELAY = 1.2
local STORAGE_OPEN_SETTLE_DELAY = 3.0
local STORAGE_STORE_SETTLE_DELAY = 1.0
local STORAGE_CLOSE_SETTLE_DELAY = 0.7
local MAX_MATERIAL_BANK_ATTEMPTS = 2

local running = false
local paused = false
local currentState = nil
local stateSince = 0
local nextResultScan = 0
local targetName = ""
local configuredRecipe = nil
local storageOpenedAt = nil
local storageCloseAttempts = 0
local materialBankAttempts = 0

local function Now()
    return os.clock()
end

local function TrimText(text)
    return tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function SetState(state)
    currentState = state
    stateSince = Now()
end

local function IsInterfaceOpen()
    return API.GetInterfaceOpenBySize(Data.Interfaces.Furniture.MainId)
end

local function IsStorageOpen()
    return API.GetInterfaceOpenBySize(Data.Interfaces.Furniture.StorageId)
end

local function CopyPath(path)
    local copy = {}
    for index, part in ipairs(path) do
        copy[index] = { part[1], part[2], part[3], part[4] }
    end
    return copy
end

local function ReadWidget(path)
    local result = API.ScanForInterfaceTest2Get(false, path)
    return result and result[1]
end

local function ReadText(path)
    local widget = ReadWidget(path)
    return widget and tostring(widget.textids or "") or ""
end

local function SelectedFurnitureMatchesTarget()
    local selectedName = TrimText(ReadText(Data.Interfaces.Furniture.SelectedPath))
    return selectedName ~= "" and selectedName:lower() == targetName:lower(), selectedName
end

local function ContinueFromOpenFurnitureInterface()
    local matches, selectedName = SelectedFurnitureMatchesTarget()

    if matches then
        API.logInfo("Geselecteerd meubel komt al overeen: " .. selectedName .. "; zoeken overslaan.")
        SetState(STATE_VERIFY_MATERIALS)
    else
        SetState(STATE_ENTER_SEARCH)
    end
end

local function ReadResultWidget(resultId)
    local path = CopyPath(Data.Interfaces.Furniture.ResultRootPath)
    path[#path + 1] = { Data.Interfaces.Furniture.MainId, 25, resultId, 0 }
    return ReadWidget(path)
end

local function ReadMaterialWidget(childId)
    local path = CopyPath(Data.Interfaces.Furniture.MaterialRootPath)
    path[#path + 1] = { Data.Interfaces.Furniture.MainId, 22, childId, 0 }
    return ReadWidget(path)
end

local function ReadMaterialSprite(widget)
    if not widget or not widget.memloc or widget.memloc == 0 then
        return nil
    end

    local ok, sprite = pcall(API.Mem_Read_int, widget.memloc + API.I_slides)
    return ok and sprite or nil
end

local function FindSingleResult()
    local found = {}

    for resultId = 0, RESULT_SCAN_LIMIT do
        local widget = ReadResultWidget(resultId)
        if widget and widget.memloc and widget.memloc ~= 0 then
            table.insert(found, resultId)
        end
    end

    if #found == 1 then
        return found[1]
    end

    if #found > 1 then
        API.logError("Furniture: search returned " .. #found .. " results; use a more exact name.")
    end

    return nil
end

local function GetConfiguredRecipe()
    if Config.FurnitureUseCustomSearch then
        return nil
    end

    local plankType = Data.Furniture.PlankTypes[(Config.FurniturePlankType or 0) + 1]
    local mode = Data.Furniture.Modes[(Config.FurnitureMode or 0) + 1]

    return plankType
        and Data.Furniture.Recipes[plankType]
        and Data.Furniture.Recipes[plankType][mode]
        or nil
end

local function HasConfiguredMaterials(recipe)
    for _, material in ipairs(recipe) do
        local inventoryAmount, boxAmount, totalAmount

        if material.name:lower():find("plank", 1, true) then
            inventoryAmount, boxAmount, totalAmount = Functions.GetPlankAmountDetails(material.name)
        else
            inventoryAmount = Functions.GetRealItemAmount(material.name)
            boxAmount = 0
            totalAmount = inventoryAmount
        end

        local available = totalAmount >= material.needed
        API.logInfo(string.format(
            "%s | Nodig: %d | Inventory: %d | Plankbox: %d | Totaal: %d | %s",
            material.name, material.needed, inventoryAmount, boxAmount, totalAmount,
            available and "OK" or "TE WEINIG"
        ))

        if not available then
            return false
        end
    end

    return true
end

local function HasAllInterfaceMaterials()
    local materialCount = 0

    for row = 0, 9 do
        local nameWidget = ReadMaterialWidget(1 + (row * 6))

        if nameWidget and nameWidget.memloc and nameWidget.memloc ~= 0 then
            materialCount = materialCount + 1

            local materialName = tostring(nameWidget.textids or "Onbekend materiaal")
            local statusWidget = ReadMaterialWidget(4 + (row * 6))
            local sprite = ReadMaterialSprite(statusWidget)

            if sprite == Data.Furniture.GreenMaterialSprite then
                API.logInfo("Materiaal beschikbaar via vinkje: " .. materialName)
            elseif sprite == Data.Furniture.RedMaterialSprite then
                API.logError("Materiaal ontbreekt via kruisje: " .. materialName)
                return false
            else
                API.logError("Onbekende materiaal-sprite: " .. materialName .. " | " .. tostring(sprite))
                return false
            end
        end
    end

    if materialCount == 0 then
        API.logError("Furniture: geen materiaalregels gevonden.")
        return false
    end

    return true
end

local function HandleBankPinIfOpen()
    if not API.GetInterfaceOpenBySize(759) then
        return true
    end

    API.logInfo("Furniture: Bank PIN gedetecteerd.")
    return Functions.HandleBankPin(Config)
end

function Furniture.Start()
    targetName = TrimText(Config.FurnitureSearch)

    if targetName == "" then
        API.logError("Furniture: kies eerst een meubel in de GUI.")
        return false
    end

    configuredRecipe = GetConfiguredRecipe()
    running = true
    paused = false
    nextResultScan = 0
    materialBankAttempts = 0

    API.logInfo("Furniture start: [" .. targetName .. "]")

    if configuredRecipe and not HasConfiguredMaterials(configuredRecipe) then
        materialBankAttempts = 1
        API.logInfo("Furniture start: onvoldoende preconfig-materialen; bankpoging 1/"
            .. MAX_MATERIAL_BANK_ATTEMPTS .. ".")
        SetState(STATE_BANK_CHECK_PLANK_BOX)
    else
        SetState(STATE_OPEN_WORKBENCH)
    end

    return true
end

function Furniture.Tick()
    if not running or paused then
        return
    end

    local now = Now()

    if currentState == STATE_OPEN_WORKBENCH then
        if API.IsPlayerMoving_() or API.isProcessing() then
            return
        end

        if IsInterfaceOpen() then
            API.logInfo("Furniture interface was already open.")
            ContinueFromOpenFurnitureInterface()
            return
        end

        API.logInfo("Open Furniture workbench.")
        API.DoAction_Object1(0xae, API.OFF_ACT_GeneralObject_route0, { Data.Objects.FurnitureWorkbench }, 50)
        SetState(STATE_WAIT_INTERFACE)
        return
    end

    if currentState == STATE_WAIT_INTERFACE then
        if IsInterfaceOpen() then
            if now - stateSince >= INTERFACE_SETTLE_DELAY then
                API.logInfo("Furniture interface open.")
                ContinueFromOpenFurnitureInterface()
            end
            return
        end

        if now - stateSince > 25 then
            Furniture.Stop("Furniture interface opende niet na de workbench-actie.")
        end
        return
    end

    if currentState == STATE_ENTER_SEARCH then
        API.logInfo("Furniture toets: Enter (zoekveld activeren).")
        API.KeyboardPress2(0x0D, 50, 50)
        SetState(STATE_CLEAR_SEARCH)
        return
    end

    if currentState == STATE_CLEAR_SEARCH then
        if now - stateSince < SEARCH_INPUT_DELAY then
            return
        end

        API.logInfo("Furniture toets: Esc (vorige zoektekst wissen).")
        API.KeyboardPress2(0x1B, 50, 50)
        SetState(STATE_REENTER_SEARCH)
        return
    end

    if currentState == STATE_REENTER_SEARCH then
        if now - stateSince < SEARCH_INPUT_DELAY then
            return
        end

        if not IsInterfaceOpen() then
            Furniture.Stop("Furniture interface sloot tijdens het wissen van de zoektekst.")
            return
        end

        API.logInfo("Furniture toets: Enter (zoekveld opnieuw activeren).")
        API.KeyboardPress2(0x0D, 50, 50)
        SetState(STATE_TYPE_SEARCH)
        return
    end

    if currentState == STATE_TYPE_SEARCH then
        if now - stateSince < SEARCH_INPUT_DELAY then
            return
        end

        if not IsInterfaceOpen() then
            Furniture.Stop("Furniture interface sloot voor de zoektekst kon worden verzonden.")
            return
        end

        targetName = TrimText(targetName)
        API.TypeOnkeyboard3(targetName)
        API.logInfo("Zoektekst verzonden: [" .. targetName .. "]")
        SetState(STATE_SUBMIT_SEARCH)
        return
    end

    if currentState == STATE_SUBMIT_SEARCH then
        if now - stateSince < SEARCH_SUBMIT_DELAY then
            return
        end

        if not IsInterfaceOpen() then
            Furniture.Stop("Furniture interface sloot tijdens het bevestigen van de zoektekst.")
            return
        end

        API.logInfo("Furniture toets: Enter (zoekopdracht bevestigen).")
        API.KeyboardPress2(0x0D, 50, 50)
        SetState(STATE_WAIT_RESULTS)
        return
    end

    if currentState == STATE_WAIT_RESULTS then
        if now - stateSince < SEARCH_RESULT_DELAY then
            return
        end

        if now < nextResultScan then
            return
        end
        nextResultScan = now + 0.5

        local noResults = ReadText(Data.Interfaces.Furniture.NoResultsPath):lower()
        if noResults:find("no items available", 1, true) then
            Furniture.Stop("Geen Furniture-resultaat voor: " .. targetName)
            return
        end

        local resultId = FindSingleResult()
        if resultId then
            API.logInfo("Selecteer Furniture-resultaat: " .. resultId)
            API.DoAction_Interface(0xffffffff, 0xffffffff, 1, Data.Interfaces.Furniture.MainId, 25, resultId, API.OFF_ACT_GeneralInterface_route)
            SetState(STATE_WAIT_SELECTED)
            return
        end

        if now - stateSince > 4 then
            Furniture.Stop("Geen uniek Furniture-resultaat gevonden.")
        end
        return
    end

    if currentState == STATE_WAIT_SELECTED then
        if now - stateSince < SELECT_RESULT_DELAY then
            return
        end

        local selectedName = ReadText(Data.Interfaces.Furniture.SelectedPath)
        if selectedName:lower() == targetName:lower() then
            API.logInfo("Geselecteerd meubel bevestigd: " .. selectedName)
            SetState(STATE_VERIFY_MATERIALS)
            return
        end

        if now - stateSince > 3 then
            Furniture.Stop("Geselecteerd Furniture-resultaat klopt niet: " .. selectedName)
        end
        return
    end

    if currentState == STATE_VERIFY_MATERIALS then
        local available
        if configuredRecipe then
            available = HasConfiguredMaterials(configuredRecipe)
        else
            API.logInfo("Vrije meubelkeuze: materiaalvinkjes in de interface controleren.")
            available = HasAllInterfaceMaterials()
        end

        if not available then
            Furniture.Stop("Materialen zijn niet volledig beschikbaar.")
            return
        end

        API.logInfo("Alle materialen zijn beschikbaar. Bouwen starten met Spatie.")
        SetState(STATE_CONSTRUCT)
        return
    end

    if currentState == STATE_CONSTRUCT then
        if now - stateSince < CONSTRUCT_DELAY then
            return
        end

        API.logInfo("Furniture toets: Spatie (bouwen starten).")
        API.KeyboardPress32(0x20, 0)
        SetState(STATE_WAIT_PROCESSING_START)
        return
    end

    if currentState == STATE_WAIT_PROCESSING_START then
        if API.isProcessing() then
            API.logInfo("Furniture bouwen gestart.")
            SetState(STATE_WAIT_PROCESSING_FINISH)
            return
        end

        if now - stateSince > PROCESSING_START_TIMEOUT then
            Furniture.Stop("Furniture-bouwactie startte niet na Spatie.")
        end
        return
    end

    if currentState == STATE_WAIT_PROCESSING_FINISH and not API.isProcessing() then
        if Config.FurnitureUseStorage then
            API.logInfo("Furniture-bouwbatch voltooid. Items naar Furniture storage.")
            SetState(STATE_STORAGE_OPEN)
        else
            API.logInfo("Furniture-bouwbatch voltooid. Naar bankcyclus.")
            SetState(STATE_BANK_CHECK_PLANK_BOX)
        end
        return
    end

    if currentState == STATE_STORAGE_OPEN then
        if API.IsPlayerMoving_() then
            return
        end

        API.logInfo("Furniture storage: openen.")
        storageCloseAttempts = 0
        API.DoAction_Object1(
            0x31,
            API.OFF_ACT_GeneralObject_route0,
            { Data.Objects.FurnitureStorage },
            50
        )
        storageOpenedAt = nil
        SetState(STATE_STORAGE_WAIT_OPEN)
        return
    end

    if currentState == STATE_STORAGE_WAIT_OPEN then
        if not IsStorageOpen() then
            if now - stateSince > 20 then
                Furniture.Stop("Furniture storage interface 1518 opende niet.")
            end
            return
        end

        if not storageOpenedAt then
            storageOpenedAt = now
            API.logInfo("Furniture storage interface 1518 geopend.")
            return
        end

        if now - storageOpenedAt >= STORAGE_OPEN_SETTLE_DELAY then
            SetState(STATE_STORAGE_STORE_ITEMS)
        end
        return
    end

    if currentState == STATE_STORAGE_STORE_ITEMS then
        if not IsStorageOpen() then
            Furniture.Stop("Furniture storage sloot voordat items konden worden opgeslagen.")
            return
        end

        API.logInfo("Furniture storage toets: Spatie (items opslaan).")
        API.KeyboardPress32(0x20, 0)
        SetState(STATE_STORAGE_CLOSE)
        return
    end

    if currentState == STATE_STORAGE_CLOSE then
        if now - stateSince < STORAGE_STORE_SETTLE_DELAY then
            return
        end

        API.logInfo("Furniture storage toets: Esc (storage sluiten).")
        API.KeyboardPress2(0x1B, 60, 100)
        storageCloseAttempts = 1
        SetState(STATE_STORAGE_WAIT_CLOSE)
        return
    end

    if currentState == STATE_STORAGE_WAIT_CLOSE then
        if not IsStorageOpen() and now - stateSince >= STORAGE_CLOSE_SETTLE_DELAY then
            API.logInfo("Furniture storage: klaar. Naar bankcyclus.")
            SetState(STATE_BANK_CHECK_PLANK_BOX)
            return
        end

        if now - stateSince >= STORAGE_CLOSE_SETTLE_DELAY then
            if storageCloseAttempts < 2 then
                API.logInfo("Furniture storage blijft open; tweede Esc versturen.")
                API.KeyboardPress2(0x1B, 60, 100)
                storageCloseAttempts = 2
                SetState(STATE_STORAGE_WAIT_CLOSE)
            else
                Furniture.Stop("Furniture storage sloot niet na twee keer Esc.")
            end
        end
        return
    end

    if currentState == STATE_BANK_LOAD_PRESET then
        if API.IsPlayerMoving_() then
            return
        end

        API.logInfo("Furniture bank: Load last preset.")
        API.DoAction_Object1(0x33, API.OFF_ACT_GeneralObject_route3, { Data.Objects.Bank }, 50)
        SetState(STATE_BANK_WAIT_PRESET)
        return
    end

    if currentState == STATE_BANK_WAIT_PRESET then
        if not HandleBankPinIfOpen() then
            Furniture.Stop("Bank PIN handling failed tijdens Load last preset.")
            return
        end

        if now - stateSince >= PRESET_SETTLE_DELAY then
            if configuredRecipe and not HasConfiguredMaterials(configuredRecipe) then
                if materialBankAttempts >= MAX_MATERIAL_BANK_ATTEMPTS then
                    Furniture.Stop("Na " .. MAX_MATERIAL_BANK_ATTEMPTS
                        .. " bankpogingen zijn de preconfig-materialen nog onvoldoende.")
                    return
                end

                materialBankAttempts = materialBankAttempts + 1
                API.logWarn("Furniture bank: materialen nog onvoldoende; bankpoging "
                    .. materialBankAttempts .. "/" .. MAX_MATERIAL_BANK_ATTEMPTS .. ".")
                SetState(STATE_BANK_CHECK_PLANK_BOX)
                return
            end

            materialBankAttempts = 0
            API.logInfo("Furniture bank: preset geladen; geselecteerde meubel opnieuw bouwen.")
            SetState(STATE_OPEN_WORKBENCH)
        end
        return
    end

    if currentState == STATE_BANK_CHECK_PLANK_BOX then
        local plankBoxAmount = Functions.GetRealItemAmount("Plank box")

        if plankBoxAmount <= 0 then
            API.logInfo("Furniture bank: geen plank box in inventory; preset laden.")
            SetState(STATE_BANK_LOAD_PRESET)
            return
        end

        API.logInfo("Furniture bank: plank box gevonden: " .. plankBoxAmount)
        SetState(STATE_BANK_OPEN)
        return
    end

    if currentState == STATE_BANK_OPEN then
        if API.IsPlayerMoving_() then
            return
        end

        API.logInfo("Furniture bank: bank openen.")
        API.DoAction_Object1(0x33, API.OFF_ACT_GeneralObject_route1, { Data.Objects.Bank }, 50)
        SetState(STATE_BANK_WAIT_OPEN)
        return
    end

    if currentState == STATE_BANK_WAIT_OPEN then
        if not HandleBankPinIfOpen() then
            Furniture.Stop("Bank PIN handling failed tijdens bank openen.")
            return
        end

        if API.BankOpen2() then
            API.logInfo("Furniture bank: bank geopend.")
            SetState(STATE_BANK_FILL_PLANK_BOX)
            return
        end

        if now - stateSince > BANK_OPEN_TIMEOUT then
            Furniture.Stop("Furniture bank kon niet worden geopend.")
        end
        return
    end

    if currentState == STATE_BANK_FILL_PLANK_BOX then
        API.logInfo("Furniture bank: plank box vullen.")
        API.DoAction_Bank_Inv(
            Data.Items.misc.plank_box,
            8,
            API.OFF_ACT_GeneralInterface_route2
        )
        SetState(STATE_BANK_CLOSE)
        return
    end

    if currentState == STATE_BANK_CLOSE then
        if now - stateSince < PLANK_BOX_FILL_DELAY then
            return
        end

        API.logInfo("Furniture bank: bank sluiten.")
        API.KeyboardPress2(0x1B, 60, 100)
        SetState(STATE_BANK_WAIT_CLOSE)
        return
    end

    if currentState == STATE_BANK_WAIT_CLOSE then
        if not API.BankOpen2() then
            API.logInfo("Furniture bank: plank box gevuld; preset laden.")
            SetState(STATE_BANK_LOAD_PRESET)
            return
        end

        if now - stateSince > 5 then
            Furniture.Stop("Furniture bank sloot niet.")
        end
    end
end

function Furniture.Pause()
    if running then
        paused = true
        API.logInfo("Furniture gepauzeerd.")
    end
end

function Furniture.Resume()
    if running and paused then
        targetName = TrimText(Config.FurnitureSearch)

        if targetName == "" then
            Furniture.Stop("Geen Furniture-naam gekozen bij hervatten.")
            return
        end

        configuredRecipe = GetConfiguredRecipe()
        paused = false

        if configuredRecipe and not HasConfiguredMaterials(configuredRecipe) then
            materialBankAttempts = 1
            API.logInfo("Furniture hervat: onvoldoende preconfig-materialen; bankpoging 1/"
                .. MAX_MATERIAL_BANK_ATTEMPTS .. ".")
            SetState(STATE_BANK_CHECK_PLANK_BOX)
        else
            API.logInfo("Furniture hervat; geselecteerd meubel opnieuw controleren.")
            SetState(STATE_OPEN_WORKBENCH)
        end
    end
end

function Furniture.Stop(reason)
    if running then
        Functions.Stop("Furniture", reason or "Stopped")
    end

    running = false
    paused = false
    currentState = nil
    materialBankAttempts = 0
end

function Furniture.IsRunning()
    return running
end

function Furniture.IsPaused()
    return paused
end

return Furniture
