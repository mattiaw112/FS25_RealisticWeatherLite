RealisticWeatherLite = {}

-- Flag per il debug nel log
RealisticWeatherLite.debugDone = false

-- Impostazioni mod
addModSettings("hailDamage", "hailDamage_settings", "hailDamage_enabled", true)
addModSettings("weatherNotifications", "weatherNotifications_settings", "notifications_enabled", true)

-- Variabili di stato
RealisticWeatherLite.fogNotified = false
RealisticWeatherLite.hailNotified = false
RealisticWeatherLite.snowNotified = false

function RealisticWeatherLite:onPostLoad(savegame)
    print("--- [RealisticWeatherLite] MOD CARICATA E IN ESECUZIONE ---")
    
    local guiFile = g_currentModDirectory .. "xml/gui.xml"
    if fileExists(guiFile) then
        g_gui:loadProfiles(guiFile)
    end
end

-- FUNZIONE NEBBIA INTEGRATA (Logica estratta dal sistema originale)
function RealisticWeatherLite:applyCustomFog(env, dt)
    local temperature = env:getTemperature()
    local isRaining = env:getIsRaining()
    local dayTime = env.dayTime
    
    -- Definiamo la mattina (tra le 05:00 e le 09:00)
    local isMorning = (dayTime >= 18000000 and dayTime <= 32400000)
    
    -- Valori predefiniti (sereno)
    local targetDensity = 0.1
    local targetDistance = 300
    
    -- Logica nebbia: se piove o è mattina fredda, la nebbia aumenta
    if isRaining or (temperature < 5 and isMorning) then
        targetDensity = 0.85
        targetDistance = 40
    end
    
    -- Applichiamo il cambiamento se la funzione esiste
    if env.setFog ~= nil then
        env:setFog(targetDensity, targetDistance)
    end
end

function RealisticWeatherLite:update(dt)
    -- Sicurezza: attendiamo che il gioco sia pronto
    if g_currentMission == nil or g_currentMission.environment == nil then
        return
    end

    -- DEBUG (appare solo una volta nel log)
    if not RealisticWeatherLite.debugDone then
        print("--- [RealisticWeatherLite] Update attivo! ---")
        RealisticWeatherLite.debugDone = true
    end

    local env = g_currentMission.environment
    local notify = getModSettings("notifications_enabled")

    -- 1. ESECUZIONE NEBBIA
    self:applyCustomFog(env, dt)

    -- 2. ACCUMULO NEVE
    local isSnowing = env.getIsSnowing and env:getIsSnowing() or false
    if isSnowing then
        if env.setSnowCover ~= nil then
            env:setSnowCover(1.0, 0.05)
        end
        if not self.snowNotified and notify then
            g_currentMission:showInGameMessage("Meteo", "Neve accumulata!", 5000)
            self.snowNotified = true
        end
    else
        self.snowNotified = false
    end

    -- 3. DANNI GRANDINE
    local isHailEnabled = getModSettings("hailDamage_enabled")
    if isHailEnabled then
        local hail = env:getHailFallScale()
        local indoorMask = g_currentMission.indoorMask
        if hail > 0 and indoorMask ~= nil then
            if not self.hailNotified and notify then
                g_currentMission:showInGameMessage("Meteo", "Grandine in arrivo!", 5000)
                self.hailNotified = true
            end

            local vehicles = g_currentMission.vehicleSystem.vehicles
            for _, vehicle in pairs(vehicles) do
                local wearable = vehicle.spec_wearable
                if wearable ~= nil then
                    local x, _, z = getWorldTranslation(vehicle.rootNode)
                    if not indoorMask:getIsIndoorAtWorldPosition(x, z) then
                        local timescale = dt * g_currentMission:getEffectiveTimeScale()
                        local damageAmount = hail * 0.0006 * (timescale / 100000)
                        local wearAmount = hail * 0.0018 * (timescale / 100000)
                        wearable:addWearAmount(wearAmount, true)
                        wearable:addDamageAmount(damageAmount, true)
                    end
                end
            end
        else
            self.hailNotified = false
        end
    end
end

-- IMPORTANTE: Registra l'evento con il nuovo nome
addModEventListener(RealisticWeatherLite)