local count=0;local function check(v,m)assert(v,m);count=count+1 end
local file=io.open('motion_sa_hud.lua');check(file~=nil,'original SA HUD renderer missing');file:close()
local V={};V.__index=V;function Vector(x,y)return setmetatable({X=x,Y=y},V)end
function Color(...)return {...}end
BlendType={ADDITIVE=1}
local calls,loads,blendCalls={},{},0
function Sprite()
 local s={}
 function s:Load(path)self.path=path;loads[#loads+1]=path end
 function s:GetLayer()return {GetBlendMode=function()return {SetMode=function()blendCalls=blendCalls+1 end}end}end
 function s:SetFrame(a,f)self.animation=a;self.frame=f end
 function s:Render(pos)calls[#calls+1]={a=self.animation,f=self.frame,pos=pos,scale=self.Scale}end
 function s:RenderLayer(id,pos)calls[#calls+1]={a=self.animation,f=self.frame,id=id,pos=pos,scale=self.Scale}end
 return s
end
include=function(name)return dofile(name..'.lua')end
local now,paused,visible=0,false,true
local function player(n)return {InitSeed=n,Exists=function()return true end,IsDead=function()return false end}end
local p,q=player(1),player(2)
local api=include('motion_sa_hud')({Key=function(who)return tostring(who.InitSeed)end,Now=function()return now end,
 IsPaused=function()return paused end,Visible=function()return visible end,ScreenWidth=function()return 480 end,ScreenHeight=function()return 270 end,HUDOffset=function()return 0 end})
local authoritative={energy=0,od=97}
api:Update(p,authoritative.energy);api:Render(p,0)
check(api:GetState(p).level==0 and api:GetState(p).fill==0,'empty meter uses original zero and empty fill')
check(#loads==1 and blendCalls==5,'native textures loaded once and additive layers configured once')
now=now+1;authoritative.energy=15;api:Update(p,15);api:Render(p,0)
check(api:GetState(p).phase=='gain','accumulation transition starts')
for _=1,7 do now=now+1;api:Update(p,15)end
check(math.abs(api:GetState(p).fill-.5)<.001,'half a 30-point bar is visibly half full')
now=now+1;api:Update(p,30);api:Render(p,0)
check(api:GetState(p).level==1 and api:GetState(p).phase=='gain','30 rolls to original level-one counter without a spend')
now=now+1;api:Update(p,90);api:Render(p,0)
check(api:GetState(p).level==3 and api:GetState(p).fill==1 and api:GetState(p).phase=='full_enter','90 is level3 full, not remainder0')
for _=1,9 do now=now+1;api:Update(p,90);api:Render(p,0)end
check(api:GetState(p).phase=='full_loop','full meter loops native glow')
local before=api:GetState(p).tick;local beforeLoads=#loads
for _=1,20 do api:Render(p,0)end
check(api:GetState(p).tick==before and #loads==beforeLoads,'render FPS does not advance animation or reload assets')
paused=true;now=now+20;api:Update(p,90);check(api:GetState(p).tick==before,'pause freezes visual clock');paused=false
now=now+1;api:Update(p,0);api:Render(p,0)
check(api:GetState(p).level==0 and api:GetState(p).fill==0 and api:GetState(p).phase=='spend','actual zero is immediate while old fill fades')
for _=1,5 do now=now+1;api:Update(p,0)end
check(api:GetState(p).phase=='idle','spend animation terminates')
now=now+1;api:Update(p,90);api:Render(p,0);check(api:GetState(p).phase=='full_enter','refund restores full-ready feedback')
api:Update(q,45);api:Render(q,1)
check(api:GetState(q).level==1 and api:GetState(p).level==3,'co-op energy display is independent')
check(api:GetState(p).position.X<240 and api:GetState(q).position.X>240,'native left/right player sides fit independent HUD positions')
visible=false;local total=#calls;api:Render(p,0);check(#calls==total,'hidden HUD draws no SA replacement');visible=true
api:Reset('hourglass');api:Update(p,90);api:Render(p,0)
check(api:GetState(p).phase=='full_loop','restore rebuilds current meter without a fake spend or gain')
check(authoritative.energy==15 and authoritative.od==97,'HUD never changes combat state')
api:Remove(p);check(api:GetState(p)==nil and api:GetState(q)==nil,'owner removal only clears existing owner after reset')
api:Reset('continuous gain');api:Update(p,0)
local advancing,previous,crossings=true,0,{}
for energy=1,89 do
 now=now+1;api:Update(p,energy);api:Render(p,0)
 local s=api:GetState(p)
 if energy%30>2 then advancing=advancing and s.fill>previous end
 if energy==29 or energy==59 or energy==89 then advancing=advancing and s.fill>.6 end
 if energy%30==0 then crossings[energy]=s.level end
 previous=s.fill
end
check(advancing,'adjacent-frame damage must advance the fill instead of restarting it at zero')
check(crossings[30]==1 and crossings[60]==2,'continuous damage crosses both counter levels')
for _=1,6 do now=now+1;api:Update(p,89)end
check(math.abs(api:GetState(p).fill-29/30)<.001,'continuous gain settles exactly when damage stops')
api:Reset('counter transition');api:Update(p,0)
now=now+1;api:Update(p,30);api:Render(p,0)
local function latestCounterFrame()
 for i=#calls,1,-1 do if calls[i].id==3 then return calls[i].a,calls[i].f end end
end
local anim,frame=latestCounterFrame();check(anim=='Gain1P1'and frame==0,'crossing a level starts the original upgrade animation')
now=now+1;api:Update(p,31);api:Render(p,0)
anim,frame=latestCounterFrame()
check(anim=='Gain1P1'and frame==2,'same-level gain must not restart the upgrade animation')
for energy=32,38 do now=now+1;api:Update(p,energy);api:Render(p,0)end
anim,frame=latestCounterFrame()
check(anim=='CounterP1'and frame==1,'sustained same-level gain leaves the counter steady after its upgrade')
api:Shutdown();api:Update(p,90);check(api:GetState(p)==nil,'unload detaches visual owner')
print('motion_sa_hud: '..count..' assertions passed')
