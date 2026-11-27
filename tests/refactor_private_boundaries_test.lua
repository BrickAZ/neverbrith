local load=dofile('tests/support/neverbirth_fixture.lua')
local env=load();local mod=Neverbirth
for _,name in ipairs({'CondomBanCount','CondomReplacementAttempts','CondomEntityPickup','CondomCollectibleVariant','GetCondomEligibleItems',
    'PickCondomTarget','IsCondomBannedCollectible','GetCondomCollectibleName','ShowCondomFeedback',
    'UtilityKnifeDamageUp','FindUtilityKnifePickupPlayer'})do
    assert(mod[name]==nil,'pure internal member still mounted: '..name)
end
assert(type(mod.DogFoodSeriesTestAPI)=='table' and type(mod.Musicbox.Visuals)=='table')
assert(mod.Musicbox.EnsureVisual==nil and mod.Musicbox.VisualSpecs==nil,'private presentation API/config leaked')
assert(type(mod.GetCollectibleConfig)=='function' and type(mod.GetCondomData)=='function')
assert(type(mod.GetUtilityKnifeData)=='function' and type(mod.GetCrazyCoconutNaturalDamage)=='function')
for _,name in ipairs({'UseMusicbox','UpdateMusicbox','RenderMusicboxCountdown','EvaluateUtilityKnife',
    'UseCondom','ReplaceCondomBannedPickup','EvaluateCrazyCoconut','TrackCrazyCoconutCopies'})do
    local n=0
    for _,records in pairs(env.callbacks)do
        for _,record in ipairs(records)do if record.fn==mod[name] then n=n+1 end end
    end
    assert(n>0,'strict-validator-compatible callback lost: '..name)
end
print('Private boundaries: local state/helpers, retained tested methods and registered handlers passed')
