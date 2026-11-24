-- Behavioral contracts for the shared acquisition/rollback service.
ModCallbacks = {MC_PRE_PICKUP_COLLISION=1,MC_PRE_ADD_COLLECTIBLE=2,MC_POST_ADD_COLLECTIBLE=3,
 MC_POST_UPDATE=4,MC_POST_GAME_STARTED=5,MC_PRE_GAME_EXIT=6,MC_POST_GLOWING_HOURGLASS_SAVE=7,
 MC_POST_GLOWING_HOURGLASS_LOAD=8,MC_POST_PICKUP_INIT=9,MC_POST_NEW_ROOM=10,MC_POST_PICKUP_COLLISION=11,
 MC_POST_TRIGGER_COLLECTIBLE_REMOVED=12}
PickupVariant={PICKUP_COLLECTIBLE=100};PlayerType={PLAYER_LAZARUS_B=29,PLAYER_LAZARUS2_B=38}
local frame,room,stage,seed=20,1,1,'run-a'; local saved={}; local players={}
local level={GetStage=function()return stage end,GetStageType=function()return 0 end,
 GetDungeonPlacementSeed=function()return 77 end,GetCurrentRoomIndex=function()return room end,
 GetCurrentRoomDesc=function()return {SafeGridIndex=room,ListIndex=room}end}
Game=function()return {GetLevel=function()return level end,GetFrameCount=function()return frame end}end
local callbacks={};local mod={AddCallback=function(_,id,fn) callbacks[id]=fn end}
local p={InitSeed=10,ControllerIndex=0,counts={},GetPlayerType=function()return 0 end,
 GetCollectibleNum=function(self,id)return self.counts[id]or 0 end,ToPlayer=function(self)return self end,
 GetData=function(self)self.data=self.data or{};return self.data end}
players={p}; local ctx={GetSaveRoot=function()return saved end,Save=function()end,
 GetCurrentRunSeed=function()return seed end,GetPlayers=function()return players end}
local f=assert(io.open('pending_content_state.lua','r'),'missing shared state module');f:close()
local s=dofile('pending_content_state.lua')(mod,ctx);local got={}
s.SubscribeAcquisition(function(...)got[#got+1]={...}end)
local function pickup(n,id)return {InitSeed=n,Variant=100,SubType=id,GetData=function(self)
 self.data=self.data or{};return self.data end,Exists=function()return true end}end
local a=pickup(99,5); local b=pickup(100,5)
assert(s.PickupToken(a)~=s.PickupToken(b),'same ID needs separate physical identity')
callbacks[1](mod,a,p,false);callbacks[1](mod,a,p,false)
callbacks[2](mod,5,0,true,0,0,p);p.counts[5]=1;callbacks[3](mod,5,0,true,0,0,p)
assert(#got==0,'wait for real native collision completion')
callbacks[11](mod,a,p,false)
assert(#got==1 and got[1][4]==true and got[1][3]==s.PickupToken(a),'confirmed physical grant')
-- Merely colliding then being cancelled cannot claim a later scripted addition.
callbacks[1](mod,b,p,false); frame=frame+1
callbacks[2](mod,5,0,true,0,0,p);p.counts[5]=2;callbacks[3](mod,5,0,true,0,0,p)
assert(#got==2 and got[2][4]==false,'cancelled collision must not become a physical receipt')
-- Callback without a true inventory increase does not grant an acquisition.
callbacks[2](mod,5,0,true,0,0,p);callbacks[3](mod,5,0,true,0,0,p)
assert(#got==2,'no inventory increase means no reward')
s.WithTemporary(p,function()
 callbacks[2](mod,6,0,false,0,0,p);p.counts[6]=1;callbacks[3](mod,6,0,false,0,0,p)
end)
assert(got[3][5]==true and got[3][4]==false,'temporary additions cannot count as physical')
local value=3;s.RegisterParticipant('probe',function()return{value=value}end,function(x)value=x.value end)
callbacks[7](mod,2);value=9;s.WithTemporary(p,function()error('intentional')end)
callbacks[8](mod,2);assert(value==3,'native slot rollback restores participants')
local other={InitSeed=20,ControllerIndex=1,GetPlayerType=p.GetPlayerType,GetData=p.GetData}
assert(s.PlayerKey(other)~=s.PlayerKey(p),'co-op identities stay separate')
local alive={InitSeed=30,ControllerIndex=2,GetPlayerType=function()return 29 end,GetData=p.GetData}
local dead={InitSeed=31,ControllerIndex=2,GetPlayerType=function()return 38 end,GetData=p.GetData}
alive.GetOtherTwin=function()return dead end;dead.GetOtherTwin=function()return alive end
assert(s.PlayerKey(alive)==s.PlayerKey(dead),'Lazarus forms share identity')
local key=s.FloorKey();room=2;assert(s.FloorKey()==key,'room changes are not new floors')
stage=2;assert(s.FloorKey()~=key,'actual floor changes are distinct')
local history=s.GetAcquisitions(p);assert(#history==3 and history[3].temporary,'serializable order')
-- Same-frame script grant after a cancelled collision has no POST_COLLISION.
local c=pickup(101,7);callbacks[1](mod,c,p,false)
callbacks[2](mod,7,0,true,0,0,p);p.counts[7]=1;callbacks[3](mod,7,0,true,0,0,p)
callbacks[4](mod);assert(got[4][4]==false,'same-frame cancelled collision cannot claim script grant')
local cold; s.RegisterParticipant('cold',function()return cold end,function(x)cold=x end)
local snap=s.Snapshot();cold={reward=1};s.Restore(snap);assert(cold==nil,'missing snapshot participant restores empty state')
callbacks[5](mod,false);assert(#s.GetAcquisitions(p)==0,'same-seed fresh run resets events')
seed='run-b';callbacks[5](mod,false);assert(#s.GetAcquisitions(p)==0,'fresh run clears acquisition state')
-- A confirmed normal collectible must keep physical identity after a native drop in another room.
local function historyItem(id,time)
 return {GetItemID=function()return id end,GetTime=function()return time end,
 IsTrinket=function()return false end,GetLevelStage=function()return stage end,
 GetStageType=function()return 0 end,GetRoomType=function()return 1 end,GetItemPoolType=function()return 0 end}
end
p.Position={X=0,Y=0};p.history={};p.GetHistory=function(self)return{GetCollectiblesHistory=function()return self.history end}end
frame=100;room=1;p.counts[8]=0
local original=pickup(200,8);original.Position={X=0,Y=0}
callbacks[1](mod,original,p,false);callbacks[11](mod,original,p,false)
callbacks[2](mod,8,0,true,0,0,p);p.counts[8]=1;p.history={historyItem(8,100)};callbacks[3](mod,8,0,true,0,0,p)
local originalToken=s.PickupToken(original)
room=2;frame=120;p.counts[8]=0;p.history={};callbacks[12](mod,p,8)
local dropped=pickup(201,8);dropped.Position={X=0,Y=0};dropped.SpawnerEntity=setmetatable({}, {__index=p})
dropped.SpawnerEntity.ToPlayer=function(wrapper)return wrapper end
callbacks[9](mod,dropped)
assert(s.PickupToken(dropped)==originalToken,'same physical collectible after cross-room drop')
callbacks[1](mod,dropped,p,false);callbacks[11](mod,dropped,p,false)
callbacks[2](mod,8,0,true,0,0,p);p.counts[8]=1;p.history={historyItem(8,120)};callbacks[3](mod,8,0,true,0,0,p)
assert(got[#got][3]==originalToken,'repick must not become a fresh reward instance')
-- A later genuinely new object must not inherit a destroyed original.
frame=130;p.counts[8]=0;p.history={};callbacks[12](mod,p,8);callbacks[4](mod)
frame=131;local fresh=pickup(202,8);fresh.Position={X=0,Y=0};fresh.SpawnerEntity=p;callbacks[9](mod,fresh)
assert(s.PickupToken(fresh)~=originalToken,'destroyed object cannot claim a later new pickup')
-- Native histories with identical metadata cannot identify which copy was dropped.
-- Suppress physical rewards on that drop instead of assigning a fresh identity.
callbacks[5](mod,false);p.history={};p.counts={};room=3;frame=200
local duplicates={pickup(300,9),pickup(301,9)}
for i,pedestal in ipairs(duplicates)do
 pedestal.Position={X=0,Y=0}
 callbacks[1](mod,pedestal,p,false);callbacks[11](mod,pedestal,p,false)
 callbacks[2](mod,9,0,true,0,0,p);p.counts[9]=i;p.history[#p.history+1]=historyItem(9,200)
 callbacks[3](mod,9,0,true,0,0,p)
end
local inventory=saved.pendingContent.inventory[s.InventoryPlayerKey(p)]
assert(inventory[1].token==s.PickupToken(duplicates[1]),'proved append keeps the older identical receipt identity')
frame=201;table.remove(p.history,1);p.counts[9]=1;callbacks[12](mod,p,9)
local unknown=pickup(302,9);unknown.Position={X=0,Y=0};unknown.SpawnerEntity=p;callbacks[9](mod,unknown)
assert(unknown:GetData().NeverbirthPhysicalUnresolved,'ambiguous drop cannot create a fresh reward token')
callbacks[1](mod,unknown,p,false);callbacks[11](mod,unknown,p,false)
callbacks[2](mod,9,0,true,0,0,p);p.counts[9]=2;p.history[#p.history+1]=historyItem(9,201)
callbacks[3](mod,9,0,true,0,0,p)
assert(got[#got][4]==false,'ambiguously identified repick must not reward again')
-- Isaac empties QueuedItem before invoking AddCollectible, 37 frames after
-- a real pedestal collision. A scripted grant while the queue is occupied
-- must not consume that physical receipt.
callbacks[5](mod,false);p.history={};p.counts={};p.QueuedItem={}
local queuedPickup=pickup(900,8)
queuedPickup.Position={X=0,Y=0}
frame=300
callbacks[1](mod,queuedPickup,p,false)
queuedPickup.SubType=0
p.QueuedItem.Item={ID=8}
-- The two Lua wrappers represent the same native pickup.
local postWrapper=setmetatable({}, {__index=queuedPickup})
callbacks[11](mod,postWrapper,p,false)
frame=325
callbacks[4](mod)
queuedPickup:GetData().NeverbirthPhysicalTemporary=true
callbacks[2](mod,8,0,true,0,0,p)
p.counts[8]=1;p.history={historyItem(8,325)}
callbacks[3](mod,8,0,true,0,0,p)
assert(got[#got][4]==false,'a grant while the native pickup is still queued is scripted')
assert(got[#got][5]==false,'an unrelated grant cannot inherit the queued pedestal temporary flag')
queuedPickup:GetData().NeverbirthPhysicalTemporary=nil
frame=336
callbacks[4](mod)
frame=337
p.QueuedItem.Item=nil
callbacks[2](mod,8,0,true,0,0,p)
p.counts[8]=2;p.history[2]=historyItem(8,337)
callbacks[3](mod,8,0,true,0,0,p)
assert(got[#got][4] and got[#got][3]==s.PickupToken(queuedPickup),'native queue flush retains its exact physical receipt')
print('PASS pending shared state: physical receipts, cancellation, queue flush, temporary, rollback, players, fresh run')
