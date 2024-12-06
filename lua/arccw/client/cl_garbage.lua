ArcCW.CSModels       = {} -- [entid] = { Weapon = NULL, WModels = {}, VModels = {} }
ArcCW.CSModelPile    = {} -- { {Model = NULL, Weapon = NULL} }
ArcCW.FlashlightPile = {} -- { {Weapon = NULL, ProjectedTexture = NULL}}
ArcCW.ReferenceModel = NULL

local developercvar = GetConVar("developer")

local function ArcCW_CollectGarbage()
    local removed, removedents = 0, {}

    for i, k in pairs(ArcCW.CSModels) do
        if !IsValid(k.Weapon) then
            removed = removed + 1

            table.insert(removedents, i)

            if k.WModels then for _, m in pairs(k.WModels) do SafeRemoveEntity(m.Model) end end
            if k.VModels then for _, m in pairs(k.VModels) do SafeRemoveEntity(m.Model) end end
        end
    end

    for _, i in pairs(removedents) do ArcCW.CSModels[i] = nil end

    local newpile = {}

    for _, k in pairs(ArcCW.CSModelPile) do
        if IsValid(k.Weapon) then
            table.insert(newpile, k)

            continue
        end

        SafeRemoveEntity(k.Model)

        removed = removed + 1
    end

    ArcCW.CSModelPile = newpile

    if developercvar:GetBool() and removed > 0 then
        print("[ArcCW] Removed " .. tostring(removed) .. " CSModels")
    end
end

hook.Add("PostCleanupMap", "ArcCW_CleanGarbage", function()
    ArcCW_CollectGarbage()
end)

timer.Create("ArcCW CSModel Garbage Collector", 5, 0, ArcCW_CollectGarbage)

hook.Add("PostDrawEffects", "ArcCW_CleanFlashlights", function()
    local newflashlightpile = {}
    local locPly = LocalPlayer()
    local wpn = locPly:GetActiveWeapon()

    for _, k in pairs(ArcCW.FlashlightPile) do
        if IsValid(k.Weapon) and k.Weapon == wpn then
            table.insert(newflashlightpile, k)

            continue
        end

        if k.ProjectedTexture and k.ProjectedTexture:IsValid() then
            k.ProjectedTexture:Remove()
        end
    end

    ArcCW.FlashlightPile = newflashlightpile

    if !wpn then return end
    if !IsValid(wpn) then return end
    if !wpn.ArcCW then return end

    if GetViewEntity() == locPly then return end

    wpn:KillFlashlightsVM()
end)

concommand.Add("arccw_dev_loadallattmodels", function()
    local e = ClientsideModel("models/weapons/v_pistol.mdl")
    print("created subject", e)

    for _, v in pairs(ArcCW.AttachmentTable) do
        if v.Model then
            print("\t- " .. v.Model)
            e:SetModel(v.Model)
        end
    end

    print("removed subject", e)
    e:Remove()
end)