-- The public field stays writable; both survival effects read it at the time of use.
return function(Neverbirth)
    Neverbirth.BlackTaisuiDeathSaveInvincibility = 60
    return function()
        return Neverbirth.BlackTaisuiDeathSaveInvincibility
    end
end
