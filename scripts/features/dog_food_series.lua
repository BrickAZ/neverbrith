-- Family assembly only: seven explicit entries share one acquisition ledger and original callbacks.
return function(Neverbirth, dependencies)
local Items = dependencies.Items
local stats = include("scripts.systems.collectible_stats")(dependencies.IsValidItemId)
local definitions = {
    include("scripts.features.protein_strip")({ ItemId = Items.ProteinStrip, Stats = stats }),
    include("scripts.features.energy_kibble")({ ItemId = Items.EnergyKibble, Stats = stats }),
    include("scripts.features.lean_can")({ ItemId = Items.LeanCan, Stats = stats }),
    include("scripts.features.dha_fish_oil")({ ItemId = Items.DHAFishOil, Stats = stats }),
    include("scripts.features.dental_chew")({ ItemId = Items.DentalChew, Stats = stats }),
    include("scripts.features.lucky_liver_bites")({ ItemId = Items.LuckyLiverBites, Stats = stats }),
    include("scripts.features.goat_milk_pudding")({ ItemId = Items.GoatMilkPudding, Stats = stats }),
}
return include("scripts.systems.dog_food_acquisition")(Neverbirth, { Definitions = definitions, Combat = definitions[5], Stats = stats, Store = dependencies.Store, GetPlayers = dependencies.GetPlayers, GetCurrentRunSeed = dependencies.GetCurrentRunSeed, IsValidItemId = dependencies.IsValidItemId, Log = dependencies.Log })
end
