function SWEP:AdjustMouseSensitivity()
    if self:GetState() != ArcCW.STATE_SIGHTS then return end

    local threshold = ArcCW.ConVars["adjustsensthreshold"]:GetFloat()

    local irons = self:GetActiveSights() or {}

    local tmag = ((irons.Magnification or 1) + (irons.ScopeMagnification or 0))

    if tmag < threshold then return end

    return 1 / tmag
end

function SWEP:Scroll(var)
    local irons = self:GetActiveSights()

    if irons.ScrollFunc == ArcCW.SCROLL_ZOOM then
        if !irons.ScopeMagnificationMin then return end
        if !irons.ScopeMagnificationMax then return end

        local old = irons.ScopeMagnification

        local minus = var < 0

        var = math.abs(irons.ScopeMagnificationMax - irons.ScopeMagnificationMin)

        var = var / (irons.ZoomLevels or 5)

        if minus then
            var = var * -1
        end

        irons.ScopeMagnification = irons.ScopeMagnification - var

        irons.ScopeMagnification = math.Clamp(irons.ScopeMagnification, irons.ScopeMagnificationMin, irons.ScopeMagnificationMax)

        self.SightMagnifications[irons.Slot or 0] = irons.ScopeMagnification

        if old != irons.ScopeMagnification then
            self:MyEmitSound(irons.ZoomSound or "", 75, math.Rand(95, 105), 1, CHAN_ITEM)
        end

        -- if !irons.MinZoom then return end
        -- if !irons.MaxZoom then return end

        -- local old = irons.Magnification

        -- irons.Magnification = irons.Magnification - var

        -- irons.Magnification = math.Clamp(irons.Magnification, irons.MinZoom, irons.MaxZoom)

        -- if old != irons.Magnification then
        --     self:MyEmitSound(irons.ZoomSound or "", 75, 100, 1, CHAN_ITEM)
        -- end
    end

end

local ang0 = Angle(0, 0, 0)

SWEP.ViewPunchAngle = Angle(ang0)
SWEP.ViewPunchVelocity = Angle(ang0)

function SWEP:OurViewPunch(angle)
    self.ViewPunchVelocity:Add(angle)
    for i = 1, 3 do self.ViewPunchVelocity[i] = math.Clamp(self.ViewPunchVelocity[i], -180, 180) end
end

function SWEP:GetOurViewPunchAngles(stable)
    stable = stable or self:GetTable()
    local a = self:GetOwner():GetViewPunchAngles()
    local vpang = stable.ViewPunchAngle
    for i = 1, 3 do a[i] = a[i] + vpang[i] * 10 end
    return a
end

local function lensqr(ang)
    return (ang[1] ^ 2) + (ang[2] ^ 2) + (ang[3] ^ 2)
end

-- scraped from source SDK 2013, just like this viewpunch damping code
local PUNCH_DAMPING = 9
local PUNCH_SPRING_CONSTANT = 120

function SWEP:DoOurViewPunch()
    -- if ( player->m_Local.m_vecPunchAngle->LengthSqr() > 0.001 || player->m_Local.m_vecPunchAngleVel->LengthSqr() > 0.001 )

    local vpa = self.ViewPunchAngle
    local vpv = self.ViewPunchVelocity

    if lensqr(vpa) + lensqr(vpv) > 0.000001 then
        -- {
        --     player->m_Local.m_vecPunchAngle += player->m_Local.m_vecPunchAngleVel * gpGlobals->frametime;
        --     float damping = 1 - (PUNCH_DAMPING * gpGlobals->frametime);

        local ft = FrameTime()

        vpa = vpa + (vpv * ft)
        local damping = 1 - (PUNCH_DAMPING * ft)

        --     if ( damping < 0 )
        --     {
        --         damping = 0;
        --     }

        if damping < 0 then damping = 0 end

        --     player->m_Local.m_vecPunchAngleVel *= damping;

        vpv = vpv * damping

        --     // torsional spring
        --     // UNDONE: Per-axis spring constant?
        --     float springForceMagnitude = PUNCH_SPRING_CONSTANT * gpGlobals->frametime;
        local springforcemagnitude = PUNCH_SPRING_CONSTANT * ft
        --     springForceMagnitude = clamp(springForceMagnitude, 0.f, 2.f );
        springforcemagnitude = math.Clamp(springforcemagnitude, 0, 2)
        --     player->m_Local.m_vecPunchAngleVel -= player->m_Local.m_vecPunchAngle * springForceMagnitude;
        vpv = vpv - (vpa * springforcemagnitude)

        --     // don't wrap around
        --     player->m_Local.m_vecPunchAngle.Init(
        --         clamp(player->m_Local.m_vecPunchAngle->x, -89.f, 89.f ),
        --         clamp(player->m_Local.m_vecPunchAngle->y, -179.f, 179.f ),
        --         clamp(player->m_Local.m_vecPunchAngle->z, -89.f, 89.f ) );
        -- }

        vpa[1] = math.Clamp(vpa[1], -89.9, 89.9)
        vpa[2] = math.Clamp(vpa[2], -179.9, 179.9)
        vpa[3] = math.Clamp(vpa[3], -89.9, 89.9)

        self.ViewPunchAngle = vpa
        self.ViewPunchVelocity = vpv
    else
        self.ViewPunchAngle = Angle(ang0)
        self.ViewPunchVelocity = Angle(ang0)
    end
end

-- viewbob during reload and firing shake
SWEP.ProceduralViewOffset = Angle(ang0)
local procedural_spdlimit = 5
local oldangtmp
local mzang_fixed,mzang_fixed_last
local mzang_velocity = Angle(ang0)
local progress = 0
local targint,targbool

function SWEP:CoolView(ply, pos, ang, fov)
    if !ang then return end
    if ply != LocalPlayer() then return end
    if ply:ShouldDrawLocalPlayer() then return end
    local vm = ply:GetViewModel()
    if !IsValid(vm) then return end
    local ftv = FrameTime()

    local gunbone, gbslot = self:GetBuff_Override("LHIK_CamDriver")
    local lhik_anim_model = gbslot and self.Attachments[gbslot].GodDriver and self.Attachments[gbslot].GodDriver.Model
    if IsValid(lhik_anim_model) and lhik_anim_model:GetAttachment(gunbone) then
        local catang = lhik_anim_model:GetAttachment(gunbone).Ang

        catang:Sub( Angle( 0, 90, 90 ) )
        catang.y = -catang.y
        local r = catang.r
        catang.r = -catang.p
        catang.p = -r

        ang:RotateAroundAxis( ang:Right(),		catang.x )
        ang:RotateAroundAxis( ang:Up(),			catang.y )
        ang:RotateAroundAxis( ang:Forward(),	catang.z )

    end

    -- Cam_Offset_Ang might not always be assigned properly. Try not to use it if it's nil, or it'll tilt the player's view.
    local att = self:GetBuff_Override("Override_CamAttachment", self.CamAttachment) or -1
    if vm:GetAttachment(att) and self.Cam_Offset_Ang then
        local attang = vm:WorldToLocalAngles(vm:GetAttachment(att).Ang)
        attang:Sub(self.Cam_Offset_Ang)
        ang:Add(attang)
        return
    end

    local viewbobintensity = self.ProceduralViewBobIntensity or 0.3

    if viewbobintensity == 0 then return end

    oldangtmp = ang * 1

    targbool = self:GetNextPrimaryFire() - .1 > CurTime()
    targint = targbool and 1 or 0
    targint = math.min(targint, 1-math.pow( vm:GetCycle(), 2 ) )
    progress = Lerp(ftv * 15, progress, targint)

    local angpos = vm:GetAttachment(self.ProceduralViewBobAttachment or self.MuzzleEffectAttachment or 1)

    if angpos and self:GetReloading() then
        mzang_fixed = vm:WorldToLocalAngles(angpos.Ang)
        mzang_fixed:Normalize()
    else return
    end

    self.ProceduralViewOffset:Normalize()

    if mzang_fixed_last then
        local delta = mzang_fixed - mzang_fixed_last
        delta:Normalize()
        mzang_velocity = mzang_velocity + delta * 2
        mzang_velocity.p = math.Approach(mzang_velocity.p, -self.ProceduralViewOffset.p * 2, ftv * 20)
        mzang_velocity.p = math.Clamp(mzang_velocity.p, -procedural_spdlimit, procedural_spdlimit)
        self.ProceduralViewOffset.p = self.ProceduralViewOffset.p + mzang_velocity.p * ftv
        self.ProceduralViewOffset.p = math.Clamp(self.ProceduralViewOffset.p, -90, 90)
        mzang_velocity.y = math.Approach(mzang_velocity.y, -self.ProceduralViewOffset.y * 2, ftv * 20)
        mzang_velocity.y = math.Clamp(mzang_velocity.y, -procedural_spdlimit, procedural_spdlimit)
        self.ProceduralViewOffset.y = self.ProceduralViewOffset.y + mzang_velocity.y * ftv
        self.ProceduralViewOffset.y = math.Clamp(self.ProceduralViewOffset.y, -90, 90)
        mzang_velocity.r = math.Approach(mzang_velocity.r, -self.ProceduralViewOffset.r * 2, ftv * 20)
        mzang_velocity.r = math.Clamp(mzang_velocity.r, -procedural_spdlimit, procedural_spdlimit)
        self.ProceduralViewOffset.r = self.ProceduralViewOffset.r + mzang_velocity.r * ftv
        self.ProceduralViewOffset.r = math.Clamp(self.ProceduralViewOffset.r, -90, 90)
    end

    self.ProceduralViewOffset.p = math.Approach(self.ProceduralViewOffset.p, 0, (1 - progress) * ftv * -self.ProceduralViewOffset.p)
    self.ProceduralViewOffset.y = math.Approach(self.ProceduralViewOffset.y, 0, (1 - progress) * ftv * -self.ProceduralViewOffset.y)
    self.ProceduralViewOffset.r = math.Approach(self.ProceduralViewOffset.r, 0, (1 - progress) * ftv * -self.ProceduralViewOffset.r)
    mzang_fixed_last = mzang_fixed
    local ints = 3 * ArcCW.ConVars["vm_coolview_mult"]:GetFloat() * -viewbobintensity
    ang:RotateAroundAxis(ang:Right(), Lerp(progress, 0, -self.ProceduralViewOffset.p) * ints)
    ang:RotateAroundAxis(ang:Up(), Lerp(progress, 0, self.ProceduralViewOffset.y / 2) * ints)
    ang:RotateAroundAxis(ang:Forward(), Lerp(progress, 0, self.ProceduralViewOffset.r / 3) * ints)

    ang = LerpAngle(0, ang, oldangtmp)
end

function SWEP:CalcView(ply, pos, ang, fov)
    if !CLIENT then return end

    if ArcCW.ConVars["vm_coolview"]:GetBool() then
        self:CoolView(ply, pos, ang, fov)
    end

    if ArcCW.ConVars["shake"]:GetBool() and !engine.IsRecordingDemo() then
        local de = (0.2 + (self:GetSightDelta()*0.8))
        ang = ang + (AngleRand() * self.RecoilAmount * 0.006 * de)
    end

    ang = ang + (self.ViewPunchAngle * 10)

    return pos, ang, fov
end

function SWEP:ShouldGlint()
    return self:GetBuff_Override("ScopeGlint") and self:GetState() == ArcCW.STATE_SIGHTS
end

function SWEP:DoScopeGlint()
end