--[[
    Please, for the love of god, don't create objects in functions that are called multiple times per frame.
    The garbage collector will explode and so will players' comptuters.

    That means minimize usage of things that generate new objects, including:
        calls to Vector() or Angle(); use vector_origin and angle_zero if the value isn't modified
        arithmetic using +, -, * and / on Vectors and Angles; modifying individual parameters is fine
        functions like Angle:Right() and Vector:Angle(); however functions like Vector:Add() and Angle:Add() are fine

    Cache them if you use them more than one time!
]]

local mth = math
local m_appor = mth.Approach
local m_clamp = mth.Clamp
local f_lerp = Lerp
local srf = surface
local issingleplayer = game.SinglePlayer()
SWEP.ActualVMData = false
local swayxmult, swayymult, swayzmult, swayspeed = 1, 1, 1, 1
local lookxmult, lookymult = 1, 1
SWEP.VMPos = Vector()
SWEP.VMAng = Angle()
SWEP.VMPosOffset = Vector()
SWEP.VMAngOffset = Angle()
SWEP.VMPosOffset_Lerp = Vector()
SWEP.VMAngOffset_Lerp = Angle()
SWEP.VMLookLerp = Angle()
SWEP.StepBob = 0
SWEP.StepBobLerp = 0
SWEP.StepRandomX = 1
SWEP.StepRandomY = 1
SWEP.LastEyeAng = Angle()
SWEP.SmoothEyeAng = Angle()
SWEP.LastVelocity = Vector()
SWEP.Velocity_Lerp = Vector()
SWEP.VelocityLastDiff = 0
SWEP.Breath_Intensity = 1
SWEP.Breath_Rate = 1

-- magic variables
local sprint_vec1 = Vector(-2, 5, 2)
local sprint_vec2 = Vector(0, 7, 3)
local sprint_ang1 = Angle(-15, -15, 0)
local spring_ang2 = Angle(-15, 15, -22)
local sight_vec1 = Vector(0, 15, -4)
local sight_vec2 = Vector(1, 5, -1)
local sight_ang1 = Angle(0, 0, -45)
local sight_ang2 = Angle(-5, 0, -10)
local sextra_vec = Vector(0.0002, 0.001, 0.005)

local procdraw_vec = Vector(0, 0, -5)
local procdraw_ang = Angle(-70, 30, 0)
local prochol_ang = Angle(-70, 30, 10)

local lst = SysTime()
local timescalecvar = GetConVar("host_timescale")
local function scrunkly()
    local ret = (SysTime() - (lst or SysTime())) * timescalecvar:GetFloat()
    return ret
end

local function LerpC(t, a, b, powa)
    return a + (b - a) * math.pow(t, powa)
end

local function ApproachMod(usrobj, to, dlt)
    usrobj[1] = m_appor(usrobj[1], to[1], dlt)
    usrobj[2] = m_appor(usrobj[2], to[2], dlt)
    usrobj[3] = m_appor(usrobj[3], to[3], dlt)
end

local function LerpMod(usrobj, to, dlt, clamp_ang)
    usrobj[1] = f_lerp(dlt, usrobj[1], to[1])
    usrobj[2] = f_lerp(dlt, usrobj[2], to[2])
    usrobj[3] = f_lerp(dlt, usrobj[3], to[3])
    if clamp_ang then
        for i = 1, 3 do usrobj[i] = math.NormalizeAngle(usrobj[i]) end
    end
end

local function LerpMod2(from, usrobj, dlt, clamp_ang)
    usrobj[1] = f_lerp(dlt, from[1], usrobj[1])
    usrobj[2] = f_lerp(dlt, from[2], usrobj[2])
    usrobj[3] = f_lerp(dlt, from[3], usrobj[3])
    if clamp_ang then
        for i = 1, 3 do usrobj[i] = math.NormalizeAngle(usrobj[i]) end
    end
end

-- debug for testing garbage count
--[[
local sw = false
local tries = {}
local totaltries = 1000
local sw_start = 0
local sw_orig = 0
concommand.Add("arccw_dev_stopwatch", function() tries = {} sw = true end)

local function stopwatch(name)
    if !sw then return end
    if name == true then
        local d = (collectgarbage("count") - sw_orig)
        if #tries == 0 then print("    total garbage: " .. d) end
        table.insert(tries, d)
        if #tries == totaltries then
            sw = false
            local average = 0
            for _, v in ipairs(tries) do average = average + v end
            average = average / totaltries
            print("----------------------------------")
            print("average over " .. totaltries .. " tries: " .. average)
        end
        return
    end
    local gb = collectgarbage("count")
    if name then
        if #tries == 0 then print(name .. ": " .. (gb - sw_start)) end
    else
        if #tries == 0 then print("----------------------------------") end
        sw_orig = gb
    end
    sw_start = gb
end
]]
function SWEP:Move_Process(EyePos, EyeAng, velocity, stable)
    stable = stable or self:GetTable()
    local VMPos, VMAng = stable.VMPos, stable.VMAng
    local VMPosOffset, VMAngOffset = stable.VMPosOffset, stable.VMAngOffset
    local VMPosOffset_Lerp, VMAngOffset_Lerp = stable.VMPosOffset_Lerp, stable.VMAngOffset_Lerp
    local FT = scrunkly()
    local sightedmult = (self:GetState(stable) == ArcCW.STATE_SIGHTS and 0.05) or 1
    local sg = self:GetSightDelta()
    VMPos:Set(EyePos)
    VMAng:Set(EyeAng)
    VMPosOffset.x = math.Clamp(velocity.z * 0.0025, -1, 1) * sightedmult
    VMPosOffset.x = VMPosOffset.x + (velocity.x * 0.001 * sg)
    VMPosOffset.y = math.Clamp(velocity.y * -0.002, -1, 1) * sightedmult
    VMPosOffset.z = math.Clamp(VMPosOffset.x * -2, -4, 4)
    VMPosOffset_Lerp.x = Lerp(8 * FT, VMPosOffset_Lerp.x, VMPosOffset.x)
    VMPosOffset_Lerp.y = Lerp(8 * FT, VMPosOffset_Lerp.y, VMPosOffset.y)
    VMPosOffset_Lerp.z = Lerp(8 * FT, VMPosOffset_Lerp.z, VMPosOffset.z)
    --VMAngOffset.x = math.Clamp(VMPosOffset.x * 8, -4, 4)
    VMAngOffset.y = VMPosOffset.y
    VMAngOffset.z = VMPosOffset.y * 0.5 + (VMPosOffset.x * -5) + (velocity.x * -0.005 * sg)
    VMAngOffset_Lerp.x = LerpC(10 * FT, VMAngOffset_Lerp.x, VMAngOffset.x, 0.75)
    VMAngOffset_Lerp.y = LerpC(5 * FT, VMAngOffset_Lerp.y, VMAngOffset.y, 0.6)
    VMAngOffset_Lerp.z = Lerp(25 * FT, VMAngOffset_Lerp.z, VMAngOffset.z)
    VMPos:Add(VMAng:Up() * VMPosOffset_Lerp.x)
    VMPos:Add(VMAng:Right() * VMPosOffset_Lerp.y)
    VMPos:Add(VMAng:Forward() * VMPosOffset_Lerp.z)
    VMAngOffset_Lerp:Normalize()
    VMAng:Add(VMAngOffset_Lerp)
end

local stepend = math.pi * 4

function SWEP:Step_Process(_, _, velocity, stable)
    stable = stable or self:GetTable()
    local VMPos, VMAng = stable.VMPos, stable.VMAng
    local VMPosOffset, VMAngOffset = stable.VMPosOffset, stable.VMAngOffset
    local VMPosOffset_Lerp = stable.VMPosOffset_Lerp
    local state = self:GetState(stable)
    local sprd = self:GetSprintDelta()

    if state == ArcCW.STATE_SPRINT and self:SelectAnimation("idle_sprint") and !self:GetReloading() and !self:CanShootWhileSprint() then
        velocity = 0
    else
        velocity = math.min(velocity:Length(), 400) * Lerp(sprd, 1, 1.25)
    end

    local delta = math.abs(stable.StepBob * 2 / stepend - 1)
    local FT = scrunkly() --FrameTime()
    local sightedmult = (state == ArcCW.STATE_SIGHTS and 0.25) or 1
    local sprintmult = (state == ArcCW.STATE_SPRINT and !self:CanShootWhileSprint() and 2) or 1
    local pronemult = (self:IsProne() and 10) or 1
    local onground = self:GetOwner():OnGround()
    stable.StepBob = stable.StepBob + (velocity * 0.00015 + (math.pow(delta, 0.01) * 0.03)) * swayspeed * FT * 300

    if stable.StepBob >= stepend then
        stable.StepBob = 0
        stable.StepRandomX = math.Rand(1, 1.5)
        stable.StepRandomY = math.Rand(1, 1.5)
    end

    if velocity == 0 then
        stable.StepBob = 0
    end

    if onground then
        -- oh no it says sex tra
        local sextra = vector_origin
        if (state == ArcCW.STATE_SPRINT and !self:CanShootWhileSprint() and !self:SelectAnimation("idle_sprint", stable)) or true then
            sextra = LerpVector(sprd, vector_origin, sextra_vec)
        end

        VMPosOffset.x = (math.sin(stable.StepBob) * velocity * (0.000375 + sextra.x) * sightedmult * swayxmult) * stable.StepRandomX
        VMPosOffset.y = (math.sin(stable.StepBob * 0.5) * velocity * (0.0005 + sextra.y) * sightedmult * sprintmult * pronemult * swayymult) * stable.StepRandomY
        VMPosOffset.z = math.sin(stable.StepBob * 0.75) * velocity * (0.002 + sextra.z) * sightedmult * pronemult * swayzmult
    end

    VMPosOffset_Lerp.x = Lerp(32 * FT, VMPosOffset_Lerp.x, VMPosOffset.x)
    VMPosOffset_Lerp.y = Lerp(4 * FT, VMPosOffset_Lerp.y, VMPosOffset.y)
    VMPosOffset_Lerp.z = Lerp(2 * FT, VMPosOffset_Lerp.z, VMPosOffset.z)
    VMAngOffset.x = VMPosOffset_Lerp.x * 2
    VMAngOffset.y = VMPosOffset_Lerp.y * -7.5
    VMAngOffset.z = VMPosOffset_Lerp.y * 10
    VMPos:Add(VMAng:Up() * VMPosOffset_Lerp.x)
    VMPos:Add(VMAng:Right() * VMPosOffset_Lerp.y)
    VMPos:Add(VMAng:Forward() * VMPosOffset_Lerp.z)
    VMAng:Add(VMAngOffset)
end

function SWEP:Breath_Health()
    local owner = self:GetOwner()
    if !IsValid(owner) then return end
    local health = owner:Health()
    local maxhealth = owner:GetMaxHealth()
    self.Breath_Intensity = math.Clamp(maxhealth / health, 0, 2)
    self.Breath_Rate = math.Clamp((maxhealth * 0.5) / health, 1, 1.5)
end

function SWEP:Breath_StateMult()
    local owner = self:GetOwner()
    if !IsValid(owner) then return end
    local sightedmult = (self:GetState() == ArcCW.STATE_SIGHTS and 0.05) or 1
    self.Breath_Intensity = self.Breath_Intensity * sightedmult
end

function SWEP:Breath_Process(_, _, stable)
    stable = stable or self:GetTable()
    local VMPos, VMAng = stable.VMPos, stable.VMAng
    local VMPosOffset, VMAngOffset = stable.VMPosOffset, stable.VMAngOffset
    -- self:Breath_Health() Snaps around when regenerating
    self:Breath_StateMult()

    local curtime = CurTime()
    local breathrate = stable.Breath_Rate
    local breathintensity = stable.Breath_Intensity

    VMPosOffset.x = (math.sin(curtime * 2 * breathrate) * 0.1) * breathintensity
    VMPosOffset.y = (math.sin(curtime * 2.5 * breathrate) * 0.025) * breathintensity
    VMAngOffset.x = VMPosOffset.x * 1.5
    VMAngOffset.y = VMPosOffset.y * 2
    VMAngOffset.z = VMPosOffset.y * VMPosOffset.x * -40
    VMPos:Add(VMAng:Up() * VMPosOffset.x)
    VMPos:Add(VMAng:Right() * VMPosOffset.y)
    VMAng:Add(VMAngOffset)
end

function SWEP:Look_Process(_, EyeAng, _, stable)
    stable = stable or self:GetTable()
    local VMPos, VMAng = stable.VMPos, stable.VMAng
    local VMPosOffset, VMAngOffset = stable.VMPosOffset, stable.VMAngOffset
    local FT = scrunkly()
    local sightedmult = (self:GetState(stable) == ArcCW.STATE_SIGHTS and 0.25) or 1
    stable.SmoothEyeAng = LerpAngle(0.05, stable.SmoothEyeAng, EyeAng - stable.LastEyeAng)
    -- local xd, yd = (velocity.z / 10), (velocity.y / 200)
    VMPosOffset.x = -stable.SmoothEyeAng.x * -0.5 * sightedmult * lookxmult
    VMPosOffset.y = stable.SmoothEyeAng.y * 0.5 * sightedmult * lookymult
    VMAngOffset.x = VMPosOffset.x * 0.75
    VMAngOffset.y = VMPosOffset.y * 2.5
    VMAngOffset.z = VMPosOffset.x * 2 + VMPosOffset.y * -2
    stable.VMLookLerp.y = Lerp(FT * 10, stable.VMLookLerp.y, VMAngOffset.y * -1.5 + stable.SmoothEyeAng.y)
    VMAng.y = VMAng.y - stable.VMLookLerp.y
    VMPos:Add(VMAng:Up() * VMPosOffset.x)
    VMPos:Add(VMAng:Right() * VMPosOffset.y)
    VMAng:Add(VMAngOffset)
end

function SWEP:GetVMPosition(EyePos, EyeAng, stable)
    stable = stable or self:GetTable()
    local velocity = self:GetOwner():GetVelocity()
    velocity = WorldToLocal(velocity, angle_zero, vector_origin, EyeAng)

    self:Move_Process(EyePos, EyeAng, velocity, stable)
    -- stopwatch("Move_Process")
    self:Step_Process(EyePos, EyeAng, velocity, stable)
    -- stopwatch("Step_Process")
    self:Breath_Process(EyePos, EyeAng, stable)
    -- stopwatch("Breath_Process")
    self:Look_Process(EyePos, EyeAng, velocity, stable)
    -- stopwatch("Look_Process")
    stable.LastEyeAng = EyeAng
    stable.LastEyePos = EyePos
    stable.LastVelocity = velocity

    return stable.VMPos, stable.VMAng
end

SWEP.TheJ = {posa = Vector(), anga = Angle()}
local rap_pos = Vector()
local rap_ang = Angle()

local actual
local target = {pos = Vector(), ang = Angle()}

local GunDriverFix = Angle( 0, 90, 90 )

function SWEP:GetViewModelPosition(pos, ang)
    if ArcCW.ConVars["dev_benchgun"]:GetBool() then
        local bgc = ArcCW.ConVars["dev_benchgun_custom"]:GetString()
        if bgc then
            if string.Left(bgc, 6) != "setpos" then return vector_origin, angle_zero end

            bgc = string.TrimLeft(bgc, "setpos ")
            bgc = string.Replace(bgc, ";setang", "")
            bgc = string.Explode(" ", bgc)

            return Vector(bgc[1], bgc[2], bgc[3]), Angle(bgc[4], bgc[5], bgc[6])
        else
            return vector_origin, angle_zero
        end
    end

    -- stopwatch()

    local owner = self:GetOwner()
    if !IsValid(owner) or !owner:Alive() then return end
    local FT = scrunkly()
    local CT = CurTime()
    local TargetTick = (1 / FT) / 66.66
    local viewoffset = owner:GetViewOffset()
    local cdelta = math.Clamp(math.ease.InOutSine((viewoffset.z - owner:GetCurrentViewOffset().z) / (viewoffset.z - owner:GetViewOffsetDucked().z)),0,1)

    if TargetTick < 1 then
        FT = FT * TargetTick
    end

    local stable = self:GetTable()
    local asight = self:GetActiveSights(stable)
    local state = self:GetState(stable)
    local sgtd = self:GetSightDelta()
    local sprd = self:GetSprintDelta()

    local sprinted = stable.Sprinted or state == ArcCW.STATE_SPRINT and !self:CanShootWhileSprint()
    local sighted = stable.Sighted or state == ArcCW.STATE_SIGHTS
    local holstered = self:GetCurrentFiremode(stable).Mode == 0

    if issingleplayer then
        sprinted = state == ArcCW.STATE_SPRINT and !self:CanShootWhileSprint()
        sighted = state == ArcCW.STATE_SIGHTS
    end

    local oldpos, oldang = Vector(), Angle()
    local vpang = self:GetOurViewPunchAngles(stable)
    oldpos:Set(pos)
    oldang:Set(ang)
    ang:Sub(vpang)

    actual = stable.ActualVMData or {
        pos = Vector(),
        ang = Angle(),
        down = 1,
        sway = 1,
        bob = 1,
        evpos = Vector(),
        evang = Angle(),
    }

    local apos, aang = self:GetBuff_Override("Override_ActivePos", stable.ActivePos, stable), self:GetBuff_Override("Override_ActiveAng", stable.ActiveAng, stable)
    target.down = 1
    target.sway = 2
    target.bob = 2

    -- stopwatch("set")

    local isreloading = self:GetReloading()

    if self:InBipod() and self:GetBipodAngle() then
        local bpos = self:GetBuff_Override("Override_InBipodPos", stable.InBipodPos, stable)
        target.pos:Set(asight and asight.Pos or apos)
        target.ang:Set(asight and asight.Ang or aang)

        local BEA = (stable.BipodStartAngle or self:GetBipodAngle()) - owner:EyeAngles()
        target.pos:Add(BEA:Right() * bpos.x * stable.InBipodMult.x)
        target.pos:Add(BEA:Forward() * bpos.y * stable.InBipodMult.y)
        target.pos:Add(BEA:Up() * bpos.z * stable.InBipodMult.z)
        target.sway = 0.2
    -- elseif (owner:Crouching() or owner:KeyDown(IN_DUCK)) and !self:GetReloading() then
        -- target.pos:Set(self:GetBuff("CrouchPos", true) or apos)
        -- target.ang:Set(self:GetBuff("CrouchAng", true) or aang)
    elseif isreloading then
        target.pos:Set(self:GetBuff("ReloadPos", true, _, stable) or apos)
        target.ang:Set(self:GetBuff("ReloadAng", true, _, stable) or aang)
    else
        local cpos, cang = self:GetBuff("CrouchPos", true, _, stable) or apos, self:GetBuff("CrouchAng", true, _, stable) or aang
        target.pos:Set(apos)
        target.ang:Set(aang)
        LerpMod(target.pos, cpos, cdelta)
        LerpMod(target.ang, cang, cdelta, true)
    end
    if (owner:Crouching() or owner:KeyDown(IN_DUCK)) then target.down = 0 end

    -- stopwatch("reload, crouch, bipod")

    target.pos.x = target.pos.x + ArcCW.ConVars["vm_right"]:GetFloat()
    target.pos.y = target.pos.y + ArcCW.ConVars["vm_forward"]:GetFloat()
    target.pos.z = target.pos.z + ArcCW.ConVars["vm_up"]:GetFloat()

    target.ang.p = target.ang.p + ArcCW.ConVars["vm_pitch"]:GetFloat()
    target.ang.y = target.ang.y + ArcCW.ConVars["vm_yaw"]:GetFloat()
    target.ang.r = target.ang.r + ArcCW.ConVars["vm_roll"]:GetFloat()

    if state == ArcCW.STATE_CUSTOMIZE then
        target.down = 1
        target.sway = 3
        target.bob = 1
        local mx, my = input.GetCursorPos()
        mx = 2 * mx / ScrW()
        my = 2 * my / ScrH()
        target.pos:Set(self:GetBuff_Override("Override_CustomizePos", stable.CustomizePos, stable))
        target.ang:Set(self:GetBuff_Override("Override_CustomizeAng", stable.CustomizeAng, stable))
        target.pos.x = target.pos.x + mx
        target.pos.z = target.pos.z + my
        target.ang.y = target.ang.y + my * 2
        target.ang.r = target.ang.r + mx * 2
        if self.InAttMenu then
            target.ang.y = target.ang.y - 5
        end
    end

    -- stopwatch("cust")

    -- Sprinting
    local hpos, spos = self:GetBuff("HolsterPos", true, _, stable), self:GetBuff("SprintPos", true, _, stable)
    local hang, sang = self:GetBuff("HolsterAng", true, _, stable), self:GetBuff("SprintAng", true, _, stable)
    do
        local aaaapos = holstered and (hpos or spos) or (spos or hpos)
        local aaaaang = holstered and (hang or sang) or (sang or hang)

        local sd = (isreloading and 0) or (self:IsProne() and math.Clamp(owner:GetVelocity():Length() / prone.Config.MoveSpeed, 0, 1)) or (holstered and 1) or (!self:CanShootWhileSprint() and sprd) or 0
        sd = math.pow(math.sin(sd * math.pi * 0.5), 2)

        local d = math.pow(math.sin(sd * math.pi * 0.5), math.pi)
        local coolilove = d * math.cos(d * math.pi * 0.5)

        local joffset, jaffset
        if !sprinted then
            joffset = sprint_vec2
            jaffset = spring_ang2
        else
            joffset = sprint_vec1
            jaffset = sprint_ang1
        end

        LerpMod(target.pos, aaaapos, sd)
        LerpMod(target.ang, aaaaang, sd, true)
        for i = 1, 3 do
            target.pos[i] = target.pos[i] + joffset[i] * coolilove
            target.ang[i] = target.ang[i] + jaffset[i] * coolilove
        end

        local fu_sprint = (sprinted and self:SelectAnimation("idle_sprint", stable))

        target.sway = target.sway * f_lerp(sd, 1, fu_sprint and 0 or 2)
        target.bob = target.bob * f_lerp(sd, 1, fu_sprint and 0 or 2)
    end

    -- stopwatch("sprint")

    -- Sighting
    if asight then
        local delta = sgtd
        delta = math.pow(math.sin(delta * math.pi * 0.5), math.pi)
        local im = asight.Midpoint
        local coolilove = delta * math.cos(delta * math.pi * 0.5)

        local joffset, jaffset
        if !sighted then
            joffset = sight_vec2
            jaffset = sight_ang2
        else
            joffset = (im and im.Pos or sight_vec1)
            jaffset = (im and im.Ang or sight_ang1)
        end

        target.pos.z = target.pos.z - 1
        LerpMod2(asight.Pos, target.pos, delta)
        LerpMod2(asight.Ang, target.ang, delta)
        for i = 1, 3 do
            target.pos[i] = target.pos[i] + joffset[i] * coolilove
            target.ang[i] = target.ang[i] + jaffset[i] * coolilove
        end

        target.evpos = f_lerp(delta, asight.EVPos or vector_origin, vector_origin)
        target.evang = f_lerp(delta, asight.EVAng or angle_zero, angle_zero)

        target.down = 0
        target.sway = target.sway * f_lerp(delta, 0.1, 1)
        target.bob = target.bob * f_lerp(delta, 0.1, 1)
    end

    -- stopwatch("sight")

    local deg = self:GetBarrelNearWall()
    if deg > 0 and ArcCW.ConVars["vm_nearwall"]:GetBool() then
        LerpMod(target.pos, hpos, deg)
        LerpMod(target.ang, hang, deg)
        target.down = 2 * math.max(sgtd, 0.5)
    end

    if !isangle(target.ang) then
        target.ang = Angle(target.ang)
    end

    local freeaimoffset = self:GetFreeAimOffset()
    target.ang.y = target.ang.y + (freeaimoffset.y * 0.5)
    target.ang.p = target.ang.p - (freeaimoffset.p * 0.5)

    if stable.InProcDraw then
        stable.InProcHolster = false
        local delta = m_clamp((CT - stable.ProcDrawTime) / (0.5 * self:GetBuff_Mult("Mult_DrawTime", stable)), 0, 1)
        target.pos = LerpVector(delta, procdraw_vec, target.pos)
        target.ang = LerpAngle(delta, procdraw_ang, target.ang)
        target.down = target.down
        target.sway = target.sway
        target.bob = target.bob
    end

    if stable.InProcHolster then
        stable.InProcDraw = false
        local delta = 1 - m_clamp((CT - stable.ProcHolsterTime) / (0.25 * self:GetBuff_Mult("Mult_DrawTime", stable)), 0, 1)
        target.pos = LerpVector(delta, procdraw_vec, target.pos)
        target.ang = LerpAngle(delta, prochol_ang, target.ang)
        target.down = target.down
        target.sway = target.sway
        target.bob = target.bob
    end

    if stable.InProcBash then
        stable.InProcDraw = false
        local mult = self:GetBuff_Mult("Mult_MeleeTime", stable)
        local mtime = stable.MeleeTime * mult
        local delta = 1 - m_clamp((CT - stable.ProcBashTime) / mtime, 0, 1)

        local bp, ba

        if delta > 0.3 then
            bp = self:GetBuff_Override("Override_BashPreparePos", stable.BashPreparePos, stable)
            ba = self:GetBuff_Override("Override_BashPrepareAng", stable.BashPrepareAng, stable)
            delta = (delta - 0.5) * 2
        else
            bp = self:GetBuff_Override("Override_BashPos", stable.BashPos, stable)
            ba = self:GetBuff_Override("Override_BashAng", stable.BashAng, stable)
            delta = delta * 2
        end

        LerpMod2(bp, target.pos, delta)
        LerpMod2(ba, target.ang, delta)

        target.speed = 10

        if delta == 0 then
            stable.InProcBash = false
        end
    end

    -- stopwatch("proc")

    -- local gunbone, gbslot = self:GetBuff_Override("LHIK_GunDriver")
    -- if gunbone and IsValid(self.Attachments[gbslot].VElement.Model) and self.LHIKGunPos and self.LHIKGunAng then
    --     local magnitude = 1 --Lerp(sgtd, 0.1, 1)
    --     local lhik_model = self.Attachments[gbslot].VElement.Model
    --     local att = lhik_model:GetAttachment(lhik_model:LookupAttachment(gunbone))
    --     local attang = att.Ang
    --     local attpos = att.Pos
    --     attang = lhik_model:WorldToLocalAngles(attang)
    --     attpos = lhik_model:WorldToLocal(attpos)
    --     attang:Sub(self.LHIKGunAng)
    --     attpos:Sub(self.LHIKGunPos)
    --     attang:Mul(magnitude)
    --     attpos:Mul(magnitude)
    --     --target.ang:Add(attang)
    --     --target.pos:Add(attpos)
    --     --debugoverlay.Axis(lhik_model:GetPos() + attpos, att.Ang, 8, FrameTime() * 3, true)
    --     debugoverlay.Axis(lhik_model:GetPos(), att.Ang, 8, FrameTime() * 3, true)
    -- end

    -- stopwatch("gunbone")

    local vmhit = stable.ViewModel_Hit
    if vmhit then
        if !vmhit:IsZero() then
            target.pos.x = target.pos.x + m_clamp(vmhit.y, -1, 1) * 0.25
            target.pos.y = target.pos.y + vmhit.y
            target.pos.z = target.pos.z + m_clamp(vmhit.x, -1, 1) * 1
            target.ang.x = target.ang.x + m_clamp(vmhit.x, -1, 1) * 5
            target.ang.y = target.ang.y + m_clamp(vmhit.y, -1, 1) * -2
            target.ang.z = target.ang.z + m_clamp(vmhit.z, -1, 1) * 12.5
        end

        local spd = vmhit:Length() * 5
        vmhit.x = m_appor(vmhit.x, 0, FT * spd)
        vmhit.y = m_appor(vmhit.y, 0, FT * spd)
        vmhit.z = m_appor(vmhit.z, 0, FT * spd)
    end

    if ArcCW.ConVars["shakevm"]:GetBool() and !engine.IsRecordingDemo() then
        target.pos:Add(VectorRand() * stable.RecoilAmount * 0.2 * stable.RecoilVMShake)
    end

    -- stopwatch("vmhit")

    local speed = 15 * FT * (issingleplayer and 1 or 2)

    LerpMod(actual.pos, target.pos, speed)
    LerpMod(actual.ang, target.ang, speed, true)
    LerpMod(actual.evpos, target.evpos or vector_origin, speed)
    LerpMod(actual.evang, target.evang or angle_zero, speed, true)
    actual.down = f_lerp(speed, actual.down, target.down)
    actual.sway = f_lerp(speed, actual.sway, target.sway)
    actual.bob = f_lerp(speed, actual.bob, target.bob)

    ApproachMod(actual.pos, target.pos, speed * 0.1)
    ApproachMod(actual.ang, target.ang, speed * 0.1)
    actual.down = m_appor(actual.down, target.down, speed * 0.1)

    -- stopwatch("actual -> target")

    local coolsway = ArcCW.ConVars["vm_coolsway"]:GetBool()
    stable.SwayScale = (coolsway and 0) or actual.sway
    stable.BobScale = (coolsway and 0) or actual.bob

    if coolsway then
        swayxmult = ArcCW.ConVars["vm_sway_zmult"]:GetFloat() or 1
        swayymult = ArcCW.ConVars["vm_sway_xmult"]:GetFloat() or 1
        swayzmult = ArcCW.ConVars["vm_sway_ymult"]:GetFloat() or 1
        swayspeed = ArcCW.ConVars["vm_sway_speedmult"]:GetFloat() or 1
        lookxmult = ArcCW.ConVars["vm_look_xmult"]:GetFloat() or 1
        lookymult = ArcCW.ConVars["vm_look_ymult"]:GetFloat() or 1

        local sd = self:GetSightDelta()
        lookxmult = Lerp(sd, 0, lookxmult)
        lookymult = Lerp(sd, 0, lookymult)
        swayxmult = Lerp(sd, 0, swayxmult)
        swayymult = Lerp(sd, 0, swayymult)
        swayzmult = Lerp(sd, 0, swayzmult)
        swayspeed = Lerp(sd, 0, swayspeed)

        -- stopwatch("before vmposition")
        local npos, nang = self:GetVMPosition(oldpos, oldang, stable)
        pos:Set(npos)
        ang:Set(nang)
    end

    local old_r, old_f, old_u = oldang:Right(), oldang:Forward(), oldang:Up()
    pos:Add(math.min(stable.RecoilPunchBack, Lerp(sgtd, stable.RecoilPunchBackMaxSights or 1, stable.RecoilPunchBackMax)) * -old_f)

    ang:RotateAroundAxis(old_r, actual.ang.x)
    ang:RotateAroundAxis(old_u, actual.ang.y)
    ang:RotateAroundAxis(old_f, actual.ang.z)
    ang:RotateAroundAxis(old_r, actual.evang.x)
    ang:RotateAroundAxis(old_u, actual.evang.y)
    ang:RotateAroundAxis(old_f, actual.evang.z)

    local new_r, new_f, new_u = ang:Right(), ang:Forward(), ang:Up()
    old_r:Mul(actual.evpos.x)
    old_f:Mul(actual.evpos.y)
    old_u:Mul(actual.evpos.z)
    pos:Add(old_r)
    pos:Add(old_f)
    pos:Add(old_u)
    new_r:Mul(actual.pos.x)
    new_f:Mul(actual.pos.y)
    new_u:Mul(actual.pos.z)
    pos:Add(new_r)
    pos:Add(new_f)
    pos:Add(new_u)

    pos.z = pos.z - actual.down

    ang:Add(vpang * Lerp(sgtd, 1, -1))

    local gunbone, gbslot = self:GetBuff_Override("LHIK_GunDriver", _, stable)
    local atts = stable.Attachments
    local lhik_model = gbslot and atts[gbslot].VElement and atts[gbslot].VElement.Model -- Visual M203 attachment
    local lhik_anim_model = gbslot and atts[gbslot].GodDriver and atts[gbslot].GodDriver.Model -- M203 anim and camera
    local lhik_refl_model = gbslot and atts[gbslot].ReflectDriver and atts[gbslot].ReflectDriver.Model -- Rifle
    if IsValid(lhik_model) and IsValid(lhik_anim_model) and IsValid(lhik_refl_model) and lhik_anim_model:GetAttachment(lhik_anim_model:LookupAttachment(gunbone)) then
        local att = lhik_anim_model:LookupAttachment(gunbone)
        local offset = lhik_anim_model:GetAttachment(att).Pos
        local affset = lhik_anim_model:GetAttachment(att).Ang

        affset:Sub( GunDriverFix )
        local r = affset.r
        affset.r = affset.p
        affset.p = -r
        affset.y = -affset.y

        local anchor = atts[gbslot].VMOffsetPos

        local looku = lhik_refl_model:LookupBone( atts[gbslot].Bone )
        local bonp, bona = lhik_refl_model:GetBonePosition( looku )
        if bonp == lhik_refl_model:GetPos() then
            bonp = lhik_refl_model:GetBoneMatrix( looku ):GetTranslation()
            bona = lhik_refl_model:GetBoneMatrix( looku ):GetAngles()
        end

        if anchor and bonp then -- Not ready / deploying
            anchor = ( bonp + ( (bona:Forward() * anchor.x) + (bona:Right() * anchor.y) + (bona:Up() * anchor.z) ) )

            debugoverlay.Axis(anchor, angle_zero, 4, FrameTime(), true)

            rap_pos, rap_ang = ArcCW.RotateAroundPoint2(pos, ang, anchor, offset, affset)
            rap_pos:Sub(pos)
            rap_ang:Sub(ang)

            pos:Add(rap_pos)
            ang:Add(rap_ang)
        end
    end

    stable.ActualVMData = actual

    -- stopwatch("apply actual")

    -- stopwatch(true)

    lst = SysTime()
    return pos, ang
end

function SWEP:ShouldCheapWorldModel()
    local lp = LocalPlayer()
    local owner = self:GetOwner()
    if lp:GetObserverMode() == OBS_MODE_IN_EYE and lp:GetObserverTarget() == owner then return true end
    if !IsValid(owner) and !ArcCW.ConVars["att_showground"]:GetBool() then return true end

    return !ArcCW.ConVars["att_showothers"]:GetBool()
end

local bird = Material("arccw/hud/arccw_bird.png", "mips smooth")
local iw = 32

function SWEP:DrawWorldModel()
    local cvar2d3d = ArcCW.ConVars["2d3d"]:GetInt()
    if !IsValid(self:GetOwner()) and !TTT2
            and (cvar2d3d == 2 or (cvar2d3d == 1 and LocalPlayer():GetEyeTrace().Entity == self))
            and (EyePos() - self:WorldSpaceCenter()):LengthSqr() <= 262144 then -- 512^2
        local ang = LocalPlayer():EyeAngles()
        ang:RotateAroundAxis(ang:Forward(), 180)
        ang:RotateAroundAxis(ang:Right(), 90)
        ang:RotateAroundAxis(ang:Up(), 90)
        cam.Start3D2D(self:WorldSpaceCenter() + Vector(0, 0, 16), ang, 0.1)

        srf.SetFont("ArcCW_32_Unscaled")
        local w = srf.GetTextSize(self.PrintName)
        srf.SetTextPos(-w / 2 + 2, 2)
        srf.SetTextColor(0, 0, 0, 150)
        srf.DrawText(self.PrintName)
        srf.SetTextPos(-w / 2, 0)
        srf.SetTextColor(255, 255, 255, 255)
        srf.DrawText(self.PrintName)

        local icons = {}
        for _, slot in pairs(self.Attachments or {}) do
            if slot.Installed then
                local atttbl = ArcCW.AttachmentTable[slot.Installed]
                if !atttbl then continue end
                local icon = atttbl.Icon
                if !icon or icon:IsError() then icon = bird end
                table.insert(icons, icon)
            end
        end

        local ind = math.min(6, #icons)

        surface.SetDrawColor(255, 255, 255)
        for i = 1, ind do
            if i == 6 and #icons > 6 then
                local str = "+" .. (#icons - ind)
                local strw = srf.GetTextSize(str)
                srf.SetTextPos(-ind * iw / 2 + (i - 1) * iw + 2 + strw / 2, iw + 14)
                srf.SetTextColor(0, 0, 0, 150)
                srf.DrawText(str)
                srf.SetTextPos(-ind * iw / 2 + (i - 1) * iw + strw / 2, iw + 12)
                srf.SetTextColor(255, 255, 255, 255)
                srf.DrawText(str)
            else
                local icon = icons[i]
                surface.SetMaterial(icon)
                surface.DrawTexturedRect(-ind * iw / 2 + (i - 1) * iw, iw + 12, iw, iw)
            end
        end

        -- srf.SetFont("ArcCW_24_Unscaled")
        -- local count = self:CountAttachments()

        -- if count > 0 then
        --     local t = tostring(count) .. " Attachments"
        --     w = srf.GetTextSize(t)
        --     srf.SetTextPos(-w / 2, 32)
        --     srf.SetTextColor(255, 255, 255, 255)
        --     srf.DrawText(t)
        -- end

        cam.End3D2D()
    end

    self:DrawCustomModel(true)
    self:DoLaser(true)

    if self:ShouldGlint() then
        self:DoScopeGlint()
    end

    if !self.CertainAboutAtts and !self.AttReqSent and !IsValid(self:GetOwner()) then
        self.AttReqSent = true
        -- print(self, "network weapon from cl_viewmodel")
        -- debugoverlay.Cross(self:GetPos(), 8, 10, color_white, true)
        -- debugoverlay.EntityTextAtPosition(self:GetPos(), 1, tostring(self) .. " requesting networking data", 10, color_white)
        net.Start("arccw_rqwpnnet")
            net.WriteEntity(self)
        net.SendToServer()
    end
end

function SWEP:ShouldCheapScope()
    if !ArcCW.ConVars["cheapscopes"]:GetBool() then return end
end

local POSTVMDONE = nil
local POSTVMDONE_TIME = 0

local lst2 = SysTime()
function SWEP:PreDrawViewModel(vm)
    if ArcCW.VM_OverDraw then return end
    if !vm then return end

    local stable = self:GetTable()

    if self:GetState(stable) == ArcCW.STATE_CUSTOMIZE then
        self:BlurNotWeapon()
    end

    if ArcCW.ConVars["cheapscopesautoconfig"]:GetBool() then
        local fps = 1 / (SysTime() - lst2)
        lst2 = SysTime()
        local lowfps = fps <= 45
        ArcCW.ConVars["cheapscopes"]:SetBool(lowfps)
        ArcCW.ConVars["cheapscopesautoconfig"]:SetBool(false)
    end

    local asight = self:GetActiveSights(stable)

    if asight and ((ArcCW.ConVars["cheapscopes"]:GetBool() and self:GetSightDelta() < 1 and asight.MagnifiedOptic)
            or (self:GetSightDelta() < 1 and asight.ScopeTexture)) then
        -- Necessary to call here since physbullets are not drawn until PreDrawEffects; cheap scope implementation will not allow them to be visible
        -- Introduces a bug when we try to call GetAttachment on the viewmodel in DrawPhysBullets here, so set a workaround variable to not call it
        ArcCW:DrawPhysBullets(true)
        self:FormCheapScope()
    end

    local coolFOV = stable.CurrentViewModelFOV or stable.ViewModelFOV

    if ArcCW.VMInRT then
        local mag = asight.ScopeMagnification
        coolFOV = stable.ViewModelFOV - mag * 4 - (ArcCW.ConVars["vm_add_ads"]:GetFloat() * 3 or 0)
        ArcCW.VMInRT = false
    end

    cam.Start3D(EyePos(), EyeAngles(), self:QuickFOVix(coolFOV), nil, nil, nil, nil, 0.5, 1000)
    render.DepthRange(0.0, 0.1)
    self:DrawCustomModel(false, nil, nil, stable)
    self:DoLHIK(stable)

    if !ArcCW.Overdraw then
        self:DoLaser(false, true)
    end

    -- patrol
    if POSTVMDONE == false and POSTVMDONE_TIME <= CurTime() then
        POSTVMDONE_TIME = CurTime() + 1
        ArcCW.Print("PostDrawViewModel failed response!! cam.End3D errors may be inbound!! You may have an addon conflict!!", true)
        ArcCW.Print("Follow the troubleshooting guide at https://github.com/HaodongMo/ArcCW/wiki/Help-&-Troubleshooting#camend3d-errors", true)
    end
    POSTVMDONE = false
end

function SWEP:PostDrawViewModel()
    POSTVMDONE = true
    if ArcCW.VM_OverDraw then return end
    render.SetBlend(1)
    cam.End3D()
    cam.Start3D(EyePos(), EyeAngles(), self:QuickFOVix(self.CurrentViewModelFOV or self.ViewModelFOV), nil, nil, nil, nil, 0.5, 1000)
    render.DepthRange(0.0, 0.1)

    if ArcCW.Overdraw then
        ArcCW.Overdraw = false
    else
        --self:DoLaser()
        self:DoHolosight()
    end

    cam.End3D()
end
