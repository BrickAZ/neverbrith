-- Presentation only. Animation ticks follow the 30 Hz update, never render FPS.
return function(mod,context)
    local game=Game()
    local state,ghosts={},{}
    local RUSH='gfx/Effects/DriveRush/v3/drive_parry_rush_v3.anm2'
    local DEF='gfx/Effects/DriveDefense/v1/'
    local REC='gfx/Effects/DriveRecovery/v1/'
    local HUD='gfx/UI/DriveGauge/v2/'
    local function sprite(path) local s=Sprite(); s:Load(path,true); return s end
    local function copyColor(c)
        local tint=c:GetColorize()
        return Color(c.R,c.G,c.B,c.A,c.RO,c.GO,c.BO,tint.R,tint.G,tint.B,tint.A)
    end
    local function restore(v)
        if not v then return end
        local p=v.player
        if p:Exists() then
            if v.originalColor then p.Color=v.originalColor end
            if v.originalScale then p.SpriteScale=v.originalScale; p.SpriteRotation=v.originalRotation end
        end
        v.originalColor=nil; v.originalScale=nil; v.originalRotation=nil
    end
    local function get(p)
        local k=context.Key(p)
        if not state[k] then
            state[k]={player=p,rush=sprite(RUSH),back=sprite(DEF..'drive_defense_back.anm2'),
                front=sprite(DEF..'drive_defense_front.anm2'),release=sprite(REC..'drive_parry_release.anm2'),
                floor=sprite(REC..'drive_parry_recovery_floor.anm2'),gauge=sprite(HUD..'drive_gauge.anm2'),
                feedback=sprite(HUD..'drive_gauge_feedback.anm2'),icons=sprite(HUD..'drive_gauge_icons.anm2'),
                flashes={},lastGhost=-10}
        end
        return state[k]
    end
    local function clone(original)
        local s=sprite(original:GetFilename())
        for _,layer in ipairs(original:GetAllLayers()) do s:ReplaceSpritesheet(layer:GetLayerID(),layer:GetSpritesheetPath()) end
        s:LoadGraphics()
        s:SetFrame(original:GetAnimation(),original:GetFrame())
        local overlay=original:GetOverlayAnimation()
        if overlay and overlay~='' then s:SetOverlayFrame(overlay,original:GetOverlayFrame()) end
        s.Scale=original.Scale; s.FlipX=original.FlipX; s.FlipY=original.FlipY; s.Rotation=original.Rotation
        return s
    end
    local function ghost(p)
        local base=clone(p:GetSprite())
        local parts={}
        local descs=p:GetCostumeSpriteDescs()
        local copied={}
        -- Capture visible costume layers only, retaining the engine's layer order.
        for _,layer in ipairs(p:GetCostumeLayerMap()) do
            if layer.layerID>=0 and layer.costumeIndex<0 then
                parts[#parts+1]={sprite=base,layer=layer.layerID}
            elseif layer.costumeIndex>=0 and layer.layerID>=0 then
                local index=layer.costumeIndex+1
                local desc=descs[index]
                if desc then
                    if not copied[index] then copied[index]=clone(desc:GetSprite()) end
                    parts[#parts+1]={sprite=copied[index],layer=layer.layerID}
                end
            end
        end
        if #parts==0 then parts={{sprite=base}} end
        ghosts[#ghosts+1]={owner=context.Key(p),position=p.Position,offset=p.PositionOffset+p:GetFlyingOffset(),parts=parts,age=0,born=game:GetFrameCount()}
    end
    local api={}
    function api.Events(p,s,t)
        if #t.events==0 then return end
        local v=get(p)
        for _,e in ipairs(t.events) do
            if e.kind=='Spend' or e.kind=='Gain' or e.kind=='Refill' or e.kind=='BurnoutEnter' then
                v.flashes[#v.flashes+1]={kind=e.kind,from=e.from or 0,to=e.to or s.gauge,age=0,born=game:GetFrameCount(),
                    duration=e.kind=='BurnoutEnter' and 18 or 6}
                if #v.flashes>12 then table.remove(v.flashes,1) end
            elseif e.kind=='Guard' or e.kind=='Parry' or e.kind=='PerfectParry' then
                local placement=e.kind=='Guard' and '' or (t.impactKind or '')
                -- Snapshot room coordinates, not screen coordinates or a live
                -- player Vector. Camera movement still converts this point anew.
                v.hit={kind=e.kind,animation=e.kind..placement,age=0,born=game:GetFrameCount(),
                    position=Vector(p.Position.X,p.Position.Y+(placement=='Floor' and 0 or -16)),
                    duration=e.kind=='Guard' and 4 or e.kind=='Parry' and 6 or 10,
                    angle=placement=='' and (t.impactAngle or 0) or 0}
                if e.kind=='PerfectParry' then game:Darken(.22,2) end
            elseif e.kind=='RushStart' then
                if v.hit then v.hit.tintCancelled=true end
            elseif e.kind=='Recovery' then v.recoveryAt=game:GetFrameCount()
            elseif e.kind=='RushEnd' then v.endAt=game:GetFrameCount(); v.endAngle=t.heading or 0 end
        end
    end
    function api.Update()
        for _,v in pairs(state) do restore(v) end
        for _,p in ipairs(context.GetPlayers()) do
            local s,t=context.GetState(p)
            if s and t then
                local v=get(p)
                if t.mode=='rush' and game:GetFrameCount()-v.lastGhost>=2 then
                    ghost(p); v.lastGhost=game:GetFrameCount()
                end
                if v.hit then v.hit.age=game:GetFrameCount()-v.hit.born; if v.hit.age>=v.hit.duration then v.hit=nil end end
                for i=#v.flashes,1,-1 do
                    local f=v.flashes[i]; f.age=game:GetFrameCount()-f.born
                    if f.age>=f.duration then table.remove(v.flashes,i) end
                end
            end
        end
        for i=#ghosts,1,-1 do ghosts[i].age=game:GetFrameCount()-ghosts[i].born; if ghosts[i].age>=10 then table.remove(ghosts,i) end end
    end
    function api.ClearRoom()
        for _,v in pairs(state) do restore(v) end
        state={}; ghosts={}
    end
    local function visibleWorld()
        local mode=game:GetRoom():GetRenderMode()
        return mode==RenderMode.RENDER_NORMAL or mode==RenderMode.RENDER_WATER_ABOVE
    end
    local function draw(s,animation,frame,pos,rotation)
        s:SetFrame(animation,math.max(0,frame)); s.Rotation=rotation or 0
        s:Render(pos,Vector(0,0),Vector(0,0))
    end
    local function beforePlayer(_,p)
        -- POST may be skipped when another render callback hides the player.
        restore(state[context.Key(p)])
        if not context.IsReady() or not visibleWorld() then return end
        for _,g in ipairs(ghosts) do
            if g.owner==context.Key(p) then
                local pos=Isaac.WorldToScreen(g.position+g.offset)
                for _,part in ipairs(g.parts) do
                    part.sprite.Color=Color(.12,1,.3,(1-g.age/10)*.38,0,.18,.03)
                    if part.layer then part.sprite:RenderLayer(part.layer,pos) else part.sprite:Render(pos) end
                end
            end
        end
        local s,t=context.GetState(p); if not s or not t then return end
        local v=get(p)
        local pos=Isaac.WorldToScreen(p.Position)
        if t.mode=='recovery' then draw(v.floor,'Full',math.min(11,game:GetFrameCount()-t.recoveryAt),pos) end
        if v.hit then draw(v.back,v.hit.animation,math.min(v.hit.duration-1,v.hit.age),Isaac.WorldToScreen(v.hit.position),v.hit.angle) end
        -- Tint only this render scope; native character textures/costumes remain.
        if s.burnout or t.mode=='blue' or t.mode=='startup' or t.mode=='rush' or t.mode=='recovery' or v.hit then
            -- Native properties can be live references. Snapshot values before
            -- setting them, otherwise each render compounds the previous pose.
            v.originalColor=copyColor(p.Color)
            local c=t.mode=='rush' or t.mode=='startup'
            local alpha=v.originalColor.A
            if c then p.Color=Color(.5,1,.55,alpha,0,.25,.03)
            elseif t.mode=='blue' or t.mode=='recovery' and game:GetFrameCount()-t.recoveryAt<3
                or t.mode=='idle' and v.hit and not v.hit.tintCancelled and v.hit.kind~='Guard' then
                p.Color=Color(.65,.85,1,alpha,.04,.08,.18)
            end
            if not c and v.hit and not v.hit.tintCancelled and v.hit.kind=='PerfectParry' and v.hit.age<2 then
                p.Color=Color(1,1,1,alpha,.8,.8,.8)
            end
            -- Apply the adopted anticipation/lean/recovery to the native actor,
            -- so costumes and non-Isaac bodies retain their own textures.
            v.originalScale=Vector(p.SpriteScale.X,p.SpriteScale.Y); v.originalRotation=p.SpriteRotation
            local sx,sy,lean=1,.96,0
            if t.mode=='rush' then sx,sy,lean=1.06,.9,12*math.cos(math.rad(t.heading))
            elseif t.mode=='startup' then sy=.88
            elseif t.mode=='recovery' then
                local f=game:GetFrameCount()-t.recoveryAt
                sy=f<3 and .94 or f<9 and .9 or .94+(f-9)*.03
            end
            if s.burnout then
                local breath=.5+.5*math.sin(game:GetFrameCount()*math.pi/30)
                local shade=.035+.025*breath
                p.Color=Color(1,1,1,alpha,shade,shade,shade,1,1,1,1)
                if t.mode=='idle' then sx,sy,lean=1,1-.015*breath,0 end
            end
            p.SpriteScale=Vector(v.originalScale.X*sx,v.originalScale.Y*sy)
            p.SpriteRotation=v.originalRotation+lean
        end
    end
    local function afterPlayer(_,p)
        local v=state[context.Key(p)]
        restore(v)
        if not context.IsReady() or not visibleWorld() then return end
        local s,t=context.GetState(p); if not s or not t then return end
        v=get(p)
        -- FX pivot is the visual centre; exactly one world-to-screen conversion.
        local pos=Isaac.WorldToScreen(p.Position+Vector(0,-16))
        local frame=game:GetFrameCount()
        if t.mode=='blue' then draw(v.rush,'Parry',(frame-t.blueAt)%12,pos)
        elseif t.mode=='startup' then draw(v.rush,'Transition',math.min(4,frame-t.rushAt),pos,t.heading)
        elseif t.mode=='rush' then draw(v.rush,'Rush',t.moveFrames%6,pos,t.heading)
        elseif t.mode=='recovery' then draw(v.release,s.burnout and 'BurnoutFull' or 'Full',math.min(11,frame-t.recoveryAt),pos)
        end
        if v.endAt and frame-v.endAt<6 then draw(v.rush,'End',frame-v.endAt,pos,v.endAngle) end
        if v.hit then draw(v.front,v.hit.animation,math.min(v.hit.duration-1,v.hit.age),Isaac.WorldToScreen(v.hit.position),v.hit.angle) end
    end
    local function hearts(_,offset,_,position,_,p)
        if not context.IsReady() or not game:GetHUD():IsVisible() then return end
        local s,t=context.GetState(p)
        if not s or not t or not context.IsHeld(p) and not s.burnout then return end
        local v=get(p)
        local heartCount=math.ceil((p:GetEffectiveMaxHearts()+p:GetSoulHearts())/2)+p:GetBrokenHearts()
        local rows=math.max(1,math.ceil(heartCount/6))
        local pos=position+Vector(0,rows*10+5)
        -- Native heart callback supplies the owning HUD anchor, including co-op
        -- placement and HUD offset. Do not add Options.HUDOffset a second time.
        pos=Vector(math.min(Isaac.GetScreenWidth()-72,math.max(8,pos.X)),math.min(Isaac.GetScreenHeight()-24,pos.Y))
        local animation=s.burnout and 'BurnoutFill' or s.gauge<3 and 'BrownFill' or 'GreenFill'
        draw(v.gauge,animation,math.floor(s.gauge*10+.00001),pos)
        for _,f in ipairs(v.flashes) do
            v.feedback:SetFrame(f.kind,math.min(f.duration-1,f.age))
            local left,right=0,0
            if f.kind=='Spend' or f.kind=='Gain' then
                left=1+math.floor(math.min(f.from,f.to)/6*58)
                right=60-(1+math.ceil(math.max(f.from,f.to)/6*58))
            end
            v.feedback:Render(pos,Vector(math.max(0,left),0),Vector(math.max(0,right),0))
        end
        if s.burnout then
            draw(v.icons,'Broken',0,pos+Vector(-10,0))
        elseif s.gauge<=1 then draw(v.icons,'Warning',0,pos+Vector(-10,0)) end
        local indicator=not context.IsHeld(p) and s.burnout and 'Lock'
            or t.mode~='idle' and 'Pause' or t.walking and 'Walk'
        if indicator then draw(v.icons,indicator,0,pos+Vector(62,0)) end
    end
    mod:AddCallback(ModCallbacks.MC_PRE_PLAYER_RENDER,beforePlayer)
    mod:AddCallback(ModCallbacks.MC_POST_PLAYER_RENDER,afterPlayer)
    mod:AddCallback(ModCallbacks.MC_POST_PLAYERHUD_RENDER_HEARTS,hearts)
    return api
end
