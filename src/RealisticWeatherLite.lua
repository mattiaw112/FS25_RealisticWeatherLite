RW_Weather = {}
RW_Weather.FACTOR = {
    SNOW_FACTOR = 0.0005,
    SNOW_HEIGHT = 1.0
}

SnowSystem.MAX_HEIGHT = RW_Weather.FACTOR.SNOW_HEIGHT

-- Stato dinamico nebbia e tracciamento notifiche sicuro
RW_Weather.currentFogDensity = 0.0
RW_Weather.targetFogDensity = 0.0
RW_Weather.currentHeightDensity = 0.0
RW_Weather.targetHeightDensity = 0.0

RW_Weather.hasWarnedHail = false
RW_Weather.hasWarnedSnow = false
RW_Weather.hasWarnedFog = false

-------------------------------------------------------------------------------
-- FUNZIONI HELPER (Forecast FS25)
-------------------------------------------------------------------------------
function RW_Weather:getIsSnowing()
    local _, currentWeather = self.forecast:dataForTime(self.owner.currentMonotonicDay, self.owner.dayTime)
    return currentWeather ~= nil and currentWeather.precipitationType == WeatherType.SNOW
end

function RW_Weather:getSnowFallScale()
    local _, currentWeather = self.forecast:dataForTime(self.owner.currentMonotonicDay, self.owner.dayTime)
    if currentWeather ~= nil and currentWeather.precipitationType == WeatherType.SNOW then
        return currentWeather.dropScale or 1.0
    end
    return 1.0
end

function RW_Weather:getIsRaining()
    local _, currentWeather = self.forecast:dataForTime(self.owner.currentMonotonicDay, self.owner.dayTime)
    return currentWeather ~= nil and currentWeather.precipitationType == WeatherType.RAIN
end

function RW_Weather:getRainFallScale()
    local _, currentWeather = self.forecast:dataForTime(self.owner.currentMonotonicDay, self.owner.dayTime)
    if currentWeather ~= nil and currentWeather.precipitationType == WeatherType.RAIN then
        return currentWeather.dropScale or 1.0
    end
    return 0.0
end

function RW_Weather:getHailFallScale()
    local _, currentWeather = self.forecast:dataForTime(self.owner.currentMonotonicDay, self.owner.dayTime)
    if currentWeather ~= nil and currentWeather.precipitationType == WeatherType.HAIL then
        return currentWeather.dropScale or 1.0
    end
    return 0.0
end

-------------------------------------------------------------------------------
-- SISTEMA NOTIFICHE GARANTITO (Stile HUD Nativo FS25)
-------------------------------------------------------------------------------
function RW_Weather:showNotification(textKey)
    local areNotificationsEnabled = _G.getModSettings and _G.getModSettings("notifications_enabled") or false
    
    -- Verifica che le notifiche siano attive e il giocatore non sia in un menu
    if areNotificationsEnabled and g_currentMission ~= nil then
        if g_gui == nil or g_gui.currentGuiName == "" then
            local message = g_i18n:hasText(textKey) and g_i18n:getText(textKey) or textKey
            
            -- Invia notifica HUD lampeggiante nativa
            if g_currentMission.showBlinkingWarning ~= nil then
                g_currentMission:showBlinkingWarning(message, 6000)
            end
        end
    end
end

-------------------------------------------------------------------------------
-- UPDATE PRINCIPALE: Neve, Grandine, Danni e Notifiche
-------------------------------------------------------------------------------
function RW_Weather:update(superFunc, dT)
    superFunc(self, dT)

    local timescale = dT * g_currentMission:getEffectiveTimeScale()
    local temperature = self.temperatureUpdater:getTemperatureAtTime(self.owner.dayTime)
    local _, currentWeather = self.forecast:dataForTime(self.owner.currentMonotonicDay, self.owner.dayTime)

    ---------------------------------------------------------------------------
    -- 1. GESTIONE NEVE E NOTIFICA NEVICATA / TEMPESTA
    ---------------------------------------------------------------------------
    if g_currentMission.missionInfo.isSnowEnabled then
        local isSnowing = self:getIsSnowing()
        local blizzardFactor = (currentWeather ~= nil and currentWeather.isBlizzard) and 10 or 1
        self.isBlizzard = currentWeather ~= nil and currentWeather.isBlizzard

        if isSnowing and temperature < 10 then
            -- Trigger Notifica Neve
            if not RW_Weather.hasWarnedSnow then
                local alertKey = self.isBlizzard and "rw_blizzard_alert" or "rw_snow_alert"
                RW_Weather:showNotification(alertKey)
                RW_Weather.hasWarnedSnow = true
            end

            local scale = 1 - temperature * 0.1
            self.snowHeight = math.clamp(
                self.snowHeight + RW_Weather.FACTOR.SNOW_FACTOR * (timescale / 100000) * self:getSnowFallScale() * scale * blizzardFactor,
                0, 
                RW_Weather.FACTOR.SNOW_HEIGHT
            )
        else
            -- Reset notifica quando smette di nevicare
            RW_Weather.hasWarnedSnow = false

            if temperature >= 10 then
                self.snowHeight = 0
                g_currentMission.snowSystem:removeAll()
            elseif temperature > 0 and self.snowHeight > 0 then
                local scale = self:getIsRaining() and math.max(5 / self:getRainFallScale(), 1.25) or 1
                self.snowHeight = math.clamp(
                    self.snowHeight - temperature * 0.001 * (timescale / 100000) * scale, 
                    0, 
                    RW_Weather.FACTOR.SNOW_HEIGHT
                )
                if self.snowHeight == 0 then 
                    g_currentMission.snowSystem:removeAll() 
                end
            end
        end
    else
        self.snowHeight = math.max(self.snowHeight - 0.005 * (dT / 1000) * (g_currentMission:getEffectiveTimeScale() / 100), 0)
        self.isBlizzard = false
        RW_Weather.hasWarnedSnow = false
    end

    g_currentMission.snowSystem:setSnowHeight(self.snowHeight)

    ---------------------------------------------------------------------------
    -- 2. GESTIONE GRANDINE, DANNI E NOTIFICA
    ---------------------------------------------------------------------------
    local isHailDamageEnabled = _G.getModSettings and _G.getModSettings("hailDamage_enabled") or false
    local hail = self:getHailFallScale()

    if hail > 0 then
        -- Trigger Notifica Grandine
        if not RW_Weather.hasWarnedHail then
            RW_Weather:showNotification("rw_hail_alert")
            RW_Weather.hasWarnedHail = true
        end

        if isHailDamageEnabled then
            local indoorMask = g_currentMission.indoorMask
            local vehicles = g_currentMission.vehicleSystem.vehicles

            for _, vehicle in pairs(vehicles) do
                local wearable = vehicle.spec_wearable
                if wearable ~= nil then
                    local x, _, z = getWorldTranslation(vehicle.rootNode)
                    if x ~= nil and z ~= nil and not indoorMask:getIsIndoorAtWorldPosition(x, z) then
                        local damageAmount = hail * 0.0001 * (timescale / 100000)
                        local wearAmount = hail * 0.0003 * (timescale / 100000)
                        
                        wearable:addWearAmount(wearAmount, true)
                        wearable:addDamageAmount(damageAmount, true)
                    end
                end
            end
        end
    else
        -- Reset notifica quando smette di grandinare
        RW_Weather.hasWarnedHail = false
    end
end

Weather.update = Utils.overwrittenFunction(Weather.update, RW_Weather.update)

-------------------------------------------------------------------------------
-- 3. GESTIONE NEBBIA DINAMICA E NOTIFICA
-------------------------------------------------------------------------------
FogUpdater.update = Utils.appendedFunction(FogUpdater.update, function(self, dt)
    local isFogEnabled = _G.getModSettings and _G.getModSettings("fog_enabled") or true
    if not isFogEnabled then return end

    local mission = g_currentMission
    local env = mission and mission.environment
    if env == nil or env.weather == nil then return end

    local dayTimeMinutes = (env.dayTime / 1000 / 60) % 1440
    local season = env.currentSeason

    local targetGroundDensity = 0.0
    local targetHeightDensity = 0.0

    -- Nebbia Mattutina (Inverno e Autunno 05:00 - 09:00)
    if season == Season.WINTER or season == Season.AUTUMN then
        if dayTimeMinutes >= 300 and dayTimeMinutes <= 540 then
            local factor = (dayTimeMinutes <= 420) and ((dayTimeMinutes - 300) / 120) or (1.0 - ((dayTimeMinutes - 420) / 120))
            targetGroundDensity = math.max(targetGroundDensity, 0.85 * factor)
            targetHeightDensity = math.max(targetHeightDensity, 0.60 * factor)
        end
    end

    -- Nebbia da Pioggia
    local rainScale = env.weather:getRainFallScale()
    if rainScale > 0 then
        targetGroundDensity = math.max(targetGroundDensity, 0.40 * rainScale)
        targetHeightDensity = math.max(targetHeightDensity, 0.30 * rainScale)
    end

    -- Lerp transizione
    local lerpSpeed = (dt / 1000) * 0.1
    RW_Weather.currentFogDensity = RW_Weather.currentFogDensity + (targetGroundDensity - RW_Weather.currentFogDensity) * lerpSpeed
    RW_Weather.currentHeightDensity = RW_Weather.currentHeightDensity + (targetHeightDensity - RW_Weather.currentHeightDensity) * lerpSpeed

    -- Applicazione C++ e Trigger Notifica Nebbia Fitta
    if RW_Weather.currentFogDensity > 0.01 then
        setGroundFogGlobalCoverage(0.05, 0.95)
        setGroundFogHeight(30.0)
        setGroundFogGroundLevelDensity(RW_Weather.currentFogDensity)
        setGroundFogMinimumValleyDepth(1.5)
        setHeightFogGroundLevelDensity(RW_Weather.currentHeightDensity)
        setHeightFogMaxHeight(700.0)

        -- Notifica attiva solo se la densità supera la soglia di nebbia fitta (> 0.35)
        if not RW_Weather.hasWarnedFog and RW_Weather.currentFogDensity > 0.35 then
            RW_Weather:showNotification("rw_fog_alert")
            RW_Weather.hasWarnedFog = true
        end
    else
        -- Reset notifica nebbia quando si dirada totalmente
        RW_Weather.hasWarnedFog = false
    end
end)

-------------------------------------------------------------------------------
-- SALVATAGGIO E CARICAMENTO XML
-------------------------------------------------------------------------------
function RW_Weather:saveToXMLFile(handle, key)
    local xmlFile = XMLFile.wrap(handle)
    if xmlFile ~= nil then
        xmlFile:setInt(key .. "#lastFogDay", self.lastFogDay or 0)
        xmlFile:save(false, true)
        xmlFile:delete()
    end
end
Weather.saveToXMLFile = Utils.appendedFunction(Weather.saveToXMLFile, RW_Weather.saveToXMLFile)

function RW_Weather:loadFromXMLFile(handle, key)
    local xmlFile = XMLFile.wrap(handle)
    if xmlFile ~= nil then
        self.lastFogDay = xmlFile:getInt(key .. "#lastFogDay", 0)
        xmlFile:delete()
    end
end
Weather.loadFromXMLFile = Utils.prependedFunction(Weather.loadFromXMLFile, RW_Weather.loadFromXMLFile)