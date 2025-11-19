Config = {}

Config.Debug = false

Config.CoreResource      = 'qb-core'
Config.MenuResource      = 'Rc2-menu'
Config.InventoryResource = 'Rc2-inventory'
Config.InputResource     = 'Rc2-input'
Config.TargetResource    = 'qb-target'

Config.PoliceJob = 'police'

-- Max number of active contracts on the whole server
Config.MaxActiveContracts = 2

-- cd_dispatch config
Config.Dispatch = {
    Enabled    = true,
    Jobs       = { 'police' },
    Title      = '10-99 - Boosting',
    Message    = 'Suspicious activity involving a high-end vehicle.',
    BlipSprite = 595,
    BlipColour = 3,
    BlipScale  = 1.0,
    BlipText   = 'Boosting Contract'
}

-- Contract giver NPC (take contracts here)
Config.ContractPed = {
    model    = 'a_m_y_business_01',
    coords   = vector4(-108.26, 6219.41, 31.33, 126.0),
    scenario = 'WORLD_HUMAN_CLIPBOARD'
}

-- Vehicle spawn when contract is taken (must steal it)
Config.VehicleSpawns = {
    vector4(-118.83, 6211.15, 31.20, 46.0)
}

-- Delivery locations:
-- 1,2,3 = random for contracts 1–3
-- 4     = fixed for contract 4
Config.DeliveryLocations = {
    [1] = {
        coords   = vector4(1954.23, 4646.85, 40.66, 242.0),
        radius   = 10.0,
        pedModel = 'a_m_m_farmer_01'
    },
    [2] = {
        coords   = vector4(598.44, 106.23, 92.90, 254.0),
        radius   = 12.0,
        pedModel = 'a_m_m_farmer_01'
    },
    [3] = {
        coords   = vector4(230.37, 1158.45, 225.47, 277.0),
        radius   = 12.0,
        pedModel = 'a_m_m_business_01'
    },
    [4] = {
        coords   = vector4(512.75, -3057.43, 6.07, 1.0),
        radius   = 12.0,
        pedModel = 'a_m_m_eastsa_02'
    },
}

-- Contracts setup (GPS, delivery timers, police, rewards, progression)
Config.Contracts = {
    [1] = {
        label           = "D-Class Contract",
        price           = 1000,
        gpsTime         = 4,      -- minutes
        deliveryTime    = 30,     -- minutes
        minEngineHealth = 550.0,
        requiredPolice  = 0,
        requiredTier    = 0,      -- no requirement
        reward = {
            item   = 'advancedlockpick',
            amount = 1
        },
        vehicles = {
            { model = 'sultan',  label = 'Karin Sultan',        color = 'Black',  colors = { primary = 0,   secondary = 0   } },
            { model = 'oracle',  label = 'Ubermacht Oracle',    color = 'Silver', colors = { primary = 4,   secondary = 4   } },
            { model = 'felon',   label = 'Lampadati Felon',     color = 'Blue',   colors = { primary = 64,  secondary = 64  } },
        },
    },

    [2] = {
        label           = "C-Class Contract",
        price           = 2500,
        gpsTime         = 6,
        deliveryTime    = 30,
        minEngineHealth = 700.0,
        requiredPolice  = 0,
        requiredTier    = 1,      -- must have completed tier 1
        reward = {
            item   = 'ziptie',
            amount = 1
        },
        vehicles = {
            { model = 'schafter3', label = 'Benefactor Schafter V12', color = 'Black',  colors = { primary = 0,   secondary = 0   } },
            { model = 'buffalo',   label = 'Bravado Buffalo',         color = 'Red',    colors = { primary = 27,  secondary = 27  } },
            { model = 'kuruma',    label = 'Karin Kuruma',            color = 'White',  colors = { primary = 111, secondary = 111 } },
        },
    },

    [3] = {
        label           = "B-Class Contract",
        price           = 5000,
        gpsTime         = 8,
        deliveryTime    = 30,
        minEngineHealth = 800.0,
        requiredPolice  = 0,
        requiredTier    = 2,      -- must have completed tier 2
        reward = {
            item   = 'Key1',      -- house robbery key
            amount = 1
        },
        vehicles = {
            { model = 'paragon',   label = 'Enus Paragon',       color = 'Matte Black', colors = { primary = 12,  secondary = 12  } },
            { model = 'comet6',    label = 'Pfister Comet S2',   color = 'Blue',        colors = { primary = 64,  secondary = 64  } },
            { model = 'feltzer2',  label = 'Benefactor Feltzer', color = 'White',       colors = { primary = 111, secondary = 111 } },
        },
    },

    [4] = {
        label           = "A-Class Contract",
        price           = 10000,
        gpsTime         = 10,
        deliveryTime    = 20,
        minEngineHealth = 900.0,
        requiredPolice  = 0,
        requiredTier    = 3,      -- must have completed tier 3
        reward = {
            item   = 'crafttable',
            amount = 1
        },
        vehicles = {
            { model = 'italirsx', label = 'Grotti Itali RSX',   color = 'Red',    colors = { primary = 27,  secondary = 27  } },
            { model = 'ignus',    label = 'Pegassi Ignus',      color = 'Yellow', colors = { primary = 88,  secondary = 88  } },
            { model = 'krieger',  label = 'Benefactor Krieger', color = 'Silver', colors = { primary = 4,   secondary = 4   } },
        },
    },
}
