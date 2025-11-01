local ESX = exports['es_extended']:getSharedObject()

Inventories = Inventories or {}
OpenInventories = OpenInventories or {}
Drops = Drops or {}
dropId = dropId or 0

local warehousesById = {}
for _, warehouse in ipairs(WarehouseConfig.Warehouses) do
    warehousesById[warehouse.id] = warehouse
end

local function GetWarehouseIdentifier(identifier, warehouseId)
    return ('%s:%s'):format(warehouseId, identifier)
end

local function EnsureInventory(type, id)
    if not Inventories[type] then
        Inventories[type] = {}
    end

    if id ~= nil and not Inventories[type][id] then
        Inventories[type][id] = {}
    end
end

local function GetPlayerInventory(xPlayer)
    if not xPlayer then
        return {}, nil, nil
    end

    local items = {}
    local weight = nil
    local hotbar = nil

    if Config.Cash then
        local cash = xPlayer.getMoney()
        if cash > 0 then
            items[#items + 1] = {
                type = 'item_account',
                name = 'cash',
                label = 'Cash',
                count = cash,
                use = false,
                remove = true
            }
        end
    end

    if Config.DirtyCash then
        local account = xPlayer.getAccount(Config.DirtyCash)
        if account and account.money > 0 then
            items[#items + 1] = {
                type = 'item_account',
                name = account.name,
                label = account.label,
                count = account.money,
                use = false,
                remove = true
            }
        end
    end

    if Config.Items then
        local inventory = xPlayer.getInventory()
        for _, v in pairs(inventory) do
            if v.count > 0 then
                items[#items + 1] = {
                    type = 'item_standard',
                    name = v.name,
                    label = v.label,
                    count = v.count,
                    use = v.usable,
                    remove = v.canRemove
                }
            end
        end
    end

    if Config.Weapons then
        local loadout = xPlayer.getLoadout()
        for _, weapon in pairs(loadout) do
            items[#items + 1] = {
                type = 'item_weapon',
                name = weapon.name,
                label = weapon.label,
                count = weapon.ammo,
                use = false,
                remove = true
            }
        end
    end

    if Config.PlayerWeight then
        weight = {current = xPlayer.getWeight(), max = xPlayer.getMaxWeight()}
    else
        weight = false
    end

    if Config.Hotbar then
        local done = promise.new()
        local identifier = xPlayer.getIdentifier()

        EnsureInventory('hotbar')

        if not Inventories['hotbar'][identifier] then
            Inventories['hotbar'][identifier] = {}
            if Config.HotbarSave then
                MySQL.Async.fetchAll('SELECT hotbar FROM users WHERE identifier=@id', {
                    ['@id'] = identifier
                }, function(result)
                    if #result > 0 then
                        Inventories['hotbar'][identifier] = json.decode(result[1].hotbar) or {}
                    end
                    done:resolve()
                end)
            else
                done:resolve()
            end
        else
            done:resolve()
        end

        Citizen.Await(done)

        for slot, data in pairs(Inventories['hotbar'][identifier]) do
            if #items > 0 then
                local found = false
                for _, item in pairs(items) do
                    if item.name == data.name then
                        found = true
                        break
                    end
                end

                if not found then
                    Inventories['hotbar'][identifier][slot] = nil
                end
            else
                Inventories['hotbar'][identifier][slot] = nil
            end
        end

        hotbar = {slotCount = Config.HotbarSlots, items = Inventories['hotbar'][identifier]}
    end

    return items, weight, hotbar
end

local function GetWeightOfItem(item, info)
    local weight = 0

    if item.type == 'item_standard' then
        if Config.PlayerWeight then
            weight = info and info.weight or 0
        else
            weight = Config.Weights[item.name] or 0
        end
    else
        weight = Config.Weights[item.name] or 0
    end

    return weight
end

local function GetWeightOfInventory(xPlayer, inventory)
    local weight = 0

    for _, v in pairs(inventory) do
        if v.type == 'item_weapon' then
            weight = weight + GetWeightOfItem(v)
        else
            local info = xPlayer.getInventoryItem(v.name)
            weight = weight + (v.count * GetWeightOfItem(v, info))
        end
    end

    return weight
end

local function GetInventory(xPlayer, inventory)
    EnsureInventory(inventory.type, inventory.id)

    local items = {}
    local weight = nil

    local done = promise.new()
    if inventory.save then
        if next(Inventories[inventory.type][inventory.id]) == nil then
            MySQL.Async.fetchAll('SELECT * FROM inventories WHERE type=@type AND identifier=@id', {
                ['@type'] = inventory.type,
                ['@id'] = inventory.id
            }, function(result)
                if #result > 0 then
                    Inventories[inventory.type][inventory.id] = json.decode(result[1].data)
                else
                    MySQL.Async.execute('INSERT INTO inventories (type, identifier, data) VALUES (@type, @id, @data)', {
                        ['@type'] = inventory.type,
                        ['@id'] = inventory.id,
                        ['@data'] = json.encode({})
                    }, function()
                        Inventories[inventory.type][inventory.id] = {}
                        print(('^4Inventory created in DB ^7(%s, %s)'):format(inventory.type, inventory.id))
                        done:resolve()
                    end)
                    return
                end
                done:resolve()
            end)
        else
            done:resolve()
        end
    else
        done:resolve()
    end

    Citizen.Await(done)

    for _, v in pairs(Inventories[inventory.type][inventory.id]) do
        if v.type == 'item_account' then
            if v.name == 'cash' then
                if Config.Cash then
                    items[#items + 1] = {
                        type = v.type,
                        name = v.name,
                        label = 'Cash',
                        count = v.count
                    }
                end
            else
                if Config.DirtyCash then
                    local account = xPlayer.getAccount(v.name)
                    local label = account and account.label or v.name
                    items[#items + 1] = {
                        type = v.type,
                        name = v.name,
                        label = label,
                        count = v.count
                    }
                end
            end
        elseif v.type == 'item_weapon' then
            if Config.Weapons then
                items[#items + 1] = {
                    type = v.type,
                    name = v.name,
                    label = ESX.GetWeaponLabel(v.name),
                    count = v.count
                }
            end
        elseif v.type == 'item_standard' then
            if Config.Items then
                local info = xPlayer.getInventoryItem(v.name)
                local label = (info and info.label) or v.label or v.name
                items[#items + 1] = {
                    type = v.type,
                    name = v.name,
                    label = label,
                    count = v.count
                }
            end
        end
    end

    if inventory.weight then
        weight = {current = GetWeightOfInventory(xPlayer, items), max = inventory.weight}
    end

    return items, weight
end

local function SaveInventory(type, id)
    if not Inventories[type] or not Inventories[type][id] then return end

    MySQL.Async.execute('UPDATE inventories SET data=@data WHERE type=@type AND identifier=@id', {
        ['@type'] = type,
        ['@id'] = id,
        ['@data'] = json.encode(Inventories[type][id])
    })
end

local function AddItemToInventory(xPlayer, item, count, inv, cb)
    if not inv then return end

    local inventoryItems, weight = GetInventory(xPlayer, inv)

    if inv.weight then
        local newWeight
        if item.type == 'item_weapon' then
            newWeight = (weight and weight.current or 0) + GetWeightOfItem(item)
        else
            local info = xPlayer.getInventoryItem(item.name)
            newWeight = (weight and weight.current or 0) + (count * GetWeightOfItem(item, info))
        end

        if newWeight > inv.weight then
            xPlayer.triggerEvent('inventory:notify', 'error', 'Inventory would be overweight!')
            return
        end
    end

    local found = false
    for k, v in pairs(inventoryItems) do
        if v.name == item.name and v.type ~= 'item_weapon' then
            inventoryItems[k].count = inventoryItems[k].count + count
            found = true
            break
        end
    end

    if not found then
        inventoryItems[#inventoryItems + 1] = {
            type = item.type,
            name = item.name,
            count = count
        }
    end

    for k in pairs(inventoryItems) do
        inventoryItems[k].label = nil
    end

    Inventories[inv.type][inv.id] = inventoryItems

    if inv.type == 'drop' then
        Drops[inv.id] = Drops[inv.id] or {coords = inv.coords, time = os.time()}
        Drops[inv.id].time = os.time()
        TriggerClientEvent('inventory:refreshDrops', -1, Drops)
    end

    if inv.save then
        SaveInventory(inv.type, inv.id)
    end

    if cb then cb() end

    Refresh(inv.type, inv.id)

    DiscordLog(('%s hat %dx %s in %s eingelagert.'):format(
        xPlayer.getName(),
        count,
        item.name,
        inv.id
    ))
end

local function RemoveItemFromInventory(xPlayer, item, count, inv, cb)
    if not inv then return end

    local inventoryItems = select(1, GetInventory(xPlayer, inv))

    for index, storedItem in pairs(inventoryItems) do
        if storedItem.name == item.name then
            inventoryItems[index].label = nil

            if item.type == 'item_weapon' then
                table.remove(inventoryItems, index)
                if cb then cb() end
            else
                if count > storedItem.count then return end

                local newCount = storedItem.count - count
                if newCount < 1 then
                    table.remove(inventoryItems, index)
                else
                    inventoryItems[index].count = newCount
                end

                if cb then cb() end
            end

            break
        end
    end

    Inventories[inv.type][inv.id] = inventoryItems

    if inv.type == 'drop' then
        if not Inventories['drop'][inv.id] or #Inventories['drop'][inv.id] < 1 then
            Drops[inv.id] = nil
        else
            Drops[inv.id].time = os.time()
        end
        TriggerClientEvent('inventory:refreshDrops', -1, Drops)
    end

    if inv.save then
        SaveInventory(inv.type, inv.id)
    end

    Refresh(inv.type, inv.id)

    DiscordLog(('%s hat %dx %s aus %s entnommen.'):format(
        xPlayer.getName(),
        count,
        item.name,
        inv.id
    ))
end

exports('AddItemToInventory', function(xPlayer, item, count, inv, cb)
    if type(xPlayer) == 'number' then
        xPlayer = ESX.GetPlayerFromId(xPlayer)
    end

    if not xPlayer then
        return false
    end

    AddItemToInventory(xPlayer, item, count, inv, cb)
    return true
end)

exports('RemoveItemFromInventory', function(xPlayer, item, count, inv, cb)
    if type(xPlayer) == 'number' then
        xPlayer = ESX.GetPlayerFromId(xPlayer)
    end

    if not xPlayer then
        return false
    end

    RemoveItemFromInventory(xPlayer, item, count, inv, cb)
    return true
end)

local function CreateDrop(item, count, coords)
    dropId = dropId + 1

    EnsureInventory('drop', dropId)
    Inventories['drop'][dropId] = {{type = item.type, name = item.name, count = count}}
    Drops[dropId] = {coords = coords, time = os.time()}

    TriggerClientEvent('inventory:refreshDrops', -1, Drops)
end

local function Refresh(type, id)
    if OpenInventories[type] == nil then
        OpenInventories[type] = {}
    end

    if OpenInventories[type][id] == nil then
        OpenInventories[type][id] = {}
    end

    for playerId in pairs(OpenInventories[type][id]) do
        TriggerClientEvent('inventory:refresh', playerId, true)
    end
end

local function CloseAllInventoriesForPlayer(source)
    for type, inventories in pairs(OpenInventories) do
        for id, players in pairs(inventories) do
            players[source] = nil
        end
    end
end

local function DropsSync()
    local function drop()
        for id, data in pairs(Drops) do
            if data.time and (os.time() - data.time) > Config.DropTimeout then
                Drops[id] = nil
                TriggerClientEvent('inventory:refreshDrops', -1, Drops)
            end
        end
        SetTimeout(5000, drop)
    end

    SetTimeout(5000, drop)
end

local function DiscordLog(desc)
    if not Config.Discord or Config.WebhookURL == '' then
        return
    end

    local embeds = {{
        color = 5015295,
        title = 'Inventory Log',
        description = desc,
        footer = {text = GetCurrentResourceName()}
    }}

    PerformHttpRequest(Config.WebhookURL, function() end, 'POST', json.encode({embeds = embeds}), {
        ['Content-Type'] = 'application/json'
    })
end

DropsSync()

ESX.RegisterServerCallback('inventory:getInventory', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    local items, weight, hotbar = GetPlayerInventory(xPlayer)
    cb(items, weight, hotbar)
end)

ESX.RegisterServerCallback('inventory:getOtherInventory', function(source, cb, inventory)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        cb({}, {current = 0, max = inventory and inventory.weight or 0})
        return
    end

    if not inventory or not inventory.type or not inventory.id then
        cb({}, {current = 0, max = 0})
        return
    end

    if inventory and inventory.type == 'warehouse' then
        local identifier = xPlayer.getIdentifier()
        local baseId = inventory.id:match('^([^:]+)') or inventory.id
        local expectedId = GetWarehouseIdentifier(identifier, baseId)
        if inventory.owner and inventory.owner ~= identifier then
            cb({}, {current = 0, max = inventory.weight or 0})
            return
        elseif expectedId ~= inventory.id then
            cb({}, {current = 0, max = inventory.weight or 0})
            return
        end
    end

    local items, weight = GetInventory(xPlayer, inventory)
    cb(items, weight)
end)

RegisterNetEvent('warehouse:open', function(warehouseId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local warehouse = warehousesById[warehouseId]
    if not warehouse then
        print(('[warehouse] Unknown warehouse id %s requested by %s'):format(warehouseId, src))
        return
    end

    local identifier = xPlayer.getIdentifier()
    local invId = GetWarehouseIdentifier(identifier, warehouse.id)
    local inventory = {
        type = 'warehouse',
        id = invId,
        label = warehouse.label,
        weight = warehouse.weight,
        save = true,
        timeout = WarehouseConfig.OpenTimeout,
        owner = identifier
    }

    EnsureInventory('warehouse', invId)

    if not OpenInventories['warehouse'] then
        OpenInventories['warehouse'] = {}
    end

    if not OpenInventories['warehouse'][invId] then
        OpenInventories['warehouse'][invId] = {}
    end

    OpenInventories['warehouse'][invId][src] = true

    TriggerClientEvent('inventory:open', src, inventory)
end)

RegisterNetEvent('inventory:closeWarehouse', function(invId)
    local src = source
    if OpenInventories['warehouse'] and OpenInventories['warehouse'][invId] then
        OpenInventories['warehouse'][invId][src] = nil
        if next(OpenInventories['warehouse'][invId]) == nil then
            OpenInventories['warehouse'][invId] = nil
        end
    end
end)

RegisterNetEvent('inventory:close', function(inv)
    local src = source
    if not inv or not inv.type or not inv.id then return end

    if OpenInventories[inv.type] and OpenInventories[inv.type][inv.id] then
        OpenInventories[inv.type][inv.id][src] = nil
        if next(OpenInventories[inv.type][inv.id]) == nil then
            OpenInventories[inv.type][inv.id] = nil
        end
    end
end)

AddEventHandler('playerDropped', function(_reason)
    local src = source
    CloseAllInventoriesForPlayer(src)
end)

AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    CloseAllInventoriesForPlayer(playerId)
end)
