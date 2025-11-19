local QBCore = exports[Config.CoreResource]:GetCoreObject()

local CurrentContract = nil
local ContractVehicle = nil
local ContractVehicleNetId = nil
local ContractBlip = nil

local GpsEndTime = nil
local DeliveryEndTime = nil
local ContractStolen = false

local function DebugPrint(msg)
    if Config.Debug then
        print('[Rc2-boosting] ' .. tostring(msg))
    end
end

local function SecondsToClock(seconds)
    if seconds < 0 then seconds = 0 end
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    return string.format('%02d:%02d', m, s)
end

local function DrawText2D(x, y, text, scale)
    SetTextFont(4)
    SetTextProportional(0)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 215)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

-- Helper: get safe ground Z so ped stands on floor, not floating
local function GetSafeGroundZ(x, y, z)
    local found, groundZ = GetGroundZFor_3dCoord(x, y, z + 50.0, 0.0)
    if found then
        return groundZ
    else
        return z
    end
end

-- Timers (bottom-left)
CreateThread(function()
    while true do
        if GpsEndTime or DeliveryEndTime then
            Wait(0)
            local now = GetGameTimer()
            local x, y = 0.015, 0.80

            if GpsEndTime then
                local sec = math.max(0, math.floor((GpsEndTime - now) / 1000))
                if sec > 0 then
                    DrawText2D(x, y, 'GPS: ' .. SecondsToClock(sec), 0.35)
                    y = y + 0.02
                else
                    GpsEndTime = nil
                    if DoesBlipExist(ContractBlip) then
                        RemoveBlip(ContractBlip)
                        ContractBlip = nil
                    end
                end
            end

            if DeliveryEndTime then
                local sec = math.max(0, math.floor((DeliveryEndTime - now) / 1000))
                if sec > 0 then
                    DrawText2D(x, y, 'Delivery: ' .. SecondsToClock(sec), 0.35)
                else
                    DeliveryEndTime = nil
                    if CurrentContract then
                        TriggerServerEvent('rc2-boosting:server:failContract', 'timeout')
                    end
                end
            end
        else
            Wait(500)
        end
    end
end)

-- Contract giver ped
local function CreateContractPed()
    local pedData = Config.ContractPed
    local model = GetHashKey(pedData.model)

    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end

    local coords = pedData.coords
    local groundZ = GetSafeGroundZ(coords.x, coords.y, coords.z)
    local ped = CreatePed(4, model, coords.x, coords.y, groundZ, coords.w, false, true)

    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)

    if pedData.scenario then
        TaskStartScenarioInPlace(ped, pedData.scenario, 0, true)
    end

    DebugPrint(('ContractPed spawned at %.2f %.2f %.2f'):format(coords.x, coords.y, groundZ))

    exports[Config.TargetResource]:AddTargetEntity(ped, {
        options = {
            {
                label = 'Open Boosting Contracts',
                icon = 'fas fa-car',
                action = function()
                    if CurrentContract then
                        QBCore.Functions.Notify('You already have an active contract.', 'error')
                        return
                    end
                    TriggerEvent('rc2-boosting:client:openMenu')
                end,
            },
        },
        distance = 2.0
    })
end

-- Delivery peds
local function CreateDeliveryPeds()
    for index, data in pairs(Config.DeliveryLocations) do
        local coords = data.coords
        local model = GetHashKey(data.pedModel or 'a_m_m_business_01')

        RequestModel(model)
        local timeout = GetGameTimer() + 5000
        while not HasModelLoaded(model) and GetGameTimer() < timeout do
            Wait(0)
        end

        if not HasModelLoaded(model) then
            print(('[Rc2-boosting] [ERROR] Failed to load model for ped %s'):format(index))
        else
            local groundZ = GetSafeGroundZ(coords.x, coords.y, coords.z)
            local ped = CreatePed(4, model, coords.x, coords.y, groundZ, coords.w, false, true)

            if DoesEntityExist(ped) then
                SetEntityAsMissionEntity(ped, true, true)
                SetBlockingOfNonTemporaryEvents(ped, true)
                SetEntityInvincible(ped, true)
                FreezeEntityPosition(ped, true)
                TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CLIPBOARD', 0, true)

                DebugPrint(('DeliveryPed[%s] spawned at %.2f %.2f %.2f'):format(index, coords.x, coords.y, groundZ))

                local label = 'Deliver Boosting Vehicle'
                if Config.Contracts[index] and Config.Contracts[index].label then
                    label = 'Deliver ' .. Config.Contracts[index].label
                end

                exports[Config.TargetResource]:AddTargetEntity(ped, {
                    options = {
                        {
                            label = label,
                            icon = 'fas fa-user-secret',
                            action = function()
                                TriggerEvent('rc2-boosting:client:deliverVehicle', index)
                            end,
                        },
                    },
                    distance = 3.0
                })
            else
                print(('[Rc2-boosting] [ERROR] Could not create ped at %.2f %.2f %.2f'):format(coords.x, coords.y, coords.z))
            end
        end
    end
end

-- Spawn NPCs when resource starts
AddEventHandler('onClientResourceStart', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    Wait(3000)
    CreateContractPed()
    Wait(1000)
    CreateDeliveryPeds()
end)

-- Contract blip
local function CreateContractBlip(coords)
    if DoesBlipExist(ContractBlip) then
        RemoveBlip(ContractBlip)
        ContractBlip = nil
    end

    ContractBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(ContractBlip, 225)
    SetBlipDisplay(ContractBlip, 4)
    SetBlipScale(ContractBlip, 0.9)
    SetBlipColour(ContractBlip, 5)
    SetBlipAsShortRange(ContractBlip, false)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Boosting Target')
    EndTextCommandSetBlipName(ContractBlip)

    SetNewWaypoint(coords.x, coords.y)
end

-- Spawn contract vehicle
local function SpawnContractVehicle(contract)
    local model = GetHashKey(contract.vehicleModel)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end

    local c = contract.spawn
    local veh = CreateVehicle(model, c.x, c.y, c.z, c.w, true, false)

    SetVehicleOnGroundProperly(veh)
    SetVehicleDoorsLocked(veh, 1)
    SetVehicleEngineOn(veh, false, false, false)
    SetVehicleNumberPlateText(veh, contract.plate or ('BST' .. math.random(100, 999)))

    if contract.colors then
        SetVehicleColours(veh, contract.colors.primary, contract.colors.secondary)
    end

    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetVehRadioStation(veh, 'OFF')

    ContractVehicle = veh
    ContractVehicleNetId = NetworkGetNetworkIdFromEntity(veh)

    DebugPrint(('Vehicle spawned at %.2f %.2f %.2f'):format(c.x, c.y, c.z))
end

-- Open menu
RegisterNetEvent('rc2-boosting:client:openMenu', function()
    local menu = {
        {
            header = 'Boosting Contracts',
            txt = 'Pick a contract. Harder = better rewards.',
            isMenuHeader = true
        }
    }

    for tier, data in ipairs(Config.Contracts) do
        menu[#menu+1] = {
            header = string.format('%s - $%s', data.label, data.price),
            txt = string.format(
                'Tier %s | GPS: %s min | Delivery: %s min | Min engine: %s',
                tier, data.gpsTime, data.deliveryTime, math.floor(data.minEngineHealth)
            ),
            params = {
                event = 'rc2-boosting:client:confirmContract',
                args = { tier = tier }
            }
        }
    end

    exports[Config.MenuResource]:openMenu(menu)
end)

-- Confirm contract
RegisterNetEvent('rc2-boosting:client:confirmContract', function(data)
    local tier = tonumber(data.tier)
    local cfg = Config.Contracts[tier]
    if not cfg then return end

    local input = exports[Config.InputResource]:ShowInput({
        header = ('Start %s'):format(cfg.label),
        submitText = 'Start',
        inputs = {
            {
                type = 'text',
                isRequired = true,
                name = 'confirm',
                text = ('Type YES to accept ($%s)'):format(cfg.price)
            }
        }
    })

    if not input or not input.confirm then return end

    if string.upper(input.confirm) ~= 'YES' then
        QBCore.Functions.Notify('You cancelled the contract.', 'error')
        return
    end

    TriggerServerEvent('rc2-boosting:server:purchaseContract', tier)
end)

-- Start contract
RegisterNetEvent('rc2-boosting:client:startContract', function(contract)
    if CurrentContract then
        QBCore.Functions.Notify('You already have an active contract.', 'error')
        return
    end

    CurrentContract = contract
    ContractStolen = false

    SpawnContractVehicle(contract)
    CreateContractBlip(contract.spawn)

    if contract.gpsTime and contract.gpsTime > 0 then
        GpsEndTime = GetGameTimer() + (contract.gpsTime * 60 * 1000)
    end

    if contract.deliveryTime and contract.deliveryTime > 0 then
        DeliveryEndTime = GetGameTimer() + (contract.deliveryTime * 60 * 1000)
    end

    local msg = ('Contract: %s\nVehicle: %s (%s)\nPlate contains: %s')
        :format(
            contract.label or 'Unknown',
            contract.vehicleLabel or contract.vehicleModel or 'Unknown',
            contract.colorLabel or 'Unknown',
            contract.platePartial or '???'
        )

    QBCore.Functions.Notify(msg, 'primary', 10000)

    -- Detect when player steals contract vehicle
    CreateThread(function()
        while CurrentContract and not ContractStolen do
            Wait(500)
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 and veh == ContractVehicle and GetPedInVehicleSeat(veh, -1) == ped then
                ContractStolen = true
                local deliveryIndex = CurrentContract.deliveryIndex or CurrentContract.tier
                local delivery = Config.DeliveryLocations[deliveryIndex]
                if delivery and delivery.coords then
                    CreateContractBlip(delivery.coords)
                    QBCore.Functions.Notify('Buyer location updated on GPS.', 'primary', 5000)
                end
            end
        end
    end)
end)

-- Deliver vehicle
RegisterNetEvent('rc2-boosting:client:deliverVehicle', function(locationIndex)
    if not CurrentContract then
        QBCore.Functions.Notify('You do not have an active contract.', 'error')
        return
    end

    local correctIndex = CurrentContract.deliveryIndex or CurrentContract.tier
    if locationIndex and correctIndex ~= locationIndex then
        QBCore.Functions.Notify('This buyer is not assigned to your contract.', 'error')
        return
    end

    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then
        QBCore.Functions.Notify('You must be driving the contract vehicle.', 'error')
        return
    end

    if GetEntityModel(veh) ~= GetHashKey(CurrentContract.vehicleModel) then
        QBCore.Functions.Notify('This is not the correct vehicle.', 'error')
        return
    end

    local engineHealth = GetVehicleEngineHealth(veh)
    if engineHealth < (CurrentContract.minEngineHealth or 0.0) then
        QBCore.Functions.Notify('The vehicle is too damaged.', 'error')
        return
    end

    local plate = string.upper(GetVehicleNumberPlateText(veh) or '')
    if CurrentContract.platePartial and not string.find(plate, CurrentContract.platePartial, 1, true) then
        QBCore.Functions.Notify('The plate does not match the contract.', 'error')
        return
    end

    local delivery = Config.DeliveryLocations[correctIndex]
    if not delivery or not delivery.coords then
        QBCore.Functions.Notify('No delivery location configured for this contract.', 'error')
        return
    end

    local vCoords = GetEntityCoords(veh)
    local dCoords = vector3(delivery.coords.x, delivery.coords.y, delivery.coords.z)
    local dist = #(vCoords - dCoords)

    if dist > (delivery.radius or 10.0) then
        QBCore.Functions.Notify('Bring the vehicle closer to the buyer.', 'error')
        return
    end

    DeleteVehicle(veh)
    ContractVehicle = nil

    TriggerServerEvent('rc2-boosting:server:completeContract')
end)

-- Finish / fail contract
RegisterNetEvent('rc2-boosting:client:contractFinished', function(data)
    local lastContract = CurrentContract
    local success = data and data.success
    local failed  = data and data.failed
    local expired = data and data.expired

    CurrentContract = nil
    ContractVehicle = nil
    ContractStolen  = false

    if success then
        -- في العقد الرابع GPS يبقى لين ينتهي وقته
        if lastContract and lastContract.tier ~= 4 then
            if DoesBlipExist(ContractBlip) then
                RemoveBlip(ContractBlip)
            end
            ContractBlip = nil
            GpsEndTime = nil
        end
        DeliveryEndTime = nil
        QBCore.Functions.Notify('Contract completed.', 'success')
    else
        if expired then
            QBCore.Functions.Notify('Contract expired.', 'error')
        elseif failed then
            QBCore.Functions.Notify('Contract failed.', 'error')
        end

        if DoesBlipExist(ContractBlip) then
            RemoveBlip(ContractBlip)
        end
        ContractBlip = nil
        GpsEndTime = nil
        DeliveryEndTime = nil
    end
end)
