local loadMod = dofile('tests/support/neverbirth_fixture.lua')
loadMod()
local seedQueries=0
Game=function()
    return { GetSeeds=function()
        seedQueries=seedQueries+1
        return {GetStartSeedString=function() return 'idle-query-test' end}
    end }
end
local player={InitSeed=9191, GetHearts=function() return 6 end, ToPlayer=function(self) return self end}
Neverbirth:EvaluateMusicbox(player,CacheFlag.CACHE_DAMAGE)
Neverbirth:PreventActiveMusicboxDamage(player)
Neverbirth:PreventMusicboxDamage(player,1)
assert(seedQueries==0,'empty death-debt lookup must short-circuit native run-seed queries; got '..seedQueries)
print('musicbox idle queries passed: no native seed lookup without debt')
