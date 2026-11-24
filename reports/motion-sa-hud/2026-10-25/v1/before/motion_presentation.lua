-- Presentation only: no damage, charge, collision, AI, inventory or saved state.
return function(mod,context)
    context=context or {}
    if mod.MotionPresentation then mod.MotionPresentation:Shutdown() end
    local assets=include('generated/motion_presentation')
    local input=assert(mod.MotionInput,'shared motion input must load first')
    local game=Game();local sfx
    local api={active=true,states={},armed={},soundOwners={}}
    local facingOrder={'Right','Down','Left','Up'}
    local faceIndex={right=1,down=2,left=3,up=4}
    local profileKey={wave_tap='wave',dp='dp',circle_360='circle_360',circle_720='circle_720'}
    local profiles={wave='wave_tap',dp='dp',circle_360='circle_360',circle_720='circle_720'}
    local aliases={wave='wave',dp='dp',['360']='circle_360',['720']='circle_720',circle_360='circle_360',circle_720='circle_720'}
    local soundIds={}
    local function soundManager()
        if not sfx then sfx=SFXManager() end
        return sfx
    end
    local function key(p)
        return context.Key and context.Key(p) or (GetPtrHash and tostring(GetPtrHash(p)) or tostring(p))..':'..tostring(p.InitSeed or 0)
    end
    local function log(message)
        if context.DebugLog then context.DebugLog('[Motion Presentation] '..message)
        elseif Isaac.DebugString then Isaac.DebugString('[Motion Presentation] '..message) end
    end
    local function alive(p)return p and p:Exists() and not p:IsDead() end
    local function visibleWorld(postRender)
        local mode=game:GetRoom():GetRenderMode()
        return mode==RenderMode.RENDER_NORMAL or mode==RenderMode.RENDER_WATER_ABOVE
            or postRender and mode==RenderMode.RENDER_NULL
    end
    local function sprite(path)local s=Sprite();s:Load(path,true);return s end
    local function clone(original)
        local s=sprite(original:GetFilename())
        for _,layer in ipairs(original:GetAllLayers()) do s:ReplaceSpritesheet(layer:GetLayerID(),layer:GetSpritesheetPath()) end
        s:LoadGraphics();s:SetFrame(original:GetAnimation(),original:GetFrame())
        local overlay=original:GetOverlayAnimation()
        if overlay and overlay~='' then s:SetOverlayFrame(overlay,original:GetOverlayFrame()) end
        s.Scale=Vector(original.Scale.X,original.Scale.Y);s.Color=original.Color
        s.FlipX=original.FlipX;s.FlipY=original.FlipY;s.Rotation=original.Rotation
        return s
    end
    local function playerArt(p)
        local original=p:GetSprite();local body=clone(original);local head=clone(original)
        local art={body=body,head=head,scale=Vector(original.Scale.X,original.Scale.Y),color=p.Color,costumes={}}
        art.native=body:GetAnimationData('WalkRight')~=nil and head:GetAnimationData('HeadRight')~=nil
        local descs=p:GetCostumeSpriteDescs();local copied={}
        for _,layer in ipairs(p:GetCostumeLayerMap()) do
            if layer.costumeIndex>=0 and layer.layerID>=0 then
                local index=layer.costumeIndex+1;local desc=descs[index]
                if desc then
                    if not copied[index] then copied[index]=clone(desc:GetSprite()) end
                    local costume=copied[index]
                    local part=costume:GetAnimationData('WalkRight')~=nil and costume:GetAnimationData('HeadRight')==nil and 'body' or 'head'
                    art.costumes[#art.costumes+1]={sprite=costume,layer=layer.layerID,part=part}
                end
            end
        end
        return art
    end
    local function frameOf(s)return s.asset[s.variant..'_frames'][s.frame+1] end
    local function transform(s,postRender)
        if not alive(s.player) or s.player.Visible==false or not visibleWorld(postRender) then return end
        local data=frameOf(s);local cam=data.camera
        if data.cinema then
            local w,h=Isaac.GetScreenWidth(),Isaac.GetScreenHeight()
            if w<=0 or h<=0 then return end
            local scale=math.min(w/320,h/208);local center=Vector(w/2,h/2+20*scale)
            return {scale=scale,rotation=0,point=function(x,y)return center+Vector(x,y)*scale end,cinema=true}
        end
        -- WorldToScreen consumes only the logical live owner position. Source
        -- X is forward distance; source Y is screen height above the ground.
        -- Do not rotate jump height into sideways motion for an up/down attack.
        local converted,pos=pcall(Isaac.WorldToScreen,s.player.Position)
        if not converted or not pos then return end
        local angle=(faceIndex[s.facing]-1)*90
        local forward=Vector(1,0):Rotated(angle);local start=s.asset.start_feet
        local originX=s.combat and s.key~='circle_720' and data.body[1] or start[1]
        return {scale=1/cam[3],rotation=angle,point=function(x,y)
            local wx,wy=x/cam[3]+cam[1],y/cam[3]+cam[2]
            return pos+forward*(wx-originX)+Vector(0,wy-start[2])
        end,cinema=false}
    end
    local function releaseAudio(s)
        for id in pairs(s.sounds) do
            api.soundOwners[id]=(api.soundOwners[id] or 1)-1
            if api.soundOwners[id]<=0 then api.soundOwners[id]=nil;soundManager():Stop(id) end
        end
        s.sounds={}
    end
    local function audioAt(s)
        for _,event in ipairs(s.asset.audio) do
            if event.tick>(s.audioCursor or -1) and event.tick<=s.frame then
                local name='Zangief V2 '..event.key;local id=soundIds[name]
                if id==nil then id=Isaac.GetSoundIdByName(name);soundIds[name]=id end
                if id and id>0 then
                    if not s.sounds[id] then s.sounds[id]=true;api.soundOwners[id]=(api.soundOwners[id] or 0)+1 end
                    soundManager():Play(id,event.gain or 1,0,false,1)
                else log('missing registered sound: '..name) end
            end
        end
        s.audioCursor=s.frame
    end
    function api:Stop(p,keepRehearsal)
        local k=key(p);local s=self.states[k]
        if s then releaseAudio(s);self.states[k]=nil end
        if not keepRehearsal and self.armed[k] then
            self.armed[k]=nil;input:SetRehearsal(p,nil)
        end
    end
    function api:Reset(reason)
        local players={};for _,s in pairs(self.states) do players[key(s.player)]=s.player end
        for k,r in pairs(self.armed) do players[k]=r.player end
        for _,p in pairs(players) do self:Stop(p) end
        self.lastReset=reason
    end
    function api:Shutdown()
        if not self.active then return end
        self:Reset('unload');self.active=false
        if input.presentationSink==self.sink then input:SetPresentationSink(nil) end
    end
    function api:GetState(p)
        local s=self.states[key(p)];if not s then return end
        return {key=s.key,variant=s.variant,frame=s.frame,frames=s.asset.frames,facing=s.facing,
            started=s.started,cinema=frameOf(s).cinema,rehearsal=s.rehearsal,version=s.asset.source_version,
            presentationOnly=s.presentationOnly,combat=s.combat,sourceOwner=s.sourceOwner,renderedFrame=s.renderedFrame}
    end
    function api:SetCombatFrame(p,frame,hit)
        local s=self.states[key(p)];if not s or not s.combat then return false end
        s.frame=math.max(0,math.min(s.asset.frames-1,frame));s.hit=hit;audioAt(s);return true
    end
    function api:SetTarget(p,target)
        local s=self.states[key(p)];if not s or not alive(target) then return false end
        local good,art=pcall(clone,target:GetSprite());if not good then return false end
        s.target=target;s.targetArt=art;s.targetSize=target.Size
        s.hiddenTargetKey=GetPtrHash and GetPtrHash(target) or target;return true
    end
    function api:FinishTarget(p,keepArt)
        local s=self.states[key(p)];if not s then return end
        s.target=nil;if not keepArt then s.targetArt=nil;s.hiddenTargetKey=nil end
    end
    function api:GetTargetPosition(p)
        local s=self.states[key(p)];if not s or not s.targetArt then return end
        local data=frameOf(s);if data.cinema then return end
        local dir=Vector(1,0):Rotated((faceIndex[s.facing]-1)*90);local q=data.target;local start=s.asset.start_feet
        local originX=s.combat and s.key~='circle_720' and data.body[1] or start[1]
        return p.Position+dir*(q[6]-originX)+Vector(0,q[7]-start[2])
    end
    function api:Play(p,name,options)
        options=options or {};local move=aliases[name];local asset=move and assets[move]
        if not self.active or not alive(p) then return {ok=false,reason='owner'} end
        local variant=options.variant or 'normal';local facing=options.facing
        if not facing then facing=({[0]='left',[1]='up',[2]='right',[3]='down'})[p:GetHeadDirection()] or 'down' end
        if not asset or not asset.variants[variant] or not faceIndex[facing] then return {ok=false,reason='variant_or_direction'} end
        local target=options.target
        if target and (not target:Exists() or target==p or target.IsDead and target:IsDead()) then return {ok=false,reason='target'} end
        if move:find('circle_',1,true) and not options.rehearsal and not options.presentationOnly and not target
            and not (options.combat and move=='circle_360') then return {ok=false,reason='target'} end
        local loaded,s=pcall(function()
            return {player=p,key=move,asset=asset,variant=variant,facing=facing,frame=0,started=game:GetFrameCount(),
                advanced=game:GetFrameCount(),sprite=sprite(asset.native_path or asset.path),art=playerArt(p),sounds={},target=target,
                targetArt=target and clone(target:GetSprite()),targetSize=target and target.Size,rehearsal=not not options.rehearsal,combat=not not options.combat,
                hiddenTargetKey=target and (GetPtrHash and GetPtrHash(target) or target),
                presentationOnly=not not options.presentationOnly,sourceOwner=options.sourceOwner}
        end)
        if not loaded then log('resource initialization failed: '..tostring(s));return {ok=false,reason='resource'} end
        self:Stop(p,true);s.sprite:SetFrame(asset.variants[variant].animation,0)
        self.states[key(p)]=s;audioAt(s)
        return {ok=true}
    end
    function api:Arm(p,name,variant)
        local move=aliases[name];variant=variant or 'normal'
        if not self.active or not alive(p) or not move or not assets[move].variants[variant] then return {ok=false,reason='variant_or_owner'} end
        self:Stop(p);self.armed[key(p)]={player=p,key=move,variant=variant}
        input:SetRehearsal(p,{profile=profiles[move],availability=function(who)return self:GetState(who) and 'recovery' or 'ready' end,
            execute=function(who,command)return self:Play(who,move,{variant=variant,facing=command.facing,rehearsal=true}) end})
        return {ok=true}
    end
    api.sink=function(p,command,result)
        if not api.active or result.presentation==false then return end
        local move=profileKey[command.profile];if not move then return end
        local info=type(result.presentation)=='table' and result.presentation or {}
        local outcome=api:Play(p,move,{variant=info.variant or 'normal',facing=command.facing,target=info.target})
        if not outcome.ok then log('command succeeded, presentation skipped: '..outcome.reason) end
    end
    input:SetPresentationSink(api.sink)
    local function mappedFace(s,data,layout)
        local index=faceIndex[data.face:lower()]
        return layout.cinema and data.face or facingOrder[(index+faceIndex[s.facing]-2)%4+1]
    end
    local function part(s,layout,data,which,offset,color)
        local pose=data[which];local art=s.art;local actor=art[which]
        if not art.native and which=='head' then return end
        local face=mappedFace(s,data,layout)
        if art.native then actor:SetFrame((which=='body' and 'Walk' or 'Head')..face,which=='body' and data.body_tick or 0) end
        local pos=layout.point(pose[1],pose[2])+(offset or Vector(0,0))
        local scale=layout.scale
        actor.Scale=Vector(math.abs(pose[3])/100*scale*art.scale.X,math.abs(pose[4])/100*scale*art.scale.Y)
        actor.Rotation=pose[5];actor.Color=color or art.color
        if art.native then actor:RenderLayer(which=='body' and 1 or 4,pos) else actor:Render(pos) end
        for _,c in ipairs(art.costumes) do
            if c.part==which then
                local animation=(which=='body' and 'Walk' or 'Head')..face
                if c.sprite:GetAnimationData(animation) then c.sprite:SetFrame(animation,which=='body' and data.body_tick or 0) end
                c.sprite.Scale=actor.Scale;c.sprite.Rotation=actor.Rotation;c.sprite.Color=color or art.color
                c.sprite:RenderLayer(c.layer,pos)
            end
        end
    end
    local function drawFx(s,layout,entry,name)
        if s.combat and (s.key=='wave' and (name=='wave_a' or name=='wave_b')
            or name:find('impact_',1,true)==1 and not s.hit) then return end
        if not layout.cinema and (name=='backdrop' or name=='bar_top' or name=='bar_bottom') then return end
        local target=name:find('target_',1,true)==1
        -- Opponents are never loaded from an authored demonstration layer.
        if target then return end
        local rotation=layout.rotation
        if layout.cinema or target or name=='shadow' then rotation=0 end
        local x,y=entry[2],entry[3];local internal=Vector(x,y)*layout.scale
        s.sprite.Scale=Vector(layout.scale,layout.scale);s.sprite.Rotation=rotation
        local pos=layout.point(x,y)-internal:Rotated(rotation)
        local layer=entry[1]
        if s.asset.native_layer_map then
            layer=assert(s.asset.native_layer_map[tostring(layer)],'missing native layer mapping')
        end
        assert(layer>=0 and layer<64,'native layer out of bounds')
        s.sprite:RenderLayer(layer,pos)
    end
    local function drawTarget(s,layout,data)
        if not s.targetArt or not data.target_visible then return end
        local q=data.target;local cam=data.camera
        -- The authored rotated sprite origin keeps an inverted victim above
        -- the floor; a bounding-box bottom cannot be used as a sprite pivot.
        local x,y=(q[6]-cam[1])*cam[3],(q[7]-cam[2])*cam[3]
        local size=math.max(1,(s.targetSize or 14)*2)
        local fit=math.min(1,q[4]/size,q[5]/size)
        local scale=cam[3]*layout.scale*fit
        s.targetArt.Scale=Vector(scale,scale);s.targetArt.Rotation=q[3]
        s.targetArt:Render(layout.point(x,y))
    end
    local function draw(s,layout)
        local data=frameOf(s);s.sprite:SetFrame(s.asset.variants[s.variant].animation,s.frame)
        local visible={};for _,entry in ipairs(data.visible) do visible[entry[1]]=entry end
        for _,layer in ipairs(s.asset.layers) do
            local id,name=layer[1],layer[2]
            if name=='native_body' then
                if s.targetArt and data.target_depth=='back' then drawTarget(s,layout,data)end
                if data.glow>0 then
                    local z=data.camera[3]*layout.scale
                    for i,d in ipairs(s.asset.gold_offsets) do
                        local alpha=(i<=4 and 60 or 215)*data.glow/255
                        local offset=Vector(d[1]*z,d[2]*z);local gold=Color(0,0,0,alpha,1,192/255,24/255)
                        part(s,layout,data,'body',offset,gold);part(s,layout,data,'head',offset,gold)
                    end
                end
                part(s,layout,data,'body')
            elseif name=='native_head' then
                part(s,layout,data,'head')
                if data.glow>0 then
                    local wash=Color(1,225/255,110/255,78*data.glow/255,25/255,12/255,0)
                    part(s,layout,data,'body',nil,wash);part(s,layout,data,'head',nil,wash)
                end
                if s.targetArt and data.target_depth=='front' then drawTarget(s,layout,data)end
            elseif visible[id] then
                drawFx(s,layout,visible[id],name)
            end
        end
    end
    function api:RenderProjectile(shot)
        if not self.active or not visibleWorld(true) then return end
        local a=assets.wave;local t=17+shot.age%18;local f=a.normal_frames[t+1]
        if not shot.art then shot.art=sprite(a.native_path or a.path)end
        local art=shot.art;art:SetFrame(a.variants.normal.animation,t)
        local angle=(faceIndex[shot.facing]-1)*90;art.Rotation=angle;art.Scale=Vector(1,1)
        local pos=Isaac.WorldToScreen(shot.entity.Position)+Vector(0,-10)
        local center
        for _,e in ipairs(f.visible) do if e[1]==32 then center=Vector(e[2],e[3]);break end end
        if center then for _,e in ipairs(f.visible) do if e[1]==32 or e[1]==33 then
            art:RenderLayer(a.native_layer_map[tostring(e[1])],pos-center:Rotated(angle))
        end end end
    end
    local function add(name,priority,fn)
        local id=ModCallbacks[name];if id then mod:AddPriorityCallback(id,priority,fn) end
    end
    add('MC_POST_UPDATE',0,function()
        if not api.active then return end
        local discard={}
        for k,r in pairs(api.armed) do if not alive(r.player) then discard[k]=r.player end end
        for k,s in pairs(api.states) do
            if not alive(s.player) or s.target and (not s.target:Exists() or s.target.IsDead and s.target:IsDead()) then discard[k]=s.player
            elseif not s.combat and not game:IsPaused() and s.advanced~=game:GetFrameCount() then
                s.advanced=game:GetFrameCount();s.frame=s.frame+1
                if s.frame>=s.asset.frames then api:Stop(s.player,true) else audioAt(s) end
            end
        end
        for _,p in pairs(discard) do api:Stop(p) end
    end)
    add('MC_PRE_PLAYER_RENDER',30000,function(_,p)
        local s=api.active and api.states[key(p)]
        -- Installed main_ex.lua _RunPreRenderCallback: false cancels this actor.
        if s and transform(s) then return false end
    end)
    add('MC_PRE_NPC_RENDER',30000,function(_,npc)
        if not api.active then return end
        local npcKey=GetPtrHash and GetPtrHash(npc) or npc
        for _,s in pairs(api.states) do if s.hiddenTargetKey==npcKey and transform(s) then return false end end
    end)
    add('MC_POST_RENDER',0,function()
        if not api.active then return end
        local cancel={}
        for _,s in pairs(api.states) do
            -- Native room entity rendering has ended here; RENDER_NULL is the
            -- expected mode for this once-per-screen presentation pass.
            local layout=transform(s,true)
            if layout then
                local good,err=pcall(draw,s,layout)
                if good then s.renderedFrame=s.frame
                else log('render cancelled safely: '..tostring(err));cancel[#cancel+1]=s.player end
            end
        end
        for _,p in ipairs(cancel) do api:Stop(p) end
    end)
    for _,name in ipairs({'MC_POST_NEW_ROOM','MC_POST_NEW_LEVEL','MC_POST_GAME_STARTED','MC_PRE_GAME_EXIT','MC_POST_GLOWING_HOURGLASS_LOAD'}) do
        add(name,0,function()if api.active then api:Reset(name) end end)
    end
    add('MC_PRE_MOD_UNLOAD',0,function(_,unloaded)if unloaded==mod then api:Shutdown() end end)
    add('MC_EXECUTE_CMD',0,function(_,cmd,params)
        if not api.active or cmd~='nbmotion' then return end
        local words={};for word in (params or ''):gmatch('%S+') do words[#words+1]=word end
        local action=table.remove(words,1) or 'help'
        local player=game:GetNumPlayers()>0 and Isaac.GetPlayer(0)
        if not player then return '请先进入一局游戏。' end
        if action=='stop' then api:Stop(player);return '招式演出与搓招预演已停止。' end
        if action=='status' then
            local s=api:GetState(player)
            return (s and (s.key..' '..s.variant..' '..s.frame..'/'..s.frames) or '当前没有演出')..' | '..input:GetDiagnosticText(player)
        end
        local arm=action=='arm';local move=arm and table.remove(words,1) or action
        if aliases[move] then
            local variant=words[1] or 'normal';local facing=words[2]
            if arm and #words>1 then return 'nbmotion arm <wave|dp|360|720> [normal|od]；朝向由实际射击输入锁定。' end
            if #words>2 then return '参数过多。nbmotion <wave|dp|360|720> [normal|od] [right|down|left|up]' end
            local result=arm and api:Arm(player,move,variant) or api:Play(player,move,{variant=variant,facing=facing,rehearsal=true})
            return result.ok and (arm and '已启用搓招预演：按住主动键，再输入已确认指令；nbmotion stop退出。' or '正在播放已确认演出（仅视觉预演）。') or '无法播放：'..tostring(result.reason)
        end
        return 'nbmotion <wave|dp|360|720> [normal|od] [right|down|left|up]\nnbmotion arm <wave|dp|360|720> [normal|od]\nnbmotion stop | status'
    end)
    mod.MotionPresentation=api
    return api
end
