RealisticWeatherLiteEvent = {}
RealisticWeatherLiteEvent_mt = Class(RealisticWeatherLiteEvent, Event)

InitEventClass(RealisticWeatherLiteEvent, "RealisticWeatherLiteEvent")

function RealisticWeatherLiteEvent.emptyNew()
    return Event.new(RealisticWeatherLiteEvent_mt)
end

function RealisticWeatherLiteEvent.new(hailDamage, notifications)
    local self = RealisticWeatherLiteEvent.emptyNew()
    self.hailDamage = hailDamage
    self.notifications = notifications
    return self
end

-- Legge i dati inviati attraverso la rete
function RealisticWeatherLiteEvent:readStream(streamId, connection)
    self.hailDamage = streamReadBool(streamId)
    self.notifications = streamReadBool(streamId)
    self:run(connection)
end

-- Scrive i dati da mandare sulla rete
function RealisticWeatherLiteEvent:writeStream(streamId, connection)
    streamWriteBool(streamId, self.hailDamage)
    streamWriteBool(streamId, self.notifications)
end

-- Esegue la sincronizzazione vera e propria
function RealisticWeatherLiteEvent:run(connection)
    if settings ~= nil and settings.CONTROLS ~= nil then
        settings.CONTROLS.hailDamage.value = self.hailDamage
        settings.CONTROLS.weatherNotifications.value = self.notifications
        print("[WeatherNet] Impostazioni di rete sincronizzate dal server!")
    end

    -- Se l'evento è arrivato al Server da un client Admin, il Server lo rimanda a tutti gli altri
    if g_server ~= nil and not connection:getIsServer() then
        g_server:broadcastEvent(RealisticWeatherLiteEvent.new(self.hailDamage, self.notifications), nil, connection)
    end
end