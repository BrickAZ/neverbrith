-- Player-facing controls and confirmed combat values; XML economy is unchanged.
return function(mod,context)
    local entries={
        {'Piledriver360','360','360','Hold Active, then circle once','按住主动键，摇一圈',
            'Enter one full circle with shooting direction keys within 0.8 seconds', '在0.8秒内用射击方向键摇一圈'},
        {'Ultimate720','720','720','Hold Active: Up + Down, or circle twice','主动键＋↑↓，或摇两圈',
            'Hold Active and Up + Down together, or enter two circles within 1.5 seconds; no OD version', '按住主动键，同时按住↑＋↓；也可在1.5秒内摇两圈；没有OD版本'},
        {'MotionWave','Wave','波动','Hold Active, then tap a shooting direction','按住主动键，再按一下射击方向',
            'Tap one shooting direction while holding the active button', '按住主动键，单击一次射击方向键'},
        {'DragonPunch','Dragon Punch','升龙','Hold Active, then enter a dragon-punch motion','按住主动键，再输入升龙指令',
            'Hold Active: 623/421; shortcuts626/424 and323/121; forward/back mean left/right only', '按住主动键输入→↓↘或←↓↙；也接受626/424、323/121；前后仅指左右'},
    }
    local combat={
        Piledriver360={'Confirms a nearby target when the command completes; grabs at frame 6 even if it moves during startup#Slam deals 3x damage#Both versions deal 3x damage to other enemy centers within 80 units of the landing; the primary is not hit twice#Hold Active and Left Shift, then circle for OD: 6x primary damage, shared 6s cooldown#OD request stays with the motion and its recovery buffer',
            '指令完成时确认周围最近有效近身目标，第六帧抓取；起手位移不使已确认命中抓空#重摔对主目标造成3倍面板伤害#普通和OD落地时，对落点半径80内的其他敌人造成3倍面板伤害；主目标不重复结算#按住主动键和左Shift再摇一圈使用OD：主目标6倍伤害，与OD升龙共用6秒冷却#OD请求随搓招及收招缓存保留'},
        Ultimate720={'Acquiring 720 fills all 3 SA bars; 30 actual damage fills one bar afterward#V9 native closeups frame the live player and real target#V9 slam: 15x primary damage, 10x to other room enemies#No target or insufficient meter: no cost; this attack cannot refill itself',
            '获得720时补满3格SA，之后每造成30点有效伤害积攒1格#V9镜头特写绘制真实玩家与实际目标#V9重摔：主目标15倍面板伤害，其余房内敌人10倍#无目标或气不足不消耗；720自身不回气'},
        MotionWave={'Fires one real projectile for 1x damage; stops at a wall or first enemy',
            '发射真实波动弹体，造成1倍伤害；碰墙或首个敌人后消失'},
        DragonPunch={'Forced horizontal uppercut; movement input is locked#Frontal strike: 2x damage#Hold Active and Left Shift, then enter the motion for OD: two stages deal 2x + 3x damage#OD request stays with the motion and its recovery buffer#OD shares a 6s cooldown with OD360; ordinary damage is blocked through the second strike, recovery is vulnerable; life payments remain',
            '升龙期间禁止移动输入，沿出招方向水平推进#前方近战攻击，造成2倍伤害#按住主动键和左Shift再搓升龙使用OD：两段分别2倍和3倍伤害#OD请求随指令缓存，不必精确卡住完成的瞬间#与OD360共用6秒冷却；OD第二段结束前免常规伤害，收招可被打；不免主动生命支付'},
    }
    for _,e in ipairs(entries) do
        local id=context.Items[e[1]]
        if type(id)=='number' and id>0 and id%1==0 then
            mod:RegisterPickupBannerText(id,e[2],e[4],e[3],e[5])
            context.EIDDescriptions[id]={
                en_us={name=e[2],eidDescription=e[6]..'#DP inputs use horizontal mirroring; grabs select a valid target#WASD only moves; holding this item disables native attacks#'..combat[e[1]][1]},
                zh_cn={name=e[3],eidDescription=e[7]..'#升龙只接受水平镜像；指令投自动选择有效目标#WASD只移动，持有时禁用眼泪及原生替代武器#'..combat[e[1]][2]},
            }
        end
    end
end
