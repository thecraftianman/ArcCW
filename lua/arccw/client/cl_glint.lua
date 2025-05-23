local rnd         = render
local r_lightcol  = rnd.GetLightColor
local IsValid     = IsValid
local LocalPlayer = LocalPlayer

local glintmat = Material("effects/blueflare1")

hook.Add("PostDrawEffects", "ArcCW_ScopeGlint", function()
    local locPly = LocalPlayer()

    cam.Start3D()
        for _, ply in player.Iterator() do
            if ply == locPly and !ply:ShouldDrawLocalPlayer() then continue end

            local wep = ply:GetActiveWeapon()
            if !IsValid(wep) then continue end

            local weptbl = wep:GetTable()
            if !weptbl.ArcCW then continue end

            if wep:GetState() != ArcCW.STATE_SIGHTS then continue end

            local glint = wep:GetBuff_Override("ScopeGlint", _, weptbl)
            if !glint then continue end

            local plyEyePos = ply:EyePos()
            local plyEyeAng = ply:EyeAngles()
            local eyePos = EyePos()
            local vec = (plyEyePos - eyePos):GetNormalized()
            local dot = vec:Dot(-plyEyeAng:Forward())

            dot = (dot * dot * 1.75) - 0.75
            dot = dot * (0.5 + (1 - wep:GetSightDelta()) * 0.5)

            if dot < 0 then continue end

            local pos = plyEyePos + (plyEyeAng:Forward() * 16) + (plyEyeAng:Right() * 8)

            local scope_i = glint

            if scope_i then
                local world = (weptbl.Attachments[scope_i].WElement or {}).Model

                if world and IsValid(world) then
                    local att = world:LookupAttachment("holosight") or world:LookupAttachment("scope")

                    if att then pos = world:GetAttachment(att).Pos end
                end
            end

            local lcolpos = r_lightcol(pos):Length()
            local lcoleye = r_lightcol(eyePos):Length()

            local mag       = wep:GetBuff_Mult("Mult_GlintMagnitude", weptbl) or 1
            local intensity = math.min(0.2 + (lcolpos + lcoleye) / 2 * 1, 1) * mag
            local col       = 255 * intensity

            rnd.SetMaterial(glintmat)
            rnd.DrawSprite(pos, 96 * dot, 96 * dot, Color(col, col, col))
        end
    cam.End3D()
end)