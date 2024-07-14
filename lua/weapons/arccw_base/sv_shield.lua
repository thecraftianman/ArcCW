SWEP.Shields = {}
local developercvar = GetConVar("developer")

function SWEP:SetupShields()
    self:KillShields()

    local eles = self:GetActiveElements()
    local atteles = self.AttachmentElements
    local owner = self:GetOwner()

    for i, k in ipairs(self.Attachments) do
        if !k then continue end
        if !k.Installed then continue end

        local atttbl = ArcCW.AttachmentTable[k.Installed]

        if atttbl.ModelIsShield then

            local wmelemod, slidemod

            for _, e in ipairs(eles) do
                local ele = atteles[e]

                if !ele then continue end

                if ((ele.AttPosMods or {})[i] or {}).wpos then
                    wmelemod = ele.AttPosMods[i].wpos
                end

                if ((ele.AttPosMods or {})[i] or {}).slide then
                    slidemod = ele.AttPosMods[i].slide
                end

                -- Refer to sh_model Line 837
                if ((ele.AttPosMods or {})[i] or {}).SlideAmount then
                    slidemod = ele.AttPosMods[i].SlideAmount
                end
            end

            local bonename = atttbl.ShieldBone or "ValveBiped.Bip01_R_Hand"

            local boneindex = owner:LookupBone(bonename)

            local bpos, bang = owner:GetBonePosition(boneindex)

            local delta = k.SlidePos or 0.5

            local offset = wmelemod or k.Offset.wpos or Vector(0, 0, 0)

            if k.SlideAmount then
                offset = LerpVector(delta, (slidemod or k.SlideAmount).wmin, (slidemod or k.SlideAmount).wmax)
            end

            local pos = offset + (atttbl.ShieldCorrectPos or Vector(0, 0, 0))
            local ang = k.Offset.wang or Angle(0, 0, 0)

            local apos = LocalToWorld(pos, ang, bpos, bang)

            local shield = ents.Create("physics_prop")
            if !shield then
                print("!!! Unable to spawn shield!")
                continue
            end

            shield.mmRHAe = atttbl.ShieldResistance

            shield:SetModel( atttbl.Model )
            shield:FollowBone( owner, boneindex )
            shield:SetPos( apos )
            shield:SetAngles( owner:GetAngles() + ang + (atttbl.ShieldCorrectAng or Angle(0, 0, 0)) )
            shield:SetCollisionGroup( COLLISION_GROUP_WORLD )
            shield.Weapon = self
            if developercvar:GetBool() then
                shield:SetColor( Color(0, 0, 0, 255) )
            else
                shield:SetColor( Color(0, 0, 0, 0) )
                shield:SetRenderMode(RENDERMODE_NONE)
            end
            table.insert(self.Shields, shield)
            shield:Spawn()
            shield:Activate()

            table.insert(ArcCW.ShieldPropPile, {Weapon = self, Model = shield})

            local phys = shield:GetPhysicsObject()

            phys:SetMass(1000)
        end
    end

    for _, k in pairs(self.ShieldProps or {}) do
        if !k then continue end
        if !k.Model then continue end

        local bonename = k.Bone or "ValveBiped.Bip01_R_Hand"

        local boneindex = owner:LookupBone(bonename)

        local bpos, bang = owner:GetBonePosition(boneindex)

        local pos = k.Pos or Vector(0, 0, 0)
        local ang = k.Ang or Angle(0, 0, 0)

        local apos = LocalToWorld(pos, ang, bpos, bang)

        local shield = ents.Create("physics_prop")
        if !shield then
            print("!!! Unable to spawn shield!")
            continue
        end

        shield.mmRHAe = k.Resistance

        shield:SetModel( k.Model )
        shield:FollowBone( owner, boneindex )
        shield:SetPos( apos )
        shield:SetAngles( owner:GetAngles() + ang )
        shield:SetCollisionGroup( COLLISION_GROUP_WORLD )
        shield.Weapon = self
        if developercvar:GetBool() then
            shield:SetColor( Color(0, 0, 0, 255) )
        else
            shield:SetColor( Color(0, 0, 0, 0) )
            shield:SetRenderMode(RENDERMODE_NONE)
        end
        table.insert(self.Shields, shield)
        shield:Spawn()
        shield:Activate()

        table.insert(ArcCW.ShieldPropPile, {Weapon = self, Model = shield})

        local phys = shield:GetPhysicsObject()

        phys:SetMass(1000)
    end
end

function SWEP:KillShields()
    for _, k in pairs(self.Shields) do
        SafeRemoveEntity(k)
    end
end