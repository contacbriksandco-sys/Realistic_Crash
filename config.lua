-- #   _____ _____  _____ _  __  ____          _____ ____  _____  ______ 
-- #  / ____|_   _|/ ____| |/ / / __ \        / ____/ __ \|  __ \|  ____|
-- # | (___   | | | (___ | ' / | |  | |      | |   | |  | | |__) | |__   
-- #  \___ \  | |  \___ \|  <  | |  | |      | |   | |  | |  _  /|  __|  
-- #  ____) |_| |_ ____) | . \ | |__| |      | |___| |__| | | \ \| |____ 
-- # |_____/|_____|_____/|_|\_\ \____/        \_____\____/|_|  \_\______|

-- ============================================================
-- --- 1. RESSOURCES DE BASE & LIBRAIRIES ---
-- ============================================================
-- FR: Configuration du script de crash réaliste.
-- EN: Realistic crash script configuration.
-- ============================================================

Config = {}

-- Reactive tick / Tick réactif
Config.InVehiclePollMs = 0
Config.OutVehiclePollMs = 200

-- Anti-spam
Config.CooldownMs = 220

-- ============================================================
-- Sensors (props/vehicles) / Capteurs (props/véhicules)
-- ============================================================
Config.Sensors = {
    UseCollidedFlag = true,

    UseBodyHealth = true,
    BodyHealthDropMin = 2.5,

    UseDeformation = true,
    DeformDeltaMin = 0.05,
    DeformSamplePos = "front",
}

-- ============================================================
-- Speed bands (km/h) / Intensité par paliers (km/h)
-- ============================================================
Config.SpeedBands = {
    { name="0-10",    minSpeed=0,   maxSpeed=10,   minDelta=1.2, fullDelta=7.0,  gain=0.10 },
    { name="10-30",   minSpeed=10,  maxSpeed=30,   minDelta=2.8, fullDelta=14.0, gain=0.30 },
    { name="30-60",   minSpeed=30,  maxSpeed=60,   minDelta=4.2, fullDelta=18.0, gain=0.70 },
    { name="60-100",  minSpeed=60,  maxSpeed=100,  minDelta=5.5, fullDelta=23.0, gain=0.95 },
    { name="100-130", minSpeed=100, maxSpeed=130,  minDelta=6.8, fullDelta=26.0, gain=1.00 },
    { name="150+",    minSpeed=150, maxSpeed=1000, minDelta=7.8, fullDelta=30.0, gain=1.10 },
}

-- ============================================================
-- Wall scrape filter / Filtre anti-frottement
-- ============================================================
Config.MinDeltaToTriggerAny = 1.6

-- ============================================================
-- Smooth shake (amplitude capped by speed) / Shake fluide (amplitude capée par vitesse)
-- ============================================================
Config.Shake = {
    Name = "SMALL_EXPLOSION_SHAKE",
    AmpMin = 0.03,
    AmpMax = 1.05,
    TotalMinMs = 180,
    TotalMaxMs = 720,
    RampUpMs = 70,
    StepMs = 20,
}

Config.SpeedAmpCaps = {
    { maxSpeed = 10,  cap = 0.10 },
    { maxSpeed = 30,  cap = 0.20 },
    { maxSpeed = 60,  cap = 0.38 },
    { maxSpeed = 100, cap = 0.60 },
    { maxSpeed = 150, cap = 0.78 },
    { maxSpeed = 1000, cap = 1.05 },
}

Config.SpeedRampUp = {
    { maxSpeed = 10,  addMs = 120 },
    { maxSpeed = 30,  addMs = 90 },
    { maxSpeed = 60,  addMs = 50 },
    { maxSpeed = 150, addMs = 20 },
    { maxSpeed = 1000, addMs = 0 },
}

-- ============================================================
-- Blackout (partial black screen) / Blackout (voile noir partiel)
-- ============================================================
Config.Blackout = {
    Enabled = true,

    MinSpeedKmh = 150.0,
    MinIntensity = 0.75,   -- High impact only / Gros choc seulement

    -- Duration / Durée
    DurationMs = 1500,

    -- Partial veil / Voile partiel
    MinAlpha = 60,
    MaxAlpha = 185,

    FadeInMs = 200,
    FadeOutMs = 420,

    -- IMPORTANT: no control blocking / IMPORTANT: aucun blocage de contrôles
    DisableControls = false
}
