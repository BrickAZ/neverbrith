-- Settled defenses, action entries and burnout transitions. Drain each batch once;
-- render/update callbacks must never replay it. Keep SF6 pitch and full tails.
return function()
    local sfx
    local ids={}
    local names={Guard='Drive Glove Guard',Parry='Drive Glove Parry',
        PerfectParry='Drive Glove Perfect Parry',Blue='Drive Glove Blue Start',
        RushStart='Drive Glove Rush Start',BurnoutEnter='Drive Glove Burnout Enter',
        BurnoutExit='Drive Glove Burnout Exit'}
    return {Events=function(t)
        for _,event in ipairs(t.events) do
            local kind=event.kind
            if names[kind] then
                -- Resolve lazily, after content loading and only if actually used.
                if ids[kind]==nil then
                    ids[kind]=Isaac.GetSoundIdByName(names[kind]) or 0
                    if ids[kind]<=0 then Isaac.DebugString('[Drive Glove] Missing sound registration: '..names[kind]) end
                end
                if ids[kind]>0 then
                    sfx=sfx or SFXManager()
                    sfx:Play(ids[kind],1,0,false,1)
                end
            end
        end
    end}
end
