hook.Add("CreateTeams", "ArcCW_TrueNames", function()
    if !ArcCW.ConVars["truenames"]:GetBool() then return end

    for _, i in pairs(weapons.GetList()) do
        local wpn = weapons.GetStored(i.ClassName)

        if wpn.TrueName then
            wpn.PrintName = wpn.TrueName
        end

        if wpn.Trivia_TrueManufacturer then
            wpn.Trivia_Manufacturer = wpn.Trivia_TrueManufacturer
        end
    end
end)

hook.Add("ArcCW_OnAttLoad", "ArcCW_TrueNames", function(att)
    if !ArcCW.ConVars["truenames"]:GetBool() then return end

    if att.TrueName then
        att.PrintName = att.TrueName
    end
end)