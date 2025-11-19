local QBCore = exports[Config.CoreResource]:GetCoreObject()

local ActiveContracts = {}

local function DebugPrint(msg)
    if Config.Debug then
        print('[Rc2-boosting] ' .. msg)
    end
end

local function GetRandomFromList(list)
    if not list or #list == 0 then return nil end
    return list[math.random(1, #list)]
end

local function GeneratePlate()
    local letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    local plate = ''

    for i = 1, 3 do
        local rand = math.random(1, #letters)
        plate = plate .. string.sub(letters, rand, rand)
    end

    plate = plate .. tostring(math.random(1000, 9999))
    return plate
end

local function GetPoliceOnlineCount()
    local count = 0
    local players = QBCore.Functions.GetQBPlayers()
    for _, v in pairs(players) do
        if v.PlayerData.job and v.PlayerData.job.name == Config.PoliceJob and v.PlayerData.job.onduty then
            count = count + 1
        end
    end
    return count
end

local function GetActiveContractsCount()
    local c = 0
    for _ in pairs(ActiveContracts) do
        c = c + 1
    end
    return c
end

-- Buy / start contract
RegisterNetEvent('rc2-boosting:server:purchaseContract', function(tier)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    tier = tonumber(tier)
    local contractCfg = Config.Contracts[tier]
    if not contractCfg then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid contract.', 'error')
        return
    end

    local citizenid = Player.PlayerData.citizenid

    if ActiveContracts[citizenid] then
        TriggerClientEvent('QBCore:Notify', src, 'You already have an active contract.', 'error')
        return
    end

    if GetActiveContractsCount() >= (Config.MaxActiveContracts or 2) then
        TriggerClientEvent('QBCore:Notify', src, 'Too many active boosting contracts right now.', 'error')
        return
    end

    local currentTier = Player.PlayerData.metadata['rc2_boosting_tier'] or 0
    local requiredTier = contractCfg.requiredTier or 0
    if requiredTier > 0 and currentTier < requiredTier then
        TriggerClientEvent('QBCore:Notify', src, 'You must complete the previous contract tier first.', 'error')
        return
    end

    local requiredPolice = contractCfg.requiredPolice or 0
    if requiredPolice > 0 then
        local onlinePolice = GetPoliceOnlineCount()
        if onlinePolice < requiredPolice then
            TriggerClientEvent('QBCore:Notify', src,
                ('Not enough police on duty (%s/%s).'):format(onlinePolice, requiredPolice), 'error')
            return
        end
    end

    local price = contractCfg.price or 0
    if price > 0 then
        if Player.Functions.GetMoney('bank') >= price then
            Player.Functions.RemoveMoney('bank', price, 'boosting-contract')
        else
            TriggerClientEvent('QBCore:Notify', src, 'You do not have enough money.', 'error')
            return
        end
    end

    local vehicleCfg = GetRandomFromList(contractCfg.vehicles)
    if not vehicleCfg then
        TriggerClientEvent('QBCore:Notify', src, 'No vehicles configured for this contract.', 'error')
        return
    end

    local spawn = GetRandomFromList(Config.VehicleSpawns)
    if not spawn then
        TriggerClientEvent('QBCore:Notify', src, 'No vehicle spawn points configured.', 'error')
        return
    end

    local plate = GeneratePlate()
    local partial = string.sub(plate, -3)

    local now = os.time()
    local deliveryTime = contractCfg.deliveryTime or 30
    local gpsTime = contractCfg.gpsTime or 5

    -- Random delivery index for tier 1–3, fixed 4 for tier 4
    local deliveryIndex
    if tier == 4 then
        deliveryIndex = 4
    else
        deliveryIndex = math.random(1, 3)
    end

    local contract = {
        tier            = tier,
        label           = contractCfg.label,
        price           = price,
        gpsTime         = gpsTime,
        deliveryTime    = deliveryTime,
        minEngineHealth = contractCfg.minEngineHealth,
        vehicleModel    = vehicleCfg.model,
        vehicleLabel    = vehicleCfg.label,
        colorLabel      = vehicleCfg.color,
        colors          = vehicleCfg.colors,
        spawn           = spawn,
        plate           = plate,
        platePartial    = partial,
        citizenid       = citizenid,
        reward          = contractCfg.reward,
        startTime       = now,
        expiresAt       = now + (deliveryTime * 60),
        deliveryIndex   = deliveryIndex
    }

    ActiveContracts[citizenid] = contract

    DebugPrint(('New contract for %s | tier %s | vehicle %s | plate %s | drop %s')
        :format(citizenid, tier, contract.vehicleModel, plate, deliveryIndex))

    if Config.Dispatch.Enabled then
        local coords = vector3(spawn.x, spawn.y, spawn.z)

        TriggerClientEvent('cd_dispatch:AddNotification', -1, {
            job_table = Config.Dispatch.Jobs,
            coords    = coords,
            title     = Config.Dispatch.Title,
            message   = Config.Dispatch.Message,
            flash     = 0,
            unique_id = tostring(math.random(0000000, 9999999)),
            sound     = 1,
            blip      = {
                sprite  = Config.Dispatch.BlipSprite,
                scale   = Config.Dispatch.BlipScale,
                colour  = Config.Dispatch.BlipColour,
                flashes = false,
                text    = Config.Dispatch.BlipText,
                time    = gpsTime,
                radius  = 0,
            }
        })
    end

    TriggerClientEvent('rc2-boosting:client:startContract', src, contract)
end)

-- Complete contract
RegisterNetEvent('rc2-boosting:server:completeContract', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local contract = ActiveContracts[citizenid]

    if not contract then
        TriggerClientEvent('QBCore:Notify', src, 'You do not have an active contract.', 'error')
        return
    end

    local now = os.time()
    if contract.expiresAt and now > contract.expiresAt then
        ActiveContracts[citizenid] = nil
        TriggerClientEvent('rc2-boosting:client:contractFinished', src, { expired = true })
        return
    end

    local reward = contract.reward
    if reward and reward.item and reward.amount and reward.amount > 0 then
        Player.Functions.AddItem(reward.item, reward.amount)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[reward.item], 'add')
    end

    local currentTier = Player.PlayerData.metadata['rc2_boosting_tier'] or 0
    if contract.tier and contract.tier > currentTier then
        Player.Functions.SetMetaData('rc2_boosting_tier', contract.tier)
    end

    ActiveContracts[citizenid] = nil
    TriggerClientEvent('rc2-boosting:client:contractFinished', src, { success = true })
end)

-- Fail contract (timeout, etc.)
RegisterNetEvent('rc2-boosting:server:failContract', function(reason)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local contract = ActiveContracts[citizenid]

    if not contract then return end

    ActiveContracts[citizenid] = nil
    TriggerClientEvent('rc2-boosting:client:contractFinished', src, { failed = true, reason = reason or 'unknown' })
end)

-- Cleanup on player drop
AddEventHandler('QBCore:Server:OnPlayerDropped', function(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    ActiveContracts[citizenid] = nil
end)
