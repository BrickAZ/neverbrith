WeaponType={WEAPON_TEARS=1,WEAPON_BRIMSTONE=2,WEAPON_LASER=3,WEAPON_KNIFE=4,WEAPON_BOMBS=5,
 WEAPON_MONSTROS_LUNGS=7,WEAPON_TECH_X=9,WEAPON_BONE=10,WEAPON_SPIRIT_SWORD=13,WEAPON_FETUS=14}
WeaponModifier={CHOCOLATE_MILK=1,CURSED_EYE=2,BRIMSTONE=4,MONSTROS_LUNG=8,LUDOVICO_TECHNIQUE=16,SOY_MILK=128,NEPTUNUS=256}
local W=dofile('drive_glove_weapon.lua')
local n=0
local function check(kind,mods,delay,want)
 local w={GetWeaponType=function()return kind end,GetModifiers=function()return mods end,GetMaxFireDelay=function()return delay end}
 assert(math.abs(W.Full(w)-want)<1e-6,string.format('weapon %s modifier %s: %s vs %s',kind,mods,W.Full(w),want));n=n+1
end
check(1,0,10,0);check(1,1,10,26.5);check(1,2,10,21);check(1,3,10,54);check(1,256,10,131)
check(2,4,32,32);check(2,5,32,80);check(2,20,32,0);check(2,132,2,2)
check(7,8,46.3,46.3);check(7,9,46.3,115.75)
check(4,0,10,40);check(4,16,10,0);check(9,0,10,30);check(13,0,10,40);check(14,0,10,30)
check(3,8,10,46.3);check(3,9,10,117.25);check(3,2,10,21);check(5,0,10,0)
check(4,0,-.5,.004);check(1,1,2,6.5);check(1,256,2,35)
for _,c in ipairs({{1,2,true,true},{1,256,false,false},{13,0,false,false},{2,132,false,false},{2,4,true,false},{9,0,true,false}}) do
 local w={GetWeaponType=function()return c[1] end,GetModifiers=function()return c[2] end,GetMaxFireDelay=function()return 10 end}
 assert(W.Release(w)==c[3],'release classification');n=n+1
 assert(W.ReleaseBurst(w)==c[4],'native release burst classification');n=n+1
end
print('Drive Glove weapon: '..n..' assertions passed')
