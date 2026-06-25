-- Inizio blocco di sicurezza (Integrato per evitare errori di caricamento)
if RealisticWeatherLite == nil then
    RealisticWeatherLite = {}
end

RealisticWeatherLite.hailNotified = false
RealisticWeatherLite.snowNotified = false

-- Funzione di sicurezza per leggere le impostazioni senza crashare
function RealisticWeatherLite:getModSettingSafe(name, default)
    if _G.getModSettings ~= nil then
        return _G.getModSettings(name)
    end
    return default
end
-- Fine blocco di sicurezza

function RealisticWeatherLite:onPostLoad(savegame)
    print("--- [RealisticWeatherLite] MOD CARICATA E IN ESECUZIONE ---")
end

-- LOGICA NEBBIA (Sicura)
function RealisticWeatherLite:applyCustomFog(env, dt)
    if env == nil then return end
    
    local isRaining = false
    if env.getIsRaining ~= nil then
        isRaining = env:getIsRaining()
    elseif env.weather ~= nil and env.weather.isRaining ~= nil then
        isRaining = env.weather.isRaining
    end
    
    local dayTime = env.dayTime
    local isMorning = (dayTime >= 18000000 and dayTime <= 32400000)
    
    local targetDensity = (isMorning or isRaining) and 0.2 or 0.05
    local targetDistance = (isMorning or isRaining) and 300 or 1000

    if env.setFog ~= nil then
        env:setFog(targetDensity, targetDistance) 
    end
end

function RealisticWeatherLite:update(dt)
    if g_currentMission == nil or g_currentMission.environment == nil then return end
    
    local env = g_currentMission.environment
    
    -- Utilizzo del blocco di sicurezza per le impostazioni
    local notify = self:getModSettingSafe("notifications_enabled", true)
    local isHailEnabled = self:getModSettingSafe("hailDamage_enabled", true)

    -- 1. ESECUZIONE NEBBIA
    self:applyCustomFog(env, dt)

    -- 2. ACCUMULO NEVE
    local isSnowing = false
    if env.getIsSnowing ~= nil then
        isSnowing = env:getIsSnowing()
    elseif env.weather ~= nil then
        isSnowing = env.weather.isSnowing or false
    end
    
    if isSnowing then
        if env.setSnowCover ~= nil then env:setSnowCover(1.0, 0.001) end
        if not self.snowNotified and notify then
            g_currentMission:showInGameMessage("Meteo", "Bufera in corso!", 5000)
            self.snowNotified = true
        end
    else
        if env.setSnowCover ~= nil then env:setSnowCover(nil, 0.05) end
        self.snowNotified = false
    end

    -- 3. DANNI GRANDINE
    if isHailEnabled then
        local hail = (env.getHailFallScale ~= nil) and env:getHailFallScale() or 0
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