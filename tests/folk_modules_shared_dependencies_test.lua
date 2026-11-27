-- Each consumer receives its real shared dependency without installing its peer items.
function include(name) return dofile(name:gsub('%.', '/') .. '.lua') end
ModCallbacks = { MC_ENTITY_TAKE_DMG = 1, MC_EVALUATE_CACHE = 2, MC_POST_UPDATE = 3, MC_POST_EFFECT_UPDATE = 4 }
EntityType = { ENTITY_PLAYER = 1 }
DamageFlag = { DAMAGE_FAKE = 1, DAMAGE_NOKILL = 2 }

local function newMod()
    local mod = { registrations = {} }
    function mod:AddCallback(event, fn, filter)
        self.registrations[#self.registrations + 1] = { event = event, fn = fn, filter = filter }
    end
    return mod
end

local meat = newMod()
local getCooldown = dofile("scripts/systems/folk_survival_cooldown.lua")(meat)
local saved = { meatLumpLives = { ["8"] = 2 }, meatLumpCounts = {}, players = { ["8"] = { parasite = 16 } } }
local saves = 0
local store = { Save = function() saves = saves + 1 end }
local function getData() return saved end
local player = { InitSeed = 8, maxHearts = 2, hearts = 0 }
function player:ToPlayer() return self end
function player:GetHearts() return self.hearts end
function player:AddHearts(amount) self.hearts = self.hearts + amount end
function player:SetMinDamageCooldown(value)
    assert(type(value) == "number")
    self.cooldown = value
end
local function getPlayers() return { player } end
local meatInstance = dofile("scripts/features/meat_lump.lua")(meat, {
    MeatLumpId = 71, IsValidItemId = function(id) return id > 0 end, GetPlayers = getPlayers,
    IsIncomingDamageLethal = function() return true end, GetSaveData = getData, Store = store,
    GetSurvivalCooldown = getCooldown,
})
meatInstance.InstallDamageCallbacks()
local damage = meat.registrations[1]
assert(damage.event == ModCallbacks.MC_ENTITY_TAKE_DMG and damage.filter == EntityType.ENTITY_PLAYER)
assert(damage.fn(meat, player, 1, 0) == false)
assert(player.hearts == 1 and player.cooldown == 60 and saved.meatLumpLives["8"] == 1 and saves == 1)

meat.BlackTaisuiDeathSaveInvincibility = 42
assert(damage.fn(meat, player, 1, 0) == false)
assert(player.cooldown == 42 and saved.meatLumpLives["8"] == 0 and saves == 2)

local vector = { __add = function(a, b) return Vector(a.X + b.X, a.Y + b.Y) end }
function Vector(x, y) return setmetatable({ X = x, Y = y }, vector) end
player.Position = Vector(10, 20)
local spawned = {}
local function spawn(variant, position)
    local data = {}
    local effect = { Variant = variant, Position = position, GetData = function() return data end }
    spawned[#spawned + 1] = effect
    return effect
end
Isaac = { Spawn = spawn }

local world = {
    GetFolkPlayerKey = function(p) return tostring(p.InitSeed) end,
    GetFolkRoomKey = function() return "1:0:2" end,
    GetFolkFloorKey = function() return "1:0" end,
    GetFolkGame = function() end,
    PlayerHasCollectible = function(_, id) return id == 73 end,
    SpawnFolkEffect = spawn,
}
local provider = newMod()
local effects = dofile("scripts/systems/folk_visual_effects.lua")(provider, { World = world, GetPlayers = getPlayers })
assert(effects.Spawn == provider.SpawnFolkVisualEffect and effects.IsActive == provider.IsFolkVisualEffectActive)
assert(effects.BindOwner == provider.BindFolkVisualEffectOwner and effects.RefreshTimeout == provider.RefreshFolkVisualEffectTimeout)
assert(#provider.registrations == 1 and provider.registrations[1].fn == provider.UpdateFolkVisualEffect)

local parasiteState = { sporeKeys = {} }
local taisui = newMod()
dofile("scripts/features/black_taisui.lua")(taisui, {
    World = world, BlackTaisuiId = 73, CleansedWavyCapId = 72, MeatLumpId = 71,
    IsValidItemId = function(id) return id > 0 end, GetPlayers = getPlayers, Store = store,
    Log = function() end, IsIncomingDamageLethal = function() return true end,
    ParasiteState = { GetSaveData = getData, GetRuntimeState = function() return parasiteState end },
    CleansedWavyCap = {}, MeatLump = meatInstance, GetSurvivalCooldown = getCooldown, VisualEffects = effects,
})
assert(taisui.SpawnFolkVisualEffect == nil)
meat.BlackTaisuiDeathSaveInvincibility = 35
assert(taisui:ApplyBlackTaisuiDeathSave(player, false) and player.cooldown == 35)
assert(spawned[1]:GetData().NeverbirthFolkVisualEffectKey == "BlackTaisuiDeathDeny")
assert(spawned[3]:GetData().NeverbirthFolkVisualEffectKey == "BlackTaisuiFearPulse")

local goodGirl = newMod()
dofile("scripts/features/good_girl_of_babylon.lua")(goodGirl, {
    World = world, GetPlayers = getPlayers, GoodGirlOfBabylonId = 70, PublishGlobal = function() end, VisualEffects = effects,
})
assert(goodGirl.BindFolkVisualEffectOwner == nil)
local state = {}
local halo = goodGirl:EnsureGoodGirlFollowEffect(state, "haloEffect", "GoodGirlHalo", player)
assert(halo == spawned[4] and halo.Parent == player)
halo:GetData().NeverbirthFolkVisualEffectTimeout = 1
local secondPlayer = { InitSeed = 9, Position = Vector(50, 60) }
assert(goodGirl:EnsureGoodGirlFollowEffect(state, "haloEffect", "GoodGirlHalo", secondPlayer) == halo)
assert(#spawned == 4 and halo.Parent == secondPlayer and halo.Position.X == 50)
assert(halo:GetData().NeverbirthFolkVisualEffectOwnerSeed == 9 and halo:GetData().NeverbirthFolkVisualEffectTimeout == 45)
print("Folk shared dependencies: independent meat save, live cooldown, Taisui burst, existing halo refresh")
