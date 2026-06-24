RW_WheelDestruction = {}
RW_WheelDestruction.TICKS_PER_DESTRUCTION = 12

function RW_WheelDestruction:destroySnowArea(_, x0, z0, x1, z1, x2, z2)

    local snowSystem = g_currentMission.snowSystem
    local snowHeight = snowSystem:getSnowHeightAtArea(x0, z0, x1, z1, x2, z2)
    local sinkHeight

    if self.ticksSinceLastDestruction == nil then self.ticksSinceLastDestruction = RW_WheelDestruction.TICKS_PER_DESTRUCTION end

    if SnowSystem.MIN_LAYER_HEIGHT < snowHeight and self.ticksSinceLastDestruction >= RW_WheelDestruction.TICKS_PER_DESTRUCTION then
        local mass = self.vehicle:getTotalMass()
        local wheels = 0

        if self.vehicle.spec_wheels ~= nil and self.vehicle.spec_wheels.wheels ~= nil then wheels = #self.vehicle.spec_wheels.wheels end

        local wheelsFull = self.vehicle.spec_wheels.wheels
        for _, wheel in pairs(wheelsFull) do
            if wheel.visualWheels ~= nil and #wheel.visualWheels > 1 then
                wheels = wheels + #wheel.visualWheels - 1
                if wheel == self.wheel then
                    for i, visualWheel in pairs(wheel.visualWheels) do
                        if i == 1 then continue end
                        x2 = x2 + visualWheel.width * 1.2
                        x1 = x1 - visualWheel.width * 1.2
                    end
                end
            end
        end

        local massPerWheel = mass / (wheels == 0 and 1 or wheels)
        sinkHeight = math.max(snowHeight - massPerWheel * 0.0075, SnowSystem.MIN_LAYER_HEIGHT)
        local minSinkHeight = 0

        if mass < 4 then
            minSinkHeight = 1 - massPerWheel * 0.08
        elseif mass < 8 then
            minSinkHeight = 1 - massPerWheel * 0.12
        elseif mass < 11 then
            minSinkHeight = 1 - massPerWheel * 0.17
        elseif mass < 15 then
            minSinkHeight = 1 - massPerWheel * 0.2
        end

        local groundWetness = g_currentMission.environment.weather:getGroundWetness()

        minSinkHeight = math.max(minSinkHeight * (1 - groundWetness), minSinkHeight * 0.75)

        sinkHeight = math.max(sinkHeight, minSinkHeight * snowSystem.height)

        if snowHeight > sinkHeight then

            snowSystem:setSnowHeightAtArea(x0, z0, x1, z1, x2, z2, sinkHeight)
            self.ticksSinceLastDestruction = 0

        end
    end


    self.wheel.physics.snowHeight = sinkHeight or snowHeight


    self.ticksSinceLastDestruction = self.ticksSinceLastDestruction >= RW_WheelDestruction.TICKS_PER_DESTRUCTION - 1 and RW_WheelDestruction.TICKS_PER_DESTRUCTION or self.ticksSinceLastDestruction + 1

end

WheelDestruction.destroySnowArea = Utils.overwrittenFunction(WheelDestruction.destroySnowArea, RW_WheelDestruction.destroySnowArea)