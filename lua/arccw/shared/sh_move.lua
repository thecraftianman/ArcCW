local IsValid = IsValid
local Lerp = Lerp
local m_clamp = math.Clamp

function ArcCW.Move(ply, mv, cmd)
    local wpn = ply:GetActiveWeapon()
    local wpntbl = wpn:GetTable()

    if !wpn.ArcCW then return end

    local basespd = (Vector(cmd:GetForwardMove(), cmd:GetUpMove(), cmd:GetSideMove())):Length()
    basespd = math.min(basespd, mv:GetMaxClientSpeed())

    if basespd == 0 then return end -- The player isn't moving, so we don't have to make any further changes

    local s = m_clamp(wpntbl.SpeedMult * wpn:GetBuff_Mult("Mult_SpeedMult", wpntbl) * wpn:GetBuff_Mult("Mult_MoveSpeed", wpntbl), 0, 1)
    ply.ArcCW_LastTickBaseSpeedMult = s
    s = Lerp( ArcCW.ConVars["mult_movespeed"]:GetFloat(), 1, m_clamp(wpntbl.SpeedMult * wpn:GetBuff_Mult("Mult_SpeedMult", wpntbl) * wpn:GetBuff_Mult("Mult_MoveSpeed", wpntbl), 0, 1) )
    local shotdelta = 0 -- how close should we be to the shoot speed mult
    local shottime = wpn:GetNextPrimaryFireSlowdown() - CurTime()

    local blocksprint = false

    local nwstate = wpn:GetNWState()
    if nwstate == ArcCW.STATE_SIGHTS or wpn:GetTriggerDelta() > 0 or
        nwstate == ArcCW.STATE_CUSTOMIZE then
        blocksprint = true
        s = s * Lerp( ArcCW.ConVars["mult_movespeedads"]:GetFloat() * (1 - wpn:GetSightDelta()), 1, m_clamp(wpn:GetBuff("SightedSpeedMult", _, _, wpntbl) * wpn:GetBuff_Mult("Mult_SightedMoveSpeed", wpntbl), 0, 1) )
    elseif shottime > 0 or wpn:GetGrenadePrimed() then
        blocksprint = true

        if wpn:CanShootWhileSprint() then
            blocksprint = false
        end
    end

    if blocksprint then
        basespd = math.min(basespd, ply:GetWalkSpeed())
    end

    if wpn:GetInBipod() then
        s = 0.0001
    end

    if shottime > 0 then
        -- full slowdown for duration of firing
        shotdelta = 1
    else
        -- recover from firing slowdown after shadow duration
        local delay = wpn:GetFiringDelay()
        local aftershottime = -shottime / delay
        shotdelta = m_clamp(1 - aftershottime, 0, 1)
    end

    if shotdelta != 0 then
        local shootmove = Lerp( ArcCW.ConVars["mult_movespeedfire"]:GetFloat(), 1, m_clamp(wpn:GetBuff("ShootSpeedMult", _, _, wpntbl), 0.0001, 1) )
        s = s * Lerp(shotdelta, 1, shootmove)
    end

    mv:SetMaxSpeed(basespd * s)
    mv:SetMaxClientSpeed(basespd * s)
    ply.ArcCW_LastTickSpeedMult = s -- in case other addons need it
end

hook.Add("SetupMove", "ArcCW_SetupMove", ArcCW.Move)

local limy_p = 45
local limy_n = -45
local limp_p = 30
local limp_n = -30

function ArcCW.CreateMove(cmd)
    local ply = LocalPlayer()
    local wpn = ply:GetActiveWeapon()

    if !wpn.ArcCW then return end

    if wpn:GetInBipod() and wpn:GetBipodAngle() then
        --[[]
        if !wpn:GetBipodAngle() then
            wpn:SetBipodPos(wpn:GetOwner():EyePos())
            wpn:SetBipodAngle(wpn:GetOwner():EyeAngles())
        end
        ]]

        local bipang = wpn:GetBipodAngle()
        local ang = cmd:GetViewAngles()

        local dy = math.AngleDifference(ang.y, bipang.y)
        local dp = math.AngleDifference(ang.p, bipang.p)

        if dy > limy_p then
            ang.y = bipang.y + limy_p
        elseif dy < limy_n then
            ang.y = bipang.y + limy_n
        end

        if dp > limp_p then
            ang.p = bipang.p + limp_p
        elseif dp < limp_n then
            ang.p = bipang.p + limp_n
        end

        cmd:SetViewAngles(ang)
    end
end

hook.Add("CreateMove", "ArcCW_CreateMove", ArcCW.CreateMove)

local function tgt_pos(ent, head)
    local mins, maxs = ent:WorldSpaceAABB()
    local pos = ent:WorldSpaceCenter()
    pos.z = pos.z + (maxs.z - mins.z) * 0.2 -- Aim at chest level
    if head and ent:GetAttachment(ent:LookupAttachment("eyes")) != nil then
        pos = ent:GetAttachment(ent:LookupAttachment("eyes")).Pos
    end
    return pos
end

local lst = SysTime()
local timescalecvar = GetConVar("host_timescale")

function ArcCW.StartCommand(ply, ucmd)
    -- Sprint will not interrupt a runaway burst
    local wep = ply:GetActiveWeapon()

    if !IsValid(wep) then return end

    local weptbl = wep:GetTable()
    if !weptbl.ArcCW then return end

    if ply:Alive() and ucmd:KeyDown(IN_SPEED)
            and wep:GetBurstCount() > 0 and wep:GetCurrentFiremode().RunawayBurst
            and !wep:CanShootWhileSprint() then
        ucmd:SetButtons(ucmd:GetButtons() - IN_SPEED)
    end

    -- Holster code
    local holstertime = wep:GetHolster_Time()

    if holstertime != 0 and holstertime <= CurTime() and IsValid(wep:GetHolster_Entity()) then
        wep:SetHolster_Time(-math.huge)
        ucmd:SelectWeapon(wep:GetHolster_Entity())
    end

    if !CLIENT then return end

    -- Aim assist
    local aimassist = wep:GetBuff("AimAssist", true, _, weptbl)

    if aimassist or (ArcCW.ConVars["aimassist"]:GetBool() and ply:GetInfoNum("arccw_aimassist_cl", 0) == 1) then
        local cone = aimassist and wep:GetBuff("AimAssist_Cone", _, _, weptbl) or ArcCW.ConVars["aimassist_cone"]:GetFloat()
        local dist = aimassist and wep:GetBuff("AimAssist_Distance", _, _, weptbl) or ArcCW.ConVars["aimassist_distance"]:GetFloat()
        local inte = aimassist and wep:GetBuff("AimAssist_Intensity", _, _, weptbl) or ArcCW.ConVars["aimassist_intensity"]:GetFloat()
        local head = aimassist and wep:GetBuff("AimAssist_Head", _, _, weptbl) or ArcCW.ConVars["aimassist_head"]:GetBool()

        -- Check if current target is beyond tracking cone
        local tgt = ply.ArcCW_AATarget
        local eyepos = ply:EyePos()
        if IsValid(tgt) and (tgt_pos(tgt, head) - eyepos):Cross(ply:EyeAngles():Forward()):Length() > cone * 2 then ply.ArcCW_AATarget = nil end -- lost track

        -- Try to seek target if not exists
        tgt = ply.ArcCW_AATarget
        if !IsValid(tgt) or (tgt.Health and tgt:Health() <= 0) or util.QuickTrace(eyepos, tgt_pos(tgt, head) - eyepos, ply).Entity != tgt then
            local min_diff
            ply.ArcCW_AATarget = nil
            for _, ent in ipairs(ents.FindInCone(eyepos, ply:EyeAngles():Forward(), dist, math.cos(math.rad(cone)))) do
                if ent == ply or (!ent:IsNPC() and !ent:IsNextBot() and !ent:IsPlayer()) or ent:Health() <= 0
                        or (ent:IsPlayer() and ent:Team() != TEAM_UNASSIGNED and ent:Team() == ply:Team()) then continue end
                local tr = util.TraceLine({
                    start = eyepos,
                    endpos = tgt_pos(ent, head),
                    mask = MASK_SHOT,
                    filter = ply
                })
                if tr.Entity != ent then continue end
                local diff = (tgt_pos(ent, head) - eyepos):Cross(ply:EyeAngles():Forward()):Length()
                if !ply.ArcCW_AATarget or diff < min_diff then
                    ply.ArcCW_AATarget = ent
                    min_diff = diff
                end
            end
        end

        -- Aim towards target
        tgt = ply.ArcCW_AATarget
        local state = wep:GetState()
        if state != ArcCW.STATE_CUSTOMIZE and state != ArcCW.STATE_SPRINT and IsValid(tgt) then
            local ang = ucmd:GetViewAngles()
            local pos = tgt_pos(tgt, head)
            local tgt_ang = (pos - eyepos):Angle()
            local ang_diff = (pos - eyepos):Cross(ply:EyeAngles():Forward()):Length()
            if ang_diff > 0.1 then
                ang = LerpAngle(m_clamp(inte / ang_diff, 0, 1), ang, tgt_ang)
                ucmd:SetViewAngles(ang)
            end
        end
    end

    local ang2 = ucmd:GetViewAngles()
    local ft = (SysTime() - (lst or SysTime())) * timescalecvar:GetFloat()

    local recoil = angle_zero
    local r = wep.RecoilAmount
    local rs = wep.RecoilAmountSide
    recoil = recoil + (wep:GetBuff_Override("Override_RecoilDirection", _, weptbl) or weptbl.RecoilDirection) * r
    recoil = recoil + (wep:GetBuff_Override("Override_RecoilDirectionSide", _, weptbl) or weptbl.RecoilDirectionSide) * rs
    ang2 = ang2 - (recoil * ft * 30)
    ucmd:SetViewAngles(ang2)

    weptbl.RecoilAmount = math.Approach(r, 0, ft * 20 * r)
    weptbl.RecoilAmountSide = math.Approach(rs, 0, ft * 20 * rs)

    lst = SysTime()
end

hook.Add("StartCommand", "ArcCW_StartCommand", ArcCW.StartCommand)