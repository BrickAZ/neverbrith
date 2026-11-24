local verify=dofile("tests/repentogon_installed_dispatch_contract.lua")
local baseline=dofile("tests/fixtures/repentogon_1_0_12a_damage_contract.lua")
local function source(version)
    return 'REPENTOGON={["Version"]="'..version..'"}\n'..baseline.comparator..'-- Normally if you execute\n'..baseline.dispatcher..'-- Custom handling for MC_PRE_TRIGGER_PLAYER_DEATH'
end
assert(verify(source("1.0.12a"))=="1.0.12a")
assert(verify(source("1.0.12a-yin-api1-dev"))=="1.0.12a-yin-api1-dev")
for _,version in ipairs({"dev","1.0.12b","1.0.12a-yin-api2-dev","1.0.12a-nightly"})do assert(not pcall(verify,source(version)),"unknown audited version must fail")end
assert(not pcall(verify,source("1.0.12a-yin-api1-dev"):gsub("return false","return true",1)),"changed damage cancellation must fail")
assert(not pcall(verify,source("1.0.12a-yin-api1-dev"):gsub("local function CallbackComparator%(","local function ChangedComparator(",1)),"missing comparator must fail")
print("PASS official_and_approved_candidate, reject_unknown_versions, reject_changed_dispatch_and_comparator")
