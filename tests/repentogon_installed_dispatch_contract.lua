-- Only the audited official version and this explicitly approved local candidate.
return function(source)
    local version=source:match('%["Version"%]%s*=%s*"([^"]+)"')
    assert(version=="1.0.12a" or version=="1.0.12a-yin-api1-dev","dispatcher evidence must match audited 1.0.12a or approved Yin candidate")
    local baseline=dofile("tests/fixtures/repentogon_1_0_12a_damage_contract.lua")
    local function section(first,last)
        local start=assert(source:find(first,1,true),"missing audited section")
        local finish=assert(source:find(last,start,true),"missing audited section end")
        return source:sub(start,finish-1):gsub("\r\n","\n")
    end
    assert(section("local function CallbackComparator(","-- Normally if you execute")==baseline.comparator,"installed callback comparator differs from audited 1.0.12a")
    assert(section("function _RunEntityTakeDmgCallback(","-- Custom handling for MC_PRE_TRIGGER_PLAYER_DEATH")==baseline.dispatcher,"installed damage dispatcher differs from audited 1.0.12a")
    return version
end
