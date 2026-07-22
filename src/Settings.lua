if settings == nil then
    settings = {}
end

settings.CONTROLS = {
    hailDamage = {
        id = "hailDamage_enabled",
        name = "hailDamage_enabled",
        textKey = "hailDamage_enabled",
        value = true
    },
    weatherNotifications = {
        id = "notifications_enabled",
        name = "notifications_enabled",
        textKey = "notifications_enabled",
        value = true
    },
    fogControl = {
        id = "fog_enabled",
        name = "fog_enabled",
        textKey = "fog_enabled",
        value = true
    }
}

-------------------------------------------------------------------------------
-- FUNZIONE GLOBALE LETTURA IMPOSTAZIONI
-------------------------------------------------------------------------------
_G.getModSettings = function(settingName)
    if settings.CONTROLS ~= nil then
        for _, control in pairs(settings.CONTROLS) do
            if control.name == settingName then
                return control.value
            end
        end
    end
    return true
end

-------------------------------------------------------------------------------
-- INIEZIONE NATIVA UI MENU GENERALE FS25 (Metodo BMProd / GIANTS)
-------------------------------------------------------------------------------
function settings:registerSettings()
    if g_gui == nil or g_gui.screenControllers == nil then return end

    local inGameMenu = g_gui.screenControllers[InGameMenu]
    if inGameMenu == nil or inGameMenu.pageSettings == nil then return end

    local settingsPage = inGameMenu.pageSettings
    local layout = settingsPage.generalSettingsLayout or settingsPage.gameSettingsLayout
    if layout == nil then return end

    if settings.isUIInitialized then return end

    -- Utilizziamo il template nativo per interruttori On/Off (Sì/No)
    local template = settingsPage.checkWoodHarvesterAutoCutBox or settingsPage.checkDevelopmentOption
    if template == nil then return end

    for _, control in pairs(settings.CONTROLS) do
        local box = template:clone(layout)
        if box ~= nil then
            box.id = control.id .. "Box"

            -- Recupera l'elemento cliccabile interno e la label
            local menuOption = box.elements[1] or box
            local label = box.elements[2]

            local titleText = g_i18n:hasText(control.textKey) and g_i18n:getText(control.textKey) or control.name
            if label ~= nil and label.setText ~= nil then
                label:setText(titleText)
            elseif box.setLabel ~= nil then
                box:setLabel(titleText)
            end

            -- Evento al cambio di stato
            if menuOption.setCallback ~= nil then
                menuOption:setCallback("onClickCallback", function(_, state)
                    control.value = (state == 1 or state == true)
                    
                    -- Sincronizzazione Multiplayer (invia tutti e 3 i parametri)
                    if g_currentMission ~= nil and RealisticWeatherLiteEvent ~= nil then
                        local hail = _G.getModSettings("hailDamage_enabled")
                        local notify = _G.getModSettings("notifications_enabled")
                        local fog = _G.getModSettings("fog_enabled")

                        RealisticWeatherLiteEvent.sendEvent(hail, notify, fog)
                    end
                end)
            end

            -- Registrazione nel FocusManager (Controller/Pad & Mouse)
            box.focusId = FocusManager:serveAutoFocusId()
            layout:addElement(box)
        end
    end

    settings.isUIInitialized = true
    if layout.invalidateLayout ~= nil then
        layout:invalidateLayout()
    end
end

-------------------------------------------------------------------------------
-- HOOK DI APERTURA FRAME E CARICAMENTO
-------------------------------------------------------------------------------
InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameOpen, function()
    settings:registerSettings()
end)

FSBaseMission.onClientJoined = Utils.appendedFunction(FSBaseMission.onClientJoined, function(self, connection)
    if g_currentMission ~= nil and g_currentMission:getIsServer() and connection ~= nil then
        local hail = _G.getModSettings("hailDamage_enabled")
        local notify = _G.getModSettings("notifications_enabled")
        local fog = _G.getModSettings("fog_enabled")
        
        if RealisticWeatherLiteEvent ~= nil then
            connection:sendEvent(RealisticWeatherLiteEvent.new(hail, notify, fog))
        end
    end
end)