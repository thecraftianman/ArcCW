-- credits : fesiug for some things

local function CacheAModel(mdl)
    if SERVER then
        if util.IsValidModel(tostring(mdl)) then
            local cmdl = ents.Create("prop_dynamic")
            cmdl:SetModel(mdl)
            cmdl:Spawn()
            cmdl:Remove()
        end
    else
        util.PrecacheModel(mdl)
    end
end

function ArcCW.CacheAttsModels()
    if !ArcCW.AttMdlPrecached then
        print("ArcCW: Starting caching all attachments models assets.")
        for _, mdl in ipairs(ArcCW.ModelToPrecacheList) do
            CacheAModel(mdl)
        end

        ArcCW.AttMdlPrecached = true
        print("ArcCW: Done caching attachments models. Pretty heavy isn't it?")
    end
end

ArcCW.PrecachedWepSounds = {}

local WepPossibleSfx = {
    "BreathInSound",
    "BreathOutSound",
    "BreathRunOutSound",
    "DropMagazineSounds",
    "FirstShootSound",
    "FirstShootSoundSilenced",
    "FirstDistantShootSound",
    "FirstDistantShootSoundSilenced",
    "ShootSound",
    "LayerSound",
    "ShootSoundSilenced",
    "LayerSoundSilenced",
    "ShootSoundIndoor",
    "LayerSoundIndoor",
    "ShootSoundSilencedIndoor",
    "LayerSoundSilencedIndoor",
    "DistantShootSoundOutdoors",
    "DistantShootSoundOutdoorsSilenced",
    "DistantShootSoundIndoors",
    "DistantShootSoundIndoorsSilenced",
    "ShootSoundTail",
    "ShootSoundTailIndoor",
    "FiremodeSound",
    "ToggleAttSound",
    "ShootDrySound",
    "EnterSightsSound",
    "ExitSightsSound",
    "MeleeHitSound",
    "MeleeHitWallSound",
    "MeleeSwingSound",
    "BackstabSound",
    "TriggerDownSound",
    "TriggerUpSound",
    "ShellSounds",
    "RicochetSounds",
}

local function CacheASound(str)
    local ex = string.GetExtensionFromFilename(str)

    if ex == "ogg" or ex == "wav" or ex == "mp3" then
        if SERVER then
            local cmdl = ents.Create("prop_dynamic")
            str = string.Replace(str, "sound\\", "")
            str = string.Replace(str, "sound/", "" )
            cmdl:EmitSound(str, 0, 100, 0.001, CHAN_WEAPON)
            cmdl:Remove()
        else
            local ply = LocalPlayer()
            if IsValid(ply) then
                ply:EmitSound(str, 75, 100, 0.001, CHAN_WEAPON)
            end
        end
    end
end

function ArcCW.CacheWepSounds(wep, class)
    if !ArcCW.PrecachedWepSounds[class] then
        local SoundsToPrecacheList = {}

        for _, posiblesfx in ipairs(WepPossibleSfx) do
            local sfx = wep[posiblesfx]

            if istable(sfx) then
                for _, sfxinside in ipairs(sfx) do
                    table.insert(SoundsToPrecacheList, sfxinside)
                end
            elseif isstring(sfx) then
                table.insert(SoundsToPrecacheList, sfx)
            end
        end

        for i, sfx in ipairs(SoundsToPrecacheList) do
            timer.Simple(i * 0.01, function()
                CacheASound(sfx)
            end)
        end

        ArcCW.PrecachedWepSounds[class] = true
    end
end

function ArcCW.CacheWeaponsModels()
    if !ArcCW.WepMdlPrecached then
        print("ArcCW: Precaching all weapon models!")

        for _, wep in ipairs(weapons.GetList()) do
            if weapons.IsBasedOn(wep.ClassName, "arccw_base") and wep.ViewModel then
                CacheAModel(wep.ViewModel)
            end
        end

        ArcCW.WepMdlPrecached = true
        print("ArcCW: Finished caching all weapon models, pretty heavy!")
    end
end

function ArcCW.CacheAllSounds()
    for _, wep in ipairs(weapons.GetList()) do
        if weapons.IsBasedOn(wep.ClassName, "arccw_base") and wep.ViewModel then
            ArcCW.CacheWepSounds(wep, wep.ClassName)
        end
    end

    print("ArcCW: Finished caching all weapon sounds.")
end

timer.Simple(1, function()
    if ArcCW.ConVars["precache_wepmodels_onstartup"]:GetBool() then
        ArcCW.CacheWeaponsModels()
    end

    if ArcCW.ConVars["precache_attsmodels_onstartup"]:GetBool() then
        ArcCW.CacheAttsModels()
    end

    if ArcCW.ConVars["precache_allsounds_onstartup"]:GetBool() then
        ArcCW.CacheAllSounds()
    end
end)

concommand.Add("arccw_precache_allsounds", ArcCW.CacheAllSounds)
concommand.Add("arccw_precache_wepmodels", ArcCW.CacheWeaponsModels)
concommand.Add("arccw_precache_attsmodels", ArcCW.CacheAttsModels)