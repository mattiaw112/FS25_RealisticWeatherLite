RealisticWeatherLite = {}

-- Variabili di stato
RealisticWeatherLite.hailNotified = false
RealisticWeatherLite.snowNotified = false

function RealisticWeatherLite:onPostLoad(savegame)
    print("--- [RealisticWeatherLite] MOD CARICATA E IN ESECUZIONE ---")
end

-- LOGICA NEBBIA (Quella avanzata)
function RealisticWeatherLite:applyCustomFog(env, dt)
    local isRaining = env:getIsRaining()
    local dayTime = env.dayTime
    
    -- Definiamo la mattina (tra le 05:00 e le 09:00)
    local isMorning = (dayTime >= 18000000 and dayTime <= 32400000)
    
    -- Valori predefiniti (sereno)
    local targetDensity = 0.05
    local targetDistance = 1000

    -- Se è mattina o piove, applichiamo la nebbia
    if isMorning or isRaining then
        targetDensity = 0.2
        targetDistance = 300
    end

    if env.setFog ~= nil then
        env:setFog(targetDensity, targetDistance) 
    end
end

function RealisticWeatherLite:update(dt)
    if g_currentMission == nil or g_currentMission.environment == nil then return end
    
    local env = g_currentMission.environment
    
    -- Leggiamo le impostazioni (il gioco le ha già caricate tramite WeatherSettings.lua)
    local notify = getModSettings("notifications_enabled")
    local isHailEnabled = getModSettings("hailDamage_enabled")

    -- 1. ESECUZIONE NEBBIA
    self:applyCustomFog(env, dt)

    -- 2. ACCUMULO NEVE "BUFERA" (Effetto 1 metro)
    local isSnowing = env.getIsSnowing and env:getIsSnowing() or false
    
    if isSnowing then
        -- Profondità 1.0 (1 metro), Scioglimento lentissimo (0.001)
        if env.setSnowCover ~= nil then
            env:setSnowCover(1.0, 0.001)
        end
        
        if not self.snowNotified and notify then
            g_currentMission:showInGameMessage("Meteo", "Bufera in corso! Neve alta in arrivo!", 5000)
            self.snowNotified = true
        end
    else
        if env.setSnowCover ~= nil then
            env:setSnowCover(nil, 0.05)
        end
        self.snowNotified = false
    end

    -- 3. DANNI GRANDINE
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

addModEventListener(RealisticWeatherLite)