local ESX = exports['es_extended']:getSharedObject()

local weaponLock = false
local weaponEquiped = nil
local hotbarLock = false
local OtherInventory = nil
local handsup = false

local function CreateWarehouseBlips()
    if not WarehouseConfig.Blip.enabled then return end

    for _, warehouse in ipairs(WarehouseConfig.Warehouses) do
        local blip = AddBlipForCoord(warehouse.coords.x, warehouse.coords.y, warehouse.coords.z)
        SetBlipSprite(blip, WarehouseConfig.Blip.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, WarehouseConfig.Blip.scale)
        SetBlipColour(blip, WarehouseConfig.Blip.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(warehouse.label)
        EndTextCommandSetBlipName(blip)
    end
end

local function DrawWarehouseMarker(warehouse)
    if not WarehouseConfig.Marker.enabled then return end
    DrawMarker(
        WarehouseConfig.Marker.type,
        warehouse.coords.x,
        warehouse.coords.y,
        warehouse.coords.z - 1.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        WarehouseConfig.Marker.size.x,
        WarehouseConfig.Marker.size.y,
        WarehouseConfig.Marker.size.z,
        WarehouseConfig.Marker.color.r,
        WarehouseConfig.Marker.color.g,
        WarehouseConfig.Marker.color.b,
        WarehouseConfig.Marker.color.a,
        false,
        true,
        2,
        false,
        nil,
        nil,
        false
    )
end

CreateThread(function()
    CreateWarehouseBlips()

    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        for _, warehouse in ipairs(WarehouseConfig.Warehouses) do
            local distance = #(coords - warehouse.coords)
            if distance <= WarehouseConfig.Marker.drawDistance then
                sleep = 0
                DrawWarehouseMarker(warehouse)
                if distance <= WarehouseConfig.Marker.interactDistance then
                    local helpText = WarehouseConfig.HelpText or 'Drücke ~INPUT_CONTEXT~, um das Lager zu öffnen.'
                    ESX.ShowHelpNotification(helpText)
                    if IsControlJustReleased(0, WarehouseConfig.OpenKey) then
                        TriggerServerEvent('warehouse:open', warehouse.id)
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

local function GetPlayersInArea()
    local players = {}
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    for _, player in ipairs(ESX.Game.GetPlayersInArea(coords, 5.0)) do
        local src = GetPlayerServerId(player)
        local name = GetPlayerName(player)
        players[#players + 1] = {src = src, name = name}
    end

    return players
end

local function GetInventory(otherInv, refresh)
    if otherInv then
        if otherInv.type == 'warehouse' then
            ESX.TriggerServerCallback('inventory:getOtherInventory', function(items, weight)
                if otherInv.timeout and not refresh then
                    Wait(otherInv.timeout)
                end

                local currentWeight, maxWeight = 0, otherInv.weight or 0
                if type(weight) == 'table' then
                    currentWeight = weight.current or 0
                    maxWeight = weight.max or maxWeight
                elseif type(weight) == 'number' then
                    currentWeight = weight
                end
                if maxWeight <= 0 then
                    maxWeight = otherInv.weight or 0
                end

                SendNUIMessage({
                    action = 'setOtherItems',
                    items = items,
                    weight = weight,
                    title = ('%s (%0.2f / %0.2f kg)'):format(
                        otherInv.label or 'Privates Lager',
                        currentWeight / 1000,
                        maxWeight / 1000
                    )
                })
            end, otherInv)
            return
        end

        ESX.TriggerServerCallback('inventory:getOtherInventory', function(items, weight)
            if otherInv.timeout and not refresh then
                Wait(otherInv.timeout)
            end

            SendNUIMessage({
                action = 'setOtherItems',
                items = items,
                weight = weight
            })
        end, otherInv)
    else
        ESX.TriggerServerCallback('inventory:getInventory', function(items, weight, hotbar)
            SendNUIMessage({
                action = 'setItems',
                items = items,
                weight = weight,
                hotbar = hotbar
            })
        end)
    end
end

local function CloseInventory()
    SetNuiFocus(false, false)

    if Config.Blur then
        SetTimecycleModifier('default')
    end

    if not IsPedInAnyVehicle(PlayerPedId()) then
        if Config.Rob then
            handsup = false
        end

        ESX.Streaming.RequestAnimDict('pickup_object', function()
            TaskPlayAnim(PlayerPedId(), 'pickup_object', 'putdown_low', 8.0, 2.0, 1200, 48, 10, 0, 0, 0)
        end)
    end

    TriggerEvent('inventory:close')

    if OtherInventory and OtherInventory.type == 'warehouse' then
        TriggerServerEvent('inventory:closeWarehouse', OtherInventory.id)
    elseif OtherInventory then
        TriggerServerEvent('inventory:close', OtherInventory)
    end

    OtherInventory = nil
end

local function OpenInventory(otherInv)
    if IsPauseMenuActive() then return end
    if weaponLock then return end

    if Config.Blur then
        SetTimecycleModifier('hud_def_blur')
    end

    local hotbar = nil
    hotbarLock = false

    if Config.Hotbar then
        hotbar = {slotCount = Config.HotbarSlots, items = nil}
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        inventory = {type = 'main', title = 'Your <b>Inventory</b>', weight = Config.PlayerWeight},
        otherInventory = otherInv,
        players = GetPlayersInArea(),
        sound = Config.SoundEffects,
        hotbar = hotbar,
        invName = GetCurrentResourceName(),
        middleClickUse = Config.MiddleClickToUse,
        clickOutside = Config.ClickOutsideToClose,
        locales = Locales
    })

    Wait(50)

    GetInventory()
    if otherInv then
        GetInventory(otherInv)
    end

    OtherInventory = otherInv
end

local function UseItemFromHotbar(slot)
    local ped = PlayerPedId()

    ESX.TriggerServerCallback('inventory:getInventory', function(items, weight, hotbar)
        if not hotbar or not hotbar.items then return end

        local item = hotbar.items[slot]

        if item then
            local data
            local found = false

            for _, inventoryItem in pairs(items) do
                if inventoryItem.name == item.name then
                    data = inventoryItem
                    found = true
                    break
                end
            end

            if not found then return end

            if item.type == 'item_standard' then
                if data.use then
                    TriggerServerEvent('esx:useItem', item.name)
                end
            elseif item.type == 'item_weapon' then
                if not weaponLock then
                    weaponLock = true
                    if not weaponEquiped or weaponEquiped.name ~= item.name then
                        weaponEquiped = item
                        ESX.Streaming.RequestAnimDict('reaction@intimidation@1h', function()
                            TaskPlayAnim(ped, 'reaction@intimidation@1h', 'intro', 8.0, 2.0, -1, 48, 2, 0, 0, 0)
                            Wait(1500)
                            ClearPedTasks(ped)
                            SetCurrentPedWeapon(ped, item.name, true)
                            weaponLock = false
                        end)
                    else
                        weaponEquiped = nil
                        ESX.Streaming.RequestAnimDict('reaction@intimidation@1h', function()
                            TaskPlayAnim(ped, 'reaction@intimidation@1h', 'outro', 8.0, 2.0, -1, 48, 2, 0, 0, 0)
                            Wait(1500)
                            ClearPedTasks(ped)
                            SetCurrentPedWeapon(ped, 'WEAPON_UNARMED', true)
                            weaponLock = false
                        end)
                    end
                end
            end
        end
    end)
end

local function ShowHotbar()
    if hotbarLock then return end

    ESX.TriggerServerCallback('inventory:getInventory', function(items, weight, hotbar)
        SendNUIMessage({
            action = 'showHotbar',
            hotbar = hotbar,
            invName = GetCurrentResourceName(),
            timeout = Config.HotbarTimeout
        })
        hotbarLock = true
    end)
end

RegisterCommand('+inventoryHotbar', function()
    ShowHotbar()
end, false)
RegisterCommand('-inventoryHotbar', function() end, false)
RegisterKeyMapping('+inventoryHotbar', 'Zeige Hotbar an', 'keyboard', 'TAB')

RegisterNetEvent('inventory:open', function(otherInv)
    OpenInventory(otherInv)
end)

RegisterNetEvent('inventory:refresh', function()
    GetInventory()
    if OtherInventory then
        GetInventory(OtherInventory, true)
    end
end)

RegisterNUICallback('close', function(_, cb)
    CloseInventory()
    cb('ok')
end)

RegisterNUICallback('useItemFromHotbar', function(data, cb)
    if data and data.slot then
        UseItemFromHotbar(tonumber(data.slot))
    end
    cb('ok')
end)

RegisterNUICallback('closeInventory', function(_, cb)
    CloseInventory()
    cb('ok')
end)

RegisterNUICallback('refreshOther', function(_, cb)
    if OtherInventory then
        GetInventory(OtherInventory, true)
    end
    cb('ok')
end)

RegisterNUICallback('giveHotbar', function(_, cb)
    ShowHotbar()
    cb('ok')
end)

RegisterNetEvent('warehouse:forceClose', function()
    CloseInventory()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    if Config.Blur then
        SetTimecycleModifier('default')
    end

    if OtherInventory and OtherInventory.type == 'warehouse' then
        TriggerServerEvent('inventory:closeWarehouse', OtherInventory.id)
    end
end)
