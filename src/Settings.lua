if Settings == nil then
    Settings = {}
end

Settings.CONTROLS = {
    hailDamage = {
        id = "hailDamageEnabled",
        name = "hailDamage_enabled",
        type = "bool",
        title = "Abilita Danni Grandine",
        value = true
    },
    weatherNotifications = {
        id = "notificationsEnabled",
        name = "notifications_enabled",
        type = "bool",
        title = "Abilita Notifiche Meteo",
        value = true
    }
}

-------------------------------------------------------------------------------
-- FUNZIONE GLOBALE DI LETTURA DELLE IMPOSTAZIONI
-------------------------------------------------------------------------------
_G.getModSettings = function(settingName)
    if Settings.CONTROLS ~= nil then
        for _, control in pairs(Settings.CONTROLS) do
            if control.name == settingName then
                return control.value
            end
        end
    end
    return true
end

-------------------------------------------------------------------------------
-- FUNZIONE GLOBALE PER CAMBIARE UN'IMPOSTAZIONE
-------------------------------------------------------------------------------
_G.setModSetting = function(settingName, newValue)
    if Settings.CONTROLS ~= nil then
        for _, control in pairs(Settings.CONTROLS) do
            if control.name == settingName then
                control.value = newValue
                print(string.format("[settings.lua] Impostazione '%s' cambiata a: %s", settingName, tostring(newValue)))
                return
            end
        end
    end
end

-------------------------------------------------------------------------------
-- AGGANCIO AL MENU DI GIOCO INGAME (SAFE HOOK PER FS25)
-------------------------------------------------------------------------------
local function injectSettingsMenu(targetPage)
    if targetPage == nil or targetPage.gameSettingsLayout == nil then return end

    if targetPage.rwSettingsInjected then return end

    local layout = targetPage.gameSettingsLayout

    for _, control in pairs(Settings.CONTROLS) do
        if targetPage.checkDevelopmentOption ~= nil then
            print(string.format("[settings.lua] Registro opzione menu: %s", control.title))
        end
    end

    targetPage.rwSettingsInjected = true
    if layout.invalidateLayout ~= nil then
        layout:invalidateLayout()
    end
end

if InGameMenuSettings ~= nil and InGameMenuSettings.onFrameOpen ~= nil then
    InGameMenuSettings.onFrameOpen = Utils.appendedFunction(InGameMenuSettings.onFrameOpen, function(self)
        pcall(injectSettingsMenu, self)
    end)
end

print("--- [settings.lua] Caricato e pronto per FS25 ---")