SWEP.Cam_Offset_Ang = nil --Angle(0, 0, 0)

function SWEP:SelectAnimation(anim, stable)
    stable = stable or self:GetTable()
    local nwstate = self:GetNWState()
    local anims = stable.Animations

    if nwstate == ArcCW.STATE_SIGHTS and anims[anim .. "_iron"] then
        anim = anim .. "_iron"
    end

    if nwstate == ArcCW.STATE_SIGHTS and anims[anim .. "_sights"] then
        anim = anim .. "_sights"
    end

    if nwstate == ArcCW.STATE_SIGHTS and anims[anim .. "_sight"] then
        anim = anim .. "_sight"
    end

    if nwstate == ArcCW.STATE_SPRINT and anims[anim .. "_sprint"] and !self:CanShootWhileSprint() then
        anim = anim .. "_sprint"
    end

    if anims[anim .. "_bipod"] and self:InBipod() then
        anim = anim .. "_bipod"
    end

    if self:GetState() == ArcCW.STATE_CUSTOMIZE and anims[anim .. "_inspect"] and ((CLIENT and !ArcCW.ConVars["noinspect"]:GetBool()) or (SERVER and self:GetOwner():GetInfoNum("arccw_noinspect", 0))) then
        anim = anim .. "_inspect"
    end

    if anims[anim .. "_empty"] and (self:Clip1() == 0 or (self:HasBottomlessClip() and self:Ammo1() == 0)) then
        anim = anim .. "_empty"
    end

    if anims[anim .. "_jammed"] and self:GetMalfunctionJam() then
        anim = anim .. "_jammed"
    end

    if anims[anim .. "_trigger"] and self:IsTriggerHeld() and self:GetBuff_Override("Override_TriggerDelay", stable.TriggerDelay, stable) then
        anim = anim .. "_trigger"
    end

    if !anims[anim] then return end

    return anim
end

SWEP.LastAnimStartTime = 0
SWEP.LastAnimFinishTime = 0

function SWEP:PlayAnimationEZ(key, mult, priority)
    return self:PlayAnimation(key, mult, true, 0, false, false, priority, false)
end

local issingleplayer = game.SinglePlayer()

function SWEP:PlayAnimation(key, mult, pred, startfrom, tt, skipholster, priority, absolute)
    mult = mult or 1
    pred = pred or false
    startfrom = startfrom or 0
    tt = tt or false
    --skipholster = skipholster or false Unused
    priority = priority or false
    absolute = absolute or false
    if !key then return end

    local ct = CurTime()

    if self:GetPriorityAnim() and !priority then return end

    local owner = self:GetOwner()

    if issingleplayer and SERVER and pred then
        net.Start("arccw_sp_anim")
        net.WriteString(key)
        net.WriteFloat(mult)
        net.WriteFloat(startfrom)
        net.WriteBool(tt)
        --net.WriteBool(skipholster) Unused
        net.WriteBool(priority)
        net.Send(owner)
    end

    local anim = self.Animations[key]
    if !anim then return end
    local tranim = self:GetBuff_Hook("Hook_TranslateAnimation", key)
    if self.Animations[tranim] then
        key = tranim
        anim = self.Animations[tranim]
    --[[elseif self.Animations[key] then -- Can't do due to backwards compatibility... unless you have a better idea?
        anim = self.Animations[key]
    else
        return]]
    end

    if anim.ViewPunchTable and CLIENT then
        for _, v in pairs(anim.ViewPunchTable) do

            if !v.t then continue end

            local st = (v.t * mult) - startfrom

            if isnumber(v.t) and st >= 0 and owner:IsPlayer() and (issingleplayer or IsFirstTimePredicted()) then
                self:SetTimer(st, function() self:OurViewPunch(v.p or Vector(0, 0, 0)) end, id)
            end
        end
    end

    if isnumber(anim.ShellEjectAt) then
        self:SetTimer(anim.ShellEjectAt * mult, function()
            local num = 1
            if self.RevolverReload then
                num = self.Primary.ClipSize - self:Clip1()
            end
            for _ = 1, num do
                self:DoShellEject()
            end
        end)
    end

    if !owner then return end
    if !owner.GetViewModel then return end
    local vm = owner:GetViewModel()

    if !vm then return end
    if !IsValid(vm) then return end

    local seq = anim.Source
    if anim.RareSource and util.SharedRandom("raresource", 0, 1, CurTime()) < (1 / (anim.RareSourceChance or 100)) then
        seq = anim.RareSource
    end
    seq = self:GetBuff_Hook("Hook_TranslateSequence", seq)

    if istable(seq) then
        seq["BaseClass"] = nil
        seq = seq[math.Round(util.SharedRandom("randomseq" .. CurTime(), 1, #seq))]
    end

    if isstring(seq) then
        seq = vm:LookupSequence(seq)
    end

    local time = absolute and 1 or self:GetAnimKeyTime(key)
    --if time == 0 then return end

    local ttime = (time * mult) - startfrom
    if startfrom > (time * mult) then return end

    if tt then
        self:SetNextPrimaryFire(ct + ((anim.MinProgress or time) * mult) - startfrom)
    end

    if anim.LHIK then
        self.LHIKStartTime = ct
        self.LHIKEndTime = ct + ttime

        if anim.LHIKTimeline then
            local lhiktimeline = {}

            for _, k in pairs(anim.LHIKTimeline) do
                table.Add(lhiktimeline, {t = (k.t or 0) * mult, lhik = k.lhik or 1})
            end

            self.LHIKTimeline = lhiktimeline
        else
            self.LHIKTimeline = {
                {t = -math.huge, lhik = 1},
                {t = ((anim.LHIKIn or 0.1) - (anim.LHIKEaseIn or anim.LHIKIn or 0.1)) * mult, lhik = 1},
                {t = (anim.LHIKIn or 0.1) * mult, lhik = 0},
                {t = ttime - ((anim.LHIKOut or 0.1) * mult), lhik = 0},
                {t = ttime - (((anim.LHIKOut or 0.1) - (anim.LHIKEaseOut or anim.LHIKOut or 0.1)) * mult), lhik = 1},
                {t = math.huge, lhik = 1}
            }

            if anim.LHIKIn == 0 then
                self.LHIKTimeline[1].lhik = -math.huge
                self.LHIKTimeline[2].lhik = -math.huge
            end

            if anim.LHIKOut == 0 then
                self.LHIKTimeline[#self.LHIKTimeline - 1].lhik = math.huge
                self.LHIKTimeline[#self.LHIKTimeline].lhik = math.huge
            end
        end
    else
        self.LHIKTimeline = nil
    end

    if anim.LastClip1OutTime then
        self.LastClipOutTime = ct + ((anim.LastClip1OutTime * mult) - startfrom)
    end

    if anim.TPAnim then
        local aseq = owner:SelectWeightedSequence(anim.TPAnim)
        if aseq then
            owner:AddVCDSequenceToGestureSlot( GESTURE_SLOT_ATTACK_AND_RELOAD, aseq, anim.TPAnimStartTime or 0, true )
            if !issingleplayer and SERVER then
                net.Start("arccw_networktpanim")
                    net.WriteEntity(owner)
                    net.WriteUInt(aseq, 16)
                    net.WriteFloat(anim.TPAnimStartTime or 0)
                net.SendPVS(owner:GetPos())
            end
        end
    end

    if !(issingleplayer and CLIENT) and (issingleplayer or IsFirstTimePredicted() or self.ReadySoundTableHack) then
        self:PlaySoundTable(anim.SoundTable or {}, 1 / mult, startfrom, key)
        self.ReadySoundTableHack = nil
    end

    if seq then
        vm:SendViewModelMatchingSequence(seq)
        local dur = vm:SequenceDuration()
        vm:SetPlaybackRate(math.Clamp(dur / (ttime + startfrom), -4, 12))
        self.LastAnimStartTime = ct
        self.LastAnimFinishTime = ct + dur
        self.LastAnimKey = key
    end

    -- Grabs the current angle of the cam attachment bone and use it as the common offset for all cambone changes.
    -- Problem: If this animation interrupted a previous animation with cambone movement,
    -- it will start with an incorrect offset and snap at the end.
    -- Therefore this now only ever sets it once.
    local att = self:GetBuff_Override("Override_CamAttachment", self.CamAttachment)
    if att and vm:GetAttachment(att) and (anim.ForceCamReset or self.Cam_Offset_Ang == nil) then
        local ang = vm:GetAttachment(att).Ang
        ang = vm:WorldToLocalAngles(ang)
        self.Cam_Offset_Ang = Angle(ang)
    end

    self:SetNextIdle(CurTime() + ttime)

    return true
end

function SWEP:PlayIdleAnimation(pred, stable)
    stable = stable or self:GetTable()
    local ianim = self:SelectAnimation("idle", stable)
    if self:GetGrenadePrimed() then
        ianim = self:GetGrenadeAlt() and self:SelectAnimation("pre_throw_hold_alt", stable) or self:SelectAnimation("pre_throw_hold", stable)
    end

    -- (key, mult, pred, startfrom, tt, skipholster, ignorereload)
    local inubgl = self:GetInUBGL()

    if inubgl then
        local ubglanims = self:GetBuff_Override("UBGL_BaseAnims", _, stable)
        local anims = stable.Animations

        if ubglanims and anims.idle_ubgl_empty and self:Clip2() <= 0 then
            ianim = "idle_ubgl_empty"
        elseif ubglanims and anims.idle_ubgl then
            ianim = "idle_ubgl"
        end
    end

    if stable.LastAnimKey ~= ianim then
        ianim = self:GetBuff_Hook("Hook_IdleReset", ianim, _, stable) or ianim
    end

    self:PlayAnimation(ianim, 1, pred, nil, nil, nil, true)
end

function SWEP:GetAnimKeyTime(key, min)
    if !self:GetOwner() then return 1 end

    local anim = self.Animations[key]

    if !anim then return 1 end

    if self:GetOwner():IsNPC() then return anim.Time or 1 end

    local vm = self:GetOwner():GetViewModel()

    if !vm or !IsValid(vm) then return 1 end

    local t = anim.Time
    if !t then
        local tseq = anim.Source

        if istable(tseq) then
            tseq["BaseClass"] = nil -- god I hate Lua inheritance
            tseq = tseq[1]
        end

        if !tseq then return 1 end
        tseq = vm:LookupSequence(tseq)

        -- to hell with it, just spits wrong on draw sometimes
        t = vm:SequenceDuration(tseq) or 1
    end

    if min and anim.MinProgress then
        t = anim.MinProgress
    end

    if anim.Mult then
        t = t * anim.Mult
    end

    return t
end

if CLIENT then
    net.Receive("arccw_networktpanim", function()
        local ent = net.ReadEntity()
        local aseq = net.ReadUInt(16)
        local starttime = net.ReadFloat()
        if IsValid(ent) and ent ~= LocalPlayer() and ent:IsPlayer() then
            ent:AddVCDSequenceToGestureSlot( GESTURE_SLOT_ATTACK_AND_RELOAD, aseq, starttime, true )
        end
    end)
end

function SWEP:QueueAnimation() end
function SWEP:NextAnimation() end
