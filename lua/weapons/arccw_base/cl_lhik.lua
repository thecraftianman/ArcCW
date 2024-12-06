local issingleplayer = game.SinglePlayer()
local lhikangoffset = Angle(0, 90, 90)

local function qerp(delta, a, b)
    local qdelta = -(delta ^ 2) + (delta * 2)

    qdelta = math.Clamp(qdelta, 0, 1)

    return Lerp(qdelta, a, b)
end

SWEP.LHIKAnimation_IsIdle = false
SWEP.LHIKAnimation = nil
SWEP.LHIKAnimationStart = 0
SWEP.LHIKAnimationTime = 0

SWEP.LHIKCamAng = Angle(0, 0, 0)
SWEP.LHIKGunAng = Angle(0, 0, 0)

function SWEP:DoLHIKAnimation(key, time, spbitch, stable)
    stable = stable or self:GetTable()
    local owner = self:GetOwner()

    if !IsValid(owner) then return end

    if issingleplayer and !spbitch then
        timer.Simple(0, function() if IsValid(self) then self:DoLHIKAnimation(key, time, true, stable) end end)
        return
    end

    local vm = owner:GetViewModel()
    if !IsValid(vm) then return end

    local lhik_model
    local lhik_anim_model
    local LHIK_GunDriver
    local LHIK_CamDriver
    local offsetang

    local tranim = self:GetBuff_Hook("Hook_LHIK_TranslateAnimation", key, _, stable)

    key = tranim or key

    for i, k in ipairs(stable.Attachments) do
        if !k.Installed then continue end
        if !k.VElement then continue end

        if self:GetBuff_Stat("LHIK", i) then
            lhik_model = k.VElement.Model
            lhik_anim_model = k.GodDriver and k.GodDriver.Model or false
            offsetang = k.VElement.OffsetAng

            local gundriver = self:GetBuff_Stat("LHIK_GunDriver", i)
            if gundriver then
                LHIK_GunDriver = gundriver
            end

            local camdriver = self:GetBuff_Stat("LHIK_CamDriver", i)
            if camdriver then
                LHIK_CamDriver = camdriver
            end
        end
    end

    if !IsValid(lhik_model) then return false end

    local seq = lhik_model:LookupSequence(key)
    local validanimmodel = IsValid(lhik_anim_model)

    if !seq then return false end
    if seq == -1 then return false end

    lhik_model:ResetSequence(seq)
    if validanimmodel then
        lhik_anim_model:ResetSequence(seq)
    end

    if !time or time < 0 then time = lhik_model:SequenceDuration(seq) end

    stable.LHIKAnimation = seq
    stable.LHIKAnimationStart = UnPredictedCurTime()
    stable.LHIKAnimationTime = time

    stable.LHIKAnimation_IsIdle = false

    if validanimmodel and LHIK_GunDriver then
        local att = lhik_anim_model:LookupAttachment(LHIK_GunDriver)
        local ang = lhik_anim_model:GetAttachment(att).Ang
        local pos = lhik_anim_model:GetAttachment(att).Pos

        stable.LHIKGunAng = lhik_anim_model:WorldToLocalAngles(ang) - lhikangoffset
        stable.LHIKGunPos = lhik_anim_model:WorldToLocal(pos)

        stable.LHIKGunAngVM = vm:WorldToLocalAngles(ang) - lhikangoffset
        stable.LHIKGunPosVM = vm:WorldToLocal(pos)
    end

    if validanimmodel and LHIK_CamDriver then
        local att = lhik_anim_model:LookupAttachment(LHIK_CamDriver)
        local ang = lhik_anim_model:GetAttachment(att).Ang

        stable.LHIKCamOffsetAng = offsetang
        stable.LHIKCamAng = lhik_anim_model:WorldToLocalAngles(ang)
    end

    -- lhik_model:SetCycle(0)
    -- lhik_model:SetPlaybackRate(dur / time)

    return true
end

SWEP.LHIKDelta = {}
SWEP.LHIKDeltaAng = {}
SWEP.ViewModel_Hit = Vector(0, 0, 0)
SWEP.Customize_Hide = 0

function SWEP:GetLHIKAnim()
    local cyc = (UnPredictedCurTime() - self.LHIKAnimationStart) / self.LHIKAnimationTime

    if cyc > 1 then return nil end
    if self.LHIKAnimation_IsIdle then return nil end

    return self.LHIKAnimation
end

function SWEP:DoLHIK(stable)
    stable = stable or self:GetTable()
    local owner = self:GetOwner()

    if !IsValid(owner) then return end

    local justhide = false
    local lhik_model = nil
    local lhik_anim_model = nil
    local hide_component = false
    local delta = 1

    local vm = owner:GetViewModel()

    if !ArcCW.ConVars["reloadincust"]:GetBool() and !stable.NoHideLeftHandInCustomization and !self:GetBuff_Override("Override_NoHideLeftHandInCustomization", _, stable) then
        if self:GetState() == ArcCW.STATE_CUSTOMIZE then
            stable.Customize_Hide = math.Approach(stable.Customize_Hide, 1, FrameTime() / 0.25)
        else
            stable.Customize_Hide = math.Approach(stable.Customize_Hide, 0, FrameTime() / 0.25)
        end
    end

    for i, k in ipairs(stable.Attachments) do
        if !k.Installed then continue end
        -- local atttbl = ArcCW.AttachmentTable[k.Installed]

        -- if atttbl.LHIKHide then
        if self:GetBuff_Stat("LHIKHide", i, stable) then
            justhide = true
        end

        if !k.VElement then continue end

        -- if atttbl.LHIK then
        if self:GetBuff_Stat("LHIK", i, stable) then
            lhik_model = k.VElement.Model
            if k.GodDriver then
                lhik_anim_model = k.GodDriver.Model
            end
        end
    end

    local tl = stable.LHIKTimeline
    local curtime = UnPredictedCurTime()
    local valid_lhik = lhik_model and IsValid(lhik_model)

    if tl then
        local stage, next_stage, next_stage_index
        local start_time = stable.LHIKStartTime

        for i, k in pairs(tl) do
            if !k or !k.t then continue end
            if k.t + start_time > curtime then
                next_stage_index = i
                break
            end
        end

        if next_stage_index then
            if next_stage_index == 1 then
                -- we are on the first stage.
                stage = {t = 0, lhik = 0}
                next_stage = tl[next_stage_index]
            else
                stage = tl[next_stage_index - 1]
                next_stage = tl[next_stage_index]
            end
        else
            stage = tl[#tl]
            next_stage = {t = stable.LHIKEndTime, lhik = tl[#tl].lhik}
        end

        local local_time = curtime - start_time

        local delta_time = next_stage.t - stage.t
        delta_time = (local_time - stage.t) / delta_time

        delta = qerp(delta_time, stage.lhik, next_stage.lhik)

        if valid_lhik then
            local key

            if stage.lhik > next_stage.lhik then
                key = "in"
            elseif next_stage.lhik > stage.lhik then
                key = "out"
            end

            if key then
                local tranim = self:GetBuff_Hook("Hook_LHIK_TranslateAnimation", key, _, stable)

                key = tranim or key

                local seq = lhik_model:LookupSequence(key)

                if seq and seq > 0 then
                    lhik_model:SetSequence(seq)
                    lhik_model:SetCycle(delta)
                    if lhik_anim_model then
                        lhik_anim_model:SetSequence(seq)
                        lhik_anim_model:SetCycle(delta)
                    end
                end
            end
        end

        -- if tl[4] <= UnPredictedCurTime() then
        --     -- it's over
        --     delta = 1
        -- elseif tl[3] <= UnPredictedCurTime() then
        --     -- transition back to 1
        --     delta = (UnPredictedCurTime() - tl[3]) / (tl[4] - tl[3])
        --     delta = qerp(delta, 0, 1)

        --     if lhik_model and IsValid(lhik_model) then
        --         local key = "out"

        --         local tranim = self:GetBuff_Hook("Hook_LHIK_TranslateAnimation", key)

        --         key = tranim or key

        --         local seq = lhik_model:LookupSequence(key)

        --         if seq and seq > 0 then
        --             lhik_model:SetSequence(seq)
        --             lhik_model:SetCycle(delta)
        --         end
        --     end
        -- elseif tl[2] <= UnPredictedCurTime() then
        --     -- hold 0
        --     delta = 0
        -- elseif tl[1] <= UnPredictedCurTime() then
        --     -- transition to 0
        --     delta = (UnPredictedCurTime() - tl[1]) / (tl[2] - tl[1])
        --     delta = qerp(delta, 1, 0)

        --     if lhik_model and IsValid(lhik_model) then
        --         local key = "in"

        --         local tranim = self:GetBuff_Hook("Hook_LHIK_TranslateAnimation", key)

        --         key = tranim or key

        --         local seq = lhik_model:LookupSequence(key)

        --         if seq and seq > 0 then
        --             lhik_model:SetSequence(seq)
        --             lhik_model:SetCycle(delta)
        --         end
        --     end
    else
        -- hasn't started yet
        delta = 1
    end

    if delta == 1 and stable.Customize_Hide > 0 then
        if !valid_lhik then
            justhide = true
            delta = math.min(stable.Customize_Hide, delta)
        else
            hide_component = true
        end
    end

    local eyeang = EyeAngles()

    if justhide then
        local vm_offset = (eyeang:Up() * 12) + (eyeang:Forward() * 12) + (eyeang:Right() * 4)

        for _, bone in ipairs(ArcCW.LHIKBones) do
            local vmbone = vm:LookupBone(bone)

            if !vmbone then continue end -- Happens when spectating someone prolly

            local vmtransform = vm:GetBoneMatrix(vmbone)

            if !vmtransform then continue end -- something very bad has happened

            local vm_pos = vmtransform:GetTranslation()
            --local vm_ang = vmtransform:GetAngles()

            --local newtransform = Matrix()
            local newtranslation = LerpVector(delta, vm_pos, vm_pos - vm_offset)

            vmtransform:SetTranslation(newtranslation)
            --newtransform:SetAngles(vm_ang)

            vm:SetBoneMatrix(vmbone, newtransform)
        end
    end

    if !valid_lhik then return end

    lhik_model:SetupBones()

    if justhide then return end

    local cyc = (curtime - stable.LHIKAnimationStart) / stable.LHIKAnimationTime

    local lhik_anim = stable.LHIKAnimation

    if lhik_anim and cyc < 1 then
        lhik_model:SetSequence(lhik_anim)
        lhik_model:SetCycle(cyc)
        if IsValid(lhik_anim_model) then
            lhik_anim_model:SetSequence(lhik_anim)
            lhik_anim_model:SetCycle(cyc)
        end
    else
        local key = "idle"

        local tranim = self:GetBuff_Hook("Hook_LHIK_TranslateAnimation", key, _, stable)

        key = tranim or key

        if key and key != "DoNotPlayIdle" then
            self:DoLHIKAnimation(key, -1, _, stable)
        end

        stable.LHIKAnimation_IsIdle = true
    end

    local cf_deltapos = vector_origin
    local cf = 0
    local gun_driver = self:GetBuff_Override("LHIK_GunDriver", _, stable)
    local lhik_delta = stable.LHIKDelta
    local vm_offset = (eyeang:Up() * 12) + (eyeang:Forward() * 12) + (eyeang:Right() * 4)

    for _, bone in ipairs(ArcCW.LHIKBones) do
        local vmbone = vm:LookupBone(bone)
        local lhikbone = lhik_model:LookupBone(bone)

        if !vmbone then continue end
        if !lhikbone then continue end

        local vmtransform = vm:GetBoneMatrix(vmbone)
        local lhiktransform = lhik_model:GetBoneMatrix(lhikbone)

        if !vmtransform then continue end
        if !lhiktransform then continue end

        local vm_pos = vmtransform:GetTranslation()
        local vm_ang = vmtransform:GetAngles()
        local lhik_pos = lhiktransform:GetTranslation()
        local lhik_ang = lhiktransform:GetAngles()

        --local newtransform = Matrix()
        local newtranslation = LerpVector(delta, vm_pos, lhik_pos)
        local newang = LerpAngle(delta, vm_ang, lhik_ang)

        --newtransform:SetTranslation(LerpVector(delta, vm_pos, lhik_pos))
        --newtransform:SetAngles(LerpAngle(delta, vm_ang, lhik_ang))

        local localpos = lhik_model:WorldToLocal(lhik_pos)

        if !gun_driver and lhik_delta[lhikbone] and lhik_anim and cyc < 1 then
            local deltapos = localpos - lhik_delta[lhikbone]

            if !deltapos:IsZero() then
                cf_deltapos = cf_deltapos + deltapos
                cf = cf + 1
            end
        end

        lhik_delta[lhikbone] = localpos

        if hide_component then
            --local new_pos = newtransform:GetTranslation()
            --newtransform:SetTranslation(LerpVector(stable.Customize_Hide, new_pos, new_pos - vm_offset))
            newtranslation = LerpVector(stable.Customize_Hide, newtranslation, newtranslation - vm_offset)
        end

        vmtransform:SetTranslation(newtranslation)
        vmtransform:SetAngles(newang)

        --local matrix = newtransform

        vm:SetBoneMatrix(vmbone, vmtransform)

        -- local vm_pos, vm_ang = vm:GetBonePosition(vmbone)
        -- local lhik_pos, lhik_ang = lhik_model:GetBonePosition(lhikbone)

        -- local pos = LerpVector(delta, vm_pos, lhik_pos)
        -- local ang = LerpAngle(delta, vm_ang, lhik_ang)

        -- vm:SetBonePosition(vmbone, pos, ang)
    end

    if !cf_deltapos:IsZero() and cf > 0 and self:GetBuff_Override("LHIK_Animation", _, stable) then
        local new = Vector(0, 0, 0)
        local viewmult = self:GetBuff_Override("LHIK_MovementMult", _, stable) or 1

        new[1] = cf_deltapos[2] * viewmult
        new[2] = cf_deltapos[1] * viewmult
        new[3] = cf_deltapos[3] * viewmult

        stable.ViewModel_Hit = LerpVector(0.25, stable.ViewModel_Hit, new / cf):GetNormalized()
    end
end