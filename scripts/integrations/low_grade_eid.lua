return function(mod, lowGradeId)
    local eidRegistered=false
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE,function()
        if not eidRegistered and lowGradeId>0 and EID and type(EID.addTrinket)=="function" then
            EID:addTrinket(lowGradeId,"{{Damage}} +5 damage#{{Tears}} +5 tears beyond the normal cap#{{Range}} +5 range#Three consecutive floors with Perfection-valid damage: the third floor's final boss drops one copy#Each physical copy expires after 5 valid hits; dropped, golden and swallowed copies keep durability","Low Grade","en_us")
            EID:addTrinket(lowGradeId,"{{Damage}} +5攻击力#{{Tears}} +5射速，可突破常规上限#{{Range}} +5射程#连续三层各受到满分考卷判定的有效伤害：第三层最终头目结算掉落一份#每份实物承受5次有效伤害后移除；丢下、金色、吞下保留该份耐久","零分考卷","zh_cn")
            eidRegistered=true
        end
    end)
end
