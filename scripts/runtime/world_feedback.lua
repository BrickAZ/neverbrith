-- Small engine adapter shared by features which darken the room.
return {
    Darken = function(amount)
        local game = Game()
        if game and game.Darken then game:Darken(amount or 0, 2) end
    end,
}
