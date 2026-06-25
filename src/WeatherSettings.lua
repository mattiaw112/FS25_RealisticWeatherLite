-- RIGA 1: PROTEZIONE DI AVVIO
if addModSettings == nil then
    _G.addModSettings = function(name, group, key, default) 
        print("--- [WeatherSettings] ATTENZIONE: addModSettings non ancora pronto, salto registrazione ---") 
    end
end

WeatherSettings = {}
WeatherSettings.CONTROLS = {}

-- Ora queste chiamate non faranno più crashare il gioco
addModSettings("hailDamage", "hailDamage_settings", "hailDamage_enabled", true)
addModSettings("weatherNotifications", "weatherNotifications_settings", "notifications_enabled", true)

-- 2. Definizione controlli
WeatherSettings.CONTROLS.hailDamage = {
    id = "hailDamageEnabled",
    name = "hailDamage_enabled",
    type = "bool",
    title = "Abilita Danni Grandine",
    value = true
}

WeatherSettings.CONTROLS.weatherNotifications = {
    id = "notificationsEnabled",
    name = "notifications_enabled",
    type = "bool",
    title = "Abilita Notifiche Meteo",
    value = true
}

-- 3. Hook sicuro per il menu
if FocusManager ~= nil then
    FocusManager.setGui = Utils.appendedFunction(FocusManager.setGui, function(_, gui)
        if gui == "ingameMenuSettings" then
            if g_gui ~= nil and g_gui.screenControllers[InGameMenu] ~= nil then
                local settingsPage = g_gui.screenControllers[InGameMenu].pageSettings
                if settingsPage ~= nil and settingsPage.gameSettingsLayout ~= nil then
                    for _, control in pairs(WeatherSettings.CONTROLS) do
                        if not control.focusId or not FocusManager.currentFocusData.idToElementMapping[control.focusId] then
                            FocusManager:loadElementFromCustomValues(control, nil, nil, false, false)
                        end
                    end
                    settingsPage.gameSettingsLayout:invalidateLayout()
                end
            end
        end
    end)
end

-- 4. Funzione GLOBALE di sicurezza
_G.getModSettings = function(settingName)
    if WeatherSettings.CONTROLS == nil then return true end
    for _, control in pairs(WeatherSettings.CONTROLS) do
        if control.name == settingName then
            return control.value
        end
    end
    return true
end

print("--- [WeatherSettings] Caricato con protezione attiva ---")