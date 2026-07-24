RW_WheelPhysics = {}

function RW_WheelPhysics:updateFriction(superFunc, vehicle, ...)
    superFunc(vehicle, ...)

    if self.hasSnowContact then
        local groundWetness = 0
        local snowFactor = 1.0

        if self.snowHeight ~= nil then
            snowFactor = 1 + (self.snowHeight * 0.33)
        end

        local friction = self.tireGroundFrictionCoeff

        -- Controllo se il veicolo utilizza i cingolati (isCrawler)
        local isCrawler = false
        if self.vehicle.spec_wheels ~= nil and self.vehicle.spec_wheels.crawlers ~= nil then
            for _, crawler in pairs(self.vehicle.spec_wheels.crawlers) do
                if crawler == self then
                    isCrawler = true
                    break
                end
            end
        end

        if isCrawler then
            -- I cingolati offrono molta più aderenza sulla neve rispetto alle ruote normali
            friction = friction * 1.35
        else
            -- Gestione della gommatura (larghezza vs peso del veicolo)
            local width = self.width or 0.6
            local mass = self.vehicle:getTotalMass() or 10
            local numWheels = #self.vehicle.spec_wheels.wheels or 4
            local widthToMassRatio = math.min(width / (mass / numWheels), 1)

            -- Riduzione base dell'attrito sulla neve per far scivolare il mezzo
            friction = friction * 0.65

            -- Trattori leggeri con gomme larghe tendono a galleggiare e perdere più aderenza (andando dritti)
            if mass < 8 then
                if widthToMassRatio > 0.06 then
                    friction = friction * 0.85 -- Scivola di più con gomme larghe su mezzi leggeri
                else
                    friction = friction * 1.15 -- Più aderenza con gomme strette (tagliano la neve)
                end
            end
        end

        -- Effetto velocità: a velocità elevate si perde ulteriore carico laterale (sottosterzo sulla neve)
        local speed = self.vehicle:getLastSpeed()
        if speed > 10 then
            local speedFactor = math.min(speed / 40, 1.25)
            friction = friction / speedFactor
        end

        if friction ~= self.tireGroundFrictionCoeff then
            self.tireGroundFrictionCoeff = friction
            self.isFrictionDirty = true
        end
    end
end

WheelPhysics.updateFriction = Utils.overwrittenFunction(WheelPhysics.updateFriction, RW_WheelPhysics.updateFriction)