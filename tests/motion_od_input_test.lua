local checks=0;local function check(v,m)assert(v,m);checks=checks+1 end
include=function(name)return dofile(name..'.lua')end
ButtonAction={ACTION_LEFT=0,ACTION_RIGHT=1,ACTION_UP=2,ACTION_DOWN=3,ACTION_SHOOTLEFT=4,ACTION_SHOOTRIGHT=5,ACTION_SHOOTUP=6,ACTION_SHOOTDOWN=7,ACTION_ITEM=9,ACTION_PILLCARD=10}
Keyboard={KEY_LEFT_SHIFT=340};ModCallbacks={};InputHook={GET_ACTION_VALUE=2};Isaac={}
PillCardSlot={PRIMARY=0};PocketItemType={ACTIVE_ITEM=2}
local now,buttons,shift,status=0,{},false,'ready';local p={ControllerIndex=0,InitSeed=1}
function p:Exists()return true end;function p:IsDead()return false end
function p:GetActiveItem()return 801 end;function p:GetHeadDirection()return 2 end
function p:GetPocketItem()return nil end
local mod={};function mod:AddPriorityCallback()end
Game=function()return {IsPaused=function()return false end,GetFrameCount=function()return now*30 end}end
Input={GetActionValue=function(action)return buttons[action]or 0 end,
 IsButtonPressed=function(key,controller)check(key==340 and controller==0,'real keyboard modifier boundary');return shift end}
local executed={}
local api=include('motion_input')(mod,{Key=function()return 'p'end,Now=function()return now end})
api:RegisterOwner('dp',{collectibleId=801,profile='dp',has=function()return true end,
 availability=function()return status end,execute=function(_,command)executed[#executed+1]=command;return {ok=true}end})
local function sample(keys,held)
 now=now+1/30;buttons=keys or {};if held then buttons[9]=1 end;api:SamplePlayer(p)
end
sample();shift=true;sample({[5]=1},true);shift=false;sample({[7]=1},true);sample({[5]=1,[7]=1},true)
check(#executed==1 and executed[1].odRequested==true,'OD pressed during the motion survives release just before completion')
sample();sample({[5]=1},true);sample({[7]=1},true);sample({[5]=1,[7]=1},true)
check(#executed==2 and executed[2].odRequested==false,'OD request does not leak into the next ordinary motion')
sample();status='recovery';shift=true;sample({[5]=1},true);sample({[7]=1},true);sample({[5]=1,[7]=1},true)
check(api:GetState(p).pending and #executed==2,'OD motion enters the existing recovery buffer')
shift=false;status='ready';sample({},true)
check(#executed==3 and executed[3].odRequested==true,'buffered OD keeps its original modifier after Shift is released')
sample();sample({[5]=1},true);sample({[7]=1},true);sample({[5]=1,[7]=1},true)
check(#executed==4 and not executed[4].odRequested,'consumed buffered modifier stays consumed')

REPENTANCE_PLUS = true
for _, keyboardIndex in ipairs({-2, 4294967294}) do
    p.ControllerIndex = keyboardIndex
    Input.IsButtonPressed = function(key, controller)
        check(key == Keyboard.KEY_LEFT_SHIFT, 'OD reads the keyboard Shift button')
        return shift and controller == keyboardIndex
    end
    local previousExecutions = #executed
    sample()
    shift = true
    sample({[5]=1},true)
    shift = false
    sample({[7]=1},true)
    sample({[5]=1,[7]=1},true)
    check(#executed == previousExecutions + 1 and executed[#executed].odRequested,
        'the owning keyboard can request OD with either representation of its device ID')
    shift = true
    check(not api:IsODModifierPressed({ControllerIndex=0}), 'gamepad zero must not read the keyboard modifier')
    check(not api:IsODModifierPressed({}), 'a player without a device must not read another input source')
    shift = false
end

print('motion_od_input: '..checks..' assertions passed')
