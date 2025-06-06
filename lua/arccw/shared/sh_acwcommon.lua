ArcCW.EnableCustomization = true
ArcCW.PresetPath          = "arccw_presets/"

ArcCW.NoDraw = true

ArcCW.HUToM    = 0.0254 -- 1 / 12 * 0.3048
ArcCW.MOAToAcc = 0.00092592592 -- 10 / 180 / 60
ArcCW.RecoilUnit = 41.4 -- lbfps

ArcCW.STATE_IDLE      = 0
ArcCW.STATE_SIGHTS    = 1
ArcCW.STATE_SPRINT    = 2
ArcCW.STATE_DISABLE   = 3
ArcCW.STATE_CUSTOMIZE = 4
ArcCW.STATE_BIPOD     = 5

ArcCW.SCROLL_NONE = 0
ArcCW.SCROLL_ZOOM = 1

ArcCW.FLASH_ATT_CONSTANT = 0
ArcCW.FLASH_ATT_LINEAR = 1
ArcCW.FLASH_ATT_QUADRATIC = 2

ArcCW.VolumetricLightModel = "models/effects/vol_light256x384.mdl"
ArcCW.VolumetricLightX = 256
ArcCW.VolumetricLightY = 256
ArcCW.VolumetricLightZ = 384

-- Special clip size denoting an bottomless clip
ArcCW.BottomlessMagicNumber = -1

COND_WEAPON_HAS_LOS = 41
COND_WEAPON_SIGHT_OCCLUDED = 45

ArcCW.ShellSoundsTable = {
    "weapons/arccw/casings/casing_556_1.wav",
    "weapons/arccw/casings/casing_556_2.wav",
    "weapons/arccw/casings/casing_556_3.wav",
    "weapons/arccw/casings/casing_556_4.wav"
}

ArcCW.MediumShellSoundsTable = {
    "weapons/arccw/casings/casing_308_1.wav",
    "weapons/arccw/casings/casing_308_2.wav",
    "weapons/arccw/casings/casing_308_3.wav",
    "weapons/arccw/casings/casing_308_4.wav"
}

ArcCW.PistolShellSoundsTable = {
    "weapons/arccw/casings/casing_9mm_1.wav",
    "weapons/arccw/casings/casing_9mm_2.wav",
    "weapons/arccw/casings/casing_9mm_3.wav",
    "weapons/arccw/casings/casing_9mm_4.wav"
}

ArcCW.TinyShellSoundsTable = {
    "weapons/arccw/casings/casing_22_1.wav",
    "weapons/arccw/casings/casing_22_2.wav",
    "weapons/arccw/casings/casing_22_3.wav",
    "weapons/arccw/casings/casing_22_4.wav"
}

ArcCW.ShotgunShellSoundsTable = {
    "weapons/arccw/casings/casing_12ga_1.wav",
    "weapons/arccw/casings/casing_12ga_2.wav",
    "weapons/arccw/casings/casing_12ga_3.wav",
    "weapons/arccw/casings/casing_12ga_4.wav"
}

ArcCW.RicochetSounds = {
    "weapons/arccw/ricochet01.wav",
    "weapons/arccw/ricochet02.wav",
    "weapons/arccw/ricochet03.wav",
    "weapons/arccw/ricochet04.wav",
    "weapons/arccw/ricochet05.wav"
 }

ArcCW.ReloadTimeTable = {
    [ACT_HL2MP_GESTURE_RELOAD_AR2]      = 2,
    [ACT_HL2MP_GESTURE_RELOAD_SMG1]     = 2,
    [ACT_HL2MP_GESTURE_RELOAD_PISTOL]   = 1.5,
    [ACT_HL2MP_GESTURE_RELOAD_REVOLVER] = 2.5,
    [ACT_HL2MP_GESTURE_RELOAD_SHOTGUN]  = 2.5,
    [ACT_HL2MP_GESTURE_RELOAD_DUEL]     = 3.25,
}

ArcCW.LimbCompensation = {
    [1] = {
        [HITGROUP_HEAD]     = 1 / 2,
        [HITGROUP_LEFTARM]  = 1 / 0.25,
        [HITGROUP_RIGHTARM] = 1 / 0.25,
        [HITGROUP_LEFTLEG]  = 1 / 0.25,
        [HITGROUP_RIGHTLEG] = 1 / 0.25,
        [HITGROUP_GEAR]     = 1 / 0.25,
    },
    ["terrortown"] = {
        [HITGROUP_HEAD]     = 1 / 2.5, -- ArcCW's sh_ttt.lua line 5!!!
        [HITGROUP_LEFTARM]  = 1 / 0.55,
        [HITGROUP_RIGHTARM] = 1 / 0.55,
        [HITGROUP_LEFTLEG]  = 1 / 0.55,
        [HITGROUP_RIGHTLEG] = 1 / 0.55,
        [HITGROUP_GEAR]     = 1 / 0.55,
    },
}

ArcCW.ReplaceWeapons = {
    ["weapon_pistol"]    = true,
    ["weapon_smg1"]      = true,
    ["weapon_ar2"]       = true,
    ["weapon_shotgun"]   = true,
    ["weapon_357"]       = true,
    ["weapon_alyxgun"]   = true,
    ["weapon_crossbow"]  = true,
    ["weapon_rpg"]       = true,
    ["weapon_annabelle"] = true,
}

ArcCW.MeleeDamageTypes = {
    [DMG_GENERIC] = "dmg.generic",
    [DMG_BULLET] = "dmg.bullet",
    [DMG_SLASH] = "dmg.slash",
    [DMG_CLUB] = "dmg.club",
    [DMG_SHOCK] = "dmg.shock",
}

ArcCW.PenTable = {
   [MAT_ANTLION]     = 1,
   [MAT_BLOODYFLESH] = 1,
   [MAT_CONCRETE]    = 0.75,
   [MAT_DIRT]        = 0.5,
   [MAT_EGGSHELL]    = 1,
   [MAT_FLESH]       = 0.1,
   [MAT_GRATE]       = 1,
   [MAT_ALIENFLESH]  = 0.25,
   [MAT_CLIP]        = 1000,
   [MAT_SNOW]        = 0.25,
   [MAT_PLASTIC]     = 0.5,
   [MAT_METAL]       = 1.5,
   [MAT_SAND]        = 0.25,
   [MAT_FOLIAGE]     = 0.5,
   [MAT_COMPUTER]    = 0.25,
   [MAT_SLOSH]       = 1,
   [MAT_TILE]        = 0.5,
   [MAT_GRASS]       = 0.5,
   [MAT_VENT]        = 0.75,
   [MAT_WOOD]        = 0.5,
   [MAT_DEFAULT]     = 0.75,
   [MAT_GLASS]       = 0.025,
   [MAT_WARPSHIELD]  = 1
}

ArcCW.Colors = {
    POS     = Color(25, 225, 25),
    MINIPOS = Color(75, 225, 75),
    NEU     = Color(225, 225, 225),
    MININEG = Color(225, 75, 75),
    NEG     = Color(225, 25, 25),
    COSM    = Color(100, 100, 225)
}

ArcCW.LHIKBones = {
    "ValveBiped.Bip01_L_UpperArm",
    "ValveBiped.Bip01_L_Forearm",
    "ValveBiped.Bip01_L_Wrist",
    "ValveBiped.Bip01_L_Ulna",
    "ValveBiped.Bip01_L_Hand",
    "ValveBiped.Bip01_L_Finger4",
    "ValveBiped.Bip01_L_Finger41",
    "ValveBiped.Bip01_L_Finger42",
    "ValveBiped.Bip01_L_Finger3",
    "ValveBiped.Bip01_L_Finger31",
    "ValveBiped.Bip01_L_Finger32",
    "ValveBiped.Bip01_L_Finger2",
    "ValveBiped.Bip01_L_Finger21",
    "ValveBiped.Bip01_L_Finger22",
    "ValveBiped.Bip01_L_Finger1",
    "ValveBiped.Bip01_L_Finger11",
    "ValveBiped.Bip01_L_Finger12",
    "ValveBiped.Bip01_L_Finger0",
    "ValveBiped.Bip01_L_Finger01",
    "ValveBiped.Bip01_L_Finger02"
}

local clientColor = Color(255, 251, 0)
local serverColor = Color(0, 183, 255)
local errorColor = Color(255, 0, 0)

function ArcCW.Print(text, isError)
    local prefixColor = SERVER and serverColor or clientColor
    local textColor = isError and errorColor or color_white
    text = !isError and text or "ERROR! " .. text

    MsgC(prefixColor, "[ArcCW] ", textColor, text, "\n")
end