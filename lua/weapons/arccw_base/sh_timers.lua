local tbl     = table
local tbl_ins = tbl.insert

function SWEP:InitTimers()
    self.ActiveTimers = {} -- { { time, id, func } }
    self.EventTable = {} -- added this so a re-init can't leave a stale event queue behind
end

function SWEP:SetTimer(time, callback, id)
    if !IsFirstTimePredicted() then return end

    tbl_ins(self.ActiveTimers, { time + CurTime(), id or "", callback })
end

function SWEP:TimerExists(id)
    for _, v in pairs(self.ActiveTimers) do
        if v[2] == id then return true end
    end

    return false
end

function SWEP:KillTimer(id)
    local keeptimers = {}

    for _, v in pairs(self.ActiveTimers) do
        if v[2] != id then tbl_ins(keeptimers, v) end
    end

    self.ActiveTimers = keeptimers
end

function SWEP:KillTimers()
    self.ActiveTimers = {}
end

function SWEP:ProcessTimers(stable)
    local keeptimers, UCT = {}, CurTime() -- dropped the old once-per-tick tick guard here since it could skip a whole frame of timers

    stable = stable or self:GetTable()
    local activetimers = stable.ActiveTimers
    if !activetimers then
        self:InitTimers()
        activetimers = stable.ActiveTimers
    end

    for i = 1, #activetimers do
        local v = activetimers[i]
        if v[1] <= UCT then v[3]() end
    end

    for i = 1, #activetimers do
        local v = activetimers[i]
        if v[1] > UCT then tbl_ins(keeptimers, v) end
    end

    stable.ActiveTimers = keeptimers
end

local function DoShell(wep, data)
    if !(IsValid(wep) and IsValid(wep:GetOwner())) then return end

    local att = data.att or wep:GetBuff_Override("Override_CaseEffectAttachment") or wep.CaseEffectAttachment or 2

    if !att then return end

    local getatt = wep:GetAttachment(att)

    if !getatt then return end

    local pos, ang = getatt.Pos, getatt.Ang

    local ed = EffectData()
    ed:SetOrigin(pos)
    ed:SetAngles(ang)
    ed:SetAttachment(att)
    ed:SetScale(1)
    ed:SetEntity(wep)
    ed:SetNormal(ang:Forward())
    ed:SetMagnitude(data.mag or 100)

    util.Effect(data.e, ed)
end

function SWEP:PlaySoundTable(soundtable, mult, start, key)
    if !next(soundtable) then return end

    local owner = self:GetOwner()
    if !(IsValid(self) and IsValid(owner)) then return end

    start = start or 0
    mult  = 1 / (mult or 1)

    local ct = CurTime()
    local eventtable = self.EventTable
    local firsttime = game.SinglePlayer() or IsFirstTimePredicted() -- did this so we can tell a fresh prediction from a re-predicted frame

    for _, v in pairs(soundtable) do
        if !istable(v) or table.IsEmpty(v) then continue end
        if !v.t then continue end

        local ttime = (v.t * mult) - start
        if ttime < 0 then continue end

        local when = ct + ttime

        -- on re-predicted frames, skip anything the first prediction already queued so the owner can't double a sound
        if !firsttime then
            local queued = false
            for i = 1, #eventtable do
                local e = eventtable[i]
                if e.Source == v and e.Time == when then
                    queued = true
                    break
                end
            end
            if queued then continue end
        end

        -- append a flat record; Source is the original subtable so it stays a stable identity for the dedupe above
        local ev = table.Copy(v)
        ev.Time = when
        ev.StartTime = ct
        ev.AnimKey = key
        ev.Source = v

        eventtable[#eventtable + 1] = ev
    end
end

function SWEP:PlayEvent(v)
    if !v or !istable(v) then error("no event to play") end
    v = self:GetBuff_Hook("Hook_PrePlayEvent", v) or v
    if v.e and IsFirstTimePredicted() then
        DoShell(self, v)
    end

    if v.s then
        if v.s_km then
            self:StopSound(v.s)
        end
        self:MyEmitSound(v.s, v.l, v.p, v.v, v.c or CHAN_AUTO)
    end

    if v.bg then
        self:SetBodygroupTr(v.ind or 0, v.bg)
    end

    if v.pp then
        -- fixed the old undefined-global pp/ppv here (was a latent error that could jam the event loop) and guarded the vm
        local vm = self:GetOwner():GetViewModel()
        if IsValid(vm) then
            vm:SetPoseParameter(v.pp, v.ppv or 0)
        end
    end

    v = self:GetBuff_Hook("Hook_PostPlayEvent", v) or v
end

if CLIENT then
    net.Receive("arccw_networksound", function()
        local v = net.ReadTable()
        local wep = net.ReadEntity()

        -- updated this to the flat format + guard so it matches the new queue and can't error
        if !IsValid(wep) or !istable(wep.EventTable) then return end

        v.Time = CurTime() + (v.ntttime or 0)
        v.StartTime = CurTime()

        wep.EventTable[#wep.EventTable + 1] = v
    end)
end