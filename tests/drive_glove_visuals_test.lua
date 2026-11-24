-- Render regression: native value copies plus cancelled/unpaired render passes.
local checks=0
local function ok(v,label) assert(v,label); checks=checks+1 end
local function near(a,b,label) ok(math.abs(a-b)<1e-6,label..': '..a) end
local vec={}; vec.__index=vec
local function V(x,y) return setmetatable({X=x,Y=y},vec) end
function vec.__add(a,b) return V(a.X+b.X,a.Y+b.Y) end
Vector=setmetatable({},{__call=function(_,x,y) return V(x,y) end})
local col={};col.__index=col
function col:GetColorize() return {R=self.RC,G=self.GC,B=self.BC,A=self.AC} end
Color=setmetatable({},{__call=function(_,r,g,b,a,ro,go,bo,rc,gc,bc,ac)
 return setmetatable({R=r,G=g,B=b,A=a,RO=ro or 0,GO=go or 0,BO=bo or 0,
 RC=rc or 0,GC=gc or 0,BC=bc or 0,AC=ac or 0},col)
end})
local calls,frame,renderMode={},0,0
Sprite=setmetatable({},{__call=function()
 local s={}
 function s:Load(path) self.path=path end
 function s:SetFrame(a,f) self.animation=a;self.frame=f end
 function s:Render(pos) assert(getmetatable(pos)==vec);calls[#calls+1]={path=self.path,animation=self.animation,pos=pos,rotation=self.Rotation} end
 return s
end})
ModCallbacks={MC_PRE_PLAYER_RENDER=1,MC_POST_PLAYER_RENDER=2,MC_POST_PLAYERHUD_RENDER_HEARTS=3}
RenderMode={RENDER_NORMAL=0,RENDER_WATER_ABOVE=1}
local game={}
function game:GetFrameCount() return frame end
function game:GetRoom() return {GetRenderMode=function() return renderMode end} end
function game:GetHUD() return {IsVisible=function() return true end} end
function game:Darken() end
Game=function() return game end
Isaac={WorldToScreen=function(p) return p+V(100,50) end,GetScreenWidth=function() return 640 end,GetScreenHeight=function() return 480 end}
local backing={SpriteScale=V(1.2,.8),SpriteRotation=7,Color=Color(.7,.8,.9,.6,.01,.02,.03,.2,.3,.4,.5)}
local liveRefs=false
local p=setmetatable({Position=V(230,170)},{__index=function(_,k)
 local v=backing[k]
 if not liveRefs and k=='SpriteScale' then return V(v.X,v.Y) end
 if not liveRefs and k=='Color' then return Color(v.R,v.G,v.B,v.A,v.RO,v.GO,v.BO,v.RC,v.GC,v.BC,v.AC) end
 return v
end,__newindex=function(_,k,v)
 if k=='SpriteScale' or k=='Color' then
  assert(getmetatable(v)==(k=='Color' and col or vec),'engine-compatible constructor required')
  for name,value in pairs(v) do backing[k][name]=value end
 else backing[k]=v end
end})
function p:Exists() return true end
function p:GetEffectiveMaxHearts() return 6 end
function p:GetSoulHearts() return 0 end
function p:GetBrokenHearts() return 0 end
local s,t={gauge=6,burnout=false},{mode='blue',blueAt=0,events={}}
local ready,held=true,true
local callbacks={}
local mod={AddCallback=function(_,id,fn) callbacks[id]=fn end}
local api=dofile(arg[1] or 'drive_glove_visuals.lua')(mod,{Key=function() return 'p' end,
 GetPlayers=function() return {p} end,GetState=function() return s,t end,
 IsReady=function() return ready end,IsHeld=function() return held end})
local function pre() callbacks[1](nil,p,V(11,13)) end
local function post() callbacks[2](nil,p,V(11,13)) end
local function restored()
 near(p.SpriteScale.X,1.2,'scale X restored');near(p.SpriteScale.Y,.8,'scale Y restored')
 near(p.SpriteRotation,7,'rotation restored');near(p.Color.R,.7,'tint restored')
 near(p.Color.A,.6,'alpha restored');near(p.Color.RO,.01,'offset restored')
 near(p.Color:GetColorize().B,.4,'colorize restored')
end
for i=1,180 do
 frame=i;pre();near(p.SpriteScale.Y,.8*.96,'blue pose stable');post();restored()
end
-- A cancelled render may not get POST; the next render/update/room reset must clean up.
pre();pre();near(p.SpriteScale.Y,.8*.96,'unpaired PRE does not compound');post();restored()
pre();api.ClearRoom();restored()
pre();api.Update();restored()
-- Defensive copy behavior also remains safe if a property adapter exposes a live value.
liveRefs=true;pre();post();restored();liveRefs=false
renderMode=2;pre();post();restored();renderMode=0
s.burnout=true;t.mode='idle';held=false
for i=1,90 do
 frame=i;pre();local c=p.Color:GetColorize()
 ok(c.A==1 and c.R==c.G and c.G==c.B,'burnout gray also when unequipped')
 ok(p.SpriteScale.Y>=.8*.98 and p.SpriteScale.Y<=.8,'bounded fatigue breathing')
 near(p.Color.A,.6,'burnout preserves alpha');post();restored()
end
calls={};callbacks[3](nil,V(1,2),0,V(20,10),0,p)
local broken=false
for _,call in ipairs(calls) do
 ok(call.animation~='BurnoutLabel','no burnout label drawn')
 if call.animation=='Broken' then broken=true end
end
ok(broken,'broken gauge icon retained')
s.burnout=false;held=true;pre();restored();post();restored()
s.burnout=true;t.mode='rush';t.moveFrames=2;t.heading=45
pre();ok(p.Color:GetColorize().A==1,'paid rush retains burnout gray');post();restored()
ready=false;pre();post();restored()
ready=true;held=true;s.burnout=false;api.ClearRoom();calls={}
t.mode='blue';t.events={{kind='Parry'}};t.impactAngle=180;t.impactKind=''
api.Events(p,s,t);pre();post();local hit=calls[#calls]
near(hit.rotation,180,'directional effect keeps incoming angle')
local origin=hit.pos;p.Position=p.Position+V(30,20);frame=frame+1;calls={};pre();post()
near(calls[#calls].pos.X,origin.X,'hit world X stays at impact');near(calls[#calls].pos.Y,origin.Y,'hit world Y stays at impact')
for _,kind in ipairs({'Floor','Center'}) do
 api.ClearRoom();calls={};t.impactKind=kind;t.events={{kind='Parry'}};api.Events(p,s,t);pre();post()
 ok(calls[#calls].animation=='Parry'..kind,'dedicated '..kind..' animation selected')
 near(calls[#calls].pos.Y,p.Position.Y+50+(kind=='Floor' and 0 or -16),kind..' world anchor converted once')
end
api.ClearRoom();t.impactKind='';t.events={{kind='PerfectParry'}};api.Events(p,s,t)
t.mode='startup';t.rushAt=frame;t.heading=0;t.events={{kind='RushStart'}};api.Events(p,s,t);pre()
near(p.Color.R,.5,'rush takes color ownership from perfect flash');post()
api.ClearRoom();t.mode='recovery';t.recoveryAt=frame-4;pre()
near(p.Color.R,.7,'middle recovery restores original tint');near(p.Color.RO,.01,'middle recovery restores original color offset');post()
frame=t.recoveryAt+11;pre();near(p.SpriteScale.Y,.8,'last recovery frame reaches original pose');post()
print('Drive Glove visuals: '..checks..' passed')
