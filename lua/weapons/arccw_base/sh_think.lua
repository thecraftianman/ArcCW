if CLIENT then
    ArcCW.LastWeapon = nil
end

local vec1 = Vector(1, 1, 1)
local vec0 = vec1 * 0
local ang0 = Angle(0, 0, 0)
local issingleplayer = game.SinglePlayer()

-- local lastUBGL = 0
function SWEP:Think()
    local owner = self:GetOwner()

    if IsValid(owner) and self:GetClass() == "arccw_base" then
        self:Remove()
        return
    end

    if !IsValid(owner) or owner:IsNPC() then return end

    local stable = self:GetTable()

    if self:GetState() == ArcCW.STATE_DISABLE and !self:GetPriorityAnim() then
        self:SetState(ArcCW.STATE_IDLE)

        if CLIENT and stable.UnReady then
            stable.UnReady = false
        end
    end

    local curtime = CurTime()
    local isfirsttimepredicted = IsFirstTimePredicted()
    local eventtbl = stable.EventTable
    local lastanimkey = stable.LastAnimKey
    local lastanimstart = stable.LastAnimStartTime

    for i, v in ipairs(eventtbl) do
        for ed, bz in pairs(v) do
            if ed <= curtime then
                if bz.AnimKey and (bz.AnimKey != lastanimkey or bz.StartTime != lastanimstart) then
                    continue
                end
                self:PlayEvent(bz)
                eventtbl[i][ed] = nil
                --print(CurTime(), "Event completed at " .. i, ed)
                if table.IsEmpty(v) and i != 1 then eventtbl[i] = nil --[[print(CurTime(), "No more events at " .. i .. ", killing")]] end
            end
        end
    end

    if CLIENT and (!issingleplayer and isfirsttimepredicted or true)
            and owner == LocalPlayer() and ArcCW.InvHUD
            and !ArcCW.Inv_Hidden and ArcCW.Inv_Fade == 0 then
        ArcCW.InvHUD:Remove()
        ArcCW.Inv_Fade = 0.01
    end

    local vm = owner:GetViewModel()

    stable.BurstCount = self:GetBurstCount()

    local sg = self:GetShotgunReloading()
    if (sg == 2 or sg == 4) and owner:KeyPressed(IN_ATTACK) then
        self:SetShotgunReloading(sg + 1)
    elseif (sg >= 2) and self:GetReloadingREAL() <= curtime then
        self:ReloadInsert((sg >= 4) and true or false)
    end

    local inbipod = self:InBipod()
    local firemode = self:GetCurrentFiremode()

    if self:GetNeedCycle() and !stable.Throwing and !self:GetReloading() and self:GetWeaponOpDelay() < curtime and self:GetNextPrimaryFire() < curtime and -- Adding this delays bolting if the RPM is too low, but removing it may reintroduce the double pump bug. Increasing the RPM allows you to shoot twice on many multiplayer servers. Sure would be convenient if everything just worked nicely
            (!ArcCW.ConVars["clicktocycle"]:GetBool() and (firemode.Mode == 2 or !owner:KeyDown(IN_ATTACK))
            or ArcCW.ConVars["clicktocycle"]:GetBool() and (firemode.Mode == 2 or owner:KeyPressed(IN_ATTACK))) then
        local anim = self:SelectAnimation("cycle")
        anim = self:GetBuff_Hook("Hook_SelectCycleAnimation", anim, _, stable) or anim
        local mult = self:GetBuff_Mult("Mult_CycleTime", stable)
        local p = self:PlayAnimation(anim, mult, true, 0, true)
        if p then
            self:SetNeedCycle(false)
            self:SetPriorityAnim(curtime + self:GetAnimKeyTime(anim, true) * mult)
        end
    end

    local attack2down = owner:KeyDown(IN_ATTACK2)

    if self:GetGrenadePrimed() and !(owner:KeyDown(IN_ATTACK) or attack2down) and (!issingleplayer or SERVER) then
        self:Throw()
    end

    if self:GetGrenadePrimed() and stable.GrenadePrimeTime > 0 and stable.isCooked then
        local heldtime = (curtime - stable.GrenadePrimeTime)

        local ft = self:GetBuff_Override("Override_FuseTime", _, stable) or stable.FuseTime

        if ft and (heldtime >= ft) and (!issingleplayer or SERVER) then
            self:Throw()
        end
    end

    if isfirsttimepredicted and self:GetNextPrimaryFire() < curtime and owner:KeyReleased(IN_USE) then
        if inbipod then
            self:ExitBipod()
        else
            self:EnterBipod()
        end
    end

    local attackreleased = owner:KeyReleased(IN_ATTACK)

    if ((issingleplayer and SERVER) or (!issingleplayer and true)) and self:GetBuff_Override("Override_TriggerDelay", stable.TriggerDelay, stable) then
        if attackreleased and self:GetBuff_Override("Override_TriggerCharge", stable.TriggerCharge, stable) and self:GetTriggerDelta(true) >= 1 then
            self:PrimaryAttack()
        else
            self:DoTriggerDelay()
        end
    end

    if firemode.RunawayBurst then

        if self:GetBurstCount() > 0 and ((issingleplayer and SERVER) or (!issingleplayer and true)) then
            self:PrimaryAttack()
        end

        if self:Clip1() < self:GetBuff("AmmoPerShot", _, _, stable) or self:GetBurstCount() == self:GetBurstLength() then
            self:SetBurstCount(0)
            if !firemode.AutoBurst then
                stable.Primary.Automatic = false
            end
        end
    end

    if attackreleased then

        if !firemode.RunawayBurst then
            self:SetBurstCount(0)
            stable.LastTriggerTime = -1 -- Cannot fire again until trigger released
            stable.LastTriggerDuration = 0
        end

        if firemode.Mode < 0 and !firemode.RunawayBurst then
            local postburst = firemode.PostBurstDelay or 0

            if (curtime + postburst) > self:GetWeaponOpDelay() then
                --self:SetNextPrimaryFire(curtime + postburst)
                self:SetWeaponOpDelay(curtime + postburst * self:GetBuff_Mult("Mult_PostBurstDelay", stable) + self:GetBuff_Add("Add_PostBurstDelay", stable))
            end
        end
    end

    if owner and owner:GetInfoNum("arccw_automaticreload", 0) == 1 and self:Clip1() == 0 and !self:GetReloading() and curtime > self:GetNextPrimaryFire() + 0.2 then
        self:Reload()
    end
    --[[
    local notreloadinsights = !(self:GetBuff_Override("Override_ReloadInSights", _, stable) or stable.ReloadInSights)
    if (notreloadinsights and (self:GetReloading() or owner:KeyDown(IN_RELOAD))) then
        if notreloadinsights and self:GetReloading() then
            self:ExitSights()
        end
    end
    ]]
    if (stable.Sighted or self:GetState() == ArcCW.STATE_SIGHTS) and self:GetBuff_Hook("Hook_ShouldNotSight", _, _, stable) then
        self:ExitSights()
    elseif self:GetHolster_Time() > 0 then
        self:ExitSights()
    else

        -- no it really doesn't, past me
        local sighted = self:GetState() == ArcCW.STATE_SIGHTS
        local toggle = owner:GetInfoNum("arccw_toggleads", 0) >= 1
        local suitzoom = owner:KeyDown(IN_ZOOM)
        local sp_cl = issingleplayer and CLIENT

        -- if in singleplayer, client realm should be completely ignored
        if toggle and !sp_cl then
            if owner:KeyPressed(IN_ATTACK2) then
                if sighted then
                    self:ExitSights()
                elseif !suitzoom then
                    self:EnterSights()
                end
            elseif suitzoom and sighted then
                self:ExitSights()
            end
        elseif !toggle then
            if (attack2down and !suitzoom) and !sighted then
                self:EnterSights()
            elseif (!attack2down or suitzoom) and sighted then
                self:ExitSights()
            end
        end

    end

    if (!issingleplayer and isfirsttimepredicted) or (issingleplayer and true) then
        local insprint = self:InSprint(stable)

        if insprint and (self:GetState() != ArcCW.STATE_SPRINT) then
            self:EnterSprint()
        elseif !insprint and (self:GetState() == ArcCW.STATE_SPRINT) then
            self:ExitSprint()
        end
    end

    if issingleplayer or isfirsttimepredicted then
        self:SetSightDelta(math.Approach(self:GetSightDelta(), self:GetState() == ArcCW.STATE_SIGHTS and 0 or 1, FrameTime() / self:GetSightTime()))
        self:SetSprintDelta(math.Approach(self:GetSprintDelta(), self:GetState() == ArcCW.STATE_SPRINT and 1 or 0, FrameTime() / self:GetSprintTime()))
    end

    if CLIENT and (issingleplayer or isfirsttimepredicted) then
        self:ProcessRecoil()
    end

    if CLIENT and IsValid(vm) then

        for i = 1, vm:GetBoneCount() do
            vm:ManipulateBoneScale(i, vec1)
        end

        for i, k in pairs(self:GetBuff_Override("Override_CaseBones", stable.CaseBones, stable) or {}) do
            if !isnumber(i) then continue end
            for _, b in pairs(istable(k) and k or {k}) do
                local bone = vm:LookupBone(b)

                if !bone then continue end

                if self:GetVisualClip() >= i then
                    vm:ManipulateBoneScale(bone, vec1)
                else
                    vm:ManipulateBoneScale(bone, vec0)
                end
            end
        end

        for i, k in pairs(self:GetBuff_Override("Override_BulletBones", stable.BulletBones, stable) or {}) do
            if !isnumber(i) then continue end
            for _, b in pairs(istable(k) and k or {k}) do
                local bone = vm:LookupBone(b)

                if !bone then continue end

                if self:GetVisualBullets() >= i then
                    vm:ManipulateBoneScale(bone, vec1)
                else
                    vm:ManipulateBoneScale(bone, vec0)
                end
            end
        end

        for i, k in pairs(self:GetBuff_Override("Override_StripperClipBones", stable.StripperClipBones, stable) or {}) do
            if !isnumber(i) then continue end
            for _, b in pairs(istable(k) and k or {k}) do
                local bone = vm:LookupBone(b)

                if !bone then continue end

                if self:GetVisualLoadAmount() >= i then
                    vm:ManipulateBoneScale(bone, vec1)
                else
                    vm:ManipulateBoneScale(bone, vec0)
                end
            end
        end
    end

    self:DoHeat()

    self:ThinkFreeAim()

    -- if CLIENT then
        -- if !IsValid(ArcCW.InvHUD) then
        --     gui.EnableScreenClicker(false)
        -- end

        -- if self:GetState() != ArcCW.STATE_CUSTOMIZE then
        --     self:CloseCustomizeHUD()
        -- else
        --     self:OpenCustomizeHUD()
        -- end
    -- end

    local eles = stable.Attachments

    for i = 1, #eles do
        local k = eles[i]
        local installed = k.Installed
        if !installed then continue end
        local atttbl = ArcCW.AttachmentTable[installed]

        if atttbl.DamagePerSecond then
            local dmg = atttbl.DamagePerSecond * FrameTime()

            self:DamageAttachment(i, dmg)
        end
    end

    if CLIENT then
        self:DoOurViewPunch()
    end

    if stable.Throwing and self:Clip1() == 0 and self:Ammo1() > 0 then
        self:SetClip1(1)
        owner:SetAmmo(self:Ammo1() - 1, stable.Primary.Ammo)
    end

    -- self:RefreshBGs()

    if self:GetMagUpIn() != 0 and curtime > self:GetMagUpIn() then
        self:ReloadTimed()
        self:SetMagUpIn( 0 )
    end

    local hasbottomless = self:HasBottomlessClip()

    if hasbottomless and self:Clip1() != ArcCW.BottomlessMagicNumber then
        self:Unload()
        self:SetClip1(ArcCW.BottomlessMagicNumber)
    elseif !hasbottomless and self:Clip1() == ArcCW.BottomlessMagicNumber then
        self:SetClip1(0)
    end

    -- Performing traces in rendering contexts seem to cause flickering with c_hands that have QC attachments(?)
    -- Since we need to run the trace every tick anyways, do it here instead
    if CLIENT then
        self:BarrelHitWall()
    end

    self:GetBuff_Hook("Hook_Think", _, _, stable)

    -- Running this only serverside in SP breaks animation processing and causes CheckpointAnimation to !reset.
    --if SERVER or !issingleplayer then
        self:ProcessTimers()
    --end

    -- Only reset to idle if we don't need cycle. empty idle animation usually doesn't play nice
    local nextidle = self:GetNextIdle()

    if nextidle != 0 and nextidle <= curtime and !self:GetNeedCycle()
            and self:GetHolster_Time() == 0 and self:GetShotgunReloading() == 0 then
        self:SetNextIdle(0)
        self:PlayIdleAnimation(true, stable)
    end

    if self:GetUBGLDebounce() and !owner:KeyDown(IN_RELOAD) then
        self:SetUBGLDebounce( false )
    end
end

local lst = SysTime()
local timescalecvar = GetConVar("host_timescale")

function SWEP:ProcessRecoil()
    local owner = self:GetOwner()
    local ft = (SysTime() - (lst or SysTime())) * timescalecvar:GetFloat()
    local newang = owner:EyeAngles()
    -- local r = self.RecoilAmount -- self:GetNWFloat("recoil", 0)
    -- local rs = self.RecoilAmountSide -- self:GetNWFloat("recoilside", 0)

    local ra = Angle(ang0)

    ra = ra + (self:GetBuff_Override("Override_RecoilDirection", self.RecoilDirection) * self.RecoilAmount * 0.5)
    ra = ra + (self:GetBuff_Override("Override_RecoilDirectionSide", self.RecoilDirectionSide) * self.RecoilAmountSide * 0.5)

    newang = newang - ra

    local rpb = self.RecoilPunchBack
    local rps = self.RecoilPunchSide
    local rpu = self.RecoilPunchUp

    if rpb != 0 then
        self.RecoilPunchBack = math.Approach(rpb, 0, ft * rpb * 10)
    end

    if rps != 0 then
        self.RecoilPunchSide = math.Approach(rps, 0, ft * rps * 5)
    end

    if rpu != 0 then
        self.RecoilPunchUp = math.Approach(rpu, 0, ft * rpu * 5)
    end

    lst = SysTime()
end

function SWEP:InSprint(stable)
    stable = stable or self:GetTable()
    local owner = self:GetOwner()

    local sm = stable.SpeedMult * self:GetBuff_Mult("Mult_SpeedMult", stable) * self:GetBuff_Mult("Mult_MoveSpeed", stable)

    sm = math.Clamp(sm, 0, 1)

    local walkspeed = owner:GetWalkSpeed() * sm

    local curspeed = owner:GetVelocity():Length()

    if TTT2 and owner.isSprinting == true then
        return (owner.sprintProgress or 0) > 0 and owner:KeyDown(IN_SPEED) and !owner:Crouching() and curspeed > walkspeed and owner:OnGround()
    end

    if !owner:KeyDown(IN_SPEED) or !owner:KeyDown(IN_FORWARD + IN_MOVELEFT + IN_MOVERIGHT + IN_BACK) then return false end
    if !owner:OnGround() then return false end
    if owner:Crouching() then return false end

    local sprintspeed = owner:GetRunSpeed() * sm

    if curspeed < Lerp(0.5, walkspeed, sprintspeed) then
        -- provide some grace time so changing directions won't immediately exit sprint
        stable.LastExitSprintCheck = stable.LastExitSprintCheck or CurTime()
        if stable.LastExitSprintCheck < CurTime() - 0.25 then
            return false
        end
    else
        stable.LastExitSprintCheck = nil
    end

    return true
end

function SWEP:IsTriggerHeld()
    return self:GetOwner():KeyDown(IN_ATTACK) and (self:CanShootWhileSprint() or (!self.Sprinted or self:GetState() != ArcCW.STATE_SPRINT)) and (self:GetHolster_Time() < CurTime()) and !self:GetPriorityAnim()
end

SWEP.LastTriggerTime = 0
SWEP.LastTriggerDuration = 0
function SWEP:GetTriggerDelta(noheldcheck)
    if self.LastTriggerTime <= 0 or (!noheldcheck and !self:IsTriggerHeld()) then return 0 end
    return math.Clamp((CurTime() - self.LastTriggerTime) / self.LastTriggerDuration, 0, 1)
end

function SWEP:DoTriggerDelay()
    local shouldHold = self:IsTriggerHeld()

    local reserve = self:HasBottomlessClip() and self:Ammo1() or self:Clip1()
    if self.LastTriggerTime == -1 or (!self.TriggerPullWhenEmpty and (reserve < self:GetBuff("AmmoPerShot"))) and self:GetNextPrimaryFire() < CurTime() then
        if !shouldHold then
            self.LastTriggerTime = 0 -- Good to fire again
            self.LastTriggerDuration = 0
        end
        return
    end

    if self:GetBurstCount() > 0 and self:GetCurrentFiremode().Mode == 1 then
        self.LastTriggerTime = -1 -- Cannot fire again until trigger released
        self.LastTriggerDuration = 0
    elseif self:GetNextPrimaryFire() < CurTime() and self.LastTriggerTime > 0 and !shouldHold then
        -- Attack key is released. Stop the animation and clear progress
        local anim = self:SelectAnimation("untrigger")
        if anim then
            self:PlayAnimation(anim, self:GetBuff_Mult("Mult_TriggerDelayTime"), true, 0)
        end
        self.LastTriggerTime = 0
        self.LastTriggerDuration = 0
        self:GetBuff_Hook("Hook_OnTriggerRelease")
    elseif self:GetNextPrimaryFire() < CurTime() and self.LastTriggerTime == 0 and shouldHold then
        -- We haven't played the animation yet. Pull it!
        local anim = self:SelectAnimation("trigger")
        local delaymult = self:GetBuff_Mult("Mult_TriggerDelayTime")
        self:PlayAnimation(anim, delaymult, true, 0, nil, nil, true) -- need to overwrite sprint up
        self.LastTriggerTime = CurTime()
        self.LastTriggerDuration = self:GetAnimKeyTime(anim, true) * delaymult
        self:GetBuff_Hook("Hook_OnTriggerHeld")
    end
end
