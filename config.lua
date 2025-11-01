Config = Config or {}

local function vec(x, y, z)
    if type(vector3) == 'function' then
        return vector3(x, y, z)
    end

    return {x = x, y = y, z = z}
end

Config.Blur = true
Config.Hotbar = true
Config.HotbarSlots = 5
Config.HotbarTimeout = 3500
Config.SoundEffects = true
Config.MiddleClickToUse = false
Config.ClickOutsideToClose = true
Config.Rob = false
Config.Cash = true
Config.DirtyCash = 'black_money'
Config.Items = true
Config.Weapons = true
Config.PlayerWeight = true
Config.HotbarSave = true
Config.DropTimeout = 300
Config.Weights = Config.Weights or {}
Config.Discord = false
Config.WebhookURL = ''

Locales = Locales or {}

WarehouseConfig = {}
WarehouseConfig.OpenKey = 38 -- E
WarehouseConfig.OpenKeyLabel = '~INPUT_CONTEXT~'
WarehouseConfig.OpenTimeout = 250
WarehouseConfig.Blip = {
    enabled = true,
    sprite = 473,
    color = 3,
    scale = 0.8
}
WarehouseConfig.Marker = {
    enabled = true,
    type = 1,
    size = vec(0.75, 0.75, 0.75),
    color = {r = 50, g = 120, b = 255, a = 150},
    drawDistance = 20.0,
    interactDistance = 1.5
}
WarehouseConfig.HelpText = 'Drücke ~INPUT_CONTEXT~, um dein Lagerhaus zu öffnen.'
WarehouseConfig.Warehouses = {
    {
        id = 'vespucci',
        label = 'Privates Lagerhaus',
        coords = vec(-326.99, -135.19, 39.01),
        weight = 60000
    },
    {
        id = 'sandy',
        label = 'Wüstenlager',
        coords = vec(2568.04, 466.76, 108.73),
        weight = 60000
    }
}
