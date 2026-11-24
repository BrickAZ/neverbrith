-- Current combat supplements only. Approved offline V7/V9 remain immutable.
local A={fistPath='gfx/Effects/MotionShowcase/additions_v1/dragon_fist.anm2'}
local function clamp(x)return math.max(0,math.min(1,x))end
local function copy(t)local r={};for k,v in pairs(t)do r[k]=v end;return r end
function A.Frame(s,source)
 if not(s.combat and s.key=='circle_360'and s.variant=='od')then return source end
 if s.additionFrame==s.frame then return s.additionPose end
 local f=copy(source);f.body=copy(source.body);f.feet=copy(source.feet);f.target=copy(source.target)
 local t=s.frame;local height,turn=0,0
 if t>=18 and t<28 then
  local u=(t-18)/10;height=4*math.sin(u*math.pi);f.body[4]=f.body[4]*(1-.1*math.sin(u*math.pi))
  f.target[3]=90+90*u;f.phase='brace'
 elseif t>=28 and t<=65 then
  local u=(t-28)/37;height=-84*math.sin(u*math.pi/2);turn=6*math.pi*u
  f.target[3]=180;f.phase='horizontal-rise'
 elseif t>=66 and t<=73 then
  local u=(t-66)/7;height=-84*(1-u*u);f.target[3]=180;f.phase=t==73 and 'slam'or 'dive'
 else f.phase=t>73 and 'recovery'or 'startup'end
 f.feet[2]=s.asset.start_feet[2]+height;f.turnCos=math.cos(turn)
 if t>=18 and t<=73 then
  local cam=f.camera;local x=f.body[1]/cam[3]+cam[1];local y=f.body[2]/cam[3]+cam[2]
  f.target[6]=x+12*math.cos(turn);f.target[7]=y-28+3*math.sin(turn)
  f.target_depth=math.sin(turn)<0 and 'back'or 'front';f.targetScaleX=math.cos(turn)
  f.glow=math.max(f.glow,.85)
 end
 s.additionFrame=t;s.additionPose=f;return f
end
function A.Fist(s)
 if not s.combat or s.key~='dp'then return end
 local a,b,stage=18,44,1
 if s.variant=='od'then
  if s.frame>=18 and s.frame<=29 then a,b,stage=18,29,1
  elseif s.frame>=38 and s.frame<=53 then a,b,stage=38,53,2
  else return end
 elseif s.frame<a or s.frame>b then return end
 local u=(s.frame-a)/(b-a)
 return {stage=stage,alpha=.6*math.min(1,(u+.15)*4)*clamp((1-u)*3),
  forward=13+5*u,height=-12-6*u,scale=stage==2 and 1.1 or 1,frame=math.min(11,math.floor(u*12))}
end
return A
