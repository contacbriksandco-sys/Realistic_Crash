-- #   _____ _____  _____ _  __  ____          _____ ____  _____  ______ 
-- #  / ____|_   _|/ ____| |/ / / __ \        / ____/ __ \|  __ \|  ____|
-- # | (___   | | | (___ | ' / | |  | |      | |   | |  | | |__) | |__   
-- #  \___ \  | |  \___ \|  <  | |  | |      | |   | |  | |  _  /|  __|  
-- #  ____) |_| |_ ____) | . \ | |__| |      | |___| |__| | | \ \| |____ 
-- # |_____/|_____|_____/|_|\_\ \____/        \_____\____/|_|  \_\______|

-- ============================================================
-- --- 1. RESSOURCES DE BASE & LIBRAIRIES ---
-- ============================================================
-- FR: Logique client pour les effets de crash réalistes.
-- EN: Client-side logic for realistic crash effects.
-- ============================================================

local lastSpeedKmh = 0.0
local lastTrigger = 0

-- Blackout state / État du voile noir
local blackout = {
    active = false,
    untilMs = 0,
    alpha = 0.0,
    maxAlpha = 0.0,
    fadeInEnd = 0,
    fadeOutStart = 0
}

-- Sensors cache / Cache des capteurs
local lastBodyHealth = nil
local lastDeform = nil

local function clamp(x,a,b)
    if x < a then return a end
    if x > b then return b end
    return x
end
local function lerp(a,b,t) return a + (b-a)*t end
local function nowMs() return GetGameTimer() end
local function toKmh(ms) return ms * 3.6 end

local function easeOutQuad(t)
    t = clamp(t, 0.0, 1.0)
    return 1.0 - (1.0 - t) * (1.0 - t)
end
local function easeInOutCubic(t)
    t = clamp(t, 0.0, 1.0)
    if t < 0.5 then
        return 4.0 * t * t * t
    else
        local f = (-2.0 * t + 2.0)
        return 1.0 - (f * f * f) / 2.0
    end
end

local function getBand(speedKmh)
    for _, b in ipairs(Config.SpeedBands) do
        if speedKmh >= b.minSpeed and speedKmh < b.maxSpeed then
            return b
        end
    end
    return Config.SpeedBands[#Config.SpeedBands]
end

local function getAmpCapForSpeed(speedKmh)
    for _, v in ipairs(Config.SpeedAmpCaps) do
        if speedKmh <= v.maxSpeed then return v.cap end
    end
    return Config.SpeedAmpCaps[#Config.SpeedAmpCaps].cap
end

local function getRampAddForSpeed(speedKmh)
    for _, v in ipairs(Config.SpeedRampUp) do
        if speedKmh <= v.maxSpeed then return v.addMs end
    end
    return 0
end

local function computeIntensity(speedBeforeKmh, deltaKmh)
    local band = getBand(speedBeforeKmh)
    if deltaKmh < band.minDelta then return 0.0 end

    local t = (deltaKmh - band.minDelta) / (band.fullDelta - band.minDelta)
    t = clamp(t, 0.0, 1.0)

    local curve = t ^ 1.15
    return clamp(curve * band.gain, 0.0, 1.0)
end

local function sampleDeform(veh)
    local pos = (Config.Sensors.DeformSamplePos == "front") and vector3(0.0, 2.2, 0.2) or vector3(0.0, 0.0, 0.0)
    local d = GetVehicleDeformationAtPos(veh, pos)
    return math.sqrt(d.x*d.x + d.y*d.y + d.z*d.z)
end

local function anySignalNow(veh)
    local collided = Config.Sensors.UseCollidedFlag and HasEntityCollidedWithAnything(veh) or false

    local bodyOk = false
    if Config.Sensors.UseBodyHealth then
        local body = GetVehicleBodyHealth(veh)
        if lastBodyHealth ~= nil then
            local drop = math.max(0.0, lastBodyHealth - body)
            bodyOk = drop >= Config.Sensors.BodyHealthDropMin
        end
        lastBodyHealth = body
    end

    local deformOk = false
    if Config.Sensors.UseDeformation then
        local deform = sampleDeform(veh)
        if lastDeform ~= nil then
            local dd = math.max(0.0, deform - lastDeform)
            deformOk = dd >= Config.Sensors.DeformDeltaMin
        end
        lastDeform = deform
    end

    return collided or bodyOk or deformOk
end

local function triggerShakeSmooth(intensity, speedBeforeKmh)
    local n = nowMs()
    if (n - lastTrigger) < Config.CooldownMs then return end
    lastTrigger = n

    local total = math.floor(lerp(Config.Shake.TotalMinMs, Config.Shake.TotalMaxMs, intensity))
    local rampUpBase = Config.Shake.RampUpMs + getRampAddForSpeed(speedBeforeKmh)
    local rampUp = math.min(rampUpBase, math.floor(total * 0.60))
    local start = nowMs()

    local maxAmp = lerp(Config.Shake.AmpMin, Config.Shake.AmpMax, intensity)
    local cap = getAmpCapForSpeed(speedBeforeKmh)
    if maxAmp > cap then maxAmp = cap end

    CreateThread(function()
        while true do
            local t = nowMs() - start
            if t >= total then break end

            local amp
            if t <= rampUp then
                local k = easeInOutCubic(t / math.max(rampUp, 1))
                amp = maxAmp * k
            else
                local k = easeOutQuad((t - rampUp) / math.max(total - rampUp, 1))
                amp = maxAmp * (1.0 - k)
            end

            if amp > 0.005 then
                ShakeGameplayCam(Config.Shake.Name, amp)
            end

            Wait(Config.Shake.StepMs)
        end
        StopGameplayCamShaking(true)
    end)
end

local function startBlackout(intensity)
    if not Config.Blackout.Enabled then return end
    if blackout.active then return end

    local n = nowMs()
    blackout.active = true
    blackout.untilMs = n + Config.Blackout.DurationMs
    blackout.fadeInEnd = n + Config.Blackout.FadeInMs
    blackout.fadeOutStart = blackout.untilMs - Config.Blackout.FadeOutMs

    blackout.maxAlpha = clamp(lerp(Config.Blackout.MinAlpha, Config.Blackout.MaxAlpha, intensity) / 255.0, 0.0, 1.0)
end

-- Render blackout (no controls blocked) / Rendu du blackout (aucun contrôle bloqué)
CreateThread(function()
    while true do
        if not Config.Blackout.Enabled then
            Wait(400)
        elseif not blackout.active and blackout.alpha < 0.01 then
            Wait(150)
        else
            Wait(0)
            local n = nowMs()
            local target = 0.0

            if blackout.active then
                if n <= blackout.fadeInEnd then
                    local t = (n - (blackout.fadeInEnd - Config.Blackout.FadeInMs)) / Config.Blackout.FadeInMs
                    target = lerp(0.0, blackout.maxAlpha, easeInOutCubic(t))
                elseif n >= blackout.fadeOutStart then
                    local t = (n - blackout.fadeOutStart) / Config.Blackout.FadeOutMs
                    target = lerp(blackout.maxAlpha, 0.0, easeInOutCubic(t))
                else
                    target = blackout.maxAlpha
                end
            end

            blackout.alpha = blackout.alpha + (target - blackout.alpha) * 0.14

            if blackout.alpha > 0.01 then
                DrawRect(0.5, 0.5, 1.0, 1.0, 0, 0, 0, math.floor(blackout.alpha * 255.0))
            end

            if blackout.active and n >= blackout.untilMs then
                blackout.active = false
            end
        end
    end
end)

-- Main loop / Boucle principale
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local inVeh = IsPedInAnyVehicle(ped, false)
        Wait(inVeh and Config.InVehiclePollMs or Config.OutVehiclePollMs)

        if not inVeh then
            lastSpeedKmh = 0.0
            lastBodyHealth = nil
            lastDeform = nil
            goto continue
        end

        local veh = GetVehiclePedIsIn(ped, false)
        if veh == 0 then goto continue end

        -- Only driver feels the crash / Seul le conducteur ressent le crash
        if GetPedInVehicleSeat(veh, -1) ~= ped then
            lastSpeedKmh = 0.0
            lastBodyHealth = nil
            lastDeform = nil
            goto continue
        end

        local speedKmh = toKmh(GetEntitySpeed(veh))
        local rawDelta = lastSpeedKmh - speedKmh
        if rawDelta < 0 then rawDelta = 0 end

        -- Wall scrape filter / Filtre anti-frottement
        if rawDelta < Config.MinDeltaToTriggerAny then
            lastSpeedKmh = speedKmh
            goto continue
        end

        -- Requires a collision/props signal / Signal collision/props requis
        local signal = anySignalNow(veh)
        if signal then
            local intensity = computeIntensity(lastSpeedKmh, rawDelta)
            if intensity > 0.0 then
                triggerShakeSmooth(intensity, lastSpeedKmh)

                -- Blackout only for high impacts (no control lock) / Blackout uniquement gros impacts (pas de blocage)
                if Config.Blackout.Enabled
                    and lastSpeedKmh >= Config.Blackout.MinSpeedKmh
                    and intensity >= Config.Blackout.MinIntensity
                then
                    startBlackout(intensity)
                end
            end
        end

        lastSpeedKmh = speedKmh
        ::continue::
    end
end)
