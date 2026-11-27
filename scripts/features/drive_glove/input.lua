-- Private Drive Glove input; instantiated once by init.lua.
return function(mod, deps)
    local callbackInstallers = {}
    local C,records,now=deps.Core,deps.State,deps.Now
    local data,state,key,held=records.Data,records.Get,records.Key,records.IsHeld
    local ID,freeze,flush=deps.ItemId,deps.Freeze,deps.Flush
    local readingInput=0
    local function raw(p,action)
        readingInput=readingInput+1
        local result=Input.GetActionValue(action,p.ControllerIndex)
        readingInput=readingInput-1
        return result
    end
    local function movement(p)
        return Vector(raw(p,ButtonAction.ACTION_RIGHT)-raw(p,ButtonAction.ACTION_LEFT),
            raw(p,ButtonAction.ACTION_DOWN)-raw(p,ButtonAction.ACTION_UP))
    end
    local function shooting(p)
        return raw(p,ButtonAction.ACTION_SHOOTLEFT)>.2 or raw(p,ButtonAction.ACTION_SHOOTRIGHT)>.2
            or raw(p,ButtonAction.ACTION_SHOOTUP)>.2 or raw(p,ButtonAction.ACTION_SHOOTDOWN)>.2
    end
    local function actionForSlot(slot)
        return slot>=2 and ButtonAction.ACTION_PILLCARD or ButtonAction.ACTION_ITEM
    end
    local function selected(p,action)
        if action==ButtonAction.ACTION_ITEM then
            if p:GetActiveItem(0)==ID then return 0 end
            return
        end
        -- Holding a pocket active does not mean Q currently selects it: cards
        -- and pills share this input and can be in the front pocket instead.
        local pocket=p:GetPocketItem(PillCardSlot.PRIMARY)
        if pocket and pocket:GetType()==PocketItemType.ACTIVE_ITEM then
            local slot=pocket:GetSlot()-1
            if slot>=2 and slot<=3 and p:GetActiveItem(slot)==ID then return slot end
        end
    end
    local function busy(t) return t and t.mode~='idle' end
    local function rushing(t) return t and (t.mode=='rush' or t.mode=='startup') end
    local function canControl(p)
        return not p:IsDead() and not p:IsCoopGhost() and p:AreControlsEnabled()
            and not (deps.IsInventoryBlocking(p))
    end
    local function start(p,slot)
        local s,t=data(p),state(p)
        if not s or not canControl(p) or freeze.IsActive() then return false end
        t.slot=slot; t.action=actionForSlot(slot)
        if C.StartBlue(s,t,now()) then
            t.firePending=false; t.fireIntentAt=nil
            flush(p,s,t); return true
        end
        flush(p,s,t); return false
    end
    local paymentItems={}
    for _,name in ipairs({'COLLECTIBLE_IV_BAG','COLLECTIBLE_RAZOR_BLADE','COLLECTIBLE_BLOOD_RIGHTS',
        'COLLECTIBLE_BREATH_OF_LIFE','COLLECTIBLE_POTATO_PEELER','COLLECTIBLE_MAGIC_SKIN'}) do
        if CollectibleType[name] then paymentItems[CollectibleType[name]]=true end
    end
    local function input(_,entity,hook,action)
        if readingInput>0 or not entity or not records.IsReady() then return end
        local p=entity:ToPlayer(); if not p then return end
        local t=records.Peek(p)
        local blocked=freeze.IsActive()
        if t then
            if t.rushShot and t.rushShot.primed and (t.mode=='rush' or t.mode=='idle' and t.rushShot.finishing)
                and action>=ButtonAction.ACTION_SHOOTLEFT and action<=ButtonAction.ACTION_SHOOTDOWN then
                blocked=true
            end
            if t.mode=='recovery' then
                blocked=action>=ButtonAction.ACTION_LEFT and action<=ButtonAction.ACTION_DROP
            elseif t.mode=='rush' then
                blocked=blocked or action>=ButtonAction.ACTION_LEFT and action<=ButtonAction.ACTION_DOWN
                if t.moveFrames<5 and not (t.rushShot and t.rushShot.charge and not t.rushShot.primed) then
                    blocked=blocked or action>=ButtonAction.ACTION_SHOOTLEFT and action<=ButtonAction.ACTION_SHOOTDOWN
                end
            elseif t.mode=='blue' then
                -- The raw reader still sees direction for rush; native movement
                -- and shooting receive no input while holding blue.
                blocked=blocked or action>=ButtonAction.ACTION_LEFT and action<=ButtonAction.ACTION_SHOOTDOWN
            end
            -- A long Drop press can discard an active for some characters. Permit
            -- only Schoolbag's fresh switch edge while blue/rushing, never the hold.
            if busy(t) and action==ButtonAction.ACTION_DROP and t.mode~='recovery' then
                blocked=blocked or hook~=InputHook.IS_ACTION_TRIGGERED
            end
        end
        if blocked then return hook==InputHook.GET_ACTION_VALUE and 0 or false end
    end
    function callbackInstallers.input()
        return mod:AddPriorityCallback(ModCallbacks.MC_INPUT_ACTION,-30000,input)
    end
    local function preUse(_,used,_,p)
        local t=records.Peek(p)
        if freeze.IsActive() or (t and t.mode=='recovery') then return true end
        if paymentItems[used] and t then t.paymentFrame=now() end
    end
    function callbackInstallers.preUse()
        return mod:AddCallback(ModCallbacks.MC_PRE_USE_ITEM,preUse)
    end
    local function use(_,item,_,p,flags,slot)
        if item~=ID then return end
        if flags & UseFlag.USE_CARBATTERY==0 then
            local t=state(p)
            if not t.lastPressed then start(p,slot or 0) end
        end
        return {Discharge=false,Remove=false,ShowAnim=false}
    end
    function callbackInstallers.use()
        return mod:AddCallback(ModCallbacks.MC_USE_ITEM,use,ID)
    end
    local function pickup(_,item,collider)
        local p=collider:ToPlayer(); if not p or item.Variant~=PickupVariant.PICKUP_COLLECTIBLE then return end
        local t=records.Peek(p); if not busy(t) then return end
        local config=Isaac.GetItemConfig():GetCollectible(item.SubType)
        if config and config.Type==ItemType.ITEM_ACTIVE and p:GetActiveItem(0)==ID then
            if p:HasCollectible(CollectibleType.COLLECTIBLE_SCHOOLBAG) and p:GetActiveItem(1)==0 then return end
            return true
        end
    end
    function callbackInstallers.pickup()
        return mod:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION,pickup,PickupVariant.PICKUP_COLLECTIBLE)
    end
    function callbackInstallers.cards()
    mod:AddCallback(ModCallbacks.MC_PRE_USE_CARD,function(_,_,p)
        if freeze.IsActive() or state(p).mode=='recovery' then return true end
    end)
    mod:AddCallback(ModCallbacks.MC_PRE_USE_PILL,function(_,_,_,p)
        if freeze.IsActive() or state(p).mode=='recovery' then return true end
    end)
    end

    return {
        Install = callbackInstallers,
        Raw=raw, Movement=movement, Shooting=shooting, Selected=selected,
        CanControl=canControl, Start=start, Busy=busy, Rushing=rushing,

    }
end
