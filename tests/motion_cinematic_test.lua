local n=0;local function check(v,m)assert(v,m);n=n+1 end
local V={};V.__index=V;function Vector(x,y)return setmetatable({X=x,Y=y},V)end
function V.__add(a,b)return Vector(a.X+b.X,a.Y+b.Y)end
function V.__sub(a,b)return Vector(a.X-b.X,a.Y-b.Y)end
function V.__mul(a,b)return Vector(a.X*b,a.Y*b)end
local C=dofile('motion_cinematic.lua');local a=dofile('generated/motion_presentation.lua').circle_720
local f=a.normal_frames[111];local l=C.Layout(f,640,416,'right');local p=C.Pose(f,l)
check(l.cinema and p.scaleY>4,'V9 closeup really enlarges native actor beyond room size')
local r=l.point(f.body[1],f.body[2]);check(r.X>0 and r.X<640 and r.Y>0 and r.Y<416,'V9 actor pivot is on the visible screen')
local left=C.Layout(f,640,416,'left');check(math.abs(left.point(10,0).X-(640-l.point(10,0).X))<.001,'cinematic facing mirrors framing horizontally')
check(C.Pose(f,left).scaleX*p.scaleX<0,'native cinematic actor mirrors as one unit')
local narrowed,turned=false,false
for t=217,254 do local q=a.normal_frames[t+1];local pose=C.Pose(q,C.Layout(q,640,416,'right'),t)
 narrowed=narrowed or math.abs(pose.scaleX)<math.abs(pose.scaleY)*.75;turned=turned or pose.scaleX<0
end
check(narrowed and turned,'V9 airborne yaw survives the native closeup instead of becoming a static flip')
print('motion_cinematic: '..n..' assertions passed')
