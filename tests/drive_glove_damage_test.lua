-- Expected values come from paired native hits in mechanic-audit, not from
-- duplicating the adapter formula. Amounts and cooldowns use different units.
DamageFlag={DAMAGE_NO_MODIFIERS=1<<25,DAMAGE_RED_HEARTS=1<<5,DAMAGE_COUNTDOWN=1<<6,DAMAGE_FIRE=2}
CollectibleType={COLLECTIBLE_WAFER=108,COLLECTIBLE_MOMS_BOX=439}
TrinketType={TRINKET_BLIND_RAGE=82}
PlayerType={PLAYER_KEEPER=14,PLAYER_KEEPER_B=33}
LevelStage={STAGE4_1=7}
local D=dofile('drive_glove_damage.lua')
local count=0
local cases={
 {1,1,0,0,false,0,false,1,60},
 {1,2,0,0,false,0,false,2,120},
 {1,.5,0,0,false,0,false,1,60},
 {1,1.5,0,0,false,0,false,2,120},
 {1,2.5,0,0,false,0,false,3,120},
 {7,1,0,0,false,0,false,2,60},
 {7,1,0,0,true,0,false,1,60},
 {1,2,0,0,true,0,false,1,120},
 {7,3,DamageFlag.DAMAGE_NO_MODIFIERS,0,false,0,false,3,120},
 {7,1,DamageFlag.DAMAGE_RED_HEARTS,0,false,0,false,2,60},
 {1,1,0,0,false,1,false,1,120},
 {7,1,0,0,false,1,false,2,120},
 {1,1,0,0,false,2,false,1,240},
 {1,2,0,0,false,1,false,2,240},
 {1,2,0,0,false,2,false,2,480},
 {1,1,0,0,false,2,true,1,240},
 {1,1,0,0,false,3,true,1,360},
 {1,1,0,14,false,0,false,2,60},
 {1,2,0,14,true,0,false,2,120},
 {1,3,DamageFlag.DAMAGE_NO_MODIFIERS,14,false,0,false,4,120},
 {1,1,0,33,false,0,false,2,60},
}
for i,c in ipairs(cases) do
 local p={HasCollectible=function(_,id)return id==108 and c[5] or id==439 and c[7] end,
  GetPlayerType=function()return c[4] end,GetTrinketMultiplier=function()return c[6] end,
  SetMinDamageCooldown=function(self,v)self.cooldown=v end}
 local game={GetLevel=function()return {GetStage=function()return c[1] end}end}
 assert(D.NormalAmount(p,c[2],c[3],game)==c[8],'native fee case '..i);count=count+1
 D.Cooldown(p,c[2],c[3],0)
 assert(p.cooldown==c[9],'native cooldown case '..i);count=count+1
end
print('Drive Glove damage: '..count..' assertions passed')
