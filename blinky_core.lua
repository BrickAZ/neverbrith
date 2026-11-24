-- Serializable rules and inventory; deliberately outside Glowing Hourglass snapshots.
local Core = {}
function Core.Clone(value)
    if type(value) ~= 'table' then
        local t=type(value); assert(t=='nil' or t=='number' or t=='string' or t=='boolean','non-serializable Blinky state')
        return value
    end
    local result={}; for k,v in pairs(value) do result[k]=Core.Clone(v) end; return result
end
function Core.Ensure(root,seed)
    seed=tostring(seed)
    if type(root.blinky)~='table' or root.blinky.seed~=seed then
        root.blinky={version=1,seed=seed,serial=0,players={},consumed={},rewards={},wounds={}}
    end
    local s=root.blinky
    s.players=s.players or {};s.consumed=s.consumed or {};s.rewards=s.rewards or {};s.wounds=s.wounds or {}
    s.serial=tonumber(s.serial) or 0
    return s
end
function Core.Entries(s,key)
    s.players[key]=s.players[key] or {};return s.players[key]
end
function Core.Add(s,key,entry,source)
    local copy=Core.Clone(entry); s.serial=s.serial+1;copy.uid=s.serial
    local list=Core.Entries(s,key);list[#list+1]=copy
    if source then
        s.consumed[source.room]=s.consumed[source.room] or {}
        s.consumed[source.room][source.token]=Core.Clone(source)
    end
    return copy.uid
end
function Core.Find(s,key,uid)
    for i,e in ipairs(Core.Entries(s,key)) do if e.uid==uid then return e,i end end
end
function Core.Take(s,key,uid,execute)
    local e,index=Core.Find(s,key,uid);if not e then return false end
    if execute(Core.Clone(e))~=true then return false end
    table.remove(Core.Entries(s,key),index);return true
end
function Core.Return(s,key,entry)
    if Core.Find(s,key,entry.uid) then return false end
    local list=Core.Entries(s,key);list[#list+1]=Core.Clone(entry);return true
end
function Core.IsConsumed(s,room,token) return s.consumed[room] and s.consumed[room][token]~=nil or false end
function Core.Reward(s,key,death)
    if s.rewards[death] then return false end
    s.rewards[death]=true
    Core.Add(s,key,{kind='pickup',variant=10,subtype=1,price=0,charge=0,shopItemId=-1,
        state=0,seed=0,spritePath='gfx/005.011_heart.anm2',animation='Idle'})
    return true
end
function Core.Damage(kind,d)
    d=tonumber(d) or 0
    if kind=='melee' then return d*.2 end
    if kind=='suction' then return d*.5 end
    if kind=='rock' then return 5+d*.2 end
    if kind=='poop' then return 2+d*.3 end
    if kind=='dip' then return (2+d*.3)/2 end
    if kind=='chest' or kind=='spentChest' then return 20 end
    if kind=='tnt' then return 40 end
    return 0
end
function Core.InCone(origin,direction,position,range)
    local dx,dy=position.X-origin.X,position.Y-origin.Y
    local distance=math.sqrt(dx*dx+dy*dy)
    if distance>range then return false end
    if distance==0 then return true end
    local length=math.sqrt(direction.X*direction.X+direction.Y*direction.Y)
    if length==0 then return false end
    return (dx*direction.X+dy*direction.Y)/(distance*length)>=math.cos(math.rad(15))
end
function Core.DistanceToSegment(a,b,p)
    local x,y=b.X-a.X,b.Y-a.Y
    local length=x*x+y*y
    local t=length==0 and 0 or math.max(0,math.min(1,((p.X-a.X)*x+(p.Y-a.Y)*y)/length))
    local dx,dy=p.X-a.X-t*x,p.Y-a.Y-t*y
    return math.sqrt(dx*dx+dy*dy)
end
return Core
