local realDofile=dofile
local load=realDofile('tests/support/neverbirth_fixture.lua')
local complete=realDofile('tests/support/batch16_engine_surface.lua')
local service, consumers
consumers={}
_G.dofile=function(path)
    local result=realDofile(path)
    local name=path:gsub('\\','/'):gsub('%.lua$','')
    if name=='scripts/systems/control_ownership' then
        return {Create=function(...)
            assert(not service,'only one control service per installation')
            service=result.Create(...);return service
        end}
    elseif name=='scripts/systems/shooting_scope' then
        local original=result.ForOwner
        result.ForOwner=function(provided,owner)
            assert(provided==service and service,'consumer bypassed installed control service: '..owner)
            consumers[owner]=(consumers[owner] or 0)+1
            return original(provided,owner)
        end
    end
    return result
end
local ok,err=pcall(load,{OnModCreated=complete})
_G.dofile=realDofile
assert(ok,err)
for _,name in ipairs({'god_complex','bomb_suit','drive_glove'}) do
    assert(consumers[name]==1,name..' must bind one owner to the shared installation')
end
local previous=Neverbirth
local rows
local success,message=pcall(load,{
    OnModCreated=function(_,registered)complete();rows=registered end,
    OnInclude=function(name)
        if name=='scripts.systems.control_ownership' then error('missing control ownership') end
    end,
})
assert(not success and tostring(message):find('missing control ownership',1,true))
assert(Neverbirth==previous,'missing controls replaced the active installation')
for _,callbacks in pairs(rows) do assert(#callbacks==0,'missing controls left callbacks') end
print('control consumers: one installation service, three real owners, missing-module rollback passed')
