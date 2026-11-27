local Archive=dofile('scripts/systems/archive_room.lua')
local Controls=dofile('scripts/systems/archive_controls.lua')
local p1={InitSeed=3,Position={X=1,Y=2}}
local players={p1};local vectorCalls=0
Vector=function(x,y)vectorCalls=vectorCalls+1;return {X=x,Y=y,engine=true}end
local room=Archive.Create(function()return players end,'[test]')
local object={nilValue=function()return nil end,falseValue=function()return false end,
    add=function(_,n)return n end,broken=function()error('broken')end}
local v,ok=Archive.Call(object,'nilValue');assert(v==nil and ok)
v,ok=Archive.Call(object,'falseValue');assert(v==false and ok)
v,ok=Archive.Call(object,'missing');assert(v==nil and not ok)
v,ok=Archive.Call(object,'broken');assert(v==nil and not ok)
v,ok=Archive.Call(object,'add',17);assert(v==17 and ok)
Game=setmetatable({},{__call=function()error('callable table must be rejected')end})
assert(Archive.CurrentGame()==nil)
Game=function()return false end;assert(Archive.CurrentGame()==nil)
local game={};Game=function()return game end;assert(Archive.CurrentGame()==game)
local descriptor={};local calls={}
GetPtrHash=function(v)assert(v);return v end
local level={GetCurrentRoomIndex=function()return 10 end,
    GetRoomByIdx=function(_,index,dimension)calls[#calls+1]={index,dimension};return dimension==2 and descriptor or {}end}
descriptor.SafeGridIndex=21
assert(Archive.CurrentDimension(level,descriptor)==2 and calls[3][1]==21)
GetPtrHash=function()error('missing hash')end;assert(Archive.CurrentDimension(level,descriptor)==0)
local saved=room.capturePlayerPositions();assert(saved[1].key=='3' and saved[1].x==1)
p1.Position.X=9;assert(saved[1].x==1,'capture must not retain live Vector')
room.restorePlayerPositions({originPlayerPositions=saved})
assert(p1.Position.X==1 and p1.Position.engine)
players={{InitSeed=3,Position={X=7,Y=8}}};room.restorePlayerPositions({originPlayerPositions=saved})
assert(players[1].Position.X==1 and p1.Position.X==1,'restore resolves current players')
local nativeRoom={GetTopLeftPos=function()return Vector(40,120)end,GetBottomRightPos=function()return Vector(600,440)end}
local bounds=assert(Archive.SafeBounds(nativeRoom,40,80));assert(bounds.left==80 and bounds.galleryBottom==320)
v,ok=Archive.SafeBounds({},40,80);assert(v==nil and ok=='unavailable')
nativeRoom.GetBottomRightPos=function()return Vector(50,150)end
v,ok=Archive.SafeBounds(nativeRoom,40,80);assert(v==nil and ok=='too_small')
local six=room.gridPositions(nativeRoom,bounds,6);assert(#six==6 and six[1].X==160 and six[6].X==480)
local checked=0
local compact=room.gridPositions(nativeRoom,bounds,6,function(_,pos,margin)
    checked=checked+1;assert(pos.engine and margin==18);return pos.X~=320
end)
assert(checked==6 and #compact==4 and compact[2].X==480)
assert(room.controlPosition(bounds,'return').X==320 and room.controlPosition(bounds,'previous').X==208)
assert(Archive.PageEdges(3,0).next==2 and Archive.PageEdges(3,99).previous==2)
local effect={};function effect:GetSprite()return self.sprite end
local missing=0
v,ok=Controls.PlayAnimation(effect,'Idle',function()missing=missing+1 end);assert(not v and ok==nil)
effect.sprite={HasAnimation=function()return false end,Play=function()error('unexpected play')end}
v,ok=Controls.PlayAnimation(effect,'Idle',function()missing=missing+1 end);assert(not v and ok==nil and missing==1)
effect.sprite.HasAnimation=function()return true end
v,ok=Controls.PlayAnimation(effect,'Idle');assert(v==false and ok==true,'attempted Play failure distinguished')
effect.sprite.Play=function(self,name,force)self.name=name;assert(force)end
v,ok=Controls.PlayAnimation(effect,'Idle');assert(v and ok and effect.sprite.name=='Idle')
EntityCollisionClass={ENTCOLL_NONE=0};GridCollisionClass={COLLISION_NONE=0}
Controls.MakeHarmless(effect);assert(effect.Timeout==-1 and effect.CollisionDamage==0 and effect.EntityCollisionClass==0)
effect.Position={X=0,Y=0};players={{Position={X=24,Y=0}}}
assert(Controls.AnyPlayerWithin(effect,24,function()return players end,Archive.VectorXY))
players[1].Position.X=24.1;assert(not Controls.AnyPlayerWithin(effect,24,function()return players end,Archive.VectorXY))
local session={controlTouchLatch={previous=true,next=true}};local order={}
local touching=Controls.UpdateTouchLatches(session,{'previous','return','next'},function(_,role)
    order[#order+1]=role;return role=='next'
end)
assert(table.concat(order,',')=='previous,return,next' and session.controlTouchLatch.previous==nil and session.controlTouchLatch.next==true)
assert(touching.next and touching.previous==false)
print('archive shared contracts: protected calls, dimensions, live players, geometry, animation failures, distance and latch ownership passed')
