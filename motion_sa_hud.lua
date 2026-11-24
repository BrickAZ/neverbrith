-- Original SF6 SA HUD. All state below is visual and never saved as combat data.
return function(context)
 local asset=include('generated/motion_sa_hud');local states={};local active=true
 local api={};local factor=asset.source_fps/asset.logic_fps
 local layers={Base={0},Frame={1},Fill={2},Counter={3},Marker={4},FullEnter={5},FullLoop={6,7},Spend={8}}
 local function phase(s)
  if s.spendAt and (s.tick-s.spendAt)*factor<=asset.spend_frames then return 'spend' end
  if s.fullAt and (s.tick-s.fullAt)*factor<=asset.full_frames then return 'full_enter' end
  if s.energy==90 then return 'full_loop' end
  if s.gainAt and (s.tick-s.gainAt)*factor<=asset.gain_frames then return 'gain' end
  return 'idle'
 end
 local function initialize(p,energy)
  local ok,sprite=pcall(function()
   local sprite=Sprite();sprite:Load(asset.path,true)
   for _,id in ipairs(asset.additive_layers)do sprite:GetLayer(id):GetBlendMode():SetMode(BlendType.ADDITIVE)end
   return sprite
  end)
  local s={player=p,energy=energy,level=math.floor(energy/30),fill=energy==90 and 1 or energy%30/30,
   tick=0,lastNow=context.Now(),sprite=ok and sprite or nil,error=not ok and tostring(sprite)or nil,rendered={}}
  if s.error and context.Log then context.Log('[Motion SA HUD] '..s.error)end
  states[context.Key(p)]=s;return s
 end
 function api:Update(p,energy)
  if not active then return end
  energy=math.max(0,math.min(90,tonumber(energy)or 0))
  local s=states[context.Key(p)]or initialize(p,energy)
  local now=context.Now();if s.lastNow==now then return end;s.lastNow=now
  if context.IsPaused()then return end;s.tick=s.tick+1
  -- Advance the previous target before a new damage receipt retargets it.
  -- Otherwise adjacent-frame gains keep resetting interpolation to t=0.
  if s.gainAt and s.energy~=90 then
   local t=math.min(1,(s.tick-s.gainAt)*factor/asset.gain_frames)
   s.fill=s.fillFrom+(s.fillTo-s.fillFrom)*t
  end
  if s.energy~=energy then
   local old=s.energy;local level=math.floor(energy/30);local fill=energy==90 and 1 or energy%30/30
   s.energy=energy;s.level=level;s.fullAt=nil
   if energy<old then
    s.spendAt=s.tick;s.gainAt=nil;s.counterAt=nil;s.fill=fill;s.fillFrom=fill;s.fillTo=fill
   else
    s.spendAt=nil;s.gainAt=s.tick;s.fillFrom=math.floor(old/30)==level and s.fill or 0;s.fillTo=fill
    if level>math.floor(old/30)then s.counterAt=s.tick end
    if energy==90 then s.fullAt=s.tick;s.fill=1
    elseif math.floor(old/30)~=level then s.fill=0 end
   end
  end
 end
 function api:Render(p,index)
  if not active or not p:Exists()or p:IsDead()or not context.Visible()then return end
  local s=states[context.Key(p)];if not s or not s.sprite then return end
  local width,height=context.ScreenWidth(),context.ScreenHeight();if width<=0 or height<=0 then return end
  index=index or 0;local side=index%2==0 and 'P1'or 'P2';local offset=context.HUDOffset and context.HUDOffset()or 0
  local pos=Vector(side=='P1'and 72+offset*20 or width-72-offset*20,height-34-index*32-offset*12)
  local scale=math.min(asset.scale,width/1920);local sprite=s.sprite;sprite.Scale=Vector(scale,scale);sprite.Color=Color(1,1,1,1)
  local function draw(name,frame,ids)
   local animation=name..side;sprite:SetFrame(animation,frame)
   for _,id in ipairs(ids or layers[name]or layers.Counter)do sprite:RenderLayer(id,pos)end
   s.rendered[name]=(s.rendered[name]or 0)+1
  end
  local which=phase(s);local percent=math.floor(s.fill*100+.5)
  draw('Base',0)
  if which=='spend'then draw('Spend',math.floor((s.tick-s.spendAt)*factor))end
  if percent>0 then draw('Fill',percent)end
  if s.energy==90 then draw('FullLoop',math.floor(s.tick*factor%asset.loop_frames))end
  draw('Frame',0)
  if which=='full_enter'then draw('FullEnter',math.floor((s.tick-s.fullAt)*factor))end
  if s.counterAt and s.level>0 and (s.tick-s.counterAt)*factor<=asset.gain_frames then
   draw('Gain'..s.level,math.floor((s.tick-s.counterAt)*factor))
  else draw('Counter',s.level)end
  if percent>0 and percent<100 then draw('Marker',percent)end
  s.position=pos;s.side=side;s.renderedAt=context.Now();s.renderedPhase=which
 end
 function api:GetState(p)
  local s=states[context.Key(p)];if not s then return end
  local rendered={};for k,v in pairs(s.rendered)do rendered[k]=v end
  return {energy=s.energy,level=s.level,fill=s.fill,phase=phase(s),tick=s.tick,error=s.error,resource=asset.path,
   position=s.position,side=s.side,renderedAt=s.renderedAt,renderedPhase=s.renderedPhase,rendered=rendered}
 end
 function api:Remove(p)states[context.Key(p)]=nil end
 function api:Prune(seen)for k in pairs(states)do if not seen[k]then states[k]=nil end end end
 function api:Reset(reason)states={};self.lastReset=reason end
 function api:Shutdown()active=false;self:Reset('unload')end
 return api
end
